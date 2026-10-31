# Base-game module preparation

This unreleased route separates the base game's translated code from DinoPad's
public iOS app. The existing Mac/static builds and their restoration default are
unchanged. The new shell explicitly disables restoration and does not fetch or
compile DinoMod. It retains the existing iOS 15 minimum.

`padmint.json` (schema 2) now declares Windows x64 and ARM64 as experimental: on
Windows, PadMint runs `scripts/build-game-module.py` and inserts
`DinoPadGame.dylib` into the published `DinoPad-v{version}-ios-shell.ipa`; Macs
keep the existing static build. No such shell has been published yet, so the
Windows route cannot run until a release adds it. The supported ROM completed
this module build on Windows 11 ARM64 and Mac on 31 October 2026 (see the pull
request). Device launch and gameplay are still untested, and the release pause in
`AGENTS.md` still applies.

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
PadMint checks for them before a Windows build starts.
Host generators carry a process-local UTF-8 manifest, and Visual Studio discovery,
environment output, Git repository paths and Python helpers use explicit encodings.
No Windows code-page setting changes are required for non-English folder names.

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
The Unicode follow-up passed 36 Apple Python tests and 14 portable Windows tests
(one expected symlink-privilege skip). Fresh Mac and native Windows ARM64 builds
executed public CPU/RSP fixtures from non-English working, config, input and output
paths. The Windows build also used non-English build and temporary directories;
manifest readback verified UTF-8 and `asInvoker`. Bundled x64 Python started with
UTF-8 mode off. A Unicode source-patch fixture caught Git output being decoded with
the Windows default encoding; explicit UTF-8 decoding fixed it while retaining
the preservation checks. Existing tools and verified public source were reused.
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
