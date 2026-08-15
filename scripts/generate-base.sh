#!/usr/bin/env bash
# generate-base.sh - generate the private base DinoPad AOT output from the
# user-supplied supported ROM.
#
# Usage: scripts/generate-base.sh [--rom /absolute/path/to/rom]
#
# Everything produced is ROM-derived and lives only under ignored generated/.
# Outputs:
#   generated/rom/baserom.z64            normalized private ROM (copy)
#   generated/rom/baserom.patched.z64    recompiler-prerequisite patched ROM
#   generated/aot/RecompiledFuncs/       base game code C (N64Recomp)
#   generated/aot/rsp/aspMain.cpp        audio microcode C (RSPRecomp)
#   generated/patches/build/patches.elf  MIPS patch library ELF
#   generated/aot/RecompiledPatches/     recompiled patches C + overlays + bin
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SUPPORTED_MD5="49f7bb346ade39d1915c22e090ffd748"
DINO_RECOMP="ref/dino-recomp"
ROM_ARG=""
while (($#)); do
  case "$1" in
    --rom) (($# >= 2)) || { echo "ERROR: --rom requires a path" >&2; exit 2; }; ROM_ARG=$2; shift 2 ;;
    *) echo "usage: generate-base.sh [--rom /absolute/path/to/rom]" >&2; exit 2 ;;
  esac
done

PY=""
for p in python3.13 python3.12 python3.11 python3.10 python3.9; do
  if command -v "$p" >/dev/null 2>&1; then PY=$p; break; fi
done
if [ -z "$PY" ]; then
  echo "ERROR: need Python >= 3.9 (recomp_rom_patcher.py uses subscriptable generics)" >&2
  exit 1
fi

MIPS_BIN="$ROOT/build-tools/toolchains/mips-clang/nrs_bin"
test -x "$MIPS_BIN/clang" || { echo "ERROR: run scripts/build-tools.sh first (MIPS clang missing)" >&2; exit 1; }
test -x "$ROOT/build-tools/N64Recomp" || { echo "ERROR: run scripts/build-tools.sh first (N64Recomp missing)" >&2; exit 1; }

mkdir -p generated/rom generated/aot/rsp generated/patches

echo "== 1. Private ROM =="
if [ -n "$ROM_ARG" ]; then
  cp "$ROM_ARG" generated/rom/baserom.z64
fi
if [ ! -f generated/rom/baserom.z64 ]; then
  echo "ERROR: generated/rom/baserom.z64 missing; pass --rom" >&2
  exit 1
fi
got_md5="$(md5 -q generated/rom/baserom.z64)"
if [ "$got_md5" != "$SUPPORTED_MD5" ]; then
  echo "ERROR: ROM fingerprint mismatch: $got_md5 (expected $SUPPORTED_MD5)" >&2
  exit 1
fi
echo "OK: private ROM fingerprint verified (not logged further)"

echo "== 2. Patch ROM for the recompiler =="
if [ ! -f generated/rom/baserom.patched.z64 ]; then
  "$PY" "$DINO_RECOMP/lib/dino-recomp-decomp-bridge/dinosaur-planet/tools/recomp_rom_patcher.py" \
    -o generated/rom/baserom.patched.z64 generated/rom/baserom.z64
fi
test -s generated/rom/baserom.patched.z64
echo "OK: patched ROM ready"

echo "== 3. Prepare DinoPad-owned recomp configs =="
sed -e 's|^rom_file_path = "baserom.patched.z64"|rom_file_path = "rom/baserom.patched.z64"|' \
    -e 's|^output_func_path = "RecompiledFuncs"|output_func_path = "aot/RecompiledFuncs"|' \
    -e 's|^symbols_file_path = "lib/dino-recomp-decomp-bridge/dino.syms.toml"|symbols_file_path = "../ref/dino-recomp/lib/dino-recomp-decomp-bridge/dino.syms.toml"|' \
    -e 's|^relocatable_sections_path = "lib/dino-recomp-decomp-bridge/dino.dlls.txt"|relocatable_sections_path = "../ref/dino-recomp/lib/dino-recomp-decomp-bridge/dino.dlls.txt"|' \
    "$DINO_RECOMP/dino.toml" > generated/dino.toml

sed -e 's|^rom_file_path = "baserom.patched.z64"|rom_file_path = "rom/baserom.patched.z64"|' \
    -e 's|^output_file_path = "rsp/aspMain.cpp"|output_file_path = "aot/rsp/aspMain.cpp"|' \
    "$DINO_RECOMP/aspMain.toml" > generated/aspMain.toml

sed -e 's|^elf_path = "patches/build/patches.elf"|elf_path = "patches/build/patches.elf"|' \
    -e 's|^output_func_path = "RecompiledPatches"|output_func_path = "aot/RecompiledPatches"|' \
    -e 's|^func_reference_syms_file = "lib/dino-recomp-decomp-bridge/dino.syms.toml"|func_reference_syms_file = "../ref/dino-recomp/lib/dino-recomp-decomp-bridge/dino.syms.toml"|' \
    -e 's|"lib/dino-recomp-decomp-bridge/dino.datasyms.toml"|"../ref/dino-recomp/lib/dino-recomp-decomp-bridge/dino.datasyms.toml"|g' \
    -e 's|"lib/dino-recomp-decomp-bridge/dino.datasyms_manual.toml"|"../ref/dino-recomp/lib/dino-recomp-decomp-bridge/dino.datasyms_manual.toml"|g' \
    -e 's|^output_binary_path = "patches/build/patches.bin"|output_binary_path = "patches/build/patches.bin"|' \
    "$DINO_RECOMP/patches.toml" > generated/patches.toml

echo "== 4. Patch library source (outside ref/, via symlinked lib) =="
if [ ! -f generated/patches/Makefile ]; then
  rsync -a --exclude build/ "$DINO_RECOMP/patches/" generated/patches/
fi
if [ ! -e generated/lib ]; then
  ln -s ../ref/dino-recomp/lib generated/lib
fi

echo "== 5. Build MIPS patch library ELF =="
make -C generated/patches -j "${DINOPAD_MAX_JOBS:-4}" \
  CC="$MIPS_BIN/clang" LD="$MIPS_BIN/ld.lld"
test -s generated/patches/build/patches.elf
echo "OK: patches.elf built"

echo "== 6. Generate base game AOT C (N64Recomp) =="
(cd generated && ../build-tools/N64Recomp dino.toml)
test -d generated/aot/RecompiledFuncs
nfuncs="$(find generated/aot/RecompiledFuncs -type f | wc -l | tr -d ' ')"
echo "OK: RecompiledFuncs emitted ($nfuncs files)"

echo "== 7. Generate audio RSP C (RSPRecomp) =="
(cd generated && ../build-tools/RSPRecomp aspMain.toml)
test -s generated/aot/rsp/aspMain.cpp
echo "OK: aspMain.cpp emitted"

echo "== 8. Recompile patch library (RecompPatcher) =="
(cd generated && ../build-tools/N64Recomp patches.toml)
test -s generated/aot/RecompiledPatches/patches.c
test -s generated/patches/build/patches.bin
echo "OK: RecompiledPatches emitted"

echo "== 9. Embed patch binary as C =="
mkdir -p generated/aot/RecompiledPatches
"$PY" tools/file_to_c.py generated/patches/build/patches.bin dp_patches_bin \
  generated/aot/RecompiledPatches/patches_bin.c generated/aot/RecompiledPatches/patches_bin.h

echo ""
echo "== Base AOT generation complete =="
du -sh generated/aot generated/rom generated/patches 2>/dev/null
