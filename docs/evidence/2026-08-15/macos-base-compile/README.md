# Evidence: Base recompiled code compiles for macOS arm64

Date: 2026-08-15
Commit: 215b71f (baseline; this goal adds the DinoPad CMake layer)
Target: none (compile-only milestone, no runtime launched)

## Commands

```sh
cmake -S . -B build-macos -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build-macos --parallel 4
```

## Result

- PASS: `dinopad_base` (219 generated game-code C files, N64Recomp output) compiles for arm64; libdinopad_base.a 12,523,960 bytes.
- PASS: `dinopad_patches` (RecompiledPatches patches.c + patches_bin.c) compiles; libdinopad_patches.a 804,152 bytes.
- PASS: `dinopad_rsp` (aspMain.cpp audio microcode) compiles for aarch64; libdinopad_rsp.a 993,456 bytes.
- PASS: incremental rebuild reports "no work to do".
- PASS: all three archives are non-fat arm64.

## Notes

- `librecomp/rsp_vu.hpp` requires `<sse2neon.h>` on aarch64; provided by `lib/N64ModernRuntime/thirdparty/sse2neon` (added to include dirs).
- Build flags mirror upstream (`-fno-strict-aliasing`, `-Wno-unused-variable`, `-Wno-implicit-function-declaration`).
- This proves the AOT pipeline end-to-end; the runtime link (N64ModernRuntime services + dino-recomp src) is the next goal.

## Cleanup

- macOS DinoPad process: none launched (stopped)
- booted Simulators: 0
- runtime lock: released
