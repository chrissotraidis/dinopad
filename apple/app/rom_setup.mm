// rom_setup.mm - DinoPad-owned UIKit Files ROM import (Goal 27a).
// Normalizes .z64/.v64/.n64 to big-endian and validates the exact December
// 2000 Dinosaur Planet prototype fingerprint before private storage.

#import "rom_setup.h"
#import "test_harness.h"

#import <CommonCrypto/CommonDigest.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#include <cstring>
#include <cstdio>

namespace {

NSString* const kSupportedROMMD5 = @"49f7bb346ade39d1915c22e090ffd748";
NSString* const kROMErrorDomain = @"com.chrissotraidis.dinopad.rom-import";
constexpr NSUInteger kExpectedROMSize = 64u * 1024u * 1024u;

enum class ROMError : NSInteger {
    Read = 1,
    Format,
    Fingerprint,
    Write,
};

NSURL* applicationSupportRoot(NSError** error) {
    NSFileManager* files = NSFileManager.defaultManager;
    NSURL* support = [[files URLsForDirectory:NSApplicationSupportDirectory
                                     inDomains:NSUserDomainMask] firstObject];
    NSURL* root = [support URLByAppendingPathComponent:@"DinoPad" isDirectory:YES];
    if (![files createDirectoryAtURL:root
         withIntermediateDirectories:YES
                          attributes:@{NSFileProtectionKey:
                                           NSFileProtectionCompleteUntilFirstUserAuthentication}
                               error:error]) {
        return nil;
    }
    return root;
}

NSError* romError(ROMError code, NSString* description) {
    return [NSError errorWithDomain:kROMErrorDomain
                               code:static_cast<NSInteger>(code)
                           userInfo:@{NSLocalizedDescriptionKey: description}];
}

NSString* md5ForData(NSData* data) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    unsigned char digest[CC_MD5_DIGEST_LENGTH] = {};
    CC_MD5(data.bytes, static_cast<CC_LONG>(data.length), digest);
#pragma clang diagnostic pop
    NSMutableString* result = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (unsigned char byte : digest) [result appendFormat:@"%02x", byte];
    return result;
}

NSData* normalizedROMData(NSData* source, NSError** error) {
    if (source.length != kExpectedROMSize) {
        if (error) {
            *error = romError(ROMError::Format,
                @"This file is not 64 MiB. Choose the unmodified December 2000 Dinosaur Planet prototype ROM.");
        }
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
        case 0x80371240u: // .z64 big-endian
            memcpy(output, input, source.length);
            break;
        case 0x37804012u: // .v64 byte-swapped
            for (NSUInteger index = 0; index + 1 < source.length; index += 2) {
                output[index] = input[index + 1];
                output[index + 1] = input[index];
            }
            break;
        case 0x40123780u: // .n64 little-endian
            for (NSUInteger index = 0; index + 3 < source.length; index += 4) {
                output[index] = input[index + 3];
                output[index + 1] = input[index + 2];
                output[index + 2] = input[index + 1];
                output[index + 3] = input[index];
            }
            break;
        default:
            if (error) {
                *error = romError(ROMError::Format,
                    @"This is not a recognized .z64, .v64, or .n64 Dinosaur Planet ROM.");
            }
            return nil;
    }

    if (![[md5ForData(normalized) lowercaseString] isEqualToString:kSupportedROMMD5]) {
        if (error) {
            *error = romError(ROMError::Fingerprint,
                @"This ROM does not match the supported December 2000 Dinosaur Planet prototype. DinoPad supports the exact unmodified prototype only.");
        }
        return nil;
    }
    return normalized;
}

BOOL validateInstalledROM(NSURL* root) {
    NSURL* target = [root URLByAppendingPathComponent:@"dino.z64"];
    NSDictionary* attributes = [NSFileManager.defaultManager
        attributesOfItemAtPath:target.path error:nil];
    if ([attributes[NSFileSize] unsignedIntegerValue] != kExpectedROMSize) return NO;
    NSData* data = [NSData dataWithContentsOfURL:target
                                        options:NSDataReadingMappedIfSafe
                                          error:nil];
    return data != nil && [[md5ForData(data) lowercaseString] isEqualToString:kSupportedROMMD5];
}

BOOL installROMFromURL(NSURL* sourceURL, NSError** error) {
    BOOL scoped = [sourceURL startAccessingSecurityScopedResource];
    NSData* source = [NSData dataWithContentsOfURL:sourceURL
                                           options:NSDataReadingMappedIfSafe
                                             error:error];
    if (scoped) [sourceURL stopAccessingSecurityScopedResource];
    if (source == nil) {
        if (error && *error == nil) {
            *error = romError(ROMError::Read,
                @"DinoPad could not read that file. Check Files access and try again.");
        }
        return NO;
    }

    NSData* normalized = normalizedROMData(source, error);
    if (normalized == nil) return NO;

    NSURL* root = applicationSupportRoot(error);
    if (root == nil) return NO;
    NSURL* target = [root URLByAppendingPathComponent:@"dino.z64"];
    if (![normalized writeToURL:target options:NSDataWritingAtomic error:error]) {
        if (error && *error == nil) {
            *error = romError(ROMError::Write,
                              @"DinoPad could not store the ROM. Check available storage and try again.");
        }
        return NO;
    }

    [NSFileManager.defaultManager setAttributes:@{
        NSFileProtectionKey: NSFileProtectionCompleteUntilFirstUserAuthentication,
    } ofItemAtPath:target.path error:nil];
    [target setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];

    std::fprintf(stderr, "[DinoPad] ROM import accepted: December 2000 prototype\n");
    std::fflush(stderr);
    return YES;
}

#if DINOPAD_ENABLE_TEST_HARNESS
BOOL runROMImportSmokeIfRequested(NSURL* root) {
    NSDictionary<NSString*, NSString*>* environment = NSProcessInfo.processInfo.environment;
    if (![environment[@"DINOPAD_RUN_ROM_IMPORT_SMOKE"] boolValue]) return YES;

    NSString* shortPath = environment[@"DINOPAD_ROM_IMPORT_SHORT"];
    NSString* invalidPath = environment[@"DINOPAD_ROM_IMPORT_INVALID"];
    NSString* z64Path = environment[@"DINOPAD_ROM_IMPORT_Z64"];
    NSString* v64Path = environment[@"DINOPAD_ROM_IMPORT_V64"];
    NSString* n64Path = environment[@"DINOPAD_ROM_IMPORT_N64"];
    if (shortPath.length == 0 || invalidPath.length == 0 || z64Path.length == 0 ||
        v64Path.length == 0 || n64Path.length == 0) {
        std::fprintf(stderr, "[dinopad-rom-test] FAIL: fixture paths missing\n");
        std::fflush(stderr);
        return NO;
    }

    NSFileManager* files = NSFileManager.defaultManager;
    NSURL* target = [root URLByAppendingPathComponent:@"dino.z64"];
    [files removeItemAtURL:target error:nil];

    NSError* error = nil;
    BOOL accepted = installROMFromURL([NSURL fileURLWithPath:shortPath], &error);
    if (accepted || error.code != static_cast<NSInteger>(ROMError::Format) ||
        [files fileExistsAtPath:target.path]) {
        std::fprintf(stderr, "[dinopad-rom-test] FAIL: wrong-size ROM rejection\n");
        std::fflush(stderr);
        return NO;
    }
    std::fprintf(stderr, "[dinopad-rom-test] PASS: wrong-size ROM rejected without staging\n");

    error = nil;
    accepted = installROMFromURL([NSURL fileURLWithPath:invalidPath], &error);
    if (accepted || error.code != static_cast<NSInteger>(ROMError::Fingerprint) ||
        [files fileExistsAtPath:target.path]) {
        std::fprintf(stderr, "[dinopad-rom-test] FAIL: modified ROM rejection\n");
        std::fflush(stderr);
        return NO;
    }
    std::fprintf(stderr, "[dinopad-rom-test] PASS: modified ROM rejected without staging\n");

    BOOL (^verifyByteOrder)(NSString*, const char*) = ^BOOL(NSString* path, const char* label) {
        NSError* importError = nil;
        [files removeItemAtURL:target error:nil];
        if (!installROMFromURL([NSURL fileURLWithPath:path], &importError) ||
            !validateInstalledROM(root)) {
            std::fprintf(stderr, "[dinopad-rom-test] FAIL: %s import/validation\n", label);
            std::fflush(stderr);
            return NO;
        }
        NSData* imported = [NSData dataWithContentsOfURL:target
                                                 options:NSDataReadingMappedIfSafe error:nil];
        const uint8_t* importedBytes = static_cast<const uint8_t*>(imported.bytes);
        const BOOL normalized = imported.length == kExpectedROMSize &&
            importedBytes[0] == 0x80 && importedBytes[1] == 0x37 &&
            importedBytes[2] == 0x12 && importedBytes[3] == 0x40 &&
            [[md5ForData(imported) lowercaseString] isEqualToString:kSupportedROMMD5];
        if (!normalized) {
            std::fprintf(stderr, "[dinopad-rom-test] FAIL: %s normalization\n", label);
            std::fflush(stderr);
            return NO;
        }
        std::fprintf(stderr, "[dinopad-rom-test] PASS: %s normalized to exact supported z64\n", label);
        return YES;
    };

    if (!verifyByteOrder(z64Path, "z64") || !verifyByteOrder(v64Path, "v64") ||
        !verifyByteOrder(n64Path, "n64")) return NO;

    NSData* stored = [NSData dataWithContentsOfURL:target options:NSDataReadingMappedIfSafe error:nil];
    const uint8_t* bytes = static_cast<const uint8_t*>(stored.bytes);
    NSNumber* excluded = nil;
    [target getResourceValue:&excluded forKey:NSURLIsExcludedFromBackupKey error:nil];
    const BOOL normalizedMagic = stored.length == kExpectedROMSize &&
        bytes[0] == 0x80 && bytes[1] == 0x37 && bytes[2] == 0x12 && bytes[3] == 0x40;
    if (!normalizedMagic || !excluded.boolValue ||
        ![[md5ForData(stored) lowercaseString] isEqualToString:kSupportedROMMD5]) {
        std::fprintf(stderr, "[dinopad-rom-test] FAIL: stored ROM metadata/fingerprint\n");
        std::fflush(stderr);
        return NO;
    }

    std::fprintf(stderr, "[dinopad-rom-test] PASS: exact MD5; private atomic storage; excluded from backup\n");
    std::fprintf(stderr, "[dinopad-rom-test] ALL ROM IMPORT TESTS PASSED\n");
    std::fflush(stderr);
    return YES;
}
#endif

UIViewController* topViewController(UIViewController* controller) {
    while (controller.presentedViewController != nil) {
        controller = controller.presentedViewController;
    }
    return controller;
}

UIWindow* applicationKeyWindow() {
    UIWindow* fallback = nil;
    for (UIScene* scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow* window in ((UIWindowScene*)scene).windows) {
            if (fallback == nil) fallback = window;
            if (window.isKeyWindow) return window;
        }
    }
    return fallback;
}

void styleButton(UIButton* button) {
    UIButtonConfiguration* configuration = [UIButtonConfiguration filledButtonConfiguration];
    configuration.baseBackgroundColor = [UIColor colorWithRed:0.11 green:0.46 blue:0.22 alpha:1.0];
    configuration.baseForegroundColor = UIColor.whiteColor;
    configuration.cornerStyle = UIButtonConfigurationCornerStyleMedium;
    configuration.contentInsets = NSDirectionalEdgeInsetsMake(14.0, 24.0, 14.0, 24.0);
    button.configuration = configuration;
    button.titleLabel.font = [UIFont boldSystemFontOfSize:18.0];
}

} // namespace

// MARK: - Setup Controller (first-run / missing ROM)

@interface DinoPadROMSetupController : UIViewController <UIDocumentPickerDelegate>
@property(nonatomic, assign) BOOL imported;
@property(nonatomic, assign) BOOL smokePickerPresented;
@property(nonatomic, strong) UILabel* statusLabel;
@end

@implementation DinoPadROMSetupController

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationLandscapeRight;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.027 green:0.110 blue:0.141 alpha:1.0];

    UILabel* title = [[UILabel alloc] init];
    title.text = @"DinoPad";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont boldSystemFontOfSize:40.0];
    title.textAlignment = NSTextAlignmentCenter;

    UILabel* body = [[UILabel alloc] init];
    body.text = @"Choose your legally obtained December 2000 Dinosaur Planet prototype ROM.\n\nDinoPad accepts .z64, .v64, and .n64 files, verifies the exact supported prototype, and keeps the normalized copy private on this device. No ROM is included with the app.";
    body.textColor = [UIColor colorWithWhite:0.88 alpha:1.0];
    body.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightRegular];
    body.textAlignment = NSTextAlignmentCenter;
    body.numberOfLines = 0;

    UIButton* choose = [UIButton buttonWithType:UIButtonTypeSystem];
    [choose setTitle:@"Choose ROM" forState:UIControlStateNormal];
    [choose setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    choose.accessibilityIdentifier = @"dinopad.rom.choose";
    styleButton(choose);
    [choose addTarget:self action:@selector(chooseROM) forControlEvents:UIControlEventTouchUpInside];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.text = @"Supported: December 2000 Dinosaur Planet prototype";
    self.statusLabel.textColor = [UIColor colorWithWhite:0.62 alpha:1.0];
    self.statusLabel.font = [UIFont systemFontOfSize:14.0];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 0;

    UIStackView* stack = [[UIStackView alloc] initWithArrangedSubviews:@[
        title, body, choose, self.statusLabel,
    ]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 20.0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.centerXAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerYAnchor],
        [stack.widthAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.widthAnchor multiplier:0.78],
        [body.widthAnchor constraintLessThanOrEqualToConstant:650.0],
    ]];
}

- (void)chooseROM {
    UIDocumentPickerViewController* picker = [[UIDocumentPickerViewController alloc]
        initForOpeningContentTypes:@[UTTypeData] asCopy:YES];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    picker.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:picker animated:YES completion:nil];
#if DINOPAD_ENABLE_TEST_HARNESS
    std::fprintf(stderr, "[dinopad-rom-test] Files picker presented\n");
#else
    std::fprintf(stderr, "[DinoPad] Files picker presented\n");
#endif
    std::fflush(stderr);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
#if DINOPAD_ENABLE_TEST_HARNESS
    NSString* smoke = NSProcessInfo.processInfo.environment[@"DINOPAD_SHOW_ROM_PICKER_SMOKE"];
    if (!self.smokePickerPresented && smoke.boolValue) {
        self.smokePickerPresented = YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ [self chooseROM]; });
    }
#endif
}

- (void)documentPicker:(UIDocumentPickerViewController*)controller
didPickDocumentsAtURLs:(NSArray<NSURL*>*)urls {
    NSError* error = nil;
    if (urls.count == 1 && installROMFromURL(urls.firstObject, &error)) {
        self.statusLabel.textColor = [UIColor colorWithRed:0.38 green:0.91 blue:0.57 alpha:1.0];
        self.statusLabel.text = @"Verified. Starting Dinosaur Planet…";
        self.imported = YES;
        return;
    }
    self.statusLabel.textColor = [UIColor colorWithRed:1.0 green:0.48 blue:0.48 alpha:1.0];
    self.statusLabel.text = error.localizedDescription ?: @"DinoPad could not import that file.";
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController*)controller {
    self.statusLabel.textColor = [UIColor colorWithWhite:0.72 alpha:1.0];
    self.statusLabel.text = @"No ROM selected. Choose your legal copy whenever you're ready.";
}

@end

// MARK: - C Interface

bool dinopad_prepare_rom_setup(void) {
    @autoreleasepool {
        NSError* error = nil;
        NSURL* root = applicationSupportRoot(&error);
        if (root == nil) {
            std::fprintf(stderr, "[DinoPad] setup storage unavailable: %s\n",
                         error.localizedDescription.UTF8String);
            return false;
        }
#if DINOPAD_ENABLE_TEST_HARNESS
        if (!runROMImportSmokeIfRequested(root)) return false;
#endif
        if (validateInstalledROM(root)) return true;

        DinoPadROMSetupController* controller = [[DinoPadROMSetupController alloc] init];
        UIWindow* window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        window.windowLevel = UIWindowLevelNormal + 2.0;
        window.rootViewController = controller;
        [window makeKeyAndVisible];
#if DINOPAD_ENABLE_TEST_HARNESS
        std::fprintf(stderr, "[dinopad-rom-test] First-run setup presented\n");
#else
        std::fprintf(stderr, "[DinoPad] First-run setup presented\n");
#endif
        std::fflush(stderr);

        while (!controller.imported) {
            @autoreleasepool {
                [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode
                                        beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
            }
        }
        window.hidden = YES;
        return true;
    }
}

bool dinopad_rom_validation_status(void) {
    @autoreleasepool {
        NSError* error = nil;
        NSURL* root = applicationSupportRoot(&error);
        return root != nil && validateInstalledROM(root);
    }
}

// MARK: - ROM Manager (replace / remove from in-game menu)

@interface DinoPadROMManager : NSObject <UIDocumentPickerDelegate>
@property(nonatomic, assign) UIViewController* presenter;
+ (instancetype)shared;
- (void)presentFrom:(UIViewController*)presenter;
@end

@implementation DinoPadROMManager

+ (instancetype)shared {
    static DinoPadROMManager* manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ manager = [[DinoPadROMManager alloc] init]; });
    return manager;
}

- (void)finish {
    [NSNotificationCenter.defaultCenter
        postNotificationName:@"DinoPadROMManagerDidDismissNotification" object:nil];
}

- (void)showMessage:(NSString*)title body:(NSString*)body {
    UIViewController* presenter = topViewController(self.presenter);
    if (presenter == nil) return;
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:body
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK"
        style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction* action) {
            [self finish];
        }]];
    [presenter presentViewController:alert animated:YES completion:nil];
}

- (void)presentPicker {
    UIViewController* presenter = topViewController(self.presenter);
    if (presenter == nil) return;
    UIDocumentPickerViewController* picker = [[UIDocumentPickerViewController alloc]
        initForOpeningContentTypes:@[UTTypeData] asCopy:YES];
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [presenter presentViewController:picker animated:YES completion:nil];
}

- (void)removeROM {
    NSError* error = nil;
    NSURL* root = applicationSupportRoot(&error);
    if (root != nil) {
        NSURL* rom = [root URLByAppendingPathComponent:@"dino.z64"];
        NSFileManager* files = NSFileManager.defaultManager;
        if ([files fileExistsAtPath:rom.path] && ![files removeItemAtURL:rom error:&error]) {
            [self showMessage:@"Could Not Remove ROM" body:error.localizedDescription];
            return;
        }
    }
    [self showMessage:@"ROM Removed"
                 body:@"The private ROM copy was removed. DinoPad will ask for a ROM the next time it launches."];
}

- (void)presentFrom:(UIViewController*)presenter {
    self.presenter = topViewController(presenter);
    if (self.presenter == nil) {
        [self finish];
        return;
    }
    UIAlertController* menu = [UIAlertController
        alertControllerWithTitle:@"Game ROM"
                         message:@"DinoPad never bundles or downloads game data."
                  preferredStyle:UIAlertControllerStyleActionSheet];
    [menu addAction:[UIAlertAction actionWithTitle:@"Replace ROM"
                                             style:UIAlertActionStyleDefault
                                           handler:^(__unused UIAlertAction* action) {
        [self presentPicker];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Remove ROM"
                                             style:UIAlertActionStyleDestructive
                                           handler:^(__unused UIAlertAction* action) {
        [self removeROM];
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                             style:UIAlertActionStyleCancel
                                           handler:^(__unused UIAlertAction* action) {
        [self finish];
    }]];
    menu.popoverPresentationController.sourceView = presenter.view;
    menu.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(presenter.view.bounds),
                                                               CGRectGetMidY(presenter.view.bounds), 0, 0);
    [presenter presentViewController:menu animated:YES completion:nil];
    std::fprintf(stderr, "[dinopad-rom-test] ROM manager presented with Replace/Remove actions\n");
    std::fflush(stderr);
}

- (void)documentPicker:(UIDocumentPickerViewController*)controller
didPickDocumentsAtURLs:(NSArray<NSURL*>*)urls {
    NSError* error = nil;
    if (urls.count == 1 && installROMFromURL(urls.firstObject, &error)) {
        [self showMessage:@"ROM Replaced"
                     body:@"The new December 2000 prototype ROM was verified and stored privately."];
        return;
    }
    [self showMessage:@"Import Failed"
                 body:error.localizedDescription ?: @"DinoPad could not import that file."];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController*)controller {
    [self finish];
}

@end

void dinopad_present_rom_manager(void* presenter_pointer) {
    __block UIViewController* presenter = (__bridge UIViewController*)presenter_pointer;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (presenter == nil) {
            presenter = applicationKeyWindow().rootViewController;
        }
        [[DinoPadROMManager shared] presentFrom:presenter];
    });
}
