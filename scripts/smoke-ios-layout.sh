#!/usr/bin/env bash
# Two-launch iOS touch-layout persistence, reset, and idiom-isolation smoke.
# Run only through runtime-guard.sh with one Simulator.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UDID="${DINOPAD_RUNTIME_UDID:-}"
TARGET="${DINOPAD_RUNTIME_TARGET:-}"
APP="$ROOT/build-ios-simulator/Release-iphonesimulator/DinoPad.app"
BUNDLE_ID="com.chrissotraidis.dinopad"
ROM="${DINOPAD_ROM_PATH:-$ROOT/ref/DINO/rom}"
EVIDENCE_DIR="${DINOPAD_IOS_LAYOUT_EVIDENCE_DIR:-$ROOT/.goal-loop/smoke-ios-layout}"
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

if [[ "$TARGET" != "iphone-simulator" && "$TARGET" != "ipad-simulator" ]]; then
  echo "ERROR: smoke-ios-layout.sh requires an iOS Simulator guard" >&2
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
rm -f "$EVIDENCE_DIR"/*.log "$EVIDENCE_DIR"/*.png "$EVIDENCE_DIR/result.txt"
crashes_before="$(find "$REPORTS" -type f -name 'DinoPad-*.ips' 2>/dev/null | wc -l | tr -d ' ')"

xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b
xcrun simctl uninstall "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP"
DATA_CONTAINER="$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data)"
mkdir -p "$DATA_CONTAINER/Library/Application Support/DinoPad"
python3 "$ROOT/tools/normalize_rom.py" "$ROM" \
  --out "$DATA_CONTAINER/Library/Application Support/DinoPad/dino.z64" >/dev/null

export SIMCTL_CHILD_DINOPAD_HOME_AUTOMATION_SEQUENCE=restored
export SIMCTL_CHILD_DINOPAD_RUN_LAYOUT_SMOKE=1
export SIMCTL_CHILD_DINOPAD_LAYOUT_SMOKE_PHASE=edit
unset SIMCTL_CHILD_DINOPAD_SHOW_TOUCH_MENU_SMOKE
xcrun simctl launch --console --terminate-running-process "$UDID" "$BUNDLE_ID" \
  >"$EVIDENCE_DIR/edit.log" 2>&1 &
CONSOLE_PID=$!
for _ in {1..80}; do
  grep -q 'EDIT PHASE PASSED' "$EVIDENCE_DIR/edit.log" 2>/dev/null && break
  kill -0 "$CONSOLE_PID" 2>/dev/null || break
  sleep 0.5
done
grep -q 'EDIT PHASE PASSED' "$EVIDENCE_DIR/edit.log" || {
  echo "ERROR: touch-layout edit phase did not complete" >&2
  exit 1
}
if grep -q '\[dinopad-layout-test\] FAIL:' "$EVIDENCE_DIR/edit.log"; then
  echo "ERROR: touch-layout edit phase reported a failure" >&2
  exit 1
fi
xcrun simctl io "$UDID" screenshot "$EVIDENCE_DIR/editor-edited.png"
stop_launch

export SIMCTL_CHILD_DINOPAD_LAYOUT_SMOKE_PHASE=verify
xcrun simctl launch --console --terminate-running-process "$UDID" "$BUNDLE_ID" \
  >"$EVIDENCE_DIR/verify.log" 2>&1 &
CONSOLE_PID=$!
for _ in {1..80}; do
  grep -q 'ALL LAYOUT TESTS PASSED' "$EVIDENCE_DIR/verify.log" 2>/dev/null && break
  kill -0 "$CONSOLE_PID" 2>/dev/null || break
  sleep 0.5
done
grep -q 'ALL LAYOUT TESTS PASSED' "$EVIDENCE_DIR/verify.log" || {
  echo "ERROR: touch-layout relaunch/reset phase did not complete" >&2
  exit 1
}
if grep -q '\[dinopad-layout-test\] FAIL:' "$EVIDENCE_DIR/verify.log"; then
  echo "ERROR: touch-layout relaunch/reset phase reported a failure" >&2
  exit 1
fi
xcrun simctl io "$UDID" screenshot "$EVIDENCE_DIR/editor-reset.png"
stop_launch

unset SIMCTL_CHILD_DINOPAD_RUN_LAYOUT_SMOKE SIMCTL_CHILD_DINOPAD_LAYOUT_SMOKE_PHASE
export SIMCTL_CHILD_DINOPAD_SHOW_TOUCH_MENU_SMOKE=1
xcrun simctl launch --console --terminate-running-process "$UDID" "$BUNDLE_ID" \
  >"$EVIDENCE_DIR/menu.log" 2>&1 &
CONSOLE_PID=$!
for _ in {1..80}; do
  grep -q 'touch layout menu presented' "$EVIDENCE_DIR/menu.log" 2>/dev/null && break
  kill -0 "$CONSOLE_PID" 2>/dev/null || break
  sleep 0.5
done
grep -q 'touch layout menu presented' "$EVIDENCE_DIR/menu.log" || {
  echo "ERROR: native touch-layout menu was not presented" >&2
  exit 1
}
sleep 0.5
xcrun simctl io "$UDID" screenshot "$EVIDENCE_DIR/menu.png"
stop_launch

crashes_after="$(find "$REPORTS" -type f -name 'DinoPad-*.ips' 2>/dev/null | wc -l | tr -d ' ')"
[[ "$crashes_after" == "$crashes_before" ]] || {
  echo "ERROR: new DinoPad crash report detected" >&2
  exit 1
}

for marker in \
  'editing clears held gameplay input' \
  'Cancel restores the pre-edit layout' \
  'D-pad link moves all four controls as a group' \
  'C-button link moves all four controls as a group' \
  'resize, fade, hide, and one-step Undo are functional' \
  'safe-area clamp keeps edited controls reachable' \
  'gameplay touch resumes after editor dismissal'; do
  grep -q "PASS: $marker" "$EVIDENCE_DIR/edit.log" || {
    echo "ERROR: missing edit marker: $marker" >&2
    exit 1
  }
done
for marker in \
  'persisted across relaunch' \
  'persistence keys are isolated' \
  'active layout reset restores only current idiom defaults' \
  'inactive layout reset preserves current idiom defaults'; do
  grep -q "PASS: .*$marker" "$EVIDENCE_DIR/verify.log" || {
    echo "ERROR: missing verify marker: $marker" >&2
    exit 1
  }
done

printf '%s\n' \
  'IOS TOUCH LAYOUT RESULT: PASS (two-launch persistence; independent phone/tablet defaults; move/resize/fade/hide/link; undo/cancel; safe-area clamp; reset; input restoration; native menu; arm64 ROM-free app; no crash)' \
  | tee "$EVIDENCE_DIR/result.txt"
