#!/usr/bin/env bash
# Prove that the same binary falls back to the unmodified base-function path
# when the restoration package is absent. Run through runtime-guard.sh.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build-macos/DinoPad.app/Contents/MacOS/DinoPad"
MOD_DIR="$HOME/Library/Application Support/DinoPad/mods"
NRM="$MOD_DIR/dinomod_enhanced.offline.nrm"
DYLIB="$MOD_DIR/dinomod_enhanced.offline.dylib"
DISABLED_NRM="$MOD_DIR/dinomod_enhanced.offline.nrm.disabled"
DISABLED_DYLIB="$MOD_DIR/dinomod_enhanced.offline.dylib.disabled"
SCRATCH="$ROOT/.goal-loop/static-prototype"
EVIDENCE_DIR="${DINOPAD_PROTOTYPE_EVIDENCE_DIR:-}"
APP_PID=""
MOVED_NRM=0
MOVED_DYLIB=0

mkdir -p "$SCRATCH"

cleanup() {
  trap - EXIT INT TERM
  if [ -n "$APP_PID" ] && kill -0 "$APP_PID" 2>/dev/null; then
    kill "$APP_PID" 2>/dev/null || true
    for _ in $(jot 100 1); do
      if ! kill -0 "$APP_PID" 2>/dev/null; then break; fi
      sleep 0.1
    done
    if kill -0 "$APP_PID" 2>/dev/null; then kill -9 "$APP_PID" 2>/dev/null || true; fi
    wait "$APP_PID" 2>/dev/null || true
  fi
  if [ "$MOVED_NRM" -eq 1 ] && [ -f "$DISABLED_NRM" ]; then
    mv "$DISABLED_NRM" "$NRM"
  fi
  if [ "$MOVED_DYLIB" -eq 1 ] && [ -f "$DISABLED_DYLIB" ]; then
    mv "$DISABLED_DYLIB" "$DYLIB"
  fi
}
trap cleanup EXIT INT TERM

if [ ! -x "$APP" ]; then
  echo "ERROR: missing executable: $APP" >&2
  exit 1
fi
if [ ! -f "$NRM" ] || [ ! -f "$DYLIB" ]; then
  echo "ERROR: expected macOS feasibility mod artifacts are not installed" >&2
  exit 1
fi
if [ -e "$DISABLED_NRM" ] || [ -e "$DISABLED_DYLIB" ]; then
  echo "ERROR: prototype smoke staging paths already exist" >&2
  exit 1
fi

mv "$NRM" "$DISABLED_NRM"
MOVED_NRM=1
mv "$DYLIB" "$DISABLED_DYLIB"
MOVED_DYLIB=1
echo "restoration package disabled; testing base-function fallback"

"$APP" --skip-launcher --window-width 1024 --window-height 768 \
  >"$SCRATCH/runtime.log" 2>&1 &
APP_PID=$!

send_space() {
  osascript -e 'tell application "System Events" to set frontmost of (first application process whose name is "DinoPad") to true' 2>/dev/null || true
  sleep 0.2
  osascript -e 'tell application "System Events" to key down 49' 2>/dev/null
  sleep 0.35
  osascript -e 'tell application "System Events" to key up 49' 2>/dev/null
}

sleep 12
send_space
sleep 2
send_space
sleep 6

if [ -n "$EVIDENCE_DIR" ]; then
  mkdir -p "$EVIDENCE_DIR"
  "$ROOT/scripts/capture-window.sh" DinoPad "$EVIDENCE_DIR/prototype-game-select.png"
fi

if ! kill -0 "$APP_PID" 2>/dev/null; then
  echo "ERROR: DinoPad exited during Prototype fallback smoke" >&2
  exit 1
fi
if rg -q "Using statically linked code|Static restoration dispatch enabled" "$SCRATCH/runtime.log"; then
  echo "ERROR: restoration dispatch activated with the package absent" >&2
  exit 1
fi

echo "STATIC PROTOTYPE RESULT: PASS (same binary; restoration absent; base wrappers active)"
