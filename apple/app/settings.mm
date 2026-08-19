// settings.mm - DinoPad-owned native iPhone/iPad runtime settings and status.

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <filesystem>

#import <UIKit/UIKit.h>

#import "diagnostics.h"
#import "rom_setup.h"
#import "settings.h"
#import "test_harness.h"

#include "config/config.hpp"
#include "ultramodern/ultramodern.hpp"

extern "C" int dinopad_shell_touch_enabled(void);
extern "C" double dinopad_shell_touch_opacity(void);
extern "C" void dinopad_shell_set_touch(int enabled, double opacity);
extern "C" void dinopad_shell_set_modal_hidden(int hidden);
extern "C" void dinopad_shell_begin_layout_editor(void);
extern "C" void dinopad_shell_reset_current_layout(void);
extern "C" void dinopad_shell_quit_to_home(void);
extern "C" int dinopad_shell_controller_connected(void);
extern "C" void dinopad_shell_request_config_save(void);
#if DINOPAD_ENABLE_TEST_HARNESS
extern "C" int dinopad_shell_test_touch_after_settings(void);
#endif
extern "C" void dinopad_touch_snapshot(uint16_t* buttons, float* x, float* y);

namespace {

NSInteger resolutionMode() {
    switch (ultramodern::renderer::get_graphics_config().res_option) {
        case ultramodern::renderer::Resolution::Original: return 1;
        case ultramodern::renderer::Resolution::Original2x: return 2;
        default: return 0;
    }
}

NSInteger aspectMode() {
    return ultramodern::renderer::get_graphics_config().ar_option ==
        ultramodern::renderer::AspectRatio::Expand ? 1 : 0;
}

NSInteger frameRateMode() {
    return ultramodern::renderer::get_graphics_config().rr_option ==
        ultramodern::renderer::RefreshRate::Display ? 1 : 0;
}

NSInteger hudMode() {
    switch (ultramodern::renderer::get_graphics_config().hr_option) {
        case ultramodern::renderer::HUDRatioMode::Original: return 0;
        case ultramodern::renderer::HUDRatioMode::Full: return 2;
        default: return 1;
    }
}

void applyAudioVolume(NSInteger percent) {
    dino::config::set_main_volume(static_cast<int>(std::clamp<NSInteger>(percent, 0, 100)));
    dinopad_shell_request_config_save();
}

void applyGraphics(NSInteger resolution, NSInteger aspect,
                   NSInteger frameRate, NSInteger hud) {
    auto config = ultramodern::renderer::get_graphics_config();
    switch (std::clamp<NSInteger>(resolution, 0, 2)) {
        case 1: config.res_option = ultramodern::renderer::Resolution::Original; break;
        case 2: config.res_option = ultramodern::renderer::Resolution::Original2x; break;
        default: config.res_option = ultramodern::renderer::Resolution::Auto; break;
    }
    config.ds_option = 1;
    config.ar_option = aspect == 1
        ? ultramodern::renderer::AspectRatio::Expand
        : ultramodern::renderer::AspectRatio::Original;
    config.rr_option = frameRate == 1
        ? ultramodern::renderer::RefreshRate::Display
        : ultramodern::renderer::RefreshRate::Original;
    switch (std::clamp<NSInteger>(hud, 0, 2)) {
        case 0: config.hr_option = ultramodern::renderer::HUDRatioMode::Original; break;
        case 2: config.hr_option = ultramodern::renderer::HUDRatioMode::Full; break;
        default: config.hr_option = ultramodern::renderer::HUDRatioMode::Clamp16x9; break;
    }
    ultramodern::renderer::set_graphics_config(config);
    dinopad_shell_request_config_save();
}

NSString* profileDisplayName() {
#if DINOPAD_ENABLE_STATIC_RESTORATION
    return dino::config::get_session_profile() == dino::config::SessionProfile::Restored
        ? @"Restored Adventure" : @"Prototype Mode";
#else
    return @"Prototype Mode";
#endif
}

NSString* saveStatus() {
    const std::filesystem::path path = ultramodern::get_save_file_path();
    std::error_code error;
    if (path.empty() || !std::filesystem::exists(path, error)) {
        return @"No profile save yet; automatic backup is enabled.";
    }
    std::filesystem::path backup = path;
    backup += ".bak";
    error.clear();
    return std::filesystem::exists(backup, error)
        ? @"Primary profile save and recovery backup are present."
        : @"Primary profile save is present; backup appears after the next successful write.";
}

bool configFilesExist() {
    const std::filesystem::path root = dino::config::get_app_folder_path();
    std::error_code error;
    const bool sound = std::filesystem::exists(root / "sound.json", error);
    error.clear();
    const bool graphics = std::filesystem::exists(root / "graphics.json", error);
    return sound && graphics;
}

#if DINOPAD_ENABLE_TEST_HARNESS
void settingsTestLog(NSString* message) {
    std::fprintf(stderr, "[dinopad-settings-test] %s\n", message.UTF8String);
    std::fflush(stderr);
}
#endif

} // namespace

@interface DinoPadSettingsViewController : UIViewController
#if DINOPAD_ENABLE_TEST_HARNESS
- (void)runAutomationPhase:(NSString*)phase;
#endif
@end

@implementation DinoPadSettingsViewController {
    UILabel* _profileStatus;
#if DINOPAD_ENABLE_STATIC_RESTORATION
    UILabel* _restorationStatus;
#endif
    UILabel* _saveStatus;
    UILabel* _controllerStatus;
    UILabel* _rendererStatus;
    UISwitch* _touchSwitch;
    UISlider* _touchOpacity;
    UILabel* _touchOpacityValue;
    UISlider* _volume;
    UILabel* _volumeValue;
    UISegmentedControl* _resolution;
    UISegmentedControl* _aspect;
    UISegmentedControl* _frameRate;
    UISegmentedControl* _hud;
    NSTimer* _statusTimer;
    BOOL _keepControlsHidden;
}

- (void)loadView {
    self.view = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.view.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.98];
    self.preferredContentSize = CGSizeMake(680.0, 700.0);
}

- (UILabel*)label:(NSString*)text {
    UILabel* label = [[UILabel alloc] init];
    label.text = text;
    label.textColor = UIColor.whiteColor;
    label.font = [UIFont systemFontOfSize:17.0];
    label.numberOfLines = 0;
    return label;
}

- (UILabel*)section:(NSString*)title {
    UILabel* label = [self label:title];
    label.font = [UIFont boldSystemFontOfSize:18.0];
    label.textColor = UIColor.systemTealColor;
    label.accessibilityTraits |= UIAccessibilityTraitHeader;
    return label;
}

- (UILabel*)valueLabel {
    UILabel* value = [self label:@""];
    value.textAlignment = NSTextAlignmentRight;
    value.textColor = [UIColor colorWithWhite:0.76 alpha:1.0];
    return value;
}

- (UIStackView*)valueRow:(NSString*)title value:(UILabel*)value {
    UIStackView* row = [[UIStackView alloc] init];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentFirstBaseline;
    row.spacing = 16.0;
    UILabel* name = [self label:title];
    [name setContentHuggingPriority:UILayoutPriorityRequired
                           forAxis:UILayoutConstraintAxisHorizontal];
    [row addArrangedSubview:name];
    [row addArrangedSubview:value];
    return row;
}

- (UIButton*)actionButton:(NSString*)title image:(NSString*)image action:(SEL)action {
    UIButton* button = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButtonConfiguration* configuration = [UIButtonConfiguration tintedButtonConfiguration];
    configuration.title = title;
    configuration.image = [UIImage systemImageNamed:image];
    configuration.imagePadding = 10.0;
    configuration.cornerStyle = UIButtonConfigurationCornerStyleMedium;
    configuration.contentInsets = NSDirectionalEdgeInsetsMake(12.0, 16.0, 12.0, 16.0);
    button.configuration = configuration;
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    button.accessibilityLabel = title;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:48.0].active = YES;
    return button;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    UIScrollView* scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.alwaysBounceVertical = YES;
    [self.view addSubview:scroll];
    UIView* content = [[UIView alloc] init];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:content];
    UIStackView* stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12.0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:stack];

    UILabel* title = [self label:@"DinoPad Settings & Status"];
    title.font = [UIFont boldSystemFontOfSize:25.0];
    title.accessibilityTraits |= UIAccessibilityTraitHeader;
    [stack addArrangedSubview:title];

    [stack addArrangedSubview:[self section:@"Game"]];
    _profileStatus = [self valueLabel];
#if DINOPAD_ENABLE_STATIC_RESTORATION
    _restorationStatus = [self valueLabel];
#endif
    _saveStatus = [self valueLabel];
    [stack addArrangedSubview:[self valueRow:@"Mode" value:_profileStatus]];
#if DINOPAD_ENABLE_STATIC_RESTORATION
    [stack addArrangedSubview:[self valueRow:@"Restoration" value:_restorationStatus]];
#endif
    [stack addArrangedSubview:[self valueRow:@"Save / Recovery" value:_saveStatus]];

    [stack addArrangedSubview:[self section:@"Controls"]];
    UIStackView* touchRow = [[UIStackView alloc] init];
    touchRow.axis = UILayoutConstraintAxisHorizontal;
    touchRow.alignment = UIStackViewAlignmentCenter;
    [touchRow addArrangedSubview:[self label:@"Touch Controls"]];
    _touchSwitch = [[UISwitch alloc] init];
    _touchSwitch.accessibilityLabel = @"Touch Controls";
    [_touchSwitch addTarget:self action:@selector(touchChanged:)
           forControlEvents:UIControlEventValueChanged];
    [touchRow addArrangedSubview:_touchSwitch];
    [stack addArrangedSubview:touchRow];
    _touchOpacityValue = [self valueLabel];
    [stack addArrangedSubview:[self valueRow:@"Touch Opacity" value:_touchOpacityValue]];
    _touchOpacity = [[UISlider alloc] init];
    _touchOpacity.minimumValue = 20.0;
    _touchOpacity.maximumValue = 100.0;
    _touchOpacity.accessibilityLabel = @"Touch Opacity";
    [_touchOpacity addTarget:self action:@selector(touchOpacityChanged:)
             forControlEvents:UIControlEventValueChanged];
    [stack addArrangedSubview:_touchOpacity];
    _controllerStatus = [self valueLabel];
    [stack addArrangedSubview:[self valueRow:@"Controller" value:_controllerStatus]];
    [stack addArrangedSubview:[self actionButton:@"Customize Touch Layout"
                                              image:@"hand.draw" action:@selector(editLayout)]];
    [stack addArrangedSubview:[self actionButton:@"Reset Current Touch Layout"
                                              image:@"arrow.counterclockwise" action:@selector(resetLayout)]];

    [stack addArrangedSubview:[self section:@"Display"]];
    [stack addArrangedSubview:[self label:@"Internal Resolution"]];
    _resolution = [[UISegmentedControl alloc] initWithItems:@[@"Auto", @"1x", @"2x"]];
    _resolution.accessibilityLabel = @"Internal Resolution";
    [_resolution addTarget:self action:@selector(graphicsChanged:)
          forControlEvents:UIControlEventValueChanged];
    [stack addArrangedSubview:_resolution];
    [stack addArrangedSubview:[self label:@"Aspect Ratio"]];
    _aspect = [[UISegmentedControl alloc] initWithItems:@[@"Original (4:3)", @"Fill Screen"]];
    _aspect.accessibilityLabel = @"Aspect Ratio";
    [_aspect addTarget:self action:@selector(graphicsChanged:)
      forControlEvents:UIControlEventValueChanged];
    [stack addArrangedSubview:_aspect];
    [stack addArrangedSubview:[self label:@"Frame Rate"]];
    _frameRate = [[UISegmentedControl alloc] initWithItems:@[@"Original", @"Display"]];
    _frameRate.accessibilityLabel = @"Frame Rate";
    [_frameRate addTarget:self action:@selector(graphicsChanged:)
         forControlEvents:UIControlEventValueChanged];
    [stack addArrangedSubview:_frameRate];
    [stack addArrangedSubview:[self label:@"HUD Placement"]];
    _hud = [[UISegmentedControl alloc] initWithItems:@[@"4:3", @"Safe 16:9", @"Fill"]];
    _hud.accessibilityLabel = @"HUD Placement";
    [_hud addTarget:self action:@selector(graphicsChanged:)
    forControlEvents:UIControlEventValueChanged];
    [stack addArrangedSubview:_hud];
    _rendererStatus = [self valueLabel];
    [stack addArrangedSubview:[self valueRow:@"Renderer" value:_rendererStatus]];

    [stack addArrangedSubview:[self section:@"Audio"]];
    _volumeValue = [self valueLabel];
    [stack addArrangedSubview:[self valueRow:@"Master Volume" value:_volumeValue]];
    _volume = [[UISlider alloc] init];
    _volume.minimumValue = 0.0;
    _volume.maximumValue = 100.0;
    _volume.accessibilityLabel = @"Master Volume";
    [_volume addTarget:self action:@selector(volumeChanged:)
       forControlEvents:UIControlEventValueChanged];
    [stack addArrangedSubview:_volume];

    [stack addArrangedSubview:[self section:@"Game Data"]];
    [stack addArrangedSubview:[self actionButton:@"Manage Game ROM"
                                              image:@"externaldrive" action:@selector(manageROM)]];
    [stack addArrangedSubview:[self section:@"Support"]];
    UILabel* support = [self label:@"Shared diagnostics are bounded, redact private paths, and never include ROM or save contents."];
    support.font = [UIFont systemFontOfSize:14.0];
    support.textColor = [UIColor colorWithWhite:0.68 alpha:1.0];
    [stack addArrangedSubview:support];
    [stack addArrangedSubview:[self actionButton:@"Share Diagnostics & Logs…"
                                              image:@"square.and.arrow.up" action:@selector(shareDiagnostics)]];
    [stack addArrangedSubview:[self actionButton:@"Return to DinoPad Home"
                                              image:@"house" action:@selector(quitHome)]];

    UIButton* done = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButtonConfiguration* doneConfig = [UIButtonConfiguration filledButtonConfiguration];
    doneConfig.title = @"Done";
    doneConfig.cornerStyle = UIButtonConfigurationCornerStyleMedium;
    doneConfig.contentInsets = NSDirectionalEdgeInsetsMake(13.0, 18.0, 13.0, 18.0);
    done.configuration = doneConfig;
    done.accessibilityLabel = @"Done";
    [done addTarget:self action:@selector(done) forControlEvents:UIControlEventTouchUpInside];
    [done.heightAnchor constraintGreaterThanOrEqualToConstant:50.0].active = YES;
    [stack addArrangedSubview:done];

    [NSLayoutConstraint activateConstraints:@[
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
        [scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
        [content.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor],
        [content.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
        [content.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
        [content.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor],
        [stack.topAnchor constraintEqualToAnchor:content.topAnchor constant:22.0],
        [stack.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-22.0],
        [stack.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:26.0],
        [stack.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-26.0],
    ]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshValues];
    [_statusTimer invalidate];
    _statusTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self
        selector:@selector(refreshStatus) userInfo:nil repeats:YES];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [_statusTimer invalidate];
    _statusTimer = nil;
    if (!_keepControlsHidden) dinopad_shell_set_modal_hidden(0);
}

- (void)refreshValues {
    _touchSwitch.on = dinopad_shell_touch_enabled() != 0;
    _touchOpacity.value = static_cast<float>(dinopad_shell_touch_opacity() * 100.0);
    _volume.value = static_cast<float>(std::clamp(dino::config::get_main_volume(), 0, 100));
    _resolution.selectedSegmentIndex = resolutionMode();
    _aspect.selectedSegmentIndex = aspectMode();
    _frameRate.selectedSegmentIndex = frameRateMode();
    _hud.selectedSegmentIndex = hudMode();
    [self refreshStatus];
}

- (void)refreshStatus {
    _profileStatus.text = profileDisplayName();
#if DINOPAD_ENABLE_STATIC_RESTORATION
    _restorationStatus.text = dino::config::get_session_profile() ==
        dino::config::SessionProfile::Restored
        ? @"Bundled static restoration active; writable mods disabled."
        : @"Disabled for archival Prototype Mode.";
#endif
    _saveStatus.text = saveStatus();
    _controllerStatus.text = dinopad_shell_controller_connected()
        ? @"Connected; gameplay touch hidden" : @"Not connected; gameplay touch available";
    const float scale = ultramodern::get_resolution_scale();
    const uint32_t refresh = ultramodern::get_display_refresh_rate();
    _rendererStatus.text = scale > 0.0F && refresh > 0
        ? [NSString stringWithFormat:@"Metal • %.2fx • %u Hz", scale, refresh]
        : @"Metal • waiting for a presented frame";
    _touchOpacityValue.text = [NSString stringWithFormat:@"%d%%", (int)std::lround(_touchOpacity.value)];
    _touchOpacity.accessibilityValue = _touchOpacityValue.text;
    _volumeValue.text = [NSString stringWithFormat:@"%d%%", (int)std::lround(_volume.value)];
    _volume.accessibilityValue = _volumeValue.text;
}

- (void)touchChanged:(UISwitch*)sender {
    dinopad_shell_set_touch(sender.isOn, _touchOpacity.value / 100.0);
}

- (void)touchOpacityChanged:(UISlider*)sender {
    dinopad_shell_set_touch(_touchSwitch.isOn, sender.value / 100.0);
    [self refreshStatus];
}

- (void)volumeChanged:(UISlider*)sender {
    applyAudioVolume((NSInteger)std::lround(sender.value));
    [self refreshStatus];
}

- (void)graphicsChanged:(UISegmentedControl*)sender {
    applyGraphics(_resolution.selectedSegmentIndex, _aspect.selectedSegmentIndex,
                  _frameRate.selectedSegmentIndex, _hud.selectedSegmentIndex);
    [self refreshStatus];
}

- (void)editLayout {
    [self dismissViewControllerAnimated:YES completion:^{
        dinopad_shell_begin_layout_editor();
    }];
}

- (void)resetLayout {
    UIAlertController* confirmation = [UIAlertController
        alertControllerWithTitle:@"Reset Current Touch Layout?"
                         message:@"This restores the default layout for this device type."
                  preferredStyle:UIAlertControllerStyleAlert];
    [confirmation addAction:[UIAlertAction actionWithTitle:@"Cancel"
        style:UIAlertActionStyleCancel handler:nil]];
    [confirmation addAction:[UIAlertAction actionWithTitle:@"Reset"
        style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction* action) {
            dinopad_shell_reset_current_layout();
        }]];
    [self presentViewController:confirmation animated:YES completion:nil];
}

- (void)manageROM {
    _keepControlsHidden = YES;
    UIViewController* presenter = self.presentingViewController;
    [self dismissViewControllerAnimated:YES completion:^{
        if (presenter != nil) dinopad_present_rom_manager((__bridge void*)presenter);
    }];
}

- (void)shareDiagnostics {
    _keepControlsHidden = YES;
    UIViewController* presenter = self.presentingViewController;
    [self dismissViewControllerAnimated:YES completion:^{
        if (presenter == nil) {
            self->_keepControlsHidden = NO;
            dinopad_shell_set_modal_hidden(0);
            return;
        }
        dinopad_present_diagnostics_share((__bridge void*)presenter, ^{
            self->_keepControlsHidden = NO;
            dinopad_shell_set_modal_hidden(0);
        });
    }];
}

- (void)quitHome {
    _keepControlsHidden = YES;
    [self dismissViewControllerAnimated:YES completion:^{
        dinopad_shell_quit_to_home();
    }];
}

- (void)done {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#if DINOPAD_ENABLE_TEST_HARNESS
- (void)runAutomationPhase:(NSString*)phase {
    uint16_t buttons = 0;
    float x = 0.0F;
    float y = 0.0F;
    dinopad_touch_snapshot(&buttons, &x, &y);
    if (buttons != 0 || x != 0.0F || y != 0.0F) {
        settingsTestLog(@"FAIL: modal presentation did not clear gameplay input");
        return;
    }
    settingsTestLog(@"modal input suppression verified");

    if ([phase isEqualToString:@"verify"]) {
        const bool persisted = dinopad_shell_touch_enabled() != 0 &&
            std::abs(dinopad_shell_touch_opacity() - 0.43) < 0.005 &&
            dino::config::get_main_volume() == 37 && resolutionMode() == 2 &&
            aspectMode() == 1 && frameRateMode() == 1 && hudMode() == 2;
        if (!persisted) {
            settingsTestLog(@"FAIL: settings did not survive relaunch");
            return;
        }
        settingsTestLog(@"RELAUNCH VALUES VERIFIED");

        _touchSwitch.on = YES;
        _touchOpacity.value = 70.0F;
        [self touchOpacityChanged:_touchOpacity];
        _volume.value = 100.0F;
        [self volumeChanged:_volume];
        _resolution.selectedSegmentIndex = 0;
        _aspect.selectedSegmentIndex = 1;
        _frameRate.selectedSegmentIndex = 0;
        _hud.selectedSegmentIndex = 1;
        [self graphicsChanged:_resolution];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            const bool resetSaved = configFilesExist() &&
                dino::config::get_main_volume() == 100 && resolutionMode() == 0 &&
                aspectMode() == 1 && frameRateMode() == 0 && hudMode() == 1;
            [self dismissViewControllerAnimated:YES completion:^{
                const bool touchRestored = dinopad_shell_test_touch_after_settings() != 0;
                settingsTestLog(resetSaved && touchRestored
                    ? @"ALL SETTINGS TESTS PASSED"
                    : @"FAIL: reset persistence or post-modal touch input");
            }];
        });
        return;
    }

    applyAudioVolume(-50);
    applyAudioVolume(150);
    applyGraphics(99, -1, 99, 99);
    const bool clamped = dino::config::get_main_volume() == 100 &&
        resolutionMode() == 2 && aspectMode() == 0 &&
        frameRateMode() == 0 && hudMode() == 2;
    if (!clamped) {
        settingsTestLog(@"FAIL: invalid native settings were not clamped");
        return;
    }
    settingsTestLog(@"invalid native values clamped safely");

    _touchSwitch.on = YES;
    _touchOpacity.value = 43.0F;
    [self touchOpacityChanged:_touchOpacity];
    _volume.value = 37.0F;
    [self volumeChanged:_volume];
    _resolution.selectedSegmentIndex = 2;
    _aspect.selectedSegmentIndex = 1;
    _frameRate.selectedSegmentIndex = 1;
    _hud.selectedSegmentIndex = 2;
    [self graphicsChanged:_resolution];
    settingsTestLog(@"EDIT VALUES APPLIED");

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        const bool live = configFilesExist() && dinopad_shell_touch_enabled() != 0 &&
            std::abs(dinopad_shell_touch_opacity() - 0.43) < 0.005 &&
            dino::config::get_main_volume() == 37 && resolutionMode() == 2 &&
            aspectMode() == 1 && frameRateMode() == 1 && hudMode() == 2;
        [self dismissViewControllerAnimated:YES completion:^{
            const bool touchRestored = dinopad_shell_test_touch_after_settings() != 0;
            settingsTestLog(live && touchRestored
                ? @"EDIT PHASE PASSED"
                : @"FAIL: live apply, persistence, or post-modal touch input");
        }];
    });
}
#endif

@end

extern "C" void dinopad_present_settings(void* presenter_pointer) {
    UIViewController* presenter = (__bridge UIViewController*)presenter_pointer;
    if (presenter == nil) {
        dinopad_shell_set_modal_hidden(0);
        return;
    }
    dinopad_shell_set_modal_hidden(1);
    DinoPadSettingsViewController* settings = [DinoPadSettingsViewController new];
    settings.modalPresentationStyle = UIModalPresentationFormSheet;
#if DINOPAD_ENABLE_TEST_HARNESS
    [presenter presentViewController:settings animated:YES completion:^{
        const char* smoke = std::getenv("DINOPAD_RUN_SETTINGS_SMOKE");
        const char* phase = std::getenv("DINOPAD_SETTINGS_SMOKE_PHASE");
        if (smoke != nullptr && smoke[0] != '\0' && smoke[0] != '0') {
            [settings runAutomationPhase:phase == nullptr
                ? @"edit" : [NSString stringWithUTF8String:phase]];
        }
    }];
#else
    [presenter presentViewController:settings animated:YES completion:nil];
#endif
}
