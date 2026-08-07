#!/usr/bin/env bash
# Refuse tracked ROMs / large baserom-like blobs.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
bad=0
while IFS= read -r f; do
  case "$f" in
    *.v64|*.z64|*.n64)
      echo "ERROR: tracked ROM path: $f" >&2
      bad=1
      ;;
  esac
done < <(git ls-files)

if git ls-files | grep -E 'baseroms/|extracted/' >/dev/null 2>&1; then
  echo "ERROR: tracked extracted/baserom paths" >&2
  bad=1
fi

if [ "$bad" -ne 0 ]; then
  exit 1
fi
echo "[BarrelPad] repo safety OK (no tracked ROMs)"
