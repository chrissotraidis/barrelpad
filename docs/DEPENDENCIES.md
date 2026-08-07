# Dependencies

Every external dependency used by BarrelPad. Prefer pinning revisions. Do not
add optional or speculative dependencies.

## Reference repositories (`ref/`)

| Name | URL | Pinned revision | Purpose | Setup |
|---|---|---|---|---|
| SpaghettiPad | https://github.com/chrissotraidis/spaghettipad (local checkout under `ref/spaghettipad`) | as vendored in this worktree | Apple-port patterns: shell, touch, safe-area, scripts, README shape | Already present; read-only reference |
| Diddy Kong Racing decomp | https://github.com/davidsm64/diddy-kong-racing | `c66957033046b1d66e72fcb096bf90fb49bcedba` | Matching decomp; control/docs research; not runtime host | `git clone` into `ref/diddy-kong-racing` |
| Golden Balloon | https://github.com/akratch/goldenballoon | `6fc93d886b090b22eb39d90fada535faa7282f2d` | Native DKR port (game host) | `git clone` into `ref/goldenballoon`; build via CMake (see BUILDING.md) |

### Decomp-only tools (not required for BarrelPad play)

Recorded for completeness if someone rebuilds the N64 ROM from decomp:

- Homebrew: `make` (as `gmake`), `pcre2`
- Python 3 + venv packages from decomp `requirements.txt`
- MIPS binutils / IDO (installed by decomp `make setup`)
- Submodules under decomp `tools/`

**BarrelPad play path does not run the decomp Makefile.** Golden Balloon loads
assets from the ROM at runtime.

## Host build dependencies (macOS)

| Dependency | Source | Purpose |
|---|---|---|
| Xcode + CLT | Apple | clang, iOS Simulator, Metal, codesign tooling |
| CMake ≥ 3.16 | Homebrew `cmake` | Configure Golden Balloon / BarrelPad |
| Ninja | Homebrew `ninja` | Fast builds |
| pkg-config | Homebrew `pkgconf` | Find SDL2 |
| SDL2 | Homebrew or Golden Balloon’s release-built SDL2 | Window, audio, input, controllers |
| Python 3 | system / pyenv | Golden Balloon configure helpers / tests |
| Network at first configure | — | wgpu-native prebuilt download (SHA-verified) when WebGPU is ON |

Install:

```sh
brew install cmake ninja pkgconf make
# SDL2: brew install sdl2  (or use goldenballoon macos/Scripts/build_release_sdl2.sh
# for a real libSDL2 without sdl2-compat → SDL3 shim issues)
```

### wgpu-native (fetched by Golden Balloon CMake)

- Version: `v29.0.1.1` (see `ref/goldenballoon/cmake/webgpu.cmake`)
- Purpose: WebGPU C API → Metal on Apple silicon
- Pin/SHA: enforced inside Golden Balloon’s cmake; not re-pinned here
- Disable with `-DMDKR_WEBGPU_BACKEND=OFF` for OpenGL-only diagnostic builds

## Runtime game data

| Item | Location | Policy |
|---|---|---|
| Diddy Kong Racing ROM | Local only, e.g. `ref/Diddy Kong Racing (U) (M2) (V1.1) [!].v64` | Never commit, redistribute, modify, or bundle. US 1.1 V64 family expected by Golden Balloon for this dump. |

Local ROM fingerprint (for operator verification only — not redistributed):

```text
SHA-1: 03f04dfe0c34e8bad370aa4b68f4bb8ed3429fde
Format: Nintendo 64 ROM image (V64)
Label: US 1.1 (M2)
```

Golden Balloon accepts `.z64` / `.v64` / `.n64` and verifies revision (US 1.1
and European 1.1 supported). BarrelPad must copy or pass a path; never rewrite
the canonical `ref/` file in place for redistribution.

## Intentionally not added

| Candidate | Why omitted |
|---|---|
| SpaghettiKart / libultraship / Torch | MK64-specific; DKR has Golden Balloon instead |
| Emulator cores (mupen64plus, ares) | Unnecessary once native port host is available |
| Emscripten / browser stack | Out of scope for native Apple targets |
| Closed binary-only PC ports | Golden Balloon is open source; prefer it |

## License notes

- BarrelPad integration code: project license (see root LICENSE when present).
- Golden Balloon first-party: MIT (see `ref/goldenballoon/LICENSE`, `NOTICE.md`).
- Decomp: see `ref/diddy-kong-racing/LICENSE.md`.
- SpaghettiPad: reference only; rights boundary in its `RIGHTS_AND_LICENSES.md`.
- Nintendo ROM/assets: not included; user-supplied.
