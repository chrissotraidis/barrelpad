# Target status

Last updated: 2026-08-05 (SpaghettiPad grip layout)

| Target | Build | Launch | Render | Input | Playable | Notes |
|---|---|---|---|---|---|---|
| macOS | **pass** | **pass** | **pass** | **pass** | **pass** | TT race script → levelId=5; racer moves; LAP HUD screenshot |
| iPhone Simulator | **pass** | **pass** | **pass** | **pass** | **pass** | SP compact grip + P1 inject; dual Z; A hold assist |
| iPad Simulator | **pass** | **pass** | **pass** | **pass** | **pass** | SP tablet rail layout + same inject path |

Playable = DKR game (not host launcher) reaches race/track gameplay with control response.

### Touch controls (2026-08-05)

- **Inject:** shell → `platform_ios_touch_set` → P1 fixed-tick merge.
- **Layout:** SpaghettiPad phone compact + tablet rail (L/Z/R above stick,
  dual Z, face A/B, C-pad, Start under menu). Glass alpha + 50 ms min press.
- Evidence: `docs/evidence/touch-controls-phone.png`
