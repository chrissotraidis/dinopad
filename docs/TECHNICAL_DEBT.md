# DinoPad Technical Debt Register

Last updated: 2026-08-16

Severity is relative to Preview 1. `P0` blocks correctness/release, `P1` blocks a
platform phase, and `P2` is maintainability or test debt that should not be lost.

## P0: release and product blockers

| Debt | Current state | Required closure |
|---|---|---|
| DinoMod permission/license | The pinned restoration source declares no conventional redistribution license and its policy is restrictive. Technical static integration exists, but public redistribution is not authorized. | Obtain explicit maintainer permission and record the granted scope before shipping restoration code/data. |
| Physical-device evidence | No physical iPhone/iPad device run exists. | Build/sign/install and complete the Phase 7/8 device matrix. |
| Restored progression certification | No start-to-credits Restored device playthrough exists. | Complete and document at least one physical-device playthrough; fix blockers. |
| iOS ROM ownership flow | Simulator smoke currently stages a private ROM with `simctl`; users cannot yet import through Files. | Port PaperPad-style UIKit document picker, normalization, exact fingerprint validation, atomic storage, replacement, and error recovery. |
| Mobile restoration package | The iPhone first frame is base/prototype output; mobile has not proven packaged permitted restoration data and Restored boot. | Package only cleared non-code data and verify static Restored dispatch on iPhone/iPad. |

## P1: iPhone/iPad phase blockers

| Debt | Evidence/impact | Required closure |
|---|---|---|
| ~~Touch analog not yet logged~~ | **Closed 2026-08-17 (Goal 26c).** The deterministic DINOPAD_RUN_INPUT_SMOKE harness produced non-zero x/y for all 4 cardinal directions plus return-to-zero, visible in the runtime's own [dinopad-in] poll log. | Analog runtime evidence exists; long-duration analog-flick retention across 30/60 Hz modes remains a Phase 6/7 check. |
| Incomplete menu | The persistent menu opens and hides controls, but two entries are placeholders. | Implement the complete menu tree in `IMPLEMENTATION_PLAN.md` section 3.4. |
| No layout editor | Default phone/tablet coordinates exist, but users cannot move/resize/fade/link/hide/reset controls. | Port PaperPad editor behavior and independent persisted idiom keys. |
| Partial settings | Touch enable/opacity storage exists internally; no complete UI/bridges for display, audio, frame rate, HUD, mode, or restoration settings. | Add typed settings bridge and persisted native sheets. |
| ~~Lifecycle proof absent~~ | **Closed 2026-08-17 (Goal 26c).** A guarded smoke-ios.sh run delivers background/foreground notifications while holding a button+stick, verifies the snapshot clears to zero and resumes cleanly with no crash, and leaves no booted Simulator. | Explicit in-engine pause policy during modal sheets still needs validation once the full menu tree lands. |
| Controller handoff only event-driven | Add/remove events hide touch; the CoreSimulator synthetic controller exception is verified (touch stays available). Real MFi hardware, reconnect loops, rumble, and initial-state behavior remain unverified. | Test a real MFi/SDL controller on a physical device with repeated connect/disconnect (Phase 7/8). |
| No mobile home/profile UI | iOS launches Restored directly with `--skip-launcher`; Prototype warning/selection is absent. | Add UIKit setup/home boundary before SDL runtime startup and quit-to-home behavior. |
| No diagnostics/ROM manager | Native share/log and replacement workflows are absent. | Port bounded private logging, redaction, share sheet, and ROM manager. |
| iPad untested | Tablet defaults exist in code but have never run. | Complete Phase 6 only after iPhone is green and shut down. |

## P1: orientation and presentation

The iOS 26.5 headless Simulator exposes a fixed 1206x2622 raw framebuffer and
does not offer a command-line orientation operation. Both DinoPad and the pinned
PaperPad Simulator app render landscape UIKit content into that portrait raw
capture. The Simulator GUI toolbar can rotate the virtual hardware, but Metal
frames are black to the Computer Use screenshot capture during some transitions.

This is not evidence that physical-device orientation is correct. Do not add
more temporary UIKit windows or private orientation APIs. Keep the landscape
plist + SDL hint, validate with the Simulator GUI where possible, and make a
physical iPhone/iPad the final authority.

## P2: code structure and testing

| Debt | Impact | Preferred direction |
|---|---|---|
| `ios_main.mm` is becoming monolithic | Touch rendering, input state, menu, lifecycle, and startup now share one file. | Split into `touch/`, `ui/`, `rom_setup`, `diagnostics`, and a small startup coordinator as behavior lands. |
| Drawn controls lack individual accessibility elements | The menu button is accessible; canvas-drawn controls are not exposed as named adjustable/buttons. | Add `UIAccessibilityElement` frames/labels/traits while preserving multi-touch rendering. |
| Touch smoke uses manual Computer Use coordinates | Fragile across Simulator chrome/scale and not CI-suitable. | Add a deterministic test-only injection boundary or a pure touch-state unit harness; keep release behavior unchanged. |
| ~~`smoke-ios.sh` error cleanup can wait on console~~ | **Closed 2026-08-17 (Goal 26c).** A persistent EXIT/INT/TERM cleanup() trap now terminates the app and kills TERM then KILL the simctl console child even on early failure. | Unit-covered by the 8-second green run plus the bounded failure path. |
| Upstream mixed line endings | Dino source mixes CRLF/LF, causing content-correct patches to fail exact whitespace matching. | Patch replay/safety now use `git apply --ignore-space-change`; preserve semantic hunk checks and consider normalizing only during a future upstream rebase. |
| Touch tap duration is poll-count based | Six polls work for current runtime cadence but are not time-based. | Keep evidence across 30/60 Hz modes; convert only if missed or overlong taps appear. |
| Touch/controller merge has no isolated unit test | Runtime evidence exists for several masks but regression localization is weak. | Add a small arm64 host/Simulator harness covering masks, axis clamp/range, multi-touch, menu clearing, and controller hiding. |
| CoreSimulator synthetic controller special case | Simulator always forces controller-disconnected so touch stays visible. | Keep the explicit exception documented and test real controller handoff on device. |
| Mobile display/Metal layer metrics rely on upstream adapters | First frame is green but repeated resize/orientation/memory-pressure behavior is unproven. | Add resize/orientation/device stress tests and compare drawable size to safe-area/window metrics. |
| macOS physical controller remains externally blocked | Paired controllers were not connected; only the exact SDL mapping path is verified via a virtual controller. | Re-test when hardware is connected, then record physical evidence. |

## Known upstream/runtime noise

- RT64 Metal reports that RenderPool is not implemented and creates resources
  directly; currently non-fatal.
- The iOS Simulator may print duplicate accessibility-bundle class warnings.
- The game can print RSP/RDP stall diagnostics during early frames; the bounded
  first-frame runs remain live, but longer stability work must classify any
  stalls that stop progression.
