# Target status

Last updated: 2026-08-07

| Target | Build | Launch | Render | Input | Playable | Notes |
|---|---|---|---|---|---|---|
| macOS | **pass** | **pass** | **pass** | **pass** | **pass** | TT race script → levelId=5; racer moves; LAP HUD screenshot |
| iPhone Simulator | **pass** | **pass** | **pass** | **pass** | **pass** | SP compact grip + P1 inject; dual Z; A hold assist |
| iPad Simulator | **pass** | **pass** | **pass** | **pass** | **pass** | SP tablet rail layout + same inject path |
| iPhone 14 | **pass** | **pass** | **pass** | **pass** | **pass** | Native widescreen; accepted compact default; editable per-control size/position; full scrollable settings |
| iPad Pro 12.9-inch | **pass** | **pass** | **pass** | **pass** | **pass** | Existing tablet rail default retained; physical install and launch verified |

Playable = DKR game (not host launcher) reaches race/track gameplay with control response.

### Touch controls (2026-08-07)

- **Inject:** shell → `platform_ios_touch_set` → P1 fixed-tick merge.
- **Layout:** accepted compact iPhone default plus the existing iPad rail
  default. Layout profiles remain separate by device class.
- **Editing:** controls can be moved and resized individually; leaving the
  editor restores the live input path.
- **Settings:** iPhone touch controls and the complete scrollable settings list
  remain separately accessible in landscape.
- **iPad parity:** `•••` now exposes the same Touch Controls / All Settings
  split as iPhone, including the saved gameplay-touch toggle.
- **Controller takeover:** physical hardware owns SDL Player 1; gameplay touch
  hides while connected and restores on disconnect when enabled. `•••` remains
  available throughout. The event route and policy tests pass; a real
  connect/disconnect session remains an explicit hands-on check.
