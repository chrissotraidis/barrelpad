# Known issues, limitations, failed approaches

## Open issues

| ID | Severity | Summary | Reproduce | Status |
|---|---|---|---|---|
| ORIENT-01 | low | Simulator often launches portrait; game letterboxed | Launch iOS app without landscape lock | Open — force landscape UI orientations + SDL hint next |
| SAVE-01 | low | Simulator may log read-only save create failures | Launch on sim; inspect mdkr64.log | Non-blocking |
| TOUCH-01 | low | Touch overlay may be hard to see on dark intro frames | Screenshot at intro | Overlay linked; verify mid-menu next |
| PATCH-01 | med | iOS patches live in `sources/goldenballoon` disposable tree | Fresh clone | Need `scripts/apply-ios-patches.sh` packaging |
| KART-01 | med | Kart can remain oriented sideways after some closed-door impacts until it enters water | Physical iPad; intermittently collide with a closed Adventure door | Open; accepted known issue for the current release — do not change physics before release |

### KART-01 — sideways orientation after a closed-door impact

**Player-visible symptom:** On physical iPad, an intermittent collision with a
closed Adventure door can leave the kart travelling or responding sideways.
Normal steering may not restore the expected forward orientation; entering
water has recovered it.

**What is confirmed:** BarrelPad uses Golden Balloon's real object-model
collision for closed doors. A deterministic closed-door route on the pinned
Golden Balloon v1.0.4 host recorded 1,747 resolved object-collision hits from
frame 6641 through frame 8999. The authored-cadence arm also sustained repeated
contact, and Golden Balloon v1.1.0 produced the same 1,747-hit regression result.
This proves the prolonged door-contact condition, but the exact sideways state
has not yet been reproduced under an orientation trace.

**Likely seam, not yet a proven root cause:** Ground collision derives kart yaw
from four collision-adjusted wheel points and writes that result back into the
next frame. An asymmetric door impact could therefore preserve a bad heading.
Water uses a different steering path and damps lateral velocity, which is
consistent with the observed recovery.

**Logging gap:** `mdkr64.log` exists, but normal builds do not record door
identity, kart yaw, velocity heading, lateral velocity, wheel-point correction,
or water transitions. A past occurrence therefore leaves no decisive physics
event trail.

**Release decision (2026-08-08):** Keep this as an accepted open issue for the
current release. Do not alter collision or vehicle physics before release for an
intermittent issue without a captured bad-state transition and a regression
test. The player workaround is to enter water if the state occurs.

**Future investigation:** Add a throttled, opt-in persistent physics trace and
a deterministic post-door steerability assertion. Compare the captured
transition with retail behavior before selecting any fix.

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
