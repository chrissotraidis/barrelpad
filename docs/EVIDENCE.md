# Test evidence ledger

## 2026-08-05 — DKR game boot on iPhone + iPad (skeptic fix)

### Fix
- `ChimpPadRomBoot.mm`: Documents / `MDKR_ROM` → enable `MDKR_APP_AUTOPLAY` so AppHost boots engine with touch
- `scripts/run-ios-sim.sh`: copies ROM to Documents; sets `SIMCTL_CHILD_MDKR_ROM` + `SIMCTL_CHILD_MDKR_APP_AUTOPLAY=1` (+ optional input script)

### iPhone 17 (`7D6E5F28-…`)
- Logs (`iphone-dkr-boot.log` / `iphone-sim.log`):
  - `[ChimpPad] using MDKR_ROM=…/Documents/diddy-kong-racing.v64`
  - `[app] boot: --rom … --input-script …`
  - `[ROM] … US 1.1 … Loaded 12582912 bytes`
  - `[mdkr64] entering boot path…`
  - `[webgpu] adopted host device/surface`
  - touch overlay installed; `layout kind=phone`
  - `touch action=A pressed=1` (agent clicks)
- Screenshots:
  - `iphone-before-input.png` — Rareware intro + touch overlay (not launcher)
  - `iphone-after-input.png` / `iphone-play.png` — **GAME SELECT / NEW GAME A–C** + touch overlay
  - SHA differs; mean/blue ratios change

### iPad Pro 13" M5 (`D80E9862-…`) — one sim at a time
- Logs (`ipad-dkr-boot.log` / `ipad-sim.log`):
  - same ROM boot path; `layout kind=tablet`
  - `touch action=A/B/R` from agent clicks
- Screenshots:
  - `ipad-before-input.png` → `ipad-after-input.png` / `ipad-play.png` — **DIDDY KONG RACING title / START OPTIONS** + tablet touch
  - SHA differs (not identical frames)

### macOS (prior + still valid)
- 900-frame input script → CAUTION Controller Pak screen (`macos-after-input.png`)
- Unit tests pass (`input-tests.log`)
