# DinoPad Upstream Sources and Patch Strategy

Last updated: 2026-08-16
Source of truth: docs/IMPLEMENTATION_PLAN.md section 6 (upstream and patch strategy).
Exact pins also recorded in dependencies.lock.json (keep the two in sync).

## 1. Pinned sources

| Component | Repository | Pin | Commit | License | Purpose |
|---|---|---|---|---|---|
| PaperPad | github.com/chrissotraidis/paperpad | commit | `644945d4bc4facbbd8ecda8cdfd37ae64e7993fa` | see repo | Apple shell reference (UI, touch, architecture) |
| Dino Recompiled | github.com/DinosaurPlanetRecomp/dino-recomp | v0.3.0 | `725b2ede9cacc57968e0a028efed8df9235ba483` | GPLv3 (COPYING) | Base Dinosaur Planet static recompilation |
| DinoMod Enhanced | github.com/EoinODoodles/dinomod-enhanced-recompiled | v0.9.3 | `d79e86be2304cba75216b0b98e9fb53ee99b7500` | none declared; no-AI policy | Progression restoration (read-only until clearance) |
| SDL2 | github.com/libsdl-org/SDL | release-2.32.10 | `5d249570393f7a37e037abf22cd6012a4cc56a71` | zlib (LICENSE.txt) | Native static SDL2 for macOS (avoids Homebrew sdl2-compat shim) |

Dino Recompiled v0.3.0 recursive submodules (exact commits in
`dependencies.lock.json`): N64ModernRuntime, N64Recomp, RmlUi,
SDL_GameControllerDB, SlotMap, dino-recomp-decomp-bridge,
freetype-windows-binaries, lunasvg, rt64.

DinoMod Enhanced v0.9.3 submodules: dino-recomp-decomp-bridge,
dino-recomp-mod-api.

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
| 0001-macos-sdl-metal-window.patch | src/runtime/gfx.cpp | Ports the PaperPad macOS window path: RT64 needs the NSWindow + CAMetalLayer as WindowHandle{window, view} | Yes (Apple-only branch) |
| 0002-disable-imgui-debug-overlay-on-apple.patch | src/debug_ui/backend.cpp | The pinned imgui debug overlay has no Metal backend and dereferences a Vulkan device; disabling on Apple keeps the game loop alive. The RmlUi launcher registers its own UI | Yes (Apple-only) |
| 0003-macos-app-folder-path.patch | src/config/config.cpp | Upstream has no Apple config path branch (returns empty -> config in CWD). DinoPad uses PaperPad-style `~/Library/Application Support/DinoPad` | Yes (Apple-only) |
| 0004-input-debug-log.patch | src/input/controls.cpp | Env-gated (`DINOPAD_LOG_INPUT=1`) input state logging for smoke tests/evidence; disabled by default | Yes (off by default) |
| 0005-audio-debug-log.patch | src/runtime/audio.cpp | Env-gated (`DINOPAD_LOG_AUDIO=1`, `DINOPAD_AUDIO_DUMP=<path>`) audio diagnostics; disabled by default | Yes (off by default) |

Additional patch: `patches/hlslpp/0001-scalar-labs.patch` (hlslpp scalar
platform header fix required by the pinned RT64/hlslpp combination on Apple).

Patch-set checksum is recorded by `scripts/check-repo-safety.sh` and in the
repository safety audit evidence.

## 4. How patches are tested

Each patch is applied to the pinned checkout, then:

1. `cmake --build build-macos --target DinoPad` (macOS arm64 compile).
2. `scripts/runtime-guard.sh macos scripts/smoke-macos.sh` (boot -> GAME
   SELECT -> save load -> playable scene -> input -> clean shutdown).
3. Targeted evidence sessions for behavior (title/audio, gameplay input, save
   persistence, app bundle).

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
| iPhone Simulator arm64 | tbd | Not started (Phase 5) |
| iPad Simulator arm64 | tbd | Not started (Phase 6) |
| Physical iPhone / iPad | tbd | Not started (Phases 7-8) |
