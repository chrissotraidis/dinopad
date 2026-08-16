# Evidence: full DinoMod offline AOT load on macOS

Date: 2026-08-16
Target: macOS arm64 (Apple M2, macOS 26.5, Xcode 26.6)
Goal: load all pinned DinoMod v0.9.3 code through the precompiled offline
path and demonstrate a visible restored-versus-prototype difference
Result: **PASS for the macOS full-AOT feasibility gate; not the production
static/iOS integration gate**

DinoPad cycle-start commit: `8205112` (evidence and fix follow this commit).
Pins: dino-recomp `v0.3.0` = `725b2ed...`; DinoMod `v0.9.3` =
`d79e86b...`.

## Result

- The complete `.offline.nrm` opened with its arm64 offline library. The
  package contains 920 converted functions, 37 imports, 2,346 reference
  symbols, 294 replacements, and 42 hooks. No live recompiler was used.
- The first full load exposed a real arm64 trampoline bug: the generated
  `__dll60_dll_60_update2` and `__dll60_dll_60_draw` entry points were only
  four bytes apart, while N64ModernRuntime writes a 16-byte arm64 replacement
  trampoline. Patching the first corrupted the second and caused `SIGBUS` in
  `rcp_clear_screen`.
- DinoPad now compiles patchable AOT entry points with
  `-falign-functions=16`. The two reproducing functions link 16 bytes apart,
  and `tools/check_patchable_aot.py` verifies 11,162 linked generated entry
  points with zero misalignment.
- After the fix, Restored Adventure stayed alive through the complete boot
  flow and visibly restored the rolling demo: `PRESS START` appears and leads
  to the Start / Options / Language title menu. See
  `restored-rolling-demo.png` and `restored-title-menu.png`.
- In a same-build Prototype comparison, the offline mod files were temporarily
  renamed under an automatic restoration trap. The same two A presses skip
  directly to Game Select, with no rolling-demo title flow. See
  `prototype-game-select.png`.
- Both guarded sessions ended with no DinoPad process, zero booted
  Simulators, and the mod files restored to their original paths.

## Commands

```sh
DINOPAD_MAX_JOBS=4 scripts/generate-restoration.sh
cmake -S . -B build-macos -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build-macos --parallel 4 --target DinoPad
tools/check_patchable_aot.py build-macos/DinoPad \
  generated/aot/RecompiledFuncs/funcs.h \
  generated/aot/RecompiledPatches/funcs.h
scripts/runtime-guard.sh macos bash <bounded restored session>
scripts/runtime-guard.sh macos bash <bounded prototype session>
```

## Limitations / next gate

This uses N64ModernRuntime's macOS developer-only offline dynamic-library
handle. It proves complete AOT translation, symbol parsing, imports,
replacements, hooks, assets, and visible restored behavior without live/JIT
recompilation. It is not acceptable for iOS: the next goal is a DinoPad-owned
static code handle/dispatch bridge that links the generated functions into the
app and does not require a dynamic library or writable executable segment.

DinoMod redistribution permission remains a separate release blocker.
