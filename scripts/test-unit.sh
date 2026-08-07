#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${BARRELPAD_TEST_BIN:-$ROOT/build-unit}"
mkdir -p "$OUT"
clang -std=c11 -O2 -Wall -Wextra -Isrc \
  -o "$OUT/test_barrelpad_input" \
  "$ROOT/src/BarrelPadInput.c" \
  "$ROOT/tests/test_barrelpad_input.c" \
  -lm
"$OUT/test_barrelpad_input"
echo "[BarrelPad] unit tests OK"
