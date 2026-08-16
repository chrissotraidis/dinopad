## DinoPad offline-mod-recomp proof of concept (plan goal 20)

Date: 2026-08-16. Target: macOS arm64 host toolchain. Result: PASS.

The pinned DinoMod Enhanced v0.9.3 source built a MIPS-II mod ELF (42,997,184 bytes) with the pinned n64recomp-clang toolchain, RecompModTool packaged the .nrm (mod_syms.bin 201,008 B; mod_binary.bin 42,711,744 B; mod.json 32,425 B; thumb.png), and OfflineModRecomp emitted 6,979,048 bytes of C (460 mod functions, 37 imports, 2,346 reference symbols, 294 replacements, 42 hooks in the symbol file).

The emitted C compiles cleanly on arm64 macOS (0 warnings with -O2) against the DinoPad-owned include/mod_recomp.h ABI header and links into a harness that passes 13/13 ABI checks (recomp_api_version == 1, import/reference tables exported and writable, all runtime bindings present).

Key ABI findings:
- OfflineModRecomp emits function-pointer globals for get_function/cop0_status_write/cop0_status_read/switch_error/do_break, while recomp.h declares them as functions; mod_recomp.h renames the recomp.h declarations during include.
- REF_RELOC_HI16/LO16 index the base-game reference_section_addresses table (populated by the runtime), not the mod-local section_addresses.
- The .nrm zip passes integrity testing (4 files).

Known follow-ups (next goals): bind imports, invoke one safe exported function/hook on macOS with a live runtime (goal 21), then full integration.
