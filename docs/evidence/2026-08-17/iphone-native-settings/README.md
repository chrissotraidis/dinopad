# Evidence: native iPhone settings and status (Goal 28b)

Goal 28b completes DinoPad's production native settings sheet and the non-
diagnostics portion of the section 3.4 menu contract.

The `Settings & Status` action opens a safe-area-constrained, scrollable UIKit
form with:

- truthful profile, restoration, save/recovery, controller, and effective
  Metal renderer status;
- live persisted touch enablement and opacity;
- live profile-local master volume;
- typed internal-resolution, aspect-ratio, frame-rate, and HUD-placement
  controls;
- reachable touch-layout editing/reset, ROM management, and quit-to-home
  actions; and
- explicit private support status without a placeholder diagnostics action.

`scripts/smoke-ios-settings.sh` starts from a clean app install and drives the
production settings target/action paths in two guarded process launches. The
first launch proves held input is cleared, deliberately invalid native values
are clamped, then applies touch opacity 43%, volume 37%, 2x internal resolution,
expanded aspect, display refresh, and full HUD. It verifies live runtime values
and serialized profile files before dismissal, then proves gameplay touch input
resumes. The second launch verifies all values were loaded, captures the form,
restores defaults through the same controls, verifies the second serialization,
and again proves post-modal touch input. A Prototype-profile sentinel remains
unchanged throughout.

Artifacts:

- `result.txt`: final bounded smoke result.
- `edit.log`: first-launch runtime and test markers.
- `verify.log`: relaunch verification, reset, and input-restoration markers.
- `edited-sound.json`: persisted Restored audio fixture after live editing.
- `edited-graphics.json`: persisted Restored display fixture after live editing.
- `settings-edited-landscape.png`: normalized visual capture at edited values.
- `settings-reloaded-landscape.png`: normalized relaunch capture before reset.

The raw iOS 26.5 headless framebuffer is portrait-oriented for this landscape-
only app, matching the pinned PaperPad behavior. The committed screenshots are
losslessly rotated 270 degrees only for review; no content is altered.

Final regression matrix:

- iOS Simulator arm64 ROM-free build: PASS.
- native settings two-launch smoke: PASS.
- input/lifecycle smoke: PASS.
- home/quit/restart smoke: PASS.
- Files import/ROM-manager smoke: PASS.
- touch-layout persistence/editor smoke: PASS.
- restored title/late gameplay smoke: PASS at frame 26,672.
- macOS app build and touch unit test: PASS.
- macOS Restored/Prototype profile isolation smoke: PASS.
- repository safety and 25-file patch lock: PASS, SHA-256
  `0ced288c398859a955484d17ce7cd46e9c8b1f9eea8501ec0ae7fe0dba39b1a6`.
- clean local replay of all 25 maintained patches with
  `--ignore-space-change`: PASS.
- every runtime guard cleanup: zero DinoPad processes and zero booted
  Simulators.

Diagnostics capture/redaction/share remains explicitly scoped to Goal 28c.
