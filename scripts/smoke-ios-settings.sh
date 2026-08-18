#!/usr/bin/env bash
# Two-launch iOS native-settings persistence, live-apply, and input-modal smoke.
# Run only through runtime-guard.sh with one Simulator.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UDID="${DINOPAD_RUNTIME_UDID:-}"
TARGET="${DINOPAD_RUNTIME_TARGET:-}"
APP="$ROOT/build-ios-simulator/Release-iphonesimulator/DinoPad.app"
BUNDLE_ID="com.chrissotraidis.dinopad"
ROM="${DINOPAD_ROM_PATH:-$ROOT/ref/DINO/rom}"
EVIDENCE_DIR="${DINOPAD_IOS_SETTINGS_EVIDENCE_DIR:-$ROOT/.goal-loop/smoke-ios-settings}"
REPORTS="$HOME/Library/Logs/DiagnosticReports"
CONSOLE_PID=""

stop_launch() {
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
  stop_launch
}
trap cleanup EXIT INT TERM

if [[ "$TARGET" != "iphone-simulator" ]]; then
  echo "ERROR: smoke-ios-settings.sh requires the iPhone Simulator guard" >&2
  exit 2
fi
[[ -n "$UDID" ]] || { echo "ERROR: runtime guard did not provide a Simulator UDID" >&2; exit 2; }
[[ -x "$APP/DinoPad" ]] || { echo "ERROR: missing Simulator app; run scripts/build-ios-simulator.sh" >&2; exit 1; }
[[ -f "$ROM" ]] || { echo "ERROR: private supported ROM missing (set DINOPAD_ROM_PATH)" >&2; exit 1; }

if find "$APP" -type f \( -iname '*.z64' -o -iname '*.v64' -o -iname '*.n64' -o -iname '*.rom' \) -print -quit | grep -q .; then
  echo "ERROR: Simulator bundle contains a ROM" >&2
  exit 1
fi
[[ "$(lipo -archs "$APP/DinoPad")" == "arm64" ]] || {
  echo "ERROR: Simulator executable is not arm64-only" >&2
  exit 1
}

mkdir -p "$EVIDENCE_DIR"
rm -f "$EVIDENCE_DIR"/*.log "$EVIDENCE_DIR"/*.png "$EVIDENCE_DIR"/*.json "$EVIDENCE_DIR/result.txt"
crashes_before="$(find "$REPORTS" -type f -name 'DinoPad-*.ips' 2>/dev/null | wc -l | tr -d ' ')"

xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b
xcrun simctl uninstall "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP"
DATA_CONTAINER="$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data)"
DATA_ROOT="$DATA_CONTAINER/Library/Application Support/DinoPad"
RESTORED_ROOT="$DATA_ROOT/Profiles/Restored"
PROTOTYPE_ROOT="$DATA_ROOT/Profiles/Prototype"
mkdir -p "$RESTORED_ROOT" "$PROTOTYPE_ROOT"
python3 "$ROOT/tools/normalize_rom.py" "$ROM" --out "$DATA_ROOT/dino.z64" >/dev/null
printf '%s\n' 'prototype-settings-must-remain-untouched' > "$PROTOTYPE_ROOT/settings-isolation.txt"
prototype_before="$(shasum -a 256 "$PROTOTYPE_ROOT/settings-isolation.txt" | awk '{print $1}')"

export SIMCTL_CHILD_DINOPAD_HOME_AUTOMATION_SEQUENCE=restored
export SIMCTL_CHILD_DINOPAD_RUN_SETTINGS_SMOKE=1
export SIMCTL_CHILD_DINOPAD_SETTINGS_SMOKE_PHASE=edit
xcrun simctl launch --console --terminate-running-process "$UDID" "$BUNDLE_ID" \
  >"$EVIDENCE_DIR/edit.log" 2>&1 &
CONSOLE_PID=$!
for _ in {1..100}; do
  grep -q 'EDIT VALUES APPLIED' "$EVIDENCE_DIR/edit.log" 2>/dev/null && break
  kill -0 "$CONSOLE_PID" 2>/dev/null || break
  sleep 0.4
done
grep -q 'EDIT VALUES APPLIED' "$EVIDENCE_DIR/edit.log" || {
  echo "ERROR: native settings edit values were not applied" >&2
  exit 1
}
xcrun simctl io "$UDID" screenshot "$EVIDENCE_DIR/settings-edited.png"
for _ in {1..40}; do
  grep -q 'EDIT PHASE PASSED' "$EVIDENCE_DIR/edit.log" 2>/dev/null && break
  sleep 0.25
done
grep -q 'EDIT PHASE PASSED' "$EVIDENCE_DIR/edit.log" || {
  echo "ERROR: native settings edit phase did not complete" >&2
  exit 1
}
if grep -q '\[dinopad-settings-test\] FAIL:' "$EVIDENCE_DIR/edit.log"; then
  echo "ERROR: native settings edit phase reported a failure" >&2
  exit 1
fi
stop_launch

python3 - "$RESTORED_ROOT" "$EVIDENCE_DIR" <<'PY'
import json
import pathlib
import shutil
import sys

root = pathlib.Path(sys.argv[1])
evidence = pathlib.Path(sys.argv[2])
sound = json.loads((root / "sound.json").read_text())
graphics = json.loads((root / "graphics.json").read_text())
assert sound["main_volume"] == 37, sound
assert graphics["res_option"] == "Original2x", graphics
assert graphics["ar_option"] == "Expand", graphics
assert graphics["rr_option"] == "Display", graphics
assert graphics["hr_option"] == "Full", graphics
shutil.copy2(root / "sound.json", evidence / "edited-sound.json")
shutil.copy2(root / "graphics.json", evidence / "edited-graphics.json")
PY

export SIMCTL_CHILD_DINOPAD_SETTINGS_SMOKE_PHASE=verify
xcrun simctl launch --console --terminate-running-process "$UDID" "$BUNDLE_ID" \
  >"$EVIDENCE_DIR/verify.log" 2>&1 &
CONSOLE_PID=$!
for _ in {1..100}; do
  grep -q 'RELAUNCH VALUES VERIFIED' "$EVIDENCE_DIR/verify.log" 2>/dev/null && break
  kill -0 "$CONSOLE_PID" 2>/dev/null || break
  sleep 0.4
done
grep -q 'RELAUNCH VALUES VERIFIED' "$EVIDENCE_DIR/verify.log" || {
  echo "ERROR: native settings values did not survive relaunch" >&2
  exit 1
}
xcrun simctl io "$UDID" screenshot "$EVIDENCE_DIR/settings-reloaded.png"
for _ in {1..40}; do
  grep -q 'ALL SETTINGS TESTS PASSED' "$EVIDENCE_DIR/verify.log" 2>/dev/null && break
  sleep 0.25
done
grep -q 'ALL SETTINGS TESTS PASSED' "$EVIDENCE_DIR/verify.log" || {
  echo "ERROR: native settings verification phase did not complete" >&2
  exit 1
}
if grep -q '\[dinopad-settings-test\] FAIL:' "$EVIDENCE_DIR/verify.log"; then
  echo "ERROR: native settings verification phase reported a failure" >&2
  exit 1
fi
stop_launch

prototype_after="$(shasum -a 256 "$PROTOTYPE_ROOT/settings-isolation.txt" | awk '{print $1}')"
[[ "$prototype_after" == "$prototype_before" ]] || {
  echo "ERROR: Restored settings flow modified the Prototype profile" >&2
  exit 1
}
python3 - "$RESTORED_ROOT" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
sound = json.loads((root / "sound.json").read_text())
graphics = json.loads((root / "graphics.json").read_text())
assert sound["main_volume"] == 100, sound
assert graphics["res_option"] == "Auto", graphics
assert graphics["ar_option"] == "Expand", graphics
assert graphics["rr_option"] == "Original", graphics
assert graphics["hr_option"] == "Clamp16x9", graphics
PY

crashes_after="$(find "$REPORTS" -type f -name 'DinoPad-*.ips' 2>/dev/null | wc -l | tr -d ' ')"
[[ "$crashes_after" == "$crashes_before" ]] || {
  echo "ERROR: new DinoPad crash report detected" >&2
  exit 1
}

for marker in \
  'modal input suppression verified' \
  'invalid native values clamped safely' \
  'EDIT VALUES APPLIED' \
  'EDIT PHASE PASSED'; do
  grep -q "$marker" "$EVIDENCE_DIR/edit.log" || {
    echo "ERROR: missing edit marker: $marker" >&2
    exit 1
  }
done
for marker in \
  'modal input suppression verified' \
  'RELAUNCH VALUES VERIFIED' \
  'ALL SETTINGS TESTS PASSED'; do
  grep -q "$marker" "$EVIDENCE_DIR/verify.log" || {
    echo "ERROR: missing verify marker: $marker" >&2
    exit 1
  }
done

printf '%s\n' \
  'IOS NATIVE SETTINGS RESULT: PASS (live touch/audio/display apply; defensive clamping; two-launch persistence; profile isolation; modal input suppression and restoration; reset defaults; arm64 ROM-free app; no crash)' \
  | tee "$EVIDENCE_DIR/result.txt"
