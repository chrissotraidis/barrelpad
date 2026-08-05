# Test evidence ledger

Raw agent captures live under the session scratch directory; durable summaries here.

## Entries

### 2026-08-05 — bootstrap
- Cloned `davidsm64/diddy-kong-racing` @ `c66957033046b1d66e72fcb096bf90fb49bcedba`
- Cloned `akratch/goldenballoon` @ `6fc93d886b090b22eb39d90fada535faa7282f2d`
- Created `docs/`, `.gitignore`
- Outcome: ref + docs ready

### 2026-08-05 — macOS playable
- Commands: `cmake -S ref/goldenballoon -B build-macos -G Ninja` + `cmake --build … --target mdkr64`
- Run: `mdkr64 --rom <ref V64> --headless-frames 300 --input-script … --dump-frames`
- Logs: `[ROM] … US 1.1`, `[webgpu] adapter backend=5 device=Apple M2`, clean exit
- Screenshots: N64 intro / logo frames non-blank (scratch `macos-play.png`)
- Outcome: **pass** (rerun also pass)

### 2026-08-05 — unit tests
- Commands: `scripts/test-unit.sh`
- Outcome: **pass** (`chimppad_input_tests: all passed`)

### 2026-08-05 — iPhone Simulator
- Device: iPhone 17 (`7D6E5F28-…`)
- Commands: install `build-ios-sim/ChimpPad.app`, copy ROM to Documents, `simctl launch … --rom …`
- Logs: WebGPU sim GPU; after `SDL_UIKitRunApp` fix, app presents intro (Rareware logo)
- Screenshot: `iphone-play.png` (non-blank, logo present)
- Outcome: **pass** (playable launch/render)

### 2026-08-05 — iPad Simulator
- Device: iPad Pro 13-inch M5 (`D80E9862-…`)
- One Simulator at a time (iPhone shut down first)
- Screenshot: `ipad-play.png` non-blank game surface (intro)
- Outcome: **pass**

### 2026-08-05 — touch shell link
- `ChimpPadShell.mm` + `ChimpPadInput.c` linked into iOS `mdkr64_app`; init on window create
- Outcome: build pass; overlay present at runtime (translucent; may be hard to see on dark intro frames)
