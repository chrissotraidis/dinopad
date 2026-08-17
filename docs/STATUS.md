# DinoPad Status

Last updated: 2026-08-17T00:00:00Z
Current commit: Goal 27c milestone pending on main (predecessor 90084b4)
Current phase: Phase 5 - iPhone Simulator
Active goal: Goal 28 (native menu/settings/layout editor/diagnostics parity)

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
- Offline-mod-recomp proof of concept green (2026-08-16): pinned DinoMod v0.9.3 ELF built (MIPS-II, 42,997,184 B) with n64recomp-clang; RecompModTool produced a zip-tested .nrm (mod_syms.bin 201,008 B, mod_binary.bin 42,711,744 B, mod.json, thumb.png); OfflineModRecomp emitted 6,979,048 B of C (460 mod functions, 37 imports, 2,346 reference symbols, 294 replacements, 42 hooks); the C compiles on arm64 macOS with 0 warnings against the new DinoPad-owned include/mod_recomp.h and links into tools/mod_aot_harness.c passing 13/13 ABI checks. Evidence: docs/evidence/2026-08-16/dinomod-aot/. Replayable via scripts/generate-restoration.sh.
- DinoMod live invocation green (2026-08-16): tools/mod_invoke_harness.c binds imported_funcs[10] (recomp_get_config_u32) and executes the statically converted mod_func_16 (the pinned mod's kiosk_icons_gold_silver_keys restoration handler) on arm64 against a simulated N64 address space. Verified 0 failures: the import was called with all three config keys, mod-local static state updated, and base-game inventory data received exactly the constants the mod source writes (0x25C/0x25D/0x25E/0x260/0x261), proving RELOC + REF_RELOC semantics and the sign-extended gpr address convention. Evidence: docs/evidence/2026-08-16/dinomod-invoke/.
- Full DinoMod offline AOT load green on macOS (2026-08-16): N64ModernRuntime's precompiled `.offline.nrm` path resolves the complete 460-function module with 294 replacements and 42 hooks; no live recompiler. Restored mode visibly restores the rolling-demo `PRESS START` and Start/Options/Language title screens, while a same-build run with the mod disabled skips directly to Game Select. The first run exposed a 16-byte arm64 trampoline overlap; `-falign-functions=16` fixes it and `tools/check_patchable_aot.py` verifies 11,162 linked AOT entries with zero misalignment. Evidence: docs/evidence/2026-08-16/dinomod-full-macos/.
- DinoMod static code handle green on macOS (2026-08-16): `tools/generate_static_mod_exports.py` creates a checked table for all 460 functions, 37 imports, 2,346 reference slots, and one local section; CMake links it into DinoPad. With the package presented as an ordinary `.nrm` and the offline dylib disabled, N64ModernRuntime selected the registered static handle and rendered restored PRESS START plus the title menu. Mach-O inspection found all 460 symbols and no DinoMod/offline dynamic dependency. Evidence: docs/evidence/2026-08-16/dinomod-static-macos/.
- Production static replacement/hook dispatch green on macOS (2026-08-16): `tools/generate_static_dispatch.py` emits 328 wrappers for all 294 replacements and 42 hook callbacks / 35 slots. N64ModernRuntime validates conflicts but skips `patch_func` and unpatch writes for the static handle. The same arm64 binary renders the restored title when the ordinary package is present and falls back to Prototype Game Select when absent. Its `__TEXT` is immutable `r-x`, the former `__GAME` segment is absent, all 460 mod functions are linked, and there is no DinoMod dynamic dependency. Evidence: docs/evidence/2026-08-16/dinomod-static-dispatch-macos/.
- Restored/Prototype session profiles and isolation green on macOS (2026-08-16): Restored is the default, `--profile restored|prototype` is deterministic, and invalid values fail before initialization. Shared ROM/package data is separated from per-profile configs, mod configs, and FlashRAM. A disposable-root smoke with distinct 128 KiB sentinel saves proved no cross-mode writes; Restored visibly enabled static dispatch, while Prototype disabled all mod scanning/registration and reached Game Select. Evidence: docs/evidence/2026-08-16/macos-profiles/.
- Native macOS setup/home and profile handoff green (2026-08-16): a DinoPad-owned AppKit boundary precedes SDL, presents a ROM-free first-run setup screen, makes Restored Adventure the primary action, requires an explicit archival warning for Prototype, and offers ROM replacement. A guarded disposable-root smoke verified setup Quit, native Prototype -> base Game Select with no restoration, and native Restored -> PRESS START with static no-write dispatch. Evidence: docs/evidence/2026-08-16/macos-native-home/.
- Native document-picker ROM import green on macOS (2026-08-16): the real AppKit picker visibly rejected a fingerprint-modified 64 MiB z64 without staging it, then accepted a private v64 byte-swapped supported ROM, normalized it to `80371240`, atomically stored MD5 `49f7bb346ade39d1915c22e090ffd748`, and advanced to the native home. Evidence: docs/evidence/2026-08-16/macos-native-rom-import/.
- ROM-free iOS Simulator arm64 build green (2026-08-16): the Xcode target cross-compiles the pinned runtime/RT64/Plume/SDL stack for `iphonesimulator`, uses native host shader tools, disables LiveRecomp/SLJIT, bundles only the executable/plist/controller database, and passes architecture/ROM-extension audits. Built with Xcode 26.6 for iOS 15+.
- iPhone Simulator first rendered frame green (2026-08-16): a guarded automated smoke installed the app, staged the verified private ROM only in its data container, kept DinoPad alive for 20 seconds with audio and RT64 Metal active, captured the Rareware opening frame, found no new crash report, terminated cleanly, and left zero booted Simulators. The run exposed and fixed mobile Plume metadata, desktop RmlUi null state, and nil Simulator timestamp-query readback. Evidence: docs/evidence/2026-08-16/iphone-simulator-first-frame/.
- Initial iPhone touch/menu bridge green at pause point (2026-08-16): a DinoPad-owned UIKit overlay attaches to SDL's real window, draws all 15 N64 targets plus an accessible persistent menu button from PaperPad-derived safe-area phone/tablet defaults, latches taps, implements analog response, clears state on lifecycle notifications, and hides controls for native modal/controller state. A guarded 90-second live run delivered A=0x8000, Z=0x2000, Start=0x1000, and C-left=0x0002 through the actual `get_n64_input` path; the menu visibly hid controls and the run ended with no crash or remaining Simulator/process. Analog and the full mask/lifecycle matrix remain open, so this is not Phase 5 completion.
- Goal 26c input/lifecycle hardening green (2026-08-17): a deterministic in-app injection harness (DinoPadInputSmokeRunner, enabled only via DINOPAD_RUN_INPUT_SMOKE) plus a hardened smoke-ios.sh cleanup trap verified every digital N64 mask (14 masks A/B/Z/Start/D-pad*4/L/R/C*4), all 4 analog cardinal directions with return-to-zero, diagonal analog in a simultaneous stick+A+B+Z multi-touch suite, menu open clearing held input and hiding/restoring gameplay controls, background/foreground notification round-trip clearing and resuming state, and controller-handoff with the CoreSimulator synthetic-controller exception. Unit coverage in tools/touch_unit_test.cpp (21 ctest checks). The runtime's own [dinopad-in] poll log confirms every mask and analog value reaching the actual N64 input path; the bounded 8-second guarded run leaves no process, no booted Simulator, and no crash report. This completes the Goal 26c acceptance criteria; Phase 5 remains open for the UIKit ROM importer, Restored packaging, and 10-minute smoke. Evidence: docs/evidence/2026-08-17/iphone-touch-lifecycle/.
- Goal 27a UIKit ROM import/replacement green (2026-08-17): a clean ROM-free install presents DinoPad's native first-run setup and the real Files picker. The production importer requires the exact 64 MiB December 2000 prototype, rejects wrong-size and fingerprint-modified files without staging, normalizes valid z64/v64/n64 inputs to z64 magic `80371240`, verifies MD5 `49f7bb346ade39d1915c22e090ffd748`, writes atomically with file protection and backup exclusion, and exposes reachable Replace/Remove actions from the in-game menu. A three-launch guarded smoke captured the picker, live imported runtime, and ROM manager with no crash or leaked process/Simulator; the full Goal 26c regression remained green afterward. Evidence: docs/evidence/2026-08-17/iphone-rom-import/.
- Goal 27b native UIKit home/profile boundary green (2026-08-17): after ROM setup and before SDL startup, DinoPad now presents a landscape-safe Restored-primary home with accessible native actions and an explicit archival/incompleteness warning before Prototype Mode. The in-game menu exposes Quit to DinoPad Home. Runtime teardown is restartable in-process: renderer/window/audio teardown is ordered, queued UIKit/Plume work cannot outlive its window, timers/events/mod overlays reset, and every guest N64 host thread is signaled and joined before RDRAM is released. A guarded three-phase smoke proved no SDL startup while home/warning UI was waiting, real gameplay input polling before quit, return to the native home in the same process, warned Prototype selection, a second live RT64/game runtime, isolated Restored/Prototype sentinels, no crash, and zero leaked runtime/Simulator. Full iPhone input/lifecycle and ROM-import regressions and macOS smoke 22/22 remained green. Evidence: docs/evidence/2026-08-17/iphone-home/.
- Goal 27c embedded restoration data green on iPhone Simulator (2026-08-17): a deterministic builder maps the pinned MIPS ELF through `mod_syms.bin`, verifies every declared function, and zeroes the complete 316,592-byte executable segment before producing an ignored/private package containing exactly `mod.json`, `mod_syms.bin`, and `mod_binary.bin` (SHA-256 `2ee8befb...17be5e1`). iOS disables writable mod discovery and registers only this app-bundled data for Restored; all 460 functions remain ordinary linked arm64 code, with 294 replacements and 42 hooks dispatching without runtime writes. A final guarded run visibly proved the restored `PRESS START` title and controllable ship-deck cannon tutorial with analog/A input at frame 26,656. Same-process Restored -> home -> Prototype omitted the package/static markers after the profile switch. Bundle, crash, cleanup, fresh patch replay, macOS profile isolation, and repository audits passed. The package remains private pending redistribution permission. Evidence: docs/evidence/2026-08-17/iphone-restoration-data/.
- Graceful RT64 Metal shutdown green on macOS (2026-08-16): the supplied crash report identified `objc_release` during `RT64 Present` thread autorelease cleanup while `PresentQueue` was being destroyed. Replayable RT64/Plume patches stop workers before resources, scope worker autoreleases, and balance Metal ownership. `scripts/smoke-graceful-shutdown-macos.sh` passed 5/5 native window closes with status 0, no remaining process, and no new crash report. Evidence: docs/evidence/2026-08-16/macos-graceful-shutdown/.
- docs/UPSTREAM.md written and current (2026-08-17): pinned sources table, 25-file macOS/iOS patch inventory and checksum, test method, upstream update procedure, known upstream issues, compatibility matrix.
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
- DinoMod redistribution permission: BLOCKED (release gate only; technical work may continue).
- iPhone Simulator is not Phase 5 green yet: editable phone layout, complete menu/settings/diagnostics, save/relaunch, and the 10-minute smoke remain open. Native Files import/replacement, the Restored/Prototype home boundary with quit-to-home restart, embedded-only Restored title/gameplay, and the full input/lifecycle matrix are green.
- iPad Simulator, physical iPhone/iPad, progression certification, and release packaging remain open; see docs/HANDOFF.md and docs/TECHNICAL_DEBT.md.

## Last successful commands

```sh
./scripts/apply-patches.sh                           # PASS: all 25 maintained patches applied; fresh-clone replay also PASS
./scripts/check-repo-safety.sh                       # PASS: clean (private paths, patches covered)
cmake --build build-macos --parallel 4 --target DinoPad   # PASS: incremental, arm64 executable
DINOPAD_MAX_JOBS=4 scripts/generate-restoration.sh       # PASS: C + macOS offline AOT artifacts
scripts/runtime-guard.sh macos scripts/smoke-static-restoration-macos.sh  # PASS: 460 linked, r-x, no writes/dylib, restored title
scripts/runtime-guard.sh macos scripts/smoke-static-prototype-macos.sh    # PASS: same binary, base fallback, Game Select
scripts/runtime-guard.sh macos scripts/smoke-profiles-macos.sh            # PASS: explicit profiles + config/save isolation
scripts/runtime-guard.sh macos scripts/smoke-native-home-macos.sh         # PASS: native setup/home + both profile handoffs
scripts/runtime-guard.sh macos scripts/smoke-native-rom-import-macos.sh   # PASS: invalid rejection + v64 normalization/import
scripts/runtime-guard.sh macos scripts/smoke-macos.sh   # PASS: 22/22 automated smoke checks
scripts/runtime-guard.sh macos scripts/smoke-graceful-shutdown-macos.sh 5  # PASS: 5/5, no new crash report
scripts/runtime-guard.sh macos bash <session>        # PASS: full restored and prototype comparison sessions
./build-macos/DinoPad --skip-launcher --window-width 1024 --window-height 768  # PASS with DINOPAD_LOG_* env
.goal-loop/scratch-title-audio/sendkey.sh <keycode> <hold-s>   # activate DinoPad window, send held key
# full flow: A x3 (boot) -> A x5 (name AAAAA) -> S x3, D x1 (END) -> A (PLAY THIS GAME?) -> A (YES) -> opening cinematic -> playable tutorial scene
md5 ref/DINO/rom                                    # 49f7bb346ade39d1915c22e090ffd748 (private, untracked)
scripts/build-ios-simulator.sh                      # PASS: ROM-free arm64 Simulator app
scripts/runtime-guard.sh iphone-simulator <UDID> scripts/smoke-ios-rom-import.sh  # PASS: picker/rejection/all byte orders/replacement
scripts/runtime-guard.sh iphone-simulator <UDID> scripts/smoke-ios-home.sh  # PASS: native home/warning, gameplay -> home -> second profile/runtime, no crash
scripts/runtime-guard.sh iphone-simulator <UDID> scripts/smoke-ios-restoration.sh  # PASS: embedded-only static Restored title + controllable gameplay
scripts/runtime-guard.sh iphone-simulator <UDID> scripts/smoke-ios.sh  # PASS: full input/lifecycle regression, no crash, clean shutdown
```

## Current evidence

- iPhone embedded-only restoration data, restored title, and controllable gameplay (2026-08-17): docs/evidence/2026-08-17/iphone-restoration-data/.
- iPhone native home/profile boundary and live restart (2026-08-17): docs/evidence/2026-08-17/iphone-home/.
- iPhone Files ROM import/replacement (2026-08-17): docs/evidence/2026-08-17/iphone-rom-import/ (real picker, invalid rejection, z64/v64/n64 normalization, exact MD5, private atomic storage, manager, clean runtime).
- iPhone deterministic input/lifecycle completion (2026-08-17): docs/evidence/2026-08-17/iphone-touch-lifecycle/.
- iPhone touch/menu runtime pause point (2026-08-16): docs/evidence/2026-08-16/iphone-touch-runtime/ (90-second guarded result and actual N64 input-log excerpt; explicitly partial).
- Native macOS setup/home + warned Prototype/primary Restored handoffs (2026-08-16): docs/evidence/2026-08-16/macos-native-home/.
- iPhone Simulator ROM-free arm64 first frame (2026-08-16): docs/evidence/2026-08-16/iphone-simulator-first-frame/ (automated result, app console, real RT64 frame, limitations).
- Native AppKit picker rejection + byte-swapped import (2026-08-16): docs/evidence/2026-08-16/macos-native-rom-import/.
- Deterministic profiles + save/config isolation (2026-08-16): docs/evidence/2026-08-16/macos-profiles/.
- Static no-write dispatch + same-binary Restored/Prototype fallback (2026-08-16): docs/evidence/2026-08-16/dinomod-static-dispatch-macos/.
- Statically linked DinoMod code + no-dylib restored boot (2026-08-16): docs/evidence/2026-08-16/dinomod-static-macos/.
- Full DinoMod macOS AOT load + visible restored/prototype comparison (2026-08-16): docs/evidence/2026-08-16/dinomod-full-macos/.
- Native-close RT64/Metal teardown regression (2026-08-16): docs/evidence/2026-08-16/macos-graceful-shutdown/.
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
- RT64 Metal/iOS now renders on Simulator, but lifecycle, orientation on physical
  hardware, longer stability, and device behavior need dedicated verification.
- Name-entry navigation quirks (analog-only, +3 jump) must be handled by the touch/controller shell and automated smoke input.
- Automated macOS input requires the DinoPad window to be frontmost; sendkey.sh handles it, but native input injection (or SDL-internal injection) is the durable fix for smoke automation.
- iPad/physical-device runs must repeat the embedded-only restoration policy and gameplay proof.

## Next three candidate goals

1. Complete the native menu/settings/layout editor/diagnostics.
2. Prove mobile save/relaunch and finish the 10-minute iPhone smoke.
3. Repeat the package policy and product flow on iPad Simulator.

## Selected next goal

Goal 28: complete the native menu/settings/layout editor/diagnostics to the
section 3.4 contract, beginning with independent persisted phone/tablet layout
editing and reset.

Goal 27c outcome: iPhone embeds only sanitized non-executable restoration data,
disables writable mod scanning, and uses statically linked no-write arm64
dispatch. The final guarded build visibly reached the restored `PRESS START`
title and controllable cannon tutorial; live Prototype restart omitted the
package. Evidence: docs/evidence/2026-08-17/iphone-restoration-data/.

Goal 27b outcome: the UIKit DinoPad home is green before SDL startup. Restored
is primary, Prototype requires the archival warning, both profiles use isolated
roots, and live gameplay can quit to home before a second profile/runtime starts
in the same process without a crash. Evidence:
docs/evidence/2026-08-17/iphone-home/.

Goal 27a outcome: native first-run Files import and in-game ROM replacement are
green for z64/v64/n64, exact size/fingerprint rejection, atomic protected
private storage, ROM-free packaging, and guarded runtime cleanup. Evidence:
docs/evidence/2026-08-17/iphone-rom-import/.

Goal 26b outcome: landscape-only plist and SDL orientation contracts are in
place. The iOS 26.5 headless Simulator raw framebuffer remains portrait for both
DinoPad and the pinned PaperPad control app, and its CLI exposes no orientation
operation. The GUI can rotate virtual hardware, but physical iPhone/iPad remain
the presentation authority. Do not revive temporary-window/private-API hacks;
see docs/TECHNICAL_DEBT.md.

Goal 26a outcome: the ROM-free arm64 app builds, installs, remains live for a
bounded smoke, renders the Rareware opening frame through RT64 Metal with SDL
audio active, produces no new crash report, and cleans up completely. This is
base prototype output because the permitted restoration package data and
mobile shell gates intentionally follow. Evidence:
docs/evidence/2026-08-16/iphone-simulator-first-frame/.

Goal 24b outcome: the real AppKit picker rejected a modified 64 MiB ROM without
staging it, accepted a private v64 fixture, normalized it to z64, stored the
exact supported fingerprint atomically, and advanced to the native home.
Evidence: docs/evidence/2026-08-16/macos-native-rom-import/.

Goal 24a outcome: DinoPad's native AppKit setup/home precedes runtime startup,
makes Restored the primary action, warns before Prototype, and hands both
modes into their isolated profiles without showing the desktop mod manager.
Evidence: docs/evidence/2026-08-16/macos-native-home/.

Goal 23c outcome: the Restored-default and explicit Prototype engine boundary
is deterministic, separates shared ROM/package data from profile-local config
and saves, and disables mod scanning/registration in Prototype. Disposable
sentinel saves plus visual runs proved cross-mode isolation. Evidence:
docs/evidence/2026-08-16/macos-profiles/.

Goal 23b outcome: build-time wrappers now cover all 294 replacements and 42
hooks without runtime code writes. The same immutable arm64 Mach-O passed both
Restored and Prototype fallback smokes, has no `__GAME` segment, and has no
DinoMod/offline dynamic dependency. Evidence:
docs/evidence/2026-08-16/dinomod-static-dispatch-macos/.

Goal 23a outcome: the complete restoration module is statically linked and
selected by manifest ID. The ordinary `.nrm` + disabled-dylib smoke passed,
with all 460 functions in the executable and no DinoMod dynamic dependency.
Evidence: docs/evidence/2026-08-16/dinomod-static-macos/.

Goal 22 outcome summary: complete offline AOT loading now works on arm64 macOS.
All 294 replacements and 42 hooks resolve without live recompilation, and the
restored rolling-demo title flow is visibly present versus direct Game Select
in the same-build Prototype comparison. This is technical success for full mod
binding, but still uses a developer-only `.dylib`/runtime-patching path that the
production static bridge must remove. Evidence:
docs/evidence/2026-08-16/dinomod-full-macos/.
