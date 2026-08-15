# Evidence: Base AOT generation on Apple Silicon

Date: 2026-08-15
Commit: a4089e1 (baseline; this goal adds scripts/tools)
Target: none (host tooling + private generation, no runtime launched)

## Commands

```sh
scripts/build-tools.sh        # N64Recomp/RSPRecomp/OfflineModRecomp/RecompModMerger/RecompModTool from pinned source
                              # + n64recomp-clang release-22.1.8 Darwin-arm64 MIPS toolchain
scripts/generate-base.sh      # ROM copy+verify -> patch -> AOT C -> RSP C -> patches ELF -> RecompiledPatches
```

## Result

- PASS: all five host tools built for arm64 from the pinned N64Recomp fork (dino-planet, `8b46781e`).
- PASS: MIPS toolchain verified (MIPS-II big-endian ELF probe).
- PASS: private ROM fingerprint verified (`49f7bb346ade39d1915c22e090ffd748`); patched ROM created privately.
- PASS: N64Recomp emitted 219 files under `generated/aot/RecompiledFuncs/` (funcs.h, funcs_*.c, lookup.cpp with entrypoint 0x80000400, recomp_overlays.inl).
- PASS: RSPRecomp emitted `generated/aot/rsp/aspMain.cpp` (265,803 bytes).
- PASS: MIPS patch library `generated/patches/build/patches.elf` (368,700 bytes) built with MIPS clang.
- PASS: RecompPatcher recompiled 2561 patch functions to `generated/aot/RecompiledPatches/` incl. patches.bin (195,728 bytes) and patches_bin.c/h.
- PASS: all three reference checkouts remain clean (0 dirty files); nothing ROM-derived is tracked.

## Outputs (all ignored)

```text
generated/rom/baserom.z64                 (private copy, verified)
generated/rom/baserom.patched.z64         (recompiler-prerequisite patch)
generated/aot/RecompiledFuncs/            (219 files)
generated/aot/rsp/aspMain.cpp
generated/patches/build/patches.elf
generated/aot/RecompiledPatches/          (patches.c, patches_bin.c/h, funcs.h, recomp_overlays.inl)
```

## Known limitation

- The upstream `file_to_c` host utility is absent from the pinned tree; DinoPad-owned `tools/file_to_c.py` emits the equivalent `patches_bin.c`/`patches_bin.h` (sized extern array).

## Cleanup

- macOS DinoPad process: none launched (stopped)
- booted Simulators: 0
- runtime lock: released
