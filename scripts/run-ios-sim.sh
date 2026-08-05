#!/usr/bin/env bash
# Install and launch ChimpPad on one Simulator (phone or pad). Only one at a time.
# Boots into DKR when a ROM is present in Documents (or CHIMPPAD_ROM / --rom).
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
  DEV=""
  for name in "iPad Pro 13-inch (M5)" "iPad Pro 13-inch (M4)" "iPad Pro 11-inch (M5)" "iPad Air 13-inch (M4)" "iPad (A16)"; do
    UDID=$(xcrun simctl list devices available | grep "$name" | grep -oE '[A-F0-9-]{36}' | head -1 || true)
    if [ -n "${UDID:-}" ]; then DEV="$UDID"; break; fi
  done
  if [ -z "$DEV" ]; then
    DEV=$(xcrun simctl list devices available | grep iPad | grep -oE '[A-F0-9-]{36}' | head -1)
  fi
else
  DEV=""
  for name in "iPhone 17" "iPhone 16" "iPhone 15" "iPhone 17 Pro"; do
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
for i in $(seq 1 60); do
  state=$(xcrun simctl list devices | grep "$DEV" | grep -o 'Booted' || true)
  if [ "$state" = "Booted" ]; then break; fi
  sleep 1
done

xcrun simctl install "$DEV" "$APP"
BUNDLE="com.chrissotraidis.chimppad"

DATA=$(xcrun simctl get_app_container "$DEV" "$BUNDLE" data)
mkdir -p "$DATA/Documents"
if [ -n "$ROM" ] && [ -f "$ROM" ]; then
  cp -f "$ROM" "$DATA/Documents/diddy-kong-racing.v64"
  echo "[ChimpPad] ROM installed to Documents/diddy-kong-racing.v64"
fi

# Child env: boot game with AppHost + touch (not headless CLI path).
# ChimpPad_PrepareIosRomBoot also auto-discovers Documents ROMs.
export SIMCTL_CHILD_MDKR_ROM="${DATA}/Documents/diddy-kong-racing.v64"
export SIMCTL_CHILD_MDKR_APP_AUTOPLAY=1
# Optional: scripted pad while agent also taps overlay
if [ -n "${CHIMPPAD_INPUT_SCRIPT:-}" ] && [ -f "${CHIMPPAD_INPUT_SCRIPT}" ]; then
  # Copy script into container so guest can read it
  cp -f "$CHIMPPAD_INPUT_SCRIPT" "$DATA/Documents/input-script.txt"
  export SIMCTL_CHILD_MDKR_APP_AUTOPLAY_INPUT_SCRIPT="$DATA/Documents/input-script.txt"
fi

echo "[ChimpPad] launching $BUNDLE (MDKR_APP_AUTOPLAY + Documents ROM)"
if [ -n "${CHIMPPAD_CONSOLE_LOG:-}" ]; then
  xcrun simctl launch --console --terminate-running-process "$DEV" "$BUNDLE" \
    >"$CHIMPPAD_CONSOLE_LOG" 2>&1 &
else
  xcrun simctl launch --terminate-running-process "$DEV" "$BUNDLE"
fi

echo "[ChimpPad] launched on $FAMILY ($DEV)"
echo "$DEV" > "$BUILD/last-sim-udid.txt"
