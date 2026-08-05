#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${CHIMPPAD_TEST_BIN:-$ROOT/build-unit}"
mkdir -p "$OUT"
clang -std=c11 -O2 -Wall -Wextra -Isrc \
  -o "$OUT/test_chimppad_input" \
  "$ROOT/src/ChimpPadInput.c" \
  "$ROOT/tests/test_chimppad_input.c" \
  -lm
"$OUT/test_chimppad_input"
echo "[ChimpPad] unit tests OK"
