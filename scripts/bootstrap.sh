#!/usr/bin/env bash
# bootstrap.sh - set up the DinoPad repository from a fresh clone.
#
# - Verifies host prerequisites.
# - Clones (or verifies) the exact pinned reference checkouts into ref/.
# - Disables push URLs on every reference checkout.
# - Verifies resolved commits against dependencies.lock.json.
# - Runs the repository safety audit.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: missing prerequisite: $1" >&2
    return 1
  fi
  echo "OK:   $1 -> $(command -v "$1")"
}

echo "== DinoPad bootstrap =="
echo "== Host prerequisites =="
require_cmd git
require_cmd cmake
require_cmd ninja
require_cmd clang
require_cmd python3
xcodebuild -version >/dev/null 2>&1 || { echo "ERROR: Xcode toolchain not available" >&2; exit 1; }
echo "OK:   Xcode $(xcodebuild -version 2>/dev/null | head -1)"

if ! command -v jq >/dev/null 2>&1 && ! python3 -c 'import json' >/dev/null 2>&1; then
  echo "ERROR: need jq or python3 with json for lock parsing" >&2
  exit 1
fi

lock_ref() {
  python3 - "$1" "$2" <<'PY'
import json, sys
with open("dependencies.lock.json") as fh:
    data = json.load(fh)
for entry in data["entries"]:
    if entry["name"] == sys.argv[1]:
        print(entry[sys.argv[2]])
        break
PY
}

clone_or_verify() {
  local name="$1" dir="$2"
  local url ref commit recursive
  url="$(lock_ref "$name" url)"
  ref="$(lock_ref "$name" ref)"
  commit="$(lock_ref "$name" commit)"
  recursive="$(python3 - "$name" <<'PY'
import json, sys
with open("dependencies.lock.json") as fh:
    data = json.load(fh)
for entry in data["entries"]:
    if entry["name"] == sys.argv[1]:
        print("yes" if entry.get("recursive") else "no")
        break
PY
)"

  if [ -d "$dir/.git" ]; then
    echo "== $name: checkout exists, verifying =="
    got="$(git -C "$dir" rev-parse HEAD)"
    if [ "$got" != "$commit" ]; then
      echo "ERROR: $name at $got, expected $commit" >&2
      exit 1
    fi
    echo "OK:   $name at $got"
    if [ "$recursive" = "yes" ]; then
      git -C "$dir" submodule update --init --recursive
    fi
  else
    echo "== $name: cloning $ref =="
    if [ "$recursive" = "yes" ]; then
      git clone --recursive --branch "$ref" "$url" "$dir"
    else
      git clone --branch "$ref" "$url" "$dir"
      git -C "$dir" submodule update --init 2>/dev/null || true
    fi
    got="$(git -C "$dir" rev-parse HEAD)"
    if [ "$got" != "$commit" ]; then
      echo "ERROR: $name resolved to $got, lock expects $commit" >&2
      echo "       Update dependencies.lock.json deliberately, then rerun." >&2
      exit 1
    fi
    echo "OK:   $name at $got"
  fi
  git -C "$dir" remote set-url --push origin DISABLED
}

mkdir -p ref
clone_or_verify "PaperPad" "ref/paperpad"
clone_or_verify "dino-recomp" "ref/dino-recomp"
clone_or_verify "dinomod-enhanced-recompiled" "ref/dinomod-enhanced-recompiled"
clone_or_verify "SDL2" "ref/SDL2"

# Disable push URLs recursively for every nested reference repository.
while IFS= read -r gitdir; do
  repo="$(dirname "$gitdir")"
  git -C "$repo" remote set-url --push origin DISABLED 2>/dev/null || true
done < <(find ref -name .git -type d 2>/dev/null)

echo "== Reference push URLs =="
for d in ref/paperpad ref/dino-recomp ref/dinomod-enhanced-recompiled ref/SDL2; do
  echo "$d: $(git -C "$d" remote get-url --push origin)"
done

echo "== Maintained patch series =="
scripts/apply-patches.sh

echo "== Repository safety audit =="
scripts/check-repo-safety.sh

echo ""
echo "Bootstrap complete. Reference checkouts are pinned and read-only."
