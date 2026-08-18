# DinoPad Technical Debt Register

Last updated: 2026-08-18

Severity is relative to Preview 1. `P0` blocks correctness/release, `P1` blocks a
platform phase, and `P2` is maintainability or test debt that should not be lost.

## P0: release and product blockers

| Debt | Current state | Required closure |
|---|---|---|
| Root license and third-party notices | The repository has no root license grant or complete assembled notice set. Dino Recompiled records GPLv3, while every recursive dependency retains its own terms. | Decide the license for DinoPad-owned work, satisfy GPL source/notice obligations, assemble the exact shipped dependency notices, and audit them against the final package. |
| DinoMod permission/license | The pinned restoration source declares no conventional redistribution license and its policy is restrictive. Technical static integration exists, but public redistribution is not authorized. | Obtain explicit maintainer permission and record the granted scope before shipping restoration code/data. |
| Physical-device evidence | No physical iPhone/iPad device run exists. The unsigned arm64 `iphoneos` build is green, but CoreDevice reports zero devices and the keychain reports zero valid signing identities as of 2026-08-17. | Connect a supported device, add a valid personal Apple Development identity/provision, then build/sign/install and complete the Phase 7/8 device matrix. |
| Restored progression certification | No start-to-credits Restored device playthrough exists. | Complete and document at least one physical-device playthrough; fix blockers. |
| ~~iOS ROM ownership flow~~ | **Closed 2026-08-17 (Goal 27a).** A clean install presents the real UIKit Files picker; production code rejects wrong-size/modified ROMs without staging, normalizes z64/v64/n64, verifies the exact MD5, stores atomically/protected/excluded from backup, and provides Replace/Remove actions. | Physical-device Files-provider coverage remains part of Phase 7/8, but the Simulator product gate is green. |
| ~~Mobile restoration package~~ | **Closed for iPhone/iPad Simulator 2026-08-17 (Goals 27c/30a).** A deterministic builder strips the complete MIPS executable segment from the embedded package, iOS permits only that app-bundled data, and guarded phone/tablet runs visibly proved restored title plus controllable gameplay with static no-write dispatch. | Repeat the same policy/runtime proof on physical devices. Public redistribution remains blocked separately by the DinoMod permission row above. |

## P1: iPhone/iPad phase blockers

| Debt | Evidence/impact | Required closure |
|---|---|---|
| ~~Touch analog not yet logged~~ | **Closed 2026-08-17 (Goal 26c).** The deterministic DINOPAD_RUN_INPUT_SMOKE harness produced non-zero x/y for all 4 cardinal directions plus return-to-zero, visible in the runtime's own [dinopad-in] poll log. | Analog runtime evidence exists on both Simulator idioms; retain 30 Hz and physical-device coverage in Phase 7/8. |
| ~~Partial Support menu~~ | **Closed for iPhone/iPad Simulator 2026-08-17 (Goals 28c/30a).** The persistent menu and Settings Support section reach a bounded, redacted diagnostics report through the native UIKit share sheet; held input clears and touch restores after cancellation on both idioms. | Repeat presentation, redaction, and cleanup acceptance on physical devices. |
| ~~No layout editor~~ | **Closed for iPhone/iPad Simulator 2026-08-17 (Goals 28a/30a).** The native editor supports safe-area move, size, per-control opacity, visibility, D-pad/C linking, reset, one-step undo, Done, and full-session Cancel. Independent versioned phone/tablet dictionaries survived guarded process relaunches and reset in isolation; tablet presentation is visually accepted. | Repeat visual/usability acceptance on physical devices; add individual accessibility elements separately. |
| ~~Partial settings~~ | **Closed for iPhone/iPad Simulator 2026-08-17 (Goals 28b/30a).** A safe-area UIKit sheet exposes touch, master volume, resolution, aspect, frame rate, and HUD through typed live bridges, while mode/restoration/save/controller/effective-render state is truthful and read-only. Guarded two-launch smokes prove defensive clamping, serialization, relaunch, profile isolation, and modal input restoration on both idioms. | Repeat presentation and persistence acceptance on physical devices. |
| ~~Lifecycle proof absent~~ | **Closed 2026-08-17 (Goal 26c).** A guarded smoke-ios.sh run delivers background/foreground notifications while holding a button+stick, verifies the snapshot clears to zero and resumes cleanly with no crash, and leaves no booted Simulator. | Explicit in-engine pause policy during modal sheets still needs validation once the full menu tree lands. |
| Controller handoff only event-driven | Add/remove events hide touch; the CoreSimulator synthetic controller exception is verified (touch stays available). Real MFi hardware, reconnect loops, rumble, and initial-state behavior remain unverified. | Test a real MFi/SDL controller on a physical device with repeated connect/disconnect (Phase 7/8). |
| ~~No mobile home/profile UI~~ | **Closed 2026-08-17 (Goal 27b).** UIKit presents Restored as the primary action before SDL, requires an archival warning for Prototype, passes isolated profile roots, and supports live quit-to-home plus a second runtime in the same process. | Device presentation remains part of Phase 7/8; the Simulator product gate is green. |
| ~~No diagnostics~~ | **Closed for iPhone/iPad Simulator 2026-08-17 (Goals 28c/30a).** Protected current/previous logs are bounded, every complete line is sanitized before persistence, shared tails/reports have independent caps, useful status excludes ROM/save contents, and adversarial smokes prove native share/cancel and cleanup. The tablet report explicitly identifies `iPad (tablet)`. | Repeat on physical devices; retain the existing bounds and redaction corpus as fields evolve. |
| ~~iPad untested~~ | **Closed 2026-08-17 (Goal 30a).** The complete guarded Phase 6 setup/home/layout/menu/settings/diagnostics/ROM/restoration/input/endurance/save matrix passed on iPad Pro 11-inch (M5), including independent idiom persistence and measured PaperPad parity. | Physical iPad validation remains Phase 8. |

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
| `ios_main.mm` is becoming monolithic | Home, ROM setup, and settings are split out, but touch rendering, input state, menu, lifecycle, and startup coordination still share one file. | Continue splitting into `touch/`, `ui/`, `diagnostics`, and a small startup coordinator as behavior lands. |
| ~~iOS runtime assumed process-exit teardown~~ | **Closed 2026-08-17 (Goal 27b).** Quit-to-home originally exposed a Plume queued-block use-after-free and parked N64 guest threads accessing released RDRAM. Window metrics are now synchronously cached on iOS; timer/event/mod/overlay state resets; guest contexts are registered, signaled, joined, and deleted before RDRAM release. | Keep the two-runtime home smoke and macOS smoke as regressions; add repeated-switch soak later in Phase 9. |
| Drawn controls lack individual accessibility elements | The menu button is accessible; canvas-drawn controls are not exposed as named adjustable/buttons. | Add `UIAccessibilityElement` frames/labels/traits while preserving multi-touch rendering. |
| ~~Touch smoke uses manual Computer Use coordinates~~ | **Closed 2026-08-17 (Goal 26c).** `DinoPadInputSmokeRunner` drives the production snapshot bridge without Simulator-window coordinates. | Keep the environment gate release-inert and rerun after touch changes. |
| ~~`smoke-ios.sh` error cleanup can wait on console~~ | **Closed 2026-08-17 (Goal 26c).** A persistent EXIT/INT/TERM cleanup() trap now terminates the app and kills TERM then KILL the simctl console child even on early failure. | Unit-covered by the 8-second green run plus the bounded failure path. |
| Upstream mixed line endings | Dino source mixes CRLF/LF, causing content-correct patches to fail exact whitespace matching. | Patch replay/safety now use `git apply --ignore-space-change`; preserve semantic hunk checks and consider normalizing only during a future upstream rebase. |
| Touch tap duration is poll-count based | Six polls work for current runtime cadence but are not time-based. | Keep evidence across 30/60 Hz modes; convert only if missed or overlong taps appear. |
| ~~Touch/controller merge has no isolated unit test~~ | **Closed 2026-08-17 (Goal 26c).** `tools/touch_unit_test.cpp` covers masks, latch decay, deadzone, cardinal/diagonal math, and clamp; the Simulator harness covers merge/menu/controller behavior. | Extend only when settings make range/deadzone configurable. |
| ~~Simulator automation compiled into device builds~~ | **Closed 2026-08-17 (Goal 31b).** Environment-driven runners, simulated-touch selectors, and adversarial fixtures compile only when the Simulator build explicitly enables `DINOPAD_ENABLE_TEST_HARNESS`; physical/release builds force it off and a package gate scans the binary. | Keep the Simulator positive regression and physical-binary negative assertions in `scripts/check-package-safety.sh`. |
| CoreSimulator synthetic controller special case | Simulator always forces controller-disconnected so touch stays visible. | Keep the explicit exception documented and test real controller handoff on device. |
| Mobile display/Metal layer metrics rely on upstream adapters | First frame is green but repeated resize/orientation/memory-pressure behavior is unproven. | Add resize/orientation/device stress tests and compare drawable size to safe-area/window metrics. |
| macOS physical controller remains externally blocked | Paired controllers were not connected; only the exact SDL mapping path is verified via a virtual controller. | Re-test when hardware is connected, then record physical evidence. |

## Known upstream/runtime noise

- RT64 Metal reports that RenderPool is not implemented and creates resources
  directly; currently non-fatal.
- The iOS Simulator may print duplicate accessibility-bundle class warnings.
- SDL's UIKit view controller may report unbalanced appearance transitions when
  the native home hands off to the SDL window. Both runtime launches render and
  tear down cleanly; classify this during the full menu/orientation lifecycle
  pass rather than treating console text alone as a crash.
- The game can print RSP/RDP stall diagnostics during early frames; the bounded
  first-frame runs remain live, but longer stability work must classify any
  stalls that stop progression.
