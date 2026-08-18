# iPad Simulator Phase 6

Date: 2026-08-17 (America/Chicago)

Target: iPad Pro 11-inch (M5), iPadOS 26.5, arm64 Simulator

Reference: PaperPad `644945d4bc4facbbd8ecda8cdfd37ae64e7993fa`

Phase 6 is green. Every launch used `scripts/runtime-guard.sh ipad-simulator`
with exactly one Simulator; every run ended with no DinoPad process and zero
booted Simulators. The installed app was arm64-only and ROM-free. The supported
private ROM, game-created save, and Prototype sentinel stayed only inside the
disposable Simulator data container and are not evidence artifacts.

## Acceptance matrix

| Gate | Result | Evidence |
|---|---|---|
| Complete N64 input and lifecycle | PASS: 14 digital masks, four analog directions, multi-touch, menu/background clearing, foreground resume, Simulator controller handoff | `input-result.txt`, `input-lifecycle.png` |
| Tablet defaults and layout editor | PASS: safe-area move/resize/fade/hide, D/C linking, undo, cancel, reset, two-launch iPad persistence, phone-key isolation | `layout-result.txt`, `layout-editor.png`, `menu.png` |
| Native settings/status | PASS: live touch/audio/display application, clamping, profile isolation, defaults, modal suppression/restoration, process relaunch | `settings-result.txt`, `settings.png` |
| Diagnostics/share | PASS: explicit `Device: iPad (tablet)`, protected bounded logs, redaction, useful status, native share/cancel, cleanup | `diagnostics-result.txt`, `diagnostics-report.txt`, `diagnostics-share.png` |
| Setup/home/profile boundary | PASS: UIKit before SDL, Restored primary, warned Prototype, isolated profiles, live quit-to-home, second runtime | `home-result.txt`, `home.png`, `prototype-warning.png` |
| ROM import/manager | PASS: real Files picker, useful size/fingerprint rejection without staging, z64/v64/n64 normalization, exact MD5, private atomic storage, replace/remove | `rom-import-result.txt`, `rom-setup-picker.png`, `rom-manager.png` |
| Embedded restoration | PASS: audited non-executable package, static no-write dispatch, writable mods ignored, restored title and controllable gameplay at frame 26,670 | `restoration-result.txt`, `restored-title.png`, `restored-gameplay.png` |
| Endurance/save relaunch | PASS: 600 live seconds; identical Restored SHA-256 at seed/ten-minute/relaunch; unchanged Prototype sentinel; same-install relaunch to gameplay at frame 26,669 | `endurance-result.txt`, `ten-minute-gameplay.png`, `relaunch-gameplay.png` |

`geometry.txt` records the measured PaperPad comparison. The persistent menu is
an exact rect match and the largest control-center delta is at most 0.64 point,
well inside the 8-point menu and 12-point control tolerances.

The iOS 26.5 headless `simctl` captures retain the Simulator's portrait pixel
frame while the app exposes a correct 1210x834-point landscape UIKit/SDL
viewport. The pinned PaperPad target has the same capture behavior. Visual QA
therefore evaluates the landscape app viewport, not the outer raw PNG axes.

## Final regression cycle

- macOS arm64 incremental build: PASS.
- iOS Simulator Release build: PASS; resulting app arm64-only and ROM-free.
- `ctest --test-dir build-macos --output-on-failure`: PASS (1/1).
- guarded macOS smoke: PASS (22/22, late gameplay frame 22,741, clean exit).
- guarded iPhone layout regression after idiom generalization: PASS.
- guarded iPhone diagnostics regression with explicit phone identity: PASS.
- `scripts/check-repo-safety.sh`: PASS; patch lock is 25 files at
  `0ced288c398859a955484d17ce7cd46e9c8b1f9eea8501ec0ae7fe0dba39b1a6`.
- disposable clean-clone patch replay: PASS (25/25 forward-applied).
