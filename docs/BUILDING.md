# Building DinoPad

Status: macOS arm64, iPhone/iPad Simulator arm64, and unsigned physical iOS
arm64 builds active (updated 2026-08-17).

DinoPad does not distribute a ROM or ROM-derived playable output. All generation output is private and ignored.

## Host requirements

- Apple Silicon Mac with Xcode (26.x observed) and the iOS Simulator SDK
- CMake >= 3.20, Ninja, Git, Python 3, `make`
- A MIPS-targeting Clang for building the recompiled patch library (`PATCHES_C_COMPILER`). Upstream notes that stock Clang 19+ from the Visual Studio Installer dropped MIPS support; [n64recomp-clang](https://github.com/LT-Schmiddy/n64recomp-clang/releases) provides MIPS-capable builds. On macOS this must be resolved during Phase 2 toolchain bring-up.
- At least 20 GiB free disk (bootstrap observed 28 GiB free)
- A legally obtained, unmodified December 2000 Dinosaur Planet prototype ROM, MD5 `49f7bb346ade39d1915c22e090ffd748`

Accepted input byte orders: `.z64`, `.v64`, `.n64`. The input must normalize to the supported fingerprint.

## Clean private generation pipeline

The target top-level entry point is:

```sh
scripts/build-macos-app.sh --rom /absolute/path/to/your/rom
scripts/build-ios-simulator.sh
scripts/build-ios-device.sh                 # unsigned iphoneos build
scripts/build-ios-device.sh --team TEAM_ID # personal-development signed build
scripts/check-package-safety.sh             # audit unsigned device app
# later: scripts/package-ios.sh
```

The pipeline (mirroring `ref/dino-recomp/BUILDING.md` sections 3-5, plus PaperPad's Apple flow):

1. `scripts/bootstrap.sh` clones exact pins from `dependencies.lock.json` into ignored `ref/` and disables checkout push URLs, including the static macOS FreeType source.
2. `scripts/apply-patches.sh` applies the ordered maintained Apple patch series.
3. Build the MIPS patch library: the `patches/` sources compile to an ELF with the MIPS Clang, then RecompPatcher (`patches.toml`) converts them to `RecompiledPatches` C.
4. Build the N64Recomp/RSPRecomp host tools for Apple Silicon.
5. Normalize and validate the private ROM under ignored `generated/rom/`.
6. Patch the ROM with the decomp's `recomp_rom_patcher.py` to produce the private `baserom.patched.z64` used by the recompiler (recompiler prerequisite, not DinoMod).
7. Generate ignored AOT source: `N64Recomp dino.toml` (game code) and `RSPRecomp aspMain.toml` (audio microcode).
8. Configure and build the chosen ROM-free app with the DinoPad Apple CMake layer (RT64 static + Metal, `HLSL_CPU`, SDL only on macOS, UIKit on iOS).

The first clean generation is long. Use `DINOPAD_MAX_JOBS` (default `min(6, max(2, logical_cpu_count / 2))`) for parallelism; never run more than one build at a time.

## Incremental builds

Once `generated/aot/<game>/lookup.cpp` exists, omit `--rom`:

```sh
scripts/build-macos-app.sh
scripts/build-ios-simulator.sh
scripts/build-ios-device.sh
```

Scripts still verify/fetch pins and apply maintained patches; they refuse to continue when generated source is absent.

## Target outputs

| Target | Output | Notes |
|---|---|---|
| macOS | `build-macos/DinoPad.app` | Apple Silicon; ad-hoc signed, no bundle symlinks, and only Apple system runtime dependencies |
| iOS Simulator | `build-ios-simulator/Release-iphonesimulator/DinoPad.app` | arm64 Simulator app; signing disabled; iPhone+iPad |
| Physical iOS | `build-ios-device/Release-iphoneos/DinoPad.app` | arm64 device app; unsigned by default, or personal-team signed with `--team` |

All app artifacts must remain ROM-free. Use
`scripts/check-macos-package-safety.sh` for macOS and
`scripts/check-package-safety.sh` for physical iOS.

Both Apple targets compile pinned SDL2 2.32.10 in-tree so all SDL objects inherit
the app architecture and deployment target; macOS linker warnings are fatal.
The macOS build also compiles pinned FreeType 2.13.3 statically for RmlUi. PNG,
HarfBuzz, Brotli, bzip2, and external zlib support are disabled because the
bundled UI fonts do not require them. The app audit rejects non-system dylibs,
absolute checkout paths, and bundle symlinks; these gates prevent regressions
to host-only packages or newer-target static objects.

The Simulator target explicitly compiles deterministic environment-driven test
harnesses used by the guarded smoke scripts. The physical-device target forces
those harnesses off. `scripts/check-package-safety.sh` fails a physical app that
contains an automation key/selector/fixture, personal path, unexpected runtime
dependency, signing residue in unsigned mode, ROM/save/log, or restoration data
that differs from its generated sanitization audit. This is a development app
gate; it does not close the separate rights/notices or public-package gates.
Both iOS products also bundle `PrivacyInfo.xcprivacy` at the app root. The
package gate validates its exact no-tracking/no-collection and required-reason
declarations; the final release still requires a transitive dependency/Xcode
privacy-report review.

## macOS session profiles

Restored Adventure is the default. The current engine boundary can also be
selected explicitly while the native home screen is being ported:

```sh
build-macos/DinoPad --profile restored --skip-launcher
build-macos/DinoPad --profile prototype --skip-launcher
```

Unknown profile values fail before runtime initialization. ROM/package data is
shared under the DinoPad data root; configs and saves are isolated under
`Profiles/Restored/` and `Profiles/Prototype/`.

## One runtime at a time

Every launch goes through `scripts/runtime-guard.sh <target> [udid] <command...>`, which terminates any DinoPad process, shuts down all Simulators, verifies zero booted devices, then launches exactly one target and cleans up on exit. Never launch a macOS DinoPad and a Simulator together, and never boot iPhone and iPad Simulators together.

## Simulator install and first run

```sh
scripts/build-ios-simulator.sh
xcrun simctl list devices available
xcrun simctl boot "iPhone 17 Pro"
open -a Simulator
xcrun simctl install booted build-ios-simulator/Release-iphonesimulator/DinoPad.app
xcrun simctl launch booted com.chrissotraidis.dinopad
```

The importer smoke starts from a clean app container, captures the real Files
picker, rejects invalid private fixtures without staging, verifies all three
byte orders and the in-game ROM manager, then checks the imported runtime:

```sh
scripts/runtime-guard.sh iphone-simulator <UDID> scripts/smoke-ios-rom-import.sh
```

The input/lifecycle smoke stages a private supported ROM only in the Simulator
container, verifies every N64 input plus lifecycle/controller behavior, captures
a frame, checks CrashReporter, and shuts down the Simulator:

```sh
scripts/runtime-guard.sh iphone-simulator <UDID> scripts/smoke-ios.sh
```

The native-settings smoke uses two process launches to prove defensive typed
load, live touch/audio/display application, profile-local serialization,
relaunch persistence, modal input clearing/restoration, and safe-area layout:

```sh
scripts/runtime-guard.sh iphone-simulator <UDID> scripts/smoke-ios-settings.sh
```

The diagnostics smoke proves bounded protected capture, pre-persistence path
redaction, useful ROM-free status, native share/cancel, modal input restoration,
and temporary report cleanup:

```sh
scripts/runtime-guard.sh iphone-simulator <UDID> scripts/smoke-ios-diagnostics.sh
```

The final Phase 5 smoke uses a private game-created save and one clean install
to prove 600 seconds of live Restored gameplay, same-container process relaunch
back to controllable gameplay, full input/lifecycle coverage, profile isolation,
bounded diagnostics, and cleanup without storing save bytes in evidence:

```sh
scripts/runtime-guard.sh iphone-simulator <UDID> scripts/smoke-ios-phase5.sh
```

The native-home smoke verifies that UIKit waits before SDL, warns before
Prototype, starts Restored through the real gameplay input poll, returns from a
live runtime to home, then starts Prototype in the same process with isolated
profile state:

```sh
scripts/runtime-guard.sh iphone-simulator <UDID> scripts/smoke-ios-home.sh
```

The iOS shell now has native Files import/replacement, complete default touch
input/lifecycle verification, the Restored/Prototype home boundary, editable
phone/tablet layouts, embedded Restored data, native settings/status, and
bounded redacted diagnostics/share. Save/relaunch and 10-minute runs are
evidenced on both Simulator idioms; iPhone Phase 5 and iPad Phase 6 are green.
Shut the Simulator down before starting a physical-device runtime.

Choose the ROM from the first-run screen. The app validates, normalizes, and stores it privately. Use the `•••` menu > Manage Game ROM to replace or remove it.

End a session before testing another target:

```sh
xcrun simctl terminate booted com.chrissotraidis.dinopad || true
xcrun simctl shutdown all
```

## Physical devices and unsigned IPA

`scripts/build-ios-device.sh` always cross-compiles for the physical `iphoneos`
platform and audits arm64 architecture plus ROM-free contents. With no arguments
it produces an unsigned app containing neither `_CodeSignature` nor
`embedded.mobileprovision`. Pass `--team TEAM_ID` only when a valid personal
Apple Development identity/provision is available; add
`--allow-provisioning-updates` only when Xcode may contact the developer service.
Signed apps are installed with `xcrun devicectl` or Xcode.

The public deliverable is a separate unsigned, self-signable IPA produced by
`scripts/package-ios.sh`, audited by `scripts/check-package-safety.sh`, and
published only after every Phase 10 gate (source tag, ROM-free audit, no
provisioning profile, checksums, notices). Installation instructions will live
in `docs/INSTALL_IPA.md` at release time. The authoritative stop conditions and
physical/package matrices are in
[`RELEASE_CHECKLIST.md`](RELEASE_CHECKLIST.md); its current P0 gates are red, so
the build script's successful audit is not permission to package or publish.

## Troubleshooting notes

- `create_window()` in dino-recomp's `src/runtime/gfx.cpp` is currently a compile-time `static_assert` on Apple; the DinoPad adapter replaces this path (see `docs/ARCHITECTURE.md` section 4.1).
- MIPS Clang version mismatches fail only at patch build time; record the exact toolchain version in `dependencies.lock.json` once pinned.
- Keep incremental builds preferred; clean only the smallest implicated target (`docs/IMPLEMENTATION_PLAN.md` section 7).
