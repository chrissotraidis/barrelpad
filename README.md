# ChimpPad

<p align="center">
  <strong>Diddy Kong Racing on Mac, iPhone, and iPad.</strong><br>
  Native WebGPU/Metal host, SpaghettiPad-inspired touch controls, and a
  bring-your-own-ROM workflow.
</p>

<p align="center">
  <img alt="macOS" src="https://img.shields.io/badge/macOS-Apple%20silicon-0A84FF?logo=apple">
  <img alt="iOS and iPadOS 15 or later" src="https://img.shields.io/badge/iOS%20%2F%20iPadOS-15%2B-0A84FF?logo=apple">
  <img alt="WebGPU / Metal" src="https://img.shields.io/badge/renderer-WebGPU%20%2F%20Metal-5E5CE6">
  <img alt="Touch controls" src="https://img.shields.io/badge/touch-DKR%20mapped-32ADE6">
  <img alt="ROM not included" src="https://img.shields.io/badge/game%20data-not%20included-FF453A">
</p>

ChimpPad is a native Apple shell around the open-source
[Golden Balloon](https://github.com/akratch/goldenballoon) port of
[Diddy Kong Racing](https://github.com/davidsm64/diddy-kong-racing). It reuses
[SpaghettiPad](ref/spaghettipad) patterns for lifecycle, virtual N64-style
input, safe-area touch layouts, and README/docs structure—but **maps controls
for DKR**, not Mario Kart 64.

This repository contains integration code, scripts, patches, and documentation.
It does **not** contain the Diddy Kong Racing ROM or extractable copyrighted
assets. Supply your own legally obtained dump. See [docs/ROM_POLICY.md](docs/ROM_POLICY.md).

## What you get

- **macOS** desktop play via Golden Balloon (`mdkr64`) with WebGPU → Metal
- **iPhone / iPad Simulator** app bundle with the same host
- **DKR touch mapping** (A accelerate, B brake, R hop/slide, Z item, C-buttons, Start)
- **Phone vs tablet** layout helpers with safe-area awareness
- **Active runtime logging** (`[ChimpPad]`, host `[mdkr64]` / `[webgpu]` lines)
- **Unit tests** for pure stick/layout/mapping helpers

## Current status

| Target | Status |
|---|---|
| macOS (Apple silicon) | **Playable** — ROM loads, intro/menus render, input scripts drive pad |
| iPhone Simulator | **Playable** — WebGPU on simulator GPU; intro screens render |
| iPad Simulator | **Playable** — same binary; tablet layout helpers present |
| Physical device / App Store | Out of scope for this milestone |

Details and evidence: [docs/STATUS.md](docs/STATUS.md), [docs/EVIDENCE.md](docs/EVIDENCE.md), [docs/HANDOFF.md](docs/HANDOFF.md).

## Requirements

- macOS with Xcode and command-line tools
- [Homebrew](https://brew.sh): `cmake`, `ninja`, `pkgconf`, `make`
- Your own **Diddy Kong Racing** ROM (`.z64` / `.v64` / `.n64`)
  - This workspace uses a local **US 1.1 V64** dump under `ref/` (gitignored)
  - Golden Balloon supports US 1.1 and European 1.1

```sh
brew install cmake ninja pkgconf make
```

## Quick start

```sh
git clone https://github.com/chrissotraidis/chimppad.git
cd chimppad
scripts/clone-refs.sh          # decomp + goldenballoon pins into ref/
scripts/build-macos.sh         # builds mdkr64 + unit tests
scripts/run-macos.sh --rom "/path/to/your.v64"
```

### iOS / iPadOS Simulator

```sh
scripts/build-ios.sh --simulator --device-family phone
scripts/run-ios-sim.sh phone    # or: pad
# Only one Simulator at a time
```

Place the ROM in the app Documents container (the run script copies from
`ref/` when present). Never embed the ROM in the committed tree.

## Documentation

| Doc | Contents |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Layers, host strategy, repo layout |
| [docs/DEPENDENCIES.md](docs/DEPENDENCIES.md) | URLs, pins, purpose, setup |
| [docs/BUILDING.md](docs/BUILDING.md) | Prerequisites and commands |
| [docs/ROM_POLICY.md](docs/ROM_POLICY.md) | Legal boundary for game data |
| [docs/TOUCH_CONTROLS.md](docs/TOUCH_CONTROLS.md) | DKR touch mapping and layouts |
| [docs/STATUS.md](docs/STATUS.md) | Target-by-target status |
| [docs/EVIDENCE.md](docs/EVIDENCE.md) | Test evidence ledger |
| [docs/ISSUES.md](docs/ISSUES.md) | Known issues and failed approaches |
| [docs/HANDOFF.md](docs/HANDOFF.md) | What works, what doesn’t, next task |

## Architecture in one paragraph

`davidsm64/diddy-kong-racing` is a matching N64 decompilation (rebuilds a
console ROM). It is **not** a libultraship-style PC host. ChimpPad therefore
uses **Golden Balloon** as the native game host and layers SpaghettiPad-style
Apple integration (shell, touch, logging) on top. The decomp remains a
reference under `ref/` for control semantics and future sync.

## Controls (DKR defaults)

| Touch / pad | Role |
|---|---|
| Stick | Steer / menu navigate |
| A | Accelerate / confirm |
| B | Brake / reverse / cancel |
| R | Hop / power-slide |
| Z | Item / special |
| C-buttons | Camera |
| Start | Pause |
| ••• | Shell menu (when wired) |

Keyboard defaults match Golden Balloon: `X` accel, `Z` brake, `Space` hop,
`Shift` item, arrows/WASD stick, `IJKL` C-buttons, Enter Start.

## License and rights

- ChimpPad integration code: see repository license when published
- Golden Balloon first-party code: MIT (`ref/goldenballoon/LICENSE`)
- Decomp: see `ref/diddy-kong-racing/LICENSE.md`
- SpaghettiPad: reference only
- Nintendo / Rare game data: **not included**; user-supplied only

## Contributing

1. Keep ROMs and extracted assets out of git (`scripts/check-repo-safety.sh`)
2. Prefer small, focused commits
3. Update `docs/` in the same change when behavior or status shifts
4. Run `scripts/test-unit.sh` before claiming input/layout changes
