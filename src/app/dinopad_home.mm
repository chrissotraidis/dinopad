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

NSColor* macColor(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha = 1.0) {
    return [NSColor colorWithSRGBRed:red green:green blue:blue alpha:alpha];
}

NSFont* macThemedFont(NSString* name, CGFloat size, NSFontWeight fallbackWeight) {
    return [NSFont fontWithName:name size:size] ?: [NSFont systemFontOfSize:size weight:fallbackWeight];
}

NSTextField* macLabel(NSString* text, NSFont* font, NSColor* textColor) {
    NSTextField* label = [NSTextField labelWithString:text];
    label.font = font;
    label.textColor = textColor;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    label.maximumNumberOfLines = 0;
    return label;
}

@interface DinoPadMacBackgroundView : NSView
@end

@implementation DinoPadMacBackgroundView

- (void)drawRect:(NSRect)dirtyRect {
    NSGradient* gradient = [[NSGradient alloc]
        initWithStartingColor:macColor(0.010, 0.055, 0.075)
                     endingColor:macColor(0.022, 0.185, 0.170)];
    [gradient drawInRect:self.bounds angle:-35.0];
}

@end

@interface DinoPadMacHomeController : NSWindowController <NSWindowDelegate>
@property(nonatomic, assign) NSInteger selection;
@end

@implementation DinoPadMacHomeController

- (instancetype)init {
    NSWindow* window = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 1000, 620)
                  styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                             NSWindowStyleMaskFullSizeContentView)
                    backing:NSBackingStoreBuffered
                      defer:NO];
    self = [super initWithWindow:window];
    if (self == nil) return nil;

    self.selection = -1;
    window.delegate = self;
    window.title = @"DinoPad";
    window.titleVisibility = NSWindowTitleHidden;
    window.titlebarAppearsTransparent = YES;
    window.movableByWindowBackground = YES;
    window.backgroundColor = macColor(0.010, 0.055, 0.075);
    window.minSize = NSMakeSize(760, 520);

    DinoPadMacBackgroundView* background = [[DinoPadMacBackgroundView alloc]
        initWithFrame:window.contentView.bounds];
    background.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    window.contentView = background;

    NSURL* artURL = [NSBundle.mainBundle URLForResource:@"dinosaur-jungle-v1"
                                           withExtension:@"png"];
    if (artURL != nil) {
        NSImageView* art = [[NSImageView alloc] initWithFrame:NSZeroRect];
        art.image = [[NSImage alloc] initWithContentsOfURL:artURL];
        art.imageScaling = NSImageScaleProportionallyUpOrDown;
        art.alphaValue = 0.62;
        art.translatesAutoresizingMaskIntoConstraints = NO;
        [background addSubview:art];
        [NSLayoutConstraint activateConstraints:@[
            [art.trailingAnchor constraintEqualToAnchor:background.trailingAnchor constant:-10.0],
            [art.bottomAnchor constraintEqualToAnchor:background.bottomAnchor],
            [art.widthAnchor constraintEqualToConstant:760.0],
        ]];
    }

    NSTextField* eyebrow = macLabel(@"DINOPAD PRESENTS",
        macThemedFont(@"AvenirNextCondensed-DemiBold", 16.0, NSFontWeightBold),
        macColor(0.72, 0.88, 0.52));
    NSTextField* title = macLabel(@"DinoPad",
        macThemedFont(@"Baskerville-Bold", 70.0, NSFontWeightHeavy), NSColor.whiteColor);
    NSTextField* subtitle = macLabel(@"Two ways to explore a lost dinosaur world.",
        macThemedFont(@"Avenir Next", 21.0, NSFontWeightMedium),
        [NSColor colorWithWhite:1.0 alpha:0.86]);
    NSTextField* select = macLabel(@"SELECT A PATH",
        macThemedFont(@"AvenirNextCondensed-DemiBold", 16.0, NSFontWeightBold),
        macColor(0.72, 0.88, 0.52));

    NSButton* restored = [self modeButton:@"Restored Adventure"
                                  subtitle:@"Recommended"
                                   symbol:@"leaf.fill"
                                  primary:YES
                                   action:@selector(selectRestored:)];
    NSButton* prototype = [self modeButton:@"Prototype Mode"
                                   subtitle:@"Original build"
                                    symbol:@"archivebox.fill"
                                   primary:NO
                                    action:@selector(selectPrototype:)];
    NSButton* replace = [NSButton buttonWithTitle:@"Replace ROM…"
                                            target:self
                                            action:@selector(replaceROM:)];
    replace.bezelStyle = NSBezelStyleTexturedRounded;
    replace.contentTintColor = [NSColor colorWithWhite:1.0 alpha:0.84];
    replace.font = macThemedFont(@"AvenirNext-Medium", 15.0, NSFontWeightMedium);

    NSStackView* stack = [NSStackView stackViewWithViews:@[
        eyebrow, title, subtitle, select, restored, prototype, replace,
    ]];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = 14.0;
    [stack setCustomSpacing:8.0 afterView:eyebrow];
    [stack setCustomSpacing:14.0 afterView:title];
    [stack setCustomSpacing:34.0 afterView:subtitle];
    [stack setCustomSpacing:14.0 afterView:select];
    [stack setCustomSpacing:16.0 afterView:prototype];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [background addSubview:stack];

    for (NSView* card in @[restored, prototype]) {
        [card.widthAnchor constraintEqualToConstant:510.0].active = YES;
        [card.heightAnchor constraintEqualToConstant:94.0].active = YES;
    }
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:background.leadingAnchor constant:58.0],
        [stack.centerYAnchor constraintEqualToAnchor:background.centerYAnchor],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:background.trailingAnchor constant:-36.0],
    ]];
    return self;
}

- (NSButton*)modeButton:(NSString*)title subtitle:(NSString*)subtitle
                  symbol:(NSString*)symbol primary:(BOOL)primary action:(SEL)action {
    NSButton* button = [NSButton buttonWithTitle:[title stringByAppendingFormat:@"  •  %@", subtitle]
                                           target:self
                                           action:action];
    button.bordered = NO;
    button.wantsLayer = YES;
    button.layer.backgroundColor = (primary ? macColor(0.12, 0.62, 0.34)
                                             : macColor(0.035, 0.135, 0.150)).CGColor;
    button.layer.cornerRadius = 16.0;
    button.layer.borderWidth = primary ? 0.0 : 1.0;
    button.layer.borderColor = [NSColor colorWithWhite:1.0 alpha:0.20].CGColor;
    button.contentTintColor = NSColor.whiteColor;
    button.image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil];
    button.imagePosition = NSImageLeft;
    button.imageScaling = NSImageScaleProportionallyDown;
    button.focusRingType = NSFocusRingTypeNone;
    button.alignment = NSTextAlignmentLeft;
    button.font = macThemedFont(@"AvenirNextCondensed-DemiBold", 22.0, NSFontWeightBold);
    return button;
}

- (void)finishWithSelection:(NSInteger)selection {
    self.selection = selection;
    [NSApp stopModal];
    [self.window orderOut:nil];
}

- (void)selectRestored:(__unused id)sender {
    [self finishWithSelection:0];
}

- (void)selectPrototype:(__unused id)sender {
    NSAlert* warning = [[NSAlert alloc] init];
    warning.alertStyle = NSAlertStyleWarning;
    warning.messageText = @"Prototype Mode is archival";
    warning.informativeText = @"This original build is unfinished and may become progression-blocked. Its saves and settings remain separate.";
    [warning addButtonWithTitle:@"Start Prototype Mode"];
    [warning addButtonWithTitle:@"Cancel"];
    [warning beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
        if (response == NSAlertFirstButtonReturn) [self finishWithSelection:1];
    }];
}

- (void)replaceROM:(__unused id)sender {
    [self finishWithSelection:-2];
}

- (BOOL)windowShouldClose:(__unused id)sender {
    [self finishWithSelection:-1];
    return NO;
}

- (NSInteger)run {
    [self showWindow:nil];
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp runModalForWindow:self.window];
    return self.selection;
}

@end

NSInteger presentMacHome(void) {
    DinoPadMacHomeController* controller = [[DinoPadMacHomeController alloc] init];
    return [controller run];
}

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
            const NSInteger selection = presentMacHome();
            if (selection == 0 || selection == 1) return (int)selection;
            if (selection != -2 || !chooseAndInstallROM(root)) return -1;
        }
    }
}
