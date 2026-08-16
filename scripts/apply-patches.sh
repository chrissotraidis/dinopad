#!/usr/bin/env bash
# apply-patches.sh - apply the maintained DinoPad patch series to ref checkouts.
# Idempotent: patches already applied are skipped.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

apply_to_repo() {
  local repo="$1" name patch
  name="$(basename "$repo")"
  for patch in "$ROOT"/patches/"$name"/*.patch; do
    [ -f "$patch" ] || continue
    # dino-recomp v0.3.0 mixes CRLF and LF inside several source files. Ignore
    # whitespace only while locating hunks; every added/removed content line
    # remains part of the maintained patch and is verified below.
    if git -C "$repo" apply --check --ignore-space-change "$patch" >/dev/null 2>&1; then
      git -C "$repo" apply --ignore-space-change "$patch"
      echo "applied: ${patch#"$ROOT"/}"
    elif git -C "$repo" apply -R --check --ignore-space-change "$patch" >/dev/null 2>&1; then
      echo "skip (already applied): ${patch#"$ROOT"/}"
    else
      echo "ERROR: patch neither applies nor reverse-applies: $patch" >&2
      exit 1
    fi
  done
}

apply_to_repo ref/paperpad
apply_to_repo ref/SDL2
while IFS= read -r gitdir; do
  apply_to_repo "$(dirname "$gitdir")"
done < <(find ref/dino-recomp ref/dinomod-enhanced-recompiled -name .git \( -type d -o -type f \) 2>/dev/null | sort)
echo "Patch series applied."
