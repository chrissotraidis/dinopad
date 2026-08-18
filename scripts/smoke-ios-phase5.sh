#!/usr/bin/env bash
# Final iPhone Simulator Phase 5 gate: ten-minute Restored gameplay plus a
# same-install save relaunch back to controllable gameplay.
# Run only through runtime-guard.sh with one iPhone Simulator.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UDID="${DINOPAD_RUNTIME_UDID:-}"
TARGET="${DINOPAD_RUNTIME_TARGET:-}"
APP="$ROOT/build-ios-simulator/Release-iphonesimulator/DinoPad.app"
BUNDLE_ID="com.chrissotraidis.dinopad"
ROM="${DINOPAD_ROM_PATH:-$ROOT/ref/DINO/rom}"
SAVE_FIXTURE="${DINOPAD_SAVE_PATH:-$HOME/Library/Application Support/DinoPad/saves/dino.bin}"
EVIDENCE_DIR="${DINOPAD_IOS_PHASE5_EVIDENCE_DIR:-$ROOT/.goal-loop/smoke-ios-phase5}"
REPORTS="$HOME/Library/Logs/DiagnosticReports"
CONSOLE_PID=""

stop_app() {
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  if [[ -n "$CONSOLE_PID" ]]; then
    kill -TERM "$CONSOLE_PID" 2>/dev/null || true
    for _ in {1..20}; do
      if ! kill -0 "$CONSOLE_PID" 2>/dev/null; then break; fi
      sleep 0.1
    done
    kill -9 "$CONSOLE_PID" 2>/dev/null || true
    wait "$CONSOLE_PID" 2>/dev/null || true
    CONSOLE_PID=""
  fi
}

cleanup() {
  trap - EXIT INT TERM
  stop_app
}
trap cleanup EXIT INT TERM

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

hash_file() {
  shasum -a 256 "$1" | awk '{print $1}'
}

wait_for_marker() {
  local log="$1" marker="$2" attempts="$3" description="$4"
  for ((attempt = 0; attempt < attempts; attempt++)); do
    grep -q "$marker" "$log" 2>/dev/null && return 0
    kill -0 "$CONSOLE_PID" 2>/dev/null || break
    sleep 0.5
  done
  fail "$description"
}

[[ "$TARGET" == "iphone-simulator" || "$TARGET" == "ipad-simulator" ]] ||
  fail "smoke-ios-phase5.sh requires an iOS Simulator guard"
[[ -n "$UDID" ]] || fail "runtime guard did not provide a UDID"
[[ -x "$APP/DinoPad" ]] || fail "missing Simulator app"
[[ -f "$ROM" ]] || fail "private supported ROM missing"
[[ -f "$SAVE_FIXTURE" ]] || fail "private game-produced save fixture missing"
[[ "$(stat -f '%z' "$SAVE_FIXTURE")" -eq 131072 ]] ||
  fail "private game-produced save fixture has the wrong size"
strings -a "$SAVE_FIXTURE" | grep -q '^AAAAA$' ||
  fail "private save fixture does not contain the proven game-created AAAAA slot"
[[ "$(lipo -archs "$APP/DinoPad")" == "arm64" ]] ||
  fail "Simulator executable is not arm64-only"
if find "$APP" -type f \( -iname '*.z64' -o -iname '*.v64' -o -iname '*.n64' -o -iname '*.rom' \) -print -quit | grep -q .; then
  fail "Simulator bundle contains a ROM"
fi

mkdir -p "$EVIDENCE_DIR"
find "$EVIDENCE_DIR" -maxdepth 1 -type f -delete
crashes_before="$(find "$REPORTS" -type f -name 'DinoPad-*.ips' 2>/dev/null | wc -l | tr -d ' ')"

xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b
xcrun simctl uninstall "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP"
DATA_CONTAINER="$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data)"
DATA_ROOT="$DATA_CONTAINER/Library/Application Support/DinoPad"
RESTORED_SAVE="$DATA_ROOT/Profiles/Restored/saves/dino.bin"
PROTOTYPE_SAVE="$DATA_ROOT/Profiles/Prototype/saves/dino.bin"
mkdir -p "$(dirname "$RESTORED_SAVE")" "$(dirname "$PROTOTYPE_SAVE")"
python3 "$ROOT/tools/normalize_rom.py" "$ROM" --out "$DATA_ROOT/dino.z64" >/dev/null
cp "$SAVE_FIXTURE" "$RESTORED_SAVE"
dd if=/dev/zero of="$PROTOTYPE_SAVE" bs=131072 count=1 status=none
printf 'PROTOTYPE-PHASE5-SENTINEL' | dd of="$PROTOTYPE_SAVE" conv=notrunc status=none

seed_hash="$(hash_file "$RESTORED_SAVE")"
prototype_hash="$(hash_file "$PROTOTYPE_SAVE")"

export SIMCTL_CHILD_DINOPAD_HOME_AUTOMATION_SEQUENCE=restored
export SIMCTL_CHILD_DINOPAD_LOG_INPUT=1
export SIMCTL_CHILD_DINOPAD_RUN_GAMEPLAY_SMOKE=1

# Launch 1: reach controllable Restored gameplay, then remain live for at least
# ten wall-clock minutes from process launch.
FIRST_LOG="$EVIDENCE_DIR/ten-minute-runtime.log"
first_started="$(date +%s)"
xcrun simctl launch --console --terminate-running-process "$UDID" "$BUNDLE_ID" \
  >"$FIRST_LOG" 2>&1 &
CONSOLE_PID=$!
wait_for_marker "$FIRST_LOG" \
  '\[dinopad-restoration-test\] Late-session input replay completed' 1000 \
  "first launch did not reach controllable Restored gameplay"

while (( $(date +%s) - first_started < 600 )); do
  kill -0 "$CONSOLE_PID" 2>/dev/null || fail "app exited before ten minutes"
  sleep 1
done
first_duration="$(( $(date +%s) - first_started ))"
kill -0 "$CONSOLE_PID" 2>/dev/null || fail "app was not live at the ten-minute boundary"
xcrun simctl io "$UDID" screenshot "$EVIDENCE_DIR/ten-minute-gameplay.png"
stop_app

[[ -f "$RESTORED_SAVE" && "$(stat -f '%z' "$RESTORED_SAVE")" -eq 131072 ]] ||
  fail "Restored save missing or malformed after ten-minute launch"
after_first_hash="$(hash_file "$RESTORED_SAVE")"
strings -a "$RESTORED_SAVE" | grep -q '^AAAAA$' ||
  fail "game-created AAAAA slot was not preserved after ten-minute launch"
[[ "$(hash_file "$PROTOTYPE_SAVE")" == "$prototype_hash" ]] ||
  fail "Restored launch modified the Prototype save namespace"

# Launch 2: retain the same installed app/data container. The existing replay
# selects the persisted AAAAA slot; reaching late controllable gameplay proves
# the FlashRAM image loaded after process relaunch. The full input/lifecycle
# harness runs before the replay starts and is complete before its first A.
SECOND_LOG="$EVIDENCE_DIR/relaunch-runtime.log"
export SIMCTL_CHILD_DINOPAD_RUN_INPUT_SMOKE=1
xcrun simctl launch --console --terminate-running-process "$UDID" "$BUNDLE_ID" \
  >"$SECOND_LOG" 2>&1 &
CONSOLE_PID=$!
wait_for_marker "$SECOND_LOG" \
  'ALL 7 INPUT/LIFECYCLE TEST SUITES PASSED' 240 \
  "relaunch input/lifecycle matrix did not complete"
wait_for_marker "$SECOND_LOG" \
  '\[dinopad-restoration-test\] Late-session input replay completed' 1000 \
  "persisted save did not relaunch into controllable gameplay"
xcrun simctl io "$UDID" screenshot "$EVIDENCE_DIR/relaunch-gameplay.png"
stop_app

after_relaunch_hash="$(hash_file "$RESTORED_SAVE")"
[[ "$after_relaunch_hash" == "$after_first_hash" ]] ||
  fail "Restored save changed unexpectedly during relaunch verification"
[[ "$(hash_file "$PROTOTYPE_SAVE")" == "$prototype_hash" ]] ||
  fail "relaunch modified the Prototype save namespace"

for log in "$FIRST_LOG" "$SECOND_LOG"; do
  for marker in \
    'Bundled restoration data registered' \
    'Using statically linked code for mod dinomod_enhanced' \
    'Static restoration dispatch enabled'; do
    grep -q "$marker" "$log" || fail "missing runtime marker: $marker"
  done
  if grep -Eq 'Segmentation fault|Abort trap|Assertion failed|fatal renderer|EXC_BAD_ACCESS' "$log"; then
    fail "fatal runtime marker found in $(basename "$log")"
  fi
done

last_input_frame="$(sed -n 's/.*\[dinopad-in\] frame=\([0-9][0-9]*\).*/\1/p' "$SECOND_LOG" | tail -1)"
[[ -n "$last_input_frame" && "$last_input_frame" -gt 15000 ]] ||
  fail "relaunch did not deliver late gameplay input"
grep -q '\[dinopad-in\].*buttons=0x8000' "$SECOND_LOG" ||
  fail "relaunch gameplay A input did not reach the N64 poll"
grep -Eq '\[dinopad-in\].*y=0\.[6-9][0-9]' "$SECOND_LOG" ||
  fail "relaunch gameplay analog input did not reach the N64 poll"

LATEST_LOG="$DATA_ROOT/Logs/dinopad-latest.log"
PREVIOUS_LOG="$DATA_ROOT/Logs/dinopad-previous.log"
[[ -f "$LATEST_LOG" && "$(stat -f '%z' "$LATEST_LOG")" -le $((4 * 1024 * 1024)) ]] ||
  fail "bounded current diagnostics log missing or oversized"
[[ ! -f "$PREVIOUS_LOG" || "$(stat -f '%z' "$PREVIOUS_LOG")" -le $((4 * 1024 * 1024)) ]] ||
  fail "bounded previous diagnostics log is oversized"

crashes_after="$(find "$REPORTS" -type f -name 'DinoPad-*.ips' 2>/dev/null | wc -l | tr -d ' ')"
[[ "$crashes_after" == "$crashes_before" ]] || fail "new DinoPad crash report detected"

{
  printf 'IOS PHASE 5 RESULT: PASS\n'
  printf 'first_launch_duration_seconds=%s\n' "$first_duration"
  printf 'restored_seed_sha256=%s\n' "$seed_hash"
  printf 'restored_after_ten_minutes_sha256=%s\n' "$after_first_hash"
  printf 'restored_after_relaunch_sha256=%s\n' "$after_relaunch_hash"
  printf 'prototype_sentinel_sha256=%s\n' "$prototype_hash"
  printf 'relaunch_late_input_frame=%s\n' "$last_input_frame"
  printf 'proof=game-produced AAAAA save remained valid, survived process relaunch, and loaded into controllable Restored gameplay\n'
  printf 'cleanup=runtime guard must confirm zero DinoPad processes and zero booted Simulators\n'
} | tee "$EVIDENCE_DIR/result.txt"
