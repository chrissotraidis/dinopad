#!/usr/bin/env bash
# Create a deterministic unsigned DinoPad IPA from the audited physical app.
# Candidate mode is local/private; release mode additionally requires every
# strict rights/package gate to be green.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build-ios-device/Release-iphoneos/DinoPad.app"
OUTPUT=""
MODE=""
DISTRIBUTION="restored"
APP_EXPLICIT=0

usage() {
    echo "usage: scripts/package-ios.sh (--candidate|--release) [--distribution restored|base] [--app DinoPad.app] [--output file.ipa]" >&2
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --candidate|--release)
            [[ -z "$MODE" ]] || { usage; exit 2; }
            MODE="${1#--}"
            shift
            ;;
        --app)
            [[ $# -ge 2 ]] || { usage; exit 2; }
            APP="$2"
            APP_EXPLICIT=1
            shift 2
            ;;
        --distribution)
            [[ $# -ge 2 && ("$2" == restored || "$2" == base) ]] || { usage; exit 2; }
            DISTRIBUTION="$2"
            shift 2
            ;;
        --output)
            [[ $# -ge 2 ]] || { usage; exit 2; }
            OUTPUT="$2"
            shift 2
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

[[ -n "$MODE" ]] || { usage; exit 2; }
if [[ "$APP_EXPLICIT" -eq 0 && "$DISTRIBUTION" == base ]]; then
    APP="$ROOT/build-ios-base/Release-iphoneos/DinoPad.app"
fi
[[ "$APP" = /* ]] || APP="$ROOT/$APP"
[[ -d "$APP" ]] || { echo "ERROR: app not found: $APP" >&2; exit 1; }

"$ROOT/scripts/check-package-safety.sh" --distribution "$DISTRIBUTION" "$APP"
if [[ "$MODE" == release ]]; then
    python3 "$ROOT/tools/validate_package_rights_inventory.py" \
        --require-release-ready --distribution-profile "$DISTRIBUTION" \
        --artifact-app "$APP"
    "$ROOT/scripts/package-release-source.sh" --release
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Info.plist")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Info.plist")"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "ERROR: invalid app version: $VERSION" >&2; exit 1; }
[[ "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || { echo "ERROR: invalid build number: $BUILD_NUMBER" >&2; exit 1; }

if [[ -z "$OUTPUT" ]]; then
    if [[ "$MODE" == candidate ]]; then
        if [[ "$DISTRIBUTION" == base ]]; then
            OUTPUT="$ROOT/artifacts/DinoPad-$VERSION-build.$BUILD_NUMBER-prototype-only-unsigned-candidate.ipa"
        else
            OUTPUT="$ROOT/artifacts/DinoPad-$VERSION-build.$BUILD_NUMBER-$DISTRIBUTION-unsigned-candidate.ipa"
        fi
    else
        if [[ "$DISTRIBUTION" == base ]]; then
            OUTPUT="$ROOT/artifacts/DinoPad-$VERSION-prototype-only-unsigned.ipa"
        else
            OUTPUT="$ROOT/artifacts/DinoPad-$VERSION-$DISTRIBUTION-unsigned.ipa"
        fi
    fi
fi
[[ "$OUTPUT" = /* ]] || OUTPUT="$ROOT/$OUTPUT"
mkdir -p "$(dirname "$OUTPUT")"

PACKAGE_ROOT="$(mktemp -d /tmp/dinopad-package.XXXXXX)"
trap 'rm -rf "$PACKAGE_ROOT"' EXIT
mkdir -p "$PACKAGE_ROOT/Payload"
ditto "$APP" "$PACKAGE_ROOT/Payload/DinoPad.app"

# Normalize archive metadata and file ordering so repeating the package step
# over the same audited app yields byte-identical IPA output.
find "$PACKAGE_ROOT/Payload" -exec touch -h -t 200001010000 {} +
TEMPORARY_IPA="$PACKAGE_ROOT/DinoPad.ipa"
(
    cd "$PACKAGE_ROOT"
    find Payload/DinoPad.app -type f -print | LC_ALL=C sort |
        zip -X -q "$TEMPORARY_IPA" -@
)
mv -f "$TEMPORARY_IPA" "$OUTPUT"

"$ROOT/scripts/audit-ios-ipa.sh" "$OUTPUT" "$APP" "$DISTRIBUTION"
SHA256="$(shasum -a 256 "$OUTPUT" | awk '{print $1}')"
echo "Packaged unsigned DinoPad $VERSION ($BUILD_NUMBER) $DISTRIBUTION $MODE IPA"
echo "IPA: $OUTPUT"
echo "SHA-256: $SHA256"
if [[ "$MODE" == candidate ]]; then
    echo "This is a private candidate, not an authorized public release."
fi
echo "The IPA must be re-signed before installation on a standard device."
