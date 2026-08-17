# Evidence: static Restored data and gameplay on iPhone Simulator

Date: 2026-08-17
Target: iPhone 17 Pro Simulator, arm64, iOS 26.5
Goal: Bundle only non-executable restoration data and prove Restored title and
controllable gameplay without enabling writable mods or runtime code generation
Result: **PASS**

## What shipped in the test app

`tools/build_static_restoration_data.py` deterministically rebuilds a private,
ignored `.nrm` containing exactly `mod.json`, `mod_syms.bin`, and
`mod_binary.bin`. It maps the executable MIPS ELF `PT_LOAD` range through the
symbol table and zeroes all 316,592 bytes of that range before writing the ZIP.
The source range contained 213,988 non-zero bytes; the bundled range was
independently read back and verified all-zero. The package has no thumbnail or
native-library declaration. Its SHA-256 is recorded in `package-audit.json`.

The app bundles that data package byte-for-byte, while all 460 restoration
functions and 294 replacement/42 hook dispatch paths are ordinary ahead-of-time
arm64 code in the signed executable. N64ModernRuntime runs with runtime code
generation disabled. iOS disables writable-filesystem mod scanning before
startup and registers only the app-bundled data for Restored. Prototype does not
register it.

## Runtime proof

The final guarded run used `scripts/smoke-ios-restoration.sh` and one iPhone
Simulator. A private supported ROM and an existing private `AAAAA` FlashRAM save
were copied only into the app data container. Neither is present here or in the
app bundle.

- `restored-title.png` visibly shows the restored animated title state with
  `PRESS START`, captured at an event-driven boundary after skipping the two
  startup splashes.
- `restored-gameplay.png` visibly shows subtitle-free, controllable Krystal on
  the ship-deck cannon tutorial. The same instant has analog-up at frame 26,536
  and A at frame 26,656 in the N64 input poll; the screenshot shows the cannon
  energy response.
- `runtime-excerpt.txt` records bundled-only registration, static dispatch, the
  no-runtime-write policy, and those late input values.
- The writable data directory contained an invalid `should-not-open.nrm`
  sentinel; its name never appeared in the runtime log.
- The app remained alive, produced no new crash report, and guard cleanup left
  no DinoPad process and zero booted Simulators.

A separate final `smoke-ios-home.sh` regression restarted Restored to the native
home and then launched Prototype in the same process. The package/static markers
occurred once before the profile switch and never after `DinoPad profile:
Prototype`, proving Prototype omission. The macOS disposable profile smoke also
passed with the same sanitized package and isolated saves/config.

## Build and policy audits

- Fresh clones of all six patched repositories accepted all 25 maintained
  patches in order.
- Regeneration reproduced package SHA-256
  `2ee8befb8ee724e776f52b7654eb2202ae9f6971d716df1aafc5346e617be5e1`.
- The Simulator bundle contains only the arm64 executable, Info.plist, PkgInfo,
  controller database, and restoration data package; no ROM, dynamic library,
  or downloaded executable payload is present.
- The Mach-O `__TEXT` maximum protection is `r-x` (`0x5`). Generic system
  loader/protection symbols may exist in linked platform dependencies, so the
  enforceable audit is DinoPad source/configuration plus immutable executable
  text, not a misleading raw-symbol absence claim.
- `ctest`, macOS build, repository safety, iPhone Restored gameplay, iPhone
  Restored-to-Prototype restart, and macOS profile isolation all passed.

## Legal boundary

The generated package remains ignored/private. This proves the technical mobile
architecture only; DinoMod redistribution still requires written permission or
license clearance before any public binary release.
