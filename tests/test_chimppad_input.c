/* Unit tests for pure ChimpPad input/layout helpers — drives real shipped code. */
#include "ChimpPadInput.h"

#include <math.h>
#include <stdio.h>
#include <string.h>

static int g_failures;

#define EXPECT(cond, msg)                                                      \
    do {                                                                       \
        if (!(cond)) {                                                         \
            fprintf(stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, msg);      \
            g_failures++;                                                      \
        }                                                                      \
    } while (0)

static void test_stick_center(void) {
    ChimpPadStickState s = ChimpPad_StickFromTouch(0.f, 0.f, 100.f);
    EXPECT(fabsf(s.x) < 0.01f && fabsf(s.y) < 0.01f, "center stick is zero");
}

static void test_stick_full_right(void) {
    ChimpPadStickState s = ChimpPad_StickFromTouch(100.f, 0.f, 100.f);
    EXPECT(s.x > 0.9f, "full right");
    EXPECT(fabsf(s.y) < 0.1f, "no vertical on pure right");
    int8_t x = 0, y = 0;
    ChimpPad_StickToN64(s, &x, &y);
    EXPECT(x >= 70, "N64 x near +80");
    EXPECT(y == 0, "N64 y zero");
}

static void test_stick_up_is_positive_y(void) {
    /* UIKit dy negative when finger moves up from center. */
    ChimpPadStickState s = ChimpPad_StickFromTouch(0.f, -80.f, 100.f);
    EXPECT(s.y > 0.7f, "up touch yields +N64 y");
    int8_t x = 0, y = 0;
    ChimpPad_StickToN64(s, &x, &y);
    EXPECT(y > 50, "N64 y positive for up");
}

static void test_stick_clamp(void) {
    ChimpPadStickState s = ChimpPad_StickFromTouch(500.f, 500.f, 50.f);
    float mag = sqrtf(s.x * s.x + s.y * s.y);
    EXPECT(mag <= 1.01f, "stick magnitude clamped to unit circle");
}

static void test_layout_kind(void) {
    EXPECT(ChimpPad_LayoutKindForSize(844.f, 390.f) == kChimpPadLayoutPhone,
           "iPhone landscape is phone");
    EXPECT(ChimpPad_LayoutKindForSize(1024.f, 768.f) == kChimpPadLayoutTablet,
           "iPad is tablet");
}

static void test_default_layouts(void) {
    ChimpPadControlSpec specs[20];
    int nPhone = ChimpPad_DefaultLayout(kChimpPadLayoutPhone, specs, 20);
    EXPECT(nPhone >= 8, "phone layout has controls");
    EXPECT(specs[0].isStick, "first control is stick");

    bool hasA = false, hasB = false, hasR = false, hasZ = false, hasStart = false;
    for (int i = 0; i < nPhone; i++) {
        if (specs[i].isStick) {
            continue;
        }
        if (specs[i].action == kChimpPadActionA) {
            hasA = true;
        }
        if (specs[i].action == kChimpPadActionB) {
            hasB = true;
        }
        if (specs[i].action == kChimpPadActionR) {
            hasR = true;
        }
        if (specs[i].action == kChimpPadActionZ) {
            hasZ = true;
        }
        if (specs[i].action == kChimpPadActionStart) {
            hasStart = true;
        }
        /* All rects in unit square. */
        EXPECT(specs[i].rect.x >= 0.f && specs[i].rect.x <= 1.f, "x in range");
        EXPECT(specs[i].rect.y >= 0.f && specs[i].rect.y <= 1.f, "y in range");
    }
    EXPECT(hasA && hasB && hasR && hasZ && hasStart, "core DKR racing buttons");

    int nPad = ChimpPad_DefaultLayout(kChimpPadLayoutTablet, specs, 20);
    EXPECT(nPad >= 8, "tablet layout has controls");
    EXPECT(specs[0].isStick, "tablet stick first");
}

static void test_safe_area(void) {
    ChimpPadSafeArea safe = {
        .left = 40.f, .top = 10.f, .right = 40.f, .bottom = 20.f,
        .width = 844.f, .height = 390.f,
    };
    ChimpPadLayoutRect b = ChimpPad_SafeAreaBounds(safe);
    EXPECT(fabsf(b.x - 40.f) < 0.01f, "left inset");
    EXPECT(fabsf(b.w - (844.f - 80.f)) < 0.01f, "width after insets");
    EXPECT(fabsf(b.h - (390.f - 30.f)) < 0.01f, "height after insets");

    ChimpPadLayoutRect norm = {.x = 0.5f, .y = 0.5f, .w = 0.1f, .h = 0.1f};
    ChimpPadLayoutRect abs = ChimpPad_AbsoluteRect(b, norm);
    EXPECT(abs.x > b.x, "absolute x inside");
    EXPECT(abs.w > 1.f, "absolute width scaled");
}

static void test_host_key_tokens_dkr(void) {
    /* Golden Balloon DKR map — not Mario Kart. */
    EXPECT(strcmp(ChimpPad_HostKeyToken(kChimpPadActionA), "X") == 0,
           "A accel is X");
    EXPECT(strcmp(ChimpPad_HostKeyToken(kChimpPadActionB), "Z") == 0,
           "B brake is Z");
    EXPECT(strcmp(ChimpPad_HostKeyToken(kChimpPadActionR), "SPACE") == 0,
           "R hop is SPACE");
    EXPECT(strcmp(ChimpPad_HostKeyToken(kChimpPadActionZ), "SHIFT") == 0,
           "Z item is SHIFT");
}

static void test_hold_assist(void) {
    ChimpPadHoldAssist h;
    ChimpPad_HoldAssistInit(&h, 0.65);
    EXPECT(ChimpPad_HoldAssistOnA(&h, true, 0.0) == true, "press down");
    EXPECT(ChimpPad_HoldAssistOnA(&h, true, 0.30) == true, "still holding short");
    EXPECT(h.locked == false, "not locked yet");
    EXPECT(ChimpPad_HoldAssistOnA(&h, true, 0.70) == true, "cross threshold");
    EXPECT(h.locked == true, "locked after hold");
    EXPECT(ChimpPad_HoldAssistOnA(&h, false, 0.80) == true, "up keeps lock");
    EXPECT(ChimpPad_HoldAssistOnA(&h, true, 0.90) == false, "tap releases");
    EXPECT(h.locked == false, "unlocked");
    ChimpPad_HoldAssistForceRelease(&h);
    EXPECT(h.locked == false && h.fingerDown == false, "force release");
}

int main(void) {
    test_stick_center();
    test_stick_full_right();
    test_stick_up_is_positive_y();
    test_stick_clamp();
    test_layout_kind();
    test_default_layouts();
    test_safe_area();
    test_host_key_tokens_dkr();
    test_hold_assist();

    if (g_failures) {
        fprintf(stderr, "%d failure(s)\n", g_failures);
        return 1;
    }
    printf("chimppad_input_tests: all passed\n");
    return 0;
}
