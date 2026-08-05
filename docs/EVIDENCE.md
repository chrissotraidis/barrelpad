# Test evidence ledger

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
