#!/usr/bin/env bash
# Focused packaged-app smoke for DinoPad's fresh macOS keyboard defaults,
# fullscreen transition, and bounded warm-session memory observation. Physical
# mouse-button acceptance remains manual because macOS filters synthetic clicks.
# Run through scripts/runtime-guard.sh.
set -eu

if [ "${DINOPAD_ALLOW_UI_AUTOMATION:-0}" != "1" ]; then
  echo "ERROR: this smoke takes over the active Mac window, keyboard, and fullscreen Space for about two minutes." >&2
  echo "Re-run only while the workstation is idle with DINOPAD_ALLOW_UI_AUTOMATION=1." >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build-macos/DinoPad.app/Contents/MacOS/DinoPad"
SOURCE_ROOT="$HOME/Library/Application Support/DinoPad"
SOURCE_ROM="$SOURCE_ROOT/dino.z64"
SOURCE_NRM="$SOURCE_ROOT/mods/dinomod_enhanced.offline.nrm"
TODAY="$(date +%Y-%m-%d)"
EVIDENCE="$ROOT/docs/evidence/$TODAY/macos-desktop-controls"
SCRATCH="$(mktemp -d "$ROOT/.goal-loop/desktop-controls-smoke.XXXXXX")"
DATA_ROOT="$SCRATCH/data"
LOG="$EVIDENCE/runtime.log"
MEMORY="$EVIDENCE/memory.tsv"
APP_PID=""

cleanup() {
  trap - EXIT INT TERM
  if [ -n "$APP_PID" ] && kill -0 "$APP_PID" 2>/dev/null; then
    kill "$APP_PID" 2>/dev/null || true
    for _ in $(jot 50 1); do
      if ! kill -0 "$APP_PID" 2>/dev/null; then break; fi
      sleep 0.1
    done
    if kill -0 "$APP_PID" 2>/dev/null; then kill -9 "$APP_PID" 2>/dev/null || true; fi
    wait "$APP_PID" 2>/dev/null || true
  fi
  case "$SCRATCH" in
    "$ROOT"/.goal-loop/desktop-controls-smoke.*) rm -rf -- "$SCRATCH" ;;
    *) echo "ERROR: refusing to remove unexpected scratch path: $SCRATCH" >&2 ;;
  esac
}
trap cleanup EXIT INT TERM

sendkey() {
  local key="$1" hold="${2:-0.45}"
  osascript -e 'tell application "System Events" to set frontmost of (first application process whose name is "DinoPad") to true' >/dev/null
  sleep 0.2
  osascript -e "tell application \"System Events\" to key down $key" >/dev/null
  sleep "$hold"
  osascript -e "tell application \"System Events\" to key up $key" >/dev/null
  sleep 0.25
}

window_size() {
  osascript \
    -e 'tell application "System Events" to tell process "DinoPad"' \
    -e 'set bestSize to {0, 0}' \
    -e 'set bestArea to 0' \
    -e 'repeat with candidate in windows' \
    -e 'set candidateSize to size of candidate' \
    -e 'set candidateArea to (item 1 of candidateSize) * (item 2 of candidateSize)' \
    -e 'if candidateArea > bestArea then set bestSize to candidateSize' \
    -e 'if candidateArea > bestArea then set bestArea to candidateArea' \
    -e 'end repeat' \
    -e 'return bestSize' \
    -e 'end tell' 2>/dev/null
}

toggle_fullscreen() {
  osascript -e 'tell application "System Events" to set frontmost of (first application process whose name is "DinoPad") to true' >/dev/null
  sleep 0.2
  osascript -e 'tell application "System Events" to key down option' \
    -e 'tell application "System Events" to key code 36' \
    -e 'delay 0.2' \
    -e 'tell application "System Events" to key up option' >/dev/null
}

require_log() {
  local pattern="$1" label="$2"
  if rg -q "$pattern" "$LOG"; then
    echo "PASS: $label"
  else
    echo "ERROR: $label was not observed" >&2
    return 1
  fi
}

if [ ! -x "$APP" ] || [ ! -f "$SOURCE_ROM" ] || [ ! -f "$SOURCE_NRM" ]; then
  echo "ERROR: missing packaged app, private ROM, or private restoration package" >&2
  exit 1
fi

mkdir -p "$DATA_ROOT/mods" "$EVIDENCE"
cp "$SOURCE_ROM" "$DATA_ROOT/dino.z64"
cp "$SOURCE_NRM" "$DATA_ROOT/mods/dinomod_enhanced.nrm"
DINOPAD_DATA_ROOT="$DATA_ROOT" DINOPAD_LOG_INPUT=1 \
  "$APP" --skip-launcher --profile prototype --window-width 960 --window-height 720 >"$LOG" 2>&1 &
APP_PID=$!
sleep 14
kill -0 "$APP_PID"

osascript -e 'tell application "System Events" to set frontmost of (first application process whose name is "DinoPad") to true' >/dev/null
sleep 1
scripts/capture-window.sh DinoPad "$EVIDENCE/windowed.png"
WINDOWED_SIZE="$(window_size)"

# macOS virtual-key codes: W/S/A/D, Space, X, Shift, Q/E/R/F, arrows,
# and Z/C. Start is exercised separately after the other gameplay bindings
# because the game's pause state captures subsequent input.
for key in 13 1 0 2 49 7 56 12 14 15 3 123 124 126 125 6 8; do
  sendkey "$key"
done

require_log 'x=-?0\.6[0-9]|y=-?0\.6[0-9]' 'WASD -> analog movement'
require_log 'buttons=0x8000' 'Space -> N64 A'
require_log 'buttons=0x4000' 'X -> N64 B'
require_log 'buttons=0x2000' 'Shift -> N64 Z'
require_log 'buttons=0x0002' 'Q -> C-left'
require_log 'buttons=0x0001' 'E -> C-right'
require_log 'buttons=0x0008' 'R -> C-up'
require_log 'buttons=0x0004' 'F -> C-down'
require_log 'buttons=0x0200' 'left arrow -> D-pad left'
require_log 'buttons=0x0100' 'right arrow -> D-pad right'
require_log 'buttons=0x0800' 'up arrow -> D-pad up'
require_log 'buttons=0x0400' 'down arrow -> D-pad down'
require_log 'buttons=0x0020' 'Z -> N64 L'
require_log 'buttons=0x0010' 'C -> N64 R'

# Replay held Start defaults across several poll windows. Synthetic keyboard
# events can otherwise land between game frames during the boot sequence.
for key in 53 50 53 50; do sendkey "$key" 0.7; done
require_log 'buttons=0x1000' 'Escape/backtick -> N64 Start'

# Option+Return is handled by the SDL desktop event path rather than N64
# polling. It avoids macOS keyboard settings that reserve the F11 key.
toggle_fullscreen
sleep 2
FULLSCREEN_SIZE="$(window_size)"
if [ "$FULLSCREEN_SIZE" = "$WINDOWED_SIZE" ]; then
  echo "ERROR: Option+Return did not change the window geometry ($WINDOWED_SIZE)" >&2
  exit 1
fi
echo "PASS: Option+Return fullscreen transition ($WINDOWED_SIZE -> $FULLSCREEN_SIZE)"

printf 'elapsed_seconds\trss_kib\n' >"$MEMORY"
for elapsed in 0 15 30 45; do
  if [ "$elapsed" -ne 0 ]; then sleep 15; fi
  kill -0 "$APP_PID"
  RSS="$(ps -o rss= -p "$APP_PID" | tr -d ' ')"
  printf '%s\t%s\n' "$elapsed" "$RSS" >>"$MEMORY"
done
echo "PASS: packaged app remained alive during 45-second warm memory sample"

# Return to a normal window, then use bounded process cleanup. Graceful RT64
# shutdown has its own dedicated repeated smoke; the SDL gameplay window does
# not expose a stable accessibility close button after fullscreen transitions.
toggle_fullscreen
sleep 2
kill "$APP_PID" 2>/dev/null || true
for _ in $(jot 50 1); do
  if ! kill -0 "$APP_PID" 2>/dev/null; then break; fi
  sleep 0.1
done
if kill -0 "$APP_PID" 2>/dev/null; then
  kill -9 "$APP_PID" 2>/dev/null || true
fi
wait "$APP_PID" 2>/dev/null || true
APP_PID=""

printf '%s\n' \
  'RESULT: PASS' \
  "windowed_size=$WINDOWED_SIZE" \
  "fullscreen_size=$FULLSCREEN_SIZE" \
  'scope=fresh keyboard defaults, fullscreen, bounded memory observation, guarded cleanup' \
  'manual_gate=physical left-click A and right-click B' \
  >"$EVIDENCE/result.txt"
echo "DESKTOP CONTROLS RESULT: PASS"
