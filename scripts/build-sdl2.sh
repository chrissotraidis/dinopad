#!/usr/bin/env bash
# build-sdl2.sh - optional standalone build of the pinned native SDL2 static
# library for macOS diagnostics. The DinoPad CMake build compiles SDL in-tree.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SOURCE_DIR="$ROOT/ref/SDL2"
BUILD_DIR="$ROOT/build-macos-sdl2"

if [ ! -d "$SOURCE_DIR/.git" ]; then
  echo "ERROR: SDL2 source missing; run scripts/bootstrap.sh" >&2
  exit 1
fi

cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" -G Ninja \
  -DSDL_STATIC=ON -DSDL_SHARED=OFF -DSDL_TEST=OFF -DSDL_TESTS=OFF \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 \
  -DCMAKE_BUILD_TYPE=Release
cmake --build "$BUILD_DIR" --parallel "${DINOPAD_MAX_JOBS:-4}" --target SDL2-static

test -f "$BUILD_DIR/libSDL2.a" || { echo "ERROR: libSDL2.a not produced" >&2; exit 1; }
echo "OK: native SDL2 ready: $BUILD_DIR/libSDL2.a"
