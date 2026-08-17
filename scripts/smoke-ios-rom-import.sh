#!/usr/bin/env bash
# Verify DinoPad's real UIKit first-run Files picker and production ROM-import
# boundary. Run only through runtime-guard.sh with one Simulator.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UDID="${DINOPAD_RUNTIME_UDID:-}"
TARGET="${DINOPAD_RUNTIME_TARGET:-}"
APP="$ROOT/build-ios-simulator/Release-iphonesimulator/DinoPad.app"
BUNDLE_ID="com.chrissotraidis.dinopad"
ROM="${DINOPAD_ROM_PATH:-$ROOT/ref/DINO/rom}"
EVIDENCE_DIR="${DINOPAD_IOS_ROM_IMPORT_EVIDENCE_DIR:-$ROOT/.goal-loop/smoke-ios-rom-import}"
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

if [[ "$TARGET" != "iphone-simulator" ]]; then
  echo "ERROR: smoke-ios-rom-import.sh requires the iPhone Simulator guard" >&2
  exit 2
fi
[[ -n "$UDID" ]] || { echo "ERROR: runtime guard did not provide a Simulator UDID" >&2; exit 2; }
[[ -x "$APP/DinoPad" ]] || { echo "ERROR: missing Simulator app" >&2; exit 1; }
[[ -f "$ROM" ]] || { echo "ERROR: private supported ROM missing" >&2; exit 1; }

if find "$APP" -type f \( -iname '*.z64' -o -iname '*.v64' -o -iname '*.n64' -o -iname '*.rom' \) -print -quit | grep -q .; then
  echo "ERROR: Simulator bundle contains a ROM" >&2
  exit 1
fi
python3 "$ROOT/tools/normalize_rom.py" "$ROM" >/dev/null
mkdir -p "$EVIDENCE_DIR"

crashes_before="$(find "$REPORTS" -type f -name 'DinoPad-*.ips' 2>/dev/null | wc -l | tr -d ' ')"
xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b
xcrun simctl uninstall "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP"
DATA_CONTAINER="$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data)"
FIXTURES="$DATA_CONTAINER/Documents/DinoPadImportSmoke"
mkdir -p "$FIXTURES"

SOURCE_Z64="$FIXTURES/source.z64"
SHORT_ROM="$FIXTURES/too-small.z64"
INVALID_ROM="$FIXTURES/modified.z64"
V64_ROM="$FIXTURES/supported.v64"
N64_ROM="$FIXTURES/supported.n64"
TARGET_ROM="$DATA_CONTAINER/Library/Application Support/DinoPad/dino.z64"
python3 "$ROOT/tools/normalize_rom.py" "$ROM" --out "$SOURCE_Z64" >/dev/null
head -c 1024 "$SOURCE_Z64" > "$SHORT_ROM"
python3 -c 'import pathlib,sys; data=bytearray(pathlib.Path(sys.argv[1]).read_bytes()); data[-1] ^= 1; pathlib.Path(sys.argv[2]).write_bytes(data)' "$SOURCE_Z64" "$INVALID_ROM"
python3 -c 'import pathlib,sys; data=pathlib.Path(sys.argv[1]).read_bytes(); out=bytearray(len(data)); out[0::2]=data[1::2]; out[1::2]=data[0::2]; pathlib.Path(sys.argv[2]).write_bytes(out)' "$SOURCE_Z64" "$V64_ROM"
python3 -c 'import pathlib,sys; data=pathlib.Path(sys.argv[1]).read_bytes(); out=bytearray(len(data)); out[0::4]=data[3::4]; out[1::4]=data[2::4]; out[2::4]=data[1::4]; out[3::4]=data[0::4]; pathlib.Path(sys.argv[2]).write_bytes(out)' "$SOURCE_Z64" "$N64_ROM"

# Phase 1: no installed ROM. Present the actual native Files picker and capture it.
export SIMCTL_CHILD_DINOPAD_SHOW_ROM_PICKER_SMOKE=1
xcrun simctl launch --console --terminate-running-process "$UDID" "$BUNDLE_ID" \
  >"$EVIDENCE_DIR/picker-runtime.log" 2>&1 &
CONSOLE_PID=$!
sleep 4
pgrep -x DinoPad >/dev/null || { echo "ERROR: setup process did not remain alive" >&2; exit 1; }
grep -q '\[dinopad-rom-test\] First-run setup presented' "$EVIDENCE_DIR/picker-runtime.log" || {
  echo "ERROR: first-run setup marker missing" >&2; exit 1;
}
grep -q '\[dinopad-rom-test\] Files picker presented' "$EVIDENCE_DIR/picker-runtime.log" || {
  echo "ERROR: native Files picker marker missing" >&2; exit 1;
}
xcrun simctl io "$UDID" screenshot "$EVIDENCE_DIR/files-picker.png"
stop_app

# Phase 2: drive the production import function with private disposable
# fixtures. Invalid inputs must leave no target; valid v64 must normalize.
unset SIMCTL_CHILD_DINOPAD_SHOW_ROM_PICKER_SMOKE
export SIMCTL_CHILD_DINOPAD_RUN_ROM_IMPORT_SMOKE=1
export SIMCTL_CHILD_DINOPAD_ROM_IMPORT_SHORT="$SHORT_ROM"
export SIMCTL_CHILD_DINOPAD_ROM_IMPORT_INVALID="$INVALID_ROM"
export SIMCTL_CHILD_DINOPAD_ROM_IMPORT_Z64="$SOURCE_Z64"
export SIMCTL_CHILD_DINOPAD_ROM_IMPORT_V64="$V64_ROM"
export SIMCTL_CHILD_DINOPAD_ROM_IMPORT_N64="$N64_ROM"
xcrun simctl launch --console --terminate-running-process "$UDID" "$BUNDLE_ID" \
  >"$EVIDENCE_DIR/import-runtime.log" 2>&1 &
CONSOLE_PID=$!
sleep 8
pgrep -x DinoPad >/dev/null || { echo "ERROR: imported-ROM process did not remain alive" >&2; exit 1; }
xcrun simctl io "$UDID" screenshot "$EVIDENCE_DIR/imported-runtime.png"
stop_app

for marker in \
  'PASS: wrong-size ROM rejected without staging' \
  'PASS: modified ROM rejected without staging' \
  'PASS: z64 normalized to exact supported z64' \
  'PASS: v64 normalized to exact supported z64' \
  'PASS: n64 normalized to exact supported z64' \
  'PASS: exact MD5; private atomic storage; excluded from backup' \
  'ALL ROM IMPORT TESTS PASSED'; do
  grep -q "\[dinopad-rom-test\] $marker" "$EVIDENCE_DIR/import-runtime.log" || {
    echo "ERROR: missing ROM import marker: $marker" >&2; exit 1;
  }
done

[[ -f "$TARGET_ROM" ]] || { echo "ERROR: normalized private ROM was not stored" >&2; exit 1; }
[[ "$(md5 -q "$TARGET_ROM")" == "49f7bb346ade39d1915c22e090ffd748" ]] || {
  echo "ERROR: stored ROM fingerprint mismatch" >&2; exit 1;
}
[[ "$(xxd -p -l 4 "$TARGET_ROM")" == "80371240" ]] || {
  echo "ERROR: stored ROM is not normalized z64" >&2; exit 1;
}

# Phase 3: prove the in-game menu's production ROM manager is reachable and
# visibly offers replacement/removal while gameplay controls remain hidden.
unset SIMCTL_CHILD_DINOPAD_RUN_ROM_IMPORT_SMOKE
unset SIMCTL_CHILD_DINOPAD_ROM_IMPORT_SHORT
unset SIMCTL_CHILD_DINOPAD_ROM_IMPORT_INVALID
unset SIMCTL_CHILD_DINOPAD_ROM_IMPORT_Z64
unset SIMCTL_CHILD_DINOPAD_ROM_IMPORT_V64
unset SIMCTL_CHILD_DINOPAD_ROM_IMPORT_N64
export SIMCTL_CHILD_DINOPAD_SHOW_ROM_MANAGER_SMOKE=1
xcrun simctl launch --console --terminate-running-process "$UDID" "$BUNDLE_ID" \
  >"$EVIDENCE_DIR/manager-runtime.log" 2>&1 &
CONSOLE_PID=$!
sleep 4
pgrep -x DinoPad >/dev/null || { echo "ERROR: ROM manager process did not remain alive" >&2; exit 1; }
grep -q '\[dinopad-rom-test\] ROM manager presented with Replace/Remove actions' \
  "$EVIDENCE_DIR/manager-runtime.log" || { echo "ERROR: ROM manager marker missing" >&2; exit 1; }
xcrun simctl io "$UDID" screenshot "$EVIDENCE_DIR/rom-manager.png"
stop_app

crashes_after="$(find "$REPORTS" -type f -name 'DinoPad-*.ips' 2>/dev/null | wc -l | tr -d ' ')"
[[ "$crashes_after" == "$crashes_before" ]] || { echo "ERROR: new DinoPad crash report detected" >&2; exit 1; }

printf 'IOS ROM IMPORT RESULT: PASS (real Files picker + replacement manager; size/fingerprint rejection without staging; z64/v64/n64 normalization; exact MD5; private atomic storage; ROM-free bundle; no crash)\n' \
  | tee "$EVIDENCE_DIR/result.txt"
