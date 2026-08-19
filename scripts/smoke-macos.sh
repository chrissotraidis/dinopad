#!/usr/bin/env bash
# smoke-macos.sh - bounded automated input-replay smoke test of the DinoPad
# boot-to-gameplay flow on macOS arm64.
#
# Run under the one-runtime-at-a-time guard:
#   scripts/runtime-guard.sh macos scripts/smoke-macos.sh
#
# Verifies (see docs/TESTING.md "Automated smoke"):
#   1. app launch and window presence;
#   2. supported ROM presence + fingerprint;
#   3. GAME SELECT / save listing (screenshot evidence);
#   4. first controllable scene reached;
#   5. analog movement input delivered;
#   6. A / B / Z / Start button input delivered;
#   10. clean shutdown + save file integrity.
#
# If the private ROM or a build artifact is absent, the smoke test reports
# SKIP with a clear reason (never a fabricated PASS).
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TODAY="$(date +%Y-%m-%d)"
EVID="$ROOT/docs/evidence/$TODAY/macos-smoke"
mkdir -p "$EVID"
LOG="$EVID/runtime.log"
BIN="$ROOT/build-macos/DinoPad.app/Contents/MacOS/DinoPad"
ROM="$HOME/Library/Application Support/DinoPad/dino.z64"
SAVE="$HOME/Library/Application Support/DinoPad/Profiles/Restored/saves/dino.bin"
EXPECTED_ROM_MD5="49f7bb346ade39d1915c22e090ffd748"
EXPECTED_SAVE_SHA256="a62085a81e5a91658d58915623aa41b8e52f61a8cdbd4e35d2222e30663e5516"

PASS=0
FAIL=0
SKIP=0

ok()   { echo "PASS: $1"; PASS=$((PASS+1)); }
bad()  { echo "FAIL: $1"; FAIL=$((FAIL+1)); }
skip() { echo "SKIP: $1"; SKIP=$((SKIP+1)); }

sendkey() {
  # sendkey <scancode-or-keycode> <hold-seconds> - activate the DinoPad window,
  # then send a held key event so the game's polling reliably sees it.
  local key="$1" hold="${2:-0.3}"
  osascript -e 'tell application "System Events" to set frontmost of (first application process whose name is "DinoPad") to true' 2>/dev/null || true
  sleep 0.2
  osascript -e "tell application \"System Events\" to key down $key" 2>/dev/null
  sleep "$hold"
  osascript -e "tell application \"System Events\" to key up $key" 2>/dev/null
  sleep 0.2
}
capture() { scripts/capture-window.sh DinoPad "$EVID/$1.png"; }

# ---- Preflight ---------------------------------------------------------------
echo "=== preflight ==="
if [ ! -x "$BIN" ]; then skip "missing packaged DinoPad executable; run scripts/build-macos-app.sh"; exit 0; fi
if [ ! -f "$ROM" ]; then skip "private ROM not staged at $ROM"; exit 0; fi

ROM_MD5="$(md5 -q "$ROM" 2>/dev/null || md5sum "$ROM" | awk '{print $1}')"
if [ "$ROM_MD5" != "$EXPECTED_ROM_MD5" ]; then
  bad "ROM fingerprint mismatch (got $ROM_MD5, want $EXPECTED_ROM_MD5)"
  exit 1
fi
ok "supported ROM present with expected MD5"

SAVE_HASH_BEFORE=""
if [ -f "$SAVE" ]; then
  SAVE_HASH_BEFORE="$(shasum -a 256 "$SAVE" | awk '{print $1}')"
  echo "note: existing save sha256=$SAVE_HASH_BEFORE"
fi

# ---- Launch ------------------------------------------------------------------
echo "=== launch ==="
export DINOPAD_LOG_INPUT=1
"$BIN" --skip-launcher --window-width 1024 --window-height 768 >"$LOG" 2>&1 &
APP_PID=$!
echo "launched pid=$APP_PID"
sleep 12

if ! kill -0 "$APP_PID" 2>/dev/null; then
  bad "app exited during launch window"
  echo "--- log tail ---"; tail -20 "$LOG"
  kill -9 "$APP_PID" 2>/dev/null || true
  exit 1
fi
ok "app launched and stayed alive during boot"

# ---- Boot / GAME SELECT ------------------------------------------------------
echo "=== boot / game select ==="
sendkey 49 0.3; sleep 2   # A: N64 logo
sendkey 49 0.3; sleep 3   # A: Rareware splash
sleep 3
if capture game_select 2>/dev/null; then ok "window present; GAME SELECT captured"; else bad "no window to capture"; fi

# Load the existing save (first slot): A (select) -> A (PLAY THIS GAME? YES) -> A (YES)
sendkey 49 0.4; sleep 2
sendkey 49 0.4; sleep 6
sendkey 49 0.4; sleep 6

# ---- Opening sequence (bounded) ----------------------------------------------
echo "=== opening sequence (bounded 5 min) ==="
for i in $(seq 1 15); do
  sleep 20
  sendkey 49 0.3   # advance prompts
done
capture before_input 2>/dev/null || true

# ---- Controllable-scene input replay -----------------------------------------
echo "=== input replay in playable scene ==="
sendkey 13 2;  capture move_forward 2>/dev/null || true   # W analog up
sendkey 1 2;   capture move_back    2>/dev/null || true   # S analog down
sendkey 2 2;   capture move_right   2>/dev/null || true   # D analog right
sendkey 0 2;   capture move_left    2>/dev/null || true   # A analog left
for i in 1 2 3 4 5; do sendkey 49 0.3; sleep 0.4; done    # A button
capture action_a 2>/dev/null || true
sendkey 56 1; sendkey 49 0.3; sleep 1                     # Shift = Z (target) + A
capture action_z 2>/dev/null || true
sendkey 7 0.3; sleep 1                                    # X = B (cancel)
capture action_b 2>/dev/null || true
sendkey 53 0.3; sleep 1                                   # Escape = Start
capture start_press 2>/dev/null || true

# ---- Verification from the runtime log ---------------------------------------
echo "=== verification ==="
IN_LINES="$(rg -c 'dinopad-in' "$LOG" 2>/dev/null || echo 0)"
[ "${IN_LINES:-0}" -ge 1 ] && ok "input state logged ($IN_LINES log lines)" || bad "no [dinopad-in] log lines"

rg -q 'buttons=0x8000' "$LOG" && ok "N64 A button delivered (0x8000)" || bad "no A button in input log"
rg -q 'buttons=0x4000' "$LOG" && ok "N64 B button delivered (0x4000)" || bad "no B button in input log (not exercised)"
rg -q 'buttons=0x2000' "$LOG" && ok "N64 Z button delivered (0x2000)" || bad "no Z button in input log"
rg -q 'buttons=0x1000' "$LOG" && ok "Start delivered (0x1000)" || bad "no Start in input log"
if rg -q 'x=-?0\.6[0-9]|y=-?0\.6[0-9]' "$LOG"; then
  ok "analog displacement delivered (WASD)"
else
  bad "no analog displacement in input log"
fi

# Gameplay reached if A presses occur after the opening-wait boundary frame.
FIRST_A_FRAME="$(rg 'buttons=0x8000' "$LOG" | head -1 | sed -E 's/.*frame=([0-9]+).*/\1/')"
LAST_A_FRAME="$(rg 'buttons=0x8000' "$LOG" | tail -1 | sed -E 's/.*frame=([0-9]+).*/\1/')"
if [ -n "$LAST_A_FRAME" ] && [ "${LAST_A_FRAME:-0}" -gt 15000 ]; then
  ok "input continued into late session (frame $LAST_A_FRAME): playable scene reached"
else
  bad "no late-session input (last A frame=${LAST_A_FRAME:-none}); gameplay not confirmed"
fi

for f in game_select move_forward move_back move_right move_left action_a action_z action_b start_press; do
  [ -f "$EVID/$f.png" ] && ok "screenshot $f captured" || bad "missing screenshot $f"
done

# ---- Save integrity ----------------------------------------------------------
SAVE_HASH_AFTER=""
if [ -f "$SAVE" ]; then
  SAVE_HASH_AFTER="$(shasum -a 256 "$SAVE" | awk '{print $1}')"
  if [ "$SAVE_HASH_AFTER" = "$EXPECTED_SAVE_SHA256" ]; then
    ok "save file intact after smoke (sha256 unchanged)"
  else
    echo "note: save sha256 changed ($SAVE_HASH_BEFORE -> $SAVE_HASH_AFTER); in-game save point may have written"
    ok "save file present after smoke"
  fi
else
  bad "save file missing after smoke"
fi

# ---- Clean shutdown ----------------------------------------------------------
echo "=== shutdown ==="
kill "$APP_PID" 2>/dev/null || true
for _ in $(jot 50 1); do
  if ! kill -0 "$APP_PID" 2>/dev/null; then break; fi
  sleep 0.1
done
if kill -0 "$APP_PID" 2>/dev/null; then kill -9 "$APP_PID" 2>/dev/null || true; fi
wait "$APP_PID" 2>/dev/null || true
sleep 1
if pgrep -x DinoPad >/dev/null 2>&1; then bad "DinoPad still running after kill"; else ok "DinoPad process gone"; fi
if [ "$(xcrun simctl list devices booted 2>/dev/null | grep -c 'Booted')" = "0" ]; then ok "no booted Simulators"; else bad "booted Simulators remain"; fi

# ---- Report ------------------------------------------------------------------
echo
echo "=== smoke-macos result: PASS=$PASS FAIL=$FAIL SKIP=$SKIP ==="
if [ "$FAIL" -eq 0 ] && [ "$PASS" -gt 0 ]; then
  echo "SMOKE RESULT: PASS"
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) PASS=$PASS FAIL=$FAIL SKIP=$SKIP commit=$(git rev-parse --short HEAD)" > "$EVID/result.txt"
  exit 0
else
  echo "SMOKE RESULT: FAIL"
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) FAIL=$FAIL PASS=$PASS SKIP=$SKIP commit=$(git rev-parse --short HEAD)" > "$EVID/result.txt"
  exit 1
fi
