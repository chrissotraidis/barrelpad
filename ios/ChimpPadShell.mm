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

#include <SDL.h>
#include <SDL_syswm.h>

#include "ChimpPadTouchControls.h"
#include "ChimpPadInput.h"

static UIWindow *sSDLWindow;
static SDL_Joystick *sVirtualJoystick;
static int sVirtualDeviceIndex = -1;
static std::array<int, kChimpPadActionCount> sActionPressCounts = {};
static std::atomic_bool sMenuVisible(false);
static std::atomic_bool sTouchStickActive(false);
static std::atomic_bool sGameplayActive(true);
static BOOL sTouchControlsDesired = YES;

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

static SDL_GameControllerButton ChimpPad_ActionButton(ChimpPadAction action) {
    switch (action) {
        case kChimpPadActionA:
            return SDL_CONTROLLER_BUTTON_A;
        case kChimpPadActionB:
            return SDL_CONTROLLER_BUTTON_B;
        case kChimpPadActionL:
            return SDL_CONTROLLER_BUTTON_LEFTSHOULDER;
        case kChimpPadActionR:
            return SDL_CONTROLLER_BUTTON_RIGHTSHOULDER;
        case kChimpPadActionStart:
            return SDL_CONTROLLER_BUTTON_START;
        case kChimpPadActionDUp:
            return SDL_CONTROLLER_BUTTON_DPAD_UP;
        case kChimpPadActionDDown:
            return SDL_CONTROLLER_BUTTON_DPAD_DOWN;
        case kChimpPadActionDLeft:
            return SDL_CONTROLLER_BUTTON_DPAD_LEFT;
        case kChimpPadActionDRight:
            return SDL_CONTROLLER_BUTTON_DPAD_RIGHT;
        case kChimpPadActionCDown:
            return SDL_CONTROLLER_BUTTON_X;
        case kChimpPadActionCLeft:
            return SDL_CONTROLLER_BUTTON_Y;
        default:
            return SDL_CONTROLLER_BUTTON_INVALID;
    }
}

static void ChimpPad_EmitAction(ChimpPadAction action, BOOL pressed) {
    ChimpPad_Log("touch action=%s pressed=%d", ChimpPad_ActionLabel(action),
                 pressed ? 1 : 0);
    if (action != kChimpPadActionMenu && sVirtualJoystick != nullptr) {
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
        if (action == kChimpPadActionCRight) {
            SDL_JoystickSetVirtualAxis(sVirtualJoystick, SDL_CONTROLLER_AXIS_RIGHTX,
                                       axisValue);
            return;
        }
        SDL_GameControllerButton button = ChimpPad_ActionButton(action);
        if (button != SDL_CONTROLLER_BUTTON_INVALID) {
            SDL_JoystickSetVirtualButton(sVirtualJoystick, button,
                                         pressed ? SDL_PRESSED : SDL_RELEASED);
            return;
        }
    }
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
    if (sVirtualJoystick != nullptr) {
        SDL_JoystickSetVirtualAxis(sVirtualJoystick, SDL_CONTROLLER_AXIS_LEFTX, x);
        SDL_JoystickSetVirtualAxis(sVirtualJoystick, SDL_CONTROLLER_AXIS_LEFTY, y);
        return;
    }
    /* Keyboard fallback for stick via host WASD/arrows. */
    const Sint16 thr = SDL_JOYSTICK_AXIS_MAX / 3;
    ChimpPad_PushKey(SDL_SCANCODE_LEFT, x < -thr);
    ChimpPad_PushKey(SDL_SCANCODE_RIGHT, x > thr);
    ChimpPad_PushKey(SDL_SCANCODE_UP, y < -thr);
    ChimpPad_PushKey(SDL_SCANCODE_DOWN, y > thr);
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
    ChimpPad_SetStickAxes(0, 0);
    sTouchStickActive.store(false);
}

@interface ChimpPadTouchButton : UIButton
@property(nonatomic) ChimpPadAction action;
@property(nonatomic) BOOL inputPressed;
@property(nonatomic) BOOL outputPressed;
@property(nonatomic) BOOL holdAssistEnabled;
@property(nonatomic) BOOL holdLocked;
@property(nonatomic) CFTimeInterval inputDownTime;
@property(nonatomic) NSUInteger releaseGeneration;
@property(nonatomic, copy) NSString *normalLabel;
@property(nonatomic, strong) UIColor *idleColor;
@property(nonatomic, strong) UIColor *pressedColor;
- (instancetype)initWithLabel:(NSString *)label action:(ChimpPadAction)action;
- (void)applyIdleColor:(UIColor *)idle pressedColor:(UIColor *)pressed;
- (void)cancelInput;
@end

@implementation ChimpPadTouchButton
- (instancetype)initWithLabel:(NSString *)label action:(ChimpPadAction)action {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.action = action;
        self.normalLabel = label;
        self.multipleTouchEnabled = YES;
        self.idleColor = [UIColor colorWithWhite:0.04 alpha:0.38];
        self.pressedColor = [UIColor colorWithWhite:0.72 alpha:0.48];
        self.backgroundColor = self.idleColor;
        self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.58].CGColor;
        self.layer.borderWidth = 2.0;
        [self setTitle:label forState:UIControlStateNormal];
        [self setTitleColor:[UIColor colorWithWhite:1.0 alpha:0.92]
                   forState:UIControlStateNormal];
        self.titleLabel.font =
            [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
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
    CGFloat m = MIN(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds));
    self.layer.cornerRadius = m * 0.5;
}

- (void)inputDown {
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

- (void)inputUp {
    if (!self.inputPressed) {
        return;
    }
    self.inputPressed = NO;
    [self updateOutput];
    [self updateAppearance];
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
        self.layer.borderWidth = 3.0;
    } else {
        [self setTitle:self.normalLabel forState:UIControlStateNormal];
        self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.58].CGColor;
        self.layer.borderWidth = 2.0;
    }
}

- (void)applyIdleColor:(UIColor *)idle pressedColor:(UIColor *)pressed {
    self.idleColor = idle;
    self.pressedColor = pressed;
    self.backgroundColor = idle;
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
    ChimpPadStickState st = ChimpPad_StickFromTouch(dx, dy, (float)radius);
    Sint16 x = (Sint16)lround(st.x * SDL_JOYSTICK_AXIS_MAX);
    /* ChimpPad_StickFromTouch already uses +up N64; SDL left-stick +y is down. */
    Sint16 y = (Sint16)lround(-st.y * SDL_JOYSTICK_AXIS_MAX);
    ChimpPad_SetStickAxes(x, y);
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
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
    ChimpPad_SetStickAxes(0, 0);
    sTouchStickActive.store(false);
    self.knob.center =
        CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
}
@end

static CGRect CP_Frame(CGPoint center, CGFloat w, CGFloat h) {
    return CGRectMake(center.x - w * 0.5, center.y - h * 0.5, w, h);
}

@interface ChimpPadTouchOverlay : UIView
@property(nonatomic, strong) ChimpPadTouchStick *stick;
@property(nonatomic, strong) NSArray<ChimpPadTouchButton *> *buttons;
@property(nonatomic, strong) ChimpPadTouchButton *buttonA;
@property(nonatomic, strong) ChimpPadTouchButton *buttonB;
@property(nonatomic, strong) ChimpPadTouchButton *buttonL;
@property(nonatomic, strong) ChimpPadTouchButton *buttonZ;
@property(nonatomic, strong) ChimpPadTouchButton *buttonR;
@property(nonatomic, strong) ChimpPadTouchButton *buttonStart;
@property(nonatomic, strong) ChimpPadTouchButton *cUp;
@property(nonatomic, strong) ChimpPadTouchButton *cDown;
@property(nonatomic, strong) ChimpPadTouchButton *cLeft;
@property(nonatomic, strong) ChimpPadTouchButton *cRight;
@property(nonatomic, strong) ChimpPadTouchButton *menuButton;
- (void)cancelAllInputs;
@end

@implementation ChimpPadTouchOverlay
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.clearColor;
        self.multipleTouchEnabled = YES;
        self.stick = [[ChimpPadTouchStick alloc] initWithFrame:CGRectZero];
        self.buttonA = [[ChimpPadTouchButton alloc] initWithLabel:@"A"
                                                           action:kChimpPadActionA];
        self.buttonA.holdAssistEnabled = YES;
        self.buttonB = [[ChimpPadTouchButton alloc] initWithLabel:@"B"
                                                           action:kChimpPadActionB];
        self.buttonL = [[ChimpPadTouchButton alloc] initWithLabel:@"L"
                                                           action:kChimpPadActionL];
        self.buttonZ = [[ChimpPadTouchButton alloc] initWithLabel:@"Z"
                                                           action:kChimpPadActionZ];
        self.buttonR = [[ChimpPadTouchButton alloc] initWithLabel:@"R"
                                                           action:kChimpPadActionR];
        self.buttonStart = [[ChimpPadTouchButton alloc] initWithLabel:@"▶"
                                                               action:kChimpPadActionStart];
        self.cUp = [[ChimpPadTouchButton alloc] initWithLabel:@"▲"
                                                       action:kChimpPadActionCUp];
        self.cDown = [[ChimpPadTouchButton alloc] initWithLabel:@"▼"
                                                         action:kChimpPadActionCDown];
        self.cLeft = [[ChimpPadTouchButton alloc] initWithLabel:@"◀"
                                                         action:kChimpPadActionCLeft];
        self.cRight = [[ChimpPadTouchButton alloc] initWithLabel:@"▶"
                                                          action:kChimpPadActionCRight];
        self.menuButton = [[ChimpPadTouchButton alloc] initWithLabel:@"•••"
                                                              action:kChimpPadActionMenu];

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
            b.idleColor = cIdle;
            b.pressedColor = cPressed;
            b.backgroundColor = cIdle;
        }

        self.buttons = @[
            self.buttonA, self.buttonB, self.buttonL, self.buttonZ, self.buttonR,
            self.buttonStart, self.cUp, self.cDown, self.cLeft, self.cRight,
            self.menuButton
        ];
        [self addSubview:self.stick];
        for (ChimpPadTouchButton *b in self.buttons) {
            [self addSubview:b];
        }
    }
    return self;
}

/* Silence missing applyIdleColor if category not on base — implement here. */
- (void)doesNotRecognizeSelector:(SEL)aSelector {
    [super doesNotRecognizeSelector:aSelector];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return hit == self ? nil : hit;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    UIEdgeInsets safe = self.safeAreaInsets;
    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat height = CGRectGetHeight(self.bounds);
    ChimpPadLayoutKind kind = ChimpPad_LayoutKindForSize((float)width, (float)height);
    BOOL phone = (kind == kChimpPadLayoutPhone);

    CGFloat left = safe.left + (phone ? 10.0 : 24.0);
    CGFloat right = safe.right + (phone ? 10.0 : 24.0);
    CGFloat bottom = safe.bottom + (phone ? 10.0 : 20.0);
    CGFloat top = safe.top + 8.0;

    CGFloat stickSize = phone ? 124.0 : 150.0;
    CGPoint stickCenter =
        CGPointMake(left + stickSize * 0.55, height - bottom - stickSize * 0.55);
    self.stick.frame = CP_Frame(stickCenter, stickSize, stickSize);

    CGFloat shoulder = phone ? 48.0 : 54.0;
    self.buttonZ.frame =
        CP_Frame(CGPointMake(stickCenter.x + 8.0,
                             CGRectGetMinY(self.stick.frame) - 8.0 - shoulder * 0.5),
                 shoulder, shoulder);
    self.buttonL.frame =
        CP_Frame(CGPointMake(stickCenter.x - shoulder - 4.0,
                             CGRectGetMidY(self.buttonZ.frame)),
                 shoulder, shoulder);

    CGFloat aSize = phone ? 78.0 : 90.0;
    CGFloat bSize = phone ? 64.0 : 72.0;
    CGFloat rSize = phone ? 56.0 : 64.0;
    CGPoint aCenter =
        CGPointMake(width - right - aSize * 0.55, height - bottom - aSize * 0.55);
    self.buttonA.frame = CP_Frame(aCenter, aSize, aSize);
    self.buttonB.frame =
        CP_Frame(CGPointMake(aCenter.x - bSize - 12.0, aCenter.y + 8.0), bSize, bSize);
    self.buttonR.frame =
        CP_Frame(CGPointMake(aCenter.x + 4.0, aCenter.y - aSize * 0.85), rSize, rSize);

    CGFloat cSize = phone ? 40.0 : 46.0;
    CGPoint cCenter = CGPointMake(aCenter.x - 10.0, top + cSize * 2.2 + 20.0);
    self.cUp.frame = CP_Frame(CGPointMake(cCenter.x, cCenter.y - cSize), cSize, cSize);
    self.cDown.frame = CP_Frame(CGPointMake(cCenter.x, cCenter.y + cSize), cSize, cSize);
    self.cLeft.frame = CP_Frame(CGPointMake(cCenter.x - cSize, cCenter.y), cSize, cSize);
    self.cRight.frame = CP_Frame(CGPointMake(cCenter.x + cSize, cCenter.y), cSize, cSize);

    CGFloat startW = phone ? 52.0 : 58.0;
    self.menuButton.frame =
        CGRectMake(width - right - startW, top, startW, 28.0);
    self.buttonStart.frame =
        CGRectMake(width - right - startW, top + 32.0, startW, 36.0);

    ChimpPad_Log("layout kind=%s size=%.0fx%.0f safe L%.0f R%.0f T%.0f B%.0f",
                 phone ? "phone" : "tablet", width, height, safe.left, safe.right,
                 safe.top, safe.bottom);
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
    BOOL show = sTouchControlsDesired && !sMenuVisible.load();
    sOverlay.hidden = !show;
    if (!show) {
        [sOverlay cancelAllInputs];
        ChimpPad_ResetAllInputs();
    }
}

static void ChimpPad_InstallOverlay(void) {
    if (sOverlay != nil || sSDLWindow == nil) {
        return;
    }
    sOverlay = [[ChimpPadTouchOverlay alloc] initWithFrame:sSDLWindow.bounds];
    sOverlay.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [sSDLWindow addSubview:sOverlay];
    ChimpPad_AttachVirtualController();
    ChimpPad_ApplyTouchControlsState();
    ChimpPad_Log("touch overlay installed");
}

void ChimpPad_OnWindowCreated(struct SDL_Window *window) {
    if (window == nullptr) {
        return;
    }
    SDL_SysWMinfo info;
    SDL_VERSION(&info.version);
    if (!SDL_GetWindowWMInfo(window, &info)) {
        ChimpPad_Log("SDL_GetWindowWMInfo failed: %s", SDL_GetError());
        return;
    }
#if defined(SDL_VIDEO_DRIVER_UIKIT)
    sSDLWindow = info.info.uikit.window;
#endif
    if (sSDLWindow == nil) {
        ChimpPad_Log("no UIKit window yet");
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
