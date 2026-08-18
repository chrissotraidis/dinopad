#!/usr/bin/env bash
# Prove the audited static restoration package reaches its title and a late
# controllable scene on iPhone Simulator. Run only through runtime-guard.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UDID="${DINOPAD_RUNTIME_UDID:-}"
TARGET="${DINOPAD_RUNTIME_TARGET:-}"
APP="$ROOT/build-ios-simulator/Release-iphonesimulator/DinoPad.app"
BUNDLE_ID="com.chrissotraidis.dinopad"
ROM="${DINOPAD_ROM_PATH:-$ROOT/ref/DINO/rom}"
SAVE_FIXTURE="${DINOPAD_SAVE_PATH:-$HOME/Library/Application Support/DinoPad/saves/dino.bin}"
EVIDENCE_DIR="${DINOPAD_IOS_RESTORATION_EVIDENCE_DIR:-$ROOT/.goal-loop/smoke-ios-restoration}"
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

[[ "$TARGET" == "iphone-simulator" || "$TARGET" == "ipad-simulator" ]] || {
  echo "ERROR: smoke-ios-restoration.sh requires an iOS Simulator guard" >&2; exit 2;
}
[[ -n "$UDID" ]] || { echo "ERROR: missing guarded Simulator UDID" >&2; exit 2; }
[[ -x "$APP/DinoPad" ]] || { echo "ERROR: missing Simulator app" >&2; exit 1; }
[[ -f "$ROM" ]] || { echo "ERROR: private supported ROM missing" >&2; exit 1; }
[[ -f "$SAVE_FIXTURE" ]] || { echo "ERROR: private gameplay save fixture missing" >&2; exit 1; }
[[ "$(stat -f '%z' "$SAVE_FIXTURE")" -eq 131072 ]] || {
  echo "ERROR: private gameplay save fixture has the wrong size" >&2; exit 1;
}
strings -a "$SAVE_FIXTURE" | grep -q '^AAAAA$' || {
  echo "ERROR: private gameplay save fixture does not contain the proven AAAAA slot" >&2; exit 1;
}

PACKAGE="$APP/dinomod_restoration_data.nrm"
GENERATED_PACKAGE="$ROOT/generated/restoration/dinomod_restoration_data.nrm"
[[ -f "$PACKAGE" && -f "$GENERATED_PACKAGE" ]] || {
  echo "ERROR: audited restoration package is missing" >&2; exit 1;
}
cmp -s "$PACKAGE" "$GENERATED_PACKAGE" || {
  echo "ERROR: bundled restoration package differs from generated audit input" >&2; exit 1;
}
[[ "$(unzip -Z1 "$PACKAGE")" == $'mod.json\nmod_syms.bin\nmod_binary.bin' ]] || {
  echo "ERROR: restoration package contains unexpected members" >&2; exit 1;
}
if find "$APP" -type f \( -iname '*.z64' -o -iname '*.v64' -o -iname '*.n64' -o -iname '*.rom' \) -print -quit | grep -q .; then
  echo "ERROR: Simulator bundle contains a ROM" >&2; exit 1
fi

mkdir -p "$EVIDENCE_DIR"
crashes_before="$(find "$REPORTS" -type f -name 'DinoPad-*.ips' 2>/dev/null | wc -l | tr -d ' ')"
xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b
xcrun simctl uninstall "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP"
DATA_CONTAINER="$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data)"
DATA_ROOT="$DATA_CONTAINER/Library/Application Support/DinoPad"
mkdir -p "$DATA_ROOT/Profiles/Restored/saves" "$DATA_ROOT/mods"
python3 "$ROOT/tools/normalize_rom.py" "$ROM" --out "$DATA_ROOT/dino.z64" >/dev/null
cp "$SAVE_FIXTURE" "$DATA_ROOT/Profiles/Restored/saves/dino.bin"
printf 'must-not-be-opened\n' > "$DATA_ROOT/mods/should-not-open.nrm"

export SIMCTL_CHILD_DINOPAD_HOME_AUTOMATION_SEQUENCE=restored
export SIMCTL_CHILD_DINOPAD_LOG_INPUT=1

# Phase 1: skip the two startup splashes and capture inside the explicit
# six-second restored-title window before the next replay input.
export SIMCTL_CHILD_DINOPAD_RUN_GAMEPLAY_SMOKE=1
xcrun simctl launch --console --terminate-running-process "$UDID" "$BUNDLE_ID" \
  >"$EVIDENCE_DIR/title-runtime.log" 2>&1 &
CONSOLE_PID=$!
for _ in {1..60}; do
  grep -q 'Static restoration dispatch enabled .*no runtime code writes' \
    "$EVIDENCE_DIR/title-runtime.log" 2>/dev/null && break
  if ! kill -0 "$CONSOLE_PID" 2>/dev/null; then break; fi
  sleep 0.5
done
grep -q 'Static restoration dispatch enabled .*no runtime code writes' \
  "$EVIDENCE_DIR/title-runtime.log" || { echo "ERROR: Restored title launch failed" >&2; exit 1; }
for _ in {1..80}; do
  grep -q '\[dinopad-restoration-test\] Restored title capture boundary' \
    "$EVIDENCE_DIR/title-runtime.log" 2>/dev/null && break
  if ! kill -0 "$CONSOLE_PID" 2>/dev/null; then break; fi
  sleep 0.5
done
grep -q '\[dinopad-restoration-test\] Restored title capture boundary' \
  "$EVIDENCE_DIR/title-runtime.log" || { echo "ERROR: restored title replay did not reach its capture boundary" >&2; exit 1; }
pgrep -x DinoPad >/dev/null || { echo "ERROR: Restored title process exited" >&2; exit 1; }
xcrun simctl io "$UDID" screenshot "$EVIDENCE_DIR/restored-title.png"
stop_app
unset SIMCTL_CHILD_DINOPAD_RUN_GAMEPLAY_SMOKE

# Phase 2: follow the proven save/opening sequence and inject movement only
# after the late-session boundary.
export SIMCTL_CHILD_DINOPAD_RUN_GAMEPLAY_SMOKE=1
xcrun simctl launch --console --terminate-running-process "$UDID" "$BUNDLE_ID" \
  >"$EVIDENCE_DIR/gameplay-runtime.log" 2>&1 &
CONSOLE_PID=$!
for _ in {1..1000}; do
  grep -q '\[dinopad-restoration-test\] Late-session input replay completed' \
    "$EVIDENCE_DIR/gameplay-runtime.log" 2>/dev/null && break
  if ! kill -0 "$CONSOLE_PID" 2>/dev/null; then break; fi
  sleep 0.5
done
grep -q '\[dinopad-restoration-test\] Late-session input replay completed' \
  "$EVIDENCE_DIR/gameplay-runtime.log" || {
    echo "ERROR: bounded boot-to-gameplay replay did not complete" >&2; exit 1;
  }
pgrep -x DinoPad >/dev/null || { echo "ERROR: gameplay process exited" >&2; exit 1; }
xcrun simctl io "$UDID" screenshot "$EVIDENCE_DIR/restored-gameplay.png"
stop_app
unset SIMCTL_CHILD_DINOPAD_RUN_GAMEPLAY_SMOKE

LOG="$EVIDENCE_DIR/gameplay-runtime.log"
for marker in \
  'Bundled restoration data registered' \
  'Using statically linked code for mod dinomod_enhanced' \
  'Static restoration dispatch enabled'; do
  grep -q "$marker" "$LOG" || { echo "ERROR: missing runtime marker: $marker" >&2; exit 1; }
done
if grep -q 'should-not-open' "$LOG"; then
  echo "ERROR: iOS scanned a user-controlled mod package" >&2; exit 1
fi
last_input_frame="$(sed -n 's/.*\[dinopad-in\] frame=\([0-9][0-9]*\).*/\1/p' "$LOG" | tail -1)"
[[ -n "$last_input_frame" && "$last_input_frame" -gt 15000 ]] || {
  echo "ERROR: late-session input boundary not reached (frame=${last_input_frame:-none})" >&2; exit 1;
}
grep -Eq '\[dinopad-in\].*y=0\.[6-9][0-9]' "$LOG" || {
  echo "ERROR: gameplay analog movement did not reach the N64 poll" >&2; exit 1;
}
grep -q '\[dinopad-in\].*buttons=0x8000' "$LOG" || {
  echo "ERROR: gameplay A input did not reach the N64 poll" >&2; exit 1;
}

crashes_after="$(find "$REPORTS" -type f -name 'DinoPad-*.ips' 2>/dev/null | wc -l | tr -d ' ')"
[[ "$crashes_after" == "$crashes_before" ]] || { echo "ERROR: new DinoPad crash report detected" >&2; exit 1; }

printf 'IOS RESTORATION REPLAY: PASS (audited non-code package; static no-write dispatch; restored-title candidate; late input candidate frame %s; writable mods ignored; ROM-free; no crash; screenshots require visual acceptance)\n' \
  "$last_input_frame" | tee "$EVIDENCE_DIR/result.txt"
