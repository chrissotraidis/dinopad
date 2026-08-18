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

UIFont* themedFont(NSString* name, CGFloat size, UIFontWeight fallbackWeight) {
    UIFont* font = [UIFont fontWithName:name size:size];
    return font ?: [UIFont systemFontOfSize:size weight:fallbackWeight];
}

NSAttributedString* themedText(NSString* text, UIFont* font, UIColor* textColor) {
    return [[NSAttributedString alloc] initWithString:text attributes:@{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: textColor,
    }];
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

UIButton* profileButton(NSString* title, NSString* subtitle, NSString* symbol,
                        BOOL primary, BOOL compact) {
    UIButton* button = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButtonConfiguration* configuration = [UIButtonConfiguration plainButtonConfiguration];
    configuration.attributedTitle = themedText(
        title, themedFont(@"AvenirNextCondensed-DemiBold", compact ? 22.0 : 25.0,
                          UIFontWeightBold),
        UIColor.whiteColor);
    configuration.attributedSubtitle = themedText(
        subtitle, themedFont(@"AvenirNextCondensed-Medium", compact ? 13.0 : 15.0,
                             UIFontWeightMedium),
        [UIColor colorWithWhite:1.0 alpha:0.82]);
    configuration.image = [UIImage systemImageNamed:symbol];
    configuration.imagePlacement = NSDirectionalRectEdgeLeading;
    configuration.imagePadding = compact ? 14.0 : 18.0;
    configuration.titleAlignment = UIButtonConfigurationTitleAlignmentLeading;
    configuration.contentInsets = NSDirectionalEdgeInsetsMake(
        compact ? 14.0 : 22.0, compact ? 18.0 : 24.0,
        compact ? 14.0 : 22.0, compact ? 18.0 : 24.0);
    configuration.baseForegroundColor = UIColor.whiteColor;
    configuration.preferredSymbolConfigurationForImage =
        [UIImageSymbolConfiguration configurationWithPointSize:compact ? 29.0 : 34.0
                                                         weight:UIImageSymbolWeightSemibold];

    UIBackgroundConfiguration* background = [UIBackgroundConfiguration clearConfiguration];
    background.backgroundColor = primary
        ? color(0.12, 0.62, 0.34)
        : color(0.055, 0.185, 0.205);
    background.cornerRadius = 24.0;
    background.strokeWidth = primary ? 0.0 : 1.0;
    background.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.18];
    configuration.background = background;

    button.configuration = configuration;
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentFill;
    button.accessibilityValue = subtitle;
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
            (id)color(0.010, 0.055, 0.075).CGColor,
            (id)color(0.022, 0.185, 0.170).CGColor,
            (id)color(0.012, 0.050, 0.070).CGColor,
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

    const BOOL tablet = UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;

    UIImageView* jungleArt = [[UIImageView alloc]
        initWithImage:[UIImage imageNamed:@"dinosaur-jungle-v1"]];
    jungleArt.contentMode = UIViewContentModeScaleAspectFit;
    jungleArt.alpha = tablet ? 0.58 : 0.30;
    jungleArt.userInteractionEnabled = NO;
    jungleArt.accessibilityElementsHidden = YES;
    jungleArt.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view insertSubview:jungleArt aboveSubview:background];

    UILabel* eyebrow = [self label:@"DINOPAD PRESENTS"
                                 font:themedFont(@"AvenirNextCondensed-DemiBold", 15.0,
                                                 UIFontWeightBold)
                                color:color(0.72, 0.88, 0.52)];
    eyebrow.accessibilityIdentifier = @"dinopad.home.eyebrow";
    eyebrow.hidden = !tablet;

    UILabel* title = [self label:@"DinoPad"
                           font:themedFont(@"Baskerville-Bold", tablet ? 68.0 : 48.0,
                                           UIFontWeightHeavy)
                          color:UIColor.whiteColor];

    UILabel* subtitle = [self label:@"Two ways to explore a lost dinosaur world."
                              font:themedFont(@"AvenirNext-Medium", tablet ? 21.0 : 17.0,
                                              UIFontWeightMedium)
                             color:[UIColor colorWithWhite:0.86 alpha:1.0]];
    subtitle.accessibilityIdentifier = @"dinopad.home.subtitle";

    UILabel* choose = [self label:@"SELECT A PATH"
                            font:themedFont(@"AvenirNextCondensed-DemiBold", 16.0,
                                            UIFontWeightBold)
                           color:color(0.72, 0.88, 0.52)];

    UIButton* restored = profileButton(
        @"Restored Adventure",
        @"The recommended journey",
        @"leaf.fill",
        YES, !tablet);
    restored.accessibilityIdentifier = @"dinopad.home.restored";
    restored.accessibilityHint = @"Starts the recommended restored adventure";
    [restored addTarget:self action:@selector(selectRestored)
       forControlEvents:UIControlEventTouchUpInside];

    UIButton* prototype = profileButton(
        @"Prototype Mode",
        @"The original, unfinished build",
        @"archivebox.fill",
        NO, !tablet);
    prototype.accessibilityIdentifier = @"dinopad.home.prototype";
    prototype.accessibilityHint = @"Shows an archival mode warning before starting";
    [prototype addTarget:self action:@selector(showPrototypeWarning)
        forControlEvents:UIControlEventTouchUpInside];

    UIStackView* choices = [[UIStackView alloc] initWithArrangedSubviews:@[
        restored, prototype,
    ]];
    choices.axis = UILayoutConstraintAxisVertical;
    choices.alignment = UIStackViewAlignmentFill;
    choices.distribution = UIStackViewDistributionFillEqually;
    choices.spacing = 14.0;

    [restored.heightAnchor constraintGreaterThanOrEqualToConstant:tablet ? 124.0 : 92.0].active = YES;
    [prototype.heightAnchor constraintEqualToAnchor:restored.heightAnchor].active = YES;

    UIStackView* stack = [[UIStackView alloc] initWithArrangedSubviews:@[
        eyebrow, title, subtitle, choose, choices,
    ]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentFill;
    stack.spacing = tablet ? 16.0 : 10.0;
    [stack setCustomSpacing:tablet ? 8.0 : 0.0 afterView:eyebrow];
    [stack setCustomSpacing:tablet ? 12.0 : 10.0 afterView:title];
    [stack setCustomSpacing:tablet ? 34.0 : 18.0 afterView:subtitle];
    [stack setCustomSpacing:tablet ? 14.0 : 10.0 afterView:choose];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [background.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [background.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [background.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [background.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [jungleArt.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-8.0],
        [jungleArt.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerYAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor
                                             constant:tablet ? 56.0 : 32.0],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor
                                                       constant:-32.0],
    ]];
    [jungleArt.widthAnchor constraintEqualToConstant:tablet ? 830.0 : 500.0].active = YES;
    NSLayoutConstraint* preferredStackWidth =
        [stack.widthAnchor constraintEqualToConstant:tablet ? 550.0 : 460.0];
    preferredStackWidth.priority = UILayoutPriorityDefaultHigh;
    preferredStackWidth.active = YES;
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
