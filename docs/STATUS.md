# DinoPad Status

Last updated: 2026-08-18T05:32:37Z
Current commit: Goal 31h compiler-derived notice inventory pending on main (predecessor 13beb6a)
Current phase: Phase 7 - Physical iPhone
Active goal: Goal 31a (physical iPhone build/install and product validation)

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
- Goal 28a persisted touch-layout editor green on iPhone Simulator (2026-08-17): the real `•••` menu now exposes Customize, Reset Phone, and Reset Tablet actions with no layout placeholder. The PaperPad-derived editor supports safe-area-clamped move, independent D-pad/C-button linking, resize, per-control opacity, visibility, reset, one-step undo, Done, and full-session Cancel. Complete phone/tablet dictionaries use independent versioned defaults keys with defensive loading. A guarded three-launch smoke proved input clearing/restoration, cancel, both linked groups, unreachable-coordinate clamping, persistence across process relaunch, independent phone/tablet resets, the visible editor/menu, arm64 ROM-free packaging, no crash, and zero leaked process/Simulator. Input/lifecycle, home/restart, ROM-import, restored title/gameplay, macOS profile, unit, repository, and 25-patch replay regressions passed. Evidence: docs/evidence/2026-08-17/iphone-touch-layout/.
- Goal 28b native settings/status green on iPhone Simulator (2026-08-17): the real `•••` menu now opens a safe-area-readable UIKit form with truthful mode, restoration, save/recovery, controller, and effective Metal status plus live persisted touch enable/opacity, profile-local master volume, internal resolution, aspect, refresh-rate, and HUD placement. Narrow Objective-C++ bridges queue config saves onto the game-input thread and preserve Restored/Prototype isolation. A guarded two-launch smoke proved modal input clearing, defensive clamping, live application, JSON serialization, process-relaunch loading, default restoration, post-dismissal touch input, readable normalized screenshots, arm64 ROM-free packaging, and no crash. Input/lifecycle, home/restart, ROM import, layout editor, restored title/gameplay, macOS profile, unit, repository, and clean 25-patch replay regressions passed. Evidence: docs/evidence/2026-08-17/iphone-native-settings/.
- Goal 28c native diagnostics/share green on iPhone Simulator (2026-08-17): DinoPad now captures stderr into a protected 4 MiB private current log with one rotated predecessor, sanitizes every complete line before persistence, and builds a 512 KiB maximum share report from 192 KiB log tails without ROM/save contents. The report includes useful app/device, profile/restoration, exact ROM-validation, save/recovery, controller/touch, audio/display, and effective Metal status. Support and the persistent menu expose the real UIKit share sheet. A guarded adversarial smoke proved app-container/home/temp/provider/volume/UUID redaction in stored and shared text, mode `0600`, held-input clearing, native presentation/cancellation, post-dismissal touch restoration, temporary/test cleanup, arm64 ROM-free packaging, and no crash. All iPhone regressions, restored gameplay at frame 26,681, macOS build/unit/smoke, repository safety, and clean 25-patch replay remained green. Evidence: docs/evidence/2026-08-17/iphone-diagnostics/.
- Goal 29a completes iPhone Simulator Phase 5 (2026-08-17): a clean arm64 ROM-free install staged the private game-created 128 KiB `AAAAA` FlashRAM only in Restored and an independent Prototype sentinel. Launch one loaded the slot into controllable restored ship-deck gameplay and stayed live for exactly 600 seconds. Launch two retained the same installed data container, passed all seven input/lifecycle suites, and loaded the persisted slot back into controllable gameplay at late input frame 26,685. The Restored hash remained `6f4ccb8a...c9f28` across seed/ten-minute/relaunch checkpoints, the Prototype hash was unchanged, bounded diagnostics stayed within caps, no new crash appeared, screenshots were visually accepted, and guard cleanup left zero process/Simulator residue. This closes every Phase 5 acceptance criterion. Evidence: docs/evidence/2026-08-17/iphone-phase5/.
- Goal 30a completes iPad Simulator Phase 6 (2026-08-17): one guarded iPad Pro 11-inch (M5) ran the complete native setup/home/ROM manager/layout/settings/diagnostics/input/restoration/save matrix. Tablet layout edits persisted across process relaunch while phone keys remained isolated; all seven input/lifecycle suites passed; the audited static restoration reached title and controllable gameplay at frame 26,670; and a game-created Restored save stayed byte-identical through 600 live seconds and same-install relaunch to gameplay at frame 26,669 while Prototype remained unchanged. Diagnostics explicitly reported `iPad (tablet)`, stayed bounded/redacted, the arm64 app remained ROM-free, all captures were visually accepted, and every guard cleanup left zero process/Simulator residue. The PaperPad tablet menu rect matches exactly and the maximum conservative control-center delta is 0.64 point. Evidence: docs/evidence/2026-08-17/ipad-simulator-phase6/.
- Goal 31a physical-device preflight is compile-green but externally blocked (2026-08-17): CoreDevice reports zero known devices and the keychain reports zero valid code-signing identities. The new `scripts/build-ios-device.sh` nevertheless produced an unsigned 60,334,080-byte device app for `platform IOS` (minimum 15.0, SDK 26.5), arm64-only and ROM-free, with no signature or provisioning profile. The script also supports explicit personal-team signing without storing team/certificate data. Physical install, launch, 30-minute gameplay, orientation/audio/lifecycle/thermal/controller, and update-in-place save evidence remain open. Evidence: docs/evidence/2026-08-17/physical-device-preflight/.
- Goal 31b release-build harness boundary is green (2026-08-17): environment-driven Simulator automation now defaults off at compile time, the Simulator build opts in explicitly, and the physical-device build forces it off even across CMake cache reuse. The rebuilt unsigned arm64 `IOS` executable contains zero automation keys, simulated-touch/ForTesting selectors, adversarial path/UUID fixtures, personal paths, or likely credentials. `scripts/check-package-safety.sh` additionally proves iOS 15+, system-only runtime dependencies, no rpath/signing/ROM/save/log/private output, and an exact sanitized restoration audit match; a test-enabled Simulator app is rejected as a negative control. The explicit test build still passed the guarded 8-second full input/lifecycle regression and cleaned to zero runtimes. Evidence: docs/evidence/2026-08-17/physical-device-release-boundary/.
- Goal 31c privacy-manifest package gate is green (2026-08-17): a valid `PrivacyInfo.xcprivacy` is bundled exactly at the iPhone/iPad app root with no tracking, tracking domains, or collected data and with current required reasons for app/user-selected file metadata, app-only UserDefaults, and elapsed-time calculations. The package gate checks the exact structure; physical and Simulator products contain byte-identical copies, and a `tracking=true` mutation is rejected. This is an app-resource and local audit result, not App Store acceptance or a final transitive-SDK privacy report. Evidence: docs/evidence/2026-08-17/privacy-manifest/.
- Phase 9 fixture-manifest bootstrap is green (2026-08-17): `docs/PROGRESSION_FIXTURES.json` records only public metadata for the private game-created Restored `AAAAA` ship-deck fixture already proven on both Simulator idioms. A strict validator enforces the exact schema, lowercase SHA-256/Git IDs, supported modes/targets, valid dates, existing repository evidence, unique IDs, and no private absolute paths. This is one early-game fixture only; chapter boundaries, known progression repairs, and start-to-credits remain open.
- Phase 10 documentation boundary is explicit (2026-08-18): the root README now exposes the verified target matrix, source-only build/import flow, complete controls, evidence, and honest limitations without advertising a download. `docs/RIGHTS_AND_LICENSES.md` records the ROM/private-output boundary, pinned top-level license states, unresolved DinoMod permission, and the missing root license/complete third-party notices as release blockers. This is documentation readiness only; no package or release gate is claimed.
- Goal 31d gated release checklist is green (2026-08-18): `docs/RELEASE_CHECKLIST.md` records a fail-closed P0 status matrix, explicit no-override stop conditions, clean source/build checks, the exact physical iPhone/iPad duration and update-in-place matrices, start-to-credits and fixture requirements, rights/notices/privacy gates, an unsigned-IPA audit/install sequence, and a release-record template. Physical devices/signing, progression, the root license/notices, final transitive privacy review, DinoMod permission, IPA, tag, and checksums remain red; no package or release is claimed. Evidence: docs/evidence/2026-08-17/release-checklist/.
- Goal 31e self-contained macOS bundle is green (2026-08-18): link-graph inspection found the previous app depended on absolute Homebrew FreeType/libpng paths, contained an absolute checkout-path `assets` symlink, and mixed a macOS 11 executable claim with macOS 26 SDL objects. FreeType 2.13.3 is now pinned at `42608f7`, push-disabled, and built statically with optional external dependencies disabled; pinned SDL2 now builds in-tree at the app deployment target and linker warnings are fatal. Bundle assembly resolves assets, aligns metadata to 0.1.0 build 1, implements the documented atomic `--rom` import, and runs `scripts/check-macos-package-safety.sh`. The rebuilt 30 MB arm64 app has macOS 11 load commands, only system runtime dependencies, no symlinks/private paths/game/save/log material, and a valid ad-hoc signature; guarded gameplay smoke passed 22/22 and cleaned to zero runtimes. Rights/notices and notarization remain open. Evidence: docs/evidence/2026-08-17/macos-self-contained-bundle/.
- Goal 31f package-rights inventory is green as an engineering audit and red as a release gate (2026-08-18): `docs/PACKAGE_RIGHTS_INVENTORY.json` plus its validator bind 17 direct macOS linked components to exact Git pins, archive tokens, and hashed license texts, and bind 10 selected packaged resources to exact source/app hashes. The strict no-override mode correctly fails with 10 unresolved/restricted states and 6 blockers. Newly explicit P0s are redistribution rights for compiled private ROM-derived AOT and unresolved macOS launcher font/art provenance (DinoFont, Noto/Lato notices, game logo, Krazoa art), in addition to root-license, GPL source, DinoMod, and full transitive/iOS notice work. No legal clearance or release is claimed. Evidence: docs/evidence/2026-08-17/package-rights-inventory/.
- Goal 31g rights-safe launcher packaging is green as bounded remediation and remains red for release (2026-08-18): the macOS app no longer includes DinoFont, Noto Emoji, the bitmap logo, Krazoa art, or development Sass. The dormant RML launcher now uses text plus the pinned Lato family, with exact attribution and SIL OFL 1.1 text under `Contents/Resources/Notices`. Source/executable/resource checks and negative controls reject stale references, asset reintroduction, or notice modification. The rebuilt 29 MB app passes its self-contained audit; guarded gameplay smoke remains 22/22 with zero runtime residue; the unsigned device-arm64 iOS build also remains package-audit green. The validated inventory is now 17 linked components, 8 selected resources, 2 unresolved states, and 5 release blockers. Compiled private AOT, DinoMod, root-license, GPL-source, full transitive notices, physical devices, and progression remain open; no legal clearance or release is claimed. Evidence: docs/evidence/2026-08-18/rights-safe-launcher-assets/.
- Goal 31h compiler-derived macOS notice coverage is green as an inventory and remains red for release (2026-08-18): Ninja's actual dependency database maps all 2,227 pinned `ref/` source/header paths to 46 deepest-prefix ownership roots with zero uncovered or stale components. Exact hashes bind every primary notice source. Bundle assembly now copies and indexes 39 standalone license files byte-for-byte; 7 component roots whose primary notice is inline remain explicitly null in the package index pending extraction/review. Missing-file, index-tamper, and manifest-hash negative controls all reject. The package-rights validator invokes this coverage gate, while strict release mode still returns 2 with 5 blockers. iOS graph reconciliation, inline/secondary notice review, root-license, GPL-source, DinoMod, and AOT rights remain open; no legal clearance or release is claimed. Evidence: docs/evidence/2026-08-18/compiled-dependency-inventory/.
- Graceful RT64 Metal shutdown green on macOS (2026-08-16): the supplied crash report identified `objc_release` during `RT64 Present` thread autorelease cleanup while `PresentQueue` was being destroyed. Replayable RT64/Plume patches stop workers before resources, scope worker autoreleases, and balance Metal ownership. `scripts/smoke-graceful-shutdown-macos.sh` passed 5/5 native window closes with status 0, no remaining process, and no new crash report. Evidence: docs/evidence/2026-08-16/macos-graceful-shutdown/.
- docs/UPSTREAM.md written and current (2026-08-18): pinned sources table, 26-file macOS/iOS patch inventory and checksum, test method, upstream update procedure, known upstream issues, compatibility matrix.
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
- The legacy RmlUi launcher is dormant in normal macOS flows (native home for implicit profile; direct runtime for explicit profile) and is not separately exercised on Metal.
- Physical controller play on macOS: BLOCKED (external) - both paired pads (8BitDo Lite 2, Xbox Wireless) are Not Connected; SDL sees 0 joysticks. Code path verified via virtual controller; see docs/KNOWN_ISSUES.md.
- DinoMod redistribution permission: BLOCKED (release gate only; technical work may continue).
- Physical iPhone/iPad, progression certification, and release packaging remain open; see docs/HANDOFF.md and docs/TECHNICAL_DEBT.md.

## Last successful commands

```sh
./scripts/apply-patches.sh                           # PASS: all 26 maintained patches applied; replay check PASS
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
scripts/build-ios-device.sh                         # PASS: unsigned ROM-free arm64 iOS app; package audit green
scripts/check-macos-package-safety.sh               # PASS: self-contained app, rights-safe selected resources/notices
python3 tools/validate_compiled_dependency_inventory.py  # PASS: 2227 files, 46 components, 0 uncovered
python3 tools/validate_package_rights_inventory.py  # PASS: 17 components, 8 resources, 2 unresolved states, 5 blockers
scripts/runtime-guard.sh iphone-simulator <UDID> scripts/smoke-ios-phase5.sh  # PASS: 600 s gameplay + game-save relaunch/isolation
scripts/runtime-guard.sh iphone-simulator <UDID> scripts/smoke-ios-diagnostics.sh  # PASS: bounded redaction/share/modal cleanup
scripts/runtime-guard.sh iphone-simulator <UDID> scripts/smoke-ios-settings.sh  # PASS: live typed settings + two-launch persistence/modal/profile isolation
scripts/runtime-guard.sh iphone-simulator <UDID> scripts/smoke-ios-layout.sh  # PASS: editor + two-launch idiom persistence/reset + menu
scripts/runtime-guard.sh iphone-simulator <UDID> scripts/smoke-ios-rom-import.sh  # PASS: picker/rejection/all byte orders/replacement
scripts/runtime-guard.sh iphone-simulator <UDID> scripts/smoke-ios-home.sh  # PASS: native home/warning, gameplay -> home -> second profile/runtime, no crash
scripts/runtime-guard.sh iphone-simulator <UDID> scripts/smoke-ios-restoration.sh  # PASS: embedded-only static Restored title + controllable gameplay
scripts/runtime-guard.sh iphone-simulator <UDID> scripts/smoke-ios.sh  # PASS: full input/lifecycle regression, no crash, clean shutdown
```

## Current evidence

- iPhone completed Phase 5, 600-second gameplay, and game-save relaunch/isolation (2026-08-17): docs/evidence/2026-08-17/iphone-phase5/.
- iPhone bounded diagnostics, adversarial redaction, and native share/cancel (2026-08-17): docs/evidence/2026-08-17/iphone-diagnostics/.
- iPhone persisted touch-layout editor and independent phone/tablet reset (2026-08-17): docs/evidence/2026-08-17/iphone-touch-layout/.
- iPhone native settings/status, live bridges, and two-launch persistence (2026-08-17): docs/evidence/2026-08-17/iphone-native-settings/.
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
- Physical-device Phase 7 is externally blocked: CoreDevice knows no device and
  the keychain has no valid code-signing identity. The unsigned `iphoneos`
  compile is green; resume signing/install when both prerequisites are present.
- RT64 Metal/iOS now renders on Simulator, but lifecycle, orientation on physical
  hardware, longer stability, and device behavior need dedicated verification.
- Name-entry navigation quirks (analog-only, +3 jump) must be handled by the touch/controller shell and automated smoke input.
- Automated macOS input requires the DinoPad window to be frontmost; sendkey.sh handles it, but native input injection (or SDL-internal injection) is the durable fix for smoke automation.
- Physical-device runs must repeat the embedded-only restoration policy and gameplay proof.

## Next three candidate goals

1. Build, sign, install, and validate the complete product/runtime matrix on a physical iPhone.
2. Repeat the physical-device matrix on iPad.
3. Complete progression/stability certification and release packaging.

## Selected next goal

Goal 31a: inventory connected Apple devices and signing availability, then build,
sign, install, and validate DinoPad on one supported physical iPhone. Cover native
setup/home/import/menu/layout/settings/diagnostics, orientation and safe areas,
touch/controller/lifecycle/audio behavior, Restored gameplay, save/relaunch,
thermal/memory observations, ROM-free device-arm64 packaging, and crash cleanup.
The compile/preflight portion is green, but no known device or signing identity
is currently available. Continue safe build/package preparation and recheck the
external prerequisites before any physical runtime claim.

Goal 30a outcome: iPad Simulator Phase 6 is green. The complete tablet shell and
runtime matrix passed under one-runtime guards, including measured PaperPad
parity, independent tablet persistence, restoration gameplay, 600-second live
save verification, and same-install relaunch. Evidence:
docs/evidence/2026-08-17/ipad-simulator-phase6/.

Goal 29a outcome: iPhone Simulator Phase 5 is green. A game-created Restored
save survived a 600-second controllable gameplay process and same-install
relaunch back into controllable gameplay; all seven input/lifecycle suites
passed and the Prototype sentinel remained unchanged. Evidence:
docs/evidence/2026-08-17/iphone-phase5/.

Goal 28c outcome: private diagnostics capture is bounded to a 4 MiB current log
plus one predecessor, every complete line is sanitized before persistence, and
shared tails/reports are capped at 192/512 KiB. A guarded adversarial harness
proved useful status, native share/cancel, modal input restoration, private file
permissions, cleanup, ROM-free packaging, and no path leaks. Evidence:
docs/evidence/2026-08-17/iphone-diagnostics/.

Goal 28b outcome: the native settings sheet and non-diagnostics section 3.4
menu/status contract are green. Typed live bridges cover touch, display, audio,
mode/status, and game data; a guarded two-launch harness proves defensive load,
serialization, relaunch, modal input policy, and profile isolation. Evidence:
docs/evidence/2026-08-17/iphone-native-settings/.

Goal 28a outcome: independent phone/tablet layout persistence and reset are
green. The visible editor supports move/resize/fade/hide, D-pad/C linking,
safe-area clamping, reset, one-step undo, and full-session cancel. A guarded
two-process harness proved relaunch persistence, idiom isolation, input clearing,
and dismissal restoration. Evidence:
docs/evidence/2026-08-17/iphone-touch-layout/.

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
