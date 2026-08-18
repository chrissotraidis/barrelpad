#!/usr/bin/env bash
# Build static SDL2 for iOS Simulator or physical devices (arm64).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:---simulator}"
case "$MODE" in
  --simulator)
    SDK="iphonesimulator"
    KIND="sim"
    DEFAULT_PREFIX="$ROOT/build-deps/sdl2-ios-sim"
    ;;
  --device)
    SDK="iphoneos"
    KIND="dev"
    DEFAULT_PREFIX="$ROOT/build-deps/sdl2-ios-dev"
    ;;
  *)
    echo "usage: $0 [--simulator|--device]" >&2
    exit 2
    ;;
esac
SDL_VER="${SDL_VER:-2.32.10}"
WORK="${BARRELPAD_SDL_WORK:-$ROOT/build-deps/src}"
PREFIX="${BARRELPAD_SDL_IOS:-$DEFAULT_PREFIX}"
mkdir -p "$WORK"
cd "$WORK"
if [ ! -d "SDL2-$SDL_VER" ]; then
  curl -sL "https://github.com/libsdl-org/SDL/releases/download/release-$SDL_VER/SDL2-$SDL_VER.tar.gz" \
    -o "SDL2-$SDL_VER.tar.gz"
  tar xzf "SDL2-$SDL_VER.tar.gz"
fi
BUILD="$WORK/sdl2-ios-$KIND-build"
cmake -S "SDL2-$SDL_VER" -B "$BUILD" \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_SYSROOT="$SDK" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_C_FLAGS="-ffile-prefix-map=$ROOT=." \
  -DCMAKE_OBJC_FLAGS="-ffile-prefix-map=$ROOT=." \
  -DSDL_SHARED=OFF \
  -DSDL_STATIC=ON \
  -DSDL_TEST=OFF \
  -DCMAKE_BUILD_TYPE=Release \
  -G Ninja
cmake --build "$BUILD" -j"$(sysctl -n hw.ncpu)"
cmake --install "$BUILD" --prefix "$PREFIX"
# Fix pkg-config prefix
if [ -f "$PREFIX/lib/pkgconfig/sdl2.pc" ]; then
  sed -i.bak "s|^prefix=.*|prefix=$PREFIX|" "$PREFIX/lib/pkgconfig/sdl2.pc"
fi
echo "[BarrelPad] SDL2 iOS $MODE installed at $PREFIX"
