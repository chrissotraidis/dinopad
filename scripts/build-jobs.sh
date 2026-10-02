#!/usr/bin/env bash
# Required host-tool and patch builds: manual override, PadMint, then default.
dinopad_build_jobs() {
  local jobs origin
  if [ -n "${DINOPAD_MAX_JOBS:-}" ]; then
    jobs="$DINOPAD_MAX_JOBS"
    origin="DINOPAD_MAX_JOBS"
  elif [ -n "${CMAKE_BUILD_PARALLEL_LEVEL:-}" ]; then
    jobs="$CMAKE_BUILD_PARALLEL_LEVEL"
    origin="CMAKE_BUILD_PARALLEL_LEVEL"
  else
    jobs=4
    origin="default"
  fi
  if [[ ! "$jobs" =~ ^[1-9][0-9]*$ ]]; then
    echo "ERROR: $origin must be a positive whole number (1, 2, ...)" >&2
    return 2
  fi
  printf '%s\n' "$jobs"
}
