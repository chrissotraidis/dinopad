# DinoPad Pause-Point Handoff

Last updated: 2026-08-16T20:11:57Z

This is the canonical pause-point summary for the next implementation session.
It complements `docs/STATUS.md` (chronological evidence),
`docs/TECHNICAL_DEBT.md` (known engineering debt), and
`docs/UI_PARITY.md` (PaperPad parity contract).

## Executive truth

DinoPad has a real ROM-free, native arm64 runtime. The macOS implementation is
mature enough to boot both Restored and Prototype profiles, import and validate
the supported ROM, play with audio and input, and persist saves. The iPhone
Simulator target builds and renders through RT64 Metal, and the first native
touch slice now reaches the actual N64 input poll path.

It is not a release-ready iPhone/iPad product. Phase 4 (Apple shell) and Phase 5
(iPhone Simulator) are partial. Phases 6-10 (iPad, physical devices,
progression/stability, and release) remain open.

## Completed foundation

- Pinned and push-disabled reference sources with replayable maintained patches.
- ROM-free native Apple Silicon macOS runtime and app bundle.
- Static arm64 DinoMod code plus no-write replacement/hook dispatch.
- Restored-default and warned Prototype profiles with isolated config/save roots.
- Native macOS ROM setup, exact fingerprint validation, byte-order normalization,
  profile home, and ROM replacement.
- Verified macOS title flow, controllable gameplay, audio pipeline, input, save
  persistence, clean shutdown, and bounded smoke automation.
- ROM-free arm64 iPhone Simulator build with RT64 Metal first frame and audio.
- Initial iPhone touch overlay with every N64 control, PaperPad-derived phone and
  tablet defaults, safe-area placement, tap latching, analog response, lifecycle
  clearing hooks, controller hiding, and an accessible persistent menu button.
- Live iPhone input evidence for A (`0x8000`), Z (`0x2000`), Start (`0x1000`),
  and C-left (`0x0002`) reaching `get_n64_input`.
- The menu visibly hides gameplay controls and reports controller status.
- The latest guarded iPhone run remained live for 90 seconds, captured a frame,
  created no crash report, and left zero booted Simulators/processes.

## Current iPhone touch slice

The pause-point changes are centered in:

- `apple/app/ios_main.mm`
- `patches/dino-recomp/0001-macos-sdl-metal-window.patch`
- `patches/dino-recomp/0004-input-debug-log.patch`
- `patches/dino-recomp/0008-ios-touch-input-bridge.patch`
- `CMakeLists.txt`

The overlay is attached to SDL's UIKit window after its Metal view is created.
Touch state is merged into the existing keyboard/controller result in
`dino::input::get_n64_input`; it does not bypass the normal game callback.
Controller add/remove events drive touch visibility. CoreSimulator's synthetic
controller is deliberately ignored so Simulator testing can show touch controls.

The current menu is a functional scaffold, not the Definition-of-Done menu.
`Touch Layout & Settings` and `Game Data & Diagnostics` are explicitly marked
as coming next.

## What is actually left

### Phase 4/5: finish iPhone

1. Add the native UIKit Files importer, exact rejection messages, normalization,
   atomic private storage, and ROM replacement.
2. Add DinoPad home/mode choice before runtime startup: Restored primary,
   explicit warning for Prototype, and isolated profile handoff.
3. Package the permitted non-code restoration data for mobile and prove that
   Restored—not only the base prototype—boots on iPhone.
4. Verify analog through the real N64 poll path, then exercise B, L, R, all
   D-pad/C directions, A/Z/Start, and simultaneous multi-touch.
5. Implement independent persisted phone/tablet layout editing and reset.
6. Replace menu placeholders with the complete plan-listed menu: game/mode,
   restoration/save status, controls, display, audio, game data, support,
   diagnostics, and quit-to-home.
7. Add settings bridges for volume, aspect, internal resolution, frame rate,
   HUD placement, and touch opacity/enablement.
8. Add diagnostics log/share and ROM manager flows.
9. Prove background/foreground clears held input and safely pauses/resumes.
10. Prove supported ROM -> Restored title -> controllable gameplay, save/relaunch,
    clean shutdown, and the full 10-minute iPhone Simulator smoke.

### Phase 6: iPad Simulator

- Boot only after iPhone Simulator is shut down.
- Validate independent tablet layout, layout persistence, safe areas, orientation,
  larger menu/settings presentation, controller handoff, Restored gameplay, and
  save/relaunch.
- Produce a measured parity report against the PaperPad tablet shell.

### Phases 7-8: physical devices

- Build/sign/install device-arm64 on one supported iPhone and one iPad.
- Validate orientation, touch, controller, audio session/interruption, lifecycle,
  saves, thermal behavior, memory pressure, and clean relaunch.
- Physical hardware is the authority for orientation; iOS 26.5 headless Simulator
  raw screenshots preserve a portrait framebuffer for landscape-only SDL apps.

### Phase 9: progression and stability

- Run the private fixture matrix.
- Complete at least one Restored start-to-credits physical-device playthrough.
- Resolve any immediate progression or save blocker.
- Add longer soak, repeated lifecycle, repeated import, and corruption-recovery
  coverage.

### Phase 10: release

- Produce and audit a ROM-free unsigned IPA.
- Complete GPL source/notice obligations, attribution, non-affiliation language,
  README, installation guide, release checklist, tag, and checksums.
- Obtain explicit DinoMod integration/redistribution permission. This is a real
  external release blocker; it does not block technical development.

## Non-negotiable invariants

- Never track, package, log, or publish ROMs, saves, private fixtures, signing
  material, or private absolute paths.
- No JIT, LiveRecomp, SLJIT, runtime patch writes, or downloaded executable code.
- Keep Restored/Prototype configs and saves isolated.
- Treat PaperPad as the Apple-shell/N64-feature parity reference while using
  DinoPad-owned branding and Dinosaur Planet-specific product choices.
- Use `scripts/runtime-guard.sh`; exactly one runtime/Simulator may run at once.
- Keep every upstream change in a replayable patch and update the patch checksum.
- Run `scripts/check-repo-safety.sh` before every milestone commit/push.

## Resume order

1. Read `docs/NEXT_AGENT_PROMPT.md` and the documents it names.
2. Confirm `main` is clean and reference push URLs remain disabled.
3. Run patch replay, repository safety, macOS incremental build, and iOS
   Simulator build before changing behavior.
4. Finish Goal 26c: fully verify and harden touch/lifecycle/menu behavior.
5. Then implement the UIKit ROM setup/home boundary before expanding settings.

