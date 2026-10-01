#!/usr/bin/env bash
# Shared by the iOS engine and SDL builds: manual, CMake, then CPU count.
barrelpad_build_jobs() {
  local jobs origin
  if [ -n "${BARRELPAD_JOBS:-}" ]; then
    jobs="$BARRELPAD_JOBS"
    origin="BARRELPAD_JOBS"
  elif [ -n "${CMAKE_BUILD_PARALLEL_LEVEL:-}" ]; then
    jobs="$CMAKE_BUILD_PARALLEL_LEVEL"
    origin="CMAKE_BUILD_PARALLEL_LEVEL"
  else
    jobs="$(sysctl -n hw.ncpu)" || return
    origin="sysctl hw.ncpu"
  fi
  if [[ ! "$jobs" =~ ^[1-9][0-9]*$ ]]; then
    echo "[BarrelPad] $origin must be a positive canonical integer (1, 2, ...): '$jobs'" >&2
    return 2
  fi
  printf '%s\n' "$jobs"
}
