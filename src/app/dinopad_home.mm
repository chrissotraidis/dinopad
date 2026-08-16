#import <AppKit/AppKit.h>
#import <CommonCrypto/CommonDigest.h>
#import <Foundation/Foundation.h>

#include <cstdio>
#include <cstdlib>

namespace {

constexpr NSUInteger kExpectedROMSize = 64u * 1024u * 1024u;
NSString* const kExpectedMD5 = @"49f7bb346ade39d1915c22e090ffd748";

NSURL* dataRoot(NSError** error) {
    NSString* override = NSProcessInfo.processInfo.environment[@"DINOPAD_DATA_ROOT"];
    NSURL* root = nil;
    if (override.length > 0) {
        root = [NSURL fileURLWithPath:override isDirectory:YES];
    } else {
        NSURL* support = [[NSFileManager.defaultManager
            URLsForDirectory:NSApplicationSupportDirectory
                   inDomains:NSUserDomainMask] firstObject];
        root = [support URLByAppendingPathComponent:@"DinoPad" isDirectory:YES];
    }
    if (![NSFileManager.defaultManager createDirectoryAtURL:root
                                withIntermediateDirectories:YES
                                                 attributes:nil
                                                      error:error]) {
        return nil;
    }
    return root;
}

NSString* md5(NSData* data) {
    unsigned char digest[CC_MD5_DIGEST_LENGTH] = {};
    CC_MD5(data.bytes, static_cast<CC_LONG>(data.length), digest);
    NSMutableString* text = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (unsigned char byte : digest) [text appendFormat:@"%02x", byte];
    return text;
}

NSData* normalizeROM(NSData* source, NSString** problem) {
    if (source.length != kExpectedROMSize) {
        *problem = @"This file is not 64 MiB. Choose the unmodified December 2000 Dinosaur Planet prototype.";
        return nil;
    }
    const uint8_t* input = static_cast<const uint8_t*>(source.bytes);
    const uint32_t magic = (static_cast<uint32_t>(input[0]) << 24) |
                           (static_cast<uint32_t>(input[1]) << 16) |
                           (static_cast<uint32_t>(input[2]) << 8) |
                           static_cast<uint32_t>(input[3]);
    NSMutableData* normalized = [NSMutableData dataWithLength:source.length];
    uint8_t* output = static_cast<uint8_t*>(normalized.mutableBytes);
    switch (magic) {
        case 0x80371240u:
            memcpy(output, input, source.length);
            break;
        case 0x37804012u:
            for (NSUInteger index = 0; index < source.length; index += 2) {
                output[index] = input[index + 1];
                output[index + 1] = input[index];
            }
            break;
        case 0x40123780u:
            for (NSUInteger index = 0; index < source.length; index += 4) {
                output[index] = input[index + 3];
                output[index + 1] = input[index + 2];
                output[index + 2] = input[index + 1];
                output[index + 3] = input[index];
            }
            break;
        default:
            *problem = @"This is not a recognized .z64, .v64, or .n64 ROM.";
            return nil;
    }
    if (![[md5(normalized) lowercaseString] isEqualToString:kExpectedMD5]) {
        *problem = @"This is a different game, revision, or modified ROM. DinoPad supports only the December 2000 prototype.";
        return nil;
    }
    return normalized;
}

BOOL installedROMIsValid(NSURL* root) {
    NSURL* target = [root URLByAppendingPathComponent:@"dino.z64"];
    NSDictionary* attributes = [NSFileManager.defaultManager
        attributesOfItemAtPath:target.path error:nil];
    if ([attributes[NSFileSize] unsignedIntegerValue] != kExpectedROMSize) return NO;
    NSData* data = [NSData dataWithContentsOfURL:target
                                        options:NSDataReadingMappedIfSafe
                                          error:nil];
    return data != nil && [[md5(data) lowercaseString] isEqualToString:kExpectedMD5];
}

void showError(NSString* title, NSString* message) {
    NSAlert* alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleCritical;
    alert.messageText = title;
    alert.informativeText = message ?: @"An unknown error occurred.";
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

BOOL chooseAndInstallROM(NSURL* root) {
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    panel.title = @"Choose Dinosaur Planet ROM";
    panel.message = @"DinoPad accepts .z64, .v64, and .n64 files and verifies the exact December 2000 prototype.";
    panel.allowsMultipleSelection = NO;
    panel.canChooseDirectories = NO;
    panel.canChooseFiles = YES;
    if ([panel runModal] != NSModalResponseOK) return NO;

    NSError* error = nil;
    NSData* source = [NSData dataWithContentsOfURL:panel.URL
                                           options:NSDataReadingMappedIfSafe
                                             error:&error];
    if (source == nil) {
        showError(@"ROM Could Not Be Read", error.localizedDescription);
        return NO;
    }
    NSString* problem = nil;
    NSData* normalized = normalizeROM(source, &problem);
    if (normalized == nil) {
        showError(@"Unsupported ROM", problem);
        return NO;
    }
    NSURL* target = [root URLByAppendingPathComponent:@"dino.z64"];
    if (![normalized writeToURL:target options:NSDataWritingAtomic error:&error]) {
        showError(@"ROM Could Not Be Stored", error.localizedDescription);
        return NO;
    }
    [target setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
    std::fprintf(stderr, "DinoPad ROM import accepted (December 2000 prototype)\n");
    return YES;
}

BOOL ensureROM(NSURL* root) {
    while (!installedROMIsValid(root)) {
        NSAlert* setup = [[NSAlert alloc] init];
        setup.messageText = @"Set Up DinoPad";
        setup.informativeText = @"Choose your legally obtained December 2000 Dinosaur Planet prototype ROM. DinoPad verifies it locally and keeps a normalized private copy. No ROM is included or downloaded.";
        [setup addButtonWithTitle:@"Choose ROM…"];
        [setup addButtonWithTitle:@"Quit"];
        if ([setup runModal] != NSAlertFirstButtonReturn) return NO;
        chooseAndInstallROM(root);
    }
    return YES;
}

}  // namespace

extern "C" int dinopad_macos_prepare_home(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        [NSApp finishLaunching];
        [NSApp activateIgnoringOtherApps:YES];

        NSError* error = nil;
        NSURL* root = dataRoot(&error);
        if (root == nil) {
            showError(@"DinoPad Storage Unavailable", error.localizedDescription);
            return -1;
        }
        if (!ensureROM(root)) return -1;

        for (;;) {
            NSAlert* home = [[NSAlert alloc] init];
            home.messageText = @"DinoPad";
            home.informativeText = @"Rare’s unreleased N64 adventure, restored and running natively on Apple Silicon.\n\nRestored Adventure is recommended. Prototype Mode preserves the incomplete base prototype without restoration fixes.";
            [home addButtonWithTitle:@"Restored Adventure"];
            [home addButtonWithTitle:@"Prototype Mode"];
            [home addButtonWithTitle:@"Replace ROM…"];
            NSModalResponse response = [home runModal];
            if (response == NSAlertFirstButtonReturn) return 0;
            if (response == NSAlertSecondButtonReturn) {
                NSAlert* warning = [[NSAlert alloc] init];
                warning.alertStyle = NSAlertStyleWarning;
                warning.messageText = @"Start Prototype Mode?";
                warning.informativeText = @"This archival mode disables DinoMod restoration. The surviving prototype is incomplete and may be progression-blocked. Its saves and settings are kept separate.";
                [warning addButtonWithTitle:@"Start Prototype Mode"];
                [warning addButtonWithTitle:@"Cancel"];
                if ([warning runModal] == NSAlertFirstButtonReturn) return 1;
                continue;
            }
            chooseAndInstallROM(root);
        }
    }
}
