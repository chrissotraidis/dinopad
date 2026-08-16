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
| Restored mode integrated into DinoPad | NOT STARTED (technical work follows; release gate first) |
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

## 5. Offline-mod-recomp feasibility notes

The plan treats OfflineModRecomp as the leading feasibility path but not an
assumed production solution ("primarily intended for debugging" in its source
description). It must be validated:

- Build the pinned DinoMod ELF (needs the baserom for asset extraction;
  baserom is private).
- Run OfflineModRecomp and inspect the generated C for correctness.
- If offline conversion is incomplete, fall back to a generic static bridge
  or ship Prototype-only until solved (plan risk table).

This is a formal feasibility experiment, scheduled as the next restoration
milestone after the Apple shell port; it is not yet exercised.

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

- Prototype Mode uses the base save namespace (no DinoMod).
- Restored Adventure uses a separate restored save namespace.
- `ultramodern::change_save_file(subfolder, name)` in the pinned
  N64ModernRuntime supports subfolders; the DinoPad bridge selects the
  namespace at session start.

## 8. Compatibility pair record

- dino-recomp: tag v0.3.0 = `725b2ede9cacc57968e0a028efed8df9235ba483`
- dinomod-enhanced-recompiled: tag v0.9.3 = `d79e86be2304cba75216b0b98e9fb53ee99b7500`
- Supported ROM: MD5 `49f7bb346ade39d1915c22e090ffd748` (private, user-supplied)

## 9. Open questions / blockers

1. Maintainer permission or license (BLOCKED for public Restored).
2. OfflineModRecomp completeness for this mod (needs validation run).
3. Asset patch redistribution (ROM-derived content rules; build from baserom
   privately, ship only legally distributable derived assets).
4. Whether "DinoMod Enhanced" branding is permitted in the app UI.
