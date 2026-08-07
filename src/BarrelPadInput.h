#pragma once

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* DKR / N64 virtual pad actions exposed to touch and tests. */
typedef enum BarrelPadAction {
    kBarrelPadActionA = 0,
    kBarrelPadActionB,
    kBarrelPadActionL,
    kBarrelPadActionR,
    kBarrelPadActionZ,
    kBarrelPadActionStart,
    kBarrelPadActionDUp,
    kBarrelPadActionDDown,
    kBarrelPadActionDLeft,
    kBarrelPadActionDRight,
    kBarrelPadActionCUp,
    kBarrelPadActionCDown,
    kBarrelPadActionCLeft,
    kBarrelPadActionCRight,
    kBarrelPadActionMenu,
    kBarrelPadActionCount
} BarrelPadAction;

typedef enum BarrelPadLayoutKind {
    kBarrelPadLayoutPhone = 0,
    kBarrelPadLayoutTablet = 1
} BarrelPadLayoutKind;

/* Normalized layout rect in landscape UI coordinates: origin top-left,
 * x/y in [0,1], width/height relative to short/long edges of the safe area. */
typedef struct BarrelPadLayoutRect {
    float x;
    float y;
    float w;
    float h;
} BarrelPadLayoutRect;

typedef struct BarrelPadControlSpec {
    BarrelPadAction action;
    const char *label;
    BarrelPadLayoutRect rect;
    bool isStick; /* when true, rect is the stick well; action ignored for stick */
} BarrelPadControlSpec;

/* Stick: N64-style range approximately ±80 after host scaling; we expose
 * normalized [-1,1] and mapped int8 for tests. */
typedef struct BarrelPadStickState {
    float x; /* -1 .. 1, +right */
    float y; /* -1 .. 1, +up (N64 convention for DKR menus) */
} BarrelPadStickState;

/* Map a touch delta inside a stick well to stick state.
 * dx/dy are offsets from well center in points; radius is well radius. */
BarrelPadStickState BarrelPad_StickFromTouch(float dx, float dy, float radius);

/* Clamp and quantize stick to N64-ish ±80 int8. */
void BarrelPad_StickToN64(BarrelPadStickState s, int8_t *outX, int8_t *outY);

/* Safe-area inset application: shrinks a full window into a usable rect. */
typedef struct BarrelPadSafeArea {
    float left, top, right, bottom; /* points inset from window edges */
    float width, height;            /* full window size in points */
} BarrelPadSafeArea;

BarrelPadLayoutRect BarrelPad_SafeAreaBounds(BarrelPadSafeArea safe);

/* Default control layouts for phone vs tablet (landscape).
 * Writes up to maxSpecs entries; returns count. Stick is always index 0. */
int BarrelPad_DefaultLayout(BarrelPadLayoutKind kind,
                           BarrelPadControlSpec *outSpecs,
                           int maxSpecs);

/* Choose phone vs tablet from window size (points). */
BarrelPadLayoutKind BarrelPad_LayoutKindForSize(float width, float height);

/* Convert normalized layout rect into absolute points within safe bounds. */
BarrelPadLayoutRect BarrelPad_AbsoluteRect(BarrelPadLayoutRect bounds,
                                         BarrelPadLayoutRect normalized);

/* DKR keyboard scancode names used by Golden Balloon host (for docs/tests).
 * Returns a stable token string for logging. */
const char *BarrelPad_ActionLabel(BarrelPadAction action);

/* Golden Balloon default keyboard binding tokens (X=A accel, Z=B brake, …). */
const char *BarrelPad_HostKeyToken(BarrelPadAction action);

/* A-hold assist: after holdSeconds of continuous A, lock until tapped again.
 * Pure state machine for unit tests. */
typedef struct BarrelPadHoldAssist {
    bool enabled;
    bool locked;
    bool fingerDown;
    double downTime;
    double holdThresholdSec;
} BarrelPadHoldAssist;

void BarrelPad_HoldAssistInit(BarrelPadHoldAssist *h, double thresholdSec);
/* Returns whether A should be considered pressed after this event. */
bool BarrelPad_HoldAssistOnA(BarrelPadHoldAssist *h, bool fingerDown, double nowSec);
void BarrelPad_HoldAssistForceRelease(BarrelPadHoldAssist *h);

#ifdef __cplusplus
}
#endif
