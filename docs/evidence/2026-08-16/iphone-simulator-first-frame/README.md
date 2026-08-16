# iPhone Simulator first rendered frame

Date: 2026-08-16

Base commit: `532020d` plus the iOS bring-up changes in this evidence commit

Target: arm64 iPhone Simulator, iOS 26.5

Host: Apple Silicon, macOS 26.5, Xcode 26.6 (17F113)

## Commands

```sh
scripts/build-ios-simulator.sh
DINOPAD_IOS_EVIDENCE_DIR=<scratch-evidence> \
  scripts/runtime-guard.sh iphone-simulator <UDID> scripts/smoke-ios.sh
```

## Result

PASS. The Xcode generator produced a ROM-free arm64 `DinoPad.app`; the smoke
installed it into exactly one iPhone Simulator, normalized and staged the
private supported ROM only in the app data container, kept DinoPad alive for
20 seconds, captured the Rareware opening frame, found no new crash report,
terminated the app, and left zero booted Simulators and no DinoPad process.
The permitted SDL controller mapping database is present in the bundle and
loads without the earlier mapping error.

The executable SHA-256 for the first successful frame build was
`efbc4d5200bacffab5783daadf4dec675e736611c33638032fe17d3880d5eebb`;
the maintained build script rechecks architecture and the ROM-free boundary.

## Evidence

- `first-frame.png`: real RT64 Metal output from the supported prototype.
- `runtime.log`: app console excerpt; Restored profile selection, renderer
  bring-up, and non-fatal upstream/Simulator notes.
- `result.txt`: automated smoke result.

## Known limitations

- The frame is rotated inside a portrait Simulator capture; landscape
  presentation is not accepted yet.
- This is the base prototype opening because permitted restoration package
  data has not yet been added to the mobile bundle.
- Native Files import, unsupported-ROM rejection, touch controls, `•••` menu,
  background/foreground input release, save/relaunch, and the 10-minute smoke
  are not covered by this checkpoint.
- The console's `Failed to preload executable!` line is emitted by the
  Simulator console attachment; the app proceeds to render and remains live.
