/*
 * ChimpPad iOS/iPadOS shell: touch overlay + virtual controller emission.
 * Patterns adapted from SpaghettiPad; mappings tuned for Diddy Kong Racing
 * (Golden Balloon host keyboard/gamepad map).
 */
#import <UIKit/UIKit.h>
#include <TargetConditionals.h>

#include <array>
#include <atomic>
#include <cmath>
#include <cstdarg>
#include <cstdio>
#include <cstdlib>

#include <SDL.h>
#include <SDL_syswm.h>

#include "app/app_config.h"
#include "ChimpPadTouchControls.h"
#include "ChimpPadInput.h"
#include "platform_os.h"
#include "controller_mapping.h"

static UIWindow *sSDLWindow;
static SDL_Joystick *sVirtualJoystick;
static int sVirtualDeviceIndex = -1;
static std::array<int, kChimpPadActionCount> sActionPressCounts = {};
static unsigned int sHeldButtons = 0;
static int sStickX = 0;
static int sStickY = 0;
static std::atomic_bool sMenuVisible(false);
static std::atomic_bool sTouchStickActive(false);
static std::atomic_bool sGameplayActive(true);
static BOOL sTouchControlsDesired = YES;
static BOOL sLayoutEditorActive = NO;
/* Persistent player-facing touch overlay scale (0.5x-2.0x). Main-thread only;
 * written by platform_ios_touch_set_scale and read during layout. */
static float sTouchControlScale = 1.0f;

void ChimpPad_Log(const char *fmt, ...) {
    char buf[1024];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    NSLog(@"[ChimpPad] %s", buf);
    SDL_Log("[ChimpPad] %s", buf);
}

static void ChimpPad_PushKey(SDL_Scancode scancode, BOOL pressed) {
    SDL_Event event = {};
    event.type = pressed ? SDL_KEYDOWN : SDL_KEYUP;
    event.key.timestamp = SDL_GetTicks();
    event.key.state = pressed ? SDL_PRESSED : SDL_RELEASED;
    event.key.repeat = 0;
    event.key.keysym.scancode = scancode;
    event.key.keysym.sym = SDL_GetKeyFromScancode(scancode);
    SDL_Window *window = SDL_GetKeyboardFocus();
    if (window != nullptr) {
        event.key.windowID = SDL_GetWindowID(window);
    }
    SDL_PushEvent(&event);
}

/* Map actions to Golden Balloon keyboard defaults (platform_sdl_min.c). */
static SDL_Scancode ChimpPad_ActionScancode(ChimpPadAction action) {
    switch (action) {
        case kChimpPadActionA:
            return SDL_SCANCODE_X; /* accelerate */
        case kChimpPadActionB:
            return SDL_SCANCODE_Z; /* brake */
        case kChimpPadActionL:
            return SDL_SCANCODE_Q;
        case kChimpPadActionR:
            return SDL_SCANCODE_SPACE; /* hop / slide */
        case kChimpPadActionZ:
            return SDL_SCANCODE_LSHIFT; /* item */
        case kChimpPadActionStart:
            return SDL_SCANCODE_RETURN;
        case kChimpPadActionDUp:
            return SDL_SCANCODE_UP;
        case kChimpPadActionDDown:
            return SDL_SCANCODE_DOWN;
        case kChimpPadActionDLeft:
            return SDL_SCANCODE_LEFT;
        case kChimpPadActionDRight:
            return SDL_SCANCODE_RIGHT;
        case kChimpPadActionCUp:
            return SDL_SCANCODE_I;
        case kChimpPadActionCDown:
            return SDL_SCANCODE_K;
        case kChimpPadActionCLeft:
            return SDL_SCANCODE_J;
        case kChimpPadActionCRight:
            return SDL_SCANCODE_L;
        case kChimpPadActionMenu:
            return SDL_SCANCODE_ESCAPE;
        default:
            return SDL_SCANCODE_UNKNOWN;
    }
}

static unsigned int ChimpPad_ActionN64Bit(ChimpPadAction action) {
    switch (action) {
        case kChimpPadActionA: return MDKR_N64_A;
        case kChimpPadActionB: return MDKR_N64_B;
        case kChimpPadActionL: return MDKR_N64_L;
        case kChimpPadActionR: return MDKR_N64_R;
        case kChimpPadActionZ: return MDKR_N64_Z;
        case kChimpPadActionStart: return MDKR_N64_START;
        case kChimpPadActionDUp: return MDKR_N64_DU;
        case kChimpPadActionDDown: return MDKR_N64_DD;
        case kChimpPadActionDLeft: return MDKR_N64_DL;
        case kChimpPadActionDRight: return MDKR_N64_DR;
        case kChimpPadActionCUp: return MDKR_N64_CU;
        case kChimpPadActionCDown: return MDKR_N64_CD;
        case kChimpPadActionCLeft: return MDKR_N64_CL;
        case kChimpPadActionCRight: return MDKR_N64_CR;
        default: return 0;
    }
}

static void ChimpPad_PublishPad(void) {
    /* Direct P1 merge into the engine input queue — reliable on iOS where a
     * virtual joystick is not always bound as the game's primary controller. */
    static unsigned int sLastLoggedButtons = 0xFFFFFFFFu;
    platform_ios_touch_set(sHeldButtons, sStickX, sStickY, 1);
    if (sLastLoggedButtons != sHeldButtons) {
        ChimpPad_Log("pad inject buttons=0x%04x stick=%d,%d", sHeldButtons,
                     sStickX, sStickY);
        sLastLoggedButtons = sHeldButtons;
    }
}

/* Mirror face/shoulder actions onto the virtual gamepad when attached. */
static void ChimpPad_EmitVirtualButton(ChimpPadAction action, BOOL pressed) {
    if (sVirtualJoystick == nullptr) {
        return;
    }
    if (action == kChimpPadActionZ) {
        SDL_JoystickSetVirtualAxis(
            sVirtualJoystick, SDL_CONTROLLER_AXIS_TRIGGERLEFT,
            pressed ? SDL_JOYSTICK_AXIS_MAX : SDL_JOYSTICK_AXIS_MIN);
        return;
    }
    Sint16 axisValue = pressed ? SDL_JOYSTICK_AXIS_MAX : 0;
    if (action == kChimpPadActionCUp) {
        SDL_JoystickSetVirtualAxis(sVirtualJoystick, SDL_CONTROLLER_AXIS_RIGHTY,
                                   (Sint16)(-axisValue));
        return;
    }
    if (action == kChimpPadActionCDown) {
        SDL_JoystickSetVirtualAxis(sVirtualJoystick, SDL_CONTROLLER_AXIS_RIGHTY,
                                   axisValue);
        return;
    }
    if (action == kChimpPadActionCLeft) {
        SDL_JoystickSetVirtualAxis(sVirtualJoystick, SDL_CONTROLLER_AXIS_RIGHTX,
                                   (Sint16)(-axisValue));
        return;
    }
    if (action == kChimpPadActionCRight) {
        SDL_JoystickSetVirtualAxis(sVirtualJoystick, SDL_CONTROLLER_AXIS_RIGHTX,
                                   axisValue);
        return;
    }
    SDL_GameControllerButton button = SDL_CONTROLLER_BUTTON_INVALID;
    switch (action) {
        case kChimpPadActionA: button = SDL_CONTROLLER_BUTTON_A; break;
        case kChimpPadActionB: button = SDL_CONTROLLER_BUTTON_B; break;
        case kChimpPadActionL: button = SDL_CONTROLLER_BUTTON_LEFTSHOULDER; break;
        case kChimpPadActionR: button = SDL_CONTROLLER_BUTTON_RIGHTSHOULDER; break;
        case kChimpPadActionStart: button = SDL_CONTROLLER_BUTTON_START; break;
        case kChimpPadActionDUp: button = SDL_CONTROLLER_BUTTON_DPAD_UP; break;
        case kChimpPadActionDDown: button = SDL_CONTROLLER_BUTTON_DPAD_DOWN; break;
        case kChimpPadActionDLeft: button = SDL_CONTROLLER_BUTTON_DPAD_LEFT; break;
        case kChimpPadActionDRight: button = SDL_CONTROLLER_BUTTON_DPAD_RIGHT; break;
        default: break;
    }
    if (button != SDL_CONTROLLER_BUTTON_INVALID) {
        SDL_JoystickSetVirtualButton(sVirtualJoystick, button,
                                     pressed ? SDL_PRESSED : SDL_RELEASED);
    }
}

static void ChimpPad_EmitAction(ChimpPadAction action, BOOL pressed) {
    ChimpPad_Log("touch action=%s pressed=%d", ChimpPad_ActionLabel(action),
                 pressed ? 1 : 0);
    if (action == kChimpPadActionMenu) {
        /* Escape opens the host ImGui overlay and swallows game pad input while
         * open. Still emit it so Settings remains reachable. */
        SDL_Scancode scancode = ChimpPad_ActionScancode(action);
        if (scancode != SDL_SCANCODE_UNKNOWN) {
            ChimpPad_PushKey(scancode, pressed);
        }
        ChimpPad_Log("menu key (host overlay) pressed=%d", pressed ? 1 : 0);
        return;
    }
    unsigned int bit = ChimpPad_ActionN64Bit(action);
    if (bit != 0) {
        if (pressed) {
            sHeldButtons |= bit;
        } else {
            sHeldButtons &= ~bit;
        }
        ChimpPad_PublishPad();
    }
    ChimpPad_EmitVirtualButton(action, pressed);
    /* Also synthesize keyboard for any host path that still reads keys. */
    SDL_Scancode scancode = ChimpPad_ActionScancode(action);
    if (scancode != SDL_SCANCODE_UNKNOWN) {
        ChimpPad_PushKey(scancode, pressed);
    }
}

static void ChimpPad_SetAction(ChimpPadAction action, BOOL pressed) {
    int &count = sActionPressCounts[action];
    BOOL wasPressed = count > 0;
    if (pressed) {
        count += 1;
    } else {
        count = MAX(0, count - 1);
    }
    BOOL isPressed = count > 0;
    if (wasPressed != isPressed) {
        ChimpPad_EmitAction(action, isPressed);
    }
}

static void ChimpPad_SetStickAxes(Sint16 x, Sint16 y) {
    /* Convert SDL-style axes (±32767, +y down) to N64 ±80, +y up. */
    int sx = (int)x * 80 / 32767;
    int sy = -(int)y * 80 / 32767;
    if (sx < -80) sx = -80;
    if (sx > 80) sx = 80;
    if (sy < -80) sy = -80;
    if (sy > 80) sy = 80;
    if (sx > -8 && sx < 8) sx = 0;
    if (sy > -8 && sy < 8) sy = 0;
    sStickX = sx;
    sStickY = sy;
    ChimpPad_PublishPad();
    if (sVirtualJoystick != nullptr) {
        SDL_JoystickSetVirtualAxis(sVirtualJoystick, SDL_CONTROLLER_AXIS_LEFTX, x);
        SDL_JoystickSetVirtualAxis(sVirtualJoystick, SDL_CONTROLLER_AXIS_LEFTY, y);
    }
}

static void ChimpPad_AttachVirtualController(void) {
    if (sVirtualJoystick != nullptr) {
        return;
    }
    sVirtualDeviceIndex = SDL_JoystickAttachVirtual(
        SDL_JOYSTICK_TYPE_GAMECONTROLLER, 6, 16, 0);
    if (sVirtualDeviceIndex < 0) {
        ChimpPad_Log("virtual joystick attach failed: %s", SDL_GetError());
        return;
    }
    sVirtualJoystick = SDL_JoystickOpen(sVirtualDeviceIndex);
    if (sVirtualJoystick == nullptr) {
        ChimpPad_Log("virtual joystick open failed: %s", SDL_GetError());
        return;
    }
    ChimpPad_Log("virtual controller attached index=%d", sVirtualDeviceIndex);
}

static void ChimpPad_ResetAllInputs(void) {
    for (int a = 0; a < kChimpPadActionCount; ++a) {
        if (sActionPressCounts[a] > 0) {
            sActionPressCounts[a] = 0;
            ChimpPad_EmitAction((ChimpPadAction)a, NO);
        }
    }
    sHeldButtons = 0;
    sStickX = 0;
    sStickY = 0;
    /* Keep the touch source enabled so later presses merge immediately. */
    platform_ios_touch_set(0, 0, 0, sTouchControlsDesired ? 1 : 0);
    if (sVirtualJoystick != nullptr) {
        SDL_JoystickSetVirtualAxis(sVirtualJoystick, SDL_CONTROLLER_AXIS_LEFTX, 0);
        SDL_JoystickSetVirtualAxis(sVirtualJoystick, SDL_CONTROLLER_AXIS_LEFTY, 0);
        SDL_JoystickSetVirtualAxis(sVirtualJoystick, SDL_CONTROLLER_AXIS_TRIGGERLEFT,
                                   SDL_JOYSTICK_AXIS_MIN);
    }
    sTouchStickActive.store(false);
}

@interface ChimpPadTouchButton : UIButton
@property(nonatomic) ChimpPadAction action;
@property(nonatomic) BOOL inputPressed;
@property(nonatomic) BOOL outputPressed;
@property(nonatomic) BOOL holdAssistEnabled;
@property(nonatomic) BOOL holdLocked;
@property(nonatomic) BOOL usesPillShape;
@property(nonatomic) CFTimeInterval inputDownTime;
@property(nonatomic) NSUInteger releaseGeneration;
@property(nonatomic, copy) NSString *normalLabel;
@property(nonatomic, strong) UIColor *idleColor;
@property(nonatomic, strong) UIColor *pressedColor;
- (instancetype)initWithLabel:(NSString *)label
                       action:(ChimpPadAction)action
                         pill:(BOOL)pill;
- (void)applyIdleColor:(UIColor *)idle pressedColor:(UIColor *)pressed;
- (void)cancelInput;
@end

@implementation ChimpPadTouchButton
- (instancetype)initWithLabel:(NSString *)label
                       action:(ChimpPadAction)action
                         pill:(BOOL)pill {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.action = action;
        self.normalLabel = label;
        self.usesPillShape = pill;
        self.multipleTouchEnabled = YES;
        /* SpaghettiPad glass: light tint so the game stays readable. */
        self.idleColor = [UIColor colorWithWhite:0.04 alpha:0.38];
        self.pressedColor = [UIColor colorWithWhite:0.72 alpha:0.48];
        self.backgroundColor = self.idleColor;
        self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.58].CGColor;
        self.layer.borderWidth = 2.0;
        [self setTitle:label forState:UIControlStateNormal];
        [self setTitleColor:[UIColor colorWithWhite:1.0 alpha:0.92]
                   forState:UIControlStateNormal];
        self.titleLabel.font =
            [UIFont systemFontOfSize:18.0 weight:UIFontWeightSemibold];
        self.accessibilityLabel = label;
        [self addTarget:self
                      action:@selector(inputDown)
            forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter];
        [self addTarget:self
                      action:@selector(inputUp)
            forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside |
                             UIControlEventTouchCancel | UIControlEventTouchDragExit];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.layer.cornerRadius =
        self.usesPillShape ? CGRectGetHeight(self.bounds) * 0.48
                           : MIN(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds)) *
                                 0.5;
}

- (void)inputDown {
    if (sLayoutEditorActive) {
        return;
    }
    self.releaseGeneration += 1;
    if (self.inputPressed) {
        return;
    }
    BOOL wasLocked = self.holdLocked;
    self.holdLocked = NO;
    self.inputPressed = YES;
    self.inputDownTime = CACurrentMediaTime();
    [self updateOutput];
    [self updateAppearance];
    if (self.holdAssistEnabled && !wasLocked && self.action == kChimpPadActionA &&
        sGameplayActive.load()) {
        NSUInteger generation = self.releaseGeneration;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.65 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
                           if (self.releaseGeneration != generation || !self.inputPressed ||
                               !self.holdAssistEnabled || !sGameplayActive.load()) {
                               return;
                           }
                           self.holdLocked = YES;
                           [self updateOutput];
                           [self updateAppearance];
                           UIImpactFeedbackGenerator *fb =
                               [[UIImpactFeedbackGenerator alloc]
                                   initWithStyle:UIImpactFeedbackStyleMedium];
                           [fb impactOccurred];
                           ChimpPad_Log("A hold assist locked");
                       });
    }
}

- (void)finishInputRelease {
    if (!self.inputPressed) {
        return;
    }
    self.inputPressed = NO;
    [self updateOutput];
    [self updateAppearance];
}

- (void)inputUp {
    if (!self.inputPressed) {
        return;
    }
    /* SpaghettiPad: guarantee a minimum press window so short taps register. */
    if (self.action != kChimpPadActionMenu) {
        CFTimeInterval remaining =
            MAX(0.0, 0.05 - (CACurrentMediaTime() - self.inputDownTime));
        if (remaining > 0.0) {
            NSUInteger generation = ++self.releaseGeneration;
            dispatch_after(
                dispatch_time(DISPATCH_TIME_NOW, (int64_t)(remaining * NSEC_PER_SEC)),
                dispatch_get_main_queue(), ^{
                    if (self.releaseGeneration == generation) {
                        [self finishInputRelease];
                    }
                });
            return;
        }
    }
    [self finishInputRelease];
}

- (void)updateOutput {
    BOOL shouldPress = self.inputPressed || self.holdLocked;
    if (self.outputPressed == shouldPress) {
        return;
    }
    self.outputPressed = shouldPress;
    ChimpPad_SetAction(self.action, shouldPress);
}

- (void)updateAppearance {
    BOOL active = self.inputPressed || self.holdLocked;
    self.backgroundColor = active ? self.pressedColor : self.idleColor;
    if (self.holdLocked) {
        [self setTitle:@"A •" forState:UIControlStateNormal];
        self.layer.borderColor =
            [UIColor colorWithRed:0.42 green:0.88 blue:1.0 alpha:0.95].CGColor;
        self.layer.borderWidth = 4.0;
        self.accessibilityValue = @"Acceleration locked";
    } else {
        [self setTitle:self.normalLabel forState:UIControlStateNormal];
        self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.58].CGColor;
        self.layer.borderWidth = 2.0;
        self.accessibilityValue = nil;
    }
}

- (void)applyIdleColor:(UIColor *)idle pressedColor:(UIColor *)pressed {
    self.idleColor = idle;
    self.pressedColor = pressed;
    [self updateAppearance];
}

- (void)cancelInput {
    self.releaseGeneration += 1;
    self.inputPressed = NO;
    self.holdLocked = NO;
    [self updateOutput];
    [self updateAppearance];
}
@end

@interface ChimpPadTouchStick : UIView
@property(nonatomic, strong) UIView *knob;
- (void)cancelInput;
@end

@implementation ChimpPadTouchStick
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.multipleTouchEnabled = NO;
        self.backgroundColor = [UIColor colorWithWhite:0.04 alpha:0.30];
        self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.42].CGColor;
        self.layer.borderWidth = 2.0;
        self.accessibilityLabel = @"Steering";
        self.knob = [[UIView alloc] initWithFrame:CGRectZero];
        self.knob.userInteractionEnabled = NO;
        self.knob.backgroundColor =
            [UIColor colorWithRed:0.34 green:0.62 blue:0.82 alpha:0.68];
        self.knob.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.62].CGColor;
        self.knob.layer.borderWidth = 2.0;
        [self addSubview:self.knob];
    }
    return self;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    /* Expand grab area slightly beyond the drawn ring (SpaghettiPad feel). */
    CGRect expanded = CGRectInset(self.bounds, -18.0, -18.0);
    return CGRectContainsPoint(expanded, point);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat size = MIN(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds));
    self.layer.cornerRadius = size * 0.5;
    CGFloat knobSize = size * 0.43;
    self.knob.bounds = CGRectMake(0, 0, knobSize, knobSize);
    self.knob.layer.cornerRadius = knobSize * 0.5;
    if (!sTouchStickActive.load()) {
        self.knob.center =
            CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    }
}

- (void)updateForPoint:(CGPoint)point {
    CGPoint center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    CGFloat size = MIN(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds));
    CGFloat radius = size * 0.34;
    CGFloat dx = point.x - center.x;
    CGFloat dy = point.y - center.y;
    CGFloat distance = hypot(dx, dy);
    if (distance > radius && distance > 0.0) {
        dx = dx / distance * radius;
        dy = dy / distance * radius;
    }
    self.knob.center = CGPointMake(center.x + dx, center.y + dy);
    Sint16 x = (Sint16)lround(
        MAX(-1.0, MIN(1.0, (double)(dx / radius))) * SDL_JOYSTICK_AXIS_MAX);
    Sint16 y = (Sint16)lround(
        MAX(-1.0, MIN(1.0, (double)(dy / radius))) * SDL_JOYSTICK_AXIS_MAX);
    ChimpPad_SetStickAxes(x, y);
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (sLayoutEditorActive) {
        return;
    }
    UITouch *touch = touches.anyObject;
    if (!touch) {
        return;
    }
    sTouchStickActive.store(true);
    [self updateForPoint:[touch locationInView:self]];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = touches.anyObject;
    if (touch) {
        [self updateForPoint:[touch locationInView:self]];
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self cancelInput];
}
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self cancelInput];
}

- (void)cancelInput {
    sStickX = 0;
    sStickY = 0;
    ChimpPad_PublishPad();
    if (sVirtualJoystick != nullptr) {
        SDL_JoystickSetVirtualAxis(sVirtualJoystick, SDL_CONTROLLER_AXIS_LEFTX, 0);
        SDL_JoystickSetVirtualAxis(sVirtualJoystick, SDL_CONTROLLER_AXIS_LEFTY, 0);
    }
    sTouchStickActive.store(false);
    self.knob.center =
        CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
}
@end

static CGRect CP_Frame(CGPoint center, CGFloat w, CGFloat h) {
    return CGRectMake(center.x - w * 0.5, center.y - h * 0.5, w, h);
}

static CGRect CP_MenuFrame(CGRect bounds, UIEdgeInsets safe, CGFloat size) {
    return CGRectMake(CGRectGetWidth(bounds) - safe.right - size - 8.0,
                      safe.top + 4.0, size, size);
}

@interface ChimpPadTouchOverlay : UIView
@property(nonatomic, strong) ChimpPadTouchStick *stick;
@property(nonatomic, strong) NSArray<ChimpPadTouchButton *> *buttons;
@property(nonatomic, strong) ChimpPadTouchButton *buttonA;
@property(nonatomic, strong) ChimpPadTouchButton *buttonB;
@property(nonatomic, strong) ChimpPadTouchButton *buttonL;
@property(nonatomic, strong) ChimpPadTouchButton *buttonZLeft;
@property(nonatomic, strong) ChimpPadTouchButton *buttonZRight;
@property(nonatomic, strong) ChimpPadTouchButton *buttonR;
@property(nonatomic, strong) ChimpPadTouchButton *buttonStart;
@property(nonatomic, strong) ChimpPadTouchButton *cUp;
@property(nonatomic, strong) ChimpPadTouchButton *cDown;
@property(nonatomic, strong) ChimpPadTouchButton *cLeft;
@property(nonatomic, strong) ChimpPadTouchButton *cRight;
@property(nonatomic, strong) ChimpPadTouchButton *menuButton;
@property(nonatomic, strong) NSArray<UIView *> *editableControls;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSArray<NSNumber *> *> *layoutCenters;
@property(nonatomic, copy) NSString *layoutProfile;
@property(nonatomic) BOOL layoutEditing;
@property(nonatomic, strong) UIView *editorPanel;
@property(nonatomic, strong) UILabel *editorLabel;
@property(nonatomic, strong) UIButton *resetButton;
@property(nonatomic, strong) UIButton *doneButton;
- (void)cancelAllInputs;
- (void)beginLayoutEditing;
@end

@implementation ChimpPadTouchOverlay
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.multipleTouchEnabled = YES;
        self.stick = [[ChimpPadTouchStick alloc] initWithFrame:CGRectZero];
        self.buttonA = [[ChimpPadTouchButton alloc] initWithLabel:@"A"
                                                           action:kChimpPadActionA
                                                             pill:NO];
        self.buttonA.holdAssistEnabled = YES;
        self.buttonB = [[ChimpPadTouchButton alloc] initWithLabel:@"B"
                                                           action:kChimpPadActionB
                                                             pill:NO];
        self.buttonL = [[ChimpPadTouchButton alloc] initWithLabel:@"L"
                                                           action:kChimpPadActionL
                                                             pill:NO];
        /* Dual Z like SpaghettiPad: left thumb (item near stick) + right face. */
        self.buttonZLeft = [[ChimpPadTouchButton alloc] initWithLabel:@"Z"
                                                               action:kChimpPadActionZ
                                                                 pill:NO];
        self.buttonZRight = [[ChimpPadTouchButton alloc] initWithLabel:@"Z"
                                                                action:kChimpPadActionZ
                                                                  pill:NO];
        self.buttonR = [[ChimpPadTouchButton alloc] initWithLabel:@"R"
                                                           action:kChimpPadActionR
                                                             pill:NO];
        self.buttonStart = [[ChimpPadTouchButton alloc] initWithLabel:@"▶"
                                                               action:kChimpPadActionStart
                                                                 pill:NO];
        self.cUp = [[ChimpPadTouchButton alloc] initWithLabel:@"▲"
                                                       action:kChimpPadActionCUp
                                                         pill:NO];
        self.cDown = [[ChimpPadTouchButton alloc] initWithLabel:@"▼"
                                                         action:kChimpPadActionCDown
                                                           pill:NO];
        self.cLeft = [[ChimpPadTouchButton alloc] initWithLabel:@"◀"
                                                         action:kChimpPadActionCLeft
                                                           pill:NO];
        self.cRight = [[ChimpPadTouchButton alloc] initWithLabel:@"▶"
                                                          action:kChimpPadActionCRight
                                                            pill:NO];
        self.menuButton = [[ChimpPadTouchButton alloc] initWithLabel:@"•••"
                                                              action:kChimpPadActionMenu
                                                                pill:YES];

        [self.buttonA
            applyIdleColor:[UIColor colorWithRed:0.08 green:0.35 blue:0.88 alpha:0.58]
              pressedColor:[UIColor colorWithRed:0.14 green:0.48 blue:1.00 alpha:0.88]];
        [self.buttonB
            applyIdleColor:[UIColor colorWithRed:0.05 green:0.55 blue:0.24 alpha:0.58]
              pressedColor:[UIColor colorWithRed:0.10 green:0.76 blue:0.34 alpha:0.88]];
        [self.buttonStart
            applyIdleColor:[UIColor colorWithRed:0.68 green:0.12 blue:0.16 alpha:0.52]
              pressedColor:[UIColor colorWithRed:0.94 green:0.22 blue:0.26 alpha:0.88]];
        UIColor *cIdle = [UIColor colorWithRed:0.95 green:0.67 blue:0.12 alpha:0.48];
        UIColor *cPressed = [UIColor colorWithRed:1.00 green:0.78 blue:0.20 alpha:0.86];
        for (ChimpPadTouchButton *b in @[ self.cUp, self.cDown, self.cLeft, self.cRight ]) {
            [b applyIdleColor:cIdle pressedColor:cPressed];
        }

        self.buttonStart.accessibilityLabel = @"Start";
        self.buttonZLeft.accessibilityLabel = @"Z above steering";
        self.buttonZRight.accessibilityLabel = @"Z right";
        self.cUp.accessibilityLabel = @"C Up";
        self.cDown.accessibilityLabel = @"C Down";
        self.cLeft.accessibilityLabel = @"C Left";
        self.cRight.accessibilityLabel = @"C Right";
        self.menuButton.accessibilityLabel = @"Menu";

        self.stick.accessibilityIdentifier = @"stick";
        self.buttonA.accessibilityIdentifier = @"a";
        self.buttonB.accessibilityIdentifier = @"b";
        self.buttonL.accessibilityIdentifier = @"l";
        self.buttonZLeft.accessibilityIdentifier = @"z-left";
        self.buttonZRight.accessibilityIdentifier = @"z-right";
        self.buttonR.accessibilityIdentifier = @"r";
        self.buttonStart.accessibilityIdentifier = @"start";
        self.cUp.accessibilityIdentifier = @"c-up";
        self.cDown.accessibilityIdentifier = @"c-down";
        self.cLeft.accessibilityIdentifier = @"c-left";
        self.cRight.accessibilityIdentifier = @"c-right";
        self.menuButton.accessibilityIdentifier = @"menu";

        self.buttons = @[
            self.buttonA, self.buttonB, self.buttonL, self.buttonZLeft, self.buttonZRight,
            self.buttonR, self.buttonStart, self.cUp, self.cDown, self.cLeft, self.cRight,
            self.menuButton
        ];
        [self addSubview:self.stick];
        for (ChimpPadTouchButton *b in self.buttons) {
            [self addSubview:b];
        }

        self.editableControls = @[
            self.stick, self.buttonA, self.buttonB, self.buttonL,
            self.buttonZLeft, self.buttonZRight, self.buttonR, self.buttonStart,
            self.cUp, self.cDown, self.cLeft, self.cRight,
        ];
        self.layoutCenters = [NSMutableDictionary dictionary];

        self.editorPanel = [[UIView alloc] initWithFrame:CGRectZero];
        self.editorPanel.backgroundColor =
            [UIColor colorWithWhite:0.04 alpha:0.90];
        self.editorPanel.layer.cornerRadius = 14.0;
        self.editorPanel.layer.borderColor =
            [UIColor colorWithWhite:1.0 alpha:0.55].CGColor;
        self.editorPanel.layer.borderWidth = 1.5;
        self.editorPanel.hidden = YES;

        self.editorLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.editorLabel.text = @"Drag controls to move them";
        self.editorLabel.textColor = UIColor.whiteColor;
        self.editorLabel.font =
            [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
        [self.editorPanel addSubview:self.editorLabel];

        self.resetButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [self.resetButton setTitle:@"Reset" forState:UIControlStateNormal];
        [self.resetButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        self.resetButton.backgroundColor = [UIColor colorWithWhite:0.25 alpha:0.90];
        self.resetButton.layer.cornerRadius = 10.0;
        [self.resetButton addTarget:self action:@selector(resetCurrentLayout)
                   forControlEvents:UIControlEventTouchUpInside];
        [self.editorPanel addSubview:self.resetButton];

        self.doneButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [self.doneButton setTitle:@"Done" forState:UIControlStateNormal];
        [self.doneButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        self.doneButton.backgroundColor =
            [UIColor colorWithRed:0.10 green:0.48 blue:0.92 alpha:0.92];
        self.doneButton.layer.cornerRadius = 10.0;
        [self.doneButton addTarget:self action:@selector(endLayoutEditing)
                  forControlEvents:UIControlEventTouchUpInside];
        [self.editorPanel addSubview:self.doneButton];
        [self addSubview:self.editorPanel];

        for (UIView *control in self.editableControls) {
            UIPanGestureRecognizer *pan =
                [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                        action:@selector(moveControl:)];
            pan.enabled = NO;
            pan.cancelsTouchesInView = YES;
            [control addGestureRecognizer:pan];
        }
    }
    return self;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return hit == self ? nil : hit;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.superview != nil) {
        [self.superview bringSubviewToFront:self];
    }
    UIEdgeInsets safe = self.safeAreaInsets;
    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat height = CGRectGetHeight(self.bounds);
    /* SpaghettiPad: height < 560 → purpose-built phone layout (not a shrink). */
    BOOL compact = height < 560.0;

    if (compact) {
        /*
         * Keep the iPad grammar: L/Z/R above steering; A/B/Z on the outer
         * action rail; C below and inboard. Phone is a tighter version of that
         * layout, not a separate button map.
         */
        CGFloat left = safe.left + 10.0 * sTouchControlScale;
        CGFloat right = safe.right + 8.0 * sTouchControlScale;
        CGFloat bottomY = height - safe.bottom;
        CGFloat s = sTouchControlScale * MAX(0.82, MIN(1.0, height / 390.0));

        CGFloat stickSize = 112.0 * s;
        CGPoint stickCenter = CGPointMake(left + 88.0 * s, bottomY - 74.0 * s);
        self.stick.frame = CP_Frame(stickCenter, stickSize, stickSize);

        CGFloat leftButton = 46.0 * s;
        self.buttonZLeft.frame = CP_Frame(
            CGPointMake(stickCenter.x, bottomY - 172.0 * s),
            leftButton, leftButton);
        self.buttonL.frame = CP_Frame(
            CGPointMake(stickCenter.x - 52.0 * s,
                        CGRectGetMidY(self.buttonZLeft.frame)),
            leftButton, leftButton);
        self.buttonR.frame = CP_Frame(
            CGPointMake(stickCenter.x + 52.0 * s,
                        CGRectGetMidY(self.buttonZLeft.frame)),
            leftButton, leftButton);

        /* Right rail mirrors the tablet: face buttons outside, C-pad inboard. */
        CGFloat aSize = 58.0 * s;
        CGFloat bSize = 54.0 * s;
        CGFloat zSize = 50.0 * s;
        CGFloat rightEdge = width - right;
        self.buttonA.frame =
            CP_Frame(CGPointMake(rightEdge - 48.0 * s, bottomY - 62.0 * s), aSize, aSize);
        self.buttonB.frame =
            CP_Frame(CGPointMake(rightEdge - 112.0 * s, bottomY - 76.0 * s), bSize, bSize);
        self.buttonZRight.frame =
            CP_Frame(CGPointMake(rightEdge - 46.0 * s, bottomY - 136.0 * s), zSize, zSize);

        /* Move the permanent menu inward: it must be reachable without
         * stretching into the system-edge gesture area. */
        CGFloat menuSize = 36.0 * s;
        CGRect menuFrame = CP_MenuFrame(self.bounds, safe, menuSize);
        menuFrame.origin.x -= 20.0 * s;
        menuFrame.origin.y += 8.0 * s;
        self.menuButton.frame = menuFrame;
        CGFloat startSize = 44.0 * s;
        self.buttonStart.frame = CP_Frame(
            CGPointMake(CGRectGetMidX(menuFrame), CGRectGetMaxY(menuFrame) + 6.0 + startSize * 0.5),
            startSize, startSize);

        CGFloat cSize = 38.0 * s;
        CGFloat cRadius = 32.0 * s;
        CGFloat cX = rightEdge - 210.0 * s;
        CGFloat cY = bottomY - 76.0 * s;
        self.cUp.frame = CP_Frame(CGPointMake(cX, cY - cRadius), cSize, cSize);
        self.cDown.frame = CP_Frame(CGPointMake(cX, cY + cRadius), cSize, cSize);
        self.cLeft.frame = CP_Frame(CGPointMake(cX - cRadius, cY), cSize, cSize);
        self.cRight.frame = CP_Frame(CGPointMake(cX + cRadius, cY), cSize, cSize);

        for (ChimpPadTouchButton *button in self.buttons) {
            button.titleLabel.font =
                [UIFont systemFontOfSize:14.0 * s weight:UIFontWeightSemibold];
        }
        self.buttonA.titleLabel.font =
            [UIFont systemFontOfSize:17.0 * s weight:UIFontWeightBold];
        self.buttonB.titleLabel.font =
            [UIFont systemFontOfSize:16.0 * s weight:UIFontWeightBold];
        self.buttonStart.titleLabel.font =
            [UIFont systemFontOfSize:14.0 * s weight:UIFontWeightBold];
        [self finishControlLayoutForCompact:YES];
        return;
    }

    /* Tablet / large landscape — SpaghettiPad rail layout. */
    CGFloat scale = sTouchControlScale * MAX(0.78, MIN(1.12, height / 834.0));
    CGFloat usableWidth = width - safe.left - safe.right;
    CGFloat railWidth = MIN(250.0 * scale, usableWidth * 0.22);
    CGFloat leftCenter = safe.left + railWidth * 0.5;
    CGFloat rightCenter = width - safe.right - railWidth * 0.5;
    CGFloat middleCenterY = height * 0.60;
    CGFloat lowCenterY = height * 0.86;
    CGFloat stickCenterX = leftCenter + 65.0 * scale;
    CGFloat stickCenterY = lowCenterY - 70.0 * scale;
    CGFloat faceCenterX = rightCenter + 24.0 * scale;
    CGFloat faceCenterY = middleCenterY + 30.0 * scale;
    CGFloat cpadCenterX = rightCenter + 24.0 * scale;
    CGFloat cpadCenterY = lowCenterY - 20.0 * scale;

    CGFloat stickSize = 150.0 * scale;
    self.stick.frame =
        CP_Frame(CGPointMake(stickCenterX, stickCenterY), stickSize, stickSize);
    CGFloat stickZSize = 56.0 * scale;
    CGFloat stickZGap = 12.0 * scale;
    self.buttonZLeft.frame = CP_Frame(
        CGPointMake(stickCenterX,
                    CGRectGetMinY(self.stick.frame) - stickZGap - stickZSize * 0.5),
        stickZSize, stickZSize);
    self.buttonL.frame = CP_Frame(
        CGPointMake(stickCenterX - stickZSize - stickZGap,
                    CGRectGetMidY(self.buttonZLeft.frame)),
        stickZSize, stickZSize);
    self.buttonR.frame = CP_Frame(
        CGPointMake(stickCenterX + stickZSize + stickZGap,
                    CGRectGetMidY(self.buttonZLeft.frame)),
        stickZSize, stickZSize);

    CGFloat faceSize = 66.0 * scale;
    CGFloat faceX = faceCenterX - faceSize * 0.5;
    self.buttonA.frame =
        CGRectMake(faceX, faceCenterY + 12.0 * scale, faceSize, faceSize);
    self.buttonB.frame = CP_Frame(
        CGPointMake(faceX - faceSize * 0.5 - 10.0 * scale, faceCenterY), faceSize,
        faceSize);
    self.buttonZRight.frame =
        CGRectMake(faceX, faceCenterY - faceSize - 12.0 * scale, faceSize, faceSize);
    CGFloat startSize = 54.0 * scale;
    CGFloat startGap = 12.0 * scale;
    self.buttonStart.frame = CP_Frame(
        CGPointMake(CGRectGetMidX(self.buttonZRight.frame),
                    CGRectGetMinY(self.buttonZRight.frame) - startGap - startSize * 0.5),
        startSize, startSize);

    CGFloat menuSize = 44.0 * scale;
    self.menuButton.frame = CP_MenuFrame(self.bounds, safe, menuSize);

    CGFloat cSize = 46.0 * scale;
    CGFloat cRadius = 44.0 * scale;
    CGPoint cCenter = CGPointMake(cpadCenterX, cpadCenterY);
    self.cUp.frame = CP_Frame(CGPointMake(cCenter.x, cCenter.y - cRadius), cSize, cSize);
    self.cDown.frame = CP_Frame(CGPointMake(cCenter.x, cCenter.y + cRadius), cSize, cSize);
    self.cLeft.frame = CP_Frame(CGPointMake(cCenter.x - cRadius, cCenter.y), cSize, cSize);
    self.cRight.frame = CP_Frame(CGPointMake(cCenter.x + cRadius, cCenter.y), cSize, cSize);

    CGFloat labelSize = 18.0 * scale;
    for (ChimpPadTouchButton *button in self.buttons) {
        button.titleLabel.font =
            [UIFont systemFontOfSize:labelSize weight:UIFontWeightSemibold];
    }
    self.buttonStart.titleLabel.font =
        [UIFont systemFontOfSize:18.0 * scale weight:UIFontWeightBold];
    self.buttonA.titleLabel.font =
        [UIFont systemFontOfSize:20.0 * scale weight:UIFontWeightBold];
    [self finishControlLayoutForCompact:NO];
}

- (NSString *)profileForCompact:(BOOL)compact {
    return compact ? @"phone-v1" : @"tablet-v1";
}

- (NSString *)storageKeyForProfile:(NSString *)profile {
    return [@"ChimpPad.TouchLayout." stringByAppendingString:profile];
}

- (void)loadLayoutForProfile:(NSString *)profile {
    if ([self.layoutProfile isEqualToString:profile]) {
        return;
    }
    self.layoutProfile = profile;
    [self.layoutCenters removeAllObjects];
    NSDictionary *stored = [NSUserDefaults.standardUserDefaults
        dictionaryForKey:[self storageKeyForProfile:profile]];
    NSDictionary *centers = stored[@"centers"];
    if ([centers isKindOfClass:NSDictionary.class]) {
        [self.layoutCenters addEntriesFromDictionary:centers];
    }
}

- (void)clampControlToSafeBounds:(UIView *)control {
    UIEdgeInsets safe = self.safeAreaInsets;
    CGFloat halfW = CGRectGetWidth(control.bounds) * 0.5;
    CGFloat halfH = CGRectGetHeight(control.bounds) * 0.5;
    CGFloat minX = safe.left + halfW + 4.0;
    CGFloat maxX = CGRectGetWidth(self.bounds) - safe.right - halfW - 4.0;
    CGFloat minY = safe.top + halfH + 4.0;
    CGFloat maxY = CGRectGetHeight(self.bounds) - safe.bottom - halfH - 4.0;
    control.center = CGPointMake(
        MIN(MAX(control.center.x, minX), MAX(minX, maxX)),
        MIN(MAX(control.center.y, minY), MAX(minY, maxY)));
}

- (void)layoutEditorPanel {
    if (self.editorPanel.hidden) {
        return;
    }
    UIEdgeInsets safe = self.safeAreaInsets;
    CGFloat width = MIN(480.0,
        CGRectGetWidth(self.bounds) - safe.left - safe.right - 24.0);
    self.editorPanel.frame = CGRectMake(
        CGRectGetMidX(self.bounds) - width * 0.5, safe.top + 8.0, width, 58.0);
    self.editorLabel.frame = CGRectMake(14.0, 0.0, width - 190.0, 58.0);
    self.resetButton.frame = CGRectMake(width - 168.0, 8.0, 74.0, 42.0);
    self.doneButton.frame = CGRectMake(width - 86.0, 8.0, 74.0, 42.0);
}

- (void)finishControlLayoutForCompact:(BOOL)compact {
    [self loadLayoutForProfile:[self profileForCompact:compact]];
    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat height = CGRectGetHeight(self.bounds);
    for (UIView *control in self.editableControls) {
        NSArray<NSNumber *> *center = self.layoutCenters[control.accessibilityIdentifier];
        if ([center isKindOfClass:NSArray.class] && center.count == 2) {
            control.center = CGPointMake(
                center[0].doubleValue * width,
                center[1].doubleValue * height);
        }
        [self clampControlToSafeBounds:control];
        control.layer.shadowColor =
            [UIColor colorWithRed:1.0 green:0.78 blue:0.16 alpha:1.0].CGColor;
        control.layer.shadowRadius = self.layoutEditing ? 6.0 : 0.0;
        control.layer.shadowOpacity = self.layoutEditing ? 0.9 : 0.0;
        control.layer.shadowOffset = CGSizeZero;
    }
    [self layoutEditorPanel];
    if (self.layoutEditing) {
        [self bringSubviewToFront:self.editorPanel];
    }
}

- (void)saveCurrentLayout {
    if (self.layoutProfile.length == 0) {
        return;
    }
    [NSUserDefaults.standardUserDefaults
        setObject:@{ @"centers": [self.layoutCenters copy] }
           forKey:[self storageKeyForProfile:self.layoutProfile]];
}

- (void)moveControl:(UIPanGestureRecognizer *)gesture {
    UIView *control = gesture.view;
    if (!self.layoutEditing || control == nil) {
        return;
    }
    CGPoint delta = [gesture translationInView:self];
    control.center = CGPointMake(control.center.x + delta.x,
                                 control.center.y + delta.y);
    [gesture setTranslation:CGPointZero inView:self];
    [self clampControlToSafeBounds:control];
    self.layoutCenters[control.accessibilityIdentifier] = @[
        @(control.center.x / CGRectGetWidth(self.bounds)),
        @(control.center.y / CGRectGetHeight(self.bounds)),
    ];
}

- (void)resetCurrentLayout {
    [self.layoutCenters removeAllObjects];
    [NSUserDefaults.standardUserDefaults
        removeObjectForKey:[self storageKeyForProfile:self.layoutProfile]];
    [self setNeedsLayout];
}

- (void)beginLayoutEditing {
    if (self.layoutEditing) {
        return;
    }
    [self cancelAllInputs];
    sLayoutEditorActive = YES;
    self.layoutEditing = YES;
    for (UIView *control in self.editableControls) {
        for (UIGestureRecognizer *gesture in control.gestureRecognizers) {
            if ([gesture isKindOfClass:UIPanGestureRecognizer.class]) {
                gesture.enabled = YES;
            }
        }
    }
    self.editorPanel.hidden = NO;
    self.menuButton.hidden = YES;
    [self setNeedsLayout];
    ChimpPad_Log("touch layout editor opened");
}

- (void)endLayoutEditing {
    if (!self.layoutEditing) {
        return;
    }
    [self saveCurrentLayout];
    self.layoutEditing = NO;
    sLayoutEditorActive = NO;
    for (UIView *control in self.editableControls) {
        for (UIGestureRecognizer *gesture in control.gestureRecognizers) {
            if ([gesture isKindOfClass:UIPanGestureRecognizer.class]) {
                gesture.enabled = NO;
            }
        }
    }
    self.editorPanel.hidden = YES;
    self.menuButton.hidden = !sTouchControlsDesired;
    [self setNeedsLayout];
    ChimpPad_Log("touch layout saved");
}

- (void)cancelAllInputs {
    [self.stick cancelInput];
    for (ChimpPadTouchButton *b in self.buttons) {
        [b cancelInput];
    }
}
@end



static ChimpPadTouchOverlay *sOverlay;

static void ChimpPad_ApplyTouchControlsState(void) {
    if (sOverlay == nil) {
        return;
    }
    if (sLayoutEditorActive) {
        for (ChimpPadTouchButton *b in sOverlay.buttons) {
            b.hidden = b == sOverlay.menuButton;
        }
        sOverlay.stick.hidden = NO;
        return;
    }
    const BOOL show = sTouchControlsDesired;
    const BOOL menuOpen = sMenuVisible.load();
    /* Race controls hide while the host ImGui menu is open so they never sit
     * on top of it; the persistent ••• button stays reachable to come back.
     * Matches SpaghettiPad's "settings menu hides the race controls" design. */
    for (ChimpPadTouchButton *b in sOverlay.buttons) {
        b.hidden = !show || menuOpen;
    }
    sOverlay.stick.hidden = !show || menuOpen;
    sOverlay.menuButton.hidden = !show;
    if (!show || menuOpen) {
        [sOverlay cancelAllInputs];
        ChimpPad_ResetAllInputs();
    }
}

static void ChimpPad_InstallOverlay(void) {
    if (sOverlay != nil || sSDLWindow == nil) {
        return;
    }
    /* Apply the persisted touch-control size before the first layout. */
    const std::string scaleText = AppConfig::get("touch_control_scale", "1.0");
    const float parsedScale = (float)std::atof(scaleText.c_str());
    sTouchControlScale = parsedScale < 0.5f ? 0.5f
                       : (parsedScale > 2.0f ? 2.0f : parsedScale);
    sOverlay = [[ChimpPadTouchOverlay alloc] initWithFrame:sSDLWindow.bounds];
    sOverlay.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [sSDLWindow addSubview:sOverlay];
    sOverlay.userInteractionEnabled = YES;
    sOverlay.opaque = NO;
    sOverlay.alpha = 1.0;
    [sSDLWindow bringSubviewToFront:sOverlay];
    ChimpPad_AttachVirtualController();
    platform_ios_touch_set(0, 0, 0, 1);
    ChimpPad_ApplyTouchControlsState();
    ChimpPad_Log("touch overlay installed");
}

void ChimpPad_OnWindowCreated(struct SDL_Window *window) {
    if (window == nullptr) {
        return;
    }
    SDL_SysWMinfo info;
    SDL_VERSION(&info.version);
    if (SDL_GetWindowWMInfo(window, &info)) {
#if defined(SDL_VIDEO_DRIVER_UIKIT)
        sSDLWindow = info.info.uikit.window;
#endif
    } else {
        ChimpPad_Log("SDL_GetWindowWMInfo failed: %s", SDL_GetError());
    }
    if (sSDLWindow == nil) {
        /* Fallback: key window / first app window (Metal path race). */
        sSDLWindow = UIApplication.sharedApplication.keyWindow;
        if (sSDLWindow == nil && UIApplication.sharedApplication.windows.count > 0) {
            sSDLWindow = UIApplication.sharedApplication.windows.firstObject;
        }
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }
            UIWindowScene *ws = (UIWindowScene *)scene;
            for (UIWindow *w in ws.windows) {
                if (w.isKeyWindow || sSDLWindow == nil) {
                    sSDLWindow = w;
                }
            }
        }
        ChimpPad_Log("UIKit window fallback used=%d", sSDLWindow != nil ? 1 : 0);
    }
    if (sSDLWindow == nil) {
        ChimpPad_Log("no UIKit window yet — retrying install shortly");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            if (sSDLWindow == nil) {
                sSDLWindow = UIApplication.sharedApplication.keyWindow;
                for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
                    if (![scene isKindOfClass:[UIWindowScene class]]) continue;
                    for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                        sSDLWindow = w;
                    }
                }
            }
            ChimpPad_InstallOverlay();
        });
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        ChimpPad_InstallOverlay();
    });
}

int ChimpPad_TouchControlsAvailable(void) {
#if TARGET_OS_IOS
    return 1;
#else
    return 0;
#endif
}

void ChimpPad_InitializeTouchControls(void) {
    sTouchControlsDesired = YES;
    ChimpPad_Log("initialize touch controls");
    if (sSDLWindow != nil) {
        ChimpPad_InstallOverlay();
    }
}

void ChimpPad_SetTouchControlsEnabled(int enabled) {
    sTouchControlsDesired = enabled ? YES : NO;
    ChimpPad_ApplyTouchControlsState();
}

void ChimpPad_SetGameplayActive(int active) {
    sGameplayActive.store(active != 0);
    if (!active && sOverlay != nil) {
        [sOverlay cancelAllInputs];
    }
}

void ChimpPad_SetMenuVisible(int visible) {
    sMenuVisible.store(visible != 0);
    ChimpPad_ApplyTouchControlsState();
}

/* Called by the host overlay (ui_overlay.cpp) whenever the ImGui menu opens or
 * closes so the race controls never cover it. Weak on the engine side; this
 * definition is what makes the hook live on iOS. */
extern "C" void platform_ios_touch_menu_visible(int visible) {
    dispatch_async(dispatch_get_main_queue(), ^{
        ChimpPad_SetMenuVisible(visible);
    });
}

/* Called by the Settings panel's "Touch control size" slider. */
extern "C" void platform_ios_touch_set_scale(float scale) {
    dispatch_async(dispatch_get_main_queue(), ^{
        const float clamped = scale < 0.5f ? 0.5f : (scale > 2.0f ? 2.0f : scale);
        if (clamped == sTouchControlScale) {
            return;
        }
        sTouchControlScale = clamped;
        [sOverlay setNeedsLayout];
        ChimpPad_Log("touch control scale=%.2f", (double)clamped);
    });
}

extern "C" int platform_ios_touch_get_preset(void) {
    if (sTouchControlScale < 0.875f) return 1;
    if (sTouchControlScale < 1.125f) return 2;
    if (sTouchControlScale < 1.375f) return 3;
    return 4;
}

extern "C" void platform_ios_touch_set_preset(int preset) {
    static const float scales[] = { 0.75f, 1.0f, 1.25f, 1.5f };
    int index = MAX(1, MIN(4, preset)) - 1;
    float scale = scales[index];
    char value[16];
    std::snprintf(value, sizeof(value), "%.2f", (double)scale);
    AppConfig::setAndSave("touch_control_scale", value);
    platform_ios_touch_set_scale(scale);
}

extern "C" void platform_ios_touch_begin_edit(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        ChimpPad_SetMenuVisible(0);
        [sOverlay beginLayoutEditing];
    });
}

void ChimpPad_BeginTouchLayoutEditing(void) {
    platform_ios_touch_begin_edit();
}

float ChimpPad_RecommendedMenuScale(void) {
    if (sSDLWindow == nil) {
        return 1.0f;
    }
    CGFloat shortSide =
        MIN(CGRectGetWidth(sSDLWindow.bounds), CGRectGetHeight(sSDLWindow.bounds));
    if (shortSide >= 600.0) {
        return 1.15f;
    }
    return 1.0f;
}
