#!/usr/bin/env bash
# Build DinoPad for physical iPhone/iPad. The default output is unsigned;
# pass --team only when a personal Apple Development team is available.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT/build-ios-device"
APP="$BUILD_DIR/Release-iphoneos/DinoPad.app"
TEAM=""
ALLOW_PROVISIONING=0

usage() {
    echo "usage: scripts/build-ios-device.sh [--team TEAM_ID] [--allow-provisioning-updates]" >&2
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --team)
            [[ $# -ge 2 ]] || { usage; exit 2; }
            TEAM="$2"
            shift 2
            ;;
        --allow-provisioning-updates)
            ALLOW_PROVISIONING=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage
            exit 2
            ;;
    esac
done

if [[ -n "$TEAM" && ! "$TEAM" =~ ^[A-Z0-9]{10}$ ]]; then
    echo "ERROR: --team must be a 10-character Apple Development team ID" >&2
    exit 2
fi
if [[ "$ALLOW_PROVISIONING" -eq 1 && -z "$TEAM" ]]; then
    echo "ERROR: --allow-provisioning-updates requires --team" >&2
    exit 2
fi

command -v cmake >/dev/null || { echo "ERROR: cmake is required" >&2; exit 1; }
command -v xcodebuild >/dev/null || { echo "ERROR: Xcode is required" >&2; exit 1; }
command -v vtool >/dev/null || { echo "ERROR: vtool is required" >&2; exit 1; }

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

configure_args=(
    -S "$ROOT" -B "$BUILD_DIR" -G Xcode
    -DCMAKE_SYSTEM_NAME=iOS
    -DCMAKE_OSX_SYSROOT=iphoneos
    -DCMAKE_OSX_ARCHITECTURES=arm64
    -DDINOPAD_ENABLE_TEST_HARNESS=OFF
)
build_args=(-quiet -sdk iphoneos)

if [[ -n "$TEAM" ]]; then
    configure_args+=(
        -DDEVELOPMENT_TEAM="$TEAM"
        -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=YES
    )
    build_args+=(CODE_SIGNING_ALLOWED=YES CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM="$TEAM")
    if [[ "$ALLOW_PROVISIONING" -eq 1 ]]; then
        build_args+=(-allowProvisioningUpdates)
    fi
else
    configure_args+=(
        -DDEVELOPMENT_TEAM=
        -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO
    )
    build_args+=(CODE_SIGNING_ALLOWED=NO)
fi

cmake "${configure_args[@]}"
cmake --build "$BUILD_DIR" --config Release --target DinoPad -- "${build_args[@]}"

[[ -x "$APP/DinoPad" ]] || { echo "ERROR: physical-device app was not produced" >&2; exit 1; }
[[ "$(lipo -archs "$APP/DinoPad")" == "arm64" ]] || {
    echo "ERROR: physical-device executable is not arm64-only" >&2
    exit 1
}
vtool -show-build "$APP/DinoPad" | grep -q 'platform IOS$' || {
    echo "ERROR: executable is not built for the physical iOS platform" >&2
    exit 1
}
if find "$APP" -type f \( -iname '*.z64' -o -iname '*.v64' -o -iname '*.n64' -o -iname '*.rom' \) -print -quit | grep -q .; then
    echo "ERROR: physical-device app unexpectedly contains a ROM" >&2
    exit 1
fi

if [[ -n "$TEAM" ]]; then
    codesign --verify --deep --strict "$APP"
    [[ -f "$APP/embedded.mobileprovision" ]] || {
        echo "ERROR: signed device app has no embedded provisioning profile" >&2
        exit 1
    }
    echo "DinoPad signed iOS device app ready: $APP"
    "$ROOT/scripts/check-package-safety.sh" --allow-signing "$APP"
else
    [[ ! -e "$APP/_CodeSignature" && ! -e "$APP/embedded.mobileprovision" ]] || {
        echo "ERROR: unsigned device app unexpectedly contains signing state" >&2
        exit 1
    }
    echo "DinoPad unsigned iOS device app ready: $APP"
    "$ROOT/scripts/check-package-safety.sh" "$APP"
fi
