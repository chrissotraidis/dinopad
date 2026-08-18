#!/usr/bin/env bash
# Audit a development macOS app bundle. This proves technical package hygiene;
# it does not close rights, notices, progression, notarization, or release gates.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${1:-$ROOT/build-macos/DinoPad.app}"
EXE="$APP/Contents/MacOS/DinoPad"
PLIST="$APP/Contents/Info.plist"

fail() { echo "ERROR: $*" >&2; exit 1; }

[ -d "$APP" ] || fail "app bundle not found: $APP"
[ -x "$EXE" ] || fail "app executable missing: $EXE"
[ -f "$PLIST" ] || fail "Info.plist missing: $PLIST"

plutil -lint "$PLIST" >/dev/null || fail "invalid Info.plist"
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$PLIST")" = \
  "com.chrissotraidis.dinopad" ] || fail "unexpected bundle identifier"
[ "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$PLIST")" = \
  "11.0" ] || fail "unexpected minimum macOS version"
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")" = \
  "0.1.0" ] || fail "unexpected app version"
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST")" = \
  "1" ] || fail "unexpected build number"

file "$EXE" | grep -q 'Mach-O 64-bit executable arm64' || \
  fail "executable is not arm64 Mach-O"
build_info="$(xcrun vtool -show-build "$EXE")"
echo "$build_info" | grep -Eq 'platform[[:space:]]+MACOS' || \
  fail "executable platform is not macOS"
echo "$build_info" | grep -Eq 'minos[[:space:]]+11\.0([[:space:]]|$)' || \
  fail "executable minimum macOS version is not 11.0"

bad_dependencies="$(otool -L "$EXE" | tail -n +2 | awk '{print $1}' | \
  grep -Ev '^(/System/Library/|/usr/lib/)' || true)"
[ -z "$bad_dependencies" ] || \
  fail "non-system runtime dependencies found: $bad_dependencies"

bundle_symlink="$(find "$APP" -type l -print -quit)"
[ -z "$bundle_symlink" ] || fail "symbolic link found in app bundle: $bundle_symlink"

if find "$APP" -type f \( \
    -iname '*.z64' -o -iname '*.v64' -o -iname '*.n64' -o -iname '*.rom' -o \
    -iname '*.sav' -o -iname '*.srm' -o -iname '*.eep' -o -iname '*.fla' -o \
    -iname '*.mpk' -o -iname '*.nrm' -o -iname '*.log' -o \
    -iname '*.mobileprovision' -o -iname '*.p12' -o -iname '*.cer' -o \
    -iname '*.pem' -o -iname '*.key' \) -print -quit | grep -q .; then
  fail "forbidden game/save/log/signing/package material found"
fi

if strings -a "$EXE" | grep -Eq '/Users/[A-Za-z0-9_.-]+/'; then
  fail "personal absolute path found in executable"
fi
if strings -a "$EXE" | grep -Eq \
    'DinoFont\.otf|NotoEmoji-Regular\.ttf|images/DPLogo\.png|images/krazoa\.png'; then
  fail "removed launcher font/art reference found in executable"
fi
if grep -RIlE '/Users/[A-Za-z0-9_.-]+/' "$APP/Contents/Resources" \
    2>/dev/null | grep -q .; then
  fail "personal absolute path found in resources"
fi

for removed_resource in \
    assets/DinoFont.otf \
    assets/NotoEmoji-Regular.ttf \
    assets/images/DPLogo.png \
    assets/images/krazoa.png \
    assets/scss; do
  [ ! -e "$APP/Contents/Resources/$removed_resource" ] || \
    fail "unreviewed/development-only resource packaged: $removed_resource"
done
if grep -RIEq 'DinoFont|NotoEmoji|DPLogo|krazoa\.png|PriskaSerif|font-family:chiaro' \
    "$APP/Contents/Resources/assets" 2>/dev/null; then
  fail "removed font/art resource is still referenced by packaged UI files"
fi
cmp -s "$ROOT/notices/Lato-NOTICE.txt" \
  "$APP/Contents/Resources/Notices/Lato-NOTICE.txt" || \
  fail "Lato notice is missing or modified"
cmp -s "$ROOT/ref/dino-recomp/assets/promptfont/LICENSE.txt" \
  "$APP/Contents/Resources/Notices/OFL-1.1.txt" || \
  fail "SIL Open Font License text is missing or modified"
python3 "$ROOT/tools/validate_compiled_dependency_inventory.py" || \
  fail "compiled dependency inventory is invalid"
python3 "$ROOT/tools/package_compiled_dependency_notices.py" \
  --app "$APP" --verify || fail "compiled dependency notice set is invalid"

codesign --verify --deep --strict "$APP" >/dev/null 2>&1 || \
  fail "bundle signature verification failed"
signature="$(codesign -dvv "$APP" 2>&1 | awk -F= '/^Signature=/{print $2}')"
[ "$signature" = "adhoc" ] || fail "development bundle is not ad-hoc signed"

echo "DinoPad macOS app safety audit passed: $APP"
echo "  executable: arm64, macOS 11.0+, system runtime dependencies only"
echo "  ROM/save/log/private paths: absent"
echo "  removed launcher fonts/art and development-only Sass: absent"
echo "  compiled dependency notices: exact standalone set assembled; inline sources pending"
echo "  signing state: ad-hoc development signature"
echo "NOTE: rights/notices, physical testing, notarization, and release remain separate blockers."
