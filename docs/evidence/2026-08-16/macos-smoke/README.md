# Evidence: automated input-replay smoke test PASS (macOS arm64)

Date: 2026-08-16
Target: macOS arm64 (Apple M2, macOS 26.5, Xcode 26.6)
Goal: Run a bounded automated input-replay smoke of the boot-to-gameplay flow
Result: **PASS** (22/22 checks, 0 fail, 0 skip)

DinoPad commit: def59ac (this evidence set follows)
Upstream pins: dino-recomp v0.3.0 = 725b2ede9cacc57968e0a028efed8df9235ba483;
dinomod v0.9.3 = d79e86be... (unchanged)

## Command

```sh
scripts/runtime-guard.sh macos scripts/smoke-macos.sh
```

The smoke script is the new `scripts/smoke-macos.sh`. It runs under the
one-runtime-at-a-time guard, replays deterministic keyboard input (A/B/Z/
Start/WASD), and verifies each check from the `[dinopad-in]` runtime log plus
window captures. Full output: `result.txt`; runtime log: `runtime.log`.

## Verified checks

- Preflight: supported ROM present with expected MD5
  (49f7bb346ade39d1915c22e090ffd748).
- Launch: app stays alive through boot; window present (GAME SELECT captured).
- Input delivery: A (0x8000), B (0x4000), Z (0x2000), Start (0x1000) all
  reach the recompiled game; analog displacement (WASD, x/y ±0.66) delivered.
- Gameplay: input continues past frame 23669, i.e. well beyond the opening
  sequence into the playable tutorial scene.
- Screenshots: game select, before-input, move forward/back/right/left,
  action A/Z/B, Start press (see files in this directory).
- Save integrity: `dino.bin` SHA-256 unchanged after the run
  (a62085a8...5516) - the smoke session does not corrupt or lose the save.
- Clean shutdown: DinoPad process gone; 0 booted Simulators; runtime lock
  released by the guard.

## Notes

- The first smoke run FAILED on a real gap: B was never exercised by the
  replay. A B press (Left Shift) was added to the script and the rerun passed
  22/22. This is exactly what the smoke harness is for.
- Deterministic input relies on activating the DinoPad window before each key
  (osascript keystrokes go to the frontmost app; see docs/KNOWN_ISSUES.md).
- Opening-sequence wait is bounded (~5 min); total session ~8 min.

## Cleanup

- DinoPad terminated; 0 booted Simulators; runtime lock released (guard
  cleanup lines above).
