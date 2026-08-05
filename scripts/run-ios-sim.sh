#!/usr/bin/env bash
# Install and launch ChimpPad on one Simulator (phone or pad). Only one at a time.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAMILY="${1:-phone}"
BUILD="${CHIMPPAD_IOS_BUILD:-$ROOT/build-ios-sim}"
APP="$BUILD/ChimpPad.app"
ROM="${CHIMPPAD_ROM:-}"
if [ -z "$ROM" ]; then
  for cand in \
    "$ROOT/ref/Diddy Kong Racing (U) (M2) (V1.1) [!].v64" \
    "$ROOT/ref/"*.v64; do
    if [ -f "$cand" ]; then ROM="$cand"; break; fi
  done
fi

if [ ! -d "$APP" ]; then
  "$ROOT/scripts/build-ios.sh" --simulator --device-family "$FAMILY"
fi

# Shut down any running sims first (one at a time policy)
xcrun simctl shutdown all 2>/dev/null || true

if [ "$FAMILY" = "pad" ]; then
  DEV=$(xcrun simctl list devices available | grep -E 'iPad' | head -1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')
  # Prefer a named iPad if available
  for name in "iPad Pro 13-inch (M4)" "iPad Pro (12.9-inch) (6th generation)" "iPad Air (5th generation)" "iPad (10th generation)"; do
    UDID=$(xcrun simctl list devices available | grep "$name" | grep -oE '[A-F0-9-]{36}' | head -1 || true)
    if [ -n "${UDID:-}" ]; then DEV="$UDID"; break; fi
  done
else
  DEV=""
  for name in "iPhone 16" "iPhone 15" "iPhone 16 Pro" "iPhone 14"; do
    UDID=$(xcrun simctl list devices available | grep "$name (" | grep -v unavailable | grep -oE '[A-F0-9-]{36}' | head -1 || true)
    if [ -n "${UDID:-}" ]; then DEV="$UDID"; break; fi
  done
  if [ -z "$DEV" ]; then
    DEV=$(xcrun simctl list devices available | grep iPhone | grep -oE '[A-F0-9-]{36}' | head -1)
  fi
fi

echo "[ChimpPad] booting Simulator $DEV ($FAMILY)"
xcrun simctl boot "$DEV" 2>/dev/null || true
open -a Simulator --args -CurrentDeviceUDID "$DEV" || true
# Wait for boot
for i in $(seq 1 60); do
  state=$(xcrun simctl list devices | grep "$DEV" | grep -o 'Booted' || true)
  if [ "$state" = "Booted" ]; then break; fi
  sleep 1
done

xcrun simctl install "$DEV" "$APP"
BUNDLE="com.chrissotraidis.chimppad"

# Copy ROM into app Documents (never into the .app bundle in git)
if [ -n "$ROM" ] && [ -f "$ROM" ]; then
  DATA=$(xcrun simctl get_app_container "$DEV" "$BUNDLE" data 2>/dev/null || true)
  if [ -n "$DATA" ]; then
    mkdir -p "$DATA/Documents"
    cp -f "$ROM" "$DATA/Documents/diddy-kong-racing.v64"
    echo "[ChimpPad] ROM installed to Documents"
  fi
fi

echo "[ChimpPad] launching $BUNDLE"
# Pass ROM via args if supported
xcrun simctl launch --console-pty "$DEV" "$BUNDLE" \
  --rom /Documents/diddy-kong-racing.v64 \
  2>&1 | tee /tmp/chimppad-sim-launch.log | head -5 || \
xcrun simctl launch "$DEV" "$BUNDLE"

echo "[ChimpPad] launched on $FAMILY ($DEV)"
echo "$DEV" > "$BUILD/last-sim-udid.txt"
