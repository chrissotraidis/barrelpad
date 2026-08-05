# Handoff / status

**Date:** 2026-08-05  
**Remote:** `origin/main`

## What works

| Target | State |
|---|---|
| **macOS** | Boots DKR; official TT route enters race (levelId=5); racer position/clock advance under scripted A/steer |
| **iPhone Simulator** | Documents ROM + autoplay → **in-race** with phone touch overlay; agent A taps logged; before/after race frames differ |
| **iPad Simulator** | Same route → **in-race** with tablet overlay; racer advances (checkpoints/clock); before/after differ |

## Reproduce race path

```sh
# macOS
./build-macos/mdkr64 --rom "ref/Diddy Kong Racing (U) (M2) (V1.1) [!].v64" \
  --input-script ref/goldenballoon/tests/input_scripts/race_drive_time_trial.txt \
  --headless-frames 4800 --dump-frames /tmp/frames

# iOS Simulator (one device at a time)
scripts/build-ios.sh --simulator
# Copy race_drive_time_trial.txt as Documents/input-script.txt, or:
CHIMPPAD_INPUT_SCRIPT=ref/goldenballoon/tests/input_scripts/race_drive_time_trial.txt \
  scripts/run-ios-sim.sh phone
# Wait ~70s for levelId=5; screenshot shows LAP HUD + touch
```

## Boot notes

- iOS game boot: `MDKR_ROM` / Documents ROM + `MDKR_APP_AUTOPLAY=1` (set by `ChimpPadRomBoot` + `run-ios-sim.sh`)
- Do not use headless-only CLI if you need the touch overlay

## Next priority

- Optional: shorter smoke script for CI; physical-device signing still out of scope
