#!/usr/bin/env bash
# Build Golden Balloon (ChimpPad macOS host) via CMake/Ninja.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="${CHIMPPAD_MACOS_BUILD:-$ROOT/build-macos}"
SRC="${CHIMPPAD_HOST_SRC:-$ROOT/ref/goldenballoon}"

if [ ! -f "$SRC/CMakeLists.txt" ]; then
  "$ROOT/scripts/clone-refs.sh"
  SRC="$ROOT/ref/goldenballoon"
fi

echo "[ChimpPad] configure macOS host from $SRC"
cmake -S "$SRC" -B "$BUILD" \
  -DCMAKE_BUILD_TYPE="${CMAKE_BUILD_TYPE:-Release}" \
  -G Ninja \
  ${MDKR_WEBGPU_BACKEND:+-DMDKR_WEBGPU_BACKEND=$MDKR_WEBGPU_BACKEND}

echo "[ChimpPad] build mdkr64"
cmake --build "$BUILD" -j"${CHIMPPAD_JOBS:-$(sysctl -n hw.ncpu)}" --target mdkr64

# Unit tests (ChimpPad pure helpers)
echo "[ChimpPad] unit tests"
"$ROOT/scripts/test-unit.sh"

echo "[ChimpPad] macOS binary: $BUILD/mdkr64"
