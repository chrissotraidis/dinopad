# DinoPad Status

Last updated: 2026-08-16T09:00:00Z
Current commit: b1d350f (this cycle's evidence + docs follow)
Current phase: Phase 2 - Apple Silicon macOS base build
Active goal: Verify saves (Flashram) persist across relaunch on macOS

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
- Patch series extended to 0004 (env-gated input logging) and 0005 (env-gated audio device/PCM logging); repo safety audit clean with the new patches.
- Input verified end-to-end on macOS: Space = N64 A, WASD = analog, IJKL = D-pad, Enter = Start all reach the recompiled game (logged via [dinopad-in]).
- macOS title/game flow verified (2026-08-16): N64 logo -> Rareware splash -> GAME SELECT -> ENTER NAME (save created, name "AAAAA") -> PLAY THIS GAME? -> YES -> opening cinematic with subtitles renders through RT64 Metal.
- Stable audio loop verified on macOS (2026-08-16): SDL device opens at 48000 Hz/2ch; continuous float32 stereo PCM captured (95 s session, 36 MB, RMS ~0.09, peak ~0.51, mean spectral entropy 5.5); no audio errors.
- Controllable gameplay verified on macOS (2026-08-16): the playable tutorial scene ("Krystal! Try shooting the cannon!") responds to input end-to-end. All input types delivered to the recompiled game during gameplay (analog WASD x/y ±0.66, A=0x8000, Z=0x2000 in the [dinopad-in] log); held W displaces the on-screen character and S returns it (NCC tracking: t1 750,1050 -> W -> t2 648,954 -> S -> t3 414,1032 -> idle -> t4 768,1038); A-presses fire the tutorial cannon (orange energy pixels 1,132 -> 112,846, ~100x). Evidence: docs/evidence/2026-08-16/macos-gameplay/.
- Scripted macOS input now activates the DinoPad window before sending keys (.goal-loop/scratch-title-audio/sendkey.sh) after session 16 showed osascript keystrokes go to the frontmost app; see docs/KNOWN_ISSUES.md.
- scripts/capture-window.sh + tools/window_id.swift added for clean window-only evidence screenshots.
- docs/KNOWN_ISSUES.md created; naming-screen input quirks documented (analog-only cursor, +3 key jump).
- docs/PLAYTEST_MATRIX.md created with the three verified macOS sessions.
- Private supported ROM present; MD5 verified as 49f7bb346ade39d1915c22e090ffd748 (path never exposed publicly).
- Commits: 96f8377, 7c42e58, 26f75f9, 5500d28, a4089e1, 215b71f, 66f1e69, 0d1e7ea, 0e1f9af, 10f6b1d, 04ea270, b1d350f (+ this cycle).
- Incident resolved: spirv-cross build output (build/) was briefly tracked; removed and /build/ ignored (0e1f9af).

## Red / blocked

- Saves (Flashram) persistence across relaunch not yet verified.
- Acoustic playback (speaker/headphones) not checked; audio verified at the pipeline/SDL-device level.
- RmlUi launcher not exercised on Metal (--skip-launcher used).
- scripts/build-macos-app.sh (app bundle + auto ROM staging) not yet written.
- Controller input on macOS not yet exercised (SDL gamepad path untested).
- docs/UPSTREAM.md, docs/DINOMOD_INTEGRATION.md, docs/UI_PARITY.md not yet written.
- DinoMod redistribution permission: BLOCKED (release gate only; technical work may continue).

## Last successful commands

```sh
./scripts/apply-patches.sh                           # PASS: series 0001-0005 + hlslpp applied
./scripts/check-repo-safety.sh                       # PASS: clean (private paths, patches covered)
cmake --build build-macos --parallel 4 --target DinoPad   # PASS: incremental, arm64 executable
scripts/runtime-guard.sh macos bash <session>        # PASS: guarded macOS sessions (19 total)
./build-macos/DinoPad --skip-launcher --window-width 1024 --window-height 768  # PASS with DINOPAD_LOG_* env
.goal-loop/scratch-title-audio/sendkey.sh <keycode> <hold-s>   # activate DinoPad window, send held key
# full flow: A x3 (boot) -> A x5 (name AAAAA) -> S x3, D x1 (END) -> A (PLAY THIS GAME?) -> A (YES) -> opening cinematic -> playable tutorial scene
md5 ref/DINO/rom                                    # 49f7bb346ade39d1915c22e090ffd748 (private, untracked)
```

## Current evidence

- Controllable gameplay verified (2026-08-16): docs/evidence/2026-08-16/macos-gameplay/ (pre_input, move_*, action_*, cannon-fire pair, displacement captures, analysis.txt, README).
- macOS title/game flow + stable audio loop (2026-08-16): docs/evidence/2026-08-16/macos-title-audio/ (boot, game select, name entry, play question, opening cinematic screenshots; runtime excerpt; README).
- Reference checkouts resolved and push-disabled (2026-08-15): PaperPad 644945d..., dino-recomp 725b2ed..., dinomod d79e86b...
- Repository safety audit green (2026-08-16, after patch series 0004/0005 and evidence curation).
- Base AOT generation verified (2026-08-15): docs/evidence/2026-08-15/base-aot/.
- macOS arm64 compile of base AOT and full runtime stack verified (2026-08-15): docs/evidence/2026-08-15/macos-base-compile/, macos-runtime-compile/.
- macOS first Metal frame verified (2026-08-15): docs/evidence/2026-08-15/macos-first-frame/.
- Private ROM fingerprint verified (2026-08-15).

## Current upstream pins

- PaperPad: 644945d4bc4facbbd8ecda8cdfd37ae64e7993fa (verified)
- dino-recomp: v0.3.0 = 725b2ede9cacc57968e0a028efed8df9235ba483
- dinomod-enhanced-recompiled: v0.9.3 = d79e86be2304cba75216b0b98e9fb53ee99b7500
- Supported ROM: MD5 49f7bb346ade39d1915c22e090ffd748 (present, private)

## Risks

- Disk: ~27 GiB free (gate is 20 GiB); monitor before full generation/builds.
- DinoMod redistribution clearance unresolved (release gate only).
- RT64 Metal/iOS path unproven on this toolchain (Xcode 26.6).
- Name-entry navigation quirks (analog-only, +3 jump) must be handled by the touch/controller shell and automated smoke input.
- Automated macOS input requires the DinoPad window to be frontmost; sendkey.sh handles it, but native input injection (or SDL-internal injection) is the durable fix for smoke automation.

## Next three candidate goals

1. Verify saves (Flashram) persist across relaunch on macOS.
2. Run a bounded automated input-replay smoke of the boot-to-gameplay flow on macOS.
3. Verify controller input (SDL gamepad) on macOS.

## Selected next goal

Verify saves (Flashram) persist across relaunch on macOS.
