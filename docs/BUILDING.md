# Building ChimpPad

## Prerequisites

- macOS with Xcode and command-line tools
- Homebrew packages: `cmake`, `ninja`, `pkgconf`, `make`
- SDL2 (Homebrew `sdl2` / `sdl2-compat`, or Golden Balloon’s release SDL2 build)
- Local DKR ROM (see [ROM_POLICY.md](ROM_POLICY.md)) — **not** a build-time
  input for compile; required only to launch/play

```sh
brew install cmake ninja pkgconf make
```

## One-command paths

### macOS (desktop host)

```sh
scripts/build-macos.sh
# optional: run with ROM
scripts/run-macos.sh --rom "ref/Diddy Kong Racing (U) (M2) (V1.1) [!].v64"
```

### iOS / iPadOS Simulator

```sh
# one Simulator at a time
scripts/build-ios.sh --simulator --device-family phone
scripts/build-ios.sh --simulator --device-family pad
```

See [STATUS.md](STATUS.md) for which targets currently launch playably.

## What the scripts do

1. Ensure pinned Golden Balloon sources are present under `sources/goldenballoon`
   (cloned from the pin in [DEPENDENCIES.md](DEPENDENCIES.md) if missing).
2. Configure CMake (WebGPU ON for macOS when available; iOS uses the
   documented backend for that target).
3. Build `mdkr64` / ChimpPad app product.
4. Log loudly with `[ChimpPad]` prefixes during smoke runs.

## Manual Golden Balloon build (debug)

```sh
cd ref/goldenballoon   # or sources/goldenballoon
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -G Ninja
cmake --build build -j
./build/mdkr64 --rom "/absolute/path/to/rom.v64"
```

OpenGL-only diagnostic:

```sh
cmake -S . -B build-gl -DMDKR_WEBGPU_BACKEND=OFF -DCMAKE_BUILD_TYPE=Release -G Ninja
```

## ROM at runtime

Pass `--rom <path>` or use the native launcher file picker. ChimpPad’s iOS
shell looks under the app Documents container and known dev paths; it never
embeds the ROM in the bundle.

## Tests

```sh
scripts/test-unit.sh
# or: cmake --build build --target chimppad_input_tests && ctest --test-dir build -R chimppad
```

## iOS game boot

`scripts/run-ios-sim.sh` copies the ROM into the app Documents container and
sets `SIMCTL_CHILD_MDKR_ROM` + `SIMCTL_CHILD_MDKR_APP_AUTOPLAY=1` so the
interactive AppHost boots Diddy Kong Racing with touch controls active.
Bare `--rom` on desktop is the headless engine path; on iOS, ChimpPad
prefers autoplay so the overlay stays live.
