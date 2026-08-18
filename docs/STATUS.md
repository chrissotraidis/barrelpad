# Target status

Last updated: 2026-08-18

| Target | Build | Launch | Render | Input | Playable | Notes |
|---|---|---|---|---|---|---|
| macOS | **pass** | **pass** | **pass** | **pass** | **pass** | TT race script → levelId=5; racer moves; LAP HUD screenshot |
| iPhone Simulator | **pass** | **pass** | **pass** | **pass** | **pass** | SP compact grip + P1 inject; dual Z; A hold assist |
| iPad Simulator | **pass** | **pass** | **pass** | **pass** | **pass** | SP tablet rail layout + same inject path |
| iPhone 14 | **pass** | **pass** | **pass** | **pass** | **pass** | Native widescreen; accepted compact default; editable per-control size/position; full scrollable settings |
| iPad Pro 12.9-inch | **pass** | **pass** | **pass** | **pass** | **pass** | Existing tablet rail default retained; physical install and launch verified |

Playable = DKR game (not host launcher) reaches race/track gameplay with control response.

## Preview 1 release

- Version `0.1.0` (build `1`), tag `v0.1.0-preview.1`.
- Public artifact: unsigned, re-signable arm64 IPA for iPhone and iPad running
  iOS/iPadOS 15 or later.
- IPA SHA-256: `e94bb65710ded282e67e40e3394190d415adf8a3170495039c69cd58fe4a8a24`.
- Package audit rejects ROMs, saves, signing material, non-system runtime
  dependencies, code signatures, local build rpaths, and personal build paths.
- The IPA includes rights and third-party notices but no game data; users must
  provide their own legally acquired supported ROM after installation.

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
