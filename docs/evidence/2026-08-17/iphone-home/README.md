# DinoPad iPhone Native Home and Runtime Restart (Goal 27b)

Date: 2026-08-17
Target: iPhone 17 Pro Simulator, iOS 26.5, arm64
Duration: three bounded phases inside one `runtime-guard.sh` session

## Result

`scripts/smoke-ios-home.sh` passed all acceptance checks:

- A valid private ROM was staged only in the app data container; the app bundle
  remained ROM-free.
- DinoPad's UIKit home remained visible before any SDL video initialization.
- Restored Adventure was the primary, recommended action.
- Prototype Mode presented an explicit archival/incompleteness warning and did
  not start until confirmation.
- Restored reached the actual N64 gameplay input callback before the test used
  the reachable in-game Quit to DinoPad Home action.
- The live renderer, audio, SDL window, runtime timers/events/mod state, and all
  guest N64 host threads shut down before session memory was released.
- The same process returned to UIKit home, warned for Prototype, and started a
  second RT64/game runtime.
- Distinct Restored and Prototype profile sentinels remained byte-identical.
- No new DinoPad crash report appeared; cleanup left no DinoPad process and no
  booted Simulator.

After the home smoke, the full iPhone input/lifecycle regression, ROM-import
regression, Apple Silicon macOS build/unit test, and macOS gameplay smoke 22/22
all passed.

## Evidence

- `home.png`: native Restored-primary profile chooser before SDL.
- `prototype-warning.png`: explicit Prototype archival warning.
- `prototype-runtime.png`: second live runtime after Restored quit-to-home.
- `home-runtime.txt`: marker proving home waited without SDL startup.
- `prototype-warning-runtime.txt`: marker proving the warning waited without a
  profile/runtime launch.
- `profile-switch-runtime.txt`: gameplay input poll, quit/return markers, both
  profile namespaces, two overlay attachments, and second-runtime game output.
- `result.txt`: guarded smoke PASS summary.

The screenshots preserve the known iOS 26.5 headless Simulator raw-framebuffer
rotation also reproduced by pinned PaperPad; this is not treated as an app
orientation defect. Physical devices remain the presentation authority.
