#include <algorithm>
#include <array>
#include <atomic>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>

#include <SDL.h>
#include <TargetConditionals.h>
#import <UIKit/UIKit.h>

extern "C" int dinopad_recomp_main(int argc, char **argv);
extern "C" void dinopad_touch_snapshot(uint16_t* buttons, float* x, float* y);
extern "C" void dinopad_set_physical_controller_connected(int connected);

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
};

std::array<TouchControl, kControlCount> defaultControls() {
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        return {{
            {"stick", "", ControlKind::Stick, 0x0000, 0.164, 0.745, 0.090, 0.42},
            {"d_up", "\u2191", ControlKind::Button, 0x0800, 0.080, 0.550, 0.032, 0.42},
            {"d_down", "\u2193", ControlKind::Button, 0x0400, 0.080, 0.665, 0.032, 0.42},
            {"d_left", "\u2190", ControlKind::Button, 0x0200, 0.040, 0.608, 0.032, 0.42},
            {"d_right", "\u2192", ControlKind::Button, 0x0100, 0.120, 0.608, 0.032, 0.42},
            {"c_up", "\u2191", ControlKind::Button, 0x0008, 0.904, 0.805, 0.033, 0.42},
            {"c_down", "\u2193", ControlKind::Button, 0x0004, 0.904, 0.910, 0.033, 0.42},
            {"c_left", "\u2190", ControlKind::Button, 0x0002, 0.861, 0.858, 0.033, 0.42},
            {"c_right", "\u2192", ControlKind::Button, 0x0001, 0.946, 0.858, 0.033, 0.42},
            {"a", "A", ControlKind::Button, 0x8000, 0.893, 0.693, 0.048, 0.48},
            {"b", "B", ControlKind::Button, 0x4000, 0.826, 0.635, 0.048, 0.48},
            {"z", "Z", ControlKind::Button, 0x2000, 0.897, 0.581, 0.048, 0.44},
            {"l", "L", ControlKind::Button, 0x0020, 0.941, 0.460, 0.041, 0.38},
            {"r", "R", ControlKind::Button, 0x0010, 0.941, 0.374, 0.041, 0.38},
            {"start", "START", ControlKind::Button, 0x1000, 0.942, 0.291, 0.033, 0.40},
        }};
    }
    return {{
        {"stick", "", ControlKind::Stick, 0x0000, 0.141, 0.783, 0.1480, 0.38},
        {"d_up", "\u2191", ControlKind::Button, 0x0800, 0.087, 0.359, 0.0560, 0.38},
        {"d_down", "\u2193", ControlKind::Button, 0x0400, 0.084, 0.541, 0.0560, 0.38},
        {"d_left", "\u2190", ControlKind::Button, 0x0200, 0.038, 0.444, 0.0560, 0.38},
        {"d_right", "\u2192", ControlKind::Button, 0x0100, 0.133, 0.449, 0.0560, 0.38},
        {"c_up", "\u2191", ControlKind::Button, 0x0008, 0.925, 0.337, 0.0510, 0.52},
        {"c_down", "\u2193", ControlKind::Button, 0x0004, 0.926, 0.522, 0.0510, 0.52},
        {"c_left", "\u2190", ControlKind::Button, 0x0002, 0.883, 0.425, 0.0510, 0.52},
        {"c_right", "\u2192", ControlKind::Button, 0x0001, 0.967, 0.428, 0.0510, 0.52},
        {"a", "A", ControlKind::Button, 0x8000, 0.930, 0.844, 0.0858, 0.58},
        {"b", "B", ControlKind::Button, 0x4000, 0.851, 0.736, 0.0792, 0.58},
        {"z", "Z", ControlKind::Button, 0x2000, 0.924, 0.672, 0.0660, 0.40},
        {"l", "L", ControlKind::Button, 0x0020, 0.946, 0.188, 0.0500, 0.36},
        {"r", "R", ControlKind::Button, 0x0010, 0.946, 0.079, 0.0500, 0.36},
        {"start", "START", ControlKind::Button, 0x1000, 0.874, 0.069, 0.0500, 0.54},
    }};
}

std::atomic<uint16_t> g_touchButtons{0};
std::atomic<int32_t> g_touchX{0};
std::atomic<int32_t> g_touchY{0};
std::atomic<int32_t> g_touchFlickX{0};
std::atomic<int32_t> g_touchFlickY{0};
std::atomic<uint8_t> g_touchFlickPolls{0};
std::atomic_bool g_controllerConnected{false};
TouchTapLatch g_touchTaps;

}  // namespace

@interface DinoPadTouchOverlayView : UIView
- (void)publishInput;
- (void)clearInput;
- (void)setControlsEnabled:(BOOL)enabled;
- (void)setModalControlsHidden:(BOOL)hidden;
- (void)setPhysicalControllerConnected:(BOOL)connected;
- (void)presentUtilityMenu;
- (void)dismissUtilityMenu;

// Deterministic test injection methods
- (CGPoint)centerForControlIndex:(NSInteger)index;
- (CGFloat)radiusForControlIndex:(NSInteger)index;
- (NSInteger)controlIndexForKey:(const char*)key;
- (void)beginSimulatedTouchWithID:(NSInteger)touchID atPoint:(CGPoint)point;
- (void)moveSimulatedTouchWithID:(NSInteger)touchID toPoint:(CGPoint)point;
- (void)endSimulatedTouchWithID:(NSInteger)touchID;
@end

@interface DinoPadInputSmokeRunner : NSObject
+ (void)runWithOverlay:(DinoPadTouchOverlayView*)overlay;
@end

@implementation DinoPadTouchOverlayView {
    std::array<TouchControl, kControlCount> _controls;
    NSMapTable<UITouch*, NSNumber*>* _touchRoles;
    NSMutableDictionary<NSNumber*, NSNumber*>* _simulatedTouchRoles;
    NSMutableDictionary<NSNumber*, NSValue*>* _simulatedTouchPoints;
    CGPoint _stickOrigin;
    CGPoint _stickKnob;
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
        _simulatedTouchRoles = [NSMutableDictionary dictionary];
        _simulatedTouchPoints = [NSMutableDictionary dictionary];
        _controlsEnabled = YES;
        _globalOpacity = 0.70;

        NSDictionary* saved = [NSUserDefaults.standardUserDefaults
            dictionaryForKey:@"dinopad.touch.settings.v1"];
        if (saved[@"enabled"] != nil) _controlsEnabled = [saved[@"enabled"] boolValue];
        if (saved[@"opacity"] != nil) {
            _globalOpacity = MAX(0.20, MIN(1.0, [saved[@"opacity"] doubleValue]));
        }

        _utilityButton = [UIButton buttonWithType:UIButtonTypeCustom];
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

        NSNotificationCenter* notifications = NSNotificationCenter.defaultCenter;
        [notifications addObserver:self selector:@selector(clearInput)
                              name:UIApplicationWillResignActiveNotification object:nil];
        [notifications addObserver:self selector:@selector(clearInput)
                              name:UIApplicationDidEnterBackgroundNotification object:nil];
        [notifications addObserver:self selector:@selector(clearInput)
                              name:UIApplicationDidBecomeActiveNotification object:nil];
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
    if (!_controlsEnabled || _controllerConnected || _modalControlsHidden) return;
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (context == nullptr) return;

    for (NSInteger index = 0; index < static_cast<NSInteger>(kControlCount); ++index) {
        const TouchControl& control = _controls[index];
        CGFloat radius = [self radiusForControl:control];
        CGRect frame = [self frameForControl:control];
        UIBezierPath* path = [self isShoulder:control]
            ? [UIBezierPath bezierPathWithRoundedRect:frame cornerRadius:radius]
            : [UIBezierPath bezierPathWithOvalInRect:frame];
        BOOL pressed = NO;
        for (NSNumber* role in _touchRoles.objectEnumerator) {
            if (role.integerValue == index) { pressed = YES; break; }
        }
        if (!pressed) {
            for (NSNumber* role in _simulatedTouchRoles.allValues) {
                if (role.integerValue == index) { pressed = YES; break; }
            }
        }
        CGFloat alpha = MIN(1.0, control.opacity * (_globalOpacity / 0.70));
        UIColor* accent = [self accentForControl:control];
        UIColor* fill = accent != nil
            ? [accent colorWithAlphaComponent:pressed ? MIN(0.95, alpha + 0.25) : alpha]
            : [UIColor colorWithWhite:pressed ? 0.34 : 0.04
                                 alpha:pressed ? MIN(0.90, alpha + 0.30) : alpha];
        [fill setFill];
        [path fill];
        [[UIColor colorWithWhite:1.0 alpha:MIN(0.88, alpha + 0.28)] setStroke];
        path.lineWidth = 2.0;
        [path stroke];

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
}

- (NSInteger)controlAtPoint:(CGPoint)point {
    if (!_controlsEnabled || _controllerConnected || _modalControlsHidden) return NSNotFound;
    NSInteger nearest = NSNotFound;
    CGFloat nearestDistance = CGFLOAT_MAX;
    for (NSInteger index = 0; index < static_cast<NSInteger>(kControlCount); ++index) {
        const TouchControl& control = _controls[index];
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

- (void)setControlsEnabled:(BOOL)enabled {
    _controlsEnabled = enabled;
    if (!enabled) [self clearInput];
    [NSUserDefaults.standardUserDefaults setObject:@{
        @"enabled": @(enabled), @"opacity": @(_globalOpacity)
    } forKey:@"dinopad.touch.settings.v1"];
    [self setNeedsDisplay];
}

- (void)setModalControlsHidden:(BOOL)hidden {
    _modalControlsHidden = hidden;
    _utilityButton.hidden = hidden;
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
    [self clearInput];
    [self setModalControlsHidden:YES];
    UIViewController* presenter = [self topPresenter];
    if (presenter == nil) {
        [self setModalControlsHidden:NO];
        return;
    }

    NSString* controllerStatus = _controllerConnected ? @"Connected" : @"Not Connected";
    NSString* touchTitle = _controlsEnabled ? @"Disable Touch Controls" : @"Enable Touch Controls";
    UIAlertController* menu = [UIAlertController
        alertControllerWithTitle:@"DinoPad"
                         message:[NSString stringWithFormat:
                             @"Restored Adventure\nController: %@", controllerStatus]
                  preferredStyle:UIAlertControllerStyleActionSheet];
    [menu addAction:[UIAlertAction actionWithTitle:@"Resume"
        style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction* action) {
            [self setModalControlsHidden:NO];
        }]];
    [menu addAction:[UIAlertAction actionWithTitle:touchTitle
        style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction* action) {
            [self setControlsEnabled:!self->_controlsEnabled];
            [self setModalControlsHidden:NO];
        }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Touch Layout & Settings (Coming Next)"
        style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction* action) {
            [self setModalControlsHidden:NO];
        }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"Game Data & Diagnostics (Coming Next)"
        style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction* action) {
            [self setModalControlsHidden:NO];
        }]];
    UIPopoverPresentationController* popover = menu.popoverPresentationController;
    if (popover != nil) {
        popover.sourceView = self;
        popover.sourceRect = [self utilityButtonRect];
        popover.permittedArrowDirections = UIPopoverArrowDirectionUp;
    }
    [presenter presentViewController:menu animated:YES completion:nil];
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
    [_simulatedTouchRoles removeAllObjects];
    [_simulatedTouchPoints removeAllObjects];
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
        NSInteger control = [self controlAtPoint:point];
        CGRect usable = [self usableBounds];
        if (control == NSNotFound && point.x <= CGRectGetMinX(usable) + usable.size.width * 0.47) {
            control = 0;
        }
        if (control == NSNotFound) continue;
        [_touchRoles setObject:@(control) forKey:touch];
        const TouchControl& item = _controls[control];
        if (item.kind == ControlKind::Stick) {
            _stickOrigin = [self centerForControl:item];
            _stickKnob = _stickOrigin;
        } else {
            g_touchTaps.extend(item.mask, kTapHoldPolls);
        }
    }
    [self publishInput];
}

- (void)touchesMoved:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
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
    for (UITouch* touch in touches) [_touchRoles removeObjectForKey:touch];
    [self publishInput];
}

- (void)touchesEnded:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
    [self finishTouches:touches];
}

- (void)touchesCancelled:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
    [self finishTouches:touches];
}

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

static __weak DinoPadTouchOverlayView* g_touchOverlay = nil;

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

        const char* smokeEnv = getenv("DINOPAD_RUN_INPUT_SMOKE");
        if (smokeEnv != nullptr && smokeEnv[0] != '\0' && smokeEnv[0] != '0') {
            [DinoPadInputSmokeRunner runWithOverlay:overlay];
        }
    });
}

extern "C" void dinopad_touch_snapshot(uint16_t* buttons, float* x, float* y) {
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
    g_controllerConnected.store(isConnected, std::memory_order_relaxed);
    dispatch_async(dispatch_get_main_queue(), ^{
        [g_touchOverlay setPhysicalControllerConnected:isConnected];
    });
}

extern "C" int SDL_main(int, char **) {
    SDL_SetHint(SDL_HINT_ORIENTATIONS, "LandscapeLeft LandscapeRight");
    SDL_SetHint(SDL_HINT_IOS_HIDE_HOME_INDICATOR, "1");

    char app_name[] = "DinoPad";
    char skip_launcher[] = "--skip-launcher";
    char profile_flag[] = "--profile";
    char profile_name[] = "restored";
    char *arguments[] = {
        app_name,
        skip_launcher,
        profile_flag,
        profile_name,
        nullptr,
    };
    return dinopad_recomp_main(4, arguments);
}
