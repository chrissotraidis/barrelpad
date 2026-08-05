#pragma once

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* DKR / N64 virtual pad actions exposed to touch and tests. */
typedef enum ChimpPadAction {
    kChimpPadActionA = 0,
    kChimpPadActionB,
    kChimpPadActionL,
    kChimpPadActionR,
    kChimpPadActionZ,
    kChimpPadActionStart,
    kChimpPadActionDUp,
    kChimpPadActionDDown,
    kChimpPadActionDLeft,
    kChimpPadActionDRight,
    kChimpPadActionCUp,
    kChimpPadActionCDown,
    kChimpPadActionCLeft,
    kChimpPadActionCRight,
    kChimpPadActionMenu,
    kChimpPadActionCount
} ChimpPadAction;

typedef enum ChimpPadLayoutKind {
    kChimpPadLayoutPhone = 0,
    kChimpPadLayoutTablet = 1
} ChimpPadLayoutKind;

/* Normalized layout rect in landscape UI coordinates: origin top-left,
 * x/y in [0,1], width/height relative to short/long edges of the safe area. */
typedef struct ChimpPadLayoutRect {
    float x;
    float y;
    float w;
    float h;
} ChimpPadLayoutRect;

typedef struct ChimpPadControlSpec {
    ChimpPadAction action;
    const char *label;
    ChimpPadLayoutRect rect;
    bool isStick; /* when true, rect is the stick well; action ignored for stick */
} ChimpPadControlSpec;

/* Stick: N64-style range approximately ±80 after host scaling; we expose
 * normalized [-1,1] and mapped int8 for tests. */
typedef struct ChimpPadStickState {
    float x; /* -1 .. 1, +right */
    float y; /* -1 .. 1, +up (N64 convention for DKR menus) */
} ChimpPadStickState;

/* Map a touch delta inside a stick well to stick state.
 * dx/dy are offsets from well center in points; radius is well radius. */
ChimpPadStickState ChimpPad_StickFromTouch(float dx, float dy, float radius);

/* Clamp and quantize stick to N64-ish ±80 int8. */
void ChimpPad_StickToN64(ChimpPadStickState s, int8_t *outX, int8_t *outY);

/* Safe-area inset application: shrinks a full window into a usable rect. */
typedef struct ChimpPadSafeArea {
    float left, top, right, bottom; /* points inset from window edges */
    float width, height;            /* full window size in points */
} ChimpPadSafeArea;

ChimpPadLayoutRect ChimpPad_SafeAreaBounds(ChimpPadSafeArea safe);

/* Default control layouts for phone vs tablet (landscape).
 * Writes up to maxSpecs entries; returns count. Stick is always index 0. */
int ChimpPad_DefaultLayout(ChimpPadLayoutKind kind,
                           ChimpPadControlSpec *outSpecs,
                           int maxSpecs);

/* Choose phone vs tablet from window size (points). */
ChimpPadLayoutKind ChimpPad_LayoutKindForSize(float width, float height);

/* Convert normalized layout rect into absolute points within safe bounds. */
ChimpPadLayoutRect ChimpPad_AbsoluteRect(ChimpPadLayoutRect bounds,
                                         ChimpPadLayoutRect normalized);

/* DKR keyboard scancode names used by Golden Balloon host (for docs/tests).
 * Returns a stable token string for logging. */
const char *ChimpPad_ActionLabel(ChimpPadAction action);

/* Golden Balloon default keyboard binding tokens (X=A accel, Z=B brake, …). */
const char *ChimpPad_HostKeyToken(ChimpPadAction action);

/* A-hold assist: after holdSeconds of continuous A, lock until tapped again.
 * Pure state machine for unit tests. */
typedef struct ChimpPadHoldAssist {
    bool enabled;
    bool locked;
    bool fingerDown;
    double downTime;
    double holdThresholdSec;
} ChimpPadHoldAssist;

void ChimpPad_HoldAssistInit(ChimpPadHoldAssist *h, double thresholdSec);
/* Returns whether A should be considered pressed after this event. */
bool ChimpPad_HoldAssistOnA(ChimpPadHoldAssist *h, bool fingerDown, double nowSec);
void ChimpPad_HoldAssistForceRelease(ChimpPadHoldAssist *h);

#ifdef __cplusplus
}
#endif
