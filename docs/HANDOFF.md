# DinoPad Pause-Point Handoff

Last updated: 2026-08-17T00:00:00Z

This is the canonical pause-point summary for the next implementation session.
It complements `docs/STATUS.md` (chronological evidence),
`docs/TECHNICAL_DEBT.md` (known engineering debt), and
`docs/UI_PARITY.md` (PaperPad parity contract).

## Executive truth

DinoPad has a real ROM-free, native arm64 runtime. The macOS implementation is
mature enough to boot both Restored and Prototype profiles, import and validate
the supported ROM, play with audio and input, and persist saves. The iPhone
Simulator target builds and renders through RT64 Metal. Full default N64 touch,
input/lifecycle/controller handoff, native Files ROM import, and ROM replacement
are now verified through bounded guarded smokes.

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
- iPhone touch overlay with every N64 control, PaperPad-derived phone and
  tablet defaults, safe-area placement, tap latching, analog response, lifecycle
  clearing hooks, controller hiding, and an accessible persistent menu button.
- Deterministic runtime evidence for all 14 digital masks, all analog cardinal
  directions/zero return, simultaneous stick+A+B+Z, modal/background clearing,
  foreground resume, and controller handoff through the actual N64 poll.
- Native first-run Files picker and in-game ROM manager with exact 64 MiB/MD5
  validation, z64/v64/n64 normalization, atomic protected private storage,
  invalid rejection without staging, and ROM-free bundle proof.

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
ROM management is live; touch layout/settings and diagnostics remain incomplete.

## What is actually left

### Phase 4/5: finish iPhone

1. Add DinoPad home/mode choice before runtime startup: Restored primary,
   explicit warning for Prototype, and isolated profile handoff.
2. Package the permitted non-code restoration data for mobile and prove that
   Restored—not only the base prototype—boots on iPhone.
3. Implement independent persisted phone/tablet layout editing and reset.
4. Replace menu placeholders with the complete plan-listed menu: game/mode,
   restoration/save status, controls, display, audio, game data, support,
   diagnostics, and quit-to-home.
5. Add settings bridges for volume, aspect, internal resolution, frame rate,
   HUD placement, and touch opacity/enablement.
6. Add bounded diagnostics log/redaction/share flows.
7. Prove supported ROM -> Restored title -> controllable gameplay, save/relaunch,
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
4. Implement Goal 27b: UIKit Restored-primary/warned-Prototype home boundary.
5. Then package permitted restoration data and prove Restored iPhone gameplay.
