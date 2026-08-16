# Evidence: controllable gameplay verified on macOS arm64

Date: 2026-08-16
Target: macOS arm64 (Apple M2, macOS 26.5, Xcode 26.6)
Goal: Verify keyboard/controller input and reach controllable gameplay on macOS
Result: **PASS**

DinoPad commit (cycle end): b1d350f (plus this evidence set)
Upstream pins: dino-recomp v0.3.0 = 725b2ede9cacc57968e0a028efed8df9235ba483;
dinomod v0.9.3 = d79e86be... (unchanged)

## What was verified

1. **Playable scene reached.** The game boots through N64 logo -> Rareware
   splash -> GAME SELECT -> (existing save AAAAA) -> opening cinematic and
   reaches the playable tutorial scene "Krystal! Try shooting the cannon!"
   with Krystal controllable on the ship deck
   (`gameplay_state.png`, `pre_input.png`).
2. **Input delivered to the recompiled game during gameplay.** The
   DINOPAD_LOG_INPUT patch records the exact N64 input state the game reads
   each frame. During the playable scene, analog X/Y (±0.66), N64 A
   (0x8000), and N64 Z (0x2000) presses all appear in the runtime log
   (see `analysis.txt`; full logs in
   `.goal-loop/scratch-title-audio/runtime-session17.log` and
   `runtime-session19.log`).
3. **The game responds to input.**
   - Held W displaces the on-screen character; held S displaces it back;
     a no-input drift control returns near the origin (NCC template
     tracking, `analysis.txt` section 2).
   - A-presses fire the tutorial cannon: orange energy pixels jump from
     1,132 to 112,846 (~100x) between `a0_before.png` and `a1_action.png`;
     the same effect appears with Z-aim + A.
   - Movement and action captures (`move_forward/back/left/right.png`,
     `action_a.png`, `action_aim.png`) show distinct gameplay states.

## Commands

```sh
cmake --build build-macos --parallel 4 --target DinoPad   # no-op (current)
scripts/runtime-guard.sh macos bash .goal-loop/scratch-title-audio/session17.sh
scripts/runtime-guard.sh macos bash .goal-loop/scratch-title-audio/session18.sh
scripts/runtime-guard.sh macos bash .goal-loop/scratch-title-audio/session19.sh
```

Launch: `build-macos/DinoPad --skip-launcher --window-width 1024 --window-height 768`
with `DINOPAD_LOG_INPUT=1`.

## Automation note (session 16 finding)

`osascript` System Events keystrokes are delivered to the **frontmost**
application, not specifically to the DinoPad window. Session 16 failed to
advance the game (game sat at GAME SELECT; input log empty) because the
frontmost app was the agent host. The fix, now used by all sessions, is
`.goal-loop/scratch-title-audio/sendkey.sh`, which first sets the DinoPad
process frontmost, then sends the held key. Documented in
`docs/KNOWN_ISSUES.md`.

## Session history

- Session 15: reached the playable scene (`gameplay_state.png`), input taps
  during gameplay.
- Session 16: input lost to frontmost-app bug; game sat at GAME SELECT.
  Finding documented; captures discarded (stored in
  `.goal-loop/discarded-gameplay-captures/`).
- Session 17: fixed input delivery; verified analog + A + Z during gameplay.
- Session 18: controlled A/B with no-input baseline and per-direction
  captures; cannon fire response quantified.
- Session 19: displacement experiment (W/S/back/idle) with NCC tracking.

## Not verified (next goals)

- Save persistence across relaunch (Flashram `dino.bin` exists; reload
  behavior is next).
- Acoustic speaker/headphone playback (audio verified at pipeline/device
  level in `macos-title-audio/`).
- Controller input on macOS (keyboard verified; SDL gamepad path untested).
- RmlUi launcher on Metal (still bypassed with `--skip-launcher`).

## Cleanup

- DinoPad process terminated after each session; 0 booted Simulators;
  runtime lock released (runtime-guard cleanup lines in each session output).
