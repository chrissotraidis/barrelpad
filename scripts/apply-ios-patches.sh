#!/usr/bin/env bash
# Apply ChimpPad iOS patches onto sources/goldenballoon (pinned checkout).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:-$ROOT/sources/goldenballoon}"
if [ ! -f "$SRC/CMakeLists.txt" ]; then
  echo "missing $SRC — run scripts/clone-refs.sh first" >&2
  exit 1
fi
if [ -f "$ROOT/patches/goldenballoon-ios-webgpu.patch" ]; then
  # Best-effort; full tree may already be patched
  (cd "$SRC" && patch -p1 --forward --dry-run < "$ROOT/patches/goldenballoon-ios-webgpu.patch" >/dev/null 2>&1) && \
    (cd "$SRC" && patch -p1 --forward < "$ROOT/patches/goldenballoon-ios-webgpu.patch") || \
    echo "[ChimpPad] webgpu patch already applied or drifted — continuing"
fi
mkdir -p "$SRC/platform/chimppad"
cp -f "$ROOT/ios/ChimpPadShell.mm" "$ROOT/ios/ChimpPadTouchControls.h" \
  "$ROOT/src/ChimpPadInput.c" "$ROOT/src/ChimpPadInput.h" \
  "$SRC/platform/chimppad/"
# Stub/main helpers if present in sources from prior build
for f in gfx_opengl_ios_stub.c chimppad_ios_main.c; do
  if [ -f "$SRC/platform/$f" ]; then :; fi
done
echo "[ChimpPad] iOS chimppad sources synced into $SRC/platform/chimppad"
echo "[ChimpPad] If configure fails, use the existing sources/goldenballoon tree that was last known-good."
