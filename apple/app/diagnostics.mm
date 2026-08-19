// diagnostics.mm - bounded, redacted DinoPad runtime diagnostics and sharing.

#include <atomic>
#include <cerrno>
#include <chrono>
#include <cstdio>
#include <filesystem>
#include <mutex>
#include <string>
#include <thread>

#include <fcntl.h>
#include <mach/mach.h>
#include <os/proc.h>
#include <sys/resource.h>
#include <sys/stat.h>
#include <sys/sysctl.h>
#include <unistd.h>

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "diagnostics.h"
#import "rom_setup.h"
#import "test_harness.h"

#ifdef MIN
#undef MIN
#endif

#include "config/config.hpp"
#include "ultramodern/ultramodern.hpp"

extern "C" int dinopad_shell_touch_enabled(void);
extern "C" double dinopad_shell_touch_opacity(void);
extern "C" int dinopad_shell_controller_connected(void);

namespace {

constexpr NSUInteger kMaximumSharedLogBytes = 192u * 1024u;
constexpr NSUInteger kMaximumReportBytes = 512u * 1024u;
constexpr size_t kMaximumStoredLogBytes = 4u * 1024u * 1024u;
constexpr size_t kMaximumStoredLineBytes = 64u * 1024u;
std::atomic_bool g_diagnosticsStarted{false};
std::atomic_bool g_appActive{true};
std::atomic_bool g_runtimeActive{false};
std::atomic_bool g_stallReported{false};
std::atomic<uint64_t> g_flightSequence{0};
std::atomic<uint64_t> g_gameplayPolls{0};
std::atomic<uint64_t> g_lastGameplayProgressNanos{0};
std::atomic<uint64_t> g_lastHeartbeatLogNanos{0};
NSArray<id>* g_lifecycleObservers = nil;
std::mutex g_processSampleMutex;
double g_previousCPUSeconds = 0.0;
uint64_t g_previousCPUSampleNanos = 0;

constexpr uint64_t kNanosPerSecond = 1000000000ULL;
#if DINOPAD_ENABLE_TEST_HARNESS
constexpr uint64_t kHeartbeatLogIntervalNanos = 2ULL * kNanosPerSecond;
#else
constexpr uint64_t kHeartbeatLogIntervalNanos = 15ULL * kNanosPerSecond;
#endif
constexpr uint64_t kSuspectedStallNanos = 15ULL * kNanosPerSecond;

uint64_t monotonicNanos() {
    return static_cast<uint64_t>(std::chrono::duration_cast<std::chrono::nanoseconds>(
        std::chrono::steady_clock::now().time_since_epoch()).count());
}

uint64_t processElapsedMilliseconds() {
    static const uint64_t started = monotonicNanos();
    return (monotonicNanos() - started) / 1000000ULL;
}

void logFlight(const char* category, const char* event) {
    if (category == nullptr || event == nullptr) return;
    const uint64_t sequence = g_flightSequence.fetch_add(1, std::memory_order_relaxed) + 1;
    std::fprintf(stderr,
        "[dinopad-flight] seq=%llu t_ms=%llu thread=%s category=%s event=%s\n",
        static_cast<unsigned long long>(sequence),
        static_cast<unsigned long long>(processElapsedMilliseconds()),
        NSThread.isMainThread ? "main" : "background", category, event);
    std::fflush(stderr);
}

const char* thermalStateName(NSProcessInfoThermalState state) {
    switch (state) {
        case NSProcessInfoThermalStateFair: return "fair";
        case NSProcessInfoThermalStateSerious: return "serious";
        case NSProcessInfoThermalStateCritical: return "critical";
        default: return "nominal";
    }
}

bool processUsage(double& cpuSeconds, double& residentMiB) {
    struct rusage usage = {};
    if (getrusage(RUSAGE_SELF, &usage) != 0) return false;
    mach_task_basic_info_data_t info = {};
    mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
    if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO,
            reinterpret_cast<task_info_t>(&info), &count) != KERN_SUCCESS) {
        return false;
    }
    cpuSeconds = static_cast<double>(usage.ru_utime.tv_sec) +
        static_cast<double>(usage.ru_utime.tv_usec) / 1e6 +
        static_cast<double>(usage.ru_stime.tv_sec) +
        static_cast<double>(usage.ru_stime.tv_usec) / 1e6;
    residentMiB = static_cast<double>(info.resident_size) / (1024.0 * 1024.0);
    return true;
}

void logProcessSample(uint64_t now, uint64_t polls) {
    double cpuSeconds = 0.0;
    double residentMiB = 0.0;
    if (!processUsage(cpuSeconds, residentMiB)) {
        logFlight("telemetry", "process_sample_unavailable");
        return;
    }
    double cpuPercent = -1.0;
    {
        std::lock_guard<std::mutex> lock(g_processSampleMutex);
        if (g_previousCPUSampleNanos != 0 && now > g_previousCPUSampleNanos) {
            cpuPercent = 100.0 * (cpuSeconds - g_previousCPUSeconds) /
                (static_cast<double>(now - g_previousCPUSampleNanos) /
                    static_cast<double>(kNanosPerSecond));
        }
        g_previousCPUSeconds = cpuSeconds;
        g_previousCPUSampleNanos = now;
    }
    NSProcessInfo* info = NSProcessInfo.processInfo;
    const double availableMiB = static_cast<double>(os_proc_available_memory()) /
        (1024.0 * 1024.0);
    char event[256];
    std::snprintf(event, sizeof(event),
        "sample polls=%llu cpu_pct=%.1f resident_mib=%.1f available_mib=%.1f thermal=%s low_power=%d",
        static_cast<unsigned long long>(polls), cpuPercent, residentMiB, availableMiB,
        thermalStateName(info.thermalState), info.isLowPowerModeEnabled ? 1 : 0);
    logFlight("telemetry", event);
}

void logSessionMetadata() {
    char hardware[128] = {};
    size_t hardwareLength = sizeof(hardware);
    if (sysctlbyname("hw.machine", hardware, &hardwareLength, nullptr, 0) != 0 ||
        hardware[0] == '\0') {
        std::snprintf(hardware, sizeof(hardware), "unknown");
    }
    NSBundle* bundle = NSBundle.mainBundle;
    UIScreen* screen = UIScreen.mainScreen;
    NSString* version = [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"]
        ?: @"unknown";
    NSString* build = [bundle objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"unknown";
    NSString* os = NSProcessInfo.processInfo.operatingSystemVersionString;
    char event[384];
    std::snprintf(event, sizeof(event),
        "metadata version=%s build=%s os=%s hardware=%s processors=%ld physical_memory_mib=%.1f screen_points=%.0fx%.0f native_scale=%.2f max_fps=%ld",
        version.UTF8String, build.UTF8String, os.UTF8String, hardware,
        static_cast<long>(NSProcessInfo.processInfo.activeProcessorCount),
        static_cast<double>(NSProcessInfo.processInfo.physicalMemory) / (1024.0 * 1024.0),
        screen.bounds.size.width, screen.bounds.size.height, screen.nativeScale,
        static_cast<long>(screen.maximumFramesPerSecond));
    logFlight("session", event);
}

void installLifecycleObservers() {
    if (g_lifecycleObservers != nil) return;
    NSNotificationCenter* center = NSNotificationCenter.defaultCenter;
    NSMutableArray<id>* observers = [NSMutableArray array];
    [observers addObject:[center addObserverForName:UIApplicationWillResignActiveNotification
        object:nil queue:nil usingBlock:^(__unused NSNotification* note) {
            g_appActive.store(false, std::memory_order_relaxed);
            logFlight("lifecycle", "will_resign_active");
        }]];
    [observers addObject:[center addObserverForName:UIApplicationDidEnterBackgroundNotification
        object:nil queue:nil usingBlock:^(__unused NSNotification* note) {
            g_appActive.store(false, std::memory_order_relaxed);
            logFlight("lifecycle", "did_enter_background");
        }]];
    [observers addObject:[center addObserverForName:UIApplicationWillEnterForegroundNotification
        object:nil queue:nil usingBlock:^(__unused NSNotification* note) {
            logFlight("lifecycle", "will_enter_foreground");
        }]];
    [observers addObject:[center addObserverForName:UIApplicationDidBecomeActiveNotification
        object:nil queue:nil usingBlock:^(__unused NSNotification* note) {
            g_appActive.store(true, std::memory_order_relaxed);
            g_lastGameplayProgressNanos.store(monotonicNanos(), std::memory_order_relaxed);
            logFlight("lifecycle", "did_become_active");
        }]];
    [observers addObject:[center addObserverForName:UIApplicationDidReceiveMemoryWarningNotification
        object:nil queue:nil usingBlock:^(__unused NSNotification* note) {
            double cpuSeconds = 0.0;
            double residentMiB = 0.0;
            processUsage(cpuSeconds, residentMiB);
            char event[160];
            std::snprintf(event, sizeof(event),
                "warning_received resident_mib=%.1f available_mib=%.1f",
                residentMiB, static_cast<double>(os_proc_available_memory()) /
                    (1024.0 * 1024.0));
            logFlight("memory", event);
        }]];
    [observers addObject:[center addObserverForName:UIApplicationUserDidTakeScreenshotNotification
        object:nil queue:nil usingBlock:^(__unused NSNotification* note) {
            logFlight("diagnostic", "user_screenshot_taken");
        }]];
    [observers addObject:[center addObserverForName:UIApplicationWillTerminateNotification
        object:nil queue:nil usingBlock:^(__unused NSNotification* note) {
            logFlight("lifecycle", "will_terminate");
        }]];
    g_lifecycleObservers = [observers copy];
}

void startRuntimeWatchdog() {
    std::thread([] {
        for (;;) {
            std::this_thread::sleep_for(std::chrono::seconds(2));
            if (!g_runtimeActive.load(std::memory_order_relaxed) ||
                !g_appActive.load(std::memory_order_relaxed)) {
                continue;
            }
            const uint64_t last = g_lastGameplayProgressNanos.load(std::memory_order_relaxed);
            const bool stalled = last != 0 && monotonicNanos() - last >= kSuspectedStallNanos;
            if (stalled && !g_stallReported.exchange(true, std::memory_order_relaxed)) {
                logFlight("watchdog", "gameplay_progress_stalled_15s");
            } else if (!stalled && g_stallReported.exchange(false, std::memory_order_relaxed)) {
                logFlight("watchdog", "gameplay_progress_resumed");
            }
        }
    }).detach();
}

NSURL* dataRootURL() {
    const std::string path = dino::config::get_data_folder_path().string();
    return path.empty() ? nil : [NSURL fileURLWithPath:[NSString stringWithUTF8String:path.c_str()]
                                            isDirectory:YES];
}

NSURL* diagnosticsDirectory(NSURL* root) {
    return [root URLByAppendingPathComponent:@"Logs" isDirectory:YES];
}

NSURL* runtimeLogURL(NSURL* root) {
    return [diagnosticsDirectory(root) URLByAppendingPathComponent:@"dinopad-latest.log"];
}

NSURL* previousRuntimeLogURL(NSURL* root) {
    return [diagnosticsDirectory(root) URLByAppendingPathComponent:@"dinopad-previous.log"];
}

NSURL* activeSessionMarkerURL(NSURL* root) {
    return [diagnosticsDirectory(root) URLByAppendingPathComponent:@"dinopad-session-active"];
}

NSURL* previousSessionUncleanMarkerURL(NSURL* root) {
    return [diagnosticsDirectory(root) URLByAppendingPathComponent:@"dinopad-previous-unclean"];
}

#if DINOPAD_ENABLE_TEST_HARNESS
NSURL* smokeEvidenceURL(NSURL* root) {
    return [diagnosticsDirectory(root) URLByAppendingPathComponent:@"dinopad-smoke-report.txt"];
}
#endif

void writeAll(int descriptor, const char* bytes, size_t length) {
    while (length > 0) {
        const ssize_t written = write(descriptor, bytes, length);
        if (written > 0) {
            bytes += written;
            length -= static_cast<size_t>(written);
        } else if (written < 0 && errno == EINTR) {
            continue;
        } else {
            break;
        }
    }
}

NSString* replaceRegex(NSString* input, NSString* pattern, NSString* replacement) {
    NSError* error = nil;
    NSRegularExpression* regex = [NSRegularExpression
        regularExpressionWithPattern:pattern options:0 error:&error];
    if (regex == nil || error != nil) return input;
    return [regex stringByReplacingMatchesInString:input options:0
        range:NSMakeRange(0, input.length) withTemplate:replacement];
}

NSString* sanitizedText(NSString* input, NSURL* root) {
    NSMutableString* sanitized = [input mutableCopy] ?: [NSMutableString string];
    NSArray<NSArray<NSString*>*>* replacements = @[
        @[root.path ?: @"", @"<DATA_ROOT>"],
        @[NSTemporaryDirectory() ?: @"", @"<TEMP>/"],
        @[NSHomeDirectory() ?: @"", @"<HOME>"],
    ];
    for (NSArray<NSString*>* replacement in replacements) {
        if (replacement[0].length == 0) continue;
        [sanitized replaceOccurrencesOfString:replacement[0]
                                   withString:replacement[1]
                                      options:NSCaseInsensitiveSearch
                                        range:NSMakeRange(0, sanitized.length)];
    }

    NSString* result = sanitized;
    result = replaceRegex(result,
        @"file:///(?:Users|private|var|tmp|Volumes)/[^\\s\\]\\[(){}<>\\\"']+",
        @"<PATH>");
    result = replaceRegex(result,
        @"(?<![A-Za-z0-9_])/(?:Users|private|var|tmp|Volumes)/[^\\s\\]\\[(){}<>\\\"']+",
        @"<PATH>");
    result = replaceRegex(result,
        @"[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}",
        @"<UUID>");
    return result;
}

NSString* decodedUTF8String(NSData* data) {
    NSString* string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return string;
}

NSString* sanitizedLogTail(NSURL* root, NSURL* logURL, NSString* unavailable) {
    NSError* error = nil;
    NSFileHandle* handle = [NSFileHandle fileHandleForReadingFromURL:logURL error:&error];
    if (handle == nil) return unavailable;
    const unsigned long long length = [handle seekToEndOfFile];
    const unsigned long long offset = length > kMaximumSharedLogBytes
        ? length - kMaximumSharedLogBytes : 0;
    [handle seekToFileOffset:offset];
    NSData* data = [handle readDataOfLength:kMaximumSharedLogBytes];
    [handle closeFile];
    if (data.length == 0) return unavailable;
    NSString* log = decodedUTF8String(data);
    for (NSUInteger skip = 1; log == nil && skip < 4 && skip < data.length; ++skip) {
        log = decodedUTF8String(
            [data subdataWithRange:NSMakeRange(skip, data.length - skip)]);
    }
    if (log == nil) return @"The runtime log could not be decoded as UTF-8.";
    return sanitizedText(log, root);
}

void storeSanitizedLine(int descriptor, size_t& storedBytes,
                        const std::string& rootPath, const std::string& line) {
    @autoreleasepool {
        NSData* output = nil;
        if (line.size() > kMaximumStoredLineBytes) {
            static NSString* const omitted =
                @"[DinoPad] oversized runtime log line omitted\n";
            output = [omitted dataUsingEncoding:NSUTF8StringEncoding];
        } else {
            NSString* source = [[NSString alloc] initWithBytes:line.data()
                length:line.size() encoding:NSUTF8StringEncoding];
            if (source == nil) source = @"[DinoPad] undecodable runtime log line omitted\n";
            NSURL* root = [NSURL fileURLWithPath:
                [NSString stringWithUTF8String:rootPath.c_str()] isDirectory:YES];
            output = [sanitizedText(source, root) dataUsingEncoding:NSUTF8StringEncoding];
        }
        if (output.length == 0) return;
        if (storedBytes + output.length > kMaximumStoredLogBytes) {
            static constexpr char rotation[] =
                "[DinoPad] earlier sanitized runtime log text was rotated\n";
            ftruncate(descriptor, 0);
            lseek(descriptor, 0, SEEK_SET);
            writeAll(descriptor, rotation, sizeof(rotation) - 1);
            storedBytes = sizeof(rotation) - 1;
        }
        writeAll(descriptor, static_cast<const char*>(output.bytes), output.length);
        storedBytes += output.length;
    }
}

void createPrivateMarker(NSURL* marker) {
    const int descriptor = open(marker.fileSystemRepresentation,
                                O_WRONLY | O_CREAT | O_TRUNC, 0600);
    if (descriptor >= 0) close(descriptor);
}

NSString* yesNo(bool value) {
    return value ? @"yes" : @"no";
}

NSString* resolutionName() {
    switch (ultramodern::renderer::get_graphics_config().res_option) {
        case ultramodern::renderer::Resolution::Original: return @"1x";
        case ultramodern::renderer::Resolution::Original2x: return @"2x";
        default: return @"Automatic";
    }
}

NSString* aspectName() {
    return ultramodern::renderer::get_graphics_config().ar_option ==
        ultramodern::renderer::AspectRatio::Expand ? @"Fill Screen" : @"Original (4:3)";
}

NSString* frameRateName() {
    return ultramodern::renderer::get_graphics_config().rr_option ==
        ultramodern::renderer::RefreshRate::Display ? @"Display" : @"Original";
}

NSString* hudName() {
    switch (ultramodern::renderer::get_graphics_config().hr_option) {
        case ultramodern::renderer::HUDRatioMode::Original: return @"4:3";
        case ultramodern::renderer::HUDRatioMode::Full: return @"Fill";
        default: return @"Safe 16:9";
    }
}

NSString* saveRecoveryStatus() {
    const std::filesystem::path save = ultramodern::get_save_file_path();
    std::error_code error;
    const bool primary = !save.empty() && std::filesystem::exists(save, error);
    std::filesystem::path backup = save;
    backup += ".bak";
    error.clear();
    const bool recovery = !save.empty() && std::filesystem::exists(backup, error);
    if (primary && recovery) return @"primary and recovery backup present";
    if (primary) return @"primary present; recovery backup not present";
    return @"no profile save yet";
}

NSString* boundedDiagnosticReport(NSURL* root) {
    NSBundle* bundle = NSBundle.mainBundle;
    UIScreen* screen = UIScreen.mainScreen;
    CGRect bounds = screen.bounds;
    const bool restored = dino::config::get_session_profile() ==
        dino::config::SessionProfile::Restored;

    NSMutableString* report = [NSMutableString string];
    [report appendString:@"DinoPad diagnostics\n"];
    [report appendString:@"===================\n"];
    [report appendFormat:@"Generated: %@\n", NSDate.date];
    [report appendFormat:@"App version: %@ (%@)\n",
        [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"unknown",
        [bundle objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"unknown"];
    [report appendFormat:@"Bundle: %@\n", bundle.bundleIdentifier ?: @"unknown"];
    [report appendFormat:@"System: %@ %@\n", UIDevice.currentDevice.systemName,
        UIDevice.currentDevice.systemVersion];
    [report appendFormat:@"Device: %@ (%@)\n", UIDevice.currentDevice.model,
        UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad
            ? @"tablet" : @"phone"];
    [report appendFormat:@"Screen: %.0fx%.0f points @ %.2fx\n",
        bounds.size.width, bounds.size.height, screen.nativeScale];
    [report appendFormat:@"Profile: %@\n", restored ? @"Restored Adventure" : @"Prototype Mode"];
    [report appendFormat:@"Restoration: %@\n", restored
        ? @"bundled static data active; writable mods disabled"
        : @"disabled for archival Prototype Mode"];
    [report appendFormat:@"ROM validation: %@\n",
        dinopad_rom_validation_status() ? @"exact supported prototype verified" : @"not verified"];
    [report appendFormat:@"Save / recovery: %@\n", saveRecoveryStatus()];
    [report appendFormat:@"Controller: %@\n",
        dinopad_shell_controller_connected() ? @"connected" : @"not connected"];
    [report appendFormat:@"Touch controls: %@\n", yesNo(dinopad_shell_touch_enabled() != 0)];
    [report appendFormat:@"Touch opacity: %.0f%%\n", dinopad_shell_touch_opacity() * 100.0];
    [report appendFormat:@"Master volume: %d%%\n",
        std::clamp(dino::config::get_main_volume(), 0, 100)];
    [report appendFormat:@"Internal resolution: %@\n", resolutionName()];
    [report appendFormat:@"Aspect ratio: %@\n", aspectName()];
    [report appendFormat:@"Frame rate: %@\n", frameRateName()];
    [report appendFormat:@"HUD placement: %@\n", hudName()];
    const float scale = ultramodern::get_resolution_scale();
    const uint32_t refresh = ultramodern::get_display_refresh_rate();
    [report appendFormat:@"Renderer: Metal; %@\n", scale > 0.0F && refresh > 0
        ? [NSString stringWithFormat:@"effective %.2fx at %u Hz", scale, refresh]
        : @"effective state not available yet"];
    [report appendFormat:@"Diagnostics bounds: %lu KiB per shared log tail; %lu KiB report maximum\n",
        (unsigned long)(kMaximumSharedLogBytes / 1024u),
        (unsigned long)(kMaximumReportBytes / 1024u)];
    [report appendString:@"\nPrivacy: ROM/save contents and private absolute paths are excluded. "];
    [report appendString:@"Review this text before choosing a share destination.\n\n"];

    NSFileManager* files = NSFileManager.defaultManager;
    const BOOL previousMayBeUnclean = [files
        fileExistsAtPath:previousSessionUncleanMarkerURL(root).path];
    if (previousMayBeUnclean) {
        [report appendString:@"Previous-session runtime log (possible unclean exit; bounded tail)\n"];
        [report appendString:@"-----------------------------------------------------------------\n"];
        [report appendString:sanitizedLogTail(root, previousRuntimeLogURL(root),
            @"No previous-session runtime log was available.")];
        [report appendString:@"\n\n"];
    }
    [report appendString:@"Current-session sanitized runtime log (bounded tail)\n"];
    [report appendString:@"----------------------------------------------------\n"];
    [report appendString:sanitizedLogTail(root, runtimeLogURL(root),
        @"No current-session runtime log was available.")];
    if (!previousMayBeUnclean) {
        [report appendString:@"\n\nPrevious-session sanitized runtime log (bounded tail)\n"];
        [report appendString:@"-----------------------------------------------------\n"];
        [report appendString:sanitizedLogTail(root, previousRuntimeLogURL(root),
            @"No previous-session runtime log was available.")];
    }

    NSString* sanitized = sanitizedText(report, root);
    NSData* encoded = [sanitized dataUsingEncoding:NSUTF8StringEncoding];
    if (encoded.length <= kMaximumReportBytes) return sanitized;
    NSData* prefix = [encoded subdataWithRange:NSMakeRange(0, kMaximumReportBytes - 96)];
    NSString* bounded = decodedUTF8String(prefix);
    for (NSUInteger trim = 1; bounded == nil && trim < 4; ++trim) {
        bounded = decodedUTF8String([prefix subdataWithRange:
            NSMakeRange(0, prefix.length - trim)]);
    }
    return [(bounded ?: @"") stringByAppendingString:
        @"\n[DinoPad] report truncated at the 512 KiB privacy boundary\n"];
}

bool writePrivateText(NSString* text, NSURL* url, NSError** error) {
    if (![text writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:error]) {
        return false;
    }
    chmod(url.fileSystemRepresentation, 0600);
    [NSFileManager.defaultManager setAttributes:@{
        NSFileProtectionKey: NSFileProtectionCompleteUntilFirstUserAuthentication,
        NSFilePosixPermissions: @0600,
    } ofItemAtPath:url.path error:nil];
    return true;
}

#if DINOPAD_ENABLE_TEST_HARNESS
bool validateDiagnosticsSmoke(NSString* report, NSURL* root, NSURL* reportURL) {
    NSData* reportData = [report dataUsingEncoding:NSUTF8StringEncoding];
    NSArray<NSString*>* required = @[
        @"DinoPad diagnostics", @"Profile: Restored Adventure",
        @"Restoration: bundled static data active", @"ROM validation: exact supported",
        @"Save / recovery:", @"Controller:", @"Renderer: Metal",
        @"Diagnostics bounds:", @"<PATH>",
    ];
    for (NSString* marker in required) {
        if ([report rangeOfString:marker].location == NSNotFound) return false;
    }
    NSArray<NSString*>* forbidden = @[
        [@"/" stringByAppendingString:@"Users/diagnostic-owner"],
        @"/private/var/mobile/Containers/Data/Application/",
        @"file:///var/mobile/Library/Mobile%20Documents", @"/tmp/dinopad-private",
        @"/Volumes/Owner", @"11111111-2222-3333-4444-555555555555",
        root.path ?: @"", NSHomeDirectory() ?: @"",
    ];
    for (NSString* marker in forbidden) {
        if (marker.length > 0 && [report rangeOfString:marker
            options:NSCaseInsensitiveSearch].location != NSNotFound) return false;
    }
    NSDictionary* attributes = [NSFileManager.defaultManager
        attributesOfItemAtPath:reportURL.path error:nil];
    const NSUInteger mode = [attributes[NSFilePosixPermissions] unsignedIntegerValue] & 0777u;
    NSDictionary* logAttributes = [NSFileManager.defaultManager
        attributesOfItemAtPath:runtimeLogURL(root).path error:nil];
    NSData* storedLog = [NSData dataWithContentsOfURL:runtimeLogURL(root)];
    NSString* storedText = decodedUTF8String(storedLog) ?: @"";
    return reportData.length <= kMaximumReportBytes && mode == 0600u &&
        [logAttributes[NSFileSize] unsignedLongLongValue] <= kMaximumStoredLogBytes &&
        [storedText rangeOfString:[@"/" stringByAppendingString:@"Users/diagnostic-owner"]].location == NSNotFound &&
        [storedText rangeOfString:@"<PATH>"].location != NSNotFound;
}
#endif

} // namespace

extern "C" void dinopad_start_diagnostics_log(void) {
    if (g_diagnosticsStarted.exchange(true, std::memory_order_acq_rel)) return;
    NSURL* root = dataRootURL();
    if (root == nil) return;
    NSFileManager* files = NSFileManager.defaultManager;
    NSError* error = nil;
    NSURL* directory = diagnosticsDirectory(root);
    if (![files createDirectoryAtURL:directory withIntermediateDirectories:YES
        attributes:@{NSFileProtectionKey:
            NSFileProtectionCompleteUntilFirstUserAuthentication} error:&error]) {
        std::fprintf(stderr, "[DinoPad] diagnostics directory unavailable: %s\n",
            error.localizedDescription.UTF8String);
        return;
    }
    [directory setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];

    NSURL* latest = runtimeLogURL(root);
    NSURL* previous = previousRuntimeLogURL(root);
    NSURL* active = activeSessionMarkerURL(root);
    NSURL* unclean = previousSessionUncleanMarkerURL(root);
    const BOOL hadLatest = [files fileExistsAtPath:latest.path];
    const BOOL previousMayBeUnclean = hadLatest && [files fileExistsAtPath:active.path];
    [files removeItemAtURL:previous error:nil];
    if (hadLatest) [files moveItemAtURL:latest toURL:previous error:nil];
    [files removeItemAtURL:unclean error:nil];
    if (previousMayBeUnclean) createPrivateMarker(unclean);
    [files removeItemAtURL:active error:nil];
    createPrivateMarker(active);
#if DINOPAD_ENABLE_TEST_HARNESS
    [files removeItemAtURL:smokeEvidenceURL(root) error:nil];
#endif

    const int logDescriptor = open(latest.fileSystemRepresentation,
        O_WRONLY | O_CREAT | O_TRUNC, 0600);
    int pipeDescriptors[2] = {-1, -1};
    const int originalStderr = dup(STDERR_FILENO);
    if (logDescriptor < 0 || originalStderr < 0 || pipe(pipeDescriptors) != 0 ||
        dup2(pipeDescriptors[1], STDERR_FILENO) < 0) {
        if (logDescriptor >= 0) close(logDescriptor);
        if (originalStderr >= 0) close(originalStderr);
        if (pipeDescriptors[0] >= 0) close(pipeDescriptors[0]);
        if (pipeDescriptors[1] >= 0) close(pipeDescriptors[1]);
        std::fprintf(stderr, "[DinoPad] diagnostics log capture could not start\n");
        return;
    }
    close(pipeDescriptors[1]);
    setvbuf(stderr, nullptr, _IONBF, 0);
    const std::string rootPath = root.path.UTF8String;

    std::thread([readDescriptor = pipeDescriptors[0], originalStderr,
                 logDescriptor, rootPath] {
        size_t storedBytes = 0;
        std::string pending;
        char buffer[4096];
        for (;;) {
            const ssize_t count = read(readDescriptor, buffer, sizeof(buffer));
            if (count > 0) {
                writeAll(originalStderr, buffer, static_cast<size_t>(count));
                pending.append(buffer, static_cast<size_t>(count));
                size_t newline = 0;
                while ((newline = pending.find('\n')) != std::string::npos) {
                    storeSanitizedLine(logDescriptor, storedBytes, rootPath,
                                       pending.substr(0, newline + 1));
                    pending.erase(0, newline + 1);
                }
                if (pending.size() > kMaximumStoredLineBytes) {
                    storeSanitizedLine(logDescriptor, storedBytes, rootPath, pending);
                    pending.clear();
                }
            } else if (count < 0 && errno == EINTR) {
                continue;
            } else {
                if (!pending.empty()) {
                    storeSanitizedLine(logDescriptor, storedBytes, rootPath, pending);
                }
                break;
            }
        }
        close(readDescriptor);
        close(originalStderr);
        close(logDescriptor);
    }).detach();

    std::fprintf(stderr, "[DinoPad] private bounded sanitized diagnostics log started\n");
    installLifecycleObservers();
    g_appActive.store(UIApplication.sharedApplication.applicationState ==
        UIApplicationStateActive, std::memory_order_relaxed);
    logFlight("session", previousMayBeUnclean
        ? "started_previous_session_unclean" : "started_previous_session_clean");
    logSessionMetadata();
    startRuntimeWatchdog();
}

extern "C" void dinopad_finish_diagnostics_log(void) {
    NSURL* root = dataRootURL();
    if (root == nil) return;
    std::fprintf(stderr, "[DinoPad] clean process exit reached\n");
    [NSFileManager.defaultManager removeItemAtURL:activeSessionMarkerURL(root) error:nil];
}

extern "C" void dinopad_diagnostics_breadcrumb(const char* category,
                                                   const char* event) {
    logFlight(category, event);
}

extern "C" void dinopad_diagnostics_set_runtime_active(int active) {
    const bool isActive = active != 0;
    g_runtimeActive.store(isActive, std::memory_order_relaxed);
    g_stallReported.store(false, std::memory_order_relaxed);
    g_gameplayPolls.store(0, std::memory_order_relaxed);
    const uint64_t now = monotonicNanos();
    g_lastGameplayProgressNanos.store(isActive ? now : 0, std::memory_order_relaxed);
    g_lastHeartbeatLogNanos.store(isActive ? now : 0, std::memory_order_relaxed);
    if (isActive) {
        double cpuSeconds = 0.0;
        double residentMiB = 0.0;
        processUsage(cpuSeconds, residentMiB);
        std::lock_guard<std::mutex> lock(g_processSampleMutex);
        g_previousCPUSeconds = cpuSeconds;
        g_previousCPUSampleNanos = now;
    }
    logFlight("runtime", isActive ? "active" : "inactive");
}

extern "C" void dinopad_diagnostics_gameplay_poll(void) {
    if (!g_runtimeActive.load(std::memory_order_relaxed)) return;
    const uint64_t now = monotonicNanos();
    const uint64_t polls = g_gameplayPolls.fetch_add(1, std::memory_order_relaxed) + 1;
    g_lastGameplayProgressNanos.store(now, std::memory_order_relaxed);
    uint64_t lastLog = g_lastHeartbeatLogNanos.load(std::memory_order_relaxed);
    if (now - lastLog < kHeartbeatLogIntervalNanos ||
        !g_lastHeartbeatLogNanos.compare_exchange_strong(
            lastLog, now, std::memory_order_relaxed)) {
        return;
    }
    logProcessSample(now, polls);
}

extern "C" void dinopad_present_diagnostics_share(void* presenter_pointer,
                                                    void (^completion)(void)) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController* presenter = (__bridge UIViewController*)presenter_pointer;
        if (presenter == nil) {
            if (completion != nil) completion();
            return;
        }
        while (presenter.presentedViewController != nil) {
            presenter = presenter.presentedViewController;
        }
        NSURL* root = dataRootURL();
        NSURL* reportURL = [NSURL fileURLWithPath:[NSTemporaryDirectory()
            stringByAppendingPathComponent:@"DinoPad-Diagnostics.txt"]];
        NSString* report = boundedDiagnosticReport(root);
        NSError* error = nil;
        if (root == nil || !writePrivateText(report, reportURL, &error)) {
            UIAlertController* alert = [UIAlertController
                alertControllerWithTitle:@"Diagnostics Unavailable"
                                 message:error.localizedDescription ?: @"The report could not be created."
                          preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction* action) {
                    if (completion != nil) completion();
                }]];
            [presenter presentViewController:alert animated:YES completion:nil];
            return;
        }

#if DINOPAD_ENABLE_TEST_HARNESS
        const BOOL smoke =
            [NSProcessInfo.processInfo.environment[@"DINOPAD_RUN_DIAGNOSTICS_SMOKE"] boolValue];
        if (smoke) {
            if (!validateDiagnosticsSmoke(report, root, reportURL) ||
                !writePrivateText(report, smokeEvidenceURL(root), &error)) {
                std::fprintf(stderr, "[dinopad-diagnostics-test] FAIL: report bounds, redaction, fields, or permissions\n");
                std::fflush(stderr);
            } else {
                std::fprintf(stderr, "[dinopad-diagnostics-test] PASS: bounded sanitized report and private log verified\n");
                std::fflush(stderr);
            }
        }
#else
        const BOOL smoke = NO;
#endif

        __block BOOL finished = NO;
        void (^finishOnce)(void) = ^{
            if (finished) return;
            finished = YES;
            [NSFileManager.defaultManager removeItemAtURL:reportURL error:nil];
            if (smoke) {
                std::fprintf(stderr, "[dinopad-diagnostics-test] PASS: temporary share report cleaned\n");
                std::fflush(stderr);
            }
            if (completion != nil) completion();
        };

        UIActivityViewController* share = [[UIActivityViewController alloc]
            initWithActivityItems:@[reportURL] applicationActivities:nil];
        share.completionWithItemsHandler = ^(__unused UIActivityType activityType,
                                             __unused BOOL completed,
                                             __unused NSArray* returnedItems,
                                             __unused NSError* activityError) {
            finishOnce();
        };
        share.modalPresentationStyle = UIModalPresentationPopover;
        UIPopoverPresentationController* popover = share.popoverPresentationController;
        if (popover != nil) {
            popover.sourceView = presenter.view;
            popover.sourceRect = CGRectMake(CGRectGetMidX(presenter.view.bounds),
                                            CGRectGetMidY(presenter.view.bounds), 1.0, 1.0);
            popover.permittedArrowDirections = 0;
        }
        [presenter presentViewController:share animated:YES completion:^{
            if (!smoke) return;
            std::fprintf(stderr, "[dinopad-diagnostics-test] SHARE PRESENTED\n");
            std::fflush(stderr);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [share dismissViewControllerAnimated:YES completion:finishOnce];
            });
        }];
    });
}
