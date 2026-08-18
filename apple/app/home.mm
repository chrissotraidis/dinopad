// home.mm - DinoPad-owned native iPhone/iPad home and profile chooser.

#import "home.h"
#import "test_harness.h"

#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>

#include <cstdio>

namespace {

UIColor* color(CGFloat red, CGFloat green, CGFloat blue) {
    return [UIColor colorWithRed:red green:green blue:blue alpha:1.0];
}

void logHome(const char* message) {
    std::fprintf(stderr, "[dinopad-home-test] %s\n", message);
    std::fflush(stderr);
}

UIWindowScene* activeWindowScene() {
    for (UIScene* scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:UIWindowScene.class] &&
            scene.activationState != UISceneActivationStateUnattached) {
            return (UIWindowScene*)scene;
        }
    }
    return nil;
}

UIButton* profileButton(NSString* title, NSString* subtitle, BOOL primary) {
    UIButton* button = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButtonConfiguration* configuration = primary
        ? [UIButtonConfiguration filledButtonConfiguration]
        : [UIButtonConfiguration tintedButtonConfiguration];
    configuration.title = title;
    configuration.subtitle = subtitle;
    configuration.titleAlignment = UIButtonConfigurationTitleAlignmentLeading;
    configuration.cornerStyle = UIButtonConfigurationCornerStyleLarge;
    configuration.contentInsets = NSDirectionalEdgeInsetsMake(16.0, 22.0, 16.0, 22.0);
    configuration.baseBackgroundColor = primary
        ? color(0.18, 0.58, 0.30)
        : [UIColor colorWithRed:0.23 green:0.57 blue:0.63 alpha:0.20];
    configuration.baseForegroundColor = UIColor.whiteColor;
    button.configuration = configuration;
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentFill;
    button.titleLabel.font = [UIFont systemFontOfSize:18.0 weight:UIFontWeightSemibold];
    return button;
}

}  // namespace

@interface DinoPadHomeBackgroundView : UIView
@end

@implementation DinoPadHomeBackgroundView

+ (Class)layerClass {
    return CAGradientLayer.class;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        CAGradientLayer* gradient = (CAGradientLayer*)self.layer;
        gradient.colors = @[
            (id)color(0.025, 0.105, 0.135).CGColor,
            (id)color(0.035, 0.175, 0.180).CGColor,
            (id)color(0.020, 0.080, 0.105).CGColor,
        ];
        gradient.locations = @[@0.0, @0.55, @1.0];
        gradient.startPoint = CGPointMake(0.0, 0.0);
        gradient.endPoint = CGPointMake(1.0, 1.0);
    }
    return self;
}

@end

@interface DinoPadHomeController : UIViewController
@property(nonatomic, assign) NSInteger selection;
#if DINOPAD_ENABLE_TEST_HARNESS
@property(nonatomic, assign) NSInteger presentationOrdinal;
@property(nonatomic, assign) BOOL automationStarted;
#endif
@end

@implementation DinoPadHomeController

- (instancetype)init {
    self = [super init];
    if (self) self.selection = -1;
    return self;
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationLandscapeRight;
}

- (UILabel*)label:(NSString*)text font:(UIFont*)font color:(UIColor*)textColor {
    UILabel* label = [[UILabel alloc] init];
    label.text = text;
    label.font = font;
    label.textColor = textColor;
    label.numberOfLines = 0;
    label.textAlignment = NSTextAlignmentLeft;
    return label;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    DinoPadHomeBackgroundView* background = [[DinoPadHomeBackgroundView alloc] init];
    background.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:background];

    UILabel* eyebrow = [self label:@"DINOPAD  •  NATIVE ON APPLE DEVICES"
                                 font:[UIFont systemFontOfSize:12.0 weight:UIFontWeightBold]
                                color:color(0.46, 0.88, 0.68)];
    eyebrow.accessibilityIdentifier = @"dinopad.home.eyebrow";

    UILabel* title = [self label:@"DinoPad"
                           font:[UIFont systemFontOfSize:46.0 weight:UIFontWeightHeavy]
                          color:UIColor.whiteColor];

    UILabel* subtitle = [self label:@"Rare’s unreleased N64 adventure, restored for iPhone and iPad."
                              font:[UIFont systemFontOfSize:19.0 weight:UIFontWeightRegular]
                             color:[UIColor colorWithWhite:0.86 alpha:1.0]];
    subtitle.accessibilityIdentifier = @"dinopad.home.subtitle";

    UILabel* choose = [self label:@"Choose how to play"
                            font:[UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold]
                           color:[UIColor colorWithWhite:0.66 alpha:1.0]];

    UIButton* restored = profileButton(
        @"Restored Adventure",
        @"Recommended • restoration fixes and intended progression",
        YES);
    restored.accessibilityIdentifier = @"dinopad.home.restored";
    restored.accessibilityHint = @"Starts the recommended restored adventure";
    [restored addTarget:self action:@selector(selectRestored)
       forControlEvents:UIControlEventTouchUpInside];

    UIButton* prototype = profileButton(
        @"Prototype Mode",
        @"Archival • incomplete original prototype",
        NO);
    prototype.accessibilityIdentifier = @"dinopad.home.prototype";
    prototype.accessibilityHint = @"Shows an archival mode warning before starting";
    [prototype addTarget:self action:@selector(showPrototypeWarning)
        forControlEvents:UIControlEventTouchUpInside];

    UILabel* footer = [self label:
        @"Your ROM stays private on this device. Each mode keeps separate saves and settings."
                               font:[UIFont systemFontOfSize:12.0 weight:UIFontWeightRegular]
                              color:[UIColor colorWithWhite:0.54 alpha:1.0]];

    UIStackView* stack = [[UIStackView alloc] initWithArrangedSubviews:@[
        eyebrow, title, subtitle, choose, restored, prototype, footer,
    ]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentFill;
    stack.spacing = 12.0;
    [stack setCustomSpacing:5.0 afterView:eyebrow];
    [stack setCustomSpacing:8.0 afterView:title];
    [stack setCustomSpacing:24.0 afterView:subtitle];
    [stack setCustomSpacing:10.0 afterView:choose];
    [stack setCustomSpacing:10.0 afterView:restored];
    [stack setCustomSpacing:17.0 afterView:prototype];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [background.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [background.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [background.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [background.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor
                                            constant:48.0],
        [stack.centerYAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerYAnchor],
        [stack.widthAnchor constraintLessThanOrEqualToConstant:610.0],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor
                                                      constant:-48.0],
    ]];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
#if DINOPAD_ENABLE_TEST_HARNESS
    if (self.automationStarted) return;
    self.automationStarted = YES;

    NSDictionary<NSString*, NSString*>* environment = NSProcessInfo.processInfo.environment;
    if ([environment[@"DINOPAD_HOME_SHOW_PROTOTYPE_WARNING"] boolValue]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.30 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ [self showPrototypeWarning]; });
        return;
    }

    NSString* sequence = environment[@"DINOPAD_HOME_AUTOMATION_SEQUENCE"];
    if (sequence.length == 0) return;
    NSArray<NSString*>* choices = [sequence componentsSeparatedByString:@","];
    NSInteger index = self.presentationOrdinal - 1;
    if (index < 0 || index >= (NSInteger)choices.count) return;
    NSString* choice = [choices[index] lowercaseString];
    if ([choice isEqualToString:@"restored"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ [self selectRestored]; });
    } else if ([choice isEqualToString:@"prototype"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [self showPrototypeWarning];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [self.presentedViewController dismissViewControllerAnimated:NO completion:nil];
                [self confirmPrototype];
            });
        });
    }
#endif
}

- (void)selectRestored {
    logHome("Restored selected");
    self.selection = 0;
}

- (void)confirmPrototype {
    logHome("Prototype selected");
    self.selection = 1;
}

- (void)showPrototypeWarning {
    if (self.presentedViewController != nil) return;
    UIAlertController* warning = [UIAlertController
        alertControllerWithTitle:@"Prototype Mode is archival"
                         message:@"This mode disables DinoPad’s restoration fixes. The surviving December 2000 prototype is incomplete, contains unfinished content, and may become progression-blocked. Prototype saves and settings remain separate from Restored Adventure."
                  preferredStyle:UIAlertControllerStyleAlert];
    [warning addAction:[UIAlertAction actionWithTitle:@"Continue to Prototype Mode"
        style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction* action) {
            [self confirmPrototype];
        }]];
    [warning addAction:[UIAlertAction actionWithTitle:@"Cancel"
        style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:warning animated:YES completion:nil];
    logHome("Prototype warning presented");
}

@end

int dinopad_present_home(void) {
    @autoreleasepool {
#if DINOPAD_ENABLE_TEST_HARNESS
        static NSInteger presentationCount = 0;
        ++presentationCount;
#endif

        DinoPadHomeController* controller = [[DinoPadHomeController alloc] init];
#if DINOPAD_ENABLE_TEST_HARNESS
        controller.presentationOrdinal = presentationCount;
#endif

        UIWindowScene* scene = activeWindowScene();
        UIWindow* window = scene != nil
            ? [[UIWindow alloc] initWithWindowScene:scene]
            : [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        window.frame = UIScreen.mainScreen.bounds;
        window.windowLevel = UIWindowLevelNormal + 1.0;
        window.rootViewController = controller;
        [window makeKeyAndVisible];
        logHome("Home presented");

        while (controller.selection < 0) {
            @autoreleasepool {
                [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode
                                        beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
            }
        }

        NSInteger selection = controller.selection;
        window.hidden = YES;
        window.rootViewController = nil;
        // Let UIKit finish the home controller's disappearance before SDL
        // installs its own root controller on the next window.
        for (int pass = 0; pass < 4; ++pass) {
            [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode
                                    beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.025]];
        }
        return (int)selection;
    }
}
