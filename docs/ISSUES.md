# Known issues, limitations, failed approaches

## Open issues

| ID | Severity | Summary | Reproduce | Status |
|---|---|---|---|---|
| ORIENT-01 | low | Simulator often launches portrait; game letterboxed | Launch iOS app without landscape lock | Open — force landscape UI orientations + SDL hint next |
| SAVE-01 | low | Simulator may log read-only save create failures | Launch on sim; inspect mdkr64.log | Non-blocking |
| TOUCH-01 | low | Touch overlay may be hard to see on dark intro frames | Screenshot at intro | Overlay linked; verify mid-menu next |
| PATCH-01 | med | iOS patches live in `sources/goldenballoon` disposable tree | Fresh clone | Need `scripts/apply-ios-patches.sh` packaging |

## Failed / rejected approaches

| Approach | Why rejected / fixed |
|---|---|
| Decomp Makefile as Apple runtime | Matching decomp rebuilds MIPS ROM; not a host |
| Emulator-only host | Unnecessary once open Golden Balloon exists |
| Desktop OpenGL backend on iOS | Desktop GL APIs missing on GLES; WebGPU-only on iOS |
| `SDL_SetMainReady` alone on iOS | Still failed SDL_Init; fixed with `SDL_UIKitRunApp` |
| Homebrew `sdl2-compat` as sole iOS SDL | Built static SDL 2.32.10 for Simulator instead |
| Blind SpaghettiPad MK64 item/Z logic | DKR mappings used instead |

## Limitations (non-blocking)

- Physical device signing / TestFlight / App Store: out of scope
- HD textures, tilt, full multiplayer validation: non-goals
- Golden Balloon OpenGL path remains desktop diagnostic only
