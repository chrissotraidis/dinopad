# DinoPad Status

Last updated: 2026-08-15T19:30:00Z
Current commit: 215b71f
Current phase: Phase 0 - Repository and documentation bootstrap
Active goal: Compile the dino-recomp runtime sources (N64ModernRuntime + src/) for macOS arm64 with an Apple window adapter

## Green

- Repository skeleton exists (initial commit 998505b).
- docs/IMPLEMENTATION_PLAN.md, docs/DINOPAD_GOAL_LOOP.md, and docs/STATUS.md at canonical paths.
- .gitignore covers ref/, generated/, build trees, private fixtures, logs, and .goal-loop/.
- dependencies.lock.json present with normalized schema and the three pinned references.
- ref/PaperPad at 644945d4bc4facbbd8ecda8cdfd37ae64e7993fa; worktree clean; push URL disabled.
- ref/dino-recomp at v0.3.0 = 725b2ede9cacc57968e0a028efed8df9235ba483 with all 9 recursive submodules pinned; push URL disabled.
- ref/dinomod-enhanced-recompiled at v0.9.3 = d79e86be2304cba75216b0b98e9fb53ee99b7500 with 2 submodules initialized; push URL disabled.
- scripts/bootstrap.sh, scripts/check-repo-safety.sh, scripts/report-size.sh, scripts/runtime-guard.sh added and verified.
- docs/ARCHITECTURE.md written from direct inventory of pinned PaperPad and dino-recomp sources.
- docs/BUILDING.md and docs/TESTING.md written from upstream build guides and PaperPad evidence discipline.
- N64Recomp/RSPRecomp/OfflineModRecomp/RecompModMerger/RecompModTool built on Apple Silicon from pinned source (build-tools/).
- MIPS Clang toolchain (n64recomp-clang release-22.1.8, Darwin-arm64) fetched and verified; patches ELF builds.
- Base AOT generation green: 219 RecompiledFuncs files, rsp/aspMain.cpp, RecompiledPatches (2561 funcs) all in ignored generated/.
- DinoPad CMake layer compiles the base game code, recompiled patches, and audio RSP into arm64 static libraries (build-macos/).
- Key architecture finding: dino-recomp renderer already maps Metal on __APPLE__; src/runtime/gfx.cpp create_window() is the first macOS blocker (static_assert on Apple).
- Private supported ROM present; MD5 verified as 49f7bb346ade39d1915c22e090ffd748 (path never exposed publicly).
- Commits: 96f8377, 7c42e58, 26f75f9, 5500d28, a4089e1.
- Commits: 96f8377, 7c42e58, 26f75f9, 5500d28.
- Commits: 96f8377 (docs bootstrap), 7c42e58 (upstream pins), 26f75f9 (scripts).

## Red / blocked

- No build, runtime, or gameplay evidence exists yet.
- docs/UPSTREAM.md, docs/DINOMOD_INTEGRATION.md, docs/KNOWN_ISSUES.md, docs/UI_PARITY.md, docs/PLAYTEST_MATRIX.md not yet written.
- No DinoPad runtime link exists yet; N64ModernRuntime services and dino-recomp src/ are not compiled.
- scripts/apply-patches.sh, scripts/build-macos-app.sh not yet written; no window/first frame.
- macOS first frame blocked until create_window() Apple adapter is implemented.
- DinoMod redistribution permission: BLOCKED (release gate only; technical work may continue).

## Last successful commands

```sh
./scripts/bootstrap.sh                              # PASS: all checkouts pinned, audit clean
./scripts/check-repo-safety.sh                      # PASS: 8/8 checks
./scripts/runtime-guard.sh macos sleep 4            # PASS: acquire -> run -> cleanup -> release
scripts/runtime-guard.sh macos echo should-not-run  # PASS: rejected while lock held (rc=1)
./scripts/build-tools.sh                            # PASS: 5 host tools + MIPS clang
./scripts/generate-base.sh                          # PASS: 219 funcs + RSP + 2561 patch funcs
cmake -S . -B build-macos -G Ninja -DCMAKE_BUILD_TYPE=Release   # PASS
cmake --build build-macos --parallel 4               # PASS: arm64 base/patches/rsp static libs
md5 ref/DINO/rom                                    # 49f7bb346ade39d1915c22e090ffd748 (private, untracked)
```

## Current evidence

- Reference checkouts resolved and push-disabled (2026-08-15): PaperPad 644945d..., dino-recomp 725b2ed..., dinomod d79e86b...
- Repository safety audit green (2026-08-15).
- Runtime guard acquire/reject/release verified (2026-08-15).
- Source inventory for Apple port recorded in docs/ARCHITECTURE.md (2026-08-15).
- Base AOT generation verified (2026-08-15): docs/evidence/2026-08-15/base-aot/.
- macOS arm64 compile of base AOT verified (2026-08-15): docs/evidence/2026-08-15/macos-base-compile/.
- Private ROM fingerprint verified (2026-08-15).
- No DinoPad build exists yet; no runtime has ever been launched.

## Current upstream pins

- PaperPad: 644945d4bc4facbbd8ecda8cdfd37ae64e7993fa (verified)
- dino-recomp: v0.3.0 = 725b2ede9cacc57968e0a028efed8df9235ba483
- dinomod-enhanced-recompiled: v0.9.3 = d79e86be2304cba75216b0b98e9fb53ee99b7500
- Supported ROM: MD5 49f7bb346ade39d1915c22e090ffd748 (present, private)

## Risks

- Disk: 28 GiB free (gate is 20 GiB); monitor before full generation/builds.
- DinoMod redistribution clearance unresolved (release gate only).
- RT64 Metal/iOS path unproven on this toolchain (Xcode 26.6).

## Next three candidate goals

1. Compile the dino-recomp runtime sources (N64ModernRuntime + src/) for macOS arm64 with an Apple window adapter.
2. Bring up RT64 Metal and render the first frame on macOS.
3. Write docs/UPSTREAM.md (pins, patch strategy, compatibility matrix) and docs/KNOWN_ISSUES.md.

## Selected next goal

Compile the dino-recomp runtime sources (N64ModernRuntime + src/) for macOS arm64 with an Apple window adapter.
