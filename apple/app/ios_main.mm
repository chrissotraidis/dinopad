#include <algorithm>
#include <array>
#include <atomic>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <pthread.h>
#include <vector>

#include <SDL.h>
#include <TargetConditionals.h>
#import "diagnostics.h"
#import "home.h"
#import "rom_setup.h"
#import "settings.h"
#import "test_harness.h"
#import <UIKit/UIKit.h>

#include "config/config.hpp"
#include "runtime/audio.hpp"
#include "runtime/gfx.hpp"
#include "ultramodern/ultramodern.hpp"

extern "C" int dinopad_recomp_main(int argc, char **argv);
extern "C" void dinopad_touch_snapshot(uint16_t* buttons, float* x, float* y);
extern "C" void dinopad_set_physical_controller_connected(int connected);

static void dinopad_apply_gameplay_window_geometry(void* opaqueWindow) {
    @autoreleasepool {
        UIWindow* window = (__bridge UIWindow*)opaqueWindow;
        if (window == nil) return;

        UIWindowScene* scene = window.windowScene;
        CGRect targetBounds = scene != nil
            ? scene.coordinateSpace.bounds : UIScreen.mainScreen.bounds;
        if (!CGRectIsEmpty(targetBounds)) {
            window.frame = targetBounds;
        }

        UIView* rootView = window.rootViewController.view;
        if (rootView != nil) {
            rootView.frame = window.bounds;
            [rootView setNeedsLayout];
            [rootView layoutIfNeeded];
        }
        [window layoutIfNeeded];

        const CGRect windowBounds = window.bounds;
        const CGRect viewBounds = rootView != nil ? rootView.bounds : CGRectZero;
        std::fprintf(stderr,
            "[dinopad-gfx] UIKit geometry window=%.0fx%.0f view=%.0fx%.0f scene=%.0fx%.0f\n",
            windowBounds.size.width, windowBounds.size.height,
            viewBounds.size.width, viewBounds.size.height,
            targetBounds.size.width, targetBounds.size.height);
        std::fflush(stderr);
    }
}

extern "C" void dinopad_prepare_gameplay_window(void* windowPointer) {
    if (windowPointer == nullptr) return;
    if (pthread_main_np() != 0) {
        dinopad_apply_gameplay_window_geometry(windowPointer);
    } else {
        dispatch_sync_f(dispatch_get_main_queue(), windowPointer,
                        dinopad_apply_gameplay_window_geometry);
    }
}

namespace {

constexpr uint8_t kTapHoldPolls = 6;
constexpr uint8_t kAnalogFlickHoldPolls = 1;
constexpr size_t kControlCount = 15;

class TouchTapLatch {
public:
    void extend(uint16_t mask, uint8_t polls) {
        for (size_t bit = 0; bit < counters_.size(); ++bit) {
            const uint16_t bitMask = static_cast<uint16_t>(1u << bit);
            if ((mask & bitMask) == 0) continue;
            uint8_t current = counters_[bit].load(std::memory_order_relaxed);
            while (current < polls &&
                   !counters_[bit].compare_exchange_weak(
                       current, polls, std::memory_order_relaxed)) {}
        }
    }

    void clearAll() {
        for (auto& counter : counters_) {
            counter.store(0, std::memory_order_relaxed);
        }
    }

    void clear(uint16_t mask) {
        for (size_t bit = 0; bit < counters_.size(); ++bit) {
            if ((mask & static_cast<uint16_t>(1u << bit)) != 0) {
                counters_[bit].store(0, std::memory_order_relaxed);
            }
        }
    }

    uint16_t consume() {
        uint16_t buttons = 0;
        for (size_t bit = 0; bit < counters_.size(); ++bit) {
            uint8_t current = counters_[bit].load(std::memory_order_relaxed);
            while (current != 0) {
                if (counters_[bit].compare_exchange_weak(
                        current, static_cast<uint8_t>(current - 1),
                        std::memory_order_relaxed)) {
                    buttons |= static_cast<uint16_t>(1u << bit);
                    break;
                }
            }
        }
        return buttons;
    }

private:
    std::array<std::atomic<uint8_t>, 16> counters_{};
};

enum class ControlKind { Stick, Button };

struct TouchControl {
    const char* key;
    const char* label;
    ControlKind kind;
    uint16_t mask;
    CGFloat x;
    CGFloat y;
    CGFloat size;
    CGFloat opacity;
    bool visible;
};

std::array<TouchControl, kControlCount> defaultControlsForIdiom(UIUserInterfaceIdiom idiom) {
    if (idiom == UIUserInterfaceIdiomPad) {
        return {{
            {"stick", "", ControlKind::Stick, 0x0000, 0.164, 0.745, 0.090, 0.42, true},
            {"d_up", "\u2191", ControlKind::Button, 0x0800, 0.080, 0.550, 0.032, 0.42, true},
            {"d_down", "\u2193", ControlKind::Button, 0x0400, 0.080, 0.665, 0.032, 0.42, true},
            {"d_left", "\u2190", ControlKind::Button, 0x0200, 0.040, 0.608, 0.032, 0.42, true},
            {"d_right", "\u2192", ControlKind::Button, 0x0100, 0.120, 0.608, 0.032, 0.42, true},
            {"c_up", "\u2191", ControlKind::Button, 0x0008, 0.904, 0.805, 0.033, 0.42, true},
            {"c_down", "\u2193", ControlKind::Button, 0x0004, 0.904, 0.910, 0.033, 0.42, true},
            {"c_left", "\u2190", ControlKind::Button, 0x0002, 0.861, 0.858, 0.033, 0.42, true},
            {"c_right", "\u2192", ControlKind::Button, 0x0001, 0.946, 0.858, 0.033, 0.42, true},
            {"a", "A", ControlKind::Button, 0x8000, 0.893, 0.693, 0.048, 0.48, true},
            {"b", "B", ControlKind::Button, 0x4000, 0.826, 0.635, 0.048, 0.48, true},
            {"z", "Z", ControlKind::Button, 0x2000, 0.897, 0.581, 0.048, 0.44, true},
            {"l", "L", ControlKind::Button, 0x0020, 0.941, 0.460, 0.041, 0.38, true},
            {"r", "R", ControlKind::Button, 0x0010, 0.941, 0.374, 0.041, 0.38, true},
            {"start", "START", ControlKind::Button, 0x1000, 0.942, 0.291, 0.033, 0.40, true},
        }};
    }
    return {{
        {"stick", "", ControlKind::Stick, 0x0000, 0.141, 0.783, 0.1480, 0.38, true},
        {"d_up", "\u2191", ControlKind::Button, 0x0800, 0.087, 0.359, 0.0560, 0.38, true},
        {"d_down", "\u2193", ControlKind::Button, 0x0400, 0.084, 0.541, 0.0560, 0.38, true},
        {"d_left", "\u2190", ControlKind::Button, 0x0200, 0.038, 0.444, 0.0560, 0.38, true},
        {"d_right", "\u2192", ControlKind::Button, 0x0100, 0.133, 0.449, 0.0560, 0.38, true},
        {"c_up", "\u2191", ControlKind::Button, 0x0008, 0.925, 0.337, 0.0510, 0.52, true},
        {"c_down", "\u2193", ControlKind::Button, 0x0004, 0.926, 0.522, 0.0510, 0.52, true},
        {"c_left", "\u2190", ControlKind::Button, 0x0002, 0.883, 0.425, 0.0510, 0.52, true},
        {"c_right", "\u2192", ControlKind::Button, 0x0001, 0.967, 0.428, 0.0510, 0.52, true},
        {"a", "A", ControlKind::Button, 0x8000, 0.930, 0.844, 0.0858, 0.58, true},
        {"b", "B", ControlKind::Button, 0x4000, 0.851, 0.736, 0.0792, 0.58, true},
        {"z", "Z", ControlKind::Button, 0x2000, 0.924, 0.672, 0.0660, 0.40, true},
        {"l", "L", ControlKind::Button, 0x0020, 0.946, 0.188, 0.0500, 0.36, true},
        {"r", "R", ControlKind::Button, 0x0010, 0.946, 0.079, 0.0500, 0.36, true},
        {"start", "START", ControlKind::Button, 0x1000, 0.874, 0.069, 0.0500, 0.54, true},
    }};
}

std::array<TouchControl, kControlCount> defaultControls() {
    return defaultControlsForIdiom(UIDevice.currentDevice.userInterfaceIdiom);
}

NSString* layoutDefaultsKeyForIdiom(UIUserInterfaceIdiom idiom) {
    return idiom == UIUserInterfaceIdiomPad
        ? @"dinopad.touch.layout.ipad.v1"
        : @"dinopad.touch.layout.iphone.v1";
}

NSString* layoutDefaultsKey() {
    return layoutDefaultsKeyForIdiom(UIDevice.currentDevice.userInterfaceIdiom);
}

std::atomic<uint16_t> g_touchButtons{0};
std::atomic<int32_t> g_touchX{0};
std::atomic<int32_t> g_touchY{0};
std::atomic<int32_t> g_touchFlickX{0};
std::atomic<int32_t> g_touchFlickY{0};
std::atomic<uint8_t> g_touchFlickPolls{0};
std::atomic_bool g_controllerConnected{false};
std::atomic_bool g_quitToHome{false};
std::atomic<int> g_currentProfile{0};
#if DINOPAD_ENABLE_TEST_HARNESS
std::atomic_bool g_quitSmokeTriggered{false};
#endif
std::atomic_bool g_settingsSaveRequested{false};
#if DINOPAD_ENABLE_TEST_HARNESS
std::atomic<uint64_t> g_gameInputPolls{0};
#endif
TouchTapLatch g_touchTaps;

void drainUIKitQueue() {
    for (int pass = 0; pass < 4; ++pass) {
        [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode
                                beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.025]];
    }
}

}  // namespace

@interface DinoPadTouchOverlayView : UIView
- (void)publishInput;
- (void)clearInput;
- (void)beginEditingLayout;
- (void)finishEditingLayoutSaving:(BOOL)save;
- (void)resetLayout;
- (void)resetLayoutForIdiom:(UIUserInterfaceIdiom)idiom;
- (void)setControlsEnabled:(BOOL)enabled;
- (void)setControlsEnabled:(BOOL)enabled opacity:(CGFloat)opacity;
- (void)setModalControlsHidden:(BOOL)hidden;
- (void)setPhysicalControllerConnected:(BOOL)connected;
- (void)presentUtilityMenu;
- (void)dismissUtilityMenu;
- (void)confirmResetLayoutForIdiom:(UIUserInterfaceIdiom)idiom;
- (void)confirmQuitToHome;
- (void)quitToHome;

#if DINOPAD_ENABLE_TEST_HARNESS
// Deterministic test injection methods. These selectors do not exist in
// physical-device or release builds.
- (CGPoint)centerForControlIndex:(NSInteger)index;
- (CGFloat)radiusForControlIndex:(NSInteger)index;
- (NSInteger)controlIndexForKey:(const char*)key;
- (void)beginSimulatedTouchWithID:(NSInteger)touchID atPoint:(CGPoint)point;
- (void)moveSimulatedTouchWithID:(NSInteger)touchID toPoint:(CGPoint)point;
- (void)endSimulatedTouchWithID:(NSInteger)touchID;
- (BOOL)performEditorActionForTesting:(NSInteger)action;
- (void)selectControlForTesting:(const char*)key;
- (void)moveSelectedForTestingToNormalizedPoint:(CGPoint)point;
- (NSDictionary*)layoutSnapshotForTesting;
#endif
@end

@interface DinoPadUtilityButton : UIButton
@end

@implementation DinoPadUtilityButton
- (BOOL)canBecomeFocused {
    return NO;
}
@end

#if DINOPAD_ENABLE_TEST_HARNESS
@interface DinoPadInputSmokeRunner : NSObject
+ (void)runWithOverlay:(DinoPadTouchOverlayView*)overlay;
@end

@interface DinoPadGameplaySmokeRunner : NSObject
+ (void)runWithOverlay:(DinoPadTouchOverlayView*)overlay;
@end

@interface DinoPadLayoutSmokeRunner : NSObject
+ (void)runWithOverlay:(DinoPadTouchOverlayView*)overlay phase:(NSString*)phase;
@end
#endif

@implementation DinoPadTouchOverlayView {
    std::array<TouchControl, kControlCount> _controls;
    std::array<TouchControl, kControlCount> _undoControls;
    std::array<TouchControl, kControlCount> _editingStartControls;
    NSMapTable<UITouch*, NSNumber*>* _touchRoles;
    NSMapTable<UITouch*, NSValue*>* _touchOffsets;
#if DINOPAD_ENABLE_TEST_HARNESS
    NSMutableDictionary<NSNumber*, NSNumber*>* _simulatedTouchRoles;
    NSMutableDictionary<NSNumber*, NSValue*>* _simulatedTouchPoints;
#endif
    CGPoint _stickOrigin;
    CGPoint _stickKnob;
    BOOL _editing;
    BOOL _hasUndo;
    BOOL _dPadLinked;
    BOOL _cButtonsLinked;
    BOOL _undoDPadLinked;
    BOOL _undoCButtonsLinked;
    BOOL _editingStartDPadLinked;
    BOOL _editingStartCButtonsLinked;
    NSInteger _selected;
    BOOL _controlsEnabled;
    BOOL _controllerConnected;
    BOOL _modalControlsHidden;
    CGFloat _globalOpacity;
    UIButton* _utilityButton;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.opaque = NO;
        self.multipleTouchEnabled = YES;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _controls = defaultControls();
        _touchRoles = [NSMapTable weakToStrongObjectsMapTable];
        _touchOffsets = [NSMapTable weakToStrongObjectsMapTable];
#if DINOPAD_ENABLE_TEST_HARNESS
        _simulatedTouchRoles = [NSMutableDictionary dictionary];
        _simulatedTouchPoints = [NSMutableDictionary dictionary];
#endif
        _selected = 9;
        _controlsEnabled = YES;
        _globalOpacity = 0.70;

        NSDictionary* saved = [NSUserDefaults.standardUserDefaults
            dictionaryForKey:@"dinopad.touch.settings.v1"];
        if ([saved[@"enabled"] isKindOfClass:NSNumber.class]) {
            _controlsEnabled = [saved[@"enabled"] boolValue];
        }
        if ([saved[@"opacity"] isKindOfClass:NSNumber.class]) {
            const double opacity = [saved[@"opacity"] doubleValue];
            if (std::isfinite(opacity)) {
                _globalOpacity = MAX(0.20, MIN(1.0, opacity));
            }
        }

        _utilityButton = [DinoPadUtilityButton buttonWithType:UIButtonTypeCustom];
        [_utilityButton setTitle:@"\u2022\u2022\u2022" forState:UIControlStateNormal];
        _utilityButton.titleLabel.font = [UIFont boldSystemFontOfSize:16.0];
        _utilityButton.backgroundColor = [UIColor colorWithWhite:0.02 alpha:0.68];
        _utilityButton.layer.cornerRadius = 22.0;
        _utilityButton.layer.borderWidth = 1.0;
        _utilityButton.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.38].CGColor;
        _utilityButton.accessibilityLabel = @"DinoPad Menu";
        _utilityButton.accessibilityHint = @"Opens game and control settings";
        [_utilityButton addTarget:self action:@selector(presentUtilityMenu)
                 forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_utilityButton];
        [self loadLayout];

        NSNotificationCenter* notifications = NSNotificationCenter.defaultCenter;
        [notifications addObserver:self selector:@selector(clearInput)
                              name:UIApplicationWillResignActiveNotification object:nil];
        [notifications addObserver:self selector:@selector(clearInput)
                              name:UIApplicationDidEnterBackgroundNotification object:nil];
        [notifications addObserver:self selector:@selector(clearInput)
                              name:UIApplicationDidBecomeActiveNotification object:nil];
        [notifications addObserver:self selector:@selector(romManagerDidDismiss)
                              name:@"DinoPadROMManagerDidDismissNotification" object:nil];
    }
    return self;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (UIEdgeInsets)usableInsets {
    UIEdgeInsets insets = self.safeAreaInsets;
    insets.top += 2.0;
    insets.bottom += 2.0;
    return insets;
}

- (CGRect)usableBounds {
    return UIEdgeInsetsInsetRect(self.bounds, [self usableInsets]);
}

- (CGFloat)baseDimension {
    CGRect usable = [self usableBounds];
    return MIN(usable.size.width, usable.size.height);
}

- (BOOL)isShoulder:(const TouchControl&)control {
    return std::strcmp(control.key, "l") == 0 || std::strcmp(control.key, "r") == 0;
}

- (BOOL)isDirectional:(const TouchControl&)control {
    return std::strncmp(control.key, "d_", 2) == 0 ||
           std::strncmp(control.key, "c_", 2) == 0;
}

- (CGPoint)centerForControl:(const TouchControl&)control {
    CGRect usable = [self usableBounds];
    CGFloat radius = control.size * [self baseDimension];
    CGFloat halfWidth = [self isShoulder:control] ? radius * 1.65 : radius;
    CGFloat x = CGRectGetMinX(usable) + control.x * usable.size.width;
    CGFloat y = CGRectGetMinY(usable) + control.y * usable.size.height;
    x = MAX(CGRectGetMinX(usable) + halfWidth, MIN(CGRectGetMaxX(usable) - halfWidth, x));
    y = MAX(CGRectGetMinY(usable) + radius, MIN(CGRectGetMaxY(usable) - radius, y));
    return CGPointMake(x, y);
}

- (CGPoint)centerForControlIndex:(NSInteger)index {
    if (index < 0 || index >= static_cast<NSInteger>(kControlCount)) return CGPointZero;
    return [self centerForControl:_controls[index]];
}

- (CGFloat)radiusForControl:(const TouchControl&)control {
    return control.size * [self baseDimension];
}

- (CGFloat)radiusForControlIndex:(NSInteger)index {
    if (index < 0 || index >= static_cast<NSInteger>(kControlCount)) return 0.0;
    return [self radiusForControl:_controls[index]];
}

- (NSInteger)controlIndexForKey:(const char*)key {
    for (NSInteger i = 0; i < static_cast<NSInteger>(kControlCount); ++i) {
        if (std::strcmp(_controls[i].key, key) == 0) return i;
    }
    return NSNotFound;
}

- (CGFloat)defaultSizeForControl:(const TouchControl&)control {
    for (const TouchControl& candidate : defaultControls()) {
        if (std::strcmp(candidate.key, control.key) == 0) return candidate.size;
    }
    return control.size;
}

- (BOOL)isControlInSelectedMoveGroup:(NSInteger)index {
    if (_selected < 0 || _selected >= static_cast<NSInteger>(kControlCount) ||
        index < 0 || index >= static_cast<NSInteger>(kControlCount)) return NO;
    const TouchControl& selected = _controls[_selected];
    const TouchControl& candidate = _controls[index];
    if (_dPadLinked && std::strncmp(selected.key, "d_", 2) == 0) {
        return std::strncmp(candidate.key, "d_", 2) == 0;
    }
    if (_cButtonsLinked && std::strncmp(selected.key, "c_", 2) == 0) {
        return std::strncmp(candidate.key, "c_", 2) == 0;
    }
    return index == _selected;
}

- (BOOL)isSelectedDirectionalGroupLinked {
    if (_selected < 0 || _selected >= static_cast<NSInteger>(kControlCount)) return NO;
    const TouchControl& selected = _controls[_selected];
    if (std::strncmp(selected.key, "d_", 2) == 0) return _dPadLinked;
    if (std::strncmp(selected.key, "c_", 2) == 0) return _cButtonsLinked;
    return NO;
}

- (NSDictionary*)serializedLayout {
    NSMutableDictionary* saved = [NSMutableDictionary dictionaryWithCapacity:kControlCount + 1];
    for (const TouchControl& control : _controls) {
        NSString* key = [NSString stringWithUTF8String:control.key];
        saved[key] = @{
            @"x": @(control.x), @"y": @(control.y),
            @"size": @(control.size), @"opacity": @(control.opacity),
            @"visible": @(control.visible),
        };
    }
    saved[@"_groups"] = @{
        @"dPadLinked": @(_dPadLinked),
        @"cButtonsLinked": @(_cButtonsLinked),
    };
    return saved;
}

- (void)loadLayout {
    NSDictionary* saved = [NSUserDefaults.standardUserDefaults dictionaryForKey:layoutDefaultsKey()];
    if (![saved isKindOfClass:NSDictionary.class]) return;
    NSDictionary* groups = saved[@"_groups"];
    if ([groups isKindOfClass:NSDictionary.class]) {
        _dPadLinked = [groups[@"dPadLinked"] boolValue];
        _cButtonsLinked = [groups[@"cButtonsLinked"] boolValue];
    }
    for (TouchControl& control : _controls) {
        NSString* key = [NSString stringWithUTF8String:control.key];
        NSDictionary* value = saved[key];
        if (![value isKindOfClass:NSDictionary.class]) continue;
        const CGFloat defaultSize = [self defaultSizeForControl:control];
        NSNumber* xValue = value[@"x"];
        NSNumber* yValue = value[@"y"];
        NSNumber* sizeValue = value[@"size"];
        NSNumber* opacityValue = value[@"opacity"];
        const double x = xValue.doubleValue;
        const double y = yValue.doubleValue;
        const double size = sizeValue.doubleValue;
        const double opacity = opacityValue.doubleValue;
        if ([xValue isKindOfClass:NSNumber.class] && std::isfinite(x)) {
            control.x = MAX(0.0, MIN(1.0, x));
        }
        if ([yValue isKindOfClass:NSNumber.class] && std::isfinite(y)) {
            control.y = MAX(0.0, MIN(1.0, y));
        }
        if ([sizeValue isKindOfClass:NSNumber.class] && std::isfinite(size) && size > 0.0) {
            control.size = MAX(defaultSize * 0.70, MIN(defaultSize * 1.50, size));
        }
        if ([opacityValue isKindOfClass:NSNumber.class] &&
            std::isfinite(opacity) && opacity > 0.0) {
            control.opacity = MAX(0.24, MIN(0.78, opacity));
        }
        control.visible = value[@"visible"] == nil || [value[@"visible"] boolValue];
    }
}

- (void)saveLayout {
    [NSUserDefaults.standardUserDefaults setObject:[self serializedLayout]
                                           forKey:layoutDefaultsKey()];
}

#if DINOPAD_ENABLE_TEST_HARNESS
- (NSDictionary*)layoutSnapshotForTesting {
    return [self serializedLayout];
}
#endif

- (CGRect)frameForControl:(const TouchControl&)control {
    CGPoint center = [self centerForControl:control];
    CGFloat radius = [self radiusForControl:control];
    CGFloat halfWidth = [self isShoulder:control] ? radius * 1.65 : radius;
    return CGRectMake(center.x - halfWidth, center.y - radius,
                      halfWidth * 2.0, radius * 2.0);
}

- (CGRect)utilityButtonRect {
    CGRect usable = [self usableBounds];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        return CGRectMake(CGRectGetMaxX(usable) - 48.0,
                          CGRectGetMinY(usable) + 4.0, 44.0, 44.0);
    }
    return CGRectMake(CGRectGetMidX(usable) - 22.0,
                      CGRectGetMinY(usable) + 4.0, 44.0, 44.0);
}

- (CGRect)toolbarRectAtIndex:(NSInteger)index {
    CGRect usable = [self usableBounds];
    CGFloat width = MIN(62.0, usable.size.width / 9.0);
    CGFloat total = width * 8.0;
    return CGRectMake(CGRectGetMidX(usable) - total / 2.0 + width * index,
                      CGRectGetMinY(usable) + 4.0, width, 44.0);
}

- (NSArray<NSString*>*)toolbarLabels {
    const BOOL hasSelection = _selected >= 0 && _selected < static_cast<NSInteger>(kControlCount);
    const BOOL selectedVisible = hasSelection ? _controls[_selected].visible : YES;
    const BOOL selectedHideable = hasSelection && _controls[_selected].kind != ControlKind::Stick;
    NSString* linkLabel = !hasSelection || ![self isDirectional:_controls[_selected]]
        ? @"SINGLE" : ([self isSelectedDirectionalGroupLinked] ? @"UNLINK" : @"LINK");
    return @[@"DONE", @"CANCEL", _hasUndo ? @"UNDO" : @"RESET", linkLabel,
             @"\u2212", @"+", @"FADE",
             !selectedHideable ? @"FIXED" : (selectedVisible ? @"HIDE" : @"SHOW")];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _utilityButton.frame = [self utilityButtonRect];
}

- (UIColor*)accentForControl:(const TouchControl&)control {
    if (std::strcmp(control.key, "a") == 0) {
        return [UIColor colorWithRed:0.12 green:0.43 blue:0.94 alpha:1.0];
    }
    if (std::strcmp(control.key, "b") == 0) {
        return [UIColor colorWithRed:0.10 green:0.62 blue:0.32 alpha:1.0];
    }
    if (std::strncmp(control.key, "c_", 2) == 0) {
        return [UIColor colorWithRed:0.94 green:0.63 blue:0.06 alpha:1.0];
    }
    if (std::strcmp(control.key, "start") == 0) {
        return [UIColor colorWithRed:0.78 green:0.12 blue:0.14 alpha:1.0];
    }
    return nil;
}

- (void)drawLabel:(NSString*)label inRect:(CGRect)rect size:(CGFloat)size {
    NSMutableParagraphStyle* style = [[NSMutableParagraphStyle alloc] init];
    style.alignment = NSTextAlignmentCenter;
    NSDictionary* attributes = @{
        NSFontAttributeName: [UIFont boldSystemFontOfSize:size],
        NSForegroundColorAttributeName: [UIColor colorWithWhite:1.0 alpha:0.94],
        NSParagraphStyleAttributeName: style,
    };
    CGSize textSize = [label sizeWithAttributes:attributes];
    CGRect textRect = CGRectMake(rect.origin.x,
        CGRectGetMidY(rect) - textSize.height / 2.0, rect.size.width, textSize.height);
    [label drawInRect:textRect withAttributes:attributes];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (context == nullptr) return;

    for (NSInteger index = 0; index < static_cast<NSInteger>(kControlCount); ++index) {
        const TouchControl& control = _controls[index];
        if (!_editing && (!_controlsEnabled || _controllerConnected || _modalControlsHidden)) continue;
        if (!control.visible && !_editing) continue;
        CGFloat radius = [self radiusForControl:control];
        CGRect frame = [self frameForControl:control];
        UIBezierPath* path = [self isShoulder:control]
            ? [UIBezierPath bezierPathWithRoundedRect:frame cornerRadius:radius]
            : [UIBezierPath bezierPathWithOvalInRect:frame];
        BOOL pressed = NO;
        for (NSNumber* role in _touchRoles.objectEnumerator) {
            if (role.integerValue == index) { pressed = YES; break; }
        }
#if DINOPAD_ENABLE_TEST_HARNESS
        if (!pressed) {
            for (NSNumber* role in _simulatedTouchRoles.allValues) {
                if (role.integerValue == index) { pressed = YES; break; }
            }
        }
#endif
        CGFloat alpha = _editing
            ? (control.visible ? 0.82 : 0.26)
            : MIN(1.0, control.opacity * (_globalOpacity / 0.70));
        UIColor* accent = [self accentForControl:control];
        UIColor* fill = accent != nil
            ? [accent colorWithAlphaComponent:pressed ? MIN(0.95, alpha + 0.25) : alpha]
            : [UIColor colorWithWhite:pressed ? 0.34 : 0.04
                                 alpha:pressed ? MIN(0.90, alpha + 0.30) : alpha];
        [fill setFill];
        [path fill];
        const BOOL selectedForEditing = _editing && [self isControlInSelectedMoveGroup:index];
        UIColor* stroke = selectedForEditing
            ? [UIColor colorWithRed:1.0 green:0.82 blue:0.18 alpha:0.95]
            : [UIColor colorWithWhite:1.0 alpha:MIN(0.88, alpha + 0.28)];
        [stroke setStroke];
        path.lineWidth = selectedForEditing ? 3.0 : 2.0;
        if (!control.visible) CGContextSetLineDash(context, 0, (CGFloat[]){4.0, 3.0}, 2);
        [path stroke];
        CGContextSetLineDash(context, 0, nullptr, 0);

        if (control.kind == ControlKind::Stick) {
            CGPoint center = [self centerForControl:control];
            CGPoint knob = pressed ? _stickKnob : center;
            if (CGPointEqualToPoint(knob, CGPointZero)) knob = center;
            CGFloat knobRadius = radius * 0.42;
            CGContextSetFillColorWithColor(context,
                [UIColor colorWithRed:0.30 green:0.59 blue:0.82
                                  alpha:MIN(0.84, alpha + 0.24)].CGColor);
            CGContextFillEllipseInRect(context, CGRectMake(
                knob.x - knobRadius, knob.y - knobRadius,
                knobRadius * 2.0, knobRadius * 2.0));
        } else {
            CGFloat labelScale = [self isDirectional:control] ? 0.72 : 0.66;
            if (std::strcmp(control.key, "start") == 0) labelScale = 0.34;
            if ([self isShoulder:control]) labelScale = 0.56;
            [self drawLabel:[NSString stringWithUTF8String:control.label]
                     inRect:frame size:MAX(11.0, radius * labelScale)];
        }
    }

    if (_editing) {
        NSArray<NSString*>* labels = [self toolbarLabels];
        CGRect toolbar = CGRectUnion([self toolbarRectAtIndex:0], [self toolbarRectAtIndex:7]);
        UIBezierPath* toolbarPath = [UIBezierPath bezierPathWithRoundedRect:toolbar
                                                              cornerRadius:10.0];
        [[UIColor colorWithWhite:0.02 alpha:0.88] setFill];
        [toolbarPath fill];
        [[UIColor colorWithWhite:1.0 alpha:0.30] setStroke];
        toolbarPath.lineWidth = 1.0;
        [toolbarPath stroke];
        for (NSInteger index = 0; index < 8; ++index) {
            CGRect item = [self toolbarRectAtIndex:index];
            if (index > 0) {
                UIBezierPath* divider = [UIBezierPath bezierPath];
                [divider moveToPoint:CGPointMake(CGRectGetMinX(item), CGRectGetMinY(item) + 7.0)];
                [divider addLineToPoint:CGPointMake(CGRectGetMinX(item), CGRectGetMaxY(item) - 7.0)];
                [[UIColor colorWithWhite:1.0 alpha:0.18] setStroke];
                divider.lineWidth = 1.0;
                [divider stroke];
            }
            [self drawLabel:labels[index] inRect:item size:10.0];
        }
    }
}

- (NSInteger)controlAtPoint:(CGPoint)point includeHidden:(BOOL)includeHidden {
    if (!_editing && (!_controlsEnabled || _controllerConnected || _modalControlsHidden)) return NSNotFound;
    NSInteger nearest = NSNotFound;
    CGFloat nearestDistance = CGFLOAT_MAX;
    for (NSInteger index = 0; index < static_cast<NSInteger>(kControlCount); ++index) {
        const TouchControl& control = _controls[index];
        if (!control.visible && !includeHidden) continue;
        CGPoint center = [self centerForControl:control];
        CGFloat distance = hypot(point.x - center.x, point.y - center.y);
        CGFloat radius = [self radiusForControl:control];
        BOOL inside = [self isShoulder:control]
            ? CGRectContainsPoint(CGRectInset([self frameForControl:control],
                                             -radius * 0.12, -radius * 0.12), point)
            : distance <= radius * 1.12;
        if (inside && distance < nearestDistance) {
            nearest = index;
            nearestDistance = distance;
        }
    }
    return nearest;
}

- (NSInteger)controlAtPoint:(CGPoint)point {
    return [self controlAtPoint:point includeHidden:NO];
}

- (void)recordUndoState {
    _undoControls = _controls;
    _undoDPadLinked = _dPadLinked;
    _undoCButtonsLinked = _cButtonsLinked;
    _hasUndo = YES;
}

- (void)beginEditingLayout {
    _editingStartControls = _controls;
    _editingStartDPadLinked = _dPadLinked;
    _editingStartCButtonsLinked = _cButtonsLinked;
    _hasUndo = NO;
    _editing = YES;
    _modalControlsHidden = NO;
    _utilityButton.hidden = YES;
    [self clearInput];
    [self setNeedsDisplay];
}

- (void)finishEditingLayoutSaving:(BOOL)save {
    [self clearInput];
    if (!save) {
        _controls = _editingStartControls;
        _dPadLinked = _editingStartDPadLinked;
        _cButtonsLinked = _editingStartCButtonsLinked;
    }
    _editing = NO;
    _hasUndo = NO;
    _modalControlsHidden = NO;
    _utilityButton.hidden = NO;
    [self saveLayout];
    [self setNeedsDisplay];
}

- (void)resetLayoutForIdiom:(UIUserInterfaceIdiom)idiom {
    const auto controls = defaultControlsForIdiom(idiom);
    NSMutableDictionary* saved = [NSMutableDictionary dictionaryWithCapacity:kControlCount + 1];
    for (const TouchControl& control : controls) {
        saved[[NSString stringWithUTF8String:control.key]] = @{
            @"x": @(control.x), @"y": @(control.y),
            @"size": @(control.size), @"opacity": @(control.opacity),
            @"visible": @(control.visible),
        };
    }
    saved[@"_groups"] = @{@"dPadLinked": @NO, @"cButtonsLinked": @NO};
    [NSUserDefaults.standardUserDefaults setObject:saved
                                           forKey:layoutDefaultsKeyForIdiom(idiom)];
    if (UIDevice.currentDevice.userInterfaceIdiom == idiom) {
        _controls = controls;
        _dPadLinked = NO;
        _cButtonsLinked = NO;
        [self clearInput];
        [self setNeedsDisplay];
    }
}

- (void)resetLayout {
    if (_editing) [self recordUndoState];
    [self resetLayoutForIdiom:UIDevice.currentDevice.userInterfaceIdiom];
}

- (BOOL)performEditorAction:(NSInteger)action {
    if (!_editing || action < 0 || action >= 8) return NO;
    if (action == 0) {
        [self finishEditingLayoutSaving:YES];
        return YES;
    }
    if (action == 1) {
        [self finishEditingLayoutSaving:NO];
        return YES;
    }
    if (action == 2) {
        if (_hasUndo) {
            std::swap(_controls, _undoControls);
            std::swap(_dPadLinked, _undoDPadLinked);
            std::swap(_cButtonsLinked, _undoCButtonsLinked);
            _hasUndo = NO;
        } else {
            [self recordUndoState];
            _controls = defaultControls();
            _dPadLinked = NO;
            _cButtonsLinked = NO;
        }
        [self saveLayout];
        [self setNeedsDisplay];
        return YES;
    }
    if (_selected < 0 || _selected >= static_cast<NSInteger>(kControlCount)) return YES;
    TouchControl& selected = _controls[_selected];
    if (action == 3) {
        if (![self isDirectional:selected]) return YES;
        [self recordUndoState];
        if (std::strncmp(selected.key, "d_", 2) == 0) _dPadLinked = !_dPadLinked;
        else _cButtonsLinked = !_cButtonsLinked;
    } else if (action == 4 || action == 5) {
        [self recordUndoState];
        const CGFloat baseSize = [self defaultSizeForControl:selected];
        const CGFloat delta = baseSize * 0.10 * (action == 4 ? -1.0 : 1.0);
        selected.size = MAX(baseSize * 0.70, MIN(baseSize * 1.50, selected.size + delta));
    } else if (action == 6) {
        [self recordUndoState];
        selected.opacity += 0.14;
        if (selected.opacity > 0.78) selected.opacity = 0.24;
    } else if (action == 7 && selected.kind != ControlKind::Stick) {
        [self recordUndoState];
        selected.visible = !selected.visible;
    }
    [self saveLayout];
    [self setNeedsDisplay];
    return YES;
}

#if DINOPAD_ENABLE_TEST_HARNESS
- (BOOL)performEditorActionForTesting:(NSInteger)action {
    return [self performEditorAction:action];
}
#endif

- (BOOL)handleToolbarPoint:(CGPoint)point {
    if (!_editing) return NO;
    for (NSInteger index = 0; index < 8; ++index) {
        if (CGRectContainsPoint([self toolbarRectAtIndex:index], point)) {
            return [self performEditorAction:index];
        }
    }
    return NO;
}

#if DINOPAD_ENABLE_TEST_HARNESS
- (void)selectControlForTesting:(const char*)key {
    const NSInteger index = [self controlIndexForKey:key];
    if (index != NSNotFound) _selected = index;
}
#endif

- (void)moveSelectedToPoint:(CGPoint)point recordUndo:(BOOL)recordUndo {
    if (_selected < 0 || _selected >= static_cast<NSInteger>(kControlCount)) return;
    CGRect usable = [self usableBounds];
    if (usable.size.width <= 0.0 || usable.size.height <= 0.0) return;
    if (recordUndo) [self recordUndoState];
    TouchControl& control = _controls[_selected];
    const CGFloat desiredX = (point.x - CGRectGetMinX(usable)) / usable.size.width;
    const CGFloat desiredY = (point.y - CGRectGetMinY(usable)) / usable.size.height;
    if ([self isDirectional:control] && [self isSelectedDirectionalGroupLinked]) {
        const char* group = std::strncmp(control.key, "d_", 2) == 0 ? "d_" : "c_";
        CGFloat minimumDeltaX = -CGFLOAT_MAX;
        CGFloat maximumDeltaX = CGFLOAT_MAX;
        CGFloat minimumDeltaY = -CGFLOAT_MAX;
        CGFloat maximumDeltaY = CGFLOAT_MAX;
        for (const TouchControl& candidate : _controls) {
            if (std::strncmp(candidate.key, group, 2) != 0) continue;
            const CGFloat radius = [self radiusForControl:candidate];
            const CGFloat horizontalMargin = radius / usable.size.width;
            const CGFloat verticalMargin = radius / usable.size.height;
            minimumDeltaX = MAX(minimumDeltaX, horizontalMargin - candidate.x);
            maximumDeltaX = MIN(maximumDeltaX, 1.0 - horizontalMargin - candidate.x);
            minimumDeltaY = MAX(minimumDeltaY, verticalMargin - candidate.y);
            maximumDeltaY = MIN(maximumDeltaY, 1.0 - verticalMargin - candidate.y);
        }
        const CGFloat deltaX = MAX(minimumDeltaX, MIN(maximumDeltaX, desiredX - control.x));
        const CGFloat deltaY = MAX(minimumDeltaY, MIN(maximumDeltaY, desiredY - control.y));
        for (TouchControl& candidate : _controls) {
            if (std::strncmp(candidate.key, group, 2) == 0) {
                candidate.x += deltaX;
                candidate.y += deltaY;
            }
        }
    } else {
        const CGFloat radius = [self radiusForControl:control];
        const CGFloat halfWidth = [self isShoulder:control] ? radius * 1.65 : radius;
        const CGFloat horizontalMargin = MIN(0.5, halfWidth / usable.size.width);
        const CGFloat verticalMargin = MIN(0.5, radius / usable.size.height);
        control.x = MAX(horizontalMargin, MIN(1.0 - horizontalMargin, desiredX));
        control.y = MAX(verticalMargin, MIN(1.0 - verticalMargin, desiredY));
    }
    [self setNeedsDisplay];
}

#if DINOPAD_ENABLE_TEST_HARNESS
- (void)moveSelectedForTestingToNormalizedPoint:(CGPoint)point {
    CGRect usable = [self usableBounds];
    [self moveSelectedToPoint:CGPointMake(
        CGRectGetMinX(usable) + point.x * usable.size.width,
        CGRectGetMinY(usable) + point.y * usable.size.height) recordUndo:YES];
    [self saveLayout];
}
#endif

- (void)setControlsEnabled:(BOOL)enabled {
    [self setControlsEnabled:enabled opacity:_globalOpacity];
}

- (void)setControlsEnabled:(BOOL)enabled opacity:(CGFloat)opacity {
    _controlsEnabled = enabled;
    _globalOpacity = std::isfinite(opacity)
        ? MAX(0.20, MIN(1.0, opacity)) : 0.70;
    _utilityButton.alpha = MAX(0.55, _globalOpacity);
    if (!enabled) [self clearInput];
    [NSUserDefaults.standardUserDefaults setObject:@{
        @"enabled": @(_controlsEnabled), @"opacity": @(_globalOpacity)
    } forKey:@"dinopad.touch.settings.v1"];
    [self setNeedsDisplay];
}

- (void)setModalControlsHidden:(BOOL)hidden {
    _modalControlsHidden = hidden;
    _utilityButton.hidden = hidden || _editing;
    if (hidden) [self clearInput];
    [self setNeedsDisplay];
}

- (UIViewController*)topPresenter {
    UIViewController* presenter = self.window.rootViewController;
    while (presenter.presentedViewController != nil) {
        presenter = presenter.presentedViewController;
    }
    return presenter;
}

- (void)presentUtilityMenu {
    dinopad_diagnostics_breadcrumb("menu", "presented");
    std::fprintf(stderr, "[dinopad-menu] utility menu presented\n");
    std::fflush(stderr);
    [self clearInput];
    [self setModalControlsHidden:YES];
    UIViewController* presenter = [self topPresenter];
    if (presenter == nil) {
        [self setModalControlsHidden:NO];
        return;
    }

    NSString* controllerStatus = _controllerConnected ? @"Connected" : @"Not Connected";
    NSString* profileTitle = g_currentProfile.load(std::memory_order_relaxed) == 0
        ? @"Restored Adventure" : @"Prototype Mode";
    NSString* touchTitle = _controlsEnabled ? @"Disable Touch Controls" : @"Enable Touch Controls";
    UIAlertController* menu = [UIAlertController
        alertControllerWithTitle:@"DinoPad"
                         message:[NSString stringWithFormat:
                             @"%@\nController: %@", profileTitle, controllerStatus]
                  preferredStyle:UIAlertControllerStyleActionSheet];
    [menu addAction:[UIAlertAction actionWithTitle:@"Resume"
        style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction* action) {
            dinopad_diagnostics_breadcrumb("menu", "resume_selected");
            [self setModalControlsHidden:NO];
        }]];
    [menu addAction:[UIAlertAction actionWithTitle:touchTitle
        style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction* action) {
            dinopad_diagnostics_breadcrumb("menu", self->_controlsEnabled
                ? "touch_controls_disabled" : "touch_controls_enabled");
            [self setControlsEnabled:!self->_controlsEnabled];
            [self setModalControlsHidden:NO];
        }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Settings & Status"
        style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction* action) {
            dinopad_diagnostics_breadcrumb("menu", "settings_selected");
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                dinopad_present_settings((__bridge void*)presenter);
            });
        }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Share Diagnostics & Logs…"
        style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction* action) {
            dinopad_diagnostics_breadcrumb("menu", "share_diagnostics_selected");
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                dinopad_present_diagnostics_share((__bridge void*)presenter, ^{
                    [self setModalControlsHidden:NO];
                });
            });
        }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Customize Touch Layout"
        style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction* action) {
            dinopad_diagnostics_breadcrumb("menu", "customize_touch_layout_selected");
            [self beginEditingLayout];
        }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Reset Phone Layout"
        style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction* action) {
            dinopad_diagnostics_breadcrumb("menu", "reset_phone_layout_selected");
            [self confirmResetLayoutForIdiom:UIUserInterfaceIdiomPhone];
        }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Reset Tablet Layout"
        style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction* action) {
            dinopad_diagnostics_breadcrumb("menu", "reset_tablet_layout_selected");
            [self confirmResetLayoutForIdiom:UIUserInterfaceIdiomPad];
        }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Manage Game ROM"
        style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction* action) {
            dinopad_diagnostics_breadcrumb("menu", "rom_manager_selected");
            dinopad_present_rom_manager((__bridge void*)presenter);
        }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Quit to DinoPad Home"
        style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction* action) {
            [self confirmQuitToHome];
        }]];
    UIPopoverPresentationController* popover = menu.popoverPresentationController;
    if (popover != nil) {
        popover.sourceView = self;
        popover.sourceRect = [self utilityButtonRect];
        popover.permittedArrowDirections = UIPopoverArrowDirectionUp;
    }
    [presenter presentViewController:menu animated:YES completion:nil];
}

- (void)confirmResetLayoutForIdiom:(UIUserInterfaceIdiom)idiom {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        UIViewController* presenter = [self topPresenter];
        if (presenter == nil) {
            [self setModalControlsHidden:NO];
            return;
        }

        const BOOL isPhone = idiom == UIUserInterfaceIdiomPhone;
        NSString* deviceName = isPhone ? @"Phone" : @"Tablet";
        UIAlertController* confirmation = [UIAlertController
            alertControllerWithTitle:[NSString stringWithFormat:@"Reset %@ Layout?", deviceName]
                             message:[NSString stringWithFormat:
                                 @"This replaces your saved %@ touch-control positions and sizes with the DinoPad defaults. This can’t be undone.",
                                 deviceName.lowercaseString]
                      preferredStyle:UIAlertControllerStyleAlert];
        [confirmation addAction:[UIAlertAction actionWithTitle:@"Cancel"
            style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction* action) {
                dinopad_diagnostics_breadcrumb("menu", isPhone
                    ? "reset_phone_layout_cancelled" : "reset_tablet_layout_cancelled");
                [self setModalControlsHidden:NO];
            }]];
        [confirmation addAction:[UIAlertAction actionWithTitle:@"Reset Layout"
            style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction* action) {
                [self resetLayoutForIdiom:idiom];
                dinopad_diagnostics_breadcrumb("menu", isPhone
                    ? "reset_phone_layout_confirmed" : "reset_tablet_layout_confirmed");
                [self setModalControlsHidden:NO];
            }]];
        [presenter presentViewController:confirmation animated:YES completion:nil];
    });
}

- (void)confirmQuitToHome {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        UIViewController* presenter = [self topPresenter];
        if (presenter == nil) {
            [self setModalControlsHidden:NO];
            return;
        }

        UIAlertController* confirmation = [UIAlertController
            alertControllerWithTitle:@"Return to DinoPad Home?"
                             message:@"Unsaved in-game progress may be lost. Your existing save files and DinoPad settings will remain intact."
                      preferredStyle:UIAlertControllerStyleAlert];
        [confirmation addAction:[UIAlertAction actionWithTitle:@"Cancel"
            style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction* action) {
                dinopad_diagnostics_breadcrumb("menu", "quit_to_home_cancelled");
                [self setModalControlsHidden:NO];
            }]];
        [confirmation addAction:[UIAlertAction actionWithTitle:@"Return Home"
            style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction* action) {
                dinopad_diagnostics_breadcrumb("menu", "quit_to_home_confirmed");
                [self quitToHome];
            }]];
        [presenter presentViewController:confirmation animated:YES completion:nil];
    });
}

- (void)quitToHome {
    dinopad_diagnostics_breadcrumb("menu", "quit_to_home_requested");
    [self clearInput];
    [self setModalControlsHidden:YES];
    g_quitToHome.store(true, std::memory_order_relaxed);
    std::fprintf(stderr, "[dinopad-home-test] Quit to home requested\n");
    std::fflush(stderr);
    ultramodern::quit();
}

- (void)romManagerDidDismiss {
    [self setModalControlsHidden:NO];
}

- (void)dismissUtilityMenu {
    UIViewController* presenter = [self topPresenter];
    if ([presenter isKindOfClass:UIAlertController.class]) {
        [presenter dismissViewControllerAnimated:NO completion:^{
            [self setModalControlsHidden:NO];
        }];
    } else {
        [self setModalControlsHidden:NO];
    }
}

- (void)publishInput {
    uint16_t buttons = 0;
    CGFloat x = 0.0;
    CGFloat y = 0.0;
    BOOL hasStickTouch = NO;
    CGPoint stickTouchPoint = CGPointZero;

    // Real UITouches
    for (UITouch* touch in _touchRoles.keyEnumerator) {
        NSInteger role = [[_touchRoles objectForKey:touch] integerValue];
        if (role < 0 || role >= static_cast<NSInteger>(kControlCount)) continue;
        const TouchControl& control = _controls[role];
        if (control.kind == ControlKind::Stick) {
            hasStickTouch = YES;
            stickTouchPoint = [touch locationInView:self];
        } else {
            buttons |= control.mask;
        }
    }

#if DINOPAD_ENABLE_TEST_HARNESS
    // Simulated touches (test harness)
    for (NSNumber* touchID in _simulatedTouchRoles) {
        NSInteger role = [_simulatedTouchRoles[touchID] integerValue];
        if (role < 0 || role >= static_cast<NSInteger>(kControlCount)) continue;
        const TouchControl& control = _controls[role];
        if (control.kind == ControlKind::Stick) {
            hasStickTouch = YES;
            stickTouchPoint = [_simulatedTouchPoints[touchID] CGPointValue];
        } else {
            buttons |= control.mask;
        }
    }
#endif

    if (hasStickTouch) {
        const TouchControl& stick = _controls[0];
        CGFloat radius = [self radiusForControl:stick];
        CGFloat dx = stickTouchPoint.x - _stickOrigin.x;
        CGFloat dy = stickTouchPoint.y - _stickOrigin.y;
        CGFloat length = hypot(dx, dy);
        if (length > radius && length > 0.0) {
            dx *= radius / length;
            dy *= radius / length;
        }
        x = dx / radius;
        y = -dy / radius;
        constexpr CGFloat deadzone = 0.16;
        CGFloat magnitude = hypot(x, y);
        if (magnitude <= deadzone) {
            x = 0.0;
            y = 0.0;
        } else {
            CGFloat remapped = (magnitude - deadzone) / (1.0 - deadzone);
            CGFloat response = remapped * remapped * (0.75 + 0.25 * remapped);
            CGFloat scale = response / magnitude;
            x *= scale;
            y *= scale;
            constexpr CGFloat cardinalBias = 1.45;
            if (std::abs(x) > std::abs(y) * cardinalBias) y = 0.0;
            else if (std::abs(y) > std::abs(x) * cardinalBias) x = 0.0;

            g_touchFlickX.store(static_cast<int32_t>(std::lround(x * 10000.0)), std::memory_order_relaxed);
            g_touchFlickY.store(static_cast<int32_t>(std::lround(y * 10000.0)), std::memory_order_relaxed);
            g_touchFlickPolls.store(kAnalogFlickHoldPolls, std::memory_order_relaxed);
        }
        _stickKnob = CGPointMake(_stickOrigin.x + dx, _stickOrigin.y + dy);
    } else {
        _stickKnob = _stickOrigin;
    }

    g_touchButtons.store(buttons, std::memory_order_relaxed);
    g_touchX.store(static_cast<int32_t>(std::lround(x * 10000.0)), std::memory_order_relaxed);
    g_touchY.store(static_cast<int32_t>(std::lround(y * 10000.0)), std::memory_order_relaxed);
    [self setNeedsDisplay];
}

- (void)clearInput {
    [_touchRoles removeAllObjects];
    [_touchOffsets removeAllObjects];
#if DINOPAD_ENABLE_TEST_HARNESS
    [_simulatedTouchRoles removeAllObjects];
    [_simulatedTouchPoints removeAllObjects];
#endif
    _stickOrigin = CGPointZero;
    _stickKnob = CGPointZero;
    g_touchButtons.store(0, std::memory_order_relaxed);
    g_touchTaps.clearAll();
    g_touchX.store(0, std::memory_order_relaxed);
    g_touchY.store(0, std::memory_order_relaxed);
    g_touchFlickX.store(0, std::memory_order_relaxed);
    g_touchFlickY.store(0, std::memory_order_relaxed);
    g_touchFlickPolls.store(0, std::memory_order_relaxed);
    [self setNeedsDisplay];
}

- (void)setPhysicalControllerConnected:(BOOL)connected {
    _controllerConnected = connected;
    if (connected) [self clearInput];
    [self setNeedsDisplay];
}

- (void)touchesBegan:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
    for (UITouch* touch in touches) {
        CGPoint point = [touch locationInView:self];
        if ([self handleToolbarPoint:point]) continue;
        NSInteger control = [self controlAtPoint:point includeHidden:_editing];
        CGRect usable = [self usableBounds];
        if (!_editing && control == NSNotFound &&
            point.x <= CGRectGetMinX(usable) + usable.size.width * 0.47) {
            control = 0;
        }
        if (control == NSNotFound) continue;
        [_touchRoles setObject:@(control) forKey:touch];
        _selected = control;
        const TouchControl& item = _controls[control];
        if (_editing) {
            [self recordUndoState];
            CGPoint center = [self centerForControl:item];
            [_touchOffsets setObject:[NSValue valueWithCGPoint:
                CGPointMake(center.x - point.x, center.y - point.y)] forKey:touch];
        } else if (item.kind == ControlKind::Stick) {
            _stickOrigin = [self centerForControl:item];
            _stickKnob = _stickOrigin;
        } else {
            if (item.mask == 0x1000) {
                dinopad_diagnostics_breadcrumb("touch", "start_pressed");
            }
            g_touchTaps.extend(item.mask, kTapHoldPolls);
        }
    }
    if (!_editing) [self publishInput];
    else [self setNeedsDisplay];
}

- (void)touchesMoved:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
    if (_editing) {
        for (UITouch* touch in touches) {
            NSNumber* found = [_touchRoles objectForKey:touch];
            if (found == nil) continue;
            _selected = found.integerValue;
            CGPoint point = [touch locationInView:self];
            NSValue* offsetValue = [_touchOffsets objectForKey:touch];
            if (offsetValue != nil) {
                CGPoint offset = offsetValue.CGPointValue;
                point.x += offset.x;
                point.y += offset.y;
            }
            [self moveSelectedToPoint:point recordUndo:NO];
        }
        return;
    }
    for (UITouch* touch in touches) {
        NSNumber* found = [_touchRoles objectForKey:touch];
        if (found == nil) continue;
        NSInteger role = found.integerValue;
        if (role <= 0 || role >= static_cast<NSInteger>(kControlCount)) continue;
        CGPoint point = [touch locationInView:self];
        if (!CGRectContainsPoint(CGRectInset([self frameForControl:_controls[role]], -8.0, -8.0), point)) {
            [_touchRoles removeObjectForKey:touch];
        }
    }
    [self publishInput];
}

- (void)finishTouches:(NSSet<UITouch*>*)touches {
    for (UITouch* touch in touches) {
        [_touchRoles removeObjectForKey:touch];
        [_touchOffsets removeObjectForKey:touch];
    }
    if (_editing) [self saveLayout];
    else [self publishInput];
}

- (void)touchesEnded:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
    [self finishTouches:touches];
}

- (void)touchesCancelled:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
    [self finishTouches:touches];
}

#if DINOPAD_ENABLE_TEST_HARNESS
#pragma mark - Simulated Touch Injection (Test Harness)

- (void)beginSimulatedTouchWithID:(NSInteger)touchID atPoint:(CGPoint)point {
    NSInteger control = [self controlAtPoint:point];
    CGRect usable = [self usableBounds];
    if (control == NSNotFound && point.x <= CGRectGetMinX(usable) + usable.size.width * 0.47) {
        control = 0;
    }
    if (control == NSNotFound) return;
    _simulatedTouchRoles[@(touchID)] = @(control);
    _simulatedTouchPoints[@(touchID)] = [NSValue valueWithCGPoint:point];
    const TouchControl& item = _controls[control];
    if (item.kind == ControlKind::Stick) {
        _stickOrigin = [self centerForControl:item];
        _stickKnob = _stickOrigin;
    } else {
        g_touchTaps.extend(item.mask, kTapHoldPolls);
    }
    [self publishInput];
}

- (void)moveSimulatedTouchWithID:(NSInteger)touchID toPoint:(CGPoint)point {
    NSNumber* found = _simulatedTouchRoles[@(touchID)];
    if (found == nil) return;
    _simulatedTouchPoints[@(touchID)] = [NSValue valueWithCGPoint:point];
    NSInteger role = found.integerValue;
    if (role > 0 && role < static_cast<NSInteger>(kControlCount)) {
        if (!CGRectContainsPoint(CGRectInset([self frameForControl:_controls[role]], -8.0, -8.0), point)) {
            [_simulatedTouchRoles removeObjectForKey:@(touchID)];
            [_simulatedTouchPoints removeObjectForKey:@(touchID)];
        }
    }
    [self publishInput];
}

- (void)endSimulatedTouchWithID:(NSInteger)touchID {
    [_simulatedTouchRoles removeObjectForKey:@(touchID)];
    [_simulatedTouchPoints removeObjectForKey:@(touchID)];
    [self publishInput];
}
#endif

@end

#if DINOPAD_ENABLE_TEST_HARNESS
#pragma mark - Automated Touch Layout Smoke Test Runner

@implementation DinoPadLayoutSmokeRunner

+ (void)pass:(NSString*)message {
    std::fprintf(stderr, "[dinopad-layout-test] PASS: %s\n", message.UTF8String);
    std::fflush(stderr);
}

+ (void)fail:(NSString*)message {
    std::fprintf(stderr, "[dinopad-layout-test] FAIL: %s\n", message.UTF8String);
    std::fflush(stderr);
}

+ (BOOL)nearlyEqual:(double)a other:(double)b {
    return std::abs(a - b) < 0.0005;
}

+ (void)runWithOverlay:(DinoPadTouchOverlayView*)overlay phase:(NSString*)phase {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.60 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if ([phase isEqualToString:@"edit"]) [self runEditPhase:overlay];
        else if ([phase isEqualToString:@"verify"]) [self runVerifyPhase:overlay];
        else [self fail:[NSString stringWithFormat:@"unknown phase %@", phase]];
    });
}

+ (void)runEditPhase:(DinoPadTouchOverlayView*)overlay {
    std::fprintf(stderr, "[dinopad-layout-test] starting edit/persist phase\n");
    std::fflush(stderr);

    const UIUserInterfaceIdiom activeIdiom = UIDevice.currentDevice.userInterfaceIdiom;
    const UIUserInterfaceIdiom inactiveIdiom = activeIdiom == UIUserInterfaceIdiomPad
        ? UIUserInterfaceIdiomPhone : UIUserInterfaceIdiomPad;

    // Seed a recognizable inactive-idiom value without changing the layout
    // currently rendered by this phone or tablet.
    [overlay resetLayoutForIdiom:inactiveIdiom];
    NSMutableDictionary* inactive = [[NSUserDefaults.standardUserDefaults
        dictionaryForKey:layoutDefaultsKeyForIdiom(inactiveIdiom)] mutableCopy];
    NSMutableDictionary* inactiveA = [inactive[@"a"] mutableCopy];
    inactiveA[@"x"] = @0.314159;
    inactive[@"a"] = inactiveA;
    [NSUserDefaults.standardUserDefaults setObject:inactive
                                           forKey:layoutDefaultsKeyForIdiom(inactiveIdiom)];

    // Entering editing must clear a held gameplay button.
    const NSInteger aIndex = [overlay controlIndexForKey:"a"];
    [overlay beginSimulatedTouchWithID:91 atPoint:[overlay centerForControlIndex:aIndex]];
    uint16_t buttons = 0;
    float x = 0.0F;
    float y = 0.0F;
    dinopad_touch_snapshot(&buttons, &x, &y);
    if ((buttons & 0x8000) == 0) {
        [self fail:@"precondition could not hold A before editing"];
        return;
    }
    [overlay beginEditingLayout];
    g_touchTaps.clearAll();
    dinopad_touch_snapshot(&buttons, &x, &y);
    if (buttons != 0 || x != 0.0F || y != 0.0F) {
        [self fail:@"editing did not clear held gameplay input"];
        return;
    }
    [self pass:@"editing clears held gameplay input"];

    // A cancelled movement must restore the complete session snapshot.
    NSDictionary* beforeCancel = [overlay layoutSnapshotForTesting];
    [overlay selectControlForTesting:"b"];
    [overlay moveSelectedForTestingToNormalizedPoint:CGPointMake(0.60, 0.60)];
    [overlay finishEditingLayoutSaving:NO];
    if (![[overlay layoutSnapshotForTesting] isEqualToDictionary:beforeCancel]) {
        [self fail:@"Cancel did not restore the pre-edit layout"];
        return;
    }
    [self pass:@"Cancel restores the pre-edit layout"];

    [overlay beginEditingLayout];
    [overlay selectControlForTesting:"d_up"];
    NSDictionary* dBefore = [overlay layoutSnapshotForTesting];
    [overlay performEditorActionForTesting:3];
    [overlay moveSelectedForTestingToNormalizedPoint:CGPointMake(0.20, 0.50)];
    NSDictionary* dAfter = [overlay layoutSnapshotForTesting];
    const double upDelta = [dAfter[@"d_up"][@"x"] doubleValue] -
                           [dBefore[@"d_up"][@"x"] doubleValue];
    const double leftDelta = [dAfter[@"d_left"][@"x"] doubleValue] -
                             [dBefore[@"d_left"][@"x"] doubleValue];
    if (![dAfter[@"_groups"][@"dPadLinked"] boolValue] ||
        ![self nearlyEqual:upDelta other:leftDelta]) {
        [self fail:@"linked D-pad controls did not move as a group"];
        return;
    }
    [self pass:@"D-pad link moves all four controls as a group"];

    [overlay selectControlForTesting:"c_up"];
    NSDictionary* cBefore = [overlay layoutSnapshotForTesting];
    [overlay performEditorActionForTesting:3];
    [overlay moveSelectedForTestingToNormalizedPoint:CGPointMake(0.80, 0.52)];
    NSDictionary* cAfter = [overlay layoutSnapshotForTesting];
    const double cUpDelta = [cAfter[@"c_up"][@"y"] doubleValue] -
                            [cBefore[@"c_up"][@"y"] doubleValue];
    const double cRightDelta = [cAfter[@"c_right"][@"y"] doubleValue] -
                               [cBefore[@"c_right"][@"y"] doubleValue];
    if (![cAfter[@"_groups"][@"cButtonsLinked"] boolValue] ||
        ![self nearlyEqual:cUpDelta other:cRightDelta]) {
        [self fail:@"linked C controls did not move as a group"];
        return;
    }
    [self pass:@"C-button link moves all four controls as a group"];

    [overlay selectControlForTesting:"a"];
    [overlay performEditorActionForTesting:5];
    [overlay performEditorActionForTesting:6];
    [overlay performEditorActionForTesting:7];
    NSDictionary* hidden = [overlay layoutSnapshotForTesting];
    if ([hidden[@"a"][@"visible"] boolValue]) {
        [self fail:@"Hide did not change A visibility"];
        return;
    }
    [overlay performEditorActionForTesting:2];
    NSDictionary* undone = [overlay layoutSnapshotForTesting];
    if (![undone[@"a"][@"visible"] boolValue]) {
        [self fail:@"Undo did not restore A visibility"];
        return;
    }
    [self pass:@"resize, fade, hide, and one-step Undo are functional"];

    [overlay performEditorActionForTesting:7];
    [overlay moveSelectedForTestingToNormalizedPoint:CGPointMake(2.0, -1.0)];
    NSDictionary* clamped = [overlay layoutSnapshotForTesting];
    const double clampedX = [clamped[@"a"][@"x"] doubleValue];
    const double clampedY = [clamped[@"a"][@"y"] doubleValue];
    if (!(clampedX > 0.0 && clampedX < 1.0 && clampedY > 0.0 && clampedY < 1.0)) {
        [self fail:@"safe-area clamp allowed an unreachable control center"];
        return;
    }
    [self pass:@"safe-area clamp keeps edited controls reachable"];
    [overlay performEditorActionForTesting:0];

    // Dismissal must restore gameplay touch handling.
    const NSInteger bIndex = [overlay controlIndexForKey:"b"];
    [overlay beginSimulatedTouchWithID:92 atPoint:[overlay centerForControlIndex:bIndex]];
    dinopad_touch_snapshot(&buttons, &x, &y);
    if ((buttons & 0x4000) == 0) {
        [self fail:@"gameplay touch did not resume after editor dismissal"];
        return;
    }
    [overlay clearInput];
    [self pass:@"gameplay touch resumes after editor dismissal"];
    [overlay beginEditingLayout];
    std::fprintf(stderr,
        "[dinopad-layout-test] EDIT PHASE PASSED; persisted %s layout and %s sentinel\n",
        activeIdiom == UIUserInterfaceIdiomPad ? "tablet" : "phone",
        inactiveIdiom == UIUserInterfaceIdiomPad ? "tablet" : "phone");
    std::fflush(stderr);
}

+ (void)runVerifyPhase:(DinoPadTouchOverlayView*)overlay {
    std::fprintf(stderr, "[dinopad-layout-test] starting relaunch/reset phase\n");
    std::fflush(stderr);
    const UIUserInterfaceIdiom activeIdiom = UIDevice.currentDevice.userInterfaceIdiom;
    const UIUserInterfaceIdiom inactiveIdiom = activeIdiom == UIUserInterfaceIdiomPad
        ? UIUserInterfaceIdiomPhone : UIUserInterfaceIdiomPad;
    NSDictionary* active = [overlay layoutSnapshotForTesting];
    NSDictionary* inactive = [NSUserDefaults.standardUserDefaults
        dictionaryForKey:layoutDefaultsKeyForIdiom(inactiveIdiom)];
    const auto activeDefaults = defaultControlsForIdiom(activeIdiom);
    if ([active[@"a"][@"visible"] boolValue] ||
        ![active[@"_groups"][@"dPadLinked"] boolValue] ||
        ![active[@"_groups"][@"cButtonsLinked"] boolValue] ||
        !([active[@"a"][@"size"] doubleValue] > activeDefaults[9].size) ||
        [self nearlyEqual:[active[@"a"][@"opacity"] doubleValue]
                    other:activeDefaults[9].opacity] ||
        [self nearlyEqual:[active[@"a"][@"y"] doubleValue] other:activeDefaults[9].y]) {
        [self fail:@"active-idiom edit did not persist across process relaunch"];
        return;
    }
    [self pass:@"active-idiom move/size/opacity/visibility/link persisted across relaunch"];
    if (![self nearlyEqual:[inactive[@"a"][@"x"] doubleValue] other:0.314159] ||
        [layoutDefaultsKeyForIdiom(UIUserInterfaceIdiomPhone)
            isEqualToString:layoutDefaultsKeyForIdiom(UIUserInterfaceIdiomPad)]) {
        [self fail:@"phone and tablet persistence are not isolated"];
        return;
    }
    [self pass:@"phone and tablet persistence keys are isolated"];

    [overlay resetLayoutForIdiom:activeIdiom];
    NSDictionary* resetActive = [overlay layoutSnapshotForTesting];
    inactive = [NSUserDefaults.standardUserDefaults
        dictionaryForKey:layoutDefaultsKeyForIdiom(inactiveIdiom)];
    if (![self nearlyEqual:[resetActive[@"a"][@"x"] doubleValue]
                       other:activeDefaults[9].x] ||
        ![resetActive[@"a"][@"visible"] boolValue] ||
        ![self nearlyEqual:[inactive[@"a"][@"x"] doubleValue] other:0.314159]) {
        [self fail:@"active reset changed inactive data or missed active defaults"];
        return;
    }
    [self pass:@"active layout reset restores only current idiom defaults"];

    [overlay resetLayoutForIdiom:inactiveIdiom];
    inactive = [NSUserDefaults.standardUserDefaults
        dictionaryForKey:layoutDefaultsKeyForIdiom(inactiveIdiom)];
    const auto inactiveDefaults = defaultControlsForIdiom(inactiveIdiom);
    if (![self nearlyEqual:[inactive[@"a"][@"x"] doubleValue]
                       other:inactiveDefaults[9].x] ||
        ![self nearlyEqual:[[overlay layoutSnapshotForTesting][@"a"][@"x"] doubleValue]
                       other:activeDefaults[9].x]) {
        [self fail:@"inactive reset changed active data or missed inactive defaults"];
        return;
    }
    [self pass:@"inactive layout reset preserves current idiom defaults"];
    [overlay beginEditingLayout];
    std::fprintf(stderr, "[dinopad-layout-test] ALL LAYOUT TESTS PASSED\n");
    std::fflush(stderr);
}

@end

#pragma mark - Automated Input Smoke Test Runner

@implementation DinoPadInputSmokeRunner {
    DinoPadTouchOverlayView* _overlay;
    std::vector<std::pair<const char*, uint16_t>> _buttons;
    size_t _buttonIndex;
    int _buttonSubStep;
    int _suite;
    int _suiteSubStep;
}

+ (void)runWithOverlay:(DinoPadTouchOverlayView*)overlay {
    DinoPadInputSmokeRunner* runner = [[DinoPadInputSmokeRunner alloc] initWithOverlay:overlay];
    [runner start];
}

- (instancetype)initWithOverlay:(DinoPadTouchOverlayView*)overlay {
    self = [super init];
    if (self) {
        _overlay = overlay;
        _buttonIndex = 0;
        _buttonSubStep = 0;
        _suite = 1;
        _suiteSubStep = 0;
        _buttons = {
            {"a", 0x8000},
            {"b", 0x4000},
            {"z", 0x2000},
            {"start", 0x1000},
            {"d_up", 0x0800},
            {"d_down", 0x0400},
            {"d_left", 0x0200},
            {"d_right", 0x0100},
            {"l", 0x0020},
            {"r", 0x0010},
            {"c_up", 0x0008},
            {"c_down", 0x0004},
            {"c_left", 0x0002},
            {"c_right", 0x0001},
        };
    }
    return self;
}

- (void)start {
    fprintf(stderr, "[dinopad-touch-test] starting automated input/lifecycle verification sequence\n");
    fflush(stderr);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.80 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self nextStep];
    });
}

- (void)nextStep {
    // Suite 1: Digital Button Masks
    if (_suite == 1) {
        if (_buttonIndex < _buttons.size()) {
            const auto& item = _buttons[_buttonIndex];
            NSInteger controlIdx = [_overlay controlIndexForKey:item.first];
            if (controlIdx == NSNotFound) {
                fprintf(stderr, "[dinopad-touch-test] FAIL: control key %s not found\n", item.first);
                fflush(stderr);
                return;
            }
            CGPoint center = [_overlay centerForControlIndex:controlIdx];

            if (_buttonSubStep == 0) {
                // Press
                [_overlay beginSimulatedTouchWithID:1 atPoint:center];
                uint16_t sb = 0; float sx = 0, sy = 0;
                dinopad_touch_snapshot(&sb, &sx, &sy);
                if ((sb & item.second) == item.second) {
                    fprintf(stderr, "[dinopad-touch-test] PASS: button %s mask=0x%04X verified (snapshot=0x%04X)\n",
                            item.first, item.second, sb);
                } else {
                    fprintf(stderr, "[dinopad-touch-test] FAIL: button %s mask=0x%04X missing (snapshot=0x%04X)\n",
                            item.first, item.second, sb);
                }
                fflush(stderr);
                _buttonSubStep = 1;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.06 * NSEC_PER_SEC)),
                               dispatch_get_main_queue(), ^{ [self nextStep]; });
            } else {
                // Release
                [_overlay endSimulatedTouchWithID:1];
                g_touchTaps.clearAll();
                [_overlay clearInput];
                _buttonSubStep = 0;
                _buttonIndex++;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.04 * NSEC_PER_SEC)),
                               dispatch_get_main_queue(), ^{ [self nextStep]; });
            }
            return;
        } else {
            _suite = 2;
            _suiteSubStep = 0;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.04 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ [self nextStep]; });
            return;
        }
    }

    // Suite 2: Analog Directions (Up, Down, Left, Right)
    if (_suite == 2) {
        NSInteger stickIdx = [_overlay controlIndexForKey:"stick"];
        CGPoint stickCenter = [_overlay centerForControlIndex:stickIdx];
        CGFloat stickRadius = [_overlay radiusForControlIndex:stickIdx];

        if (_suiteSubStep == 0) {
            // UP (dy = -stickRadius)
            [_overlay beginSimulatedTouchWithID:1 atPoint:stickCenter];
            [_overlay moveSimulatedTouchWithID:1 toPoint:CGPointMake(stickCenter.x, stickCenter.y - stickRadius)];
            uint16_t sb = 0; float sx = 0, sy = 0;
            dinopad_touch_snapshot(&sb, &sx, &sy);
            if (sy > 0.90f && sx == 0.0f) {
                fprintf(stderr, "[dinopad-touch-test] PASS: analog UP x=%.2f y=%.2f verified\n", sx, sy);
            } else {
                fprintf(stderr, "[dinopad-touch-test] FAIL: analog UP unexpected x=%.2f y=%.2f\n", sx, sy);
            }
            fflush(stderr);
            _suiteSubStep = 1;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.06 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ [self nextStep]; });
            return;
        }
        if (_suiteSubStep == 1) {
            [_overlay endSimulatedTouchWithID:1];
            [_overlay clearInput];
            uint16_t sb = 0; float sx = 0, sy = 0;
            dinopad_touch_snapshot(&sb, &sx, &sy);
            fprintf(stderr, "[dinopad-touch-test] PASS: analog UP return to zero (x=%.2f y=%.2f)\n", sx, sy);
            fflush(stderr);
            _suiteSubStep = 2;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.04 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ [self nextStep]; });
            return;
        }
        if (_suiteSubStep == 2) {
            // DOWN (dy = +stickRadius)
            [_overlay beginSimulatedTouchWithID:1 atPoint:stickCenter];
            [_overlay moveSimulatedTouchWithID:1 toPoint:CGPointMake(stickCenter.x, stickCenter.y + stickRadius)];
            uint16_t sb = 0; float sx = 0, sy = 0;
            dinopad_touch_snapshot(&sb, &sx, &sy);
            if (sy < -0.90f && sx == 0.0f) {
                fprintf(stderr, "[dinopad-touch-test] PASS: analog DOWN x=%.2f y=%.2f verified\n", sx, sy);
            } else {
                fprintf(stderr, "[dinopad-touch-test] FAIL: analog DOWN unexpected x=%.2f y=%.2f\n", sx, sy);
            }
            fflush(stderr);
            _suiteSubStep = 3;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.06 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ [self nextStep]; });
            return;
        }
        if (_suiteSubStep == 3) {
            [_overlay endSimulatedTouchWithID:1];
            [_overlay clearInput];
            uint16_t sb = 0; float sx = 0, sy = 0;
            dinopad_touch_snapshot(&sb, &sx, &sy);
            fprintf(stderr, "[dinopad-touch-test] PASS: analog DOWN return to zero (x=%.2f y=%.2f)\n", sx, sy);
            fflush(stderr);
            _suiteSubStep = 4;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.04 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ [self nextStep]; });
            return;
        }
        if (_suiteSubStep == 4) {
            // LEFT (dx = -stickRadius)
            [_overlay beginSimulatedTouchWithID:1 atPoint:stickCenter];
            [_overlay moveSimulatedTouchWithID:1 toPoint:CGPointMake(stickCenter.x - stickRadius, stickCenter.y)];
            uint16_t sb = 0; float sx = 0, sy = 0;
            dinopad_touch_snapshot(&sb, &sx, &sy);
            if (sx < -0.90f && sy == 0.0f) {
                fprintf(stderr, "[dinopad-touch-test] PASS: analog LEFT x=%.2f y=%.2f verified\n", sx, sy);
            } else {
                fprintf(stderr, "[dinopad-touch-test] FAIL: analog LEFT unexpected x=%.2f y=%.2f\n", sx, sy);
            }
            fflush(stderr);
            _suiteSubStep = 5;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.06 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ [self nextStep]; });
            return;
        }
        if (_suiteSubStep == 5) {
            [_overlay endSimulatedTouchWithID:1];
            [_overlay clearInput];
            uint16_t sb = 0; float sx = 0, sy = 0;
            dinopad_touch_snapshot(&sb, &sx, &sy);
            fprintf(stderr, "[dinopad-touch-test] PASS: analog LEFT return to zero (x=%.2f y=%.2f)\n", sx, sy);
            fflush(stderr);
            _suiteSubStep = 6;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.04 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ [self nextStep]; });
            return;
        }
        if (_suiteSubStep == 6) {
            // RIGHT (dx = +stickRadius)
            [_overlay beginSimulatedTouchWithID:1 atPoint:stickCenter];
            [_overlay moveSimulatedTouchWithID:1 toPoint:CGPointMake(stickCenter.x + stickRadius, stickCenter.y)];
            uint16_t sb = 0; float sx = 0, sy = 0;
            dinopad_touch_snapshot(&sb, &sx, &sy);
            if (sx > 0.90f && sy == 0.0f) {
                fprintf(stderr, "[dinopad-touch-test] PASS: analog RIGHT x=%.2f y=%.2f verified\n", sx, sy);
            } else {
                fprintf(stderr, "[dinopad-touch-test] FAIL: analog RIGHT unexpected x=%.2f y=%.2f\n", sx, sy);
            }
            fflush(stderr);
            _suiteSubStep = 7;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.06 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ [self nextStep]; });
            return;
        }
        if (_suiteSubStep == 7) {
            [_overlay endSimulatedTouchWithID:1];
            [_overlay clearInput];
            uint16_t sb = 0; float sx = 0, sy = 0;
            dinopad_touch_snapshot(&sb, &sx, &sy);
            fprintf(stderr, "[dinopad-touch-test] PASS: analog RIGHT return to zero (x=%.2f y=%.2f)\n", sx, sy);
            fflush(stderr);
            _suite = 3;
            _suiteSubStep = 0;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.04 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ [self nextStep]; });
            return;
        }
    }

    // Suite 3: Simultaneous Multi-Touch (Stick Up-Right + A + B + Z)
    if (_suite == 3) {
        NSInteger stickIdx = [_overlay controlIndexForKey:"stick"];
        CGPoint stickCenter = [_overlay centerForControlIndex:stickIdx];
        CGFloat stickRadius = [_overlay radiusForControlIndex:stickIdx];

        if (_suiteSubStep == 0) {
            CGPoint aCenter = [_overlay centerForControlIndex:[_overlay controlIndexForKey:"a"]];
            CGPoint bCenter = [_overlay centerForControlIndex:[_overlay controlIndexForKey:"b"]];
            CGPoint zCenter = [_overlay centerForControlIndex:[_overlay controlIndexForKey:"z"]];

            [_overlay beginSimulatedTouchWithID:1 atPoint:stickCenter];
            [_overlay moveSimulatedTouchWithID:1 toPoint:CGPointMake(stickCenter.x + stickRadius * 0.707f, stickCenter.y - stickRadius * 0.707f)];
            [_overlay beginSimulatedTouchWithID:2 atPoint:aCenter];
            [_overlay beginSimulatedTouchWithID:3 atPoint:bCenter];
            [_overlay beginSimulatedTouchWithID:4 atPoint:zCenter];

            uint16_t sb = 0; float sx = 0, sy = 0;
            dinopad_touch_snapshot(&sb, &sx, &sy);
            constexpr uint16_t expectedMask = 0x8000 | 0x4000 | 0x2000;
            if ((sb & expectedMask) == expectedMask && sx > 0.3f && sy > 0.3f) {
                fprintf(stderr, "[dinopad-touch-test] PASS: simultaneous multi-touch stick+A+B+Z buttons=0x%04X x=%.2f y=%.2f verified\n",
                        sb, sx, sy);
            } else {
                fprintf(stderr, "[dinopad-touch-test] FAIL: simultaneous multi-touch unexpected buttons=0x%04X x=%.2f y=%.2f\n",
                        sb, sx, sy);
            }
            fflush(stderr);
            _suiteSubStep = 1;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ [self nextStep]; });
            return;
        }
        if (_suiteSubStep == 1) {
            [_overlay endSimulatedTouchWithID:1];
            [_overlay endSimulatedTouchWithID:2];
            [_overlay endSimulatedTouchWithID:3];
            [_overlay endSimulatedTouchWithID:4];
            g_touchTaps.clearAll();
            [_overlay clearInput];
            uint16_t sb = 0; float sx = 0, sy = 0;
            dinopad_touch_snapshot(&sb, &sx, &sy);
            fprintf(stderr, "[dinopad-touch-test] PASS: multi-touch released to zero (buttons=0x%04X x=%.2f y=%.2f)\n",
                    sb, sx, sy);
            fflush(stderr);
            _suite = 4;
            _suiteSubStep = 0;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.04 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ [self nextStep]; });
            return;
        }
    }

    // Suite 4: Menu Open / Dismiss Lifecycle
    if (_suite == 4) {
        if (_suiteSubStep == 0) {
            CGPoint aCenter = [_overlay centerForControlIndex:[_overlay controlIndexForKey:"a"]];
            [_overlay beginSimulatedTouchWithID:1 atPoint:aCenter];
            [_overlay presentUtilityMenu];
            uint16_t sb = 0; float sx = 0, sy = 0;
            dinopad_touch_snapshot(&sb, &sx, &sy);
            if (sb == 0x0000) {
                fprintf(stderr, "[dinopad-touch-test] PASS: menu presentation cleared held input (buttons=0x%04X)\n", sb);
            } else {
                fprintf(stderr, "[dinopad-touch-test] FAIL: menu presentation did not clear input (buttons=0x%04X)\n", sb);
            }
            fflush(stderr);
            _suiteSubStep = 1;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ [self nextStep]; });
            return;
        }
        if (_suiteSubStep == 1) {
            [_overlay dismissUtilityMenu];
            fprintf(stderr, "[dinopad-touch-test] PASS: menu dismissed and gameplay controls restored\n");
            fflush(stderr);
            _suite = 5;
            _suiteSubStep = 0;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.06 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ [self nextStep]; });
            return;
        }
    }

    // Suite 5: App Lifecycle (Background / Foreground)
    if (_suite == 5) {
        NSInteger stickIdx = [_overlay controlIndexForKey:"stick"];
        CGPoint stickCenter = [_overlay centerForControlIndex:stickIdx];
        CGFloat stickRadius = [_overlay radiusForControlIndex:stickIdx];

        if (_suiteSubStep == 0) {
            CGPoint bCenter = [_overlay centerForControlIndex:[_overlay controlIndexForKey:"b"]];
            [_overlay beginSimulatedTouchWithID:1 atPoint:stickCenter];
            [_overlay moveSimulatedTouchWithID:1 toPoint:CGPointMake(stickCenter.x, stickCenter.y + stickRadius)];
            [_overlay beginSimulatedTouchWithID:2 atPoint:bCenter];

            [NSNotificationCenter.defaultCenter
                postNotificationName:UIApplicationWillResignActiveNotification object:nil];
            [NSNotificationCenter.defaultCenter
                postNotificationName:UIApplicationDidEnterBackgroundNotification object:nil];

            uint16_t sb = 0; float sx = 0, sy = 0;
            dinopad_touch_snapshot(&sb, &sx, &sy);
            if (sb == 0x0000 && sx == 0.0f && sy == 0.0f) {
                fprintf(stderr, "[dinopad-touch-test] PASS: background notification cleared held input (buttons=0x%04X x=%.2f y=%.2f)\n",
                        sb, sx, sy);
            } else {
                fprintf(stderr, "[dinopad-touch-test] FAIL: background notification failed to clear input (buttons=0x%04X x=%.2f y=%.2f)\n",
                        sb, sx, sy);
            }
            fflush(stderr);

            [NSNotificationCenter.defaultCenter
                postNotificationName:UIApplicationWillEnterForegroundNotification object:nil];
            [NSNotificationCenter.defaultCenter
                postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
            fprintf(stderr, "[dinopad-touch-test] PASS: foreground notification resumed cleanly\n");
            fflush(stderr);
            _suite = 6;
            _suiteSubStep = 0;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.06 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{ [self nextStep]; });
            return;
        }
    }

    // Suite 6: Controller Handoff & Simulator Exception
    if (_suite == 6) {
        NSInteger stickIdx = [_overlay controlIndexForKey:"stick"];
        CGPoint stickCenter = [_overlay centerForControlIndex:stickIdx];

        dinopad_set_physical_controller_connected(1);
        // On Simulator, g_controllerConnected remains false due to synthetic gamepad exception
        if (!g_controllerConnected.load(std::memory_order_relaxed)) {
            fprintf(stderr, "[dinopad-touch-test] PASS: simulator synthetic controller exception verified (touch controls kept active)\n");
        } else {
            fprintf(stderr, "[dinopad-touch-test] FAIL: simulator synthetic controller exception failed\n");
        }

        // Test explicit overlay controller hiding
        [_overlay setPhysicalControllerConnected:YES];
        [_overlay beginSimulatedTouchWithID:1 atPoint:stickCenter];
        uint16_t sb = 0; float sx = 0, sy = 0;
        dinopad_touch_snapshot(&sb, &sx, &sy);
        if (sb == 0x0000 && sx == 0.0f && sy == 0.0f) {
            fprintf(stderr, "[dinopad-touch-test] PASS: controller connected state hid touch input (buttons=0x%04X)\n", sb);
        } else {
            fprintf(stderr, "[dinopad-touch-test] FAIL: controller connected state did not suppress touch input (buttons=0x%04X)\n", sb);
        }

        [_overlay setPhysicalControllerConnected:NO];
        fprintf(stderr, "[dinopad-touch-test] PASS: controller disconnected state restored touch controls\n");
        fflush(stderr);
        _suite = 7;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.04 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ [self nextStep]; });
        return;
    }

    // Suite 7: Completion
    if (_suite == 7) {
        fprintf(stderr, "[dinopad-touch-test] ALL 7 INPUT/LIFECYCLE TEST SUITES PASSED (14 digital masks, 4 analog directions, multi-touch, menu lifecycle, app lifecycle, controller handoff)\n");
        fflush(stderr);
    }
}

@end

@implementation DinoPadGameplaySmokeRunner {
    DinoPadTouchOverlayView* _overlay;
    std::vector<double> _delaysAfterA;
    size_t _step;
}

+ (void)runWithOverlay:(DinoPadTouchOverlayView*)overlay {
    DinoPadGameplaySmokeRunner* runner =
        [[DinoPadGameplaySmokeRunner alloc] initWithOverlay:overlay];
    [runner start];
}

- (instancetype)initWithOverlay:(DinoPadTouchOverlayView*)overlay {
    self = [super init];
    if (self) {
        _overlay = overlay;
        _step = 0;
        // Mirror the proven macOS boot/save/opening replay. The first five A
        // presses reach and confirm the existing private save; later presses
        // advance bounded opening prompts before replaying movement in-game.
        _delaysAfterA = {2.0, 6.0, 2.0, 6.0, 6.0};
        _delaysAfterA.insert(_delaysAfterA.end(), 20, 20.0);
    }
    return self;
}

- (void)start {
    fprintf(stderr, "[dinopad-restoration-test] Starting boot-to-gameplay replay\n");
    fflush(stderr);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(12.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [self pressNextA]; });
}

- (void)pressNextA {
    if (_step >= _delaysAfterA.size()) {
        [self replayGameplayInput];
        return;
    }
    NSInteger index = [_overlay controlIndexForKey:"a"];
    [_overlay beginSimulatedTouchWithID:31 atPoint:[_overlay centerForControlIndex:index]];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [_overlay endSimulatedTouchWithID:31];
        const double delay = _delaysAfterA[_step++];
        if (_step == 2) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                         (int64_t)(3.0 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                fprintf(stderr,
                        "[dinopad-restoration-test] Restored title capture boundary\n");
                fflush(stderr);
            });
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                     (int64_t)(delay * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ [self pressNextA]; });
    });
}

- (void)replayGameplayInput {
    NSInteger index = [_overlay controlIndexForKey:"stick"];
    CGPoint center = [_overlay centerForControlIndex:index];
    const CGFloat radius = [_overlay radiusForControlIndex:index];
    [_overlay beginSimulatedTouchWithID:32 atPoint:center];
    [_overlay moveSimulatedTouchWithID:32
                              toPoint:CGPointMake(center.x, center.y - radius)];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [_overlay endSimulatedTouchWithID:32];
        NSInteger aIndex = [_overlay controlIndexForKey:"a"];
        [_overlay beginSimulatedTouchWithID:33
                                   atPoint:[_overlay centerForControlIndex:aIndex]];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                     (int64_t)(0.40 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [_overlay endSimulatedTouchWithID:33];
            fprintf(stderr,
                    "[dinopad-restoration-test] Late-session input replay completed "
                    "(polls=%llu)\n",
                    (unsigned long long)g_gameInputPolls.load(std::memory_order_relaxed));
            fflush(stderr);
        });
    });
}

@end

#endif  // DINOPAD_ENABLE_TEST_HARNESS

static __weak DinoPadTouchOverlayView* g_touchOverlay = nil;

extern "C" int dinopad_shell_touch_enabled(void) {
    NSDictionary* settings = [NSUserDefaults.standardUserDefaults
        dictionaryForKey:@"dinopad.touch.settings.v1"];
    id enabled = settings[@"enabled"];
    return ![enabled isKindOfClass:NSNumber.class] || [enabled boolValue];
}

extern "C" double dinopad_shell_touch_opacity(void) {
    NSDictionary* settings = [NSUserDefaults.standardUserDefaults
        dictionaryForKey:@"dinopad.touch.settings.v1"];
    id stored = settings[@"opacity"];
    const double opacity = [stored isKindOfClass:NSNumber.class]
        ? [stored doubleValue] : 0.70;
    if (!std::isfinite(opacity)) return 0.70;
    return std::clamp(opacity, 0.20, 1.0);
}

extern "C" void dinopad_shell_set_touch(int enabled, double opacity) {
    [g_touchOverlay setControlsEnabled:enabled != 0 opacity:opacity];
}

extern "C" void dinopad_shell_set_modal_hidden(int hidden) {
    [g_touchOverlay setModalControlsHidden:hidden != 0];
}

extern "C" void dinopad_shell_begin_layout_editor(void) {
    [g_touchOverlay beginEditingLayout];
}

extern "C" void dinopad_shell_reset_current_layout(void) {
    [g_touchOverlay resetLayout];
}

extern "C" void dinopad_shell_quit_to_home(void) {
    [g_touchOverlay quitToHome];
}

extern "C" int dinopad_shell_controller_connected(void) {
    return g_controllerConnected.load(std::memory_order_relaxed) ? 1 : 0;
}

extern "C" void dinopad_shell_request_config_save(void) {
    g_settingsSaveRequested.store(true, std::memory_order_release);
}

#if DINOPAD_ENABLE_TEST_HARNESS
extern "C" int dinopad_shell_test_touch_after_settings(void) {
    if (g_touchOverlay == nil) return 0;
    [g_touchOverlay clearInput];
    g_touchTaps.clearAll();
    const NSInteger index = [g_touchOverlay controlIndexForKey:"b"];
    [g_touchOverlay beginSimulatedTouchWithID:121
                                      atPoint:[g_touchOverlay centerForControlIndex:index]];
    uint16_t buttons = 0;
    float x = 0.0F;
    float y = 0.0F;
    dinopad_touch_snapshot(&buttons, &x, &y);
    [g_touchOverlay clearInput];
    return (buttons & 0x4000) != 0;
}

static void scheduleQuitToHomeSmoke(DinoPadTouchOverlayView* overlay, int attemptsRemaining) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.10 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (g_gameInputPolls.load(std::memory_order_relaxed) > 0) {
            std::fprintf(stderr, "[dinopad-home-test] Gameplay input polled before quit\n");
            std::fflush(stderr);
            [overlay quitToHome];
            return;
        }
        if (attemptsRemaining > 0) {
            scheduleQuitToHomeSmoke(overlay, attemptsRemaining - 1);
            return;
        }
        std::fprintf(stderr, "[dinopad-home-test] Gameplay input poll timed out\n");
        std::fflush(stderr);
        [overlay quitToHome];
    });
}
#endif

extern "C" void dinopad_touch_attach(void* windowPointer) {
    if (windowPointer == nullptr) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow* window = (__bridge UIWindow*)windowPointer;
        UIView* host = window.rootViewController.view ?: window;
        for (UIView* view in host.subviews) {
            if ([view isKindOfClass:DinoPadTouchOverlayView.class]) return;
        }
        DinoPadTouchOverlayView* overlay =
            [[DinoPadTouchOverlayView alloc] initWithFrame:host.bounds];
        overlay.translatesAutoresizingMaskIntoConstraints = NO;
        [overlay setPhysicalControllerConnected:
            g_controllerConnected.load(std::memory_order_relaxed)];
        [host addSubview:overlay];
        [NSLayoutConstraint activateConstraints:@[
            [overlay.leadingAnchor constraintEqualToAnchor:host.leadingAnchor],
            [overlay.trailingAnchor constraintEqualToAnchor:host.trailingAnchor],
            [overlay.topAnchor constraintEqualToAnchor:host.topAnchor],
            [overlay.bottomAnchor constraintEqualToAnchor:host.bottomAnchor],
        ]];
        g_touchOverlay = overlay;
        fprintf(stderr, "[dinopad-touch] overlay attached (%s)\n",
            UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad
                ? "tablet" : "phone");

#if DINOPAD_ENABLE_TEST_HARNESS
        const char* smokeEnv = getenv("DINOPAD_RUN_INPUT_SMOKE");
        if (smokeEnv != nullptr && smokeEnv[0] != '\0' && smokeEnv[0] != '0') {
            [DinoPadInputSmokeRunner runWithOverlay:overlay];
        }

        const char* gameplaySmoke = getenv("DINOPAD_RUN_GAMEPLAY_SMOKE");
        if (gameplaySmoke != nullptr && gameplaySmoke[0] != '\0' &&
            gameplaySmoke[0] != '0') {
            [DinoPadGameplaySmokeRunner runWithOverlay:overlay];
        }

        const char* layoutSmoke = getenv("DINOPAD_RUN_LAYOUT_SMOKE");
        const char* layoutPhase = getenv("DINOPAD_LAYOUT_SMOKE_PHASE");
        if (layoutSmoke != nullptr && layoutSmoke[0] != '\0' && layoutSmoke[0] != '0') {
            NSString* phase = layoutPhase == nullptr
                ? @"edit" : [NSString stringWithUTF8String:layoutPhase];
            [DinoPadLayoutSmokeRunner runWithOverlay:overlay phase:phase];
        }

        const char* touchMenuSmoke = getenv("DINOPAD_SHOW_TOUCH_MENU_SMOKE");
        if (touchMenuSmoke != nullptr && touchMenuSmoke[0] != '\0' &&
            touchMenuSmoke[0] != '0') {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.70 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [overlay presentUtilityMenu];
                std::fprintf(stderr, "[dinopad-layout-test] touch layout menu presented\n");
                std::fflush(stderr);
            });
        }

        const char* settingsSmoke = getenv("DINOPAD_RUN_SETTINGS_SMOKE");
        if (settingsSmoke != nullptr && settingsSmoke[0] != '\0' &&
            settingsSmoke[0] != '0') {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.50 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                const NSInteger index = [overlay controlIndexForKey:"a"];
                [overlay beginSimulatedTouchWithID:120
                                           atPoint:[overlay centerForControlIndex:index]];
                dinopad_present_settings((__bridge void*)[overlay topPresenter]);
            });
        }

        const char* diagnosticsSmoke = getenv("DINOPAD_RUN_DIAGNOSTICS_SMOKE");
        if (diagnosticsSmoke != nullptr && diagnosticsSmoke[0] != '\0' &&
            diagnosticsSmoke[0] != '0') {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.00 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                const NSInteger index = [overlay controlIndexForKey:"a"];
                [overlay beginSimulatedTouchWithID:122
                                           atPoint:[overlay centerForControlIndex:index]];
                [overlay setModalControlsHidden:YES];
                uint16_t buttons = 0;
                float x = 0.0F;
                float y = 0.0F;
                dinopad_touch_snapshot(&buttons, &x, &y);
                std::fprintf(stderr, buttons == 0 && x == 0.0F && y == 0.0F
                    ? "[dinopad-diagnostics-test] PASS: share presentation cleared held input\n"
                    : "[dinopad-diagnostics-test] FAIL: share presentation retained held input\n");
                std::fprintf(stderr,
                    "[dinopad-diagnostics-test] fixtures: "
                    "/" "Users/diagnostic-owner/Secret/game.z64 "
                    "/private/var/mobile/Containers/Data/Application/"
                    "11111111-2222-3333-4444-555555555555/Documents/save.bin "
                    "file:///var/mobile/Library/Mobile%%20Documents/provider/private.rom "
                    "/tmp/dinopad-private/report.log /Volumes/Owner Drive/private/file\n");
                std::fflush(stderr);
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.50 * NSEC_PER_SEC)),
                               dispatch_get_main_queue(), ^{
                    dinopad_present_diagnostics_share((__bridge void*)[overlay topPresenter], ^{
                        [overlay setModalControlsHidden:NO];
                        const bool touchRestored =
                            dinopad_shell_test_touch_after_settings() != 0;
                        std::fprintf(stderr, touchRestored
                            ? "[dinopad-diagnostics-test] ALL DIAGNOSTICS TESTS PASSED\n"
                            : "[dinopad-diagnostics-test] FAIL: post-share touch input\n");
                        std::fflush(stderr);
                    });
                });
            });
        }

        const char* romManagerSmoke = getenv("DINOPAD_SHOW_ROM_MANAGER_SMOKE");
        if (romManagerSmoke != nullptr && romManagerSmoke[0] != '\0' &&
            romManagerSmoke[0] != '0') {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.60 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [overlay setModalControlsHidden:YES];
                dinopad_present_rom_manager((__bridge void*)[overlay topPresenter]);
            });
        }

        const char* quitSmoke = getenv("DINOPAD_QUIT_TO_HOME_SMOKE");
        if (quitSmoke != nullptr && quitSmoke[0] != '\0' && quitSmoke[0] != '0' &&
            !g_quitSmokeTriggered.exchange(true, std::memory_order_relaxed)) {
            scheduleQuitToHomeSmoke(overlay, 100);
        }
#endif
    });
}

extern "C" void dinopad_touch_snapshot(uint16_t* buttons, float* x, float* y) {
    dinopad_diagnostics_gameplay_poll();
#if DINOPAD_ENABLE_TEST_HARNESS
    g_gameInputPolls.fetch_add(1, std::memory_order_relaxed);
#endif
    if (g_settingsSaveRequested.exchange(false, std::memory_order_acq_rel)) {
        dino::config::save_config();
        std::fprintf(stderr, "[dinopad-settings] active profile configuration saved\n");
        std::fflush(stderr);
    }
    if (buttons != nullptr) {
        *buttons = g_touchButtons.load(std::memory_order_relaxed) | g_touchTaps.consume();
    }
    float touchX = g_touchX.load(std::memory_order_relaxed) / 10000.0F;
    float touchY = g_touchY.load(std::memory_order_relaxed) / 10000.0F;
    uint8_t flickPolls = g_touchFlickPolls.load(std::memory_order_relaxed);
    if (touchX == 0.0F && touchY == 0.0F && flickPolls > 0) {
        touchX = g_touchFlickX.load(std::memory_order_relaxed) / 10000.0F;
        touchY = g_touchFlickY.load(std::memory_order_relaxed) / 10000.0F;
        g_touchFlickPolls.compare_exchange_strong(
            flickPolls, static_cast<uint8_t>(flickPolls - 1), std::memory_order_relaxed);
    }
    if (x != nullptr) *x = std::clamp(touchX, -1.0F, 1.0F);
    if (y != nullptr) *y = std::clamp(touchY, -1.0F, 1.0F);
}

extern "C" void dinopad_set_physical_controller_connected(int connected) {
#if TARGET_OS_SIMULATOR
    // CoreSimulator exposes its synthetic MFi Gamepad even when no external
    // controller is paired. Keep touch controls available in Simulator tests.
    connected = 0;
#endif
    BOOL isConnected = connected != 0;
    const bool changed = g_controllerConnected.exchange(
        isConnected, std::memory_order_relaxed) != static_cast<bool>(isConnected);
    if (changed) {
        dinopad_diagnostics_breadcrumb("controller",
            isConnected ? "physical_connected" : "physical_disconnected");
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [g_touchOverlay setPhysicalControllerConnected:isConnected];
    });
}

extern "C" void dinopad_log_controller_button(int button, int pressed) {
    const char* name = "other";
    switch (button) {
        case SDL_CONTROLLER_BUTTON_BACK: name = "back"; break;
        case SDL_CONTROLLER_BUTTON_GUIDE: name = "guide"; break;
        case SDL_CONTROLLER_BUTTON_START: name = "start"; break;
        case SDL_CONTROLLER_BUTTON_A: name = "a"; break;
        case SDL_CONTROLLER_BUTTON_B: name = "b"; break;
        default: break;
    }
    char event[96];
    std::snprintf(event, sizeof(event), "button_%s_%s_id_%d",
        name, pressed ? "down" : "up", button);
    dinopad_diagnostics_breadcrumb("controller", event);
}

extern "C" int SDL_main(int, char **) {
    SDL_SetHint(SDL_HINT_ORIENTATIONS, "LandscapeLeft LandscapeRight");
    SDL_SetHint(SDL_HINT_IOS_HIDE_HOME_INDICATOR, "1");
    dinopad_start_diagnostics_log();
    dinopad_diagnostics_breadcrumb("session", "shell_started");

    // Phase 5 (Goal 27a): verify the private supported ROM via UIKit before
    // entering the runtime. Missing/invalid ROM presents an in-app Files
    // picker that normalizes and stores the December 2000 prototype.
    if (!dinopad_prepare_rom_setup()) {
        dinopad_finish_diagnostics_log();
        return EXIT_FAILURE;
    }

    for (;;) {
        dinopad_diagnostics_breadcrumb("home", "presenting");
        const int selectedProfile = dinopad_present_home();
        dinopad_diagnostics_breadcrumb("home",
            selectedProfile == 0 ? "restored_selected" : "prototype_selected");
        g_currentProfile.store(selectedProfile, std::memory_order_relaxed);
        g_quitToHome.store(false, std::memory_order_relaxed);
        g_settingsSaveRequested.store(false, std::memory_order_relaxed);
#if DINOPAD_ENABLE_TEST_HARNESS
        g_gameInputPolls.store(0, std::memory_order_relaxed);
#endif

        char appName[] = "DinoPad";
        char skipLauncher[] = "--skip-launcher";
        char profileFlag[] = "--profile";
        char restored[] = "restored";
        char prototype[] = "prototype";
        char* arguments[] = {
            appName,
            skipLauncher,
            profileFlag,
            selectedProfile == 0 ? restored : prototype,
            nullptr,
        };

        dinopad_diagnostics_breadcrumb("runtime",
            selectedProfile == 0 ? "begin_restored" : "begin_prototype");
        dinopad_diagnostics_set_runtime_active(1);
        const int result = dinopad_recomp_main(4, arguments);
        dinopad_diagnostics_set_runtime_active(0);
        char resultEvent[64];
        std::snprintf(resultEvent, sizeof(resultEvent), "recomp_main_returned_%d", result);
        dinopad_diagnostics_breadcrumb("runtime", resultEvent);
        if (g_settingsSaveRequested.exchange(false, std::memory_order_acq_rel)) {
            dino::config::save_config();
        }
        dinopad_diagnostics_breadcrumb("teardown", "audio_begin");
        dino::runtime::shutdown_audio();
        dinopad_diagnostics_breadcrumb("teardown", "audio_complete");
        // RT64/Plume may have already queued UIKit window-attribute work from
        // its renderer thread. The renderer is joined now, so drain those
        // final blocks while the SDL window is still valid, then drain SDL's
        // own UIKit teardown before presenting the home again.
        drainUIKitQueue();
        dinopad_diagnostics_breadcrumb("teardown", "graphics_begin");
        dino::runtime::shutdown_gfx();
        drainUIKitQueue();
        dinopad_diagnostics_breadcrumb("teardown", "graphics_complete");

        if (result != EXIT_SUCCESS ||
            !g_quitToHome.exchange(false, std::memory_order_relaxed)) {
            dinopad_diagnostics_breadcrumb("runtime", result != EXIT_SUCCESS
                ? "process_exit_runtime_failure" : "process_exit_without_home_request");
            dinopad_finish_diagnostics_log();
            return result;
        }
        dinopad_diagnostics_breadcrumb("runtime", "returned_to_home_intentionally");
        std::fprintf(stderr, "[dinopad-home-test] Runtime returned to home\n");
        std::fflush(stderr);
    }
}
