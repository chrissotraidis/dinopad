#!/usr/bin/env bash
# Drive the real AppKit file picker through invalid rejection and byte-swapped
# supported-ROM import. Run through runtime-guard.sh.
set -eu

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build-macos/DinoPad"
SOURCE_ROM="$HOME/Library/Application Support/DinoPad/dino.z64"
EXPECTED_MD5="49f7bb346ade39d1915c22e090ffd748"
EVIDENCE_DIR="${DINOPAD_IMPORT_EVIDENCE_DIR:-}"
SCRATCH="$(mktemp -d "$ROOT/.goal-loop/native-import-smoke.XXXXXX")"
DATA_ROOT="$SCRATCH/data"
INVALID_ROM="$SCRATCH/invalid.z64"
V64_ROM="$SCRATCH/dinosaur-planet.v64"
APP_PID=""

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

cleanup() {
  trap - EXIT INT TERM
  stop_app
  case "$SCRATCH" in
    "$ROOT"/.goal-loop/native-import-smoke.*) rm -rf -- "$SCRATCH" ;;
    *) echo "ERROR: refusing to remove unexpected scratch path: $SCRATCH" >&2 ;;
  esac
}
trap cleanup EXIT INT TERM

wait_for_button() {
  local button="$1"
  for _ in $(jot 150 1); do
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

choose_picker_file() {
  PICKER_PATH="$1" osascript \
    -e 'set selectedPath to system attribute "PICKER_PATH"' \
    -e 'tell application "System Events" to tell process "DinoPad" to keystroke "g" using {command down, shift down}' \
    -e 'delay 0.5' \
    -e 'tell application "System Events" to tell process "DinoPad" to keystroke selectedPath' \
    -e 'tell application "System Events" to tell process "DinoPad" to key code 36' \
    -e 'delay 1' \
    -e 'tell application "System Events" to tell process "DinoPad" to key code 36'
}

if [ ! -x "$APP" ] || [ ! -f "$SOURCE_ROM" ]; then
  echo "ERROR: missing DinoPad or private supported ROM" >&2
  exit 1
fi
mkdir -p "$DATA_ROOT"
if [ -n "$EVIDENCE_DIR" ]; then mkdir -p "$EVIDENCE_DIR"; fi

# These are private, disposable fixtures. One preserves z64 byte order but has
# a modified payload; the other converts every byte pair to v64 order.
python3 -c 'import pathlib,sys; data=bytearray(pathlib.Path(sys.argv[1]).read_bytes()); data[-1] ^= 1; pathlib.Path(sys.argv[2]).write_bytes(data)' "$SOURCE_ROM" "$INVALID_ROM"
python3 -c 'import pathlib,sys; data=pathlib.Path(sys.argv[1]).read_bytes(); out=bytearray(len(data)); out[0::2]=data[1::2]; out[1::2]=data[0::2]; pathlib.Path(sys.argv[2]).write_bytes(out)' "$SOURCE_ROM" "$V64_ROM"

DINOPAD_DATA_ROOT="$DATA_ROOT" "$APP" >"$SCRATCH/runtime.log" 2>&1 &
APP_PID=$!
wait_for_button "Choose ROM…"
click_button "Choose ROM…"
sleep 1
choose_picker_file "$INVALID_ROM"
wait_for_button "OK"
if [ -n "$EVIDENCE_DIR" ]; then
  "$ROOT/scripts/capture-window.sh" DinoPad "$EVIDENCE_DIR/invalid-rom-rejected.png"
fi
if [ -e "$DATA_ROOT/dino.z64" ]; then
  echo "ERROR: invalid ROM left a staged private copy" >&2
  exit 1
fi
click_button "OK"
wait_for_button "Choose ROM…"
click_button "Choose ROM…"
sleep 1
choose_picker_file "$V64_ROM"
wait_for_button "Restored Adventure"
if [ -n "$EVIDENCE_DIR" ]; then
  "$ROOT/scripts/capture-window.sh" DinoPad "$EVIDENCE_DIR/imported-home.png"
fi

stored_md5="$(md5 -q "$DATA_ROOT/dino.z64")"
if [ "$stored_md5" != "$EXPECTED_MD5" ]; then
  echo "ERROR: normalized stored ROM fingerprint mismatch: $stored_md5" >&2
  exit 1
fi
stored_magic="$(xxd -p -l 4 "$DATA_ROOT/dino.z64")"
if [ "$stored_magic" != "80371240" ]; then
  echo "ERROR: stored ROM is not normalized z64: $stored_magic" >&2
  exit 1
fi
rg -Fq "DinoPad ROM import accepted (December 2000 prototype)" "$SCRATCH/runtime.log" || {
  echo "ERROR: native accepted-import marker missing" >&2; exit 1;
}

click_button "Restored Adventure"
sleep 2
stop_app
echo "NATIVE IMPORT RESULT: PASS (invalid rejected; v64 normalized; exact MD5 stored; home reached)"
