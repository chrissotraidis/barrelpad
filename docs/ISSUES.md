# Known issues, limitations, failed approaches

## Open issues

| ID | Severity | Summary | Reproduce | Status |
|---|---|---|---|---|
| ARCH-01 | info | Decomp alone is not a playable host | N/A | Resolved by adopting Golden Balloon as host; documented in ARCHITECTURE.md |
| — | — | (none yet for play path) | — | — |

## Failed / rejected approaches

| Approach | Why rejected |
|---|---|
| Treat `davidsm64/diddy-kong-racing` Makefile as the Apple runtime | Matching decomp rebuilds MIPS ROM via IDO; no LUS/PC host |
| Emulator-core-only host without native port | Unnecessary complexity once open Golden Balloon exists |
| Blind copy of SpaghettiPad MK64 button/item logic | Wrong game semantics; DKR mappings documented separately |

## Limitations (non-blocking)

- Physical device signing / TestFlight / App Store: out of scope (Simulator + macOS bar).
- HD texture packs, tilt steering, full multiplayer validation: non-goals for this milestone.
- Golden Balloon OpenGL path is diagnostic on desktop; WebGPU Restored is qualified upstream.
