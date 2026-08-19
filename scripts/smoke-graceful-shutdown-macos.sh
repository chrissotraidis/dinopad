#!/usr/bin/env bash
# Repeatedly close DinoPad through the native macOS window and require a clean
# process exit. Run this through scripts/runtime-guard.sh so no other DinoPad
# or Simulator runtime overlaps the test.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build-macos/DinoPad.app/Contents/MacOS/DinoPad"
RUNS="${1:-5}"
LOG_DIR="$ROOT/.goal-loop/graceful-shutdown"
CRASH_DIR="$HOME/Library/Logs/DiagnosticReports"

case "$RUNS" in
  ''|*[!0-9]*) echo "usage: $0 [positive-run-count]" >&2; exit 2 ;;
  0) echo "run count must be positive" >&2; exit 2 ;;
esac

if [ ! -x "$APP" ]; then
  echo "ERROR: missing executable: $APP" >&2
  exit 1
fi

mkdir -p "$LOG_DIR"
crash_count() {
  find "$CRASH_DIR" -maxdepth 1 -type f -name 'DinoPad*.ips' 2>/dev/null | wc -l | tr -d ' '
}

before_crashes="$(crash_count)"
passes=0

for run in $(jot "$RUNS" 1); do
  log="$LOG_DIR/run-$run.log"
  echo "=== graceful shutdown run $run/$RUNS ==="
  "$APP" >"$log" 2>&1 &
  app_pid=$!

  if ! osascript <<'APPLESCRIPT' >/dev/null
tell application "System Events"
  repeat 80 times
    if exists application process "DinoPad" then
      tell application process "DinoPad"
        set frontmost to true
        if exists window 1 then
          click button 1 of window 1
          return
        end if
      end tell
    end if
    delay 0.25
  end repeat
end tell
error "DinoPad window did not appear"
APPLESCRIPT
  then
    echo "FAIL: run $run could not close the DinoPad window" >&2
    kill "$app_pid" 2>/dev/null || true
    wait "$app_pid" 2>/dev/null || true
    exit 1
  fi

  exited=0
  for _ in $(jot 120 1); do
    if ! kill -0 "$app_pid" 2>/dev/null; then
      exited=1
      break
    fi
    sleep 0.25
  done
  if [ "$exited" -ne 1 ]; then
    echo "FAIL: run $run did not exit within 30 seconds" >&2
    kill "$app_pid" 2>/dev/null || true
    wait "$app_pid" 2>/dev/null || true
    exit 1
  fi

  wait "$app_pid"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "FAIL: run $run exited with rc=$rc" >&2
    exit 1
  fi
  if pgrep -x DinoPad >/dev/null 2>&1; then
    echo "FAIL: DinoPad process remains after run $run" >&2
    exit 1
  fi
  passes=$((passes + 1))
  echo "PASS: run $run exited cleanly"
done

# CrashReporter writes asynchronously, so allow a brief bounded flush window.
sleep 2
after_crashes="$(crash_count)"
if [ "$after_crashes" -ne "$before_crashes" ]; then
  echo "FAIL: DinoPad crash-report count changed ($before_crashes -> $after_crashes)" >&2
  exit 1
fi

echo "GRACEFUL SHUTDOWN RESULT: PASS ($passes/$RUNS; crash reports $before_crashes -> $after_crashes)"
