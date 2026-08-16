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
- Phase 4 is partial and Phase 5 is an early playable integration.
- The ROM-free iPhone Simulator arm64 app builds and renders RT64 Metal/audio.
- The initial UIKit touch overlay draws all 15 N64 controls plus an accessible
  persistent `•••` button using PaperPad-derived phone/tablet defaults.
- The overlay is attached to SDL's UIKit window and merged into the actual
  `dino::input::get_n64_input` callback.
- A guarded live run proved A `0x8000`, Z `0x2000`, Start `0x1000`, and C-left
  `0x0002`; the menu opens, hides gameplay controls, reports controller state,
  and the app survived 90 seconds without a new crash.
- Analog motion was not proven in the runtime log before pause.
- The menu still has explicit settings/diagnostics placeholders.
- iOS still stages the private ROM through `simctl`; no user-facing Files picker
  or mode/home boundary exists yet.
- Mobile has not proven packaged restoration data or a Restored title/gameplay
  boot. The first-frame evidence is base/prototype output.
- iPad Simulator, device builds, physical-device evidence, progression, and
  release packaging remain open.
- DinoMod redistribution permission is an external release blocker, not a reason
  to stop technical development.

## Immediate next goal: Goal 26c

Finish and harden the iPhone input/lifecycle slice before adding more native UI.

Acceptance:

1. Clean patch replay and repository-safety audit pass.
2. macOS incremental build remains green.
3. iPhone Simulator build remains ROM-free and arm64.
4. Runtime evidence proves every digital N64 mask: A, B, Z, L, R, Start, all
   D-pad directions, and all C directions.
5. Runtime evidence proves analog x/y non-zero in every cardinal direction,
   clamps to configured N64 range, and returns to zero after release.
6. Simultaneous touch proves analog plus at least two buttons without loss.
7. Opening/dismissing the menu clears held input and hides/restores gameplay
   controls while leaving the menu reachable.
8. A background/foreground round trip proves no held button/axis, render/audio
   resume, process remains live, and no crash report appears.
9. Controller add/remove behavior is covered as far as Simulator permits; retain
   the documented synthetic-controller exception.
10. The iPhone run is bounded, uses exactly one runtime through
    `scripts/runtime-guard.sh`, terminates cleanly, and leaves zero booted
    Simulators/processes.
11. Curate evidence, update `STATUS`, `TECHNICAL_DEBT`, `UI_PARITY`, patch lock,
    and commit the smallest coherent milestone.

Prefer a deterministic test-only touch injection boundary or pure input harness
over fragile Simulator-window pixel coordinates, provided release behavior is
unchanged and no private API ships. Harden `scripts/smoke-ios.sh` cleanup so an
early liveness failure cannot wait indefinitely on its console child.

## Then continue in this order

1. UIKit Files ROM setup/import/replacement with `.z64/.v64/.n64`
   normalization, exact MD5 validation, useful rejection, atomic private storage,
   and ROM-free bundle proof.
2. UIKit DinoPad home: Restored primary, warned Prototype, profile/save isolation,
   and quit-to-home behavior before SDL startup.
3. Package only permitted non-code restoration data and prove Restored title and
   controllable gameplay on iPhone.
4. Complete the native menu/settings/layout editor/diagnostics/ROM manager to
   PaperPad feature parity and the plan's section 3.4 menu contract.
5. Finish iPhone save/relaunch and 10-minute smoke.
6. Shut down iPhone Simulator, then complete iPad Simulator Phase 6.
7. Complete physical iPhone and iPad phases.
8. Run progression/stability matrix and start-to-credits Restored playthrough.
9. Finish legal/release/docs/package gates and ROM-free unsigned IPA.

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

Start by inspecting `git status`, `git log -5`, the current patch lock, and the
Goal 26c source paths. Then execute the smallest verified goal without asking for
clarification unless a genuinely consequential unknown cannot be discovered.

---
