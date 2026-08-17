#!/usr/bin/env bash
# Build the ROM-free DinoPad app for an Apple Silicon iOS Simulator.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT/build-ios-simulator"
APP="$BUILD_DIR/Release-iphonesimulator/DinoPad.app"

command -v cmake >/dev/null || { echo "ERROR: cmake is required" >&2; exit 1; }
command -v xcodebuild >/dev/null || { echo "ERROR: Xcode is required" >&2; exit 1; }

"$ROOT/scripts/apply-patches.sh"

for required in \
    "$ROOT/generated/aot/RecompiledFuncs/funcs.h" \
    "$ROOT/generated/restoration/dinomod_static_dispatch.c" \
    "$ROOT/generated/restoration/dinomod_restoration_data.nrm" \
    "$ROOT/build-macos/rt64/src/tools/file_to_c/file_to_c" \
    "$ROOT/ref/dino-recomp/lib/rt64/build/bin/spirv_cross_msl"; do
    if [[ ! -e "$required" ]]; then
        echo "ERROR: required generated/host artifact missing: $required" >&2
        exit 1
    fi
done

cmake -S "$ROOT" -B "$BUILD_DIR" -G Xcode \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT=iphonesimulator \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO

cmake --build "$BUILD_DIR" --config Release --target DinoPad -- \
    -quiet -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO

[[ -x "$APP/DinoPad" ]] || { echo "ERROR: Simulator app was not produced" >&2; exit 1; }
if find "$APP" -type f \( -iname '*.z64' -o -iname '*.v64' -o -iname '*.n64' -o -iname '*.rom' \) -print -quit | grep -q .; then
    echo "ERROR: Simulator app unexpectedly contains a ROM" >&2
    exit 1
fi
if ! file "$APP/DinoPad" | grep -q 'Mach-O 64-bit executable arm64'; then
    echo "ERROR: Simulator executable is not arm64 Mach-O" >&2
    exit 1
fi

echo "DinoPad iOS Simulator app ready: $APP"
