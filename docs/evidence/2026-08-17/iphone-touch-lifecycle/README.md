# DinoPad iPhone Touch/Lifecycle Verification (Goal 26c)

Date: 2026-08-17
Target: iPhone Simulator arm64 (iPhone 17 Pro, iOS 26.5)
Duration: 8 seconds (bounded via scripts/runtime-guard.sh + scripts/smoke-ios.sh)

## Verified in this run

1. All 14 digital N64 masks reach the actual game poll: A=0x8000, B=0x4000, Z=0x2000, Start=0x1000, D-pad up/down/left/right=0x0800/0x0400/0x0200/0x0100, L=0x0020, R=0x0010, C-up/down/left/right=0x0008/0x0004/0x0002/0x0001. Each mask appears in both the deterministic [dinopad-touch-test] PASS lines and the runtime's own [dinopad-in] per-frame poll log.
2. Analog stick in all four cardinal directions (x=0.00 y=±1.00, x=±1.00 y=0.00) with return-to-zero after release, plus a diagonal Up-Right at x=0.71 y=0.71 in the multi-touch suite.
3. Simultaneous multi-touch: analog stick + A + B + Z produced buttons=0xE000, x=0.47, y=0.47 in a single [dinopad-in] frame; all released to zero cleanly.
4. Menu lifecycle: opening the menu cleared held input and hid gameplay controls (buttons read 0x0000 immediately); dismissing restored gameplay controls with the menu button still reachable.
5. App lifecycle: backgrounding (WillResignActive + DidEnterBackground) while holding B + stick cleared held input (0/0); foreground notifications resumed cleanly with no crash.
6. Controller handoff: CoreSimulator's synthetic controller treated as exception (touch visible); explicit controller-connected state suppressed touch input (0x0000); disconnect restored touch.
7. Bounded, single-runtime, clean: one Simulator booted, app ran 8 seconds, terminated; Simulator shut down, zero booted devices/processes, no DiagnosticReports entry.

## Evidence files

- result.txt — smoke-ios.sh PASS summary.
- runtime-excerpt.log — filtered [dinopad-touch], [dinopad-in], [dinopad-touch-test] lines.
- screen.png — final frame from the Simulator.

## Method

- In-app deterministic harness (DinoPadInputSmokeRunner in apple/app/ios_main.mm) exercises the exact dinopad_touch_snapshot bridge the game poll calls; enabled only via DINOPAD_RUN_INPUT_SMOKE env var (release-inert).
- Unit coverage of latch and analog math in tools/touch_unit_test.cpp (ctest: 21 checks, 0 failures).

## Out of scope for 26c

- ROM import UI; smoke stages ROM in container.
- iPad run; iPhone Simulator only.
- Real physical controller play; synthetic controller path only.
- Restored title/gameplay proof; requires packaging permitted restoration data (next ordered goal).
