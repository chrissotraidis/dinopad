#!/usr/bin/env bash
# Package the exact tracked DinoPad source snapshot that corresponds to a
# binary candidate. Upstream source pins and fetch locations are recorded in
# dependencies.lock.json; private ROM/AOT/ref trees are deliberately excluded.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE=""
OUTPUT=""

usage() {
    echo "usage: scripts/package-release-source.sh (--candidate|--release) [--output file.zip]" >&2
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --candidate|--release)
            [[ -z "$MODE" ]] || { usage; exit 2; }
            MODE="${1#--}"
            shift
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
git -C "$ROOT" diff --quiet --ignore-submodules -- || {
    echo "ERROR: tracked working tree is dirty" >&2
    exit 1
}
git -C "$ROOT" diff --cached --quiet --ignore-submodules -- || {
    echo "ERROR: staged changes are not committed" >&2
    exit 1
}

VERSION="$(sed -n 's/^set(DINOPAD_VERSION "\([0-9][0-9.]*\)")$/\1/p' "$ROOT/CMakeLists.txt")"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo "ERROR: could not read DinoPad version" >&2
    exit 1
}
COMMIT="$(git -C "$ROOT" rev-parse HEAD)"
if [[ "$MODE" == release ]]; then
    git -C "$ROOT" describe --tags --exact-match --match "v$VERSION" HEAD >/dev/null 2>&1 || {
        echo "ERROR: release source must be built from exact tag v$VERSION" >&2
        exit 1
    }
fi

if [[ -z "$OUTPUT" ]]; then
    OUTPUT="$ROOT/artifacts/DinoPad-$VERSION-source-$MODE.zip"
fi
[[ "$OUTPUT" = /* ]] || OUTPUT="$ROOT/$OUTPUT"
mkdir -p "$(dirname "$OUTPUT")"

PACKAGE_ROOT="$(mktemp -d /tmp/dinopad-source.XXXXXX)"
trap 'rm -rf "$PACKAGE_ROOT"' EXIT
PREFIX="DinoPad-$VERSION-source"
mkdir -p "$PACKAGE_ROOT/$PREFIX"
git -C "$ROOT" archive HEAD | tar -xf - -C "$PACKAGE_ROOT/$PREFIX"
printf 'DinoPad %s source snapshot\nCommit: %s\nMode: %s\n' \
    "$VERSION" "$COMMIT" "$MODE" > "$PACKAGE_ROOT/$PREFIX/SOURCE_SNAPSHOT.txt"

for required in LICENSE docs/LICENSE_SCOPE.md dependencies.lock.json \
        scripts/bootstrap.sh scripts/apply-patches.sh; do
    [[ -f "$PACKAGE_ROOT/$PREFIX/$required" ]] || {
        echo "ERROR: source snapshot is missing $required" >&2
        exit 1
    }
done
if find "$PACKAGE_ROOT/$PREFIX" -type f \( \
        -iname '*.z64' -o -iname '*.v64' -o -iname '*.n64' -o \
        -iname '*.sav' -o -iname '*.mobileprovision' -o -iname '*.ipa' \
        \) -print -quit | grep -q .; then
    echo "ERROR: source snapshot contains prohibited private or binary material" >&2
    exit 1
fi

find "$PACKAGE_ROOT/$PREFIX" -exec touch -h -t 200001010000 {} +
TEMPORARY_ZIP="$PACKAGE_ROOT/source.zip"
(
    cd "$PACKAGE_ROOT"
    find "$PREFIX" -type f -print | LC_ALL=C sort | zip -X -q "$TEMPORARY_ZIP" -@
)
mv -f "$TEMPORARY_ZIP" "$OUTPUT"
unzip -tq "$OUTPUT" >/dev/null
SHA256="$(shasum -a 256 "$OUTPUT" | awk '{print $1}')"
echo "DinoPad matching tracked-source archive ready: $OUTPUT"
echo "Commit: $COMMIT"
echo "SHA-256: $SHA256"
echo "Exact third-party pins and fetch locations: dependencies.lock.json"
