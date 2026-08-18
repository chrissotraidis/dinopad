#!/usr/bin/env bash
# Bounded redaction, private capture, native share, and modal-input smoke.
# Run only through runtime-guard.sh with one Simulator.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UDID="${DINOPAD_RUNTIME_UDID:-}"
TARGET="${DINOPAD_RUNTIME_TARGET:-}"
APP="$ROOT/build-ios-simulator/Release-iphonesimulator/DinoPad.app"
BUNDLE_ID="com.chrissotraidis.dinopad"
ROM="${DINOPAD_ROM_PATH:-$ROOT/ref/DINO/rom}"
EVIDENCE_DIR="${DINOPAD_IOS_DIAGNOSTICS_EVIDENCE_DIR:-$ROOT/.goal-loop/smoke-ios-diagnostics}"
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

[[ "$TARGET" == "iphone-simulator" || "$TARGET" == "ipad-simulator" ]] || {
  echo "ERROR: smoke-ios-diagnostics.sh requires an iOS Simulator guard" >&2
  exit 2
}
[[ -n "$UDID" ]] || { echo "ERROR: runtime guard did not provide a UDID" >&2; exit 2; }
[[ -x "$APP/DinoPad" ]] || { echo "ERROR: missing Simulator app" >&2; exit 1; }
[[ -f "$ROM" ]] || { echo "ERROR: private supported ROM missing" >&2; exit 1; }
if find "$APP" -type f \( -iname '*.z64' -o -iname '*.v64' -o -iname '*.n64' -o -iname '*.rom' \) -print -quit | grep -q .; then
  echo "ERROR: Simulator bundle contains a ROM" >&2
  exit 1
fi
[[ "$(lipo -archs "$APP/DinoPad")" == "arm64" ]] || {
  echo "ERROR: Simulator executable is not arm64-only" >&2
  exit 1
}

mkdir -p "$EVIDENCE_DIR"
rm -f "$EVIDENCE_DIR"/*.log "$EVIDENCE_DIR"/*.txt "$EVIDENCE_DIR"/*.png
crashes_before="$(find "$REPORTS" -type f -name 'DinoPad-*.ips' 2>/dev/null | wc -l | tr -d ' ')"

xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b
xcrun simctl uninstall "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP"
DATA_CONTAINER="$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data)"
DATA_ROOT="$DATA_CONTAINER/Library/Application Support/DinoPad"
LOG_ROOT="$DATA_ROOT/Logs"
mkdir -p "$DATA_ROOT"
python3 "$ROOT/tools/normalize_rom.py" "$ROM" --out "$DATA_ROOT/dino.z64" >/dev/null

export SIMCTL_CHILD_DINOPAD_HOME_AUTOMATION_SEQUENCE=restored
export SIMCTL_CHILD_DINOPAD_RUN_DIAGNOSTICS_SMOKE=1
xcrun simctl launch --console --terminate-running-process "$UDID" "$BUNDLE_ID" \
  >"$EVIDENCE_DIR/runtime.log" 2>&1 &
CONSOLE_PID=$!
for _ in {1..120}; do
  grep -q 'SHARE PRESENTED' "$EVIDENCE_DIR/runtime.log" 2>/dev/null && break
  kill -0 "$CONSOLE_PID" 2>/dev/null || break
  sleep 0.25
done
grep -q 'SHARE PRESENTED' "$EVIDENCE_DIR/runtime.log" || {
  echo "ERROR: native diagnostics share sheet was not presented" >&2
  exit 1
}
xcrun simctl io "$UDID" screenshot "$EVIDENCE_DIR/share-sheet.png"
for _ in {1..80}; do
  grep -q 'ALL DIAGNOSTICS TESTS PASSED' "$EVIDENCE_DIR/runtime.log" 2>/dev/null && break
  sleep 0.25
done
grep -q 'ALL DIAGNOSTICS TESTS PASSED' "$EVIDENCE_DIR/runtime.log" || {
  echo "ERROR: diagnostics smoke did not complete" >&2
  exit 1
}
if grep -q '\[dinopad-diagnostics-test\] FAIL:' "$EVIDENCE_DIR/runtime.log"; then
  echo "ERROR: diagnostics smoke reported a failure" >&2
  exit 1
fi

REPORT="$LOG_ROOT/dinopad-smoke-report.txt"
LATEST="$LOG_ROOT/dinopad-latest.log"
[[ -f "$REPORT" && -f "$LATEST" ]] || {
  echo "ERROR: diagnostics report or private log missing" >&2
  exit 1
}
cp "$REPORT" "$EVIDENCE_DIR/sanitized-report.txt"
cp "$LATEST" "$EVIDENCE_DIR/sanitized-private-log.txt"
if [[ "$TARGET" == "ipad-simulator" ]]; then
  grep -q '^Device: iPad (tablet)$' "$REPORT" || {
    echo "ERROR: diagnostics report did not identify the iPad tablet path" >&2
    exit 1
  }
else
  grep -q '^Device: iPhone (phone)$' "$REPORT" || {
    echo "ERROR: diagnostics report did not identify the iPhone phone path" >&2
    exit 1
  }
fi
python3 - "$REPORT" "$LATEST" <<'PY'
import pathlib
import stat
import sys

report_path = pathlib.Path(sys.argv[1])
log_path = pathlib.Path(sys.argv[2])
report = report_path.read_text()
stored = log_path.read_text()
assert report_path.stat().st_size <= 512 * 1024
assert log_path.stat().st_size <= 4 * 1024 * 1024
assert stat.S_IMODE(report_path.stat().st_mode) == 0o600
assert stat.S_IMODE(log_path.stat().st_mode) == 0o600
required = [
    "DinoPad diagnostics", "Profile: Restored Adventure",
    "ROM validation: exact supported prototype verified", "Save / recovery:",
    "Controller:", "Renderer: Metal", "Diagnostics bounds:", "<PATH>",
]
for marker in required:
    assert marker in report, marker
for private in [
    "/" + "Users/diagnostic-owner", "/private/var/mobile/Containers/Data/Application/",
    "file:///var/mobile/Library/Mobile%20Documents", "/tmp/dinopad-private",
    "/Volumes/Owner", "11111111-2222-3333-4444-555555555555",
]:
    assert private not in report, private
    assert private not in stored, private
assert "<PATH>" in stored
PY

if find "$DATA_CONTAINER/tmp" -name 'DinoPad-Diagnostics.txt' -print -quit | grep -q .; then
  echo "ERROR: temporary share report was not cleaned" >&2
  exit 1
fi
rm -f "$REPORT"
[[ ! -e "$REPORT" ]] || { echo "ERROR: test evidence report was not cleanable" >&2; exit 1; }

crashes_after="$(find "$REPORTS" -type f -name 'DinoPad-*.ips' 2>/dev/null | wc -l | tr -d ' ')"
[[ "$crashes_after" == "$crashes_before" ]] || {
  echo "ERROR: new DinoPad crash report detected" >&2
  exit 1
}
for marker in \
  'share presentation cleared held input' \
  'bounded sanitized report and private log verified' \
  'SHARE PRESENTED' \
  'temporary share report cleaned' \
  'ALL DIAGNOSTICS TESTS PASSED'; do
  grep -q "$marker" "$EVIDENCE_DIR/runtime.log" || {
    echo "ERROR: missing diagnostics marker: $marker" >&2
    exit 1
  }
done

printf '%s\n' \
  'IOS DIAGNOSTICS RESULT: PASS (4 MiB private sanitized capture; 192 KiB tails; 512 KiB report; adversarial path redaction; useful status; native share/cancel; modal input restoration; temporary/test cleanup; arm64 ROM-free app; no crash)' \
  | tee "$EVIDENCE_DIR/result.txt"
