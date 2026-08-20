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
python3 "$ROOT/tests/test_pal_native_viewport.py"

BOOT_POLICY="$ROOT/ios/BarrelPadRomBoot.mm"
FULL_PATCH="$ROOT/patches/goldenballoon-ios-full.patch"
SETTINGS_PATCH="$ROOT/patches/goldenballoon-ios-phone-settings.patch"
if grep -Eq 'setenv\("MDKR_(ASPECT|WIDESCREEN)"' "$BOOT_POLICY" "$FULL_PATCH"; then
  echo "[BarrelPad] iOS presentation settings must remain player preferences" >&2
  exit 1
fi
grep -Fq 'setenv("MDKR_WINDOW_MODE", "fullscreen", 1);' "$BOOT_POLICY"
grep -Fq '{"auto",  "Auto (Fill Screen)"}' "$SETTINGS_PATCH"
grep -Fq '{"4:3",   "4:3 (Original)"}' "$SETTINGS_PATCH"
grep -Fq 'Another presentation setting is fixed for this session.' "$SETTINGS_PATCH"
echo "[BarrelPad] iOS presentation policy tests OK"
echo "[BarrelPad] unit tests OK"
