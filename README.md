# DinoPad

> A native Apple port of the December 2000 *Dinosaur Planet* prototype for
> macOS, iPhone, and iPad.

![Platforms: macOS 11+, iOS and iPadOS 15+](https://img.shields.io/badge/platforms-macOS%2011%2B%20%7C%20iOS%2FiPadOS%2015%2B-1f6feb)
![Renderer: Metal](https://img.shields.io/badge/renderer-Metal-555555)
![Status: development](https://img.shields.io/badge/status-development-b91c1c)
![Game data: user supplied](https://img.shields.io/badge/game%20data-user--supplied%20ROM-d97706)

DinoPad uses static recompilation, RT64's Metal renderer, and a native Apple
shell to run one verified Dinosaur Planet prototype on Apple Silicon. It is not
an emulator, does not use JIT compilation, and does not fetch or execute game
or mod code at runtime.

> **There is no public DinoPad release.** Physical-device validation,
> start-to-credits testing, licensing/notices, DinoMod permission, and
> redistribution review are still open release gates.

> **This repository and its builds do not contain game assets or a ROM.** A
> legally obtained, unmodified December 2000 prototype ROM is required for
> local development. See [Rights and licensing](#rights-and-licensing) before
> building or redistributing anything.

## Table of contents

- [What DinoPad offers](#what-dinopad-offers)
- [System requirements](#system-requirements)
- [Known limitations](#known-limitations)
- [FAQ](#faq)
- [Building](#building)
- [Validation](#validation)
- [Rights and licensing](#rights-and-licensing)
- [Credits](#credits)

## What DinoPad offers

One app presents two isolated ways to explore the prototype:

- **Restored Adventure** is the recommended path. It uses the pinned DinoMod
  Enhanced restoration through statically linked, no-write dispatch.
- **Prototype Mode** is the archival build. It keeps the original incomplete
  experience and requires an explicit warning before launch.

Both modes keep separate saves and settings. On iPhone and iPad, DinoPad opens
with a native dinosaur-themed launcher, a Files-based ROM importer, full N64
touch controls, a persistent `•••` menu, a touch-layout editor, settings, ROM
management, and bounded diagnostics. The macOS app uses the same native
launcher, with keyboard and controller support.

| Target | Verified development state |
|---|---|
| macOS arm64 | Native app bundle, Metal rendering, audio, keyboard input, ROM import, both modes, save persistence, and clean shutdown. |
| iPhone Simulator arm64 | Native launcher/importer, complete touch shell, Restored gameplay, save-preserving relaunch, and 600-second run. |
| iPad Simulator arm64 | Tablet launcher, independent layout persistence, complete product matrix, save relaunch, and 600-second run. |
| Physical iPhone/iPad | ROM-free arm64 build compiles, but installation and runtime validation remain open. |

For the detailed engineering record, see [Status](docs/STATUS.md) and the
[playtest matrix](docs/PLAYTEST_MATRIX.md).

## System requirements

- Apple Silicon Mac running macOS 11 or later
- Xcode with macOS and iOS Simulator SDKs
- CMake 3.20+, Ninja, Git, Python 3, and `make`
- A MIPS-capable Clang toolchain for private generation
- At least 20 GiB of available disk space
- A legally obtained, unmodified 64 MiB December 2000 *Dinosaur Planet*
  prototype ROM

DinoPad accepts `.z64`, `.v64`, and `.n64` input byte orders. It normalizes the
input locally and verifies that it matches the one supported prototype before
storing it in private app storage.

## Known limitations

- No physical iPhone or iPad runtime evidence exists yet.
- A full Restored start-to-credits playthrough and chapter-boundary matrix are
  still open.
- Real controller reconnect, rumble, Bluetooth audio, thermal behavior, memory
  pressure, interruption handling, and in-place update preservation need
  physical-hardware validation.
- The archival prototype is unfinished and may be progression-blocked.
- Touch controls are drawn as a visual overlay; individual controls are not yet
  separate accessibility elements.
- No public binary, IPA, or release package is authorized.

Read [Known issues](docs/KNOWN_ISSUES.md) and
[technical debt](docs/TECHNICAL_DEBT.md) for the full, evidence-linked record.

## FAQ

### What is static recompilation?

Static recompilation translates the supported N64 program into native arm64
code before the app is built. DinoPad's Apple targets use that generated code
with a Metal renderer and native platform shell; they do not emulate an N64 and
do not use runtime code generation.

### Can DinoPad run another ROM or a patched ROM?

No. DinoPad supports exactly one December 2000 prototype. It validates the
normalized input before accepting it and rejects a different revision, modified
file, or wrong size. The ROM is never bundled, uploaded, or downloaded by
DinoPad.

### Where are saves and settings kept?

They stay in DinoPad's private application storage. Restored Adventure and
Prototype Mode have separate save and settings namespaces, so trying the
archival build cannot overwrite a Restored session.

### How do I choose another ROM?

On iPhone and iPad, use `•••` → **Manage Game ROM**. On macOS, use **Replace
ROM…** from the native launcher. Every replacement is normalized and verified
before it can be stored.

### Is Restored Adventure a public mod release?

No. The technical static-restoration integration is development evidence only.
The project cannot publish a Restored binary while DinoMod permission and the
other rights, notice, and package gates remain unresolved.

### Can I install an IPA or download a release?

Not currently. The project has no supported public binary. Source-only local
development remains subject to the repository's rights boundary and all
upstream licenses.

## Building

Follow the complete [build guide](docs/BUILDING.md) for toolchain setup, pinned
dependency bootstrap, private generation, safety audits, target outputs, and
Simulator smoke tests.

Once the private generation prerequisites are available, the principal targets
are:

```sh
scripts/build-macos-app.sh --rom /absolute/path/to/your/rom
scripts/build-ios-simulator.sh
scripts/build-ios-device.sh
```

The macOS command creates `build-macos/DinoPad.app`. The iOS commands create
ROM-free local development apps for Simulator or a physical `iphoneos` target.
The device build is unsigned by default; a personal development team can be
specified only for local testing. It is not a distribution workflow.

Every build must preserve the ROM-free/private-output boundary. Run the package
checks described in [Building](docs/BUILDING.md) before treating an artifact as
testable, and never add generated game data, saves, ROMs, signing material, or
private fixtures to this repository.

## Validation

The strongest current evidence is maintained under `docs/evidence/`:

- [iPhone Simulator Phase 5](docs/evidence/2026-08-17/iphone-phase5/): native
  shell, controls, Restored gameplay, 600-second run, and save relaunch.
- [iPad Simulator Phase 6](docs/evidence/2026-08-17/ipad-simulator-phase6/):
  tablet product matrix, persisted layouts, 600-second run, and relaunch.
- [macOS smoke](docs/evidence/2026-08-16/macos-smoke/): gameplay, input, audio,
  and clean shutdown on arm64 macOS.
- [physical-device preflight](docs/evidence/2026-08-17/physical-device-preflight/):
  ROM-free unsigned `iphoneos` output, without a physical runtime claim.

These results demonstrate development progress on the listed targets. They do
not establish physical-device compatibility, complete gameplay, release-ready
packaging, or redistribution rights.

## Rights and licensing

DinoPad is independent and unofficial. It is not affiliated with or endorsed by
Nintendo, Rare, Microsoft, Dinosaur Planet Recompiled, DinoMod Enhanced,
PaperPad, or their contributors. Game names, assets, characters, copyrights,
and trademarks belong to their respective owners.

The tracked repository contains no ROM, save, generated playable game source,
private fixture, signing identity, or redistributable Restored package. A
ROM-free development executable may still contain locally generated code
derived from user-supplied game data; that technical boundary is **not** a
redistribution-rights conclusion.

Read [Rights and licensing](docs/RIGHTS_AND_LICENSES.md), the
[release checklist](docs/RELEASE_CHECKLIST.md), and the
[package-rights inventory](docs/PACKAGE_RIGHTS_INVENTORY.json) before sharing
source or a build. The current release gate deliberately fails closed.

## Credits

DinoPad is built on pinned work from:

- [Dinosaur Planet: Recompiled](https://github.com/DinosaurPlanetRecomp/dino-recomp)
  for the recompilation project and game integration foundation
- [DinoMod Enhanced](https://github.com/EoinODoodles/dinomod-enhanced-recompiled)
  for the restoration project
- [PaperPad](https://github.com/chrissotraidis/paperpad) for Apple-shell design
  and testing patterns
- [N64: Recompiled](https://github.com/N64Recomp/N64Recomp) for static
  recompilation
- [N64ModernRuntime](https://github.com/N64Recomp/N64ModernRuntime) for common
  recompilation runtime services
- [RT64](https://github.com/rt64/rt64) and [Plume](https://github.com/rt64/rt64)
  for rendering
- [SDL](https://github.com/libsdl-org/SDL), [FreeType](https://freetype.org/),
  and the pinned transitive dependencies listed in
  [dependencies.lock.json](dependencies.lock.json)

Each component retains its own license, notice, and rights boundary. This
README is not a substitute for those original terms.
