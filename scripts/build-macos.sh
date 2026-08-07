#!/usr/bin/env bash
# Build Golden Balloon (BarrelPad macOS host) via CMake/Ninja.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="${BARRELPAD_MACOS_BUILD:-$ROOT/build-macos}"
SRC="${BARRELPAD_HOST_SRC:-$ROOT/ref/goldenballoon}"

if [ ! -f "$SRC/CMakeLists.txt" ]; then
  "$ROOT/scripts/clone-refs.sh"
  SRC="$ROOT/ref/goldenballoon"
fi

echo "[BarrelPad] configure macOS host from $SRC"
cmake -S "$SRC" -B "$BUILD" \
  -DCMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE:-Release}" \
  -G Ninja \
  ${MDKR_WEBGPU_BACKEND:+-DMDKR_WEBGPU_BACKEND=$MDKR_WEBGPU_BACKEND}

echo "[BarrelPad] build mdkr64"
cmake --build "$BUILD" -j"${BARRELPAD_JOBS:-$(sysctl -n hw.ncpu)}" --target mdkr64

# Unit tests (BarrelPad pure helpers)
echo "[BarrelPad] unit tests"
"$ROOT/scripts/test-unit.sh"

echo "[BarrelPad] macOS binary: $BUILD/mdkr64"
