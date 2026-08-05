#!/usr/bin/env bash
# Apply ChimpPad iOS patches onto sources/goldenballoon (pinned checkout).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:-$ROOT/sources/goldenballoon}"
if [ ! -f "$SRC/CMakeLists.txt" ]; then
  echo "missing $SRC — run scripts/clone-refs.sh first" >&2
  exit 1
fi
FULL="$ROOT/patches/goldenballoon-ios-full.patch"
if [ -f "$FULL" ]; then
  if (cd "$SRC" && patch -p1 --forward --dry-run < "$FULL" >/dev/null 2>&1); then
    (cd "$SRC" && patch -p1 --forward < "$FULL")
    echo "[ChimpPad] applied goldenballoon-ios-full.patch"
  else
    echo "[ChimpPad] full patch already applied or not clean; syncing touch sources only"
  fi
fi
mkdir -p "$SRC/platform/chimppad"
cp -f "$ROOT/ios/ChimpPadShell.mm" "$ROOT/ios/ChimpPadTouchControls.h" \
  "$ROOT/src/ChimpPadInput.c" "$ROOT/src/ChimpPadInput.h" \
  "$SRC/platform/chimppad/"
echo "[ChimpPad] chimppad touch sources synced into $SRC/platform/chimppad"
