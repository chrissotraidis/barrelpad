#!/usr/bin/env bash
# Build static SDL2 for iOS Simulator (arm64).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDL_VER="${SDL_VER:-2.32.10}"
WORK="${CHIMPPAD_SDL_WORK:-$ROOT/build-deps/src}"
PREFIX="${CHIMPPAD_SDL_IOS:-$ROOT/build-deps/sdl2-ios-sim}"
mkdir -p "$WORK"
cd "$WORK"
if [ ! -d "SDL2-$SDL_VER" ]; then
  curl -sL "https://github.com/libsdl-org/SDL/releases/download/release-$SDL_VER/SDL2-$SDL_VER.tar.gz" \
    -o "SDL2-$SDL_VER.tar.gz"
  tar xzf "SDL2-$SDL_VER.tar.gz"
fi
cmake -S "SDL2-$SDL_VER" -B "$WORK/sdl2-ios-sim-build" \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_SYSROOT=iphonesimulator \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DSDL_SHARED=OFF \
  -DSDL_STATIC=ON \
  -DSDL_TEST=OFF \
  -DCMAKE_BUILD_TYPE=Release \
  -G Ninja
cmake --build "$WORK/sdl2-ios-sim-build" -j"$(sysctl -n hw.ncpu)"
cmake --install "$WORK/sdl2-ios-sim-build" --prefix "$PREFIX"
# Fix pkg-config prefix
if [ -f "$PREFIX/lib/pkgconfig/sdl2.pc" ]; then
  sed -i.bak "s|^prefix=.*|prefix=$PREFIX|" "$PREFIX/lib/pkgconfig/sdl2.pc"
fi
echo "[ChimpPad] SDL2 iOS Simulator installed at $PREFIX"
