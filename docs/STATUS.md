# DinoPad Status

Last updated: 2026-08-15T21:00:00Z
Current commit: (pending first-frame commit)
Current phase: Phase 2 - Apple Silicon macOS base build
Active goal: Reach the title screen and verify a stable audio loop on macOS

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
- Complete runtime stack compiles for macOS arm64: RT64 Metal (plume), RmlUi/lunasvg, N64ModernRuntime, NFD, SDL2 static, and all pinned dino-recomp sources (libdinopad_runtime.a).
- Apple window adapter (SDL Metal) and hlslpp fix applied as replayable patches; apply-patches.sh and check-repo-safety.sh verify patch state.
- DinoPad macOS executable links and renders the first Metal frame: the game boots to the GAME SELECT screen on arm64 macOS (2026-08-15).
- Boot blockers resolved: weak-symbol link order (patches before base) and imgui debug overlay disabled on Apple (no Metal backend).
- Key architecture finding: dino-recomp renderer already maps Metal on __APPLE__; src/runtime/gfx.cpp create_window() is the first macOS blocker (static_assert on Apple).
- Private supported ROM present; MD5 verified as 49f7bb346ade39d1915c22e090ffd748 (path never exposed publicly).
- Commits: 96f8377, 7c42e58, 26f75f9, 5500d28, a4089e1, 215b71f, 66f1e69, 0d1e7ea, 0e1f9af.
- Incident resolved: spirv-cross build output (build/) was briefly tracked; removed and /build/ ignored (0e1f9af).
- Commits: 96f8377, 7c42e58, 26f75f9, 5500d28.
- Commits: 96f8377 (docs bootstrap), 7c42e58 (upstream pins), 26f75f9 (scripts).

## Red / blocked

- No build, runtime, or gameplay evidence exists yet.
- docs/UPSTREAM.md, docs/DINOMOD_INTEGRATION.md, docs/KNOWN_ISSUES.md, docs/UI_PARITY.md, docs/PLAYTEST_MATRIX.md not yet written.
- Title screen and gameplay not yet reached/validated; audio, input, and saves unverified on macOS.
- RmlUi launcher not exercised on Metal (--skip-launcher used).
- scripts/build-macos-app.sh (app bundle + auto ROM staging) not yet written.
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
cmake --build build-macos --parallel 4               # PASS: full runtime stack static libs (arm64)
./scripts/apply-patches.sh                           # PASS: idempotent patch series
./scripts/check-repo-safety.sh                       # PASS: patches applied, push URLs disabled
cmake --build build-macos --target DinoPad           # PASS: arm64 executable
./build-macos/DinoPad --skip-launcher                # PASS: boots to GAME SELECT, stable 45s+
md5 ref/DINO/rom                                    # 49f7bb346ade39d1915c22e090ffd748 (private, untracked)
```

## Current evidence

- Reference checkouts resolved and push-disabled (2026-08-15): PaperPad 644945d..., dino-recomp 725b2ed..., dinomod d79e86b...
- Repository safety audit green (2026-08-15).
- Runtime guard acquire/reject/release verified (2026-08-15).
- Source inventory for Apple port recorded in docs/ARCHITECTURE.md (2026-08-15).
- Base AOT generation verified (2026-08-15): docs/evidence/2026-08-15/base-aot/.
- macOS arm64 compile of base AOT verified (2026-08-15): docs/evidence/2026-08-15/macos-base-compile/.
- macOS arm64 compile of the full runtime stack verified (2026-08-15): docs/evidence/2026-08-15/macos-runtime-compile/.
- macOS first Metal frame verified (2026-08-15): docs/evidence/2026-08-15/macos-first-frame/ (GAME SELECT screenshot).
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

1. Reach the title screen and verify a stable audio loop on macOS.
2. Verify keyboard/controller input and reach controllable gameplay on macOS.
3. Verify saves (Flashram) persist across relaunch on macOS.

## Selected next goal

Reach the title screen and verify a stable audio loop on macOS.
