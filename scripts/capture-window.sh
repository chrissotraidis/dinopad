#!/usr/bin/env bash
# capture-window.sh - capture one application window on macOS without
# including unrelated desktop content. Used for DinoPad evidence screenshots.
#
# Usage: scripts/capture-window.sh <owner-name> <output.png>
#
# Resolves the window's CGWindowID and pixel bounds with tools/window_id.swift
# and captures exactly that window with `screencapture -l`. Requires Screen
# Recording permission for the calling terminal/app.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OWNER="${1:?owner name required}"
OUT="${2:?output path required}"
WID_BIN="${DINOPAD_WINDOW_ID_BIN:-$ROOT/build-tools/window_id}"

if [ ! -x "$WID_BIN" ]; then
  mkdir -p "$ROOT/build-tools"
  swiftc -O "$ROOT/tools/window_id.swift" -o "$WID_BIN"
fi

WININFO="$("$WID_BIN" "$OWNER" 2>/dev/null || true)"
if [ -z "$WININFO" ]; then
  echo "capture-window: no on-screen window found for process '$OWNER'" >&2
  exit 1
fi

read -r WIN_ID WX WY WW WH <<< "$WININFO"
echo "capture-window: id=$WIN_ID bounds x=$WX y=$WY w=$WW h=$WH"

screencapture -x -l "$WIN_ID" "$OUT"
echo "capture-window: saved $OUT"
