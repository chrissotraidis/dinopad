# Goal Prompt for the Next DinoPad Agent

Copy the prompt below into the next Codex task. It is intentionally detailed so
the agent can resume from repository evidence rather than re-discovering the
project or overstating completion.

---

You are resuming the DinoPad autonomous implementation goal from the GitHub
`main` branch after the 2026-08-16 pause-point merge.

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
- Phase 4 is partial and Phase 5 is a playable integration.
- The ROM-free iPhone Simulator arm64 app builds and renders RT64 Metal/audio.
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
- The iPhone menu exposes real settings, layout, ROM-manager, diagnostics share,
  resume, and quit-to-home actions. Its native menu contract is green.
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
- iPad Simulator, device builds, physical-device evidence, progression, and
  release packaging remain open.
- DinoMod redistribution permission is an external release blocker, not a reason
  to stop technical development.

## Immediate next goal: Goal 29a

Prove iPhone save/relaunch and complete the full ten-minute Simulator smoke as
the remaining Phase 5 gate. Use the real profile-local FlashRAM path and runtime
input flow; do not substitute sentinel-only persistence for a game-produced save.

Acceptance:

1. Clean patch replay and repository-safety audit pass.
2. macOS incremental build remains green.
3. iPhone Simulator build remains ROM-free and arm64.
4. The guarded run reaches Restored controllable gameplay through the production
   runtime and lasts at least ten minutes without crash, hang, fatal renderer/
   audio error, or unbounded diagnostics growth.
5. Produce a real game save change, record only non-sensitive size/hash/timestamp
   evidence, terminate the process cleanly, relaunch the same installed app, and
   prove the save is loaded back into controllable gameplay.
6. A distinct Prototype save sentinel/hash remains unchanged throughout, proving
   profile isolation; no ROM/save bytes or private absolute paths enter Git.
7. Exercise A/B/Z/Start, analog, C-buttons, menu open/close, background/foreground,
   settings persistence, diagnostics share/cancel, and post-modal input during
   the long run without held-input residue.
8. The app remains arm64 and ROM-free, no new CrashReporter entry appears, and
   runtime-guard ends with no DinoPad process and zero booted Simulators.
9. Existing restoration, ROM-import, home/restart, input/lifecycle, settings,
   layout, diagnostics, and macOS regressions remain green.
10. Curate evidence, update the canonical status/handoff/parity documents, and
    commit the smallest coherent Phase 5 milestone.

## Then continue in this order

1. Shut down iPhone Simulator, then complete iPad Simulator Phase 6.
2. Complete physical iPhone and iPad phases.
3. Run progression/stability matrix and start-to-credits Restored playthrough.
4. Finish legal/release/docs/package gates and ROM-free unsigned IPA.

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
- Keep reporting honestly: phases 6-10 are not green until their acceptance
  criteria and evidence are actually satisfied.

Start by inspecting `git status`, `git log -5`, the current patch lock, the
current iPhone save paths/smokes, and pinned PaperPad persistence behavior.
Then execute the smallest verified goal without asking for
clarification unless a genuinely consequential unknown cannot be discovered.

---
