# DinoPad iPhone ROM Import and Replacement (Goal 27a)

Date: 2026-08-17
Target: iPhone 17 Pro Simulator, iOS 26.5, arm64
Duration: three bounded launches inside one `runtime-guard.sh` session

## Result

`scripts/smoke-ios-rom-import.sh` passed all acceptance checks:

- The app bundle contained no `.z64`, `.v64`, `.n64`, or `.rom` file.
- A clean app container presented DinoPad's first-run setup and the real
  `UIDocumentPickerViewController` Files browser.
- A wrong-size file was rejected with the 64 MiB error and no private target.
- A fingerprint-modified 64 MiB z64 was rejected and left no private target.
- Valid z64, v64, and n64 fixtures all passed through the production UIKit
  importer and were normalized to z64 magic `80371240`.
- The stored private copy had exact MD5
  `49f7bb346ade39d1915c22e090ffd748`, used atomic writing, file protection,
  and `NSURLIsExcludedFromBackupKey`.
- The running game's reachable Game ROM manager visibly offered Replace ROM
  and Remove ROM actions while gameplay controls were hidden.
- The imported ROM booted into the live runtime; no crash report appeared.
- Cleanup left zero DinoPad processes and zero booted Simulators.

The full Goal 26c input/lifecycle smoke was rerun after this change and passed
all 14 digital masks, four analog directions, multi-touch, menu, lifecycle,
and controller-handoff checks.

## Evidence

- `files-picker.png`: actual iOS Files picker on a clean first launch.
- `imported-runtime.png`: live runtime after valid n64-to-z64 import.
- `rom-manager.png`: reachable Replace/Remove ROM manager.
- `picker-runtime.txt`, `import-runtime.txt`, `manager-runtime.txt`: bounded
  marker logs, checked to contain no private absolute paths.
- `result.txt`: script PASS summary.

The screenshots preserve the known iOS 26.5 headless Simulator raw-framebuffer
rotation also reproduced by pinned PaperPad; this is not treated as an app
orientation defect. Physical devices remain the presentation authority.
