#!/usr/bin/env bash
# generate-restoration.sh - build the pinned DinoMod package and emit static C.
#
# Phase 3 technical goal: prove the offline/AOT path for the pinned DinoMod
# Enhanced package. This script performs the private, build-time steps:
#
#   1. Build the MIPS mod ELF with the pinned n64recomp-clang toolchain.
#   2. Run RecompModTool to produce mod_syms.bin, mod_binary.bin, mod.json,
#      and the .nrm package.
#   3. Run OfflineModRecomp to emit C that DinoPad can compile statically.
#   4. On macOS, compile the emitted C into the runtime's diagnostic offline
#      dylib format for the full replacement/hook feasibility test. This is
#      not the iOS production packaging path.
#
# Outputs go under .goal-loop/dinomod-aot/ (ignored, private). Nothing in this
# script downloads or distributes game data or DinoMod source; it consumes the
# already-pinned read-only checkout in ref/ and the user's private ROM (via the
# mod's own asset pipeline, which runs against ref/DINO/rom).
#
# Prerequisites (documented in docs/DINOMOD_INTEGRATION.md):
#   - xdelta3 (brew install xdelta)
#   - Python 3.9+ with PyYAML, toml, pylibyaml (venv at .goal-loop/dinomod-venv)
#   - make, zip, and the MIPS clang toolchain in build-tools/toolchains/
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MOD_DIR="ref/dinomod-enhanced-recompiled/dinomod_enhanced"
MOD_REPO="ref/dinomod-enhanced-recompiled"
TC_BIN="$(pwd)/build-tools/toolchains/mips-clang/nrs_bin"
OUT_DIR=".goal-loop/dinomod-aot"
VENV_PY=".goal-loop/dinomod-venv/bin/python"

if [[ ! -x "$TC_BIN/clang" ]]; then
    echo "ERROR: MIPS toolchain not found at $TC_BIN" >&2
    exit 1
fi
if [[ ! -x "$VENV_PY" ]]; then
    echo "ERROR: Python venv not found at $VENV_PY" >&2
    exit 1
fi
if ! command -v xdelta3 >/dev/null 2>&1; then
    echo "ERROR: xdelta3 required (brew install xdelta)" >&2
    exit 1
fi

# The mod's asset pipeline needs the private ROM FST. Verify the private ROM
# fingerprint without printing its path beyond what the repo already records.
PRIVATE_ROM="ref/DINO/rom"
if [[ ! -f "$PRIVATE_ROM" ]]; then
    echo "ERROR: private ROM not present at $PRIVATE_ROM" >&2
    exit 1
fi
ROM_MD5="$(md5 -q "$PRIVATE_ROM")"
if [[ "$ROM_MD5" != "49f7bb346ade39d1915c22e090ffd748" ]]; then
    echo "ERROR: private ROM fingerprint mismatch" >&2
    exit 1
fi

mkdir -p "$OUT_DIR"

# 1. Extract the ROM's FST and build the mod's patched assets (private, in ref/).
echo "== Extracting ROM FST (private) =="
if [[ ! -d "$MOD_REPO/bin" ]]; then
    (cd "$MOD_REPO" && "$ROOT/$VENV_PY" tools/extract.py --rom "$ROOT/$PRIVATE_ROM" --bin bin --extract extract)
fi

echo "== Building mod assets =="
(cd "$MOD_REPO" && "$ROOT/$VENV_PY" tools/build_assets.py)

# 2. Build the MIPS mod ELF with the pinned n64recomp-clang toolchain.
echo "== Building mod ELF =="
(
    cd "$MOD_DIR"
    export PATH="$TC_BIN:$PATH"
    make -j"${DINOPAD_MAX_JOBS:-4}"
)

# 3. Produce the .nrm + mod symbol/binary files.
echo "== Running RecompModTool =="
"$(pwd)/build-tools/RecompModTool" "$MOD_DIR/mod.toml" "$OUT_DIR"

# 4. Emit static C with OfflineModRecomp.
echo "== Running OfflineModRecomp =="
"$(pwd)/build-tools/OfflineModRecomp" \
    "$OUT_DIR/mod_syms.bin" \
    "$OUT_DIR/mod_binary.bin" \
    "$MOD_REPO/lib/dino-recomp-decomp-bridge/dino.syms.toml" \
    "$OUT_DIR/dinomod_enhanced.c"

# 5. Build N64ModernRuntime's macOS offline-mod developer format. The package
# filename suffix selects the precompiled code handle, avoiding live/JIT
# recompilation while the production static bridge is brought up separately.
if [[ "$(uname -s)" == "Darwin" ]]; then
    echo "== Building macOS offline AOT library =="
    clang -dynamiclib -O2 -target arm64-apple-macos \
        -I include \
        -I "$MOD_REPO/../dino-recomp/lib/N64Recomp/include" \
        "$OUT_DIR/dinomod_enhanced.c" \
        -Wl,-install_name,@rpath/dinomod_enhanced.offline.dylib \
        -o "$OUT_DIR/dinomod_enhanced.offline.dylib"
    cp "$OUT_DIR/dinomod_enhanced.nrm" "$OUT_DIR/dinomod_enhanced.offline.nrm"
fi

echo "== Done =="
ls -la "$OUT_DIR"
shasum -a 256 "$OUT_DIR/dinomod_enhanced.nrm" "$OUT_DIR/mod_syms.bin" "$OUT_DIR/dinomod_enhanced.c"
if [[ -f "$OUT_DIR/dinomod_enhanced.offline.dylib" ]]; then
    shasum -a 256 "$OUT_DIR/dinomod_enhanced.offline.dylib"
fi
