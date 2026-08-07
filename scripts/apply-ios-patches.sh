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
DEVICE_UI="$ROOT/patches/goldenballoon-ios-device-ui.patch"
if [ -f "$DEVICE_UI" ]; then
  if (cd "$SRC" && patch -p1 --forward --dry-run < "$DEVICE_UI" >/dev/null 2>&1); then
    (cd "$SRC" && patch -p1 --forward < "$DEVICE_UI")
    echo "[ChimpPad] applied goldenballoon-ios-device-ui.patch"
  else
    echo "[ChimpPad] device-ui patch already applied or not clean"
  fi
fi
PHONE_SETTINGS="$ROOT/patches/goldenballoon-ios-phone-settings.patch"
if [ -f "$PHONE_SETTINGS" ]; then
  if (cd "$SRC" && patch -p1 --forward --dry-run < "$PHONE_SETTINGS" >/dev/null 2>&1); then
    (cd "$SRC" && patch -p1 --forward < "$PHONE_SETTINGS")
    echo "[ChimpPad] applied goldenballoon-ios-phone-settings.patch"
  else
    echo "[ChimpPad] phone-settings patch already applied or not clean"
  fi
fi
# Direct P1 pad inject (shell → platform_ios_touch_set → input queue).
python3 "$ROOT/scripts/ensure-ios-touch-inject.py" "$SRC"
mkdir -p "$SRC/platform/chimppad"
cp -f "$ROOT/ios/ChimpPadShell.mm" "$ROOT/ios/ChimpPadTouchControls.h" \
  "$ROOT/src/ChimpPadInput.c" "$ROOT/src/ChimpPadInput.h" \
  "$SRC/platform/chimppad/"
if [ -f "$ROOT/ios/ChimpPadRomBoot.mm" ]; then
  cp -f "$ROOT/ios/ChimpPadRomBoot.mm" "$ROOT/ios/ChimpPadRomBoot.h" \
    "$SRC/platform/chimppad/" 2>/dev/null || true
fi
echo "[ChimpPad] chimppad touch sources synced into $SRC/platform/chimppad"
