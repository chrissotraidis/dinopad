# Evidence: statically linked DinoMod code on macOS

Date: 2026-08-16
Target: macOS arm64 (Apple M2, macOS 26.5, Xcode 26.6)
Cycle-start commit: `99b3a3b`
Result: **PASS for the static-code-handle slice; runtime replacement writes
remain for the next slice**

## Result

- OfflineModRecomp's 460 functions compile into `libdinopad_restoration.a`
  and are linked into the DinoPad executable.
- A generated, typed table covers `mod_func_0` through `mod_func_459`, plus 37
  imports, 2,346 reference slots, and one local section slot. Generation fails
  if declarations/definitions are not contiguous or the ABI tables are absent.
- N64ModernRuntime selects a registered build-time `ModCodeHandle` by the
  manifest ID `dinomod_enhanced`, before either developer offline-library or
  live-recompiler fallback.
- During the smoke, the package was renamed from `.offline.nrm` to an ordinary
  `.nrm`, and the offline dylib was moved out of reach under an automatic
  restoration trap. The executable has no DinoMod/offline dynamic dependency.
- The runtime emitted `Using statically linked code for mod
  dinomod_enhanced`, remained alive, and rendered the restored `PRESS START`
  rolling-demo screen and Start / Options / English title menu.
- The test restored both private mod files, then the runtime guard confirmed
  no DinoPad process and zero booted Simulators.

The earlier documentation count of 920 functions was corrected to 460: the
old text count included each generated forward declaration and definition.
The linked Mach-O and generated contiguous table both independently confirm
460 functions.

## Commands

```sh
DINOPAD_MAX_JOBS=4 scripts/generate-restoration.sh
cmake --build build-macos --parallel 4 --target DinoPad
DINOPAD_STATIC_EVIDENCE_DIR=docs/evidence/2026-08-16/dinomod-static-macos \
  scripts/runtime-guard.sh macos \
  scripts/smoke-static-restoration-macos.sh
```

The generation hashes and Mach-O checks are in `linkage.txt`; the focused
runtime excerpt is in `runtime.txt`. `static-press-start.png` and
`static-title-menu.png` are the visual acceptance evidence.

## Remaining production boundary

This removes the dynamic library and runtime-loaded executable code from the
restoration module. N64ModernRuntime still installs replacement trampolines by
writing the statically recompiled base-game functions, so the macOS target
still has an `rwx` `__GAME` segment. Goal 23b must replace those writes with a
static dispatch/indirection mechanism before this design is valid for iOS.

DinoMod redistribution permission remains a separate release blocker.
