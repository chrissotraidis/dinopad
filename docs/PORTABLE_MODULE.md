# Base-game module preparation

This unreleased route separates the base game's translated code from DinoPad's
public iOS app. The existing Mac/static builds and their restoration default are
unchanged. The new shell explicitly disables restoration and does not fetch or
compile DinoMod. It retains the existing iOS 15 minimum.

The route is still under validation. It is not offered by `padmint.json`, and the
existing published app is not a matching module shell. A supported original ROM
and a matching shell/module build are required before adding a host claim. The
release pause in `AGENTS.md` still applies.

## Build boundary

The app owns the runtime, renderer, input, audio and game threads. The private
`DinoPadGame.dylib` contains translated game functions, strong patch overrides,
generated overlay tables and audio microcode. One versioned getter supplies its
entrypoint, audio callback and registration callbacks. The loader checks every
required pointer, ABI size/version and source-contract identity before startup.

The identity covers the lock, maintained patch set, module boundary, compiler
configuration and preparation helpers. Rebuild the app and module together after
changing those inputs. A module from a different identity is rejected rather
than attached to an incompatible runtime. The app retains the loaded library
for the lifetime of its game threads.

## Public source preparation

`python3 scripts/setup-module-source.py` prepares the pinned sources needed to
generate and compile the module. `--shell` additionally prepares the public app
dependencies. Neither mode prepares restoration sources. Exact commits and
gitlinks come from `dependencies.lock.json`; tracked edits, unexpected untracked
files and mismatched checkouts are preserved and rejected.

Maintained patches are replayed privately from pinned Git blobs before any source
file is changed. Only exact known patch-prefix contents can be updated. A
`--source-dir` supplied to the backend is verified read-only and must already
contain the complete patch set. Build outputs stay outside those source caches.

On a Mac with Xcode, CMake and Ninja:

```sh
scripts/build-module-shell.sh
```

This builds only the unsigned iOS app in `tmp/module-shell`, including its own
native shader helpers. It requires no ROM. It cannot run the game until PadMint
adds a compatible private module.

For a private module, with PadMint's LLVM, MIPS compiler and prepared public-source
iOS SDK available:

```sh
python3 scripts/build-game-module.py \
  --rom /path/to/your-supported-rom.z64 \
  --toolchain /path/to/iPhoneOS-open-source.sdk/toolchain.cmake \
  --build-dir /path/to/private-work --jobs 2
```

The tool accepts verified z64, v64 and n64 byte orders, normalizes a private copy,
and requires the existing supported prototype fingerprint. It preserves the
original. Patch compilation uses the pinned Makefile's source order and flags;
generated inputs have a contract/tool/input ledger and individual checksums.
Stale generated folders are preserved before replacement. The shared SDK must
target iOS 15 to match this app; an iOS 16 module must not be inserted into it.

Windows requires Visual Studio 2022 C++ Build Tools and a Windows SDK. x64 hosts
select an installation with x64 tools; ARM64 hosts retain native ARM preference
and x64 fallback. Native CMake link commands require a local work directory.
These prerequisites describe the implementation, not a completed Windows game
validation or an advertised Windows route.

## Validation and maintenance

Run the synthetic checks without a ROM:

```sh
python3 -m unittest discover -s tests -p 'test_*.py'
python3 tools/normalize_rom.py --self-test
python3 scripts/check-module-loader.py
scripts/check-repo-safety.sh --module-shell
```

The native loader fixture exercises missing/mismatched modules and callbacks,
retry after refusal and strong patch precedence in both link orders. Portable
tests exercise source preservation, complete patch replay, isolated Python
imports, Make semantics, generated-input checks and Windows compiler selection.
The public-source host build also runs an actual generator regression.

Recorded local checks on 2026-10-26: 35 Python tests, 15 native loader/precedence
cases, the real pinned host generators and the unsigned iOS 15 shell passed.
The shell's package audit covered 2,569 compiled source/header dependencies and
41 notice components, with no translated game symbols or restoration content.
The module helper tests also passed under PadMint's bundled Windows Python.
The available ROM did not match the supported fingerprint and was not used;
complete original-ROM generation, module compilation and Windows game packaging
remain unverified.

The pinned DinosaurPlanetRecomp/N64Recomp commit
`8b46781e7d248ce24e235a60fc83cd7dafd56325` emits unsuffixed calls to renamed
reference symbols such as `sprintf`. The host CMake build makes one guarded
correction in its build copy and tests the actual emitter. The same method occurs
in the BearBird and Golden compiler baselines. A future canonical upstream fix
can be backported to each maintained baseline, followed by pin updates and output,
import and package parity checks. Do not replace these distinct baselines with a
single newer compiler merely to remove the local correction.

Synthetic tests, an empty app or successful compilation do not establish device
launch, gameplay, audio, controls or performance. Original game inputs, generated
code, modules and personal IPAs remain private.
