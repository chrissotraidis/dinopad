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

# 8. Reference checkouts: clean worktrees and disabled push URLs.
for d in ref/paperpad ref/dino-recomp ref/dinomod-enhanced-recompiled; do
  if [ -d "$d/.git" ]; then
    dirty="$(git -C "$d" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
    if [ "$dirty" -ne 0 ]; then
      fail "reference checkout is dirty: $d"
    fi
    push_url="$(git -C "$d" remote get-url --push origin 2>/dev/null)"
    if [ "$push_url" != "DISABLED" ]; then
      fail "reference push URL not disabled: $d (push = ${push_url:-none})"
    fi
  else
    fail "missing reference checkout: $d"
  fi
done
pass "reference checkouts present, clean, and push-disabled"

if [ "$failures" -eq 0 ]; then
  echo "RESULT: repository safety checks clean"
  exit 0
else
  echo "RESULT: $failures safety failure(s)"
  exit 1
fi
