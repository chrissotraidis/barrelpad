# Handoff / status

**Date:** 2026-08-05  
**Repo:** `/Users/chrissotraidis/GitHub/chimppad`  
**Remote:** `origin/main` (pushed)

## What works

| Target | Evidence |
|---|---|
| **macOS** | Builds `build-macos/mdkr64`; loads US 1.1 V64; WebGPU; input script advances past intro to CAUTION/Controller Pak screen; logs `[ROM]`/`[webgpu]`/`[mdkr64]` |
| **iPhone Simulator** | Final app shows **visible DKR touch overlay** (stick, A/B/R, L/Z, C, Start, Menu); logs `touch overlay installed`, `layout kind=phone`; agent clicks produce `touch action=A/B` |
| **iPad Simulator** | Same binary; **tablet** layout visible; logs `layout kind=tablet`; WebGPU sim GPU |
| **Unit tests** | `scripts/test-unit.sh` passes for stick, layouts, DKR key map, hold assist |

## What does not / limitations

| Issue | Severity | Notes |
|---|---|---|
| Interactive iOS often opens **launcher** until ROM is chosen/Play | low | Use Documents ROM + Play, or `SIMCTL_CHILD_MDKR_ROM` / `MDKR_ROM` / config `rom_path` for auto boot |
| Simulator screenshot orientation may be portrait while app is landscape | low | Overlay still visible |
| Physical device / App Store | n/a | Out of scope |
| `sources/goldenballoon` holds iOS patches | med | Re-apply via `patches/goldenballoon-ios-full.patch` + `scripts/apply-ios-patches.sh` |

## Next highest-priority task

1. Wire Documents-folder ROM auto-discovery on first launch (skip “Choose ROM” when `Documents/*.v64` present).
2. Optional: landscape-lock polish + A-hold assist UX parity.

## Reproduce residual issues

**Launcher instead of direct race:**  
`simctl launch … com.chrissotraidis.chimppad` without Play / without `MDKR_ROM` → ROM picker with overlay still usable.

## How to resume

1. `docs/ARCHITECTURE.md`, `docs/DEPENDENCIES.md`, this file  
2. `scripts/build-macos.sh` / `scripts/build-ios.sh` / `scripts/test-unit.sh`  
3. Never commit ROM (`docs/ROM_POLICY.md`)
