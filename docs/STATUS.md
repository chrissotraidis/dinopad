# DinoPad Status

Last updated: 2026-08-16T16:00:00Z
Current commit: 0e03822 (this cycle's evidence + docs follow)
Current phase: Phase 3 - Static DinoMod on macOS (technical AOT gate; release gate separate)
Active goal: Goal 21 - bind one DinoMod import and invoke one safe exported function/hook on macOS (goal 20, offline-mod-recomp PoC, passed this cycle)

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
- tools/normalize_rom.py added and green (2026-08-16): plan-listed ROM byte-order normalizer + fingerprint validator (z64/v64/n64 detection, big-endian normalization, supported MD5 check) with 16/16 self-tests; real private ROM validated (ALREADY, z64, MD5 ok); wired into scripts/build-macos-app.sh ROM staging. Evidence: docs/evidence/2026-08-16/macos-rom-normalizer/.
- docs/DINOMOD_INTEGRATION.md written (2026-08-16): package inventory, mod.toml config schema summary, AOT path and toolchain status, offline-mod-recomp feasibility notes, settings bridge, save namespace isolation, compatibility pair, and the maintainer-permission gate.
- Offline-mod-recomp proof of concept green (2026-08-16): pinned DinoMod v0.9.3 ELF built (MIPS-II, 42,997,184 B) with n64recomp-clang; RecompModTool produced a zip-tested .nrm (mod_syms.bin 201,008 B, mod_binary.bin 42,711,744 B, mod.json, thumb.png); OfflineModRecomp emitted 6,979,048 B of C (920 mod functions, 37 imports, 2,346 reference symbols, 294 replacements, 42 hooks); the C compiles on arm64 macOS with 0 warnings against the new DinoPad-owned include/mod_recomp.h and links into tools/mod_aot_harness.c passing 13/13 ABI checks. Evidence: docs/evidence/2026-08-16/dinomod-aot/. Replayable via scripts/generate-restoration.sh.
- docs/UPSTREAM.md written (2026-08-16): pinned sources table, patch series inventory (0001-0005 + hlslpp), test method, upstream update procedure, known upstream issues, compatibility matrix.
- scripts/build-macos-app.sh added and green (2026-08-16): assembles build-macos/DinoPad.app (executable, assets, Info.plist, recompcontrollerdb.txt), ad-hoc codesigns it, stages the private ROM at ~/Library/Application Support/DinoPad/dino.z64 with MD5 verification, and asserts the bundle is ROM-free. Bundle launches to GAME SELECT with all assets resolving through the bundle; evidence: docs/evidence/2026-08-16/macos-app-bundle/.
- SDL gamecontroller -> N64 input path verified hardware-free (2026-08-16): tools/controller_virtual_smoke.cpp drives a virtual SDL controller through the exact calls the game makes (open, GetButton/GetAxis, poll update) and confirms the default N64 mappings (A=0x8000, B=0x4000, Start=0x1000, D-pad, analog, Z trigger) - 11/11 PASS. Evidence: docs/evidence/2026-08-16/macos-controller/.
- scripts/smoke-macos.sh added and green (2026-08-16): bounded automated input-replay smoke of boot -> GAME SELECT -> save load -> playable scene -> input (A/B/Z/Start/WASD) -> clean shutdown. First run FAILED because B was never exercised; B added to the replay, rerun PASS 22/22 (commit def59ac). Evidence: docs/evidence/2026-08-16/macos-smoke/.
- Flashram save persistence verified on macOS (2026-08-16): the AAAAA save (created 02:30 by the game's own name-entry flow) survived two full launches in one guarded session with SHA-256 unchanged (a62085a8...5516 for dino.bin and dino.bin.bak at all three checkpoints); GAME SELECT lists it after a clean relaunch; loading it after relaunch reaches the playable tutorial scene again. Evidence: docs/evidence/2026-08-16/macos-save-persistence/.
- Second-save name entry documented as a known issue (same S x3 D x1 lands on backspace when entering via GAME SELECT -> NEW with an existing save); first save creation and persistence unaffected.
- Scripted macOS input now activates the DinoPad window before sending keys (.goal-loop/scratch-title-audio/sendkey.sh) after session 16 showed osascript keystrokes go to the frontmost app; see docs/KNOWN_ISSUES.md.
- scripts/capture-window.sh + tools/window_id.swift added for clean window-only evidence screenshots.
- docs/KNOWN_ISSUES.md created; naming-screen input quirks documented (analog-only cursor, +3 key jump).
- docs/PLAYTEST_MATRIX.md created with the three verified macOS sessions.
- Private supported ROM present; MD5 verified as 49f7bb346ade39d1915c22e090ffd748 (path never exposed publicly).
- Commits: 96f8377, 7c42e58, 26f75f9, 5500d28, a4089e1, 215b71f, 66f1e69, 0d1e7ea, 0e1f9af, 10f6b1d, 04ea270, b1d350f (+ this cycle).
- Incident resolved: spirv-cross build output (build/) was briefly tracked; removed and /build/ ignored (0e1f9af).

## Red / blocked

- Acoustic playback (speaker/headphones) not checked; audio verified at the pipeline/SDL-device level.
- RmlUi launcher not exercised on Metal (--skip-launcher used).
- Physical controller play on macOS: BLOCKED (external) - both paired pads (8BitDo Lite 2, Xbox Wireless) are Not Connected; SDL sees 0 joysticks. Code path verified via virtual controller; see docs/KNOWN_ISSUES.md.
- docs/UI_PARITY.md not yet written.
- DinoMod redistribution permission: BLOCKED (release gate only; technical work may continue).

## Last successful commands

```sh
./scripts/apply-patches.sh                           # PASS: series 0001-0005 + hlslpp applied
./scripts/check-repo-safety.sh                       # PASS: clean (private paths, patches covered)
cmake --build build-macos --parallel 4 --target DinoPad   # PASS: incremental, arm64 executable
scripts/runtime-guard.sh macos scripts/smoke-macos.sh   # PASS: 22/22 automated smoke checks
scripts/runtime-guard.sh macos bash <session>        # PASS: guarded macOS sessions (24 total)
./build-macos/DinoPad --skip-launcher --window-width 1024 --window-height 768  # PASS with DINOPAD_LOG_* env
.goal-loop/scratch-title-audio/sendkey.sh <keycode> <hold-s>   # activate DinoPad window, send held key
# full flow: A x3 (boot) -> A x5 (name AAAAA) -> S x3, D x1 (END) -> A (PLAY THIS GAME?) -> A (YES) -> opening cinematic -> playable tutorial scene
md5 ref/DINO/rom                                    # 49f7bb346ade39d1915c22e090ffd748 (private, untracked)
```

## Current evidence

- ROM normalizer + validation verified (2026-08-16): docs/evidence/2026-08-16/macos-rom-normalizer/.
- DinoPad.app bundle build + launch verified (2026-08-16): docs/evidence/2026-08-16/macos-app-bundle/.
- Controller path verified hardware-free + external blocker documented (2026-08-16): docs/evidence/2026-08-16/macos-controller/.
- Automated smoke PASS (2026-08-16): docs/evidence/2026-08-16/macos-smoke/ (result.txt, runtime.log, game-select + input screenshots, README).
- Flashram save persistence verified (2026-08-16): docs/evidence/2026-08-16/macos-save-persistence/ (game select before/after relaunch, gameplay after reload, stable hashes).
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

1. Bind one DinoMod import and invoke one safe exported function/hook on macOS against a live runtime context (plan goal 21), using mod_syms.bin's 294 replacements/42 hooks as the binding table source.
2. Port the PaperPad Apple shell (Phase 4): native ROM import/validation UI on macOS + touch overlay groundwork.
3. Start the iPhone Simulator build (Phase 5) after the Apple shell milestone.

## Selected next goal

Goal 21: bind one DinoMod import and invoke one safe exported function/hook on macOS (live runtime context), validating the hook/replacement binding tables generated from mod_syms.bin. The AOT C now compiles and links (goal 20); the remaining unknown is live execution semantics.

Goal 20 outcome summary (this cycle): the offline-mod-recomp proof of concept passed end to end. Pinned DinoMod v0.9.3 built a MIPS-II ELF, RecompModTool produced a zip-tested .nrm, OfflineModRecomp emitted 6,979,048 B of C (920 functions, 37 imports, 2,346 reference symbols, 294 replacements, 42 hooks), the C compiles on arm64 with 0 warnings against the new include/mod_recomp.h, and tools/mod_aot_harness.c passes 13/13 ABI checks. Evidence: docs/evidence/2026-08-16/dinomod-aot/. Replayable via scripts/generate-restoration.sh.
