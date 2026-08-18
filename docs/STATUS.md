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

## Preview 2 release candidate

- Version `0.1.0` (build `2`), planned tag `v0.1.0-preview.2`.
- Local candidate: unsigned, re-signable arm64 IPA for iPhone and iPad running
  iOS/iPadOS 15 or later. No Preview 2 tag or GitHub release exists yet.
- Candidate IPA SHA-256: `b2f7127113a526ce8c1fa3306f1afb4b6fb784270f3cf14c983c3cb0d8c9c7ed`.
- Package audit rejects ROMs, saves, signing material, non-system runtime
  dependencies, code signatures, local build rpaths, and personal build paths.
- The IPA includes an accurate `NSUserDefaults` privacy declaration, rights,
  and third-party notices but no game data. It is not an App Store or TestFlight
  build and must be re-signed before standard device installation.

### SDL2 controller lifecycle (2026-08-18)

- Golden Balloon owns four `SDL_GameController` handles directly as player
  slots; BarrelPad does not bypass that input layer with Apple GameController.
- Current SDL enumeration, joystick instance IDs, and
  `SDL_GameControllerGetAttached()` now preserve valid owners, release stale
  handles and latched input, and assign new devices to the lowest free slot.
- Startup, add/remove/remap events, foreground resume, and a bounded active
  check reconcile ownership without restarting SDL or changing mappings.
- Deterministic missed-removal, held-input, Player 1 reclaim, additional-player,
  two-player preservation, and foreground tests pass.
- Physical iPad build/install/boot and data preservation pass. No physical
  controller was connected, so Bluetooth, wired, natural-sleep, full mapping,
  and two-controller acceptance remain hands-on gates.

### Aspect ratio settings (2026-08-18)

- The recommended fill-screen `Auto` behavior remains the default on iPhone and
  iPad, but it is no longer session-locked by `MDKR_ASPECT`.
- Settings offers Auto (Fill Screen), 4:3 (Original), 16:10, 16:9, and 21:9;
  the selection uses the existing live, persisted video-configuration path.
- Automated configuration/UI checks and the iPhoneOS build pass. Physical
  pillarboxing and relaunch persistence remain a hands-on acceptance check.

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
