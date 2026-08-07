#include "BarrelPadInput.h"

#include <math.h>
#include <string.h>

#ifndef BARRELPAD_PI
#define BARRELPAD_PI 3.14159265358979323846f
#endif

static float clampf(float v, float lo, float hi) {
    if (v < lo) {
        return lo;
    }
    if (v > hi) {
        return hi;
    }
    return v;
}

BarrelPadStickState BarrelPad_StickFromTouch(float dx, float dy, float radius) {
    BarrelPadStickState s = {0.f, 0.f};
    if (radius <= 1.f) {
        return s;
    }
    /* UIKit y grows down; N64 stick y is +up. Invert dy. */
    float nx = dx / radius;
    float ny = -dy / radius;
    float mag = sqrtf(nx * nx + ny * ny);
    if (mag > 1.f && mag > 0.f) {
        nx /= mag;
        ny /= mag;
    }
    /* Small deadzone so resting finger does not drift menus. */
    const float dead = 0.08f;
    if (fabsf(nx) < dead) {
        nx = 0.f;
    }
    if (fabsf(ny) < dead) {
        ny = 0.f;
    }
    s.x = clampf(nx, -1.f, 1.f);
    s.y = clampf(ny, -1.f, 1.f);
    return s;
}

void BarrelPad_StickToN64(BarrelPadStickState s, int8_t *outX, int8_t *outY) {
    /* Golden Balloon scales SDL ±32767 → approx ±80; we match ±80 directly. */
    float x = clampf(s.x, -1.f, 1.f) * 80.f;
    float y = clampf(s.y, -1.f, 1.f) * 80.f;
    if (outX) {
        *outX = (int8_t)lroundf(x);
    }
    if (outY) {
        *outY = (int8_t)lroundf(y);
    }
}

BarrelPadLayoutRect BarrelPad_SafeAreaBounds(BarrelPadSafeArea safe) {
    BarrelPadLayoutRect r;
    r.x = safe.left;
    r.y = safe.top;
    r.w = safe.width - safe.left - safe.right;
    r.h = safe.height - safe.top - safe.bottom;
    if (r.w < 1.f) {
        r.w = 1.f;
    }
    if (r.h < 1.f) {
        r.h = 1.f;
    }
    return r;
}

BarrelPadLayoutKind BarrelPad_LayoutKindForSize(float width, float height) {
    float shortSide = width < height ? width : height;
    /* iPad mini short side ~744 pt; phones ≤ 500 pt short side landscape height. */
    if (shortSide >= 600.f) {
        return kBarrelPadLayoutTablet;
    }
    return kBarrelPadLayoutPhone;
}

BarrelPadLayoutRect BarrelPad_AbsoluteRect(BarrelPadLayoutRect bounds,
                                         BarrelPadLayoutRect normalized) {
    BarrelPadLayoutRect r;
    r.x = bounds.x + normalized.x * bounds.w;
    r.y = bounds.y + normalized.y * bounds.h;
    r.w = normalized.w * bounds.w;
    r.h = normalized.h * bounds.h;
    return r;
}

const char *BarrelPad_ActionLabel(BarrelPadAction action) {
    switch (action) {
        case kBarrelPadActionA:
            return "A";
        case kBarrelPadActionB:
            return "B";
        case kBarrelPadActionL:
            return "L";
        case kBarrelPadActionR:
            return "R";
        case kBarrelPadActionZ:
            return "Z";
        case kBarrelPadActionStart:
            return "Start";
        case kBarrelPadActionDUp:
            return "D-Up";
        case kBarrelPadActionDDown:
            return "D-Down";
        case kBarrelPadActionDLeft:
            return "D-Left";
        case kBarrelPadActionDRight:
            return "D-Right";
        case kBarrelPadActionCUp:
            return "C-Up";
        case kBarrelPadActionCDown:
            return "C-Down";
        case kBarrelPadActionCLeft:
            return "C-Left";
        case kBarrelPadActionCRight:
            return "C-Right";
        case kBarrelPadActionMenu:
            return "Menu";
        default:
            return "?";
    }
}

const char *BarrelPad_HostKeyToken(BarrelPadAction action) {
    /* Matches Golden Balloon platform_sdl_min.c keyboard map. */
    switch (action) {
        case kBarrelPadActionA:
            return "X"; /* accelerate */
        case kBarrelPadActionB:
            return "Z"; /* brake */
        case kBarrelPadActionL:
            return "Q";
        case kBarrelPadActionR:
            return "SPACE"; /* hop / slide */
        case kBarrelPadActionZ:
            return "SHIFT"; /* item */
        case kBarrelPadActionStart:
            return "RETURN";
        case kBarrelPadActionCUp:
            return "I";
        case kBarrelPadActionCDown:
            return "K";
        case kBarrelPadActionCLeft:
            return "J";
        case kBarrelPadActionCRight:
            return "L";
        case kBarrelPadActionDUp:
            return "UP";
        case kBarrelPadActionDDown:
            return "DOWN";
        case kBarrelPadActionDLeft:
            return "LEFT";
        case kBarrelPadActionDRight:
            return "RIGHT";
        case kBarrelPadActionMenu:
            return "ESCAPE";
        default:
            return "";
    }
}

void BarrelPad_HoldAssistInit(BarrelPadHoldAssist *h, double thresholdSec) {
    if (!h) {
        return;
    }
    memset(h, 0, sizeof(*h));
    h->enabled = true;
    h->holdThresholdSec = thresholdSec > 0.05 ? thresholdSec : 0.65;
}

bool BarrelPad_HoldAssistOnA(BarrelPadHoldAssist *h, bool fingerDown, double nowSec) {
    if (!h || !h->enabled) {
        return fingerDown;
    }
    if (fingerDown) {
        if (!h->fingerDown) {
            h->fingerDown = true;
            h->downTime = nowSec;
            /* Tap while locked releases. */
            if (h->locked) {
                h->locked = false;
                return false;
            }
        } else if (!h->locked &&
                   (nowSec - h->downTime) >= h->holdThresholdSec) {
            h->locked = true;
        }
        return true;
    }
    /* Finger up: if locked, keep A; else release. */
    h->fingerDown = false;
    return h->locked;
}

void BarrelPad_HoldAssistForceRelease(BarrelPadHoldAssist *h) {
    if (!h) {
        return;
    }
    h->locked = false;
    h->fingerDown = false;
    h->downTime = 0.0;
}

int BarrelPad_DefaultLayout(BarrelPadLayoutKind kind,
                           BarrelPadControlSpec *outSpecs,
                           int maxSpecs) {
    if (!outSpecs || maxSpecs <= 0) {
        return 0;
    }

    /* SpaghettiPad-style grip: stick + L/Z/R left; face A/B/Z + C right. */
    enum { kMax = 16 };
    BarrelPadControlSpec phone[kMax];
    BarrelPadControlSpec tablet[kMax];
    int n = 0;
    BarrelPadControlSpec *dst = (kind == kBarrelPadLayoutTablet) ? tablet : phone;

    dst[n++] = (BarrelPadControlSpec){
        .action = kBarrelPadActionA,
        .label = "Stick",
        .rect = {.x = 0.04f, .y = 0.52f, .w = 0.24f, .h = 0.40f},
        .isStick = true,
    };
    /* L / Z / R row above the stick (left thumb). */
    dst[n++] = (BarrelPadControlSpec){
        .action = kBarrelPadActionL,
        .label = "L",
        .rect = {.x = 0.02f, .y = 0.36f, .w = 0.09f, .h = 0.12f},
    };
    dst[n++] = (BarrelPadControlSpec){
        .action = kBarrelPadActionZ,
        .label = "Z",
        .rect = {.x = 0.12f, .y = 0.36f, .w = 0.09f, .h = 0.12f},
    };
    dst[n++] = (BarrelPadControlSpec){
        .action = kBarrelPadActionR,
        .label = "R",
        .rect = {.x = 0.22f, .y = 0.36f, .w = 0.09f, .h = 0.12f},
    };

    if (kind == kBarrelPadLayoutPhone) {
        dst[n++] = (BarrelPadControlSpec){
            .action = kBarrelPadActionA,
            .label = "A",
            .rect = {.x = 0.78f, .y = 0.62f, .w = 0.14f, .h = 0.20f},
        };
        dst[n++] = (BarrelPadControlSpec){
            .action = kBarrelPadActionB,
            .label = "B",
            .rect = {.x = 0.62f, .y = 0.58f, .w = 0.12f, .h = 0.16f},
        };
        dst[n++] = (BarrelPadControlSpec){
            .action = kBarrelPadActionZ,
            .label = "Z",
            .rect = {.x = 0.76f, .y = 0.40f, .w = 0.12f, .h = 0.14f},
        };
        dst[n++] = (BarrelPadControlSpec){
            .action = kBarrelPadActionCUp,
            .label = "C↑",
            .rect = {.x = 0.78f, .y = 0.18f, .w = 0.07f, .h = 0.09f},
        };
        dst[n++] = (BarrelPadControlSpec){
            .action = kBarrelPadActionCDown,
            .label = "C↓",
            .rect = {.x = 0.78f, .y = 0.32f, .w = 0.07f, .h = 0.09f},
        };
        dst[n++] = (BarrelPadControlSpec){
            .action = kBarrelPadActionCLeft,
            .label = "C←",
            .rect = {.x = 0.70f, .y = 0.25f, .w = 0.07f, .h = 0.09f},
        };
        dst[n++] = (BarrelPadControlSpec){
            .action = kBarrelPadActionCRight,
            .label = "C→",
            .rect = {.x = 0.86f, .y = 0.25f, .w = 0.07f, .h = 0.09f},
        };
        dst[n++] = (BarrelPadControlSpec){
            .action = kBarrelPadActionStart,
            .label = "Start",
            .rect = {.x = 0.88f, .y = 0.08f, .w = 0.08f, .h = 0.09f},
        };
        dst[n++] = (BarrelPadControlSpec){
            .action = kBarrelPadActionMenu,
            .label = "•••",
            .rect = {.x = 0.88f, .y = 0.00f, .w = 0.08f, .h = 0.07f},
        };
    } else {
        dst[n++] = (BarrelPadControlSpec){
            .action = kBarrelPadActionA,
            .label = "A",
            .rect = {.x = 0.80f, .y = 0.52f, .w = 0.12f, .h = 0.18f},
        };
        dst[n++] = (BarrelPadControlSpec){
            .action = kBarrelPadActionB,
            .label = "B",
            .rect = {.x = 0.68f, .y = 0.48f, .w = 0.10f, .h = 0.14f},
        };
        dst[n++] = (BarrelPadControlSpec){
            .action = kBarrelPadActionZ,
            .label = "Z",
            .rect = {.x = 0.80f, .y = 0.32f, .w = 0.10f, .h = 0.12f},
        };
        dst[n++] = (BarrelPadControlSpec){
            .action = kBarrelPadActionCUp,
            .label = "C↑",
            .rect = {.x = 0.80f, .y = 0.72f, .w = 0.06f, .h = 0.08f},
        };
        dst[n++] = (BarrelPadControlSpec){
            .action = kBarrelPadActionCDown,
            .label = "C↓",
            .rect = {.x = 0.80f, .y = 0.84f, .w = 0.06f, .h = 0.08f},
        };
        dst[n++] = (BarrelPadControlSpec){
            .action = kBarrelPadActionCLeft,
            .label = "C←",
            .rect = {.x = 0.73f, .y = 0.78f, .w = 0.06f, .h = 0.08f},
        };
        dst[n++] = (BarrelPadControlSpec){
            .action = kBarrelPadActionCRight,
            .label = "C→",
            .rect = {.x = 0.87f, .y = 0.78f, .w = 0.06f, .h = 0.08f},
        };
        dst[n++] = (BarrelPadControlSpec){
            .action = kBarrelPadActionStart,
            .label = "Start",
            .rect = {.x = 0.80f, .y = 0.18f, .w = 0.08f, .h = 0.08f},
        };
        dst[n++] = (BarrelPadControlSpec){
            .action = kBarrelPadActionMenu,
            .label = "•••",
            .rect = {.x = 0.90f, .y = 0.02f, .w = 0.07f, .h = 0.06f},
        };
        dst[0].rect = (BarrelPadLayoutRect){.x = 0.05f, .y = 0.48f, .w = 0.20f, .h = 0.38f};
    }

    int count = n < maxSpecs ? n : maxSpecs;
    memcpy(outSpecs, dst, (size_t)count * sizeof(BarrelPadControlSpec));
    return count;
}
