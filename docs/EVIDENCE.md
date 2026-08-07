# Test evidence ledger

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
