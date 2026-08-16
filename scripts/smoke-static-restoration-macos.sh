#!/usr/bin/env bash
# Prove that Restored Adventure uses code linked into DinoPad, with the mod
# package presented as an ordinary .nrm and the developer offline dylib absent.
# Run through scripts/runtime-guard.sh.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build-macos/DinoPad"
MOD_DIR="$HOME/Library/Application Support/DinoPad/mods"
OFFLINE_NRM="$MOD_DIR/dinomod_enhanced.offline.nrm"
STATIC_NRM="$MOD_DIR/dinomod_enhanced.nrm"
OFFLINE_DYLIB="$MOD_DIR/dinomod_enhanced.offline.dylib"
DISABLED_DYLIB="$MOD_DIR/dinomod_enhanced.offline.dylib.disabled"
SCRATCH="$ROOT/.goal-loop/static-restoration"
EVIDENCE_DIR="${DINOPAD_STATIC_EVIDENCE_DIR:-}"
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
  if [ "$MOVED_NRM" -eq 1 ] && [ -f "$STATIC_NRM" ]; then
    mv "$STATIC_NRM" "$OFFLINE_NRM"
  fi
  if [ "$MOVED_DYLIB" -eq 1 ] && [ -f "$DISABLED_DYLIB" ]; then
    mv "$DISABLED_DYLIB" "$OFFLINE_DYLIB"
  fi
}
trap cleanup EXIT INT TERM

if [ ! -x "$APP" ]; then
  echo "ERROR: missing executable: $APP" >&2
  exit 1
fi
if [ ! -f "$OFFLINE_NRM" ] || [ ! -f "$OFFLINE_DYLIB" ]; then
  echo "ERROR: expected macOS feasibility mod artifacts are not installed" >&2
  exit 1
fi
if [ -e "$STATIC_NRM" ] || [ -e "$DISABLED_DYLIB" ]; then
  echo "ERROR: static smoke staging paths already exist" >&2
  exit 1
fi

static_function_count="$(nm -gj "$APP" | rg -c '^_mod_func_[0-9]+$')"
if [ "$static_function_count" -ne 460 ]; then
  echo "ERROR: expected 460 linked mod functions, found $static_function_count" >&2
  exit 1
fi
if otool -L "$APP" | rg -qi 'dinomod|offline'; then
  echo "ERROR: DinoPad has a dynamic DinoMod dependency" >&2
  exit 1
fi

mv "$OFFLINE_NRM" "$STATIC_NRM"
MOVED_NRM=1
mv "$OFFLINE_DYLIB" "$DISABLED_DYLIB"
MOVED_DYLIB=1
echo "static package installed; offline dylib disabled"

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

sleep 13
send_space
sleep 4
if [ -n "$EVIDENCE_DIR" ]; then
  mkdir -p "$EVIDENCE_DIR"
  "$ROOT/scripts/capture-window.sh" DinoPad "$EVIDENCE_DIR/static-press-start.png"
fi
send_space
sleep 5
if [ -n "$EVIDENCE_DIR" ]; then
  "$ROOT/scripts/capture-window.sh" DinoPad "$EVIDENCE_DIR/static-title-menu.png"
fi

if ! kill -0 "$APP_PID" 2>/dev/null; then
  echo "ERROR: DinoPad exited during static restoration smoke" >&2
  exit 1
fi
if ! rg -q "Using statically linked code for mod dinomod_enhanced" "$SCRATCH/runtime.log"; then
  echo "ERROR: runtime did not select the static mod code handle" >&2
  exit 1
fi

echo "STATIC RESTORATION RESULT: PASS (460 linked functions; no dynamic dependency)"
