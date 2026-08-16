# DinoPad testing and evidence

Status: Active implementation contract (updated 2026-08-16).

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

The completed macOS smoke verifies the full list below. The current
`scripts/smoke-ios.sh` is intentionally the first bounded subset: ROM
fingerprint validation, ROM-free bundle audit, install/launch, a live process
for 20 seconds, rendered-frame capture, no new crash report, and clean guarded
shutdown. It will be extended goal-by-goal until it verifies:

1. app launch;
2. ROM validation;
3. title;
4. first controllable scene;
5. analog movement;
6. A/B/Z/Start;
7. menu open/close;
8. settings persistence;
9. save/relaunch;
10. clean shutdown.

Prefer deterministic input replay; if unreliable, use a bounded human-assisted checklist and capture truthful evidence.

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
scripts/runtime-guard.sh iphone-simulator <UDID> scripts/smoke-ios.sh
```

Before every launch the guard: terminates `DinoPad`, terminates/shuts down all Simulators, verifies zero booted devices and no stale process, then acquires the atomic `.goal-loop/runtime.lock`. On exit it terminates the app, shuts down Simulators, verifies cleanup, and releases the lock.

## Release evidence

Phase 10 requires: source tag matching the packaged IPA; package file-by-file audit; SHA-256 published; clean-install through the documented self-signing workflow; save/relaunch and update-in-place verified; screenshots current; README claims consistent with `docs/STATUS.md` and `docs/PLAYTEST_MATRIX.md`.
