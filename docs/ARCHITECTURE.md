# Architecture

## What ChimpPad is

ChimpPad is a native macOS, iPhone, and iPad shell for **Diddy Kong Racing**,
built around the open-source [Golden Balloon](https://github.com/akratch/goldenballoon)
native port (which itself is built from the
[Diddy Kong Racing decompilation](https://github.com/davidsm64/diddy-kong-racing)).

It is **not** an emulator shell of the decomp ROM rebuild. Game logic runs as
compiled host code (the Golden Balloon / `mdkr64` engine). ChimpPad supplies:

- Apple platform packaging and lifecycle
- ROM discovery and legal boundary (local ROM only; never redistributed)
- SpaghettiPad-inspired virtual N64 controller and touch overlays
- DKR-specific button mapping and phone/tablet layouts
- Active runtime logging for diagnosis

## Layering

```text
┌─────────────────────────────────────────────────────────────┐
│  ChimpPad shell (this repo: ios/, macos/, scripts/, docs/)  │
│  • lifecycle, logging, ROM path, touch overlay, layouts     │
└───────────────────────────┬─────────────────────────────────┘
                            │ SDL2 window / virtual controller
┌───────────────────────────▼─────────────────────────────────┐
│  Golden Balloon host (ref/goldenballoon → sources/)         │
│  • platform/* (SDL, audio, input, WebGPU/GL, launcher)      │
│  • game/* (ported decomp game code)                         │
└───────────────────────────┬─────────────────────────────────┘
                            │ runtime asset read
┌───────────────────────────▼─────────────────────────────────┐
│  Local legally owned DKR ROM (ref/*.v64 — gitignored)       │
└─────────────────────────────────────────────────────────────┘
```

## Relationship to references

| Reference | Role |
|---|---|
| `ref/spaghettipad` | Primary **Apple-port** pattern book: shell lifecycle, virtual controller, touch quality, safe areas, phone/tablet layouts, README structure, build-script shape. **Not** MK64 game logic. |
| `ref/goldenballoon` | Primary **game host**. Open MIT native port of DKR from the decomp. macOS/Linux/Windows/browser already; ChimpPad extends Apple mobile packaging and touch. |
| `ref/diddy-kong-racing` | Upstream matching decompilation. Used for control semantics research and future decomp sync; **not** the runtime host (it rebuilds an N64 ROM via IDO/MIPS). |

## Why not pure decomp-as-host?

`davidsm64/diddy-kong-racing` is a matching decompilation that rebuilds a
console ROM. SpaghettiPad’s host (SpaghettiKart + libultraship) has no DKR
equivalent in that repo. Golden Balloon is the maintained open native port of
that decomp and is the pragmatic playable host for Apple platforms.

## Input model (DKR)

DKR N64 pad usage (racing-focused):

| Control | Typical DKR use |
|---|---|
| Stick | Steer / menu navigate |
| A | Accelerate / confirm |
| B | Brake / reverse / cancel |
| Z | Use item / special |
| R | Hop / power-slide |
| L | Camera / secondary (context) |
| C-buttons | Camera / map interactions |
| Start | Pause / start |

ChimpPad maps touch controls to these via SDL virtual joystick + keyboard
fallback, adapted from SpaghettiPad’s emission path but **without** Mario Kart
item/hold semantics (no MK64 item-double-Z assumptions; A-hold assist is
optional and DKR-tuned).

## Targets

| Target | Backend preference | Notes |
|---|---|---|
| macOS (Apple silicon) | WebGPU (wgpu-native Metal) default; OpenGL diagnostic | Golden Balloon qualified path |
| iPhone Simulator | OpenGL ES / Metal via SDL2 as available | One Simulator at a time |
| iPad Simulator | Same as iPhone | Tablet touch layout |

## Repository layout

```text
chimppad/
  README.md
  docs/                 # first-class handoff documentation
  ios/                  # iOS/iPadOS shell + touch
  macos/                # macOS packaging helpers (if any)
  scripts/              # clone, configure, build, package, smoke
  sources/              # disposable pinned checkouts (gitignored build inputs)
  ref/                  # human-readable references (not build clones)
    spaghettipad/
    diddy-kong-racing/
    goldenballoon/
    *.v64               # local ROM only — gitignored
  tests/                # unit tests for pure mapping/layout helpers
```

## Logging

Runtime logging uses `os_log` / `NSLog` / SDL log with a stable `[ChimpPad]`
prefix. Enable verbose logs during smoke tests; capture under agent scratch
and summarize in `docs/evidence/`.
