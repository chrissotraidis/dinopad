#!/usr/bin/env bash
# Bounded first-frame iOS Simulator smoke. Run through runtime-guard.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UDID="${DINOPAD_RUNTIME_UDID:-}"
TARGET="${DINOPAD_RUNTIME_TARGET:-}"
APP="$ROOT/build-ios-simulator/Release-iphonesimulator/DinoPad.app"
BUNDLE_ID="com.chrissotraidis.dinopad"
ROM="${DINOPAD_ROM_PATH:-$ROOT/ref/DINO/rom}"
EVIDENCE_DIR="${DINOPAD_IOS_EVIDENCE_DIR:-$ROOT/.goal-loop/smoke-ios}"
DURATION="${DINOPAD_IOS_SMOKE_SECONDS:-20}"
REPORTS="$HOME/Library/Logs/DiagnosticReports"
CONSOLE_PID=""

if [[ "$TARGET" != "iphone-simulator" && "$TARGET" != "ipad-simulator" ]]; then
  echo "ERROR: smoke-ios.sh must run through runtime-guard.sh for a Simulator" >&2
  exit 2
fi
[[ -n "$UDID" ]] || { echo "ERROR: runtime guard did not provide a Simulator UDID" >&2; exit 2; }
[[ -x "$APP/DinoPad" ]] || { echo "ERROR: missing Simulator app; run scripts/build-ios-simulator.sh" >&2; exit 1; }
[[ -f "$ROM" ]] || { echo "ERROR: private supported ROM missing (set DINOPAD_ROM_PATH)" >&2; exit 1; }
[[ "$DURATION" =~ ^[0-9]+$ ]] && (( DURATION > 0 )) || { echo "ERROR: invalid smoke duration" >&2; exit 2; }

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
python3 "$ROOT/tools/normalize_rom.py" "$ROM" \
  --out "$DATA_CONTAINER/Library/Application Support/DinoPad/dino.z64" >/dev/null

xcrun simctl launch --console --terminate-running-process "$UDID" "$BUNDLE_ID" \
  >"$EVIDENCE_DIR/runtime.log" 2>&1 &
CONSOLE_PID=$!
sleep "$DURATION"

if ! pgrep -x DinoPad >/dev/null; then
  echo "ERROR: DinoPad did not remain alive for ${DURATION}s" >&2
  wait "$CONSOLE_PID" 2>/dev/null || true
  exit 1
fi
xcrun simctl io "$UDID" screenshot "$EVIDENCE_DIR/first-frame.png"
xcrun simctl terminate "$UDID" "$BUNDLE_ID"
wait "$CONSOLE_PID" 2>/dev/null || true
CONSOLE_PID=""

crashes_after="$(find "$REPORTS" -type f -name 'DinoPad-*.ips' 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$crashes_after" != "$crashes_before" ]]; then
  echo "ERROR: new DinoPad crash report detected" >&2
  exit 1
fi

printf 'IOS FIRST-FRAME RESULT: PASS (arm64 app; ROM-free bundle; live %ss; screenshot; no crash)\n' "$DURATION" \
  | tee "$EVIDENCE_DIR/result.txt"
