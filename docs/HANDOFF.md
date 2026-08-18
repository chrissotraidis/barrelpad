# Handoff / status

**Date:** 2026-08-18
**Remote:** `origin/main`

## What works

| Target | State |
|---|---|
| **macOS** | Boots DKR; official TT route enters race (levelId=5); racer position/clock advance under scripted A/steer |
| **iPhone Simulator** | Documents ROM + autoplay → **in-race** with phone touch overlay; agent A taps logged; before/after race frames differ |
| **iPad Simulator** | Same route → **in-race** with tablet overlay; racer advances (checkpoints/clock); before/after differ |
| **iPhone 14** | Native widescreen, accepted compact layout, per-control move/resize, scrollable settings, ROM boot and gameplay |
| **iPad Pro 12.9-inch** | Existing tablet layout, ROM boot, saves, and gameplay |

## Reproduce race path

```sh
# macOS
./build-macos/mdkr64 --rom "ref/Diddy Kong Racing (U) (M2) (V1.1) [!].v64" \
  --input-script ref/goldenballoon/tests/input_scripts/race_drive_time_trial.txt \
  --headless-frames 4800 --dump-frames /tmp/frames

# iOS Simulator (one device at a time)
scripts/build-ios.sh --simulator
# Copy race_drive_time_trial.txt as Documents/input-script.txt, or:
BARRELPAD_INPUT_SCRIPT=ref/goldenballoon/tests/input_scripts/race_drive_time_trial.txt \
  scripts/run-ios-sim.sh phone
# Wait ~70s for levelId=5; screenshot shows LAP HUD + touch
```

## Boot notes

- iOS game boot: `MDKR_ROM` / Documents ROM + `MDKR_APP_AUTOPLAY=1` (set by `BarrelPadRomBoot` + `run-ios-sim.sh`)
- Do not use headless-only CLI if you need the touch overlay

## Release boundary

- Physical-device builds are locally signed and tested.
- `KART-01` is an accepted known issue for this release: after some closed-door
  impacts, the kart may remain oriented sideways until it enters water. Do not
  change collision or vehicle physics before release without a captured
  bad-state transition and regression test; see [ISSUES.md](ISSUES.md#kart-01--sideways-orientation-after-a-closed-door-impact).
- Preview 2 is published as a ROM-free unsigned IPA at tag
  `v0.1.0-preview.2`. It must be re-signed before standard device installation;
  its SHA-256 is
  `b2f7127113a526ce8c1fa3306f1afb4b6fb784270f3cf14c983c3cb0d8c9c7ed`.
- SDL2 controller ownership now reconciles stale handles and instance IDs at
  lifecycle/event boundaries while preserving stable player slots. Automated
  regression and iPad deployment/data-preservation proof pass, but physical
  Bluetooth, wired, natural-sleep, mapping, and two-controller acceptance are
  still open.
- iOS keeps the recommended fill-screen `Aspect=auto` default but no longer
  fixes it through the environment. The standard aspect selector is available
  in Settings; physical 4:3 selection/persistence remains a hands-on check.
