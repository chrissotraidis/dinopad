#!/usr/bin/env bash
# build-tools.sh - build the pinned N64Recomp host tools on Apple Silicon and
# fetch the upstream-recommended MIPS-targeting Clang toolchain used for the
# recompiled patch library.
#
# Downloads:
#   n64recomp-clang release-22.1.8 Darwin-arm64 ClangEssentialsAndN64Recomp
#   (MIPS-only Clang + ld.lld; documented by dino-recomp BUILDING.md)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

N64RECOMP_SRC="ref/dino-recomp/lib/N64Recomp"
HOST_TOOLS="$ROOT/build-tools"
TOOLCHAIN_DIR="$HOST_TOOLS/toolchains/mips-clang"
TOOLCHAIN_TARBALL="$HOST_TOOLS/toolchains/mips-clang.tar.xz"

MIPS_CLANG_VERSION="release-22.1.8"
MIPS_CLANG_ASSET="Darwin-arm64-ClangEssentialsAndN64Recomp-ClangVersion22.1.8-MipsOnly.tar.xz"
MIPS_CLANG_URL="https://github.com/LT-Schmiddy/n64recomp-clang/releases/download/${MIPS_CLANG_VERSION}/${MIPS_CLANG_ASSET}"

JOBS="${DINOPAD_MAX_JOBS:-4}"

echo "== Building N64Recomp host tools from pinned source =="
cmake -S "$N64RECOMP_SRC" -B "$HOST_TOOLS" -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build "$HOST_TOOLS" --parallel "$JOBS" --target N64Recomp RSPRecomp OfflineModRecomp RecompModMerger RecompModTool

for t in N64Recomp RSPRecomp OfflineModRecomp RecompModMerger RecompModTool; do
  test -x "$HOST_TOOLS/$t" || { echo "ERROR: $t not produced" >&2; exit 1; }
done
echo "OK: host tools built in $HOST_TOOLS"

if [ -x "$TOOLCHAIN_DIR/nrs_bin/clang" ]; then
  echo "== MIPS Clang toolchain already present: $TOOLCHAIN_DIR =="
else
  echo "== Fetching MIPS Clang toolchain ($MIPS_CLANG_VERSION) =="
  mkdir -p "$HOST_TOOLS/toolchains"
  curl -sL -o "$TOOLCHAIN_TARBALL" "$MIPS_CLANG_URL"
  mkdir -p "$TOOLCHAIN_DIR"
  tar -xf "$TOOLCHAIN_TARBALL" -C "$TOOLCHAIN_DIR"
fi

test -x "$TOOLCHAIN_DIR/nrs_bin/clang" || { echo "ERROR: MIPS clang missing" >&2; exit 1; }
test -x "$TOOLCHAIN_DIR/nrs_bin/ld.lld" || { echo "ERROR: MIPS ld.lld missing" >&2; exit 1; }

# Prove the toolchain actually targets MIPS.
printf 'int f(void){return 42;}\n' > "$HOST_TOOLS/toolchains/mips_probe.c"
"$TOOLCHAIN_DIR/nrs_bin/clang" -target mips -mips2 -mabi=32 -O2 -c \
  "$HOST_TOOLS/toolchains/mips_probe.c" -o "$HOST_TOOLS/toolchains/mips_probe.o"
file "$HOST_TOOLS/toolchains/mips_probe.o" | grep -q 'MIPS' || { echo "ERROR: MIPS probe failed" >&2; exit 1; }
echo "OK: MIPS Clang toolchain ready ($("$TOOLCHAIN_DIR/nrs_bin/clang" --version | head -1))"
