# DinoPad Upstream Sources and Patch Strategy

Last updated: 2026-08-18
Source of truth: docs/IMPLEMENTATION_PLAN.md section 6 (upstream and patch strategy).
Exact pins also recorded in dependencies.lock.json (keep the two in sync).

## 1. Pinned sources

| Component | Repository | Pin | Commit | License | Purpose |
|---|---|---|---|---|---|
| PaperPad | github.com/chrissotraidis/paperpad | commit | `644945d4bc4facbbd8ecda8cdfd37ae64e7993fa` | see repo | Apple shell reference (UI, touch, architecture) |
| Dino Recompiled | github.com/DinosaurPlanetRecomp/dino-recomp | v0.3.0 | `725b2ede9cacc57968e0a028efed8df9235ba483` | GPLv3 (COPYING) | Base Dinosaur Planet static recompilation |
| DinoMod Enhanced | github.com/EoinODoodles/dinomod-enhanced-recompiled | v0.9.3 | `d79e86be2304cba75216b0b98e9fb53ee99b7500` | none declared; no-AI policy | Progression restoration (read-only until clearance) |
| SDL2 | github.com/libsdl-org/SDL | release-2.32.10 | `5d249570393f7a37e037abf22cd6012a4cc56a71` | zlib (LICENSE.txt) | In-tree static SDL2 for Apple targets; inherits architecture and deployment target |
| FreeType | gitlab.freedesktop.org/freetype/freetype | VER-2-13-3 | `42608f77f20749dd6ddc9e0536788eaad70ea4b5` | FreeType License (LICENSE.TXT) | Static macOS RmlUi font engine; optional external dependencies disabled |

Dino Recompiled v0.3.0 recursive submodules (exact commits in
`dependencies.lock.json`): N64ModernRuntime, N64Recomp, RmlUi,
SDL_GameControllerDB, SlotMap, dino-recomp-decomp-bridge,
freetype-windows-binaries, lunasvg, rt64.

DinoMod Enhanced v0.9.3 submodules: dino-recomp-decomp-bridge,
dino-recomp-mod-api. The decomp bridge's nested `dinosaur-planet` submodule is
pinned at `6615627aa2fefbcf82b652880d6db64aba3f1609` and is required for the
mod's MIPS ELF build (decomp headers); push URL disabled.

Mod build prerequisites (added 2026-08-16 for the AOT feasibility run):
`xdelta3` (brew install xdelta), Python 3.9+ venv with PyYAML/toml/pylibyaml,
and the pinned n64recomp-clang MIPS toolchain under `build-tools/toolchains/`.

Supported ROM: December 2000 Dinosaur Planet prototype, MD5
`49f7bb346ade39d1915c22e090ffd748` (user-supplied, never tracked).

## 2. Reference checkout rules

- Checkouts live under `ref/` (gitignored) with push URLs disabled.
- Never edit a file in `ref/` as the final solution; every maintained change
  is a DinoPad-owned adapter or a replayable patch under `patches/`.
- `scripts/bootstrap.sh`, `scripts/apply-patches.sh`, and
  `scripts/check-repo-safety.sh` verify checkout state, patch application, and
  push-URL safety.

## 3. DinoPad patch series (applies to pinned dino-recomp v0.3.0)

Ordered, numbered, replayable with `scripts/apply-patches.sh`:

| Patch | File(s) | Why it exists | Upstream semantic preserved? |
|---|---|---|---|
| 0001-macos-sdl-metal-window.patch | src/runtime/gfx.cpp | Ports the PaperPad Apple Metal-window path: RT64 receives the native window + CAMetalLayer; iOS attaches DinoPad's touch overlay after SDL creates its UIKit window | Yes (Apple-only branch) |
| 0002-disable-imgui-debug-overlay-on-apple.patch | src/debug_ui/backend.cpp | The pinned imgui debug overlay has no Metal backend and dereferences a Vulkan device; disabling on Apple keeps the game loop alive. The RmlUi launcher registers its own UI | Yes (Apple-only) |
| 0003-macos-app-folder-path.patch | src/config/config.cpp | Adds PaperPad-style Apple data root plus mode-scoped config roots and a disposable-root test override | Yes (Apple-only path; profile policy is DinoPad-specific) |
| 0004-input-debug-log.patch | src/input/controls.cpp | Env-gated (`DINOPAD_LOG_INPUT=1`) input logging plus the iOS-only merge of DinoPad touch snapshots into the normal N64 poll result | Yes (logging off by default; touch branch iOS-only) |
| 0005-audio-debug-log.patch | src/runtime/audio.cpp | Env-gated (`DINOPAD_LOG_AUDIO=1`, `DINOPAD_AUDIO_DUMP=<path>`) audio diagnostics; disabled by default | Yes (off by default) |
| 0006-session-profiles.patch | main/config/mod registration | Adds Restored-default and explicit Prototype session selection; Prototype disables mod scanning/registration | DinoPad product policy |
| 0007-ios-ui-platform-guards.patch | desktop RmlUi state/config/mod menu | Leaves the uninitialized desktop UI inert while UIKit owns the iOS shell; avoids desktop folder commands and null model access | Yes (iOS-only shell boundary) |
| 0008-ios-touch-input-bridge.patch | src/input/input.cpp | Reports physical-controller add/remove state to the UIKit overlay; CoreSimulator's synthetic controller is filtered in the DinoPad-owned bridge | Yes (iOS-only UI/input handoff) |
| 0009-ios-noop-choice-prompt.patch | src/ui/ui_prompt.cpp | Keeps the desktop RmlUi choice prompt inert while UIKit owns the iOS shell | Yes (iOS-only UI boundary) |
| 0010-restartable-ios-window-audio.patch | renderer/runtime startup and audio/window teardown | Makes iOS renderer hooks idempotent and explicitly closes audio plus destroys the SDL window so a second runtime can start in-process | Yes (iOS lifecycle fix; desktop behavior preserved) |
| 0011-rights-safe-launcher-assets.patch | desktop launcher RML/image loading and font registration | Replaces unproven logo/character bitmap use with text and uses the already-pinned OFL Lato family instead of DinoFont/Noto fallback | Product packaging policy; gameplay behavior preserved |

Additional patch: `patches/hlslpp/0001-scalar-labs.patch` (hlslpp scalar
platform header fix required by the pinned RT64/hlslpp combination on Apple).

Nested upstream patches applied by checkout basename:

| Patch | File(s) | Why it exists | Upstream semantic preserved? |
|---|---|---|---|
| `patches/rt64/0001-metal-worker-autorelease-lifetime.patch` | RT64 application, queues, worker threads | Stops/joins Metal workers before dependent resources and scopes Apple autoreleases; fixes the `RT64 Present` shutdown crash | Yes (lifetime/Apple ownership fix) |
| `patches/rt64/0002-ios-renderer-foundation.patch` | RT64 renderer/shader configuration | Uses mobile-safe sampler limits, iOS Metal SDK settings, and Simulator pipeline behavior | Yes (iOS-only portability) |
| `patches/rt64/0003-cross-compile-host-tools.patch` | RT64 CMake host-tool path | Uses pinned native shader/file conversion tools while cross-compiling | Yes (cross-build only) |
| `patches/rt64/0004-foundation-home-directory.patch` | RT64 Apple path helper | Replaces the AppKit-only home lookup with Foundation | Yes (Apple portability) |
| `patches/plume/0001-metal-ownership-balance.patch` | `plume_metal.cpp` | Balances Metal encoder ownership and avoids over-releasing autoreleased Objective-C objects | Yes (Metal ownership fix) |
| `patches/plume/0002-ios-metal-platform.patch` | Plume Apple/Metal backend | Adds UIKit window metrics, mobile device metadata, main-thread layer access, nil timestamp-query handling, and synchronous cached iOS metrics so queued blocks cannot outlive a destroyed window | Yes (iOS/Simulator portability and lifetime fix) |
| `patches/N64ModernRuntime/0001-static-mod-code-factories.patch` | librecomp mod API/loader | Lets an application register a build-time `ModCodeHandle` factory by manifest ID, before offline-library/live-recompiler fallback | Yes (opt-in generic API) |
| `patches/N64ModernRuntime/0002-static-dispatch-lifecycle.patch` | librecomp mod API/loader | Lets a static handle own replacement/hook dispatch and skip runtime writes while preserving conflict tracking and unload behavior | Yes (opt-in generic API; dynamic/live handles unchanged) |
| `patches/N64ModernRuntime/0003-separate-data-config-roots.patch` | librecomp ROM/mod/config paths | Separates shared ROM/package data from per-profile config/save roots and permits disabling mod scanning before startup | Yes (opt-in APIs; legacy one-root default preserved) |
| `patches/N64ModernRuntime/0004-no-dynamic-code.patch` | runtime CMake/mod loader | Excludes LiveRecomp/SLJIT and makes live handles inert for mobile no-code-generation builds | Yes (opt-in build mode) |
| `patches/N64ModernRuntime/0005-restartable-sessions.patch` | runtime startup/shutdown, events, timers, guest threads, overlays | Resets per-session state, unloads static mods, joins timers and all registered N64 guest host threads before freeing RDRAM, and makes overlay/manual symbol registration restart-safe | Yes (lifecycle cleanup; single-session behavior preserved) |
| `patches/N64ModernRuntime/0006-embedded-only-mod-scanning.patch` | librecomp mod discovery | Lets constrained builds load application-registered embedded packages while refusing all writable-filesystem mod discovery | Yes (opt-in policy; desktop scanning remains the default) |
| `patches/N64ModernRuntime/0007-static-extended-imports.patch` | librecomp static import binding | Lets a static code handle bind extended exports directly when runtime shim generation is disabled | Yes (opt-in static binding; dynamic/live handles unchanged) |
| `patches/nativefiledialog-extended/0001-ios-null-backend.patch` | NFD platform selection | Provides an inert backend while the native UIKit document picker is implemented by DinoPad | Yes (iOS-only boundary) |

The twenty-six-file patch set is locked in `dependencies.lock.json` at SHA-256
`2b66b9147f8b2cae2e96728a3841ef6e0a84e0c74c1a7ef83fe0d749c27233be`.
`scripts/check-repo-safety.sh` recomputes and verifies it.

## 4. How patches are tested

Each patch is applied to the pinned checkout, then:

1. `cmake --build build-macos --target DinoPad` (macOS arm64 compile).
2. `scripts/runtime-guard.sh macos scripts/smoke-macos.sh` (boot -> GAME
   SELECT -> save load -> playable scene -> input -> clean shutdown).
3. `scripts/runtime-guard.sh macos scripts/smoke-graceful-shutdown-macos.sh 5`
   (native close -> status 0 -> no new crash report).
4. Targeted evidence sessions for behavior (title/audio, gameplay input, save
   persistence, app bundle).
5. `scripts/build-ios-simulator.sh` followed by guarded ROM-import,
   home/two-runtime restart, and full input/lifecycle smokes.

Patch state is verified by `scripts/check-repo-safety.sh` before every commit
cycle; a patch that cannot be replayed cleanly is a blocker for that cycle.

## 5. Upstream update procedure (from the implementation plan)

A version update is never "change the tag and see what happens":

1. Create an update branch.
2. Update one upstream component at a time.
3. Record old/new tag and commit in dependencies.lock.json and this file.
4. Reapply patches; classify every conflict (plan section 6.3).
5. Build macOS; run the macOS smoke test.
6. Build iPhone Simulator; run iPhone smoke; shut it down.
7. Build iPad Simulator; run iPad smoke; shut it down.
8. Run the private fixture matrix; compare screenshots.
9. Merge only after the previously green matrix remains green.

No user-facing backward-compatibility layer is required: a DinoPad release
supports only its bundled pins.

## 6. Known upstream issues

- Dino Recompiled has no official macOS support (open upstream issue);
  DinoPad's Apple work is patch-based and tested in this repository.
- RT64 Metal prints "RenderPool in Metal is not implemented currently"; it is
  a non-fatal upstream note (resources are created on the device directly);
  see docs/KNOWN_ISSUES.md.
- DinoMod Enhanced declares no conventional license and has a strict no-AI
  policy; treat as read-only and redistribution-prohibited until maintainers
  grant explicit permission (docs/DINOMOD_INTEGRATION.md gate).

## 7. Compatibility matrix

| Target | Toolchain | Status |
|---|---|---|
| macOS arm64 | Xcode 26.6 / Apple Clang 21.0.0 / CMake 3.27.1 / Ninja 1.13.2 | Green (Phase 2 evidence) |
| iPhone Simulator arm64 | Xcode 26.6 / iOS 26.5 Simulator | Green (Phase 5): full native shell/runtime matrix, save relaunch, and 600-second gameplay evidenced |
| iPad Simulator arm64 | Xcode 26.6 / iPadOS 26.5 Simulator | Green (Phase 6): full native shell/runtime matrix, measured PaperPad parity, save relaunch, and 600-second gameplay evidenced |
| Physical iPhone / iPad | Xcode 26.6 / iPhoneOS 26.5 SDK | Unsigned arm64 device build green; signing/install/runtime blocked by zero known devices and zero valid identities (Phases 7-8) |
