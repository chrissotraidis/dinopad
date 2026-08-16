#!/usr/bin/env bash
# Verify DinoPad's native macOS first-run/home boundary and both profile
# handoffs against disposable data roots. Run through runtime-guard.sh.
set -eu

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build-macos/DinoPad"
SOURCE_ROOT="$HOME/Library/Application Support/DinoPad"
SOURCE_ROM="$SOURCE_ROOT/dino.z64"
SOURCE_NRM="$SOURCE_ROOT/mods/dinomod_enhanced.offline.nrm"
EVIDENCE_DIR="${DINOPAD_HOME_EVIDENCE_DIR:-}"
SCRATCH="$(mktemp -d "$ROOT/.goal-loop/native-home-smoke.XXXXXX")"
DATA_ROOT="$SCRATCH/data"
EMPTY_ROOT="$SCRATCH/empty"
APP_PID=""

cleanup() {
  trap - EXIT INT TERM
  stop_app
  case "$SCRATCH" in
    "$ROOT"/.goal-loop/native-home-smoke.*) rm -rf -- "$SCRATCH" ;;
    *) echo "ERROR: refusing to remove unexpected scratch path: $SCRATCH" >&2 ;;
  esac
}
trap cleanup EXIT INT TERM

stop_app() {
  if [ -n "$APP_PID" ] && kill -0 "$APP_PID" 2>/dev/null; then
    kill "$APP_PID" 2>/dev/null || true
    for _ in $(jot 100 1); do
      if ! kill -0 "$APP_PID" 2>/dev/null; then break; fi
      sleep 0.1
    done
    if kill -0 "$APP_PID" 2>/dev/null; then kill -9 "$APP_PID" 2>/dev/null || true; fi
    wait "$APP_PID" 2>/dev/null || true
  fi
  APP_PID=""
}

wait_for_button() {
  local button="$1"
  for _ in $(jot 100 1); do
    if osascript -e "tell application \"System Events\" to tell process \"DinoPad\" to exists button \"$button\" of window 1" 2>/dev/null | rg -q true; then
      return 0
    fi
    sleep 0.1
  done
  echo "ERROR: native button did not appear: $button" >&2
  return 1
}

click_button() {
  osascript -e "tell application \"System Events\" to tell process \"DinoPad\" to click button \"$1\" of window 1" >/dev/null
}

send_space() {
  osascript -e 'tell application "System Events" to set frontmost of (first application process whose name is "DinoPad") to true' 2>/dev/null || true
  sleep 0.2
  osascript -e 'tell application "System Events" to key down 49' 2>/dev/null
  sleep 0.35
  osascript -e 'tell application "System Events" to key up 49' 2>/dev/null
}

if [ ! -x "$APP" ] || [ ! -f "$SOURCE_ROM" ] || [ ! -f "$SOURCE_NRM" ]; then
  echo "ERROR: missing DinoPad, private ROM, or private restoration package" >&2
  exit 1
fi
mkdir -p "$DATA_ROOT/mods" "$EMPTY_ROOT"
cp "$SOURCE_ROM" "$DATA_ROOT/dino.z64"
cp "$SOURCE_NRM" "$DATA_ROOT/mods/dinomod_enhanced.nrm"
if [ -n "$EVIDENCE_DIR" ]; then mkdir -p "$EVIDENCE_DIR"; fi

# First-run state: no ROM produces native setup and exits cleanly on Quit.
DINOPAD_DATA_ROOT="$EMPTY_ROOT" "$APP" >"$SCRATCH/setup.log" 2>&1 &
APP_PID=$!
wait_for_button "Choose ROM…"
if [ -n "$EVIDENCE_DIR" ]; then
  "$ROOT/scripts/capture-window.sh" DinoPad "$EVIDENCE_DIR/native-rom-setup.png"
fi
click_button "Quit"
wait "$APP_PID"
setup_status=$?
APP_PID=""
if [ "$setup_status" -ne 0 ]; then
  echo "ERROR: setup Quit returned $setup_status" >&2
  exit 1
fi

# Prototype path: home -> explicit warning -> base profile/game flow.
DINOPAD_DATA_ROOT="$DATA_ROOT" "$APP" >"$SCRATCH/prototype.log" 2>&1 &
APP_PID=$!
wait_for_button "Restored Adventure"
if [ -n "$EVIDENCE_DIR" ]; then
  "$ROOT/scripts/capture-window.sh" DinoPad "$EVIDENCE_DIR/native-home.png"
fi
click_button "Prototype Mode"
wait_for_button "Start Prototype Mode"
if [ -n "$EVIDENCE_DIR" ]; then
  "$ROOT/scripts/capture-window.sh" DinoPad "$EVIDENCE_DIR/native-prototype-warning.png"
fi
click_button "Start Prototype Mode"
sleep 13
send_space
sleep 2
send_space
sleep 6
if [ -n "$EVIDENCE_DIR" ]; then
  "$ROOT/scripts/capture-window.sh" DinoPad "$EVIDENCE_DIR/native-prototype-game-select.png"
fi
rg -Fq "DinoPad profile: Prototype (namespace=Profiles/Prototype)" "$SCRATCH/prototype.log" || {
  echo "ERROR: native Prototype handoff marker missing" >&2; exit 1;
}
if rg -q "Using statically linked code|Static restoration dispatch enabled" "$SCRATCH/prototype.log"; then
  echo "ERROR: restoration activated after native Prototype selection" >&2
  exit 1
fi
stop_app

# Restored path: the primary/default button enters static restoration.
DINOPAD_DATA_ROOT="$DATA_ROOT" "$APP" >"$SCRATCH/restored.log" 2>&1 &
APP_PID=$!
wait_for_button "Restored Adventure"
click_button "Restored Adventure"
sleep 13
send_space
sleep 4
if [ -n "$EVIDENCE_DIR" ]; then
  "$ROOT/scripts/capture-window.sh" DinoPad "$EVIDENCE_DIR/native-restored.png"
fi
rg -Fq "DinoPad profile: Restored (namespace=Profiles/Restored)" "$SCRATCH/restored.log" || {
  echo "ERROR: native Restored handoff marker missing" >&2; exit 1;
}
rg -q "Static restoration dispatch enabled .*no runtime code writes" "$SCRATCH/restored.log" || {
  echo "ERROR: native Restored dispatch marker missing" >&2; exit 1;
}
stop_app

echo "NATIVE HOME RESULT: PASS (first-run setup; Restored primary; warned Prototype; both handoffs)"
