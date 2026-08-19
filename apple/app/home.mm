// home.mm - DinoPad-owned native iPhone/iPad home and profile chooser.

#import "home.h"
#import "diagnostics.h"
#import "rom_setup.h"
#import "test_harness.h"

#import <GameController/GameController.h>
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

@implementation DinoPadHomeController {
    UIButton* _restoredButton;
    UIButton* _prototypeButton;
    UIButton* _utilityButton;
    UILabel* _controllerHint;
    NSInteger _controllerSelection;
    BOOL _controllerConnected;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.selection = -1;
        _controllerSelection = 0;
    }
    return self;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    for (GCController* controller in GCController.controllers) {
        GCExtendedGamepad* gamepad = controller.extendedGamepad;
        gamepad.dpad.up.pressedChangedHandler = nil;
        gamepad.dpad.down.pressedChangedHandler = nil;
        gamepad.buttonA.pressedChangedHandler = nil;
        gamepad.buttonMenu.pressedChangedHandler = nil;
        gamepad.buttonOptions.pressedChangedHandler = nil;
        gamepad.buttonY.pressedChangedHandler = nil;
    }
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

- (void)updateControllerSelection {
    _controllerConnected = GCController.controllers.count > 0;
    _controllerHint.hidden = !_controllerConnected;
    NSArray<UIButton*>* buttons = @[_restoredButton, _prototypeButton];
    for (NSInteger index = 0; index < (NSInteger)buttons.count; ++index) {
        UIButton* button = buttons[index];
        const BOOL selected = _controllerConnected && index == _controllerSelection;
        button.layer.cornerRadius = 24.0;
        button.layer.borderWidth = selected ? 3.0 : 0.0;
        button.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.92].CGColor;
        button.transform = selected
            ? CGAffineTransformMakeScale(1.012, 1.012) : CGAffineTransformIdentity;
    }
}

- (void)moveControllerSelection:(NSInteger)delta {
    if (self.presentedViewController != nil || self.selection >= 0) return;
    _controllerSelection = MAX(0, MIN(1, _controllerSelection + delta));
    dinopad_diagnostics_breadcrumb("home_controller",
        _controllerSelection == 0 ? "restored_focused" : "prototype_focused");
    [self updateControllerSelection];
    [self setNeedsFocusUpdate];
    [self updateFocusIfNeeded];
}

- (void)activateControllerSelection {
    if (self.presentedViewController != nil || self.selection >= 0) return;
    dinopad_diagnostics_breadcrumb("home_controller",
        _controllerSelection == 0 ? "restored_activated" : "prototype_activated");
    if (_controllerSelection == 0) [self selectRestored];
    else [self showPrototypeWarning];
}

- (void)presentHomeMenu {
    if (self.presentedViewController != nil) return;
    dinopad_diagnostics_breadcrumb("home_menu", "presented");
    logHome("Home menu presented");
    UIAlertController* menu = [UIAlertController
        alertControllerWithTitle:@"DinoPad"
                         message:@"Game files and diagnostics"
                  preferredStyle:UIAlertControllerStyleActionSheet];
    [menu addAction:[UIAlertAction actionWithTitle:@"Share Diagnostics & Logs…"
        style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction* action) {
            dinopad_diagnostics_breadcrumb("home_menu", "share_diagnostics_selected");
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                dinopad_present_diagnostics_share((__bridge void*)self, nil);
            });
        }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Manage Game ROM"
        style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction* action) {
            dinopad_diagnostics_breadcrumb("home_menu", "rom_manager_selected");
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                dinopad_present_rom_manager((__bridge void*)self);
            });
        }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Cancel"
        style:UIAlertActionStyleCancel handler:nil]];
#if DINOPAD_ENABLE_TEST_HARNESS
    NSArray<NSString*>* titles = [menu.actions valueForKey:@"title"];
    if ([titles containsObject:@"Share Diagnostics & Logs…"] &&
        [titles containsObject:@"Manage Game ROM"]) {
        logHome("Home menu actions verified");
    }
#endif
    UIPopoverPresentationController* popover = menu.popoverPresentationController;
    if (popover != nil) {
        popover.sourceView = _utilityButton;
        popover.sourceRect = _utilityButton.bounds;
        popover.permittedArrowDirections = UIPopoverArrowDirectionUp;
    }
    [self presentViewController:menu animated:YES completion:nil];
}

- (void)configureController:(GCController*)controller {
    GCExtendedGamepad* gamepad = controller.extendedGamepad;
    if (gamepad == nil) return;
    __weak DinoPadHomeController* weakSelf = self;
    void (^move)(NSInteger) = ^(NSInteger delta) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf moveControllerSelection:delta];
        });
    };
    gamepad.dpad.up.pressedChangedHandler =
        ^(__unused GCControllerButtonInput* button, __unused float value, BOOL pressed) {
            if (pressed) move(-1);
        };
    gamepad.dpad.down.pressedChangedHandler =
        ^(__unused GCControllerButtonInput* button, __unused float value, BOOL pressed) {
            if (pressed) move(1);
        };
    void (^activate)(GCControllerButtonInput*, float, BOOL) =
        ^(__unused GCControllerButtonInput* button, __unused float value, BOOL pressed) {
            if (!pressed) return;
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf activateControllerSelection];
            });
        };
    gamepad.buttonA.pressedChangedHandler = activate;
    gamepad.buttonMenu.pressedChangedHandler = activate;
    void (^options)(GCControllerButtonInput*, float, BOOL) =
        ^(__unused GCControllerButtonInput* button, __unused float value, BOOL pressed) {
            if (!pressed) return;
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf presentHomeMenu];
            });
        };
    gamepad.buttonOptions.pressedChangedHandler = options;
    gamepad.buttonY.pressedChangedHandler = options;
}

- (void)controllerDidConnect:(NSNotification*)notification {
    [self configureController:(GCController*)notification.object];
    dinopad_diagnostics_breadcrumb("home_controller", "connected");
    [self updateControllerSelection];
    [self setNeedsFocusUpdate];
    [self updateFocusIfNeeded];
}

- (void)controllerDidDisconnect:(NSNotification*)notification {
    (void)notification;
    dinopad_diagnostics_breadcrumb("home_controller", "disconnected");
    [self updateControllerSelection];
}

- (NSArray<id<UIFocusEnvironment>>*)preferredFocusEnvironments {
    if (_controllerConnected) {
        return @[_controllerSelection == 0 ? _restoredButton : _prototypeButton];
    }
    return [super preferredFocusEnvironments];
}

- (void)didUpdateFocusInContext:(UIFocusUpdateContext*)context
        withAnimationCoordinator:(UIFocusAnimationCoordinator*)coordinator {
    [super didUpdateFocusInContext:context withAnimationCoordinator:coordinator];
    if (context.nextFocusedView == _restoredButton) _controllerSelection = 0;
    else if (context.nextFocusedView == _prototypeButton) _controllerSelection = 1;
    [coordinator addCoordinatedAnimations:^{ [self updateControllerSelection]; }
                                  completion:nil];
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

    UILabel* title = [self label:@"DinoPad"
                           font:themedFont(@"Baskerville-Bold", tablet ? 68.0 : 48.0,
                                           UIFontWeightHeavy)
                          color:UIColor.whiteColor];

    UILabel* subtitle = [self label:@"Pick your adventure."
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
    _restoredButton = restored;
    _prototypeButton = prototype;

    _controllerHint = [self label:@"D-pad  Choose    A / Start  Play    Y / View  Options"
        font:themedFont(@"AvenirNext-DemiBold", tablet ? 13.0 : 11.0,
                        UIFontWeightSemibold)
        color:[UIColor colorWithWhite:1.0 alpha:0.68]];
    _controllerHint.accessibilityIdentifier = @"dinopad.home.controller-hint";
    _controllerHint.hidden = YES;

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
        title, subtitle, choose, choices, _controllerHint,
    ]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentFill;
    stack.spacing = tablet ? 16.0 : 10.0;
    [stack setCustomSpacing:tablet ? 12.0 : 10.0 afterView:title];
    [stack setCustomSpacing:tablet ? 34.0 : 18.0 afterView:subtitle];
    [stack setCustomSpacing:tablet ? 14.0 : 10.0 afterView:choose];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];

    _utilityButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_utilityButton setImage:[UIImage systemImageNamed:@"ellipsis"] forState:UIControlStateNormal];
    _utilityButton.tintColor = UIColor.whiteColor;
    _utilityButton.backgroundColor = [UIColor colorWithWhite:0.02 alpha:0.68];
    _utilityButton.layer.cornerRadius = 22.0;
    _utilityButton.layer.borderWidth = 1.0;
    _utilityButton.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.38].CGColor;
    _utilityButton.accessibilityIdentifier = @"dinopad.home.menu";
    _utilityButton.accessibilityLabel = @"DinoPad Menu";
    [_utilityButton addTarget:self action:@selector(presentHomeMenu)
             forControlEvents:UIControlEventTouchUpInside];
    _utilityButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_utilityButton];

    [NSLayoutConstraint activateConstraints:@[
        [background.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [background.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [background.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [background.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [jungleArt.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-8.0],
        [jungleArt.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [jungleArt.widthAnchor constraintEqualToAnchor:self.view.widthAnchor
                                            multiplier:tablet ? 0.62 : 0.46],
        [jungleArt.heightAnchor constraintEqualToAnchor:jungleArt.widthAnchor
                                            multiplier:941.0 / 1672.0],
        [stack.centerYAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerYAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor
                                             constant:tablet ? 56.0 : 32.0],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor
                                                       constant:-32.0],
        [_utilityButton.widthAnchor constraintEqualToConstant:44.0],
        [_utilityButton.heightAnchor constraintEqualToConstant:44.0],
        [_utilityButton.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor
                                                       constant:-12.0],
        [_utilityButton.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor
                                                  constant:8.0],
    ]];
    NSLayoutConstraint* preferredStackWidth =
        [stack.widthAnchor constraintEqualToConstant:tablet ? 550.0 : 460.0];
    preferredStackWidth.priority = UILayoutPriorityDefaultHigh;
    preferredStackWidth.active = YES;

    NSNotificationCenter* notifications = NSNotificationCenter.defaultCenter;
    [notifications addObserver:self selector:@selector(controllerDidConnect:)
                          name:GCControllerDidConnectNotification object:nil];
    [notifications addObserver:self selector:@selector(controllerDidDisconnect:)
                          name:GCControllerDidDisconnectNotification object:nil];
    for (GCController* controller in GCController.controllers) {
        [self configureController:controller];
    }
    [self updateControllerSelection];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (_controllerConnected) {
        [self setNeedsFocusUpdate];
        [self updateFocusIfNeeded];
    }
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
    if ([environment[@"DINOPAD_HOME_CONTROLLER_SMOKE"] boolValue] &&
        self.presentationOrdinal == 1) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [self presentHomeMenu];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.20 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [self dismissViewControllerAnimated:NO completion:^{
                    [self moveControllerSelection:1];
                    [self moveControllerSelection:-1];
                    logHome("Controller home navigation verified");
                    [self activateControllerSelection];
                }];
            });
        });
        return;
    }
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
        window.frame = scene != nil
            ? scene.coordinateSpace.bounds : UIScreen.mainScreen.bounds;
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
