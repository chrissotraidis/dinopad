# DinoPad Pause-Point Handoff

Last updated: 2026-08-18T05:22:31Z

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
are verified through bounded guarded smokes. A native UIKit home now precedes
SDL, makes Restored primary, warns before Prototype, and can tear down live
gameplay back to home before launching a second isolated profile in-process.
The iPhone app now embeds only a sanitized non-executable restoration data
package, refuses writable mods, and visibly reaches the restored title and
controllable tutorial through statically linked no-write arm64 dispatch.
The touch layout is now a real persisted product surface: phone/tablet keys are
independent, and the editor supports safe-area move, resize, fade, hide/show,
directional linking, reset, undo, Done, and Cancel.
The native settings/status sheet is also green on iPhone Simulator: typed live
controls persist touch, audio, and display options per policy, while mode,
restoration, save/recovery, controller, and effective-render status remain
truthful. Bounded protected diagnostics now redact every complete line before
persistence, expose useful non-content status, and share through native UIKit
while preserving modal input policy.

The iPhone Simulator Phase 5 and iPad Simulator Phase 6 gates are green. On each
idiom, a game-created Restored save survived a 600-second controllable session
and same-install process relaunch back into controllable gameplay while
Prototype remained unchanged. The iPad run also proves native tablet
presentation, independent layout persistence, complete input/lifecycle behavior,
bounded diagnostics, and measured PaperPad parity. It is not a release-ready
iPhone/iPad product: Phases 7-10 (physical devices, progression/stability, and
release) remain open.

The repository now has an evidence-backed root README and an explicit
`docs/RIGHTS_AND_LICENSES.md` boundary. They advertise no download: the missing
root license/complete third-party notice set and DinoMod permission are recorded
release blockers alongside physical-device and progression work.
The first package-specific rights inventory now validates exact pins,
license-text hashes, direct macOS link inputs, and selected resource hashes. It
also records that raw-ROM absence does not settle redistribution rights for the
compiled private AOT. The package now removes the unproven DinoFont, Noto Emoji,
logo, and character-art files, uses the pinned Lato family, and carries exact
Lato attribution plus SIL OFL 1.1 text. This closes those selected-resource
findings without claiming a complete transitive notice audit.

## Completed foundation

- Pinned and push-disabled reference sources with replayable maintained patches.
- ROM-free native Apple Silicon macOS runtime and app bundle.
- Self-contained macOS packaging with pinned static FreeType, resolved assets,
  system-only runtime dependencies, ad-hoc signature verification, and a
  reusable package-safety gate.
- Fail-closed macOS package-rights inventory covering 17 direct linked
  components and 8 selected resources. Its 2 unresolved states and 5 release
  blockers remain explicitly red.
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
- Native UIKit Restored/Prototype chooser before SDL, explicit Prototype archival
  warning, reachable quit-to-home action, isolated profile handoff, and a guarded
  live Restored -> home -> Prototype in-process restart with no crash.
- Deterministic embedded restoration data with the complete MIPS executable
  segment erased, writable mod scanning disabled, and guarded iPhone proof of
  restored `PRESS START`, controllable cannon gameplay, and Prototype omission.
- Native touch-layout customization/reset actions plus a guarded two-process
  proof of phone persistence, tablet isolation, safe-area clamping, input
  clearing/restoration, reset, undo, and full-session cancel.
- Safe-area native settings/status with live typed touch/audio/display bridges
  and a guarded two-launch proof of clamping, serialization, relaunch loading,
  profile isolation, modal clearing, and post-dismissal input.
- Bounded protected diagnostics with pre-persistence path redaction, useful
  content-free status, native share/cancel, temporary cleanup, and a guarded
  adversarial proof of caps, permissions, modal clearing, and input restoration.
- Completed iPhone Simulator Phase 5 with a 600-second live Restored gameplay
  run, game-created FlashRAM persistence across same-install relaunch, complete
  input/lifecycle rerun, profile isolation, and clean runtime-guard teardown.
- Completed iPad Simulator Phase 6 on an iPad Pro 11-inch (M5): all shell,
  layout, settings, diagnostics, ROM, restoration, input/lifecycle, endurance,
  and same-install save/relaunch gates passed; menu geometry matched PaperPad
  exactly and the largest conservative control-center delta was 0.64 point.

## Current iPhone touch slice

The pause-point changes are centered in:

- `apple/app/ios_main.mm`
- `apple/app/home.h`
- `apple/app/home.mm`
- `apple/app/settings.h`
- `apple/app/settings.mm`
- `apple/app/diagnostics.h`
- `apple/app/diagnostics.mm`
- `patches/dino-recomp/0001-macos-sdl-metal-window.patch`
- `patches/dino-recomp/0004-input-debug-log.patch`
- `patches/dino-recomp/0008-ios-touch-input-bridge.patch`
- `patches/dino-recomp/0010-restartable-ios-window-audio.patch`
- `patches/N64ModernRuntime/0005-restartable-sessions.patch`
- `patches/plume/0002-ios-metal-platform.patch`
- `CMakeLists.txt`

The overlay is attached to SDL's UIKit window after its Metal view is created.
Touch state is merged into the existing keyboard/controller result in
`dino::input::get_n64_input`; it does not bypass the normal game callback.
Controller add/remove events drive touch visibility. CoreSimulator's synthetic
controller is deliberately ignored so Simulator testing can show touch controls.

The current menu reaches real ROM management, touch-layout customization/reset,
quit-to-home, the complete settings/status hierarchy, and bounded redacted
diagnostics through a native share sheet. The iPhone and iPad Simulator menu
contracts are green.

## What is actually left

### Phases 7-8: physical devices

- Build/sign/install device-arm64 on one supported iPhone and one iPad.
- Validate orientation, touch, controller, audio session/interruption, lifecycle,
  saves, thermal behavior, memory pressure, and clean relaunch.
- Physical hardware is the authority for orientation; iOS 26.5 headless Simulator
  raw screenshots preserve a portrait framebuffer for landscape-only SDL apps.
- Phase 7 preflight currently finds zero CoreDevice devices and zero valid
  code-signing identities. `scripts/build-ios-device.sh` is green in unsigned
  mode: arm64-only, physical `IOS` platform, ROM-free, and free of signature or
  provisioning state. Resume signing/install when hardware and an identity exist;
  see `docs/evidence/2026-08-17/physical-device-preflight/`.
- Simulator automation is now compile-time test-only. Simulator builds opt in;
  physical builds force it off. The reusable device-app safety gate proves the
  physical Mach-O contains no automation keys/selectors/fixtures or private
  paths and rejects a test-enabled Simulator app; see
  `docs/evidence/2026-08-17/physical-device-release-boundary/`.
- Both iOS products now contain an exact root privacy manifest. The package gate
  validates no tracking/collection and the known required-reason set, with a
  tampered tracking declaration rejected. A final transitive dependency/Xcode
  privacy report remains open; see
  `docs/evidence/2026-08-17/privacy-manifest/`.

### Phase 9: progression and stability

- Extend the validated `docs/PROGRESSION_FIXTURES.json` manifest beyond its one
  early-game `AAAAA` entry, then run the private fixture matrix.
- Complete at least one Restored start-to-credits physical-device playthrough.
- Resolve any immediate progression or save blocker.
- Add longer soak, repeated lifecycle, repeated import, and corruption-recovery
  coverage.

### Phase 10: release

- Keep [`RELEASE_CHECKLIST.md`](RELEASE_CHECKLIST.md) current; it now separates
  green engineering audits from red distribution prerequisites and forbids
  packaging while any P0 gate is red.
- Produce and audit a ROM-free unsigned IPA only after those prerequisites pass.
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
4. Continue Goal 31a with connected-device/signing inventory and the complete
   physical iPhone Phase 7 matrix.
