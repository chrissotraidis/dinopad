# Goal Prompt for the Next DinoPad Agent

Copy the prompt below into the next Codex task. It is intentionally detailed so
the agent can resume from repository evidence rather than re-discovering the
project or overstating completion.

---

You are resuming the DinoPad autonomous implementation goal from the GitHub
`main` branch after the 2026-08-17 iPad Simulator Phase 6 milestone.

## Goal

Execute the DinoPad autonomous implementation loop: create a ROM-free native
Apple Silicon port of the December 2000 Dinosaur Planet prototype for
macOS/iPhone/iPad. Continue the smallest independently verifiable goals until
every Definition of Done gate in `docs/IMPLEMENTATION_PLAN.md` is satisfied or
a genuine external blocker is explicitly documented with evidence.

The desired product must have Apple-shell and N64-feature parity with the pinned
PaperPad reference implementation, adapted for Dinosaur Planet and DinoPad's
Restored/Prototype product policy. Parity includes native static arm64 execution,
Metal, ROM ownership/import, complete N64 touch input, controller handoff,
safe-area/lifecycle behavior, phone/tablet layout editing, settings, diagnostics,
saves, and ROM-free unsigned packaging. Do not copy Paper Mario art or branding.

## Read first, in this order

1. `docs/HANDOFF.md`
2. `docs/STATUS.md`
3. `docs/TECHNICAL_DEBT.md`
4. `docs/UI_PARITY.md`
5. `docs/IMPLEMENTATION_PLAN.md`
6. `docs/DINOPAD_GOAL_LOOP.md`
7. `docs/ARCHITECTURE.md`
8. `docs/UPSTREAM.md`
9. `docs/BUILDING.md`
10. `docs/TESTING.md`
11. `docs/KNOWN_ISSUES.md`

Treat those files and committed evidence as authoritative. Do not infer that a
feature is complete because code exists; require the acceptance evidence named
in the plan.

## Current truth at handoff

- Phases 0-3 are substantially green: repository/pins, macOS native arm64,
  static DinoMod integration, no-write dispatch, profiles, macOS native setup,
  ROM import, gameplay/audio/input/saves, clean shutdown, and smoke tests.
- Phase 4 remains partial pending physical-device parity; iPhone Simulator
  Phase 5 and iPad Simulator Phase 6 are green.
- The shared ROM-free iPhone/iPad Simulator arm64 app builds and renders RT64
  Metal/audio on both idioms.
- The UIKit touch overlay draws all 15 N64 controls plus an accessible
  persistent `•••` button using PaperPad-derived phone/tablet defaults.
- The overlay is attached to SDL's UIKit window and merged into the actual
  `dino::input::get_n64_input` callback.
- Goal 26c proved every digital N64 mask, all analog cardinals/zero return,
  simultaneous stick+A+B+Z, modal/background clearing, foreground resume, and
  controller handoff through the actual runtime input callback.
- Goal 28a added a real native layout editor with move/resize/fade/hide,
  D-pad/C linking, safe-area clamping, reset, one-step undo, full-session Cancel,
  and independent persisted phone/tablet dictionaries. A guarded two-process
  harness proved relaunch persistence, idiom isolation, and input restoration.
- Goal 28b added a safe-area native settings/status sheet with typed live touch,
  audio, resolution, aspect, frame-rate, and HUD bridges plus truthful mode,
  restoration, save/recovery, controller, and effective-render status. Its
  guarded two-launch harness proves clamping, persistence, relaunch, profile
  isolation, modal input clearing, and post-dismissal touch input.
- Goal 28c added protected current/previous diagnostics logs, sanitizes every
  complete line before persistence, caps shared tails/reports, and exposes a
  useful content-free report through the native share sheet. Its adversarial
  harness proves path redaction, permissions, share/cancel, cleanup, modal input
  clearing, and post-dismissal touch restoration.
- The iPhone/iPad Simulator menu exposes real settings, layout, ROM-manager,
  diagnostics share, resume, and quit-to-home actions. Its native menu contract
  is green on both idioms.
- Goal 29a completed Phase 5: a private game-created Restored save survived a
  600-second controllable gameplay launch and same-install process relaunch back
  into controllable gameplay, all seven input/lifecycle suites passed, and the
  Prototype sentinel stayed unchanged.
- Goal 30a completed Phase 6 on iPad Pro 11-inch (M5): every setup/home/ROM/
  layout/settings/diagnostics/input/restoration/endurance gate passed under a
  single-runtime guard. Tablet persistence remained isolated from phone keys,
  Restored stayed live for 600 seconds and survived same-install relaunch into
  gameplay, Prototype remained unchanged, and PaperPad parity measured 0-point
  menu delta plus at most 0.64-point control-center delta.
- Goal 27a added and evidenced the real UIKit Files importer and ROM manager:
  exact size/MD5, z64/v64/n64 normalization, useful rejection, atomic protected
  private storage, replacement/removal, and ROM-free bundle proof.
- Goal 27b added and evidenced the native Restored-primary home before SDL,
  warned Prototype selection, isolated profile handoff, quit-to-home from live
  gameplay, and a second runtime in the same process. Restart teardown now joins
  all guest threads and prevents queued Plume/UIKit work from outliving windows.
- Goal 27c now embeds only deterministic non-executable restoration data,
  disables writable mod scanning, and visibly proves the restored `PRESS START`
  title plus controllable ship-deck cannon gameplay on iPhone. Same-process
  Prototype restart omits package/static dispatch. Redistribution permission is
  still a separate release blocker.
- Device builds, physical-device evidence, progression, and release packaging
  remain open.
- DinoMod redistribution permission is an external release blocker, not a reason
  to stop technical development.

## Immediate next goal: Goal 31a

Complete physical iPhone Phase 7 as the next independently verifiable target.
Start with read-only connected-device and signing inventory. Run only after
confirming every Simulator and DinoPad process is shut down.

Acceptance:

1. Clean patch replay, repository-safety audit, macOS incremental build, and
   Simulator regression remain green.
2. Inventory a connected supported iPhone, available Apple Development team,
   signing identity, and provisioning state without exposing signing material.
3. Build a ROM-free device-arm64 app, sign it with the user's available personal
   development identity, and install it on exactly one guarded physical iPhone.
4. Prove first-run ROM import, Restored-primary home, warned Prototype, menu,
   layout, settings, bounded diagnostics/share, and private storage on device.
5. Validate physical orientation/safe areas, complete touch, suspend/resume,
   audio routes available to the device, controller connect/disconnect if
   hardware is available, and responsive gameplay.
6. Record at least 30 minutes of gameplay with no severe thermal throttling,
   memory termination, crash, or input/audio failure.
7. Perform an in-place update without uninstalling and prove the private ROM and
   game-created save remain valid and profile-isolated after relaunch.
8. Curate privacy-safe device evidence, update parity/status/handoff docs, and
   commit the smallest coherent Phase 7 milestone. If hardware/signing is a
   genuine external blocker, document exact read-only evidence and continue all
   safe build/package preparation that does not require the missing authority.

## Then continue in this order

1. Complete physical iPhone and iPad phases.
2. Run progression/stability matrix and start-to-credits Restored playthrough.
3. Finish legal/release/docs/package gates and ROM-free unsigned IPA.

## Hard constraints

- Never commit/package ROMs, saves, private fixtures, signing data, private
  absolute paths, or generated/private mod output.
- Reference checkouts under `ref/` are ignored, push-disabled, and must remain
  reproducible from maintained patches.
- No JIT, LiveRecomp, SLJIT, runtime code writes, downloaded executable code, or
  arbitrary mod installation.
- Preserve static restoration dispatch and Restored/Prototype save/config
  isolation.
- Use `rg`/`rg --files` first for searches and `apply_patch` for source edits.
- Use exactly one runtime/Simulator at a time through `runtime-guard.sh`.
- Never treat a rotated raw iOS 26.5 headless screenshot as proof of a DinoPad
  orientation bug: the pinned PaperPad app behaves the same. Keep public UIKit/
  SDL orientation contracts and validate physical devices as final authority.
- Run patch replay, safety checks, relevant builds, bounded smoke, and evidence
  curation before each milestone commit.
- Keep reporting honestly: phases 7-10 are not green until their acceptance
  criteria and evidence are actually satisfied.

Start by inspecting `git status`, `git log -5`, the current patch lock, the
current iPad/tablet branches in the shell and smokes, and pinned PaperPad tablet
presentation behavior.
Then execute the smallest verified goal without asking for
clarification unless a genuinely consequential unknown cannot be discovered.

---
