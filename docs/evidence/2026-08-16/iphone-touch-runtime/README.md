# iPhone Touch Runtime Pause-Point Evidence

Date: 2026-08-16
Target: arm64 iPhone 17 Pro Simulator, iOS 26.5

## Method

The ROM-free Simulator app was installed through the guarded iPhone smoke. The
supported private ROM was normalized only into the app data container. The app
was launched with `DINOPAD_LOG_INPUT=1` and kept alive for 90 seconds.

Computer Use inspected the live Simulator UI, confirmed the accessible
`DinoPad Menu` element and all rendered touch targets, then tapped A, Z, Start,
and C-left and opened the menu. The menu visibly removed gameplay targets and
reported `Controller: Not Connected` while the game continued rendering behind
the native action sheet.

## Result

- Overlay attachment logged as phone idiom.
- A reached the N64 poll as `0x8000`.
- Z reached the N64 poll as `0x2000`.
- Start reached the N64 poll as `0x1000`.
- C-left reached the N64 poll as `0x0002`.
- Overlapping tap latches produced expected combined masks before returning to
  `0x0000`.
- Process remained live for the full 90 seconds.
- A final frame was captured by the private ignored run directory.
- No new DinoPad crash report appeared.
- Runtime guard terminated the app, shut down the Simulator, and verified zero
  remaining DinoPad processes/booted Simulators.

## Honest limitations

- Analog drag did not produce a logged axis transition and remains open.
- B/L/R, remaining D-pad/C directions, simultaneous multi-touch, controller
  handoff, and lifecycle round trip were not fully exercised.
- The menu is a functional scaffold; settings/layout and diagnostics/game-data
  actions remain placeholders.
- The raw headless Simulator screenshot is portrait/rotated, matching the pinned
  PaperPad control app. Physical devices remain the orientation authority.

See `input-excerpt.txt`, `result.txt`, `docs/TECHNICAL_DEBT.md`, and
`docs/UI_PARITY.md`.

