#!/usr/bin/env bash
# runtime-guard.sh - enforce the one-runtime-at-a-time rule for DinoPad.
#
# Usage:
#   scripts/runtime-guard.sh <target> [udid] <command...>
#
# target: macos | iphone-simulator | ipad-simulator | physical-iphone | physical-ipad
#
# Acquires an atomic .goal-loop/runtime.lock directory, performs mandatory
# pre-launch cleanup (terminate DinoPad, shut down all Simulators, verify zero
# booted), runs the given command, then on exit terminates the DinoPad process,
# shuts down Simulators, verifies zero booted, and releases the lock.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK_DIR="$ROOT/.goal-loop/runtime.lock"
INFO_FILE="$LOCK_DIR/info"

TARGET="${1:-}"
shift 2>/dev/null || true
UDID="${1:-}"

case "$TARGET" in
  macos|iphone-simulator|ipad-simulator|physical-iphone|physical-ipad) ;;
  *)
    echo "usage: runtime-guard.sh <target> [udid] <command...>" >&2
    exit 2
    ;;
esac

if [ "$#" -eq 0 ]; then
  echo "usage: runtime-guard.sh <target> [udid] <command...>" >&2
  exit 2
fi

mkdir -p "$ROOT/.goal-loop"

pid_alive() { kill -0 "$1" 2>/dev/null; }

wait_for_dinopad_exit() {
  attempts=0
  while pgrep -x DinoPad >/dev/null 2>&1 && [ "$attempts" -lt 100 ]; do
    sleep 0.1
    attempts=$((attempts + 1))
  done
  ! pgrep -x DinoPad >/dev/null 2>&1
}

acquire() {
  if [ -d "$LOCK_DIR" ]; then
    old_pid=""
    if [ -f "$INFO_FILE" ]; then
      old_pid="$(sed -n 's/^pid: //p' "$INFO_FILE" | head -1)"
    fi
    if [ -n "$old_pid" ] && pid_alive "$old_pid"; then
      old_cmd="$(sed -n 's/^command: //p' "$INFO_FILE" | head -1)"
      echo "ERROR: runtime lock held by PID $old_pid: $old_cmd" >&2
      exit 1
    fi
    # Stale lock: verify the owner process is really gone before removing.
    if [ -n "$old_pid" ] && pgrep -x DinoPad 2>/dev/null | grep -q "^${old_pid}$"; then
      echo "ERROR: lock owner PID $old_pid still running as DinoPad" >&2
      exit 1
    fi
    echo "note: removing stale runtime lock (owner PID ${old_pid:-unknown} not alive)" >&2
    rm -rf "$LOCK_DIR"
  fi
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "ERROR: could not acquire runtime lock $LOCK_DIR" >&2
    exit 1
  fi
}

pre_launch_cleanup() {
  pkill -x DinoPad 2>/dev/null || true
  wait_for_dinopad_exit || true
  xcrun simctl terminate booted com.chrissotraidis.dinopad 2>/dev/null || true
  xcrun simctl shutdown all 2>/dev/null || true
  booted="$(xcrun simctl list devices 2>/dev/null | grep -c '(Booted)' || true)"
  if [ "$booted" -ne 0 ]; then
    echo "ERROR: $booted Simulator(s) still booted; refusing to continue" >&2
    return 1
  fi
  if pgrep -x DinoPad >/dev/null 2>&1; then
    echo "ERROR: stale DinoPad process still running; refusing to continue" >&2
    return 1
  fi
}

write_info() {
  {
    echo "target: $TARGET"
    if [ -n "$UDID" ]; then
      echo "udid: $UDID"
    fi
    echo "pid: $$"
    echo "command: $*"
    echo "start: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$INFO_FILE"
}

cleanup() {
  trap - EXIT INT TERM
  echo "runtime-guard: cleanup: terminating DinoPad and shutting down Simulators"
  pkill -x DinoPad 2>/dev/null || true
  wait_for_dinopad_exit || true
  xcrun simctl terminate booted com.chrissotraidis.dinopad 2>/dev/null || true
  xcrun simctl shutdown all 2>/dev/null || true
  booted="$(xcrun simctl list devices 2>/dev/null | grep -c '(Booted)' || true)"
  if [ "$booted" -ne 0 ]; then
    echo "WARNING: $booted Simulator(s) still booted after cleanup" >&2
  else
    echo "runtime-guard: cleanup: 0 booted Simulators"
  fi
  if pgrep -x DinoPad >/dev/null 2>&1; then
    echo "WARNING: DinoPad process still running after cleanup" >&2
  else
    echo "runtime-guard: cleanup: no DinoPad process"
  fi
  rm -rf "$LOCK_DIR"
  echo "runtime-guard: lock released"
}
trap cleanup EXIT INT TERM

acquire
pre_launch_cleanup
write_info "$@"

echo "runtime-guard: acquired ($TARGET${UDID:+ $UDID}), running: $*"
"$@"
rc=$?
echo "runtime-guard: command finished with rc=$rc"
exit "$rc"
