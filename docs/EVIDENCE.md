# Test evidence ledger

Raw captures under agent scratch; durable summaries here.

## Entries

### 2026-08-05 — bootstrap
- Cloned decomp @ `c669570…`, goldenballoon @ `6fc93d8…`
- Outcome: ref + docs ready

### 2026-08-05 — macOS playable + input response
- Commands: `mdkr64 --rom <US1.1 V64> --headless-frames 900 --input-script macos-long-input.txt --dump-frames …`
- Logs: `[ROM] US 1.1`, `[webgpu] device=Apple M2`, clean exit
- Frame evidence: mean luminance progresses 0 → 55 → 109 → 161 across frames; center hashes diverge; max mean pixel delta from frame 100 is ~350 at frame 875
- Screenshots: intro logos early; **CAUTION / Controller Pak** menu screen after input mash (`macos-after-input.png` / `macos-play.png`) — clear pre→post control effect past N64/Rareware attract
- Outcome: **pass** (rerun included)

### 2026-08-05 — unit tests
- `scripts/test-unit.sh` → `chimppad_input_tests: all passed`
- Outcome: **pass**

### 2026-08-05 — iPhone Simulator (final shell binary)
- Device: iPhone 17 `7D6E5F28-…`
- Binary mtime post-shell: packaged from `build-ios-sim/mdkr64.app` after `ChimpPadShell.mm` + WebGPU-path hook + interactive iOS arg triage
- Commands: install `ChimpPad.app`; `simctl launch --console` with ROM in Documents
- **Runtime logs** (`iphone-sim.log` / `iphone-console.log` / `iphone-playthrough.log`):
  - `[app] host: WebGPU (1440x960 drawable…)`
  - `[webgpu] adapter … Apple iOS simulator GPU`
  - `[ChimpPad] initialize touch controls`
  - `[ChimpPad] virtual controller attached index=1`
  - `[ChimpPad] touch overlay installed`
  - `[ChimpPad] layout kind=phone size=480x320 …`
  - Agent clicks: `[ChimpPad] touch action=A pressed=1` / `B pressed=1` (real emit path)
- **Screenshots**: `iphone-play.png` shows stick, A/B/R, L/Z, C-buttons, Start, Menu over launcher (controls clearly visible)
- Outcome: **pass**

### 2026-08-05 — iPad Simulator (final shell binary)
- Device: iPad Pro 13" M5 `D80E9862-…` (iPhone shut down first)
- Logs (`ipad-sim.log`):
  - `[app] host: WebGPU (2048x1536…)`
  - `[ChimpPad] touch overlay installed`
  - `[ChimpPad] layout kind=tablet size=1024x768 …`
- Screenshot: `ipad-play.png` shows tablet layout (stick/L/Z left, A/B/R right, C-cluster top-right)
- Outcome: **pass**

### Fixes applied for skeptic gaps
1. Touch init only on GL path → also WebGPU `initWebGpu` + SDL window create
2. `--rom` forced headless automation → iOS interactive unless `--headless-*`
3. iPhone screenshots predated shell → re-ran after final link
4. Logs were UIKit-only → capture `simctl launch --console` stderr
5. macOS input stuck on intro → 900-frame script with A/START; observed menu CAUTION screen
