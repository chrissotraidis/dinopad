# Evidence: native macOS setup/home and profile handoff

Date: 2026-08-16  
Target: macOS arm64 (Apple M2, macOS 26.5, Xcode 26.6)  
Cycle-start commit: `1a650f9`  
Result: **PASS for native home/profile handoff; document-picker import remains next**

## Result

- An empty disposable data root presented the native Set Up DinoPad screen,
  explaining legal ROM ownership, local verification, private storage, and the
  ROM-free app. Quit returned status zero without starting SDL/game runtime.
- A disposable root containing the supported private ROM presented a native
  DinoPad home. Restored Adventure is the first/primary action; Replace ROM is
  available without exposing the desktop mod manager.
- Prototype Mode presented a second native warning explaining that restoration
  is disabled, the prototype may be progression-blocked, and saves/settings
  remain separate. Confirming reached base Game Select; neither static-handle
  nor restoration-dispatch markers appeared.
- Selecting Restored Adventure reached the restored PRESS START flow and logged
  static no-write dispatch.
- The hardened runtime guard force-terminates a modal or game process only after
  its normal termination grace period. Final cleanup found no DinoPad process
  and zero booted Simulators.

## Command

```sh
DINOPAD_HOME_EVIDENCE_DIR=docs/evidence/2026-08-16/macos-native-home \
  scripts/runtime-guard.sh macos scripts/smoke-native-home-macos.sh
```

The PNG files are window-only captures. The private disposable data root and
runtime logs were removed by the smoke's validated cleanup trap.

## Next acceptance gate

This smoke proves the setup presentation and mode handoff, but deliberately
does not claim a document-picker import. The next gate must automate the real
picker with valid, byte-swapped, and invalid inputs and verify the normalized
stored fingerprint.
