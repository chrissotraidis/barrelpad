/* Unit tests for pure BarrelPad input/layout helpers — drives real shipped code. */
#include "BarrelPadInput.h"
#include "BarrelPadControllerSlots.h"

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
    BarrelPadStickState s = BarrelPad_StickFromTouch(0.f, 0.f, 100.f);
    EXPECT(fabsf(s.x) < 0.01f && fabsf(s.y) < 0.01f, "center stick is zero");
}

static void test_stick_full_right(void) {
    BarrelPadStickState s = BarrelPad_StickFromTouch(100.f, 0.f, 100.f);
    EXPECT(s.x > 0.9f, "full right");
    EXPECT(fabsf(s.y) < 0.1f, "no vertical on pure right");
    int8_t x = 0, y = 0;
    BarrelPad_StickToN64(s, &x, &y);
    EXPECT(x >= 70, "N64 x near +80");
    EXPECT(y == 0, "N64 y zero");
}

static void test_stick_up_is_positive_y(void) {
    /* UIKit dy negative when finger moves up from center. */
    BarrelPadStickState s = BarrelPad_StickFromTouch(0.f, -80.f, 100.f);
    EXPECT(s.y > 0.7f, "up touch yields +N64 y");
    int8_t x = 0, y = 0;
    BarrelPad_StickToN64(s, &x, &y);
    EXPECT(y > 50, "N64 y positive for up");
}

static void test_stick_clamp(void) {
    BarrelPadStickState s = BarrelPad_StickFromTouch(500.f, 500.f, 50.f);
    float mag = sqrtf(s.x * s.x + s.y * s.y);
    EXPECT(mag <= 1.01f, "stick magnitude clamped to unit circle");
}

static void test_layout_kind(void) {
    EXPECT(BarrelPad_LayoutKindForSize(844.f, 390.f) == kBarrelPadLayoutPhone,
           "iPhone landscape is phone");
    EXPECT(BarrelPad_LayoutKindForSize(1024.f, 768.f) == kBarrelPadLayoutTablet,
           "iPad is tablet");
}

static void test_touch_controller_takeover(void) {
    EXPECT(BarrelPad_GameplayTouchEnabled(true, false),
           "saved-on touch is visible without a controller");
    EXPECT(!BarrelPad_GameplayTouchEnabled(true, true),
           "physical controller temporarily hides gameplay touch");
    EXPECT(!BarrelPad_GameplayTouchEnabled(false, false),
           "saved-off touch stays hidden without a controller");
    EXPECT(!BarrelPad_GameplayTouchEnabled(false, true),
           "saved-off touch stays hidden with a controller");
}

static void release_fake_controller_input(
    const BarrelPadControllerSlotChanges changes,
    uint16_t buttons[BARRELPAD_CONTROLLER_SLOT_COUNT],
    int16_t axes[BARRELPAD_CONTROLLER_SLOT_COUNT]) {
    for (int slot = 0; slot < BARRELPAD_CONTROLLER_SLOT_COUNT; ++slot) {
        if ((changes.releasedMask & (1u << slot)) != 0) {
            buttons[slot] = 0;
            axes[slot] = 0;
        }
    }
}

static void test_controller_missed_removal_releases_input(void) {
    BarrelPadControllerSlots slots;
    uint16_t buttons[BARRELPAD_CONTROLLER_SLOT_COUNT] = {0x8000, 0, 0, 0};
    int16_t axes[BARRELPAD_CONTROLLER_SLOT_COUNT] = {24000, 0, 0, 0};
    const int32_t firstController[] = {101};

    BarrelPad_ControllerSlotsInit(&slots);
    BarrelPadControllerSlotChanges changes = BarrelPad_ControllerSlotsReconcile(
        &slots, firstController, 1);
    EXPECT(changes.assignedMask == 0x1, "first controller claims player 1");

    /* SDL never delivered the removal event, but current enumeration is empty. */
    changes = BarrelPad_ControllerSlotsReconcile(&slots, NULL, 0);
    release_fake_controller_input(changes, buttons, axes);
    EXPECT(changes.releasedMask == 0x1, "missed removal releases stale player 1");
    EXPECT(slots.instanceIds[0] == BARRELPAD_CONTROLLER_ID_NONE,
           "stale player 1 ownership is vacant");
    EXPECT(buttons[0] == 0 && axes[0] == 0,
           "disconnect publishes neutral buttons and axes");
}

static void test_controller_return_and_additional_slots(void) {
    BarrelPadControllerSlots slots;
    const int32_t returning[] = {202};
    const int32_t twoControllers[] = {202, 303};

    BarrelPad_ControllerSlotsInit(&slots);
    BarrelPadControllerSlotChanges changes = BarrelPad_ControllerSlotsReconcile(
        &slots, returning, 1);
    EXPECT(changes.assignedMask == 0x1 && slots.instanceIds[0] == 202,
           "sole returning controller reclaims player 1");

    changes = BarrelPad_ControllerSlotsReconcile(&slots, twoControllers, 2);
    EXPECT(changes.assignedMask == 0x2 && slots.instanceIds[0] == 202 &&
               slots.instanceIds[1] == 303,
           "additional controller claims player 2 without moving player 1");
}

static void test_controller_two_player_preservation(void) {
    BarrelPadControllerSlots slots;
    const int32_t original[] = {101, 202};
    const int32_t secondRemains[] = {202, 303};

    BarrelPad_ControllerSlotsInit(&slots);
    (void)BarrelPad_ControllerSlotsReconcile(&slots, original, 2);
    BarrelPadControllerSlotChanges changes = BarrelPad_ControllerSlotsReconcile(
        &slots, secondRemains, 2);

    EXPECT(changes.releasedMask == 0x1 && changes.assignedMask == 0x1,
           "only changed player ownership is replaced");
    EXPECT(slots.instanceIds[0] == 303 && slots.instanceIds[1] == 202,
           "unchanged player 2 keeps its slot while player 1 is reclaimed");
}

static void test_controller_foreground_reconciliation(void) {
    BarrelPadControllerSlots slots;
    uint16_t buttons[BARRELPAD_CONTROLLER_SLOT_COUNT] = {0x0040, 0, 0, 0};
    int16_t axes[BARRELPAD_CONTROLLER_SLOT_COUNT] = {-18000, 0, 0, 0};
    const int32_t beforeBackground[] = {401};
    const int32_t afterForeground[] = {402};

    BarrelPad_ControllerSlotsInit(&slots);
    (void)BarrelPad_ControllerSlotsReconcile(&slots, beforeBackground, 1);
    BarrelPadControllerSlotChanges changes = BarrelPad_ControllerSlotsReconcile(
        &slots, afterForeground, 1);
    release_fake_controller_input(changes, buttons, axes);

    EXPECT(changes.releasedMask == 0x1 && changes.assignedMask == 0x1,
           "foreground reconciliation replaces a missed stale identity");
    EXPECT(slots.instanceIds[0] == 402, "foreground controller owns player 1");
    EXPECT(buttons[0] == 0 && axes[0] == 0,
           "foreground reconciliation does not revive held input");
}

static void test_default_layouts(void) {
    BarrelPadControlSpec specs[20];
    int nPhone = BarrelPad_DefaultLayout(kBarrelPadLayoutPhone, specs, 20);
    EXPECT(nPhone >= 8, "phone layout has controls");
    EXPECT(specs[0].isStick, "first control is stick");

    bool hasA = false, hasB = false, hasR = false, hasZ = false, hasStart = false;
    for (int i = 0; i < nPhone; i++) {
        if (specs[i].isStick) {
            continue;
        }
        if (specs[i].action == kBarrelPadActionA) {
            hasA = true;
        }
        if (specs[i].action == kBarrelPadActionB) {
            hasB = true;
        }
        if (specs[i].action == kBarrelPadActionR) {
            hasR = true;
        }
        if (specs[i].action == kBarrelPadActionZ) {
            hasZ = true;
        }
        if (specs[i].action == kBarrelPadActionStart) {
            hasStart = true;
        }
        /* All rects in unit square. */
        EXPECT(specs[i].rect.x >= 0.f && specs[i].rect.x <= 1.f, "x in range");
        EXPECT(specs[i].rect.y >= 0.f && specs[i].rect.y <= 1.f, "y in range");
    }
    EXPECT(hasA && hasB && hasR && hasZ && hasStart, "core DKR racing buttons");

    int nPad = BarrelPad_DefaultLayout(kBarrelPadLayoutTablet, specs, 20);
    EXPECT(nPad >= 8, "tablet layout has controls");
    EXPECT(specs[0].isStick, "tablet stick first");
}

static void test_safe_area(void) {
    BarrelPadSafeArea safe = {
        .left = 40.f, .top = 10.f, .right = 40.f, .bottom = 20.f,
        .width = 844.f, .height = 390.f,
    };
    BarrelPadLayoutRect b = BarrelPad_SafeAreaBounds(safe);
    EXPECT(fabsf(b.x - 40.f) < 0.01f, "left inset");
    EXPECT(fabsf(b.w - (844.f - 80.f)) < 0.01f, "width after insets");
    EXPECT(fabsf(b.h - (390.f - 30.f)) < 0.01f, "height after insets");

    BarrelPadLayoutRect norm = {.x = 0.5f, .y = 0.5f, .w = 0.1f, .h = 0.1f};
    BarrelPadLayoutRect abs = BarrelPad_AbsoluteRect(b, norm);
    EXPECT(abs.x > b.x, "absolute x inside");
    EXPECT(abs.w > 1.f, "absolute width scaled");
}

static void test_host_key_tokens_dkr(void) {
    /* Golden Balloon DKR map — not Mario Kart. */
    EXPECT(strcmp(BarrelPad_HostKeyToken(kBarrelPadActionA), "X") == 0,
           "A accel is X");
    EXPECT(strcmp(BarrelPad_HostKeyToken(kBarrelPadActionB), "Z") == 0,
           "B brake is Z");
    EXPECT(strcmp(BarrelPad_HostKeyToken(kBarrelPadActionR), "SPACE") == 0,
           "R hop is SPACE");
    EXPECT(strcmp(BarrelPad_HostKeyToken(kBarrelPadActionZ), "SHIFT") == 0,
           "Z item is SHIFT");
}

static void test_hold_assist(void) {
    BarrelPadHoldAssist h;
    BarrelPad_HoldAssistInit(&h, 0.65);
    EXPECT(BarrelPad_HoldAssistOnA(&h, true, 0.0) == true, "press down");
    EXPECT(BarrelPad_HoldAssistOnA(&h, true, 0.30) == true, "still holding short");
    EXPECT(h.locked == false, "not locked yet");
    EXPECT(BarrelPad_HoldAssistOnA(&h, true, 0.70) == true, "cross threshold");
    EXPECT(h.locked == true, "locked after hold");
    EXPECT(BarrelPad_HoldAssistOnA(&h, false, 0.80) == true, "up keeps lock");
    EXPECT(BarrelPad_HoldAssistOnA(&h, true, 0.90) == false, "tap releases");
    EXPECT(h.locked == false, "unlocked");
    BarrelPad_HoldAssistForceRelease(&h);
    EXPECT(h.locked == false && h.fingerDown == false, "force release");
}

int main(void) {
    test_stick_center();
    test_stick_full_right();
    test_stick_up_is_positive_y();
    test_stick_clamp();
    test_layout_kind();
    test_touch_controller_takeover();
    test_controller_missed_removal_releases_input();
    test_controller_return_and_additional_slots();
    test_controller_two_player_preservation();
    test_controller_foreground_reconciliation();
    test_default_layouts();
    test_safe_area();
    test_host_key_tokens_dkr();
    test_hold_assist();

    if (g_failures) {
        fprintf(stderr, "%d failure(s)\n", g_failures);
        return 1;
    }
    printf("barrelpad_input_tests: all passed\n");
    return 0;
}
