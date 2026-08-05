# Handoff / status

**Date:** 2026-08-05  
**Repo:** `/Users/chrissotraidis/GitHub/chimppad`

## What works

- **macOS:** `scripts/build-macos.sh` → `build-macos/mdkr64`. Loads local US 1.1 V64 ROM; WebGPU/Metal; intro and menus render; `--input-script` drives pad; active logs (`[mdkr64]`, `[webgpu]`, `[ROM]`).
- **iPhone Simulator:** `build-ios-sim/ChimpPad.app` installs/launches; WebGPU on “Apple iOS simulator GPU”; Rareware / intro screens render with `--rom` path into Documents.
- **iPad Simulator:** same app; non-blank gameplay surface (intro).
- **Unit tests:** `scripts/test-unit.sh` — stick, layout phone/tablet, safe area, DKR host key tokens, A-hold assist.
- **Touch shell:** `ios/ChimpPadShell.mm` + `src/ChimpPadInput.*` linked into iOS app; SpaghettiPad-style overlay with DKR mappings (A=X accel, B=Z brake, R=Space, Z=Shift item).
- **Docs:** architecture, dependencies (pins), build, ROM policy, touch, status, evidence, issues, handoff.
- **Git safety:** `.gitignore` excludes ROMs, baseroms, build trees, large `ref/` clones.

## What does not work / limitations

- **Portrait letterboxing** on Simulator until landscape orientation is forced at launch (game still renders).
- **Save path on Simulator** may log “Read-only file system” for some save probes; not launch-blocking.
- **Physical device / signing / App Store:** out of scope.
- **Touch overlay visual verification** on Simulator screenshots may not always show translucent buttons depending on intro timing; code is linked and initialized.
- **sources/goldenballoon** holds ChimpPad iOS patches (not upstreamed); re-clone requires re-applying via build path / documenting patch set under `patches/`.

## Next highest-priority task

1. Force **landscape** launch orientation and verify touch overlay visible on both phone and pad screenshots.
2. Auto-discover ROM in Documents without requiring `--rom` argv on iOS.
3. Package `scripts/apply-ios-patches.sh` so a fresh goldenballoon pin is one-command.
4. Optional: A-hold assist + layout editor polish parity with SpaghettiPad.

## How to reproduce residual issues

### Portrait letterbox

```sh
scripts/build-ios.sh --simulator
scripts/run-ios-sim.sh phone
# Observe game in portrait with black bars
```

### Save read-only warnings (Simulator)

Launch with ROM; check app container log under  
`Library/Application Support/mdkr64/mdkr64/` for `[SAVE] could not create save`.

## How to resume

1. Read this file + [ARCHITECTURE.md](ARCHITECTURE.md) + [DEPENDENCIES.md](DEPENDENCIES.md).
2. `scripts/build-macos.sh` / `scripts/build-ios.sh` / `scripts/test-unit.sh`.
3. Never commit ROM ([ROM_POLICY.md](ROM_POLICY.md)).
4. Pins: decomp `c669570…`, goldenballoon `6fc93d8…`.
