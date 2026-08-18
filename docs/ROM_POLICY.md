# ROM and asset policy

## Hard rules

1. **Supply your own ROM.** BarrelPad never ships, downloads, or generates a
   Diddy Kong Racing ROM or extractable copyrighted assets.
2. **Local use only.** The ROM in `ref/` is for local build, extract, and run
   on this machine. Do not commit, push, redistribute, bundle into `.app` /
   `.ipa` / archives, upload, or share it.
3. **Do not modify the canonical `ref/` ROM** for redistribution. If format
   conversion (byte-swap V64→Z64) is required, operate on a **copy** under a
   gitignored build directory.
4. **Do not commit extracted assets** (textures, audio, models, levels,
   `.o2r`, baserom dumps, etc.).
5. **`.gitignore` must cover** `*.v64`, `*.z64`, `*.n64`, baseroms, assets,
   build trees, and local saves.

## Expected dump for this workspace

| Field | Value |
|---|---|
| Path (local) | `ref/Diddy Kong Racing (U) (M2) (V1.1) [!].v64` |
| Format | V64 (byte-swapped) |
| Region / rev | US 1.1 |
| SHA-1 | `03f04dfe0c34e8bad370aa4b68f4bb8ed3429fde` |

Golden Balloon validates size, byte-order normalization, revision identity,
and asset-table bounds at load time. US 1.1 and European 1.1 are supported
hosts; US 1.0 is the decomp default but is a different dump.

## Decomp note

If using `ref/diddy-kong-racing` to rebuild a ROM:

```sh
# copy — do not move — into baseroms (gitignored there too)
cp "ref/Diddy Kong Racing (U) (M2) (V1.1) [!].v64" \
  ref/diddy-kong-racing/baseroms/
# US 1.1: REGION=us VERSION=v80
```

BarrelPad **play** does not require decomp extract/build.

## App packaging checks

Build and package scripts must refuse to embed ROM bytes. Prefer an audit step
(scan for known SHA-1 / large baserom-sized blobs) before any distribution
artifact is produced.

`scripts/package-ios.sh` applies this boundary to the public IPA: it checks
file names, N64 ROM header magic, the supported ROM SHA-1, saves, signing
material, runtime linkage, and the final ZIP contents before producing the
artifact and checksum.
