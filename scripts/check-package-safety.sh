#!/usr/bin/env bash
# Audit a built physical-iOS DinoPad.app. This is a development artifact gate,
# not a claim that Phase 10 rights/notices or public packaging are complete.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build-ios-device/Release-iphoneos/DinoPad.app"
ALLOW_SIGNING=0
DISTRIBUTION="restored"

usage() {
    echo "usage: scripts/check-package-safety.sh [--distribution restored|base] [--allow-signing] [DinoPad.app]" >&2
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --allow-signing)
            ALLOW_SIGNING=1
            shift
            ;;
        --distribution)
            [[ $# -ge 2 && ("$2" == restored || "$2" == base) ]] || { usage; exit 2; }
            DISTRIBUTION="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            [[ "$APP" == "$ROOT/build-ios-device/Release-iphoneos/DinoPad.app" ]] || {
                usage
                exit 2
            }
            APP="$1"
            shift
            ;;
    esac
done

[[ "$APP" = /* ]] || APP="$ROOT/$APP"

fail() {
    echo "DinoPad device-app safety audit failed: $*" >&2
    exit 1
}

for command in lipo vtool otool codesign plutil unzip shasum strings rg python3; do
    command -v "$command" >/dev/null || fail "required command is unavailable: $command"
done

[[ -d "$APP" ]] || fail "app not found: $APP"
INFO="$APP/Info.plist"
[[ -f "$INFO" ]] || fail "Info.plist is missing"
PRIVACY_MANIFEST="$APP/PrivacyInfo.xcprivacy"
[[ -f "$PRIVACY_MANIFEST" ]] || fail "PrivacyInfo.xcprivacy is missing"
cmp -s "$ROOT/apple/app/PrivacyInfo.xcprivacy" "$PRIVACY_MANIFEST" ||
    fail "bundled privacy manifest differs from the tracked declaration"
python3 "$ROOT/tools/validate_compiled_dependency_inventory.py" \
    --target ios-device || fail "iOS compiled dependency inventory is invalid"
python3 "$ROOT/tools/package_compiled_dependency_notices.py" \
    --target ios-device --app "$APP" --verify || \
    fail "iOS compiled dependency notice set is invalid"

plist_value() {
    /usr/libexec/PlistBuddy -c "Print :$1" "$INFO"
}

EXPECTED_VERSION="$(sed -n 's/^set(DINOPAD_VERSION "\([0-9][0-9.]*\)")$/\1/p' "$ROOT/CMakeLists.txt")"
EXPECTED_BUILD_NUMBER="$(sed -n 's/^set(DINOPAD_BUILD_NUMBER "\([1-9][0-9]*\)")$/\1/p' "$ROOT/CMakeLists.txt")"

EXECUTABLE_NAME="$(plist_value CFBundleExecutable)"
EXECUTABLE="$APP/$EXECUTABLE_NAME"
[[ -x "$EXECUTABLE" ]] || fail "bundle executable is missing"
EXECUTABLE_STRINGS="$(mktemp /tmp/dinopad-package-strings.XXXXXX)"
trap 'rm -f "$EXECUTABLE_STRINGS"' EXIT
strings -a "$EXECUTABLE" > "$EXECUTABLE_STRINGS"
[[ "$(lipo -archs "$EXECUTABLE")" == arm64 ]] || fail "executable is not arm64-only"
vtool -show-build "$EXECUTABLE" | grep -Eq 'platform +IOS$' ||
    fail "executable is not a physical iOS product"
vtool -show-build "$EXECUTABLE" | grep -Eq 'minos +15\.0$' ||
    fail "executable minimum OS is not iOS 15.0"

[[ "$(plist_value CFBundleIdentifier)" == com.chrissotraidis.dinopad ]] ||
    fail "unexpected bundle identifier"
[[ "$(plist_value CFBundleShortVersionString)" == "$EXPECTED_VERSION" ]] ||
    fail "unexpected app version"
[[ "$(plist_value CFBundleVersion)" == "$EXPECTED_BUILD_NUMBER" ]] ||
    fail "unexpected build number"
[[ "$(plist_value MinimumOSVersion)" == 15.0 ]] ||
    fail "unexpected Info.plist minimum OS"
[[ "$(plist_value ITSAppUsesNonExemptEncryption)" == false ]] ||
    fail "encryption declaration is not false"
plutil -lint "$INFO" >/dev/null || fail "Info.plist is invalid"
plutil -lint "$PRIVACY_MANIFEST" >/dev/null || fail "privacy manifest is invalid"
python3 - "$PRIVACY_MANIFEST" <<'PY' || exit 1
import plistlib
import sys

path = sys.argv[1]
with open(path, "rb") as stream:
    manifest = plistlib.load(stream)

expected = {
    "NSPrivacyAccessedAPICategoryFileTimestamp": {"C617.1", "3B52.1"},
    "NSPrivacyAccessedAPICategoryUserDefaults": {"CA92.1"},
    "NSPrivacyAccessedAPICategorySystemBootTime": {"35F9.1"},
}
actual = {
    entry.get("NSPrivacyAccessedAPIType"): set(entry.get("NSPrivacyAccessedAPITypeReasons", []))
    for entry in manifest.get("NSPrivacyAccessedAPITypes", [])
}
valid = (
    manifest.get("NSPrivacyTracking") is False
    and manifest.get("NSPrivacyTrackingDomains") == []
    and manifest.get("NSPrivacyCollectedDataTypes") == []
    and actual == expected
)
if not valid:
    print("DinoPad device-app safety audit failed: unexpected privacy manifest declaration",
          file=sys.stderr)
    raise SystemExit(1)
PY

if find "$APP" -type f \( \
    -iname '*.z64' -o -iname '*.v64' -o -iname '*.n64' -o -iname '*.rom' -o \
    -iname '*.fla' -o -iname '*.sav' -o -iname '*.srm' -o -iname '*.log' -o \
    -iname '*.p12' -o -iname '*.p8' -o -iname '*.pem' -o -iname '*.key' -o \
    -iname '*.cer' -o -iname '*.dylib' -o -iname '*.so' \
    \) -print -quit | grep -q .; then
    fail "bundle contains game data, a save/log, signing material, or a dynamic library"
fi
if find "$APP" -type d \( -name generated -o -name ref -o -name Logs -o -name Saves \) \
    -print -quit | grep -q .; then
    fail "bundle contains a private build/runtime directory"
fi

if [[ "$ALLOW_SIGNING" -eq 1 ]]; then
    codesign --verify --deep --strict "$APP" || fail "signed app verification failed"
    [[ -f "$APP/embedded.mobileprovision" ]] || fail "signed app has no provisioning profile"
else
    [[ ! -e "$APP/_CodeSignature" && ! -e "$APP/embedded.mobileprovision" ]] ||
        fail "unsigned app contains signing state"
    if codesign --verify --strict "$APP" >/dev/null 2>&1; then
        fail "unsigned app still verifies as signed"
    fi
    if otool -l "$EXECUTABLE" | grep -q 'cmd LC_CODE_SIGNATURE'; then
        fail "unsigned executable retains a code-signature load command"
    fi
fi

if otool -l "$EXECUTABLE" | grep -q 'cmd LC_RPATH'; then
    fail "executable contains a runtime search path"
fi
UNEXPECTED_RUNTIME="$(otool -L "$EXECUTABLE" | awk 'NR > 1 { print $1 }' |
    rg -v '^(/System/Library/|/usr/lib/)' || true)"
[[ -z "$UNEXPECTED_RUNTIME" ]] ||
    fail "executable has an unbundled runtime dependency: $UNEXPECTED_RUNTIME"

if rg -q \
    '/Users/|/Volumes/|/private/var/folders/|github_pat_|gh[pousr]_|AKIA[0-9A-Z]{16}' \
    "$EXECUTABLE_STRINGS"; then
    fail "executable contains a personal build path or likely credential"
fi
if rg -q 'DINOPAD_(RUN|SHOW|HOME|QUIT_TO_HOME|LAYOUT_SMOKE|SETTINGS_SMOKE|ROM_IMPORT_)' \
    "$EXECUTABLE_STRINGS"; then
    fail "physical executable contains a Simulator automation environment key"
fi
if rg -q \
    'beginSimulatedTouchWithID|moveSimulatedTouchWithID|endSimulatedTouchWithID|ForTesting|runAutomationPhase' \
    "$EXECUTABLE_STRINGS"; then
    fail "physical executable contains a test-only selector"
fi
if rg -q 'diagnostic-owner|11111111-2222-3333-4444-555555555555|/tmp/dinopad-private' \
    "$EXECUTABLE_STRINGS"; then
    fail "physical executable contains an adversarial test fixture"
fi

RESTORATION="$APP/dinomod_restoration_data.nrm"
if [[ "$DISTRIBUTION" == restored ]]; then
    GENERATED_RESTORATION="$ROOT/generated/restoration/dinomod_restoration_data.nrm"
    RESTORATION_AUDIT="$ROOT/generated/restoration/dinomod_restoration_data.audit.json"
    [[ -f "$RESTORATION" && -f "$GENERATED_RESTORATION" && -f "$RESTORATION_AUDIT" ]] ||
        fail "audited restoration data inputs are missing"
    cmp -s "$RESTORATION" "$GENERATED_RESTORATION" ||
        fail "bundled restoration data differs from the generated audit input"
    [[ "$(unzip -Z1 "$RESTORATION")" == $'mod.json\nmod_syms.bin\nmod_binary.bin' ]] ||
        fail "restoration data contains unexpected members"
    EXPECTED_RESTORATION_SHA="$(python3 -c \
        'import json,sys; print(json.load(open(sys.argv[1]))["package_sha256"])' \
        "$RESTORATION_AUDIT")"
    ACTUAL_RESTORATION_SHA="$(shasum -a 256 "$RESTORATION" | awk '{print $1}')"
    [[ "$ACTUAL_RESTORATION_SHA" == "$EXPECTED_RESTORATION_SHA" ]] ||
        fail "restoration data checksum does not match its audit"
else
    [[ ! -e "$RESTORATION" ]] || fail "base build contains DinoMod restoration data"
    if rg -q \
        'dinomod_enhanced|Static restoration dispatch enabled|Bundled static restoration|Bundled restoration data registered' \
        "$EXECUTABLE_STRINGS"; then
        fail "base executable contains DinoMod restoration integration"
    fi
    rg -Fq 'Prototype Mode only.' "$EXECUTABLE_STRINGS" ||
        fail "base executable does not identify itself as Prototype Mode only"
    rg -Fq 'DinoMod Enhanced is not included' "$EXECUTABLE_STRINGS" ||
        fail "base executable does not disclose that DinoMod Enhanced is absent"
    rg -Fq 'Restored Adventure requires a private build' "$EXECUTABLE_STRINGS" ||
        fail "base executable does not expose the Restored private-build guide"
    rg -Fq 'github.com/chrissotraidis/dinopad#restored-adventure-private-self-build' \
        "$EXECUTABLE_STRINGS" ||
        fail "base executable does not link to the Restored private-build guide"
fi

echo "DinoPad device-app safety audit passed: $APP"
echo "  executable: arm64, iOS 15.0+, static system dependencies only"
echo "  test harness: absent"
echo "  ROM/save/log/private paths: absent"
echo "  privacy manifest: no tracking/collection; exact required-reason set"
echo "  compiled dependency notices: complete standalone/assembled primary set"
if [[ "$DISTRIBUTION" == restored ]]; then
    echo "  distribution: restored development build"
    echo "  restoration data: sanitized audit input $ACTUAL_RESTORATION_SHA"
else
    echo "  distribution: base public-package input; DinoMod code/data absent"
fi
echo "  signing state: $([[ "$ALLOW_SIGNING" -eq 1 ]] && echo development-signed || echo unsigned)"
echo "NOTE: this technical audit does not itself grant redistribution rights."
