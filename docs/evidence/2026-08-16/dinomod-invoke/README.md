## DinoPad DinoMod live invocation proof (plan goal 21)

Date: 2026-08-16. Target: macOS arm64 host harness. Result: PASS.

The statically converted DinoMod C from goal 20 now executes on arm64 with a
bound import. `tools/mod_invoke_harness.c`:

1. Allocates a 256 MB simulated N64 address space and loads the mod binary
   exactly as the runtime does (`init_mod_code`: byte-by-byte via MEM_B, which
   byte-swaps the big-endian binary into host order).
2. Sets the mod-local `section_addresses[0]` to the mod section vram and maps
   every base-game reference section to low rdram.
3. Binds `imported_funcs[10]` (`recomp_get_config_u32`) to a stub that returns
   1 ("enabled") for the three config keys the function queries.
4. Invokes `mod_func_16` with a fresh recomp context.

`mod_func_16` is the pinned mod's `kiosk_icons_gold_silver_keys()` handler in
`src/dlls/engine/1_cmdmenu.c` - a real restoration function that toggles
restored SFA Kiosk inventory icons based on DinoMod config.

Verified observable behavior (all PASS, 0 failures):

- The import stub was called 3 times with the exact config keys:
  `cmdmenu_icons_gold_silver_keys`, `cmdmenu_icons_firefly`,
  `cmdmenu_icons_energy_eggs`.
- The mod's own static state bytes (rsKioskIconsState*) updated to 1.
- Base-game inventory data received exactly the constants the mod source
  writes when enabled: TEXTABLE_25C/25D (gold/silver keys), 25E (firefly),
  260/261 (energy eggs) - matching 0x25C/0x25D/0x25E/0x260/0x261.
- Mod-local RELOC and base-game REF_RELOC relocations both resolve correctly
  against the sign-extended gpr address convention used by the runtime.

This proves the static AOT path executes real restoration logic with bound
imports and correct relocation semantics, without any live recompilation.
Next: bind replacements/hooks/events (294 replacements, 42 hooks from the mod
symbol file) and connect the bridge to the game runtime.
