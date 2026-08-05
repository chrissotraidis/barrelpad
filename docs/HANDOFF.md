# Handoff / status

**Date:** 2026-08-05  
**Remote:** `origin/main`

## What works

| Target | Proof |
|---|---|
| **macOS** | DKR boots; scripted input advances to CAUTION menu |
| **iPhone Simulator** | Documents ROM + autoplay → DKR Game Select; touch overlay; A taps logged; before/after frames differ |
| **iPad Simulator** | Autoplay → DKR title (START/OPTIONS); tablet overlay; A/B/R taps logged |

## Boot (iOS)

1. Copy US 1.1 ROM to app Documents as `diddy-kong-racing.v64` (run script does this)
2. Launch with AppHost autoplay (`MDKR_APP_AUTOPLAY=1` + `MDKR_ROM`) — **not** bare CLI `--rom` alone (that was headless without touch; now also gated on iOS)
3. `ChimpPad_PrepareIosRomBoot()` auto-enables autoplay when Documents has a ROM

```sh
scripts/build-ios.sh --simulator
scripts/run-ios-sim.sh phone   # or pad
```

## What does not / next

| Item | Notes |
|---|---|
| Physical device | Out of scope |
| Portrait letterbox on some shots | App often landscape; device screenshot may be portrait |
| Next task | Optional: in-launcher “Play” when Documents ROM already validated without env |

## Reproduce old launcher-only issue

Launch without Documents ROM and without `MDKR_ROM`/`MDKR_APP_AUTOPLAY` → empty ROM picker (by design).
