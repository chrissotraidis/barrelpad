# Touch controls (DKR)

Adapted from **SpaghettiPad** grip layout and behavior; mapped for
**Diddy Kong Racing** (Golden Balloon host).

## Design goals

- Grip-first landscape layout matching SpaghettiPad’s accepted phone / tablet defaults
- Safe-area aware (notch, home indicator, landscape insets)
- Glass-style semi-transparent chrome so the game stays readable
- Empty center remains the game (overlay `hitTest` passes through gaps)
- Direct P1 pad inject (`platform_ios_touch_set`), leaving SDL Player 1 free
  for a physical controller
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

The default compact centers are the accepted physical-iPhone layout captured
on an iPhone 14. They are stored as normalized coordinates so the same grip
composition adapts to other supported iPhone landscape sizes.

### Tablet / large landscape

Rail layout scaled from SpaghettiPad’s iPad defaults: larger stick, dual-Z face
cluster, C-pad lower-right, Start above right Z.

Phone and tablet customizations are persisted in separate profiles. Changing
the iPhone layout does not change the iPad default.

## Editing a layout

Open `•••` and choose **Touch Controls → Move & Resize Controls**. Select a
control, drag it to a new position, and use the slider to resize only that
control from 0.70x to 1.50x. **Done** persists the active phone/tablet profile,
closes the editor, clears any held input, and restores the gameplay touch path.

## Visibility and physical controllers

- **Show gameplay touch controls** is available directly from `•••` on both
  iPhone and iPad and persists across launches.
- The `•••` menu button remains visible even when gameplay controls are off.
- A physical SDL controller takes Player 1 and temporarily hides the gameplay
  touch overlay. Disconnecting it restores touch only when the saved preference
  is enabled.
- Touch uses direct P1 injection instead of registering a virtual SDL controller,
  so the shell cannot occupy Player 1 before real hardware connects.

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
- Primary emission is direct N64 pad injection into P1; physical controllers
  use SDL's normal Player 1 route

## Diagnostics

- Logs: `touch action=…`, `pad inject buttons=0x…`,
  `physical controller connected=… touch visible=…`
- Force inject: `MDKR_IOS_FORCE_PAD=start|a|0x1000` (+ optional DELAY/HOLD frames)

## Implementation

- UIKit overlay: `ios/BarrelPadShell.mm`
- Pure layout helpers / tests: `src/BarrelPadInput.c`
- Host merge: `platform_ios_touch_set` in goldenballoon `platform_sdl_min.c`
  (applied via `scripts/ensure-ios-touch-inject.py`)
