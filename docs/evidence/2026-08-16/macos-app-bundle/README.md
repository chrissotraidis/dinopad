# Evidence: DinoPad.app macOS bundle builds and launches (arm64)

Date: 2026-08-16
Target: macOS arm64 (Apple M2, macOS 26.5, Xcode 26.6)
Goal: Build the DinoPad macOS app bundle (scripts/build-macos-app.sh) with auto ROM staging
Result: **PASS**

DinoPad commit: 7c8925d (this evidence set follows)
Upstream pins: dino-recomp v0.3.0 = 725b2ede9cacc57968e0a028efed8df9235ba483;
dinomod v0.9.3 = d79e86be... (unchanged)

## What was built

`scripts/build-macos-app.sh` assembles `build-macos/DinoPad.app`:

- `Contents/MacOS/DinoPad` - the arm64 executable.
- `Contents/Resources/assets/` - fonts, launcher RML/RCSS, icons, images,
  scss, promptfont (layout matches the game's `get_asset_path()`).
- `Contents/Resources/recompcontrollerdb.txt` - SDL controller mappings.
- `Contents/Info.plist` - bundle id `com.chrissotraidis.dinopad`, version
  0.3.0, arm64-ready metadata.
- Ad-hoc codesigned so `open DinoPad.app` works locally.

The private ROM is staged **outside** the bundle at
`~/Library/Application Support/DinoPad/dino.z64` with MD5 verified
(49f7bb346ade39d1915c22e090ffd748). A ROM-free assertion fails the build if
any game data appears inside the .app.

## Verification

- Bundle builds cleanly (26 MB; no game data inside).
- Bundle executable launches and reaches GAME SELECT with the persisted
  AAAAA save (`b2_game_select.png`); N64 A input registered in the
  `[dinopad-in]` log (frame 896).
- All fonts load from the bundle Resources path
  (`.../DinoPad.app/Contents/Resources/assets/...`), confirming asset
  resolution through the NSBundle-aware `get_bundle_resource_directory()`.
- Clean shutdown: process gone, 0 Simulators, runtime lock released.

## Commands

```sh
./scripts/build-macos-app.sh
scripts/runtime-guard.sh macos bash .goal-loop/scratch-title-audio/session22.sh
```

## Notes

- A stale experimental bundle (`DinoPad.app.stale-2026-08-15`) existed from a
  prior cycle; the new script produces the canonical `DinoPad.app`. The stale
  directory remains in the ignored build tree for comparison.
- `open DinoPad.app` (Finder launch) is the intended user path; the guarded
  session launched `Contents/MacOS/DinoPad` directly to keep one-runtime
  discipline with the runtime guard.
- Save/relaunch, audio, and gameplay behavior of the bundle match the bare
  executable (same binary); the bundle adds NSBundle asset resolution.

## Cleanup

- DinoPad terminated; 0 booted Simulators; runtime lock released.
