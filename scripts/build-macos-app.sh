#!/usr/bin/env bash
# build-macos-app.sh - build the DinoPad.app macOS bundle and stage the
# private user ROM for local play.
#
# Behavior:
#   1. Verifies the arm64 DinoPad executable exists (build-macos/DinoPad).
#   2. Assembles DinoPad.app with Info.plist, executable, and assets.
#   3. Stages the user-supplied supported ROM into
#      ~/Library/Application Support/DinoPad/dino.z64 (private, OUTSIDE the
#      app bundle) and verifies its MD5.
#   4. Ad-hoc codesigns the bundle so `open DinoPad.app` works locally.
#   5. Prints a ROM-free bundle assertion (no game data inside .app).
#
# The bundle itself never contains game data: the ROM lives in the user's
# Application Support folder, matching the plan's ROM-free rule.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BIN="$ROOT/build-macos/DinoPad"
APP="$ROOT/build-macos/DinoPad.app"
SUPPORT="$HOME/Library/Application Support/DinoPad"
ROM_DEST="$SUPPORT/dino.z64"
EXPECTED_ROM_MD5="49f7bb346ade39d1915c22e090ffd748"
VERSION="0.3.0"

fail() { echo "ERROR: $*" >&2; exit 1; }

echo "== DinoPad macOS app bundle build =="

[ -x "$BIN" ] || fail "missing build-macos/DinoPad; run cmake --build build-macos --target DinoPad first"
file "$BIN" | grep -q arm64 || fail "DinoPad executable is not arm64: $(file "$BIN")"

# ---- Assemble the bundle ----
echo "== assembling $APP =="
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/DinoPad"

# Asset layout matches get_asset_path() (program_path/assets/...):
# program_path on Apple is the bundle Resources dir.
cp -R build-macos/assets "$APP/Contents/Resources/assets"
# Controller mappings file is read from program_path directly.
cp build-macos/recompcontrollerdb.txt "$APP/Contents/Resources/recompcontrollerdb.txt"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>DinoPad</string>
    <key>CFBundleDisplayName</key><string>DinoPad</string>
    <key>CFBundleIdentifier</key><string>com.chrissotraidis.dinopad</string>
    <key>CFBundleExecutable</key><string>DinoPad</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>11.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
EOF

# ---- Stage the private ROM (never inside the bundle) ----
echo "== staging private ROM =="
mkdir -p "$SUPPORT"
if [ -f "$ROM_DEST" ]; then
  # DinoPad-owned validator: detects byte order (.z64/.v64/.n64), normalizes
  # to big-endian, and verifies the supported fingerprint.
  NORMALIZE_OUT="$(python3 "$ROOT/tools/normalize_rom.py" "$ROM_DEST" 2>&1)"
  NORMALIZE_RC=$?
  if [ "$NORMALIZE_RC" = "0" ] && echo "$NORMALIZE_OUT" | grep -qE '^(ALREADY|NORMALIZED)$'; then
    echo "ROM staged and verified: $ROM_DEST ($NORMALIZE_OUT, md5 ok)"
  else
    fail "staged ROM failed validation (rc=$NORMALIZE_RC): $NORMALIZE_OUT. Expected the supported December 2000 prototype (MD5 $EXPECTED_ROM_MD5)."
  fi
else
  fail "no ROM at $ROM_DEST. Copy your supported Dinosaur Planet prototype ROM there first (MD5 $EXPECTED_ROM_MD5); DinoPad never downloads game data."
fi

# ---- Ad-hoc codesign for local launch ----
echo "== codesigning (ad-hoc) =="
codesign --force --deep --sign - "$APP" || fail "codesign failed"

# ---- ROM-free assertion ----
echo "== ROM-free bundle check =="
if find "$APP" -type f \( -name "*.z64" -o -name "*.n64" -o -name "*.v64" -o -name "*.rom" \) | grep -q .; then
  fail "game data found inside the bundle; refusing to produce a ROM-carrying app"
fi
echo "OK: no ROM/game data inside the bundle"

echo
echo "DinoPad.app built: $APP"
echo "ROM (private, outside bundle): $ROM_DEST"
echo "Launch with: open $APP  (or: $APP/Contents/MacOS/DinoPad --skip-launcher --window-width 1024 --window-height 768)"
echo "Bundle size: $(du -sh "$APP" | awk '{print $1}')"
