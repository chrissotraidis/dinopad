# DinoPad testing and evidence

Status: Active implementation contract (updated 2026-08-18).

## Principles

- Every claim maps to dated evidence under `docs/evidence/YYYY-MM-DD/<target>/<goal-slug>/`.
- "Compiled" is never "tested"; an API initializing is never "audio works"; a title rendering is never "gameplay works".
- Exactly one DinoPad runtime is active at any time (`scripts/runtime-guard.sh`).
- Private ROMs, saves, fixtures, credentials, and device identifiers never enter Git, logs, or packages.

## Test layers

### Build tests

- Host tools (N64Recomp, RSPRecomp, MIPS patch toolchain) on Apple Silicon.
- macOS arm64 app; iOS Simulator arm64 app; iOS device arm64 app.
- Package audit (Phase 10): ROM-free, save-free, signing-free, no personal paths.

### Unit tests

Target areas: ROM byte-order normalization; fingerprint validation; path sanitization; settings serialization; mode/save namespace selection; touch coordinate mapping; controller mapping; DinoMod manifest parsing; diagnostics redaction; runtime-guard behavior.

Run with:

```sh
ctest --test-dir <build-dir> --output-on-failure
```

The historical developer offline-library feasibility path writes 16-byte
arm64 trampolines. If that diagnostic path is rebuilt, verify its generated
entry-point spacing with:

```sh
tools/check_patchable_aot.py build-macos/DinoPad \
  generated/aot/RecompiledFuncs/funcs.h \
  generated/aot/RecompiledPatches/funcs.h
```

### Automated smoke

The completed macOS smoke verifies the full list below. On iPhone/iPad Simulator,
`scripts/smoke-ios-rom-import.sh` verifies the real Files picker, exact rejection
without staging, z64/v64/n64 normalization, private atomic storage, the ROM
manager, live runtime, ROM-free bundle, and cleanup. `scripts/smoke-ios.sh`
verifies all 14 digital masks, analog cardinals/zero return, multi-touch,
menu/lifecycle/controller handoff, a live render, no crash, and clean shutdown.
`scripts/smoke-ios-restoration.sh` verifies the embedded package byte-for-byte,
its exact three-member shape, writable-mod omission, static/no-write dispatch,
an event-driven restored title boundary, and late controllable gameplay input;
its screenshots require visual acceptance rather than a frame-count-only claim.
`scripts/smoke-ios-layout.sh` starts from a clean install and uses three launches:
edit/commit, relaunch/verify/reset, and real-menu capture. Its in-app assertions
cover move/size/opacity/visibility, D-pad and C-button linking, undo/cancel,
safe-area clamping, input clearing/restoration, independent phone/tablet keys,
and independent resets while the script audits arm64, ROM-free, crashes, and
guard cleanup.
`scripts/smoke-ios-settings.sh` uses two cleanly separated process launches to
exercise the production UIKit target/action paths. It verifies modal input
clearing, invalid-value clamping, live touch/audio/display application,
profile-local JSON serialization, relaunch loading, default restoration,
Prototype-profile isolation, post-dismissal touch input, safe-area screenshots,
ROM-free arm64 packaging, CrashReporter, and guard cleanup.
`scripts/smoke-ios-diagnostics.sh` starts from a clean install and verifies the
production private logger and native share action. It independently checks the
4 MiB capture, 192 KiB tail, and 512 KiB report caps; protected mode `0600`;
useful runtime/profile/ROM/save/controller/render fields; adversarial redaction
before storage and sharing; modal input clearing/restoration; share cancellation;
temporary report cleanup; ROM-free arm64 packaging; CrashReporter; and guard
cleanup.
`scripts/smoke-ios-phase5.sh` is the final endurance/save gate for each Simulator idiom. It keeps one
Restored gameplay process live for at least 600 seconds, validates a private
game-created 128 KiB save by size/hash/slot metadata only, terminates and
relaunches the same installed app back into controllable gameplay, reruns the
seven-suite input/lifecycle matrix, proves a Prototype sentinel is unchanged,
audits bounded diagnostics/arm64/ROM-free/CrashReporter state, and relies on the
guard for complete cleanup. iPhone Phase 5 and iPad Phase 6 are green.

Prefer deterministic input replay; if unreliable, use a bounded human-assisted checklist and capture truthful evidence.

Run the importer and input regressions through the guard:

```sh
scripts/runtime-guard.sh iphone-simulator <UDID> scripts/smoke-ios-rom-import.sh
scripts/runtime-guard.sh iphone-simulator <UDID> scripts/smoke-ios-home.sh
scripts/runtime-guard.sh iphone-simulator <UDID> scripts/smoke-ios-restoration.sh
scripts/runtime-guard.sh iphone-simulator <UDID> scripts/smoke-ios-layout.sh
scripts/runtime-guard.sh iphone-simulator <UDID> scripts/smoke-ios-settings.sh
scripts/runtime-guard.sh iphone-simulator <UDID> scripts/smoke-ios-diagnostics.sh
scripts/runtime-guard.sh iphone-simulator <UDID> scripts/smoke-ios-phase5.sh
scripts/runtime-guard.sh iphone-simulator <UDID> scripts/smoke-ios.sh
```

The same eight shared harnesses run through
`scripts/runtime-guard.sh ipad-simulator <IPAD_UDID> ...`. Goal 30a ran the
complete matrix on iPad Pro 11-inch (M5), including explicit tablet diagnostics,
visual acceptance, independent idiom persistence, measured PaperPad geometry,
600 live seconds, and same-install save relaunch. Evidence is in
`docs/evidence/2026-08-17/ipad-simulator-phase6/`.

`smoke-ios-home.sh` starts from a private data-container ROM, proves the native
home and Prototype warning do not initialize SDL, then runs Restored until the
actual N64 input callback polls. It requests quit-to-home, verifies the same
process returns to UIKit, confirms warned Prototype, starts a second renderer
and game runtime, checks profile sentinels, CrashReporter, and guard cleanup.

The macOS Metal teardown regression has a shorter focused smoke. It repeatedly
closes the native window through the SDL quit path and fails on a nonzero exit,
a lingering DinoPad process, or a new CrashReporter entry:

```sh
scripts/runtime-guard.sh macos \
  scripts/smoke-graceful-shutdown-macos.sh 5
```

The production static-restoration smoke requires the 460 linked functions,
immutable `r-x` `__TEXT`, no writable executable `__GAME` segment, no
DinoMod/offline Mach-O dependency, and the no-runtime-code-writes marker. It
temporarily presents the private package as an ordinary `.nrm`, disables the
developer dylib, and verifies restored title flow. A paired smoke disables the
package and verifies the same binary stays on its base-function fallback:

```sh
scripts/runtime-guard.sh macos \
  scripts/smoke-static-restoration-macos.sh
scripts/runtime-guard.sh macos \
  scripts/smoke-static-prototype-macos.sh
```

The profile smoke stages one shared private ROM/package in a disposable root,
seeds distinct Restored and Prototype FlashRAM files, runs both explicit
profiles, verifies visual behavior and runtime markers, checks independent
configuration files, and proves each other-mode save hash stays unchanged:

```sh
scripts/runtime-guard.sh macos scripts/smoke-profiles-macos.sh
```

The native-home smoke verifies the first-run setup presentation, Restored as
the primary home action, Prototype's required archival warning, and both native
handoffs into their expected runtime profiles:

```sh
scripts/runtime-guard.sh macos scripts/smoke-native-home-macos.sh
```

The native-import smoke drives the real AppKit file picker. It first selects a
fingerprint-modified 64 MiB ROM and requires visible rejection with no staged
copy, then selects a private v64 byte-swapped fixture and requires normalized
z64 magic plus the exact supported MD5:

```sh
scripts/runtime-guard.sh macos scripts/smoke-native-rom-import-macos.sh
```

### Visual tests

- App shell, safe areas, touch layout, `•••` menu, settings, error states, title/gameplay rendering sanity.
- iPhone/iPad screenshots compared with `tools/compare_ui.py` (geometry, control centers, menu bounds, clipping), feeding `docs/UI_PARITY.md`.

Screenshot capture:

```sh
xcrun simctl io booted screenshot docs/evidence/<date>/<target>/screen.png
```

macOS capture only the DinoPad window; never capture unrelated private desktop content.

### Progression tests

- Private chapter fixtures live only in `private-fixtures/`; commit a manifest (`id`, `mode`, `expected_area`, `expected_action`, `private_sha256`, `last_verified_commit`, `last_verified_target`), never the bytes.
- Known DinoMod progression repairs are exercised per mode.
- "Playable start-to-credits" requires one documented complete Restored playthrough on physical Apple hardware; the loop never claims a playthrough it did not perform.

## Evidence layout

```text
docs/evidence/2026-08-15/
├── macos/          build.txt, runtime.log, title.png, gameplay.png, README.md
├── iphone-simulator/
├── ipad-simulator/
├── ui-compare/
└── bootstrap/      Phase 0 checks
```

Each evidence README records: commit, upstream pins, target and OS, build command, launch command, result, duration, screenshot, relevant log excerpt, known limitations, and cleanup confirmation.

## Runtime guard checks

```sh
scripts/runtime-guard.sh macos scripts/smoke-macos.sh
scripts/runtime-guard.sh macos scripts/smoke-graceful-shutdown-macos.sh 5
scripts/runtime-guard.sh macos scripts/smoke-static-restoration-macos.sh
scripts/runtime-guard.sh macos scripts/smoke-static-prototype-macos.sh
scripts/runtime-guard.sh macos scripts/smoke-profiles-macos.sh
scripts/runtime-guard.sh macos scripts/smoke-native-home-macos.sh
scripts/runtime-guard.sh macos scripts/smoke-native-rom-import-macos.sh
scripts/runtime-guard.sh iphone-simulator <UDID> scripts/smoke-ios-home.sh
scripts/runtime-guard.sh iphone-simulator <UDID> scripts/smoke-ios-restoration.sh
scripts/runtime-guard.sh iphone-simulator <UDID> scripts/smoke-ios-diagnostics.sh
scripts/runtime-guard.sh iphone-simulator <UDID> scripts/smoke-ios-phase5.sh
scripts/runtime-guard.sh iphone-simulator <UDID> scripts/smoke-ios.sh
```

Before every launch the guard: terminates `DinoPad`, terminates/shuts down all Simulators, verifies zero booted devices and no stale process, then acquires the atomic `.goal-loop/runtime.lock`. On exit it terminates the app, shuts down Simulators, verifies cleanup, and releases the lock.

## Release evidence

Phase 10 requires: source tag matching the packaged IPA; package file-by-file audit; SHA-256 published; clean-install through the documented self-signing workflow; save/relaunch and update-in-place verified; screenshots current; README claims consistent with `docs/STATUS.md` and `docs/PLAYTEST_MATRIX.md`.
