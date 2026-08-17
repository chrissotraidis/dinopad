# DinoMod Enhanced Integration

Last updated: 2026-08-16
Source of truth: docs/IMPLEMENTATION_PLAN.md section 7.
Compatibility pair: Dino Recompiled **v0.3.0** + DinoMod Enhanced **v0.9.3**.

## 1. Status summary

| Item | Status |
|---|---|
| DinoMod source pinned and read-only | DONE (ref/dinomod-enhanced-recompiled @ v0.9.3) |
| DinoMod manifest (`mod.toml`) inventoried | DONE (this document) |
| Toolchain for AOT conversion built | DONE (build-tools/OfflineModRecomp, RecompModTool, RecompModMerger, n64recomp-clang) |
| Mod ELF + .nrm + mod symbols built | DONE (2026-08-16, private; MIPS-II ELF 42,997,184 B; .nrm 4 files, zip-tested) |
| OfflineModRecomp emitted C | DONE (2026-08-16: 6,979,048 B; 460 mod functions, 37 imports, 2,346 reference symbols, 294 replacements, 42 hooks) |
| Emitted C compiles on arm64 + ABI harness | DONE (2026-08-16: 0 warnings; 13/13 harness checks) |
| One import bound + one mod function executed | DONE (2026-08-16: recomp_get_config_u32 bound; mod_func_16 = kiosk_icons_gold_silver_keys ran; 0 failures) |
| Replacements/hooks/events bound into game runtime | DONE on macOS (static no-write dispatch: 294 replacements, 42 hooks / 35 slots; release gate still required) |
| **Maintainer permission / license** | **BLOCKED** - release gate; no public Restored binary/source integration without it |

## 2. Hard policy gate (from the plan)

Before a public Restored Adventure binary or source integration is
distributed, DinoPad must obtain explicit maintainer permission or a
published license compatible with DinoPad's intended redistribution, and
clarify whether DinoPad may build DinoMod from source, include converted
native code, include its manifest/config, include or generate its asset
patches, display "DinoMod Enhanced" in the app, and ship an unsigned IPA
containing the integration. Attribution to every listed contributor must be
preserved.

Until cleared:

- `ref/dinomod-enhanced-recompiled` stays read-only (no AI-authored PRs, no
  generated changes, no bundled source/package in a public release).
- All bridge work lives in DinoPad-owned files.
- Restored release status is marked BLOCKED.

This gate does not stop the base Apple port; it only gates Restored
distribution.

## 3. Package inventory (pinned v0.9.3)

| Path | Purpose |
|---|---|
| `dinomod_enhanced/mod.toml` | Mod manifest: id `dinomod_enhanced`, version 0.9.3, game_id `dino-planet`, min recomp `0.3.0`, config options schema |
| `dinomod_enhanced/Makefile` + `mod.ld` | Builds the mod ELF (`build/mod.elf`) |
| `dino.datasyms_extra.toml` | Extra data symbol references |
| `lib/dino-recomp-decomp-bridge/` | Decomp symbols (dino.syms.toml, dino.datasyms*.toml) |
| `lib/dino-recomp-mod-api/` | Mod API headers |
| `tools/` | Asset extraction/building scripts |
| `assets/` (generated) | Patched game assets (built from the ROM; not redistributable without ROM-derived content rules) |

Manifest highlights:

- `native_libraries = []` - v0.9.3 declares **no native libraries**, so a pure
  offline/AOT conversion path is plausible (no platform-specific DinoMod
  binaries to carry onto Apple).
- `elf_path = "build/mod.elf"`, `mod_filename = "dinomod_enhanced"`.
- Config options: ~30 options (text flavor, audio jingle, accessibility,
  inventory controls, 60 Hz experimental, Sabre/Fox models, etc.); defaults
  are the "restored" experience.
- The mod fixes progression blockers and lets the prototype be explored and
  completed (per upstream README).

## 4. Preferred production path

```text
Pinned DinoMod source
  -> build MIPS mod ELF (make; n64recomp-clang MIPS target)
  -> RecompModTool build (produces .nrm and mod assets)
  -> extract symbols/binary/assets
  -> N64Recomp OfflineModRecomp (mod symbol file + mod binary -> C)
  -> DinoPad static restoration bridge (DinoPad-owned)
  -> arm64 object code linked into DinoPad
```

Toolchain status on Apple Silicon (all built from pinned N64Recomp v0.3.0-era
source into `build-tools/`):

- `OfflineModRecomp <mod syms> <mod binary> <recomp syms> <output C>` - built.
- `RecompModTool <mod.toml> <output>` - built (makes the `.nrm`).
- `RecompModMerger`, `RecompModTool`, `N64Recomp`, `RSPRecomp` - built.
- MIPS Clang (`n64recomp-clang` release-22.1.8 Darwin-arm64) - fetched and
  verified; patches ELF builds.

The bridge must provide hooks/replacements/events registration, asset patch
contribution, generated config schema, enable/disable per session, version
reporting, and separate save namespaces (restored vs prototype).

## 5. Offline-mod-recomp feasibility results (2026-08-16)

The plan treats OfflineModRecomp as the leading feasibility path but not an
assumed production solution ("primarily intended for debugging" in its source
description). The formal feasibility experiment has now been run; results:

- The pinned DinoMod v0.9.3 ELF builds with the pinned n64recomp-clang MIPS
  toolchain (42,997,184 B, MIPS-II, statically linked). The mod's asset
  pipeline requires the private baserom FST (`tools/extract.py`) plus xdelta3
  and Python 3.9+ (PyYAML, toml, pylibyaml); see prerequisites below.
- `RecompModTool dinomod_enhanced/mod.toml <out>` produces a valid .nrm
  (mod_syms.bin + mod_binary.bin + mod.json + thumb.png; zip integrity OK).
- `OfflineModRecomp <mod_syms.bin> <mod_binary.bin> <dino.syms.toml> <out.c>`
  emits 6,979,048 B of C: 460 mod functions, 37 imports, 2,346 reference
  symbols, 294 replacements, 42 hooks (all in the mod symbol file).
- The emitted C compiles cleanly on arm64 macOS (0 warnings, -O2) against the
  DinoPad-owned `include/mod_recomp.h` ABI header and links into
  `tools/mod_aot_harness.c`, which passes 13/13 ABI checks.

ABI findings recorded for the bridge:

- OfflineModRecomp emits the runtime bindings (`get_function`,
  `cop0_status_write/read`, `switch_error`, `do_break`) as function-pointer
  globals, while recomp.h declares them as functions. `mod_recomp.h` renames
  the recomp.h declarations out of the way during the include.
- `REF_RELOC_HI16/LO16` index the base-game `reference_section_addresses`
  table (runtime-populated), not the mod-local `section_addresses` array.
- The .nrm symbol file carries 294 replacements + 42 hooks; the emitted C
  alone does not encode the hook/replacement tables, so the DinoPad bridge
  must read mod_syms.bin (or the .nrm) at build time and generate the binding
  tables alongside the compiled C.
- `section_addresses` in the emitted C is sized to the mod context's single
  merged section; the mod symbol file's section list is the authoritative
  table for runtime section placement.

Prerequisites added to the build environment (documented for reproducibility):

- `xdelta3` (brew install xdelta) - mod asset pipeline.
- Python 3.9+ venv at `.goal-loop/dinomod-venv` with PyYAML, toml, pylibyaml.
- MIPS clang toolchain at `build-tools/toolchains/mips-clang/nrs_bin`.
- Nested decomp submodule `lib/dino-recomp-decomp-bridge/dinosaur-planet` at
  `6615627aa2fefbcf82b652880d6db64aba3f1609` (push URL disabled).

Replayable script: `scripts/generate-restoration.sh`. Evidence:
`docs/evidence/2026-08-16/dinomod-aot/`.

Live invocation result (goal 21, 2026-08-16): `tools/mod_invoke_harness.c`
binds `imported_funcs[10]` (`recomp_get_config_u32`) and executes the
statically converted `mod_func_16` - the pinned mod's
`kiosk_icons_gold_silver_keys()` handler in `src/dlls/engine/1_cmdmenu.c` -
on arm64 against a simulated N64 address space loaded exactly like the
runtime's `init_mod_code`. Verified 0 failures: the import stub was called
with the exact config keys (`cmdmenu_icons_gold_silver_keys`,
`cmdmenu_icons_firefly`, `cmdmenu_icons_energy_eggs`), the mod's static state
bytes updated, and base-game inventory data received exactly the constants
the mod source writes when enabled (TEXTABLE_25C/25D/25E/260/261). This proves
RELOC (mod-local) and REF_RELOC (base-game) relocation semantics plus the
sign-extended gpr address convention, with no live recompilation. Evidence:
`docs/evidence/2026-08-16/dinomod-invoke/`.

Full offline AOT load result (goal 22, 2026-08-16): the pinned package loaded
through N64ModernRuntime's precompiled macOS `.offline.nrm` developer path,
resolving the complete 460-function module with 294 replacements and 42 hooks.
The first run found an arm64 correctness bug: the runtime writes a 16-byte
replacement trampoline, while two generated leaf functions were linked only
four bytes apart. `-falign-functions=16` now protects every generated entry
point; `tools/check_patchable_aot.py` verified 11,162 linked AOT functions with
zero misalignment. The fixed build visibly restores the rolling-demo title
flow, while a same-build run with the mod disabled skips directly to Game
Select. Evidence: `docs/evidence/2026-08-16/dinomod-full-macos/`.

Static code-handle result (goal 23a, 2026-08-16): DinoPad now generates a
typed, contiguous table for all 460 offline functions and links the generated C
into the executable. A generic N64ModernRuntime registration API selects the
build-time handle by manifest ID, and the DinoPad handle directly supplies the
function, import, reference-symbol, section, event, and runtime-binding tables.
With the package renamed to an ordinary `.nrm` and the offline dylib disabled,
the runtime selected the static handle and rendered the same restored title
flow. The executable has no DinoMod dynamic dependency. Evidence:
`docs/evidence/2026-08-16/dinomod-static-macos/`.

Static no-write dispatch result (goal 23b, 2026-08-16): a DinoPad build-time
generator maps every replacement/hook record to the generated base overlay
table, renames 328 affected base definitions, and emits strong wrappers. The
294 replacement wrappers call the linked `mod_func_N` only while the static
handle is active; hook wrappers route 42 callbacks through 35 runtime hook
slots around the original functions. N64ModernRuntime still validates and
records replacement conflicts but skips `patch_func` and unpatch writes for
the static handle. The macOS Mach-O has `r-x` `__TEXT`, no `__GAME` segment,
and no DinoMod dynamic dependency. Restored and Prototype fallback visual
smokes pass on the same binary. Evidence:
`docs/evidence/2026-08-16/dinomod-static-dispatch-macos/`.

Mobile non-executable package result (goal 27c, 2026-08-17):
`tools/build_static_restoration_data.py` maps the pinned MIPS ELF executable
segment through `mod_syms.bin`, verifies every declared function lies inside
it, and zeros all 316,592 executable bytes before deterministically writing an
embedded package with exactly `mod.json`, `mod_syms.bin`, and
`mod_binary.bin`. iOS disables writable-filesystem mod scanning and registers
that bundled data only for Restored; all restoration code remains statically
linked arm64 code and dispatches without runtime writes. A guarded iPhone run
visibly reached the restored `PRESS START` title and controllable ship-deck
cannon tutorial, while a live restart into Prototype omitted package and static
dispatch markers. The package remains private/ignored pending redistribution
permission. Evidence:
`docs/evidence/2026-08-17/iphone-restoration-data/`.

If offline conversion proves incomplete during live binding (goal 21), fall
back to a generic static bridge or ship Prototype-only until solved (plan
risk table).

## 6. Restoration settings bridge

`mod.toml` already carries a typed config schema (Enum/Number options with
ids, names, descriptions, defaults). DinoPad can generate native settings
bindings from it (`tools/generate_mod_settings.py` is the planned generator).
Example options to expose:

- `rolling_demo` (restore Rolling Demo / boot to Game Select; default On)
- `sixty_fps_mode` (experimental 60 Hz; default Off)
- `play_as_fox`, `button_tap_modes`, `cmdmenu_new_controls`,
  `garunda_te_frostweeds_override`, etc.

## 7. Save namespace isolation

Restored and Prototype modes must not share saves:

- Prototype uses `Profiles/Prototype/saves/dino.bin` and disables mod scanning
  plus static restoration registration before runtime startup.
- Restored uses `Profiles/Restored/saves/dino.bin`; it is the default profile.
- General, graphics, controls, sound, mod-list, and per-mod configuration are
  also rooted under the active profile. The ROM and package data stay shared
  and read-only from the session's perspective.
- A disposable-root smoke with distinct 128 KiB sentinels proved that neither
  session touched the other profile's save. Evidence:
  `docs/evidence/2026-08-16/macos-profiles/`.

## 8. Compatibility pair record

- dino-recomp: tag v0.3.0 = `725b2ede9cacc57968e0a028efed8df9235ba483`
- dinomod-enhanced-recompiled: tag v0.9.3 = `d79e86be2304cba75216b0b98e9fb53ee99b7500`
- Supported ROM: MD5 `49f7bb346ade39d1915c22e090ffd748` (private, user-supplied)

## 9. Open questions / blockers

1. Maintainer permission or license (BLOCKED for public Restored).
2. Asset patch redistribution (ROM-derived content rules; build from baserom
   privately, ship only legally distributable derived assets).
3. Whether "DinoMod Enhanced" branding is permitted in the app UI.
