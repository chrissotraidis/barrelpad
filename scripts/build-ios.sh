#!/usr/bin/env bash
# Build BarrelPad for iOS / iPadOS Simulator (arm64).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="${BARRELPAD_SOURCE:-$ROOT/sources/goldenballoon}"
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

if [ "$MODE" = "device" ]; then
  SDK="iphoneos"
  IOS_SIMULATOR="OFF"
  BUILD_DEFAULT="$ROOT/build-ios-device"
  SDL_DEFAULT="$ROOT/build-deps/sdl2-ios-dev"
  ACTOOL_PLATFORM="iphoneos"
else
  SDK="iphonesimulator"
  IOS_SIMULATOR="ON"
  BUILD_DEFAULT="$ROOT/build-ios-sim"
  SDL_DEFAULT="$ROOT/build-deps/sdl2-ios-sim"
  ACTOOL_PLATFORM="iphonesimulator"
fi

"$ROOT/scripts/test-unit.sh"

# Ensure host sources exist (patched goldenballoon under sources/)
if [ ! -f "$SOURCE/CMakeLists.txt" ]; then
  "$ROOT/scripts/clone-refs.sh"
fi
"$ROOT/scripts/apply-ios-patches.sh" "$SOURCE"

SDL_PREFIX="${BARRELPAD_SDL_IOS:-$SDL_DEFAULT}"
if [ ! -f "$SDL_PREFIX/lib/libSDL2.a" ]; then
  echo "[BarrelPad] building SDL2 for iOS $MODE..."
  "$ROOT/scripts/build-sdl2-ios.sh" "--$MODE"
fi

export PKG_CONFIG_PATH="$SDL_PREFIX/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="$SDL_PREFIX/lib/pkgconfig"

BUILD="${BARRELPAD_IOS_BUILD:-$BUILD_DEFAULT}"
cmake -S "$SOURCE" -B "$BUILD" \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_SYSROOT="$SDK" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_SYSTEM_PROCESSOR=arm64 \
  -DCMAKE_BUILD_TYPE=Release \
  -G Ninja \
  -DMDKR_IOS_SIMULATOR="$IOS_SIMULATOR" \
  -DBUILD_TESTING=OFF \
  -DCMAKE_PREFIX_PATH="$SDL_PREFIX"

cmake --build "$BUILD" -j"${BARRELPAD_JOBS:-$(sysctl -n hw.ncpu)}" --target mdkr64

# Package BarrelPad.app
APP="$BUILD/BarrelPad.app"
# Recreate the generated bundle so a prior local signature, profile, or stale
# executable can never leak into a new unsigned product.
cmake -E remove_directory "$APP"
cmake -E make_directory "$APP"
cp -f "$BUILD/mdkr64.app/mdkr64" "$APP/BarrelPad"

# SDL2 is linked statically, so its local build-directory rpath is unnecessary
# and must not leak into a redistributable app product.
while IFS= read -r rpath; do
  [ -n "$rpath" ] || continue
  install_name_tool -delete_rpath "$rpath" "$APP/BarrelPad"
done < <(otool -l "$APP/BarrelPad" | awk '
  /cmd LC_RPATH/ { getline; getline; sub(/^ *path /, ""); sub(/ \(offset.*$/, ""); print }
')
if otool -l "$APP/BarrelPad" | grep -q 'cmd LC_RPATH'; then
  echo "[BarrelPad] refusing app executable with a remaining LC_RPATH" >&2
  exit 1
fi

# Apps without modern launch-screen metadata are placed in the legacy 480x320
# iPhone compatibility canvas. Always package the reviewed native template.
cp -f "$ROOT/ios/Info.plist" "$APP/Info.plist"

# Xcode's asset compiler turns the checked-in universal AppIcon catalog into
# the Assets.car used by modern iOS and iPadOS launchers.
actool --compile "$APP" \
  --platform "$ACTOOL_PLATFORM" \
  --minimum-deployment-target 15.0 \
  --app-icon AppIcon \
  --output-partial-info-plist "$BUILD/AppIcon-Info.plist" \
  "$ROOT/ios/Assets.xcassets"
/usr/libexec/PlistBuddy -c "Merge $BUILD/AppIcon-Info.plist" "$APP/Info.plist"

echo "[BarrelPad] $MODE app ($FAMILY): $APP"
echo "$APP" > "$BUILD/last-app-path.txt"
