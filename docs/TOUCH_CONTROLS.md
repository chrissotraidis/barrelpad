# Touch controls (DKR)

Adapted from **SpaghettiPad** grip layout and behavior; mapped for
**Diddy Kong Racing** (Golden Balloon host).

## Design goals

- Grip-first landscape layout matching SpaghettiPad’s accepted phone / tablet defaults
- Safe-area aware (notch, home indicator, landscape insets)
- Glass-style semi-transparent chrome so the game stays readable
- Empty center remains the game (overlay `hitTest` passes through gaps)
- Direct P1 pad inject (`platform_ios_touch_set`) plus virtual joystick backup
- A hold-assist during races (SpaghettiPad behavior)

## Layout (SpaghettiPad reference)

### Phone (compact, height &lt; 560 pt)

| Region | Controls |
|---|---|
| Bottom-left | Analog stick |
| Above stick | **L · Z · R** in a row (item + hop near left thumb) |
| Bottom-right face | **B**, **A** (A largest, outer corner), **Z** above A |
| Mid-right | C-pad (camera) |
| Top-right | **•••** menu, **▶** Start under it |

### Tablet / large landscape

Rail layout scaled from SpaghettiPad’s iPad defaults: larger stick, dual-Z face
cluster, C-pad lower-right, Start above right Z.

## Default racing mapping

| On-screen | N64 / host | DKR role |
|---|---|---|
| Analog stick | Stick | Steer / menus |
| A | A | Accelerate / confirm (hold-assist) |
| B | B | Brake / reverse / cancel |
| Z (left or right) | Z | Item / special |
| R | R | Hop / power-slide |
| L | L | Secondary / camera context |
| C↑ C↓ C← C→ | C-buttons | Camera / map |
| ▶ Start | Start | Pause / title “Press Start” |
| ••• | Host Escape | ImGui settings overlay |

## Feel details (from SpaghettiPad)

- Idle chrome ~38% alpha; pressed state brightens
- Minimum 50 ms press window so short taps still register
- Stick grab radius slightly larger than the drawn ring
- A hold assist: hold 0.65 s in a race → `A •` + haptic; tap again to release
- Z and R stay momentary (item / hop)

## Differences from SpaghettiPad (MK64)

- No Mario Kart dual-Z item-cycle semantics — both Z buttons fire the same DKR Z
- Host key map is Golden Balloon (X=A, Z=B, Space=R, Shift=Z), not SpaghettiKart
- Primary emission is N64 pad inject into P1, not only virtual joystick

## Diagnostics

- Logs: `touch action=…`, `pad inject buttons=0x…`
- Force inject: `MDKR_IOS_FORCE_PAD=start|a|0x1000` (+ optional DELAY/HOLD frames)

## Implementation

- UIKit overlay: `ios/ChimpPadShell.mm`
- Pure layout helpers / tests: `src/ChimpPadInput.c`
- Host merge: `platform_ios_touch_set` in goldenballoon `platform_sdl_min.c`
  (applied via `scripts/ensure-ios-touch-inject.py`)
