#!/usr/bin/env bash
# Verify DinoPad's native UIKit home, archival warning, profile isolation, and
# in-process Quit-to-Home restart. Run only through runtime-guard.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UDID="${DINOPAD_RUNTIME_UDID:-}"
TARGET="${DINOPAD_RUNTIME_TARGET:-}"
APP="$ROOT/build-ios-simulator/Release-iphonesimulator/DinoPad.app"
BUNDLE_ID="com.chrissotraidis.dinopad"
ROM="${DINOPAD_ROM_PATH:-$ROOT/ref/DINO/rom}"
EVIDENCE_DIR="${DINOPAD_IOS_HOME_EVIDENCE_DIR:-$ROOT/.goal-loop/smoke-ios-home}"
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
  echo "ERROR: smoke-ios-home.sh requires an iOS Simulator guard" >&2
  exit 2
}
[[ -n "$UDID" ]] || { echo "ERROR: missing guarded Simulator UDID" >&2; exit 2; }
[[ -x "$APP/DinoPad" ]] || { echo "ERROR: missing Simulator app" >&2; exit 1; }
[[ -f "$ROM" ]] || { echo "ERROR: private supported ROM missing" >&2; exit 1; }

mkdir -p "$EVIDENCE_DIR"
crashes_before="$(find "$REPORTS" -type f -name 'DinoPad-*.ips' 2>/dev/null | wc -l | tr -d ' ')"

xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b
xcrun simctl uninstall "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP"
DATA_CONTAINER="$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data)"
DATA_ROOT="$DATA_CONTAINER/Library/Application Support/DinoPad"
mkdir -p "$DATA_ROOT"
python3 "$ROOT/tools/normalize_rom.py" "$ROM" --out "$DATA_ROOT/dino.z64" >/dev/null

# Phase 1: the real home must remain visible before any SDL runtime starts.
xcrun simctl launch --console --terminate-running-process "$UDID" "$BUNDLE_ID" \
  >"$EVIDENCE_DIR/home-runtime.log" 2>&1 &
CONSOLE_PID=$!
for _ in {1..60}; do
  if grep -q '\[dinopad-home-test\] Home presented' \
      "$EVIDENCE_DIR/home-runtime.log" 2>/dev/null; then
    break
  fi
  if ! kill -0 "$CONSOLE_PID" 2>/dev/null; then break; fi
  sleep 0.5
done
pgrep -x DinoPad >/dev/null || { echo "ERROR: home process exited" >&2; exit 1; }
grep -q '\[dinopad-home-test\] Home presented' "$EVIDENCE_DIR/home-runtime.log" || {
  echo "ERROR: home marker missing" >&2; exit 1;
}
if grep -q 'SDL Video Driver:' "$EVIDENCE_DIR/home-runtime.log"; then
  echo "ERROR: SDL started before the home selection" >&2
  exit 1
fi
xcrun simctl io "$UDID" screenshot "$EVIDENCE_DIR/home.png"
stop_app

# Phase 2: Prototype Mode must show the honest archival warning and wait for
# explicit confirmation.
export SIMCTL_CHILD_DINOPAD_HOME_SHOW_PROTOTYPE_WARNING=1
xcrun simctl launch --console --terminate-running-process "$UDID" "$BUNDLE_ID" \
  >"$EVIDENCE_DIR/prototype-warning-runtime.log" 2>&1 &
CONSOLE_PID=$!
for _ in {1..60}; do
  if grep -q '\[dinopad-home-test\] Prototype warning presented' \
      "$EVIDENCE_DIR/prototype-warning-runtime.log" 2>/dev/null; then
    break
  fi
  if ! kill -0 "$CONSOLE_PID" 2>/dev/null; then break; fi
  sleep 0.5
done
pgrep -x DinoPad >/dev/null || { echo "ERROR: warning process exited" >&2; exit 1; }
grep -q '\[dinopad-home-test\] Prototype warning presented' \
  "$EVIDENCE_DIR/prototype-warning-runtime.log" || {
    echo "ERROR: prototype warning marker missing" >&2; exit 1;
  }
if grep -q 'DinoPad profile:' "$EVIDENCE_DIR/prototype-warning-runtime.log"; then
  echo "ERROR: Prototype runtime started without warning confirmation" >&2
  exit 1
fi
xcrun simctl io "$UDID" screenshot "$EVIDENCE_DIR/prototype-warning.png"
stop_app
unset SIMCTL_CHILD_DINOPAD_HOME_SHOW_PROTOTYPE_WARNING

# Phase 3: select Restored, request Quit to Home from the live overlay, then
# confirm Prototype in the same process. Sentinels prove both namespaces stay
# independent across the switch.
RESTORED_DIR="$DATA_ROOT/Profiles/Restored"
PROTOTYPE_DIR="$DATA_ROOT/Profiles/Prototype"
mkdir -p "$RESTORED_DIR" "$PROTOTYPE_DIR"
printf 'restored-private-state\n' > "$RESTORED_DIR/profile-sentinel.txt"
printf 'prototype-private-state\n' > "$PROTOTYPE_DIR/profile-sentinel.txt"
restored_before="$(shasum -a 256 "$RESTORED_DIR/profile-sentinel.txt" | awk '{print $1}')"
prototype_before="$(shasum -a 256 "$PROTOTYPE_DIR/profile-sentinel.txt" | awk '{print $1}')"

export SIMCTL_CHILD_DINOPAD_HOME_AUTOMATION_SEQUENCE="restored,prototype"
export SIMCTL_CHILD_DINOPAD_QUIT_TO_HOME_SMOKE=1
xcrun simctl launch --console --terminate-running-process "$UDID" "$BUNDLE_ID" \
  >"$EVIDENCE_DIR/profile-switch-runtime.log" 2>&1 &
CONSOLE_PID=$!

for _ in {1..60}; do
  if grep -q 'DinoPad profile: Prototype (namespace=Profiles/Prototype)' \
      "$EVIDENCE_DIR/profile-switch-runtime.log" 2>/dev/null; then
    break
  fi
  sleep 0.5
done
sleep 3
pgrep -x DinoPad >/dev/null || { echo "ERROR: switched runtime exited" >&2; exit 1; }

for marker in \
  'Restored selected' \
  'Gameplay input polled before quit' \
  'Quit to home requested' \
  'Runtime returned to home' \
  'Prototype warning presented' \
  'Prototype selected'; do
  grep -q "\[dinopad-home-test\] $marker" "$EVIDENCE_DIR/profile-switch-runtime.log" || {
    echo "ERROR: missing home marker: $marker" >&2; exit 1;
  }
done

[[ "$(grep -c '\[dinopad-home-test\] Home presented' "$EVIDENCE_DIR/profile-switch-runtime.log")" -ge 2 ]] || {
  echo "ERROR: home was not presented again after runtime shutdown" >&2; exit 1;
}
grep -q 'DinoPad profile: Restored (namespace=Profiles/Restored)' \
  "$EVIDENCE_DIR/profile-switch-runtime.log" || { echo "ERROR: Restored namespace missing" >&2; exit 1; }
grep -q 'DinoPad profile: Prototype (namespace=Profiles/Prototype)' \
  "$EVIDENCE_DIR/profile-switch-runtime.log" || { echo "ERROR: Prototype namespace missing" >&2; exit 1; }
[[ "$(grep -c 'Bundled restoration data registered' "$EVIDENCE_DIR/profile-switch-runtime.log")" -eq 1 ]] || {
  echo "ERROR: restoration data was not exclusive to the Restored runtime" >&2; exit 1;
}
[[ "$(grep -c 'Using statically linked code for mod dinomod_enhanced' "$EVIDENCE_DIR/profile-switch-runtime.log")" -eq 1 ]] || {
  echo "ERROR: static restoration code was not exclusive to Restored" >&2; exit 1;
}
prototype_profile_line="$(grep -n 'DinoPad profile: Prototype (namespace=Profiles/Prototype)' \
  "$EVIDENCE_DIR/profile-switch-runtime.log" | tail -1 | cut -d: -f1)"
if tail -n "+$prototype_profile_line" "$EVIDENCE_DIR/profile-switch-runtime.log" \
    | grep -Eq 'Bundled restoration data registered|Using statically linked code for mod dinomod_enhanced'; then
  echo "ERROR: Prototype runtime activated restoration" >&2
  exit 1
fi
[[ "$(grep -c '\[dinopad-touch\] overlay attached' "$EVIDENCE_DIR/profile-switch-runtime.log")" -ge 2 ]] || {
  echo "ERROR: second runtime touch overlay missing" >&2; exit 1;
}

restored_after="$(shasum -a 256 "$RESTORED_DIR/profile-sentinel.txt" | awk '{print $1}')"
prototype_after="$(shasum -a 256 "$PROTOTYPE_DIR/profile-sentinel.txt" | awk '{print $1}')"
[[ "$restored_before" == "$restored_after" && "$prototype_before" == "$prototype_after" ]] || {
  echo "ERROR: profile-isolation sentinels changed during switch" >&2; exit 1;
}
xcrun simctl io "$UDID" screenshot "$EVIDENCE_DIR/prototype-runtime.png"
stop_app
unset SIMCTL_CHILD_DINOPAD_HOME_AUTOMATION_SEQUENCE
unset SIMCTL_CHILD_DINOPAD_QUIT_TO_HOME_SMOKE

crashes_after="$(find "$REPORTS" -type f -name 'DinoPad-*.ips' 2>/dev/null | wc -l | tr -d ' ')"
[[ "$crashes_after" == "$crashes_before" ]] || { echo "ERROR: new DinoPad crash report detected" >&2; exit 1; }

printf 'IOS HOME RESULT: PASS (UIKit home before SDL; Restored primary; Prototype archival warning; isolated profiles; live Quit-to-Home restart; second runtime; no crash)\n' \
  | tee "$EVIDENCE_DIR/result.txt"
