#!/usr/bin/env bash
# Verify deterministic Restored/Prototype selection and isolated config/save
# namespaces against a disposable data root. Run through runtime-guard.sh.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build-macos/DinoPad.app/Contents/MacOS/DinoPad"
SOURCE_ROOT="$HOME/Library/Application Support/DinoPad"
SOURCE_ROM="$SOURCE_ROOT/dino.z64"
SOURCE_NRM="${DINOPAD_PROFILE_NRM:-$SOURCE_ROOT/mods/dinomod_enhanced.offline.nrm}"
EVIDENCE_DIR="${DINOPAD_PROFILE_EVIDENCE_DIR:-}"
SCRATCH="$(mktemp -d "$ROOT/.goal-loop/profile-smoke.XXXXXX")"
DATA_ROOT="$SCRATCH/data"
RESTORED_ROOT="$DATA_ROOT/Profiles/Restored"
PROTOTYPE_ROOT="$DATA_ROOT/Profiles/Prototype"
RESTORED_SAVE="$RESTORED_ROOT/saves/dino.bin"
PROTOTYPE_SAVE="$PROTOTYPE_ROOT/saves/dino.bin"
APP_PID=""

cleanup() {
  trap - EXIT INT TERM
  if [ -n "$APP_PID" ] && kill -0 "$APP_PID" 2>/dev/null; then
    kill "$APP_PID" 2>/dev/null || true
    for _ in $(jot 100 1); do
      if ! kill -0 "$APP_PID" 2>/dev/null; then break; fi
      sleep 0.1
    done
    if kill -0 "$APP_PID" 2>/dev/null; then kill -9 "$APP_PID" 2>/dev/null || true; fi
    wait "$APP_PID" 2>/dev/null || true
  fi
  case "$SCRATCH" in
    "$ROOT"/.goal-loop/profile-smoke.*) rm -rf -- "$SCRATCH" ;;
    *) echo "ERROR: refusing to remove unexpected scratch path: $SCRATCH" >&2 ;;
  esac
}
trap cleanup EXIT INT TERM

if [ ! -x "$APP" ] || [ ! -f "$SOURCE_ROM" ] || [ ! -f "$SOURCE_NRM" ]; then
  echo "ERROR: missing DinoPad, private ROM, or private restoration package" >&2
  exit 1
fi

mkdir -p "$DATA_ROOT/mods" "$RESTORED_ROOT/saves" "$PROTOTYPE_ROOT/saves"
cp "$SOURCE_ROM" "$DATA_ROOT/dino.z64"
cp "$SOURCE_NRM" "$DATA_ROOT/mods/dinomod_enhanced.nrm"
dd if=/dev/zero of="$RESTORED_SAVE" bs=131072 count=1 status=none
dd if=/dev/zero of="$PROTOTYPE_SAVE" bs=131072 count=1 status=none
printf 'RESTORED' | dd of="$RESTORED_SAVE" conv=notrunc status=none
printf 'PROTOTYPE' | dd of="$PROTOTYPE_SAVE" conv=notrunc status=none

hash_file() { shasum -a 256 "$1" | awk '{print $1}'; }
send_space() {
  osascript -e 'tell application "System Events" to set frontmost of (first application process whose name is "DinoPad") to true' 2>/dev/null || true
  sleep 0.2
  osascript -e 'tell application "System Events" to key down 49' 2>/dev/null
  sleep 0.35
  osascript -e 'tell application "System Events" to key up 49' 2>/dev/null
}
stop_app() {
  if [ -n "$APP_PID" ] && kill -0 "$APP_PID" 2>/dev/null; then
    kill "$APP_PID" 2>/dev/null || true
    for _ in $(jot 100 1); do
      if ! kill -0 "$APP_PID" 2>/dev/null; then break; fi
      sleep 0.1
    done
    if kill -0 "$APP_PID" 2>/dev/null; then kill -9 "$APP_PID" 2>/dev/null || true; fi
    wait "$APP_PID" 2>/dev/null || true
  fi
  APP_PID=""
}

restored_seed="$(hash_file "$RESTORED_SAVE")"
prototype_seed="$(hash_file "$PROTOTYPE_SAVE")"

DINOPAD_DATA_ROOT="$DATA_ROOT" "$APP" --profile restored --skip-launcher \
  --window-width 1024 --window-height 768 >"$SCRATCH/restored.log" 2>&1 &
APP_PID=$!
sleep 13
send_space
sleep 4
if [ -n "$EVIDENCE_DIR" ]; then
  mkdir -p "$EVIDENCE_DIR"
  "$ROOT/scripts/capture-window.sh" DinoPad "$EVIDENCE_DIR/profile-restored.png"
fi
send_space
sleep 5
if ! kill -0 "$APP_PID" 2>/dev/null; then
  echo "ERROR: Restored profile exited during smoke" >&2
  exit 1
fi
rg -Fq "DinoPad profile: Restored (namespace=Profiles/Restored)" "$SCRATCH/restored.log" || {
  echo "ERROR: Restored profile marker missing" >&2; exit 1;
}
rg -q "Static restoration dispatch enabled .*no runtime code writes" "$SCRATCH/restored.log" || {
  echo "ERROR: Restored dispatch marker missing" >&2; exit 1;
}
if [ "$(hash_file "$PROTOTYPE_SAVE")" != "$prototype_seed" ]; then
  echo "ERROR: Restored session modified Prototype save" >&2
  exit 1
fi
stop_app
restored_after="$(hash_file "$RESTORED_SAVE")"

DINOPAD_DATA_ROOT="$DATA_ROOT" "$APP" --profile prototype --skip-launcher \
  --window-width 1024 --window-height 768 >"$SCRATCH/prototype.log" 2>&1 &
APP_PID=$!
sleep 12
send_space
sleep 2
send_space
sleep 6
if [ -n "$EVIDENCE_DIR" ]; then
  "$ROOT/scripts/capture-window.sh" DinoPad "$EVIDENCE_DIR/profile-prototype.png"
fi
if ! kill -0 "$APP_PID" 2>/dev/null; then
  echo "ERROR: Prototype profile exited during smoke" >&2
  exit 1
fi
rg -Fq "DinoPad profile: Prototype (namespace=Profiles/Prototype)" "$SCRATCH/prototype.log" || {
  echo "ERROR: Prototype profile marker missing" >&2; exit 1;
}
if rg -q "Using statically linked code|Static restoration dispatch enabled" "$SCRATCH/prototype.log"; then
  echo "ERROR: restoration activated in Prototype profile" >&2
  exit 1
fi
if [ "$(hash_file "$RESTORED_SAVE")" != "$restored_after" ]; then
  echo "ERROR: Prototype session modified Restored save" >&2
  exit 1
fi
stop_app

for profile_root in "$RESTORED_ROOT" "$PROTOTYPE_ROOT"; do
  for config_name in general.json graphics.json controls.json sound.json; do
    if [ ! -f "$profile_root/$config_name" ]; then
      echo "ERROR: missing isolated config $profile_root/$config_name" >&2
      exit 1
    fi
  done
done

if [ -n "$EVIDENCE_DIR" ]; then
  cp "$SCRATCH/restored.log" "$EVIDENCE_DIR/restored-runtime.log"
  cp "$SCRATCH/prototype.log" "$EVIDENCE_DIR/prototype-runtime.log"
fi

echo "PROFILE RESULT: PASS (Restored default-capable; Prototype explicit; saves/config isolated)"
echo "Restored seed: $restored_seed"
echo "Restored after Restored session: $restored_after"
echo "Prototype seed: $prototype_seed"
echo "Prototype after both sessions: $(hash_file "$PROTOTYPE_SAVE")"
