# Test evidence ledger

## 2026-08-18 — SDL2 controller sleep/reconnect repair and Preview 2

- Backend: Golden Balloon's SDL2 `SDL_GameController` layer owns four stored
  handles as Player 1–4. The pre-fix code opened on startup/add and closed only
  on remove events; it did not validate attachment, enumerate current instance
  IDs on resume, or clear a missed stale owner.
- Repair: valid instance owners retain their slots; stale handles are closed and
  their buttons/axes neutralized; new identities take the lowest free slot.
  Reconciliation runs at startup, controller add/remove/remap, foreground, and
  a bounded active check. Gameplay reads only attached handles, and SDL is not
  restarted.
- Deterministic coverage passes for missed removal with held input, neutral
  state after release, sole-controller Player 1 reclaim, an additional Player 2,
  preservation of an unchanged second controller, and foreground reconciliation.
- iOS still defaults to the recommended fill-screen `Aspect=auto`, now from the
  normal video configuration rather than an environment lock. Settings exposes
  Auto (Fill Screen), 4:3 (Original), 16:10, 16:9, and 21:9. Configuration,
  persistence, launcher UI, clean patch replay, macOS, and iPhoneOS build checks
  pass; physically selecting and relaunching a framed ratio remains open.
- The ROM-free iPad Simulator and arm64 iPhoneOS Release products compiled. All
  101 practical host tests passed in the final full run. Repo safety, clean
  patch replay, diff checks, and focused tests pass.
- Signed build `0.1.0` (`2`) passed strict code-sign verification and installed
  in place as `com.chrissotraidis.barrelpad` on the 12.9-inch iPad Pro. The live
  process reached Apple M2 WebGPU initialization, verified and loaded the
  supported local ROM, entered the game boot path, and logged startup plus
  foreground controller reconciliation.
- `Documents` and `Library` were backed up separately before installation.
  Readback proved the ROM, current EEPROM, three autosaves, app config, and
  customized tablet layout byte-identical. No user mapping file was present;
  the repair does not alter Golden Balloon mapping/preferences storage.
- No physical controller was connected during this deployment. Bluetooth,
  wired, natural sleep/wake, held-input release on real hardware, full mapping,
  touch restoration, and two-controller slot preservation remain explicit
  hands-on gates.
- `BarrelPad-0.1.0-preview.2-unsigned.ipa` is a deterministic, unsigned,
  ROM-free arm64 package. Two builds were byte-identical; SHA-256 is
  `b2f7127113a526ce8c1fa3306f1afb4b6fb784270f3cf14c983c3cb0d8c9c7ed`.
  The audit passed ZIP, platform/minimum OS, version/build, dependency, rights,
  privacy-manifest, signature-removal, and private-content checks.

## 2026-08-07 — Unified touch settings and controller takeover

- iPhone and iPad now share the same direct `•••` navigation: **Touch Controls**
  and **All Settings** are first-level actions, and the touch page contains the
  saved visibility toggle, 1x–4x sizing, and layout editor entry.
- Gameplay touch visibility is persisted as `touch_controls_enabled`. The
  permanent `•••` target remains available while gameplay controls are off.
- The shell no longer registers a virtual SDL controller. Physical hardware can
  therefore claim Player 1; controller connect/disconnect events temporarily
  hide and restore gameplay touch without overwriting the saved preference.
- Pure policy tests cover saved on/off combined with controller connected/
  disconnected. The clean patch chain reproduced byte-identical overlay,
  SDL-controller, shell, and input-helper sources, and the arm64 device target
  compiled and linked them.
- The signed update installed and launched in place on the iPhone 14 and iPad
  Pro 12.9-inch. Both live `BarrelPad.app/BarrelPad` processes booted the local
  ROM with widescreen enabled. Pre/post ROM and EEPROM SHA-256 values matched,
  and each full save directory compared without differences.
- No physical controller was connected during this deployment. Real hardware
  Player 1 takeover and disconnect restoration remain a hands-on acceptance
  check; the implementation and event route are present, but not mislabeled as
  physically exercised.

## 2026-08-07 — BarrelPad physical-device acceptance

- Product/bundle: `BarrelPad.app`, executable `BarrelPad`, bundle identifier
  `com.chrissotraidis.barrelpad`.
- iPhone 14: signed install and launch pass; Apple A15 WebGPU adapter; native
  `2532×1170` drawable; touch overlay and direct P1 input initialized;
  US 1.1 ROM verified and game boot entered.
- iPad Pro 12.9-inch: signed install and launch pass; Apple M2 WebGPU adapter;
  native `2732×2048` drawable; existing tablet layout retained; ROM verified
  and game boot entered.
- Migration: each device's existing ROM and EEPROM/autosaves were backed up,
  copied into its new bundle container, and read back. Source/destination
  SHA-256 values matched, and each save directory compared without differences.
- iPhone default: the accepted physical-phone control centers are compiled as
  the compact fallback. Tablet defaults remain on the separate tablet path.
- Input editor: individual selection, movement, and 0.70x–1.50x sizing compile
  into the device product; leaving the editor resets stale held input and
  restores the touch source.

## 2026-08-05 — In-race basic gameplay (all targets)

Official route: `ref/goldenballoon/tests/input_scripts/race_drive_time_trial.txt`
(TITLE → character → caution → game select → track select → **levelId=5 race** → drive).

### macOS
- Command: `mdkr64 --rom <US1.1> --headless-frames 4800 --input-script race_drive_time_trial.txt --dump-frames …` with `MDKR_TRACE=1`
- Log: `level_load: levelId=5 numPlayers=0` @ ~frame 2621; `[PACE]` racer moves
  - early race: `x=-1682 z=-6413 clock=0`
  - mid drive: `x≈-788 z≈-11038 clock=2278` (position + clock advance)
- Screenshots: `macos-before-race.png` (menu) → `macos-in-race.png` / `macos-play.png` (**LAP 1/3**, timer, track, racer) — SHA differ

### iPhone Simulator (`7D6E5F28-…`)
- Autoplay + same input script; race loaded @ ~71s wall
- Log: `levelId=5 numPlayers=0` @ frame ~2607; `touch action=A` during race
- Screenshots: `iphone-race-before.png` → `iphone-race-after.png` / `iphone-play.png`
  - After: **in-race** (WRONG WAY / LAP 1/3 / timer / mini-map / Diddy kart) **+ full touch overlay**
  - SHA `bf1839bf0e36` → `123c5490770c` (**DIFFERENT**)

### iPad Simulator (`D80E9862-…`, alone)
- Same autoplay route; race loaded @ ~70s
- Log: `levelId=5 numPlayers=0`; racer advances to `cp=3 clock≈10380 z≈-11479`
- Screenshots: `ipad-race-before.png` → `ipad-race-after.png` / `ipad-play.png`
  - After: **in-race** Ancient Lake–style track, LAP 1/3, TIME, bananas, tablet touch layout
  - SHA `4cada55a372d` → `903c3989692b` (**DIFFERENT**)

### Unit tests
- `scripts/test-unit.sh` — pass

## Prior notes (still valid)
- Documents ROM + `MDKR_APP_AUTOPLAY` required for interactive iOS game boot with touch
- Bare CLI `--rom` is headless path; iOS uses autoplay so overlay stays
