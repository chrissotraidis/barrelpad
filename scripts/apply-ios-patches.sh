#!/usr/bin/env bash
# Apply BarrelPad iOS patches onto sources/goldenballoon (pinned checkout).
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
    echo "[BarrelPad] applied goldenballoon-ios-full.patch"
  else
    echo "[BarrelPad] full patch already applied or not clean; syncing touch sources only"
  fi
fi
DEVICE_UI="$ROOT/patches/goldenballoon-ios-device-ui.patch"
if [ -f "$DEVICE_UI" ]; then
  if (cd "$SRC" && patch -p1 --forward --dry-run < "$DEVICE_UI" >/dev/null 2>&1); then
    (cd "$SRC" && patch -p1 --forward < "$DEVICE_UI")
    echo "[BarrelPad] applied goldenballoon-ios-device-ui.patch"
  else
    echo "[BarrelPad] device-ui patch already applied or not clean"
  fi
fi
PHONE_SETTINGS="$ROOT/patches/goldenballoon-ios-phone-settings.patch"
if [ -f "$PHONE_SETTINGS" ]; then
  if (cd "$SRC" && patch -p1 --forward --dry-run < "$PHONE_SETTINGS" >/dev/null 2>&1); then
    (cd "$SRC" && patch -p1 --forward < "$PHONE_SETTINGS")
    echo "[BarrelPad] applied goldenballoon-ios-phone-settings.patch"
  else
    echo "[BarrelPad] phone-settings patch already applied or not clean"
  fi
fi
# Direct P1 pad inject (shell → platform_ios_touch_set → input queue).
python3 "$ROOT/scripts/ensure-ios-touch-inject.py" "$SRC"
CONTROLLER_TAKEOVER="$ROOT/patches/goldenballoon-ios-controller-takeover.patch"
if [ -f "$CONTROLLER_TAKEOVER" ]; then
  if (cd "$SRC" && patch -p1 --forward --dry-run < "$CONTROLLER_TAKEOVER" >/dev/null 2>&1); then
    (cd "$SRC" && patch -p1 --forward < "$CONTROLLER_TAKEOVER")
    echo "[BarrelPad] applied goldenballoon-ios-controller-takeover.patch"
  else
    echo "[BarrelPad] controller-takeover patch already applied or not clean"
  fi
fi
mkdir -p "$SRC/platform/barrelpad"
cp -f "$ROOT/ios/BarrelPadShell.mm" "$ROOT/ios/BarrelPadTouchControls.h" \
  "$ROOT/src/BarrelPadInput.c" "$ROOT/src/BarrelPadInput.h" \
  "$SRC/platform/barrelpad/"
if [ -f "$ROOT/ios/BarrelPadRomBoot.mm" ]; then
  cp -f "$ROOT/ios/BarrelPadRomBoot.mm" "$ROOT/ios/BarrelPadRomBoot.h" \
    "$SRC/platform/barrelpad/" 2>/dev/null || true
fi
echo "[BarrelPad] barrelpad touch sources synced into $SRC/platform/barrelpad"
