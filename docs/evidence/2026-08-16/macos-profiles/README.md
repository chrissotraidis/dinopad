# Evidence: Restored and Prototype profile isolation on macOS

Date: 2026-08-16  
Target: macOS arm64 (Apple M2, macOS 26.5, Xcode 26.6)  
Cycle-start commit: `6575fb7`  
Result: **PASS for the command-line session-profile boundary**

## Result

- Restored is the default session profile; `--profile restored` selects it
  explicitly and `--profile prototype` selects the archival base mode. Unknown
  values fail before runtime initialization.
- User-supplied ROM and restoration package data remain under the shared data
  root. Config, mod config, and FlashRAM live under
  `Profiles/Restored/` or `Profiles/Prototype/`.
- The test used a disposable private data root with one shared validated ROM,
  one ordinary restoration package, and distinct 128 KiB sentinel saves.
- Restored registered the static module and rendered its PRESS START flow. It
  did not modify the Prototype save.
- Prototype disabled all mod scanning and static registration, rendered direct
  Game Select, and changed only its own save. The Restored save hash remained
  identical across the Prototype session.
- Both roots independently created `general.json`, `graphics.json`,
  `controls.json`, and `sound.json`.
- The disposable root was removed by a path-validated cleanup trap. The runtime
  guard confirmed zero booted Simulators and no DinoPad process.

## Command

```sh
DINOPAD_PROFILE_EVIDENCE_DIR=docs/evidence/2026-08-16/macos-profiles \
  scripts/runtime-guard.sh macos scripts/smoke-profiles-macos.sh
```

See `runtime.txt` for markers and hashes. `profile-restored.png` and
`profile-prototype.png` are window-only visual evidence.

## Remaining product UI boundary

This is a deterministic engine/session boundary, not yet the native DinoPad
home screen described by the product plan. The Apple shell must invoke the same
profile selection API, present Prototype's archival warning, and keep Restored
as the recommended default.
