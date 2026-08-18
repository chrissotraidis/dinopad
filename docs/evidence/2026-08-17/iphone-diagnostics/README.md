# Evidence: native iPhone diagnostics and sharing (Goal 28c)

Goal 28c completes DinoPad's iPhone Simulator Support/menu contract with a
bounded private diagnostics capture, deterministic redaction, and a native
share flow.

The production logger starts before ROM setup, tees stderr to a protected
private log, rotates one previous session, and caps the current log at 4 MiB.
Every complete line is sanitized before persistence. The share report is capped
at 512 KiB with at most 192 KiB from each log tail, excludes ROM/save contents,
and reports app/system/device, profile/restoration, exact ROM validation,
save/recovery presence, controller/touch, audio/display, and effective Metal
state. Temporary reports are mode `0600`, protected, replaced atomically, and
removed after share completion or cancellation.

`scripts/smoke-ios-diagnostics.sh` starts from a clean install and drives the
production action on an iPhone 17 Pro Simulator. Its in-app assertions clear a
held gameplay input before presentation, inject adversarial app-container,
home, temporary, provider, volume, and UUID paths, verify both stored and shared
text contain redactions instead, present and cancel the real UIKit share sheet,
remove the temporary report, restore touch input, and confirm gameplay input
resumes. The outer harness independently verifies file caps, mode `0600`,
required status fields, redaction, cleanup, arm64-only packaging, ROM-free
contents, CrashReporter, and guard cleanup.

Artifacts:

- `result.txt`: final bounded smoke result.
- `sanitized-report.txt`: exact generated share report from the clean run.
- `sanitized-private-log.txt`: persisted current-session log after line-by-line
  sanitization.
- `share-sheet-landscape.png`: losslessly normalized native share-sheet capture.

Final regression matrix:

- iOS Simulator arm64 ROM-free build: PASS.
- native diagnostics/redaction/share smoke: PASS.
- input/lifecycle smoke: PASS.
- native settings two-launch smoke: PASS.
- home/quit/restart smoke: PASS.
- Files import/ROM-manager smoke: PASS.
- touch-layout persistence/editor smoke: PASS.
- restored title/late gameplay smoke: PASS at frame 26,681.
- macOS app build and touch unit test: PASS.
- macOS gameplay/input smoke: PASS 22/22 at frame 22,713.
- repository safety and 25-file patch lock: PASS, SHA-256
  `0ced288c398859a955484d17ce7cd46e9c8b1f9eea8501ec0ae7fe0dba39b1a6`.
- clean local replay of all 25 maintained patches across six fresh clones:
  PASS.
- every runtime guard cleanup: zero DinoPad processes and zero booted
  Simulators.

The raw iOS 26.5 headless framebuffer is portrait-oriented for this
landscape-only app, matching the pinned PaperPad behavior. The committed
screenshot is losslessly rotated 270 degrees only for review; no content is
altered.

Mobile save/relaunch and the full ten-minute iPhone smoke remain the Phase 5
completion gate.
