#!/usr/bin/env bash
# Clone or update pinned reference repositories under ref/.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REF="$ROOT/ref"
mkdir -p "$REF"

DKR_URL="${DKR_URL:-https://github.com/davidsm64/diddy-kong-racing.git}"
DKR_PIN="${DKR_PIN:-c66957033046b1d66e72fcb096bf90fb49bcedba}"
GB_URL="${GB_URL:-https://github.com/akratch/goldenballoon.git}"
GB_PIN="${GB_PIN:-6fc93d886b090b22eb39d90fada535faa7282f2d}"

clone_pin() {
  local name="$1" url="$2" pin="$3" dir="$REF/$name"
  if [ -d "$dir/.git" ]; then
    echo "[BarrelPad] updating $name"
    git -C "$dir" fetch --depth 1 origin "$pin" 2>/dev/null || \
      git -C "$dir" fetch --depth 1 origin
    git -C "$dir" checkout --detach "$pin" 2>/dev/null || \
      git -C "$dir" checkout --detach "origin/main" || true
  else
    echo "[BarrelPad] cloning $name @ $pin"
    git clone --depth 1 "$url" "$dir"
    git -C "$dir" fetch --depth 1 origin "$pin" 2>/dev/null || true
    git -C "$dir" checkout --detach "$pin" 2>/dev/null || true
  fi
  echo "[BarrelPad] $name HEAD=$(git -C "$dir" rev-parse HEAD)"
}

clone_pin "diddy-kong-racing" "$DKR_URL" "$DKR_PIN"
clone_pin "goldenballoon" "$GB_URL" "$GB_PIN"

# Disposable build clone for patches
SOURCES="$ROOT/sources"
mkdir -p "$SOURCES"
if [ ! -d "$SOURCES/goldenballoon/.git" ]; then
  echo "[BarrelPad] mirroring goldenballoon into sources/"
  git clone "$REF/goldenballoon" "$SOURCES/goldenballoon"
fi
git -C "$SOURCES/goldenballoon" checkout --detach "$GB_PIN" 2>/dev/null || true

echo "[BarrelPad] refs ready"
