#!/usr/bin/env bash
# check-repo-safety.sh - repository safety audit for DinoPad.
# Run before every milestone commit and public push.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

failures=0

fail() { echo "FAIL: $*"; failures=$((failures + 1)); }
pass() { echo "PASS: $*"; }

# 1. Forbidden workspace paths must never be tracked.
while IFS= read -r f; do
  case "$f" in
    ref/*|generated/*|private-fixtures/*|.goal-loop/*|build-macos/*|build-ios-simulator/*|build-ios-device/*|build-*)
      fail "forbidden workspace path tracked: $f";;
  esac
done < <(git ls-files)
pass "tracked paths contain no ref/, generated/, build, private-fixture, or lock state"

# 2. Forbidden file types (ROMs, saves, signing material, packages).
while IFS= read -r f; do
  case "${f##*.}" in
    z64|n64|v64|rom|srm|sav|eep|fla|mpk|ipa|mobileprovision|p12|cer|pem|key)
      fail "forbidden file type tracked: $f";;
  esac
done < <(git ls-files)
pass "no ROM, save, signing, or package files tracked"

# 3. No tracked file above 10 MiB without a written exception (ADR).
while IFS= read -r f; do
  if [ -f "$f" ]; then
    size="$(wc -c < "$f")"
    if [ "$size" -gt 10485760 ]; then
      fail "tracked file exceeds 10 MiB: $f ($size bytes)"
    fi
  fi
done < <(git ls-files)
pass "no tracked file exceeds 10 MiB"

# 4. No videos in the tracked tree.
while IFS= read -r f; do
  case "${f##*.}" in
    mp4|mov|mkv|webm|avi|m4v)
      fail "video file tracked: $f";;
  esac
done < <(git ls-files)
pass "no video files tracked"

# 5. No macOS junk files.
while IFS= read -r f; do
  case "$f" in
    .DS_Store|._*|*.DS_Store|__MACOSX/*)
      fail "macOS junk file tracked: $f";;
  esac
done < <(git ls-files)
pass "no .DS_Store or AppleDouble files tracked"

# 6. No private absolute paths in tracked text files.
while IFS= read -r f; do
  case "$f" in
    *.md|*.txt|*.json|*.sh|*.py|*.cmake|*.yml|*.yaml|*.toml|*.plist|*.strings)
      if grep -qE '/Users/[A-Za-z0-9_.-]+/' "$f" 2>/dev/null; then
        fail "private absolute path found in tracked file: $f"
      fi;;
  esac
done < <(git ls-files)
pass "no private absolute paths in tracked text files"

# 7. Untracked, non-ignored files must not be forbidden material about to be added.
while IFS= read -r f; do
  case "$f" in
    ref/*|generated/*|private-fixtures/*|.goal-loop/*|build-macos/*|build-ios-simulator/*|build-ios-device/*|build-*)
      fail "forbidden untracked path not ignored: $f";;
    *.z64|*.n64|*.v64|*.rom|*.srm|*.sav|*.eep|*.fla|*.mpk|*.ipa|*.mobileprovision|*.p12|*.cer|*.pem|*.key)
      fail "forbidden untracked file not ignored: $f";;
  esac
done < <(git ls-files --others --exclude-standard)
pass "untracked non-ignored files are clean"

# 8. The dependency lock records the exact maintained patch set.
expected_patch_checksum="$(python3 -c 'import json; print(json.load(open("dependencies.lock.json"))["notes"]["patch_set"]["sha256"])' 2>/dev/null)"
expected_patch_count="$(python3 -c 'import json; print(json.load(open("dependencies.lock.json"))["notes"]["patch_set"]["file_count"])' 2>/dev/null)"
actual_patch_count="$(find patches -type f -name '*.patch' | wc -l | tr -d ' ')"
actual_patch_checksum="$(find patches -type f -name '*.patch' | LC_ALL=C sort | while IFS= read -r patch; do shasum -a 256 "$patch"; done | shasum -a 256 | awk '{print $1}')"
if [ -z "$expected_patch_checksum" ] || [ "$actual_patch_checksum" != "$expected_patch_checksum" ]; then
  fail "patch-set checksum mismatch: expected ${expected_patch_checksum:-missing}, actual $actual_patch_checksum"
elif [ "$actual_patch_count" != "$expected_patch_count" ]; then
  fail "patch-set file count mismatch: expected $expected_patch_count, actual $actual_patch_count"
else
  pass "patch-set lock matches ($actual_patch_count files, sha256 $actual_patch_checksum)"
fi

# 9. Reference checkouts: only applied patches + whitelisted generated-output
# symlinks may touch a checkout; push URLs must be disabled. Submodule repos
# are verified inside their own repositories against their own patch sets.
check_ref_repo() {
  local repo_dir="$1" name
  name="$(basename "$repo_dir")"
  if [ ! -d "$repo_dir/.git" ] && [ ! -f "$repo_dir/.git" ]; then
    fail "missing reference checkout: $repo_dir"
    return
  fi
  # Files introduced by an applied patch are permitted even though Git reports
  # them as untracked in the read-only reference checkout.
  patched_files="$(grep -h '^diff --git ' "$ROOT"/patches/"$name"/*.patch 2>/dev/null \
    | sed -E 's|^diff --git a/(.*) b/.*|\1|' | tr '\n' ' ')"
  # Untracked files: generated-output symlinks or patch-owned paths only.
  while IFS= read -r f; do
    case "$f" in
      RecompiledFuncs|RecompiledPatches) ;;
      *)
        case " $patched_files " in
          *" $f "*) ;;
          *) fail "untracked file in reference checkout: $repo_dir/$f";;
        esac;;
    esac
  done < <(git -C "$repo_dir" ls-files --others --exclude-standard 2>/dev/null)
  # Modified tracked files must be covered by an applied DinoPad patch set
  # (submodule gitlinks are verified inside the submodule itself).
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if [ -d "$repo_dir/$f/.git" ] || [ -f "$repo_dir/$f/.git" ]; then
      continue  # submodule; checked recursively
    fi
    case " $patched_files " in
      *" $f "*) ;;
      *) fail "modified file not covered by a maintained patch: $repo_dir/$f";;
    esac
  done < <(git -C "$repo_dir" diff --name-only 2>/dev/null)
  # Verify the patch set is currently applied.
  for patch in "$ROOT"/patches/"$name"/*.patch; do
    [ -f "$patch" ] || continue
    if git -C "$repo_dir" apply --check --ignore-space-change "$patch" >/dev/null 2>&1; then
      fail "patch not applied: $patch"
    elif git -C "$repo_dir" apply -R --check --ignore-space-change "$patch" >/dev/null 2>&1; then
      : # applied
    else
      fail "patch neither applies nor reverse-applies: $patch"
    fi
  done
  push_url="$(git -C "$repo_dir" remote get-url --push origin 2>/dev/null)"
  if [ "$push_url" != "DISABLED" ]; then
    fail "reference push URL not disabled: $repo_dir (push = ${push_url:-none})"
  fi
  echo "OK:   reference checkout verified: $repo_dir"
}

check_ref_repo ref/paperpad
check_ref_repo ref/SDL2
while IFS= read -r gitdir; do
  check_ref_repo "$(dirname "$gitdir")"
done < <(find ref/dino-recomp ref/dinomod-enhanced-recompiled -name .git \( -type d -o -type f \) 2>/dev/null | sort)
pass "reference checkouts verified (patches applied, push-disabled)"

if [ "$failures" -eq 0 ]; then
  echo "RESULT: repository safety checks clean"
  exit 0
else
  echo "RESULT: $failures safety failure(s)"
  exit 1
fi
