# Goal 31g: rights-safe macOS launcher assets

Date: 2026-08-18

This checkpoint remediates the selected macOS launcher resource findings from
the Goal 31f package inventory. It is a bounded engineering result, not legal
clearance or release approval.

## Package change

- Removed `DinoFont.otf`, `NotoEmoji-Regular.ttf`, `images/DPLogo.png`, and
  `images/krazoa.png` from both launcher loading/registration and the app.
- Removed development-only `assets/scss` from the app.
- Replaced the launcher bitmap logo with text and selected the already-pinned
  Lato family for desktop UI fallback.
- Added exact Lato copyright/authorship/reserved-name attribution and the SIL
  Open Font License 1.1 text under `Contents/Resources/Notices`.
- Added replayable dino-recomp patch 0011 and advanced the locked patch set to
  26 files, SHA-256
  `2b66b9147f8b2cae2e96728a3841ef6e0a84e0c74c1a7ef83fe0d749c27233be`.

The legacy RML launcher is dormant in the normal macOS product flow: an
implicit profile enters the native AppKit home and an explicit profile skips
the legacy launcher. The cleanup still removes unnecessary package content and
keeps dormant code from naming those resources.

## Verification

- `scripts/bootstrap.sh`: PASS; all 26 patches recognized and repository safety
  green.
- macOS rebuild and `scripts/build-macos-app.sh`: PASS; final app approximately
  29 MB.
- `scripts/check-macos-package-safety.sh`: PASS; arm64/macOS 11+, system-only
  runtime dependencies, no symlink/private/game/save/log material, removed
  resources and references absent, exact Lato/OFL notices, valid ad-hoc
  signature.
- Negative control adding `assets/DinoFont.otf`: correctly rejected.
- Negative control truncating `Notices/Lato-NOTICE.txt`: correctly rejected.
- `python3 tools/validate_package_rights_inventory.py`: PASS with 17 direct
  linked components, 8 selected resources, 2 unresolved states, and 5 release
  blockers.
- `python3 tools/validate_package_rights_inventory.py --require-release-ready`:
  correctly returned 2 with no override.
- Guarded macOS gameplay smoke: PASS 22/22; cleanup reported zero DinoPad
  processes, zero booted Simulators, and released lock.
- `scripts/build-ios-device.sh`: PASS after shared-source recompilation; unsigned
  arm64 iOS device app remained ROM-free, test-harness-free, and package-audit
  green.

## Remaining red gates

The inventory still marks private ROM-derived AOT rights unresolved and
DinoMod restricted. Its release blockers remain the DinoPad-owned root-license
decision, GPL corresponding-source assembly, DinoMod permission, ROM-derived
binary rights, and complete transitive notice coverage. Physical iPhone/iPad,
start-to-credits progression, final privacy review, signing, and release
artifact gates are also unchanged.
