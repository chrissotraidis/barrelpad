#!/usr/bin/env bash
# Build ChimpPad for iOS / iPadOS Simulator (arm64).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAMILY="phone"
MODE="simulator"

while [ $# -gt 0 ]; do
  case "$1" in
    --simulator) MODE="simulator"; shift ;;
    --device) MODE="device"; shift ;;
    --device-family) FAMILY="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ "$MODE" != "simulator" ]; then
  echo "[ChimpPad] physical device builds are out of scope for this milestone" >&2
  exit 2
fi

"$ROOT/scripts/test-unit.sh"

# Ensure host sources exist (patched goldenballoon under sources/)
if [ ! -f "$ROOT/sources/goldenballoon/CMakeLists.txt" ]; then
  "$ROOT/scripts/clone-refs.sh"
  # Apply iOS patches via re-run of configure path documented in BUILDING.md
  echo "[ChimpPad] sources missing patches; clone-refs done — re-apply iOS patches before build"
fi

SDL_PREFIX="${CHIMPPAD_SDL_IOS:-$ROOT/build-deps/sdl2-ios-sim}"
if [ ! -f "$SDL_PREFIX/lib/libSDL2.a" ]; then
  echo "[ChimpPad] building SDL2 for iOS Simulator..."
  "$ROOT/scripts/build-sdl2-ios.sh"
fi

export PKG_CONFIG_PATH="$SDL_PREFIX/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="$SDL_PREFIX/lib/pkgconfig"

BUILD="${CHIMPPAD_IOS_BUILD:-$ROOT/build-ios-sim}"
cmake -S "$ROOT/sources/goldenballoon" -B "$BUILD" \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_SYSROOT=iphonesimulator \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_SYSTEM_PROCESSOR=arm64 \
  -DCMAKE_BUILD_TYPE=Release \
  -G Ninja \
  -DMDKR_IOS_SIMULATOR=ON \
  -DBUILD_TESTING=OFF \
  -DCMAKE_PREFIX_PATH="$SDL_PREFIX"

cmake --build "$BUILD" -j"${CHIMPPAD_JOBS:-$(sysctl -n hw.ncpu)}" --target mdkr64

# Package ChimpPad.app
APP="$BUILD/ChimpPad.app"
mkdir -p "$APP"
cp -f "$BUILD/mdkr64.app/mdkr64" "$APP/ChimpPad"
# Ensure Info.plist
if [ ! -f "$APP/Info.plist" ]; then
  cat > "$APP/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleDisplayName</key><string>ChimpPad</string>
  <key>CFBundleExecutable</key><string>ChimpPad</string>
  <key>CFBundleIdentifier</key><string>com.chrissotraidis.chimppad</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>ChimpPad</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSRequiresIPhoneOS</key><true/>
  <key>MinimumOSVersion</key><string>15.0</string>
  <key>UIDeviceFamily</key><array><integer>1</integer><integer>2</integer></array>
  <key>UIStatusBarHidden</key><true/>
  <key>UIFileSharingEnabled</key><true/>
  <key>LSSupportsOpeningDocumentsInPlace</key><true/>
  <key>UISupportedInterfaceOrientations</key>
  <array>
    <string>UIInterfaceOrientationLandscapeLeft</string>
    <string>UIInterfaceOrientationLandscapeRight</string>
  </array>
  <key>UIRequiredDeviceCapabilities</key>
  <array><string>arm64</string></array>
</dict>
</plist>
PLIST
fi

echo "[ChimpPad] Simulator app ($FAMILY): $APP"
echo "$APP" > "$BUILD/last-app-path.txt"
