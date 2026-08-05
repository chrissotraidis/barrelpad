#!/usr/bin/env bash
# Launch ChimpPad macOS host with optional ROM path and verbose logging.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="${CHIMPPAD_MACOS_BUILD:-$ROOT/build-macos}"
BIN="$BUILD/mdkr64"
ROM=""
EXTRA=()

while [ $# -gt 0 ]; do
  case "$1" in
    --rom) ROM="$2"; shift 2 ;;
    *) EXTRA+=("$1"); shift ;;
  esac
done

if [ ! -x "$BIN" ]; then
  "$ROOT/scripts/build-macos.sh"
fi

if [ -z "$ROM" ]; then
  # Prefer local ref ROM if present (never redistributed).
  for cand in \
    "$ROOT/ref/Diddy Kong Racing (U) (M2) (V1.1) [!].v64" \
    "$ROOT/ref/"*.v64 \
    "$ROOT/ref/"*.z64; do
    if [ -f "$cand" ]; then
      ROM="$cand"
      break
    fi
  done
fi

export SDL_LOG_PRIORITY="${SDL_LOG_PRIORITY:-INFO}"
echo "[ChimpPad] launching $BIN"
if [ -n "$ROM" ]; then
  echo "[ChimpPad] ROM=$ROM"
  exec "$BIN" --rom "$ROM" "${EXTRA[@]}"
else
  echo "[ChimpPad] no ROM path; opening launcher"
  exec "$BIN" "${EXTRA[@]}"
fi
