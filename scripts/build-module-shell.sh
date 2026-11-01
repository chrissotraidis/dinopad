#!/usr/bin/env bash
# Build the unsigned base-only iOS shell without a ROM or restoration inputs.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
[[ $# -eq 0 ]] || { echo "usage: scripts/build-module-shell.sh" >&2; exit 2; }
source "$ROOT/scripts/build-jobs.sh"
JOBS="$(dinopad_build_jobs)"
python3 scripts/setup-module-source.py --shell
python3 tools/package_compiled_dependency_notices.py \
    --target ios-device --destination generated/notices-ios-device
cmake --fresh -S cmake/module-shell-tools -B tmp/shell-tools -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build tmp/shell-tools --parallel "$JOBS"
cmake -S . -B tmp/module-shell -G Xcode \
    -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphoneos -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DDINOPAD_MODULE_SHELL=ON -DDINOPAD_ENABLE_STATIC_RESTORATION=OFF \
    -DDINOPAD_ENABLE_TEST_HARNESS=OFF -DDEVELOPMENT_TEAM= \
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO \
    -DFILE_TO_C_PATH="$ROOT/tmp/shell-tools/file_to_c" \
    -DSPIRV_CROSS_MSL_PATH="$ROOT/tmp/shell-tools/spirv_cross_msl"
cmake --build tmp/module-shell --config Release --target DinoPad -- \
    -quiet -jobs "$JOBS" -sdk iphoneos SKIP_INSTALL=YES CODE_SIGNING_ALLOWED=NO
APP="$ROOT/tmp/module-shell/Release-iphoneos/DinoPad.app"
[[ -x "$APP/DinoPad" ]] || { echo "ERROR: empty module shell was not produced" >&2; exit 1; }
python3 - "$APP/DinoPad" <<'PY'
from pathlib import Path
import sys
sys.path.insert(0, 'scripts')
from module_build import identity
if identity().encode('ascii') not in Path(sys.argv[1]).read_bytes():
    raise SystemExit('The app has a stale module identity; configure and build it again.')
PY
scripts/check-package-safety.sh --distribution base --build-dir tmp/module-shell/build "$APP"
SYMBOLS="$(nm -gjU "$APP/DinoPad")"
if grep -Eq '^(_dp_patches_bin|_recomp_get_func|_func_[0-9A-Fa-f]{8})$' <<<"$SYMBOLS"; then
    echo "ERROR: empty shell contains translated game code" >&2
    exit 1
fi
echo "Private validation shell ready: $APP"
echo "A matching private game module is required before installing this app."
