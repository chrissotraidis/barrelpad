# Target status

Last updated: 2026-08-05 (touch pad inject fix)

| Target | Build | Launch | Render | Input | Playable | Notes |
|---|---|---|---|---|---|---|
| macOS | **pass** | **pass** | **pass** | **pass** | **pass** | TT race script → levelId=5; racer moves; LAP HUD screenshot |
| iPhone Simulator | **pass** | **pass** | **pass** | **pass** | **pass** | Direct P1 `platform_ios_touch_set`; force-Start inject logs; ST label |
| iPad Simulator | **pass** | **pass** | **pass** | **pass** | **pass** | Same inject path; tablet overlay layout |

Playable = DKR game (not host launcher) reaches race/track gameplay with control response.

### Touch fix (2026-08-05)

- Root cause: on-screen buttons did not reliably drive P1 (virtual stick alone was
  not the primary pad; stick release cleared all buttons / disabled inject).
- Fix: shell publishes N64 bits via `platform_ios_touch_set`; host merges into
  the fixed-tick P1 sample every frame; stick release no longer wipes face
  buttons. Title uses **ST** (Start).
