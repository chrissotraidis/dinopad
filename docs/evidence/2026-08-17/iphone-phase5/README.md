# Evidence: completed iPhone Simulator Phase 5 (Goal 29a)

Goal 29a closes the remaining iPhone Simulator gate with a real profile-local
FlashRAM relaunch and a ten-minute live gameplay session.

Target: iPhone 17 Pro Simulator, iOS 26.5, arm64. Product code under test:
commit `2ba2bb2` plus the evidence-only `scripts/smoke-ios-phase5.sh` harness.

The private 128 KiB `AAAAA` save used here was created previously by the
game's own name-entry flow; it is not a synthetic save and its bytes remain
untracked. The harness starts from a clean app install, stages that image only
under `Profiles/Restored/saves/`, and writes a distinct synthetic sentinel only
under `Profiles/Prototype/saves/` for isolation proof.

Launch one selected the existing Restored slot, crossed the restored title,
reached the controllable ship-deck tutorial, delivered analog and A through the
actual N64 poll, and remained live for 600 wall-clock seconds. The save stayed
valid at 131,072 bytes with the same SHA-256 and `AAAAA` slot; the Prototype
sentinel hash did not change.

Without reinstalling or replacing the data container, launch two ran the full
seven-suite input/lifecycle harness, selected the persisted slot, and again
reached controllable Restored gameplay. Analog and A reached the runtime poll at
late frame 26,685. The Restored and Prototype hashes remained unchanged after
that second process. Both current/previous private diagnostics logs remained
within the 4 MiB cap, no fatal/crash marker or new CrashReporter entry appeared,
and runtime-guard cleanup reported zero DinoPad processes and zero booted
Simulators.

Artifacts:

- `result.txt`: duration, hashes, late input frame, persistence/isolation result,
  and cleanup contract. Hashes are non-sensitive verification metadata; no save
  bytes are present.
- `markers.txt`: curated runtime assertions from both launches, without paths or
  private log content.
- `ten-minute-gameplay-landscape.png`: live gameplay at the 600-second boundary.
- `relaunch-gameplay-landscape.png`: controllable gameplay after process
  relaunch from the persisted save.

The raw iOS 26.5 headless framebuffer is portrait-oriented for this
landscape-only app, matching pinned PaperPad. The committed screenshots are
losslessly rotated 270 degrees for review; no content is altered.

This run completes every Phase 5 acceptance item in
`docs/IMPLEMENTATION_PLAN.md`: one guarded Simulator, clean arm64 ROM-free
install, previously evidenced picker/rejection, Restored title/gameplay, all N64
input, menu and lifecycle clearing, save/relaunch, a ten-minute session, evidence,
and complete cleanup. iPad Simulator remains Phase 6.
