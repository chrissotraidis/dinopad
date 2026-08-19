#!/usr/bin/env bash
# Audit a DinoPad unsigned IPA by extracting it and rerunning the physical-app
# safety gate against the exact payload bytes.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IPA="${1:-}"
SOURCE_APP="${2:-$ROOT/build-ios-device/Release-iphoneos/DinoPad.app}"
DISTRIBUTION="${3:-restored}"

fail() { echo "DinoPad IPA audit failed: $*" >&2; exit 1; }

[[ -n "$IPA" ]] || fail "usage: scripts/audit-ios-ipa.sh IPA [source-app] [restored|base]"
[[ "$DISTRIBUTION" == restored || "$DISTRIBUTION" == base ]] ||
    fail "distribution must be restored or base"
[[ "$IPA" = /* ]] || IPA="$ROOT/$IPA"
[[ "$SOURCE_APP" = /* ]] || SOURCE_APP="$ROOT/$SOURCE_APP"
[[ -f "$IPA" ]] || fail "IPA not found: $IPA"
[[ -d "$SOURCE_APP" ]] || fail "source app not found: $SOURCE_APP"

unzip -tq "$IPA" >/dev/null || fail "ZIP integrity check failed"
ENTRIES="$(unzip -Z1 "$IPA")"
printf '%s\n' "$ENTRIES" | rg -Fxq 'Payload/DinoPad.app/DinoPad' ||
    fail "payload executable is missing"
if printf '%s\n' "$ENTRIES" | rg -q '(^|/)\.\.(/|$)|^/|(^|/)__MACOSX(/|$)'; then
    fail "archive contains an unsafe or resource-fork path"
fi
if printf '%s\n' "$ENTRIES" | rg -vq '^Payload/DinoPad\.app/'; then
    fail "archive contains content outside Payload/DinoPad.app"
fi

EXTRACT_ROOT="$(mktemp -d /tmp/dinopad-ipa-audit.XXXXXX)"
trap 'rm -rf "$EXTRACT_ROOT"' EXIT
unzip -q "$IPA" -d "$EXTRACT_ROOT"
APP_COUNT="$(find "$EXTRACT_ROOT/Payload" -mindepth 1 -maxdepth 1 -type d -name '*.app' | wc -l | tr -d ' ')"
[[ "$APP_COUNT" -eq 1 ]] || fail "archive must contain exactly one app"
PACKAGED_APP="$EXTRACT_ROOT/Payload/DinoPad.app"

"$ROOT/scripts/check-package-safety.sh" --distribution "$DISTRIBUTION" "$PACKAGED_APP"
SOURCE_SHA="$(shasum -a 256 "$SOURCE_APP/DinoPad" | awk '{print $1}')"
PACKAGED_SHA="$(shasum -a 256 "$PACKAGED_APP/DinoPad" | awk '{print $1}')"
[[ "$SOURCE_SHA" == "$PACKAGED_SHA" ]] || fail "packaged executable differs from audited source app"

echo "DinoPad IPA audit passed: $IPA"
echo "  payload executable sha256: $PACKAGED_SHA"
echo "  signing state: unsigned; re-signing required for installation"
echo "NOTE: archive safety is not redistribution permission or public-release approval."
