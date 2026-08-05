#include "ChimpPadInput.h"

#include <math.h>
#include <string.h>

#ifndef CHIMPPAD_PI
#define CHIMPPAD_PI 3.14159265358979323846f
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

ChimpPadStickState ChimpPad_StickFromTouch(float dx, float dy, float radius) {
    ChimpPadStickState s = {0.f, 0.f};
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

void ChimpPad_StickToN64(ChimpPadStickState s, int8_t *outX, int8_t *outY) {
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

ChimpPadLayoutRect ChimpPad_SafeAreaBounds(ChimpPadSafeArea safe) {
    ChimpPadLayoutRect r;
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

ChimpPadLayoutKind ChimpPad_LayoutKindForSize(float width, float height) {
    float shortSide = width < height ? width : height;
    /* iPad mini short side ~744 pt; phones ≤ 500 pt short side landscape height. */
    if (shortSide >= 600.f) {
        return kChimpPadLayoutTablet;
    }
    return kChimpPadLayoutPhone;
}

ChimpPadLayoutRect ChimpPad_AbsoluteRect(ChimpPadLayoutRect bounds,
                                         ChimpPadLayoutRect normalized) {
    ChimpPadLayoutRect r;
    r.x = bounds.x + normalized.x * bounds.w;
    r.y = bounds.y + normalized.y * bounds.h;
    r.w = normalized.w * bounds.w;
    r.h = normalized.h * bounds.h;
    return r;
}

const char *ChimpPad_ActionLabel(ChimpPadAction action) {
    switch (action) {
        case kChimpPadActionA:
            return "A";
        case kChimpPadActionB:
            return "B";
        case kChimpPadActionL:
            return "L";
        case kChimpPadActionR:
            return "R";
        case kChimpPadActionZ:
            return "Z";
        case kChimpPadActionStart:
            return "Start";
        case kChimpPadActionDUp:
            return "D-Up";
        case kChimpPadActionDDown:
            return "D-Down";
        case kChimpPadActionDLeft:
            return "D-Left";
        case kChimpPadActionDRight:
            return "D-Right";
        case kChimpPadActionCUp:
            return "C-Up";
        case kChimpPadActionCDown:
            return "C-Down";
        case kChimpPadActionCLeft:
            return "C-Left";
        case kChimpPadActionCRight:
            return "C-Right";
        case kChimpPadActionMenu:
            return "Menu";
        default:
            return "?";
    }
}

const char *ChimpPad_HostKeyToken(ChimpPadAction action) {
    /* Matches Golden Balloon platform_sdl_min.c keyboard map. */
    switch (action) {
        case kChimpPadActionA:
            return "X"; /* accelerate */
        case kChimpPadActionB:
            return "Z"; /* brake */
        case kChimpPadActionL:
            return "Q";
        case kChimpPadActionR:
            return "SPACE"; /* hop / slide */
        case kChimpPadActionZ:
            return "SHIFT"; /* item */
        case kChimpPadActionStart:
            return "RETURN";
        case kChimpPadActionCUp:
            return "I";
        case kChimpPadActionCDown:
            return "K";
        case kChimpPadActionCLeft:
            return "J";
        case kChimpPadActionCRight:
            return "L";
        case kChimpPadActionDUp:
            return "UP";
        case kChimpPadActionDDown:
            return "DOWN";
        case kChimpPadActionDLeft:
            return "LEFT";
        case kChimpPadActionDRight:
            return "RIGHT";
        case kChimpPadActionMenu:
            return "ESCAPE";
        default:
            return "";
    }
}

void ChimpPad_HoldAssistInit(ChimpPadHoldAssist *h, double thresholdSec) {
    if (!h) {
        return;
    }
    memset(h, 0, sizeof(*h));
    h->enabled = true;
    h->holdThresholdSec = thresholdSec > 0.05 ? thresholdSec : 0.65;
}

bool ChimpPad_HoldAssistOnA(ChimpPadHoldAssist *h, bool fingerDown, double nowSec) {
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

void ChimpPad_HoldAssistForceRelease(ChimpPadHoldAssist *h) {
    if (!h) {
        return;
    }
    h->locked = false;
    h->fingerDown = false;
    h->downTime = 0.0;
}

int ChimpPad_DefaultLayout(ChimpPadLayoutKind kind,
                           ChimpPadControlSpec *outSpecs,
                           int maxSpecs) {
    if (!outSpecs || maxSpecs <= 0) {
        return 0;
    }

    /* SpaghettiPad-style grip: stick + L/Z/R left; face A/B/Z + C right. */
    enum { kMax = 16 };
    ChimpPadControlSpec phone[kMax];
    ChimpPadControlSpec tablet[kMax];
    int n = 0;
    ChimpPadControlSpec *dst = (kind == kChimpPadLayoutTablet) ? tablet : phone;

    dst[n++] = (ChimpPadControlSpec){
        .action = kChimpPadActionA,
        .label = "Stick",
        .rect = {.x = 0.04f, .y = 0.52f, .w = 0.24f, .h = 0.40f},
        .isStick = true,
    };
    /* L / Z / R row above the stick (left thumb). */
    dst[n++] = (ChimpPadControlSpec){
        .action = kChimpPadActionL,
        .label = "L",
        .rect = {.x = 0.02f, .y = 0.36f, .w = 0.09f, .h = 0.12f},
    };
    dst[n++] = (ChimpPadControlSpec){
        .action = kChimpPadActionZ,
        .label = "Z",
        .rect = {.x = 0.12f, .y = 0.36f, .w = 0.09f, .h = 0.12f},
    };
    dst[n++] = (ChimpPadControlSpec){
        .action = kChimpPadActionR,
        .label = "R",
        .rect = {.x = 0.22f, .y = 0.36f, .w = 0.09f, .h = 0.12f},
    };

    if (kind == kChimpPadLayoutPhone) {
        dst[n++] = (ChimpPadControlSpec){
            .action = kChimpPadActionA,
            .label = "A",
            .rect = {.x = 0.78f, .y = 0.62f, .w = 0.14f, .h = 0.20f},
        };
        dst[n++] = (ChimpPadControlSpec){
            .action = kChimpPadActionB,
            .label = "B",
            .rect = {.x = 0.62f, .y = 0.58f, .w = 0.12f, .h = 0.16f},
        };
        dst[n++] = (ChimpPadControlSpec){
            .action = kChimpPadActionZ,
            .label = "Z",
            .rect = {.x = 0.76f, .y = 0.40f, .w = 0.12f, .h = 0.14f},
        };
        dst[n++] = (ChimpPadControlSpec){
            .action = kChimpPadActionCUp,
            .label = "C↑",
            .rect = {.x = 0.78f, .y = 0.18f, .w = 0.07f, .h = 0.09f},
        };
        dst[n++] = (ChimpPadControlSpec){
            .action = kChimpPadActionCDown,
            .label = "C↓",
            .rect = {.x = 0.78f, .y = 0.32f, .w = 0.07f, .h = 0.09f},
        };
        dst[n++] = (ChimpPadControlSpec){
            .action = kChimpPadActionCLeft,
            .label = "C←",
            .rect = {.x = 0.70f, .y = 0.25f, .w = 0.07f, .h = 0.09f},
        };
        dst[n++] = (ChimpPadControlSpec){
            .action = kChimpPadActionCRight,
            .label = "C→",
            .rect = {.x = 0.86f, .y = 0.25f, .w = 0.07f, .h = 0.09f},
        };
        dst[n++] = (ChimpPadControlSpec){
            .action = kChimpPadActionStart,
            .label = "Start",
            .rect = {.x = 0.88f, .y = 0.08f, .w = 0.08f, .h = 0.09f},
        };
        dst[n++] = (ChimpPadControlSpec){
            .action = kChimpPadActionMenu,
            .label = "•••",
            .rect = {.x = 0.88f, .y = 0.00f, .w = 0.08f, .h = 0.07f},
        };
    } else {
        dst[n++] = (ChimpPadControlSpec){
            .action = kChimpPadActionA,
            .label = "A",
            .rect = {.x = 0.80f, .y = 0.52f, .w = 0.12f, .h = 0.18f},
        };
        dst[n++] = (ChimpPadControlSpec){
            .action = kChimpPadActionB,
            .label = "B",
            .rect = {.x = 0.68f, .y = 0.48f, .w = 0.10f, .h = 0.14f},
        };
        dst[n++] = (ChimpPadControlSpec){
            .action = kChimpPadActionZ,
            .label = "Z",
            .rect = {.x = 0.80f, .y = 0.32f, .w = 0.10f, .h = 0.12f},
        };
        dst[n++] = (ChimpPadControlSpec){
            .action = kChimpPadActionCUp,
            .label = "C↑",
            .rect = {.x = 0.80f, .y = 0.72f, .w = 0.06f, .h = 0.08f},
        };
        dst[n++] = (ChimpPadControlSpec){
            .action = kChimpPadActionCDown,
            .label = "C↓",
            .rect = {.x = 0.80f, .y = 0.84f, .w = 0.06f, .h = 0.08f},
        };
        dst[n++] = (ChimpPadControlSpec){
            .action = kChimpPadActionCLeft,
            .label = "C←",
            .rect = {.x = 0.73f, .y = 0.78f, .w = 0.06f, .h = 0.08f},
        };
        dst[n++] = (ChimpPadControlSpec){
            .action = kChimpPadActionCRight,
            .label = "C→",
            .rect = {.x = 0.87f, .y = 0.78f, .w = 0.06f, .h = 0.08f},
        };
        dst[n++] = (ChimpPadControlSpec){
            .action = kChimpPadActionStart,
            .label = "Start",
            .rect = {.x = 0.80f, .y = 0.18f, .w = 0.08f, .h = 0.08f},
        };
        dst[n++] = (ChimpPadControlSpec){
            .action = kChimpPadActionMenu,
            .label = "•••",
            .rect = {.x = 0.90f, .y = 0.02f, .w = 0.07f, .h = 0.06f},
        };
        dst[0].rect = (ChimpPadLayoutRect){.x = 0.05f, .y = 0.48f, .w = 0.20f, .h = 0.38f};
    }

    int count = n < maxSpecs ? n : maxSpecs;
    memcpy(outSpecs, dst, (size_t)count * sizeof(ChimpPadControlSpec));
    return count;
}
