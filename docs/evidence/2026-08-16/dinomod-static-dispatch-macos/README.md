# Evidence: no-write static DinoMod dispatch on macOS

Date: 2026-08-16  
Target: macOS arm64 (Apple M2, macOS 26.5, Xcode 26.6)  
Cycle-start commit: `e2df107`  
Result: **PASS for the production static-dispatch architecture on macOS**

## Result

- `tools/generate_static_dispatch.py` parsed the pinned v0.9.3 symbol table
  and emitted 328 wrappers covering 294 replacements and 42 hook callbacks in
  35 unique slots. Generation fails if a target cannot be resolved to the
  pinned base overlay table.
- The affected generated base definitions are renamed at build time. With the
  static handle inactive, wrappers call those originals; when Restored loads,
  wrappers route to linked `mod_func_N` functions and registered hook slots.
- N64ModernRuntime's generic static-dispatch lifecycle preserves conflict
  validation but records that no code bytes were written, skips `patch_func`,
  and does not unpatch those entries during shutdown.
- Mach-O inspection found 460 linked mod functions, immutable `r-x` `__TEXT`
  (`maxprot == initprot == 0x5`), no former `__GAME` segment, and no dynamic
  DinoMod/offline dependency.
- With the package presented as an ordinary `.nrm` and the developer dylib
  disabled, the runtime logged the static handle and no-write marker, then
  rendered restored PRESS START and the Start/Options/English title.
- With the package absent, the same binary never activated restoration and
  reached Prototype Game Select, proving the base-wrapper fallback.
- Both guarded sessions ended with no DinoPad process and zero booted
  Simulators; private files were restored automatically.

## Commands

```sh
cmake --build build-macos --target DinoPad -j8
DINOPAD_STATIC_EVIDENCE_DIR=docs/evidence/2026-08-16/dinomod-static-dispatch-macos \
  scripts/runtime-guard.sh macos scripts/smoke-static-restoration-macos.sh
DINOPAD_PROTOTYPE_EVIDENCE_DIR=docs/evidence/2026-08-16/dinomod-static-dispatch-macos \
  scripts/runtime-guard.sh macos scripts/smoke-static-prototype-macos.sh
```

See `linkage.txt` for structural checks and `runtime.txt` for the focused
markers. The three PNGs are window-only visual evidence.

## Remaining boundary

This proves the no-JIT/no-code-write design on macOS. The iOS target still
needs allowed package data embedded at build time and must exclude the unused
live-recompiler implementation. DinoMod redistribution permission remains a
separate public-release blocker.
