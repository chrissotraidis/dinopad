#!/usr/bin/env bash
# Bounded iOS Simulator input & lifecycle smoke. Run through runtime-guard.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UDID="${DINOPAD_RUNTIME_UDID:-}"
TARGET="${DINOPAD_RUNTIME_TARGET:-}"
APP="$ROOT/build-ios-simulator/Release-iphonesimulator/DinoPad.app"
RESTORATION_PACKAGE="$APP/dinomod_restoration_data.nrm"
GENERATED_RESTORATION_PACKAGE="$ROOT/generated/restoration/dinomod_restoration_data.nrm"
BUNDLE_ID="com.chrissotraidis.dinopad"
ROM="${DINOPAD_ROM_PATH:-$ROOT/ref/DINO/rom}"
EVIDENCE_DIR="${DINOPAD_IOS_EVIDENCE_DIR:-$ROOT/.goal-loop/smoke-ios}"
DURATION="${DINOPAD_IOS_SMOKE_SECONDS:-8}"
REPORTS="$HOME/Library/Logs/DiagnosticReports"
CONSOLE_PID=""

cleanup() {
  trap - EXIT INT TERM
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
trap cleanup EXIT INT TERM

if [[ "$TARGET" != "iphone-simulator" && "$TARGET" != "ipad-simulator" ]]; then
  echo "ERROR: smoke-ios.sh must run through runtime-guard.sh for a Simulator" >&2
  exit 2
fi
[[ -n "$UDID" ]] || { echo "ERROR: runtime guard did not provide a Simulator UDID" >&2; exit 2; }
[[ -x "$APP/DinoPad" ]] || { echo "ERROR: missing Simulator app; run scripts/build-ios-simulator.sh" >&2; exit 1; }
[[ -f "$ROM" ]] || { echo "ERROR: private supported ROM missing (set DINOPAD_ROM_PATH)" >&2; exit 1; }
[[ -f "$RESTORATION_PACKAGE" ]] || { echo "ERROR: bundled restoration data is missing" >&2; exit 1; }
[[ -f "$GENERATED_RESTORATION_PACKAGE" ]] || { echo "ERROR: generated restoration data is missing" >&2; exit 1; }
[[ "$DURATION" =~ ^[0-9]+$ ]] && (( DURATION > 0 )) || { echo "ERROR: invalid smoke duration" >&2; exit 2; }

cmp -s "$RESTORATION_PACKAGE" "$GENERATED_RESTORATION_PACKAGE" || {
  echo "ERROR: bundled restoration data differs from the audited generated package" >&2
  exit 1
}
[[ "$(unzip -Z1 "$RESTORATION_PACKAGE")" == $'mod.json\nmod_syms.bin\nmod_binary.bin' ]] || {
  echo "ERROR: restoration package contains unexpected members" >&2
  exit 1
}

if find "$APP" -type f \( -iname '*.z64' -o -iname '*.v64' -o -iname '*.n64' -o -iname '*.rom' \) -print -quit | grep -q .; then
  echo "ERROR: Simulator bundle contains a ROM" >&2
  exit 1
fi
python3 "$ROOT/tools/normalize_rom.py" "$ROM" >/dev/null
mkdir -p "$EVIDENCE_DIR"

crashes_before="$(find "$REPORTS" -type f -name 'DinoPad-*.ips' 2>/dev/null | wc -l | tr -d ' ')"
xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b
xcrun simctl install "$UDID" "$APP"
DATA_CONTAINER="$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data)"
mkdir -p "$DATA_CONTAINER/Library/Application Support/DinoPad"
python3 "$ROOT/tools/normalize_rom.py" "$ROM"   --out "$DATA_CONTAINER/Library/Application Support/DinoPad/dino.z64" >/dev/null
# An invalid writable package proves iOS never scans user-controlled mod files.
mkdir -p "$DATA_CONTAINER/Library/Application Support/DinoPad/mods"
printf 'must-not-be-opened\n' > "$DATA_CONTAINER/Library/Application Support/DinoPad/mods/should-not-open.nrm"

export SIMCTL_CHILD_DINOPAD_LOG_INPUT=1
export SIMCTL_CHILD_DINOPAD_RUN_INPUT_SMOKE=1

export SIMCTL_CHILD_DINOPAD_HOME_AUTOMATION_SEQUENCE=restored
xcrun simctl launch --console --terminate-running-process "$UDID" "$BUNDLE_ID"   >"$EVIDENCE_DIR/runtime.log" 2>&1 &
CONSOLE_PID=$!

# A restoration-enabled cold launch has to copy and map a sizeable bundled
# data package. Wait for the runtime marker before starting the bounded live
# interval instead of treating normal Simulator startup latency as a crash.
for _ in {1..60}; do
  if grep -q 'DinoPad profile: Restored (namespace=Profiles/Restored)' \
      "$EVIDENCE_DIR/runtime.log" 2>/dev/null; then
    break
  fi
  if ! kill -0 "$CONSOLE_PID" 2>/dev/null; then
    break
  fi
  sleep 0.5
done
grep -q 'DinoPad profile: Restored (namespace=Profiles/Restored)' \
  "$EVIDENCE_DIR/runtime.log" || {
    echo "ERROR: DinoPad did not finish its cold launch within 30s" >&2
    exit 1
  }
sleep "$DURATION"

if ! pgrep -x DinoPad >/dev/null; then
  echo "ERROR: DinoPad did not remain alive for ${DURATION}s" >&2
  cleanup
  exit 1
fi
xcrun simctl io "$UDID" screenshot "$EVIDENCE_DIR/screen.png"
cleanup

crashes_after="$(find "$REPORTS" -type f -name 'DinoPad-*.ips' 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$crashes_after" != "$crashes_before" ]]; then
  echo "ERROR: new DinoPad crash report detected" >&2
  exit 1
fi

LOG="$EVIDENCE_DIR/runtime.log"
[[ -f "$LOG" ]] || { echo "ERROR: runtime log missing" >&2; exit 1; }

grep -q 'Bundled restoration data registered .*filesystem mods disabled' "$LOG" || {
  echo "ERROR: bundled restoration data registration missing" >&2; exit 1;
}
grep -q 'Using statically linked code for mod dinomod_enhanced' "$LOG" || {
  echo "ERROR: static restoration code was not selected" >&2; exit 1;
}
grep -q 'Static restoration dispatch enabled .*no runtime code writes' "$LOG" || {
  echo "ERROR: no-write static dispatch marker missing" >&2; exit 1;
}
if grep -q 'should-not-open' "$LOG"; then
  echo "ERROR: iOS scanned a user-controlled mod package" >&2
  exit 1
fi

echo "Verifying input test suite results from runtime log..."

# Check suite completion
grep -q "\[dinopad-touch-test\] ALL 8 INPUT/LIFECYCLE TEST SUITES PASSED" "$LOG" || {
  echo "ERROR: input/lifecycle test suite did not report full completion in $LOG" >&2
  exit 1
}
if grep -q "\[dinopad-touch-test\] FAIL:" "$LOG"; then
  echo "ERROR: input/lifecycle test suite reported a failed assertion in $LOG" >&2
  exit 1
fi

# Check digital buttons
for btn in a b z start d_up d_down d_left d_right l r c_up c_down c_left c_right; do
  grep -q "\[dinopad-touch-test\] PASS: button $btn mask=" "$LOG" || {
    echo "ERROR: digital button $btn verification missing in $LOG" >&2
    exit 1
  }
done

# Check analog cardinal directions
for dir in UP DOWN LEFT RIGHT; do
  grep -q "\[dinopad-touch-test\] PASS: analog $dir x=" "$LOG" || {
    echo "ERROR: analog direction $dir verification missing in $LOG" >&2
    exit 1
  }
  grep -q "\[dinopad-touch-test\] PASS: analog $dir return to zero" "$LOG" || {
    echo "ERROR: analog direction $dir return to zero missing in $LOG" >&2
    exit 1
  }
done

# Check multi-touch
grep -q "\[dinopad-touch-test\] PASS: simultaneous multi-touch stick+A+B+Z" "$LOG" || {
  echo "ERROR: multi-touch verification missing in $LOG" >&2
  exit 1
}

# Check menu open/dismiss
grep -q "\[dinopad-touch-test\] PASS: menu presentation cleared held input" "$LOG" || {
  echo "ERROR: menu presentation input clearing missing in $LOG" >&2
  exit 1
}
grep -q "\[dinopad-touch-test\] PASS: menu dismissed and gameplay controls restored" "$LOG" || {
  echo "ERROR: menu dismissal restoration missing in $LOG" >&2
  exit 1
}

# Check app lifecycle
grep -q "\[dinopad-touch-test\] PASS: background notification cleared held input" "$LOG" || {
  echo "ERROR: background lifecycle input clearing missing in $LOG" >&2
  exit 1
}
grep -q "\[dinopad-touch-test\] PASS: foreground notification resumed cleanly" "$LOG" || {
  echo "ERROR: foreground lifecycle resume missing in $LOG" >&2
  exit 1
}

# Check controller handoff
grep -q "\[dinopad-touch-test\] PASS: simulator synthetic controller exception verified" "$LOG" || {
  echo "ERROR: simulator synthetic controller exception missing in $LOG" >&2
  exit 1
}
grep -q "\[dinopad-touch-test\] PASS: controller connected state hid touch input" "$LOG" || {
  echo "ERROR: controller connected hiding missing in $LOG" >&2
  exit 1
}
grep -q "\[dinopad-touch-test\] PASS: controller disconnected state restored touch controls" "$LOG" || {
  echo "ERROR: controller disconnected restoration missing in $LOG" >&2
  exit 1
}

# Check optional hold-to-lock targeting behavior and its disable switch.
grep -q "\[dinopad-touch-test\] PASS: held Z locked after release and next tap unlocked it" "$LOG" || {
  echo "ERROR: Z targeting lock toggle verification missing in $LOG" >&2
  exit 1
}
grep -q "\[dinopad-touch-test\] PASS: disabled Z hold did not latch" "$LOG" || {
  echo "ERROR: disabled Z targeting lock verification missing in $LOG" >&2
  exit 1
}

# Check actual game-loop N64 poll logging
grep -q "\[dinopad-in\]" "$LOG" || {
  echo "ERROR: [dinopad-in] game-loop poll entries missing in $LOG" >&2
  exit 1
}

printf 'IOS INPUT/LIFECYCLE RESULT: PASS (arm64 app; ROM-free bundle; live %ss; all 14 digital masks; 4 analog directions; multi-touch; menu lifecycle; app lifecycle; controller handoff; Z targeting lock; screenshot; no crash)
' "$DURATION"   | tee "$EVIDENCE_DIR/result.txt"
