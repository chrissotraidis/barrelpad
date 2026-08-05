# Touch controls (DKR)

Adapted from SpaghettiPad quality and behavior; mapped for **Diddy Kong Racing**.

## Design goals

- Grip-first landscape layout: stick left, face/action right
- Safe-area aware (notch, home indicator, landscape insets)
- Separate default layouts for **phone** and **tablet**
- Empty space remains the game (no full-screen opaque pad)
- Virtual N64-style pad via SDL virtual joystick when available
- Active logging of touch actions under `[ChimpPad]` during tests

## Default racing mapping

| On-screen | N64 / host | DKR role |
|---|---|---|
| Analog stick | Stick | Steer / menu |
| A | A | Accelerate / confirm |
| B | B | Brake / reverse / cancel |
| Z | Z | Item / special |
| R | R | Hop / power-slide |
| L | L | Secondary / camera (context) |
| C↑ C↓ C← C→ | C-buttons | Camera / map |
| Start | Start | Pause |
| Menu (•••) | Shell menu / settings | Always reachable |

## Phone vs tablet

- **Phone:** enlarged stick and primary A/B cluster near thumbs; C-buttons
  smaller above the action cluster; Start under menu near safe-area edge.
- **Tablet:** slightly larger hit targets; more margin from edges; A/Z sized
  for two-hand grip similar to SpaghettiPad tablet defaults but without MK64
  dual-Z item assumptions.

## Differences from SpaghettiPad (MK64)

- No Mario Kart item double-Z / item-cycle logic.
- A-hold assist (if enabled) is optional and DKR-tuned; Z and R stay
  momentary (item / hop).
- Labels and defaults reflect DKR vehicle racing (car / hovercraft / plane),
  not MK64 kart-only UX.

## Implementation locations

- Pure layout/mapping helpers: `tests/` + shared C/C++ under `ios/` / `src/`
- UIKit overlay: `ios/ChimpPadTouchControls.*` (patterned on SpaghettiPad shell)
- Emission: SDL virtual joystick axes/buttons → Golden Balloon pad read path
