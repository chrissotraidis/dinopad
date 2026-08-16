// mod_invoke_harness.c - invoke one statically converted DinoMod function.
//
// Goal 21: bind one DinoMod import (recomp_get_config_u32) and invoke a real
// mod function (mod_func_16) against a simulated N64 address space, verifying
// observable behavior:
//
//   1. The import stub is called with the expected config key strings.
//   2. The mod's own data section (loaded at its vram) is updated with the
//      config values the import returns.
//   3. The function writes its computed results into base-game data via
//      REF_RELOC (reference_section_addresses), proving the relocation ABI.
//
// This is the live-execution step between the ABI-only harness
// (tools/mod_aot_harness.c) and full runtime integration.
//
// Build (from repo root, after generate-restoration.sh):
//   clang -O2 tools/mod_invoke_harness.c \
//         .goal-loop/dinomod-aot/harness/dinomod_enhanced.o \
//         -I include -I ref/dino-recomp/lib/N64Recomp/include \
//         -o mod_invoke_harness

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "mod_recomp.h"

// ---- ABI exports from the emitted C ----
extern recomp_func_t* imported_funcs[];
extern int32_t* reference_section_addresses;
extern int32_t section_addresses[];

void mod_func_16(uint8_t* rdram, recomp_context* ctx);

// ---- Test parameters ----
enum {
    RDRAM_SIZE = 256 * 1024 * 1024, // Simulated N64 address space (0x80000000+).
    MOD_VRAM = 0x81000000,          // Mod section vram from mod_syms.bin.
    REF_SECTIONS = 512,             // Reference section table size.
};

// N64 addresses are stored sign-extended in gpr registers (S32 semantics),
// e.g. 0x80000000 as gpr is 0xFFFFFFFF80000000. The MEM_* macros subtract
// 0xFFFFFFFF80000000, mapping N64 0x80000000+off to rdram offset `off`.
// Helpers below take plain 32-bit N64 addresses and sign-extend them.
static gpr n64_to_gpr(uint32_t addr) {
    return (gpr)(int32_t)addr;
}

// Mod-data offsets written by mod_func_16 (from the emitted C: RELOC base
// section_addresses[0] = 0x81000000 + 0x28BB914/0x28BB918/0x28BB91C; the
// -0x46EC/-0x46E8/-0x46E4 constants are the sign-extended LO16 halves of
// those addresses, not extra subtractions).
enum {
    MOD_DATA_KEY0_BYTE = 0x28BB914, // cmdmenu_icons_gold_silver_keys
    MOD_DATA_KEY1_BYTE = 0x28BB918, // cmdmenu_icons_firefly
    MOD_DATA_KEY2_BYTE = 0x28BB91C, // cmdmenu_icons_energy_eggs
};

// Base-game data writes via REF_RELOC section 1 (base 0x80000000 in harness).
enum {
    REF_BASE = 0x80000000,
    REF0 = 0x7B40, // halfwords at +0x88 and +0x94
    REF1 = 0x7984, // halfword at +0x16C
    REF2 = 0x7D8C, // halfwords at +0x40 and +0x4C
    REF3 = 0x7E40, // halfwords at +0x40 and +0x4C
};

static uint8_t* g_rdram;
static int g_config_calls = 0;

// Read an N64 string through the runtime's MEM_B convention into a static
// buffer (matches _arg_string in librecomp helpers).
static const char* rdram_string(gpr addr) {
    static char buf[128];
    uint8_t* rdram = g_rdram;
    size_t len = 0;
    while (len < sizeof(buf) - 1) {
        int8_t ch = MEM_B(len, addr);
        if (ch == 0) {
            break;
        }
        buf[len++] = (char)ch;
    }
    buf[len] = '\0';
    return buf;
}

// Stub for imported_funcs[10]: recomp_get_config_u32(rdram, ctx).
// Reads the key string pointer from $a0 (ctx->r4), returns 1 for the three
// keys mod_func_16 queries and 0 otherwise.
static void recomp_get_config_u32_stub(uint8_t* rdram, recomp_context* ctx) {
    const char* key = rdram_string(ctx->r4);
    printf("  [import] recomp_get_config_u32(\"%s\")\n", key);
    g_config_calls++;

    gpr value = 0;
    if (strcmp(key, "cmdmenu_icons_gold_silver_keys") == 0 ||
        strcmp(key, "cmdmenu_icons_firefly") == 0 ||
        strcmp(key, "cmdmenu_icons_energy_eggs") == 0) {
        value = 1; // "enabled"
    }
    ctx->r2 = value;
}

static int failures = 0;

#define CHECK(cond, msg)                                                       \
    do {                                                                       \
        if (cond) {                                                            \
            printf("PASS: %s\n", msg);                                         \
        }                                                                      \
        else {                                                                 \
            printf("FAIL: %s\n", msg);                                         \
            failures++;                                                        \
        }                                                                      \
    } while (0)

// Read back through the same byte-swapped accessors the mod code uses, so
// verification matches the runtime's storage convention.
static uint16_t rdram_u16(uint32_t n64_addr) {
    uint8_t* rdram = g_rdram;
    return MEM_H(0, n64_to_gpr(n64_addr));
}

static uint8_t rdram_u8(uint32_t n64_addr) {
    uint8_t* rdram = g_rdram;
    return MEM_B(0, n64_to_gpr(n64_addr));
}

int main(void) {
    printf("DinoPad mod invoke harness (goal 21)\n");

    g_rdram = calloc(1, RDRAM_SIZE);
    CHECK(g_rdram != NULL, "allocated 256 MB simulated rdram");
    if (g_rdram == NULL) {
        return 1;
    }

    // Load the mod binary at its section vram so mod-local RELOC references
    // and the config key strings resolve.
    FILE* f = fopen(".goal-loop/dinomod-aot/mod_binary.bin", "rb");
    CHECK(f != NULL, "opened mod_binary.bin");
    if (f != NULL) {
        long size;
        fseek(f, 0, SEEK_END);
        size = ftell(f);
        fseek(f, 0, SEEK_SET);
        // Load exactly as the runtime does (init_mod_code): byte-by-byte via
        // MEM_B, which stores the big-endian binary byte-swapped into the
        // host-order rdram buffer.
        uint8_t* rdram = g_rdram;
        gpr mod_base = n64_to_gpr(MOD_VRAM);
        size_t copied = 0;
        int ch;
        while ((ch = fgetc(f)) != EOF) {
            MEM_B(copied, mod_base) = (int8_t)ch;
            copied++;
        }
        fclose(f);
        CHECK(copied == (size_t)size, "loaded mod binary at 0x81000000 (runtime convention)");
        printf("  mod binary size: %ld bytes\n", size);
    }

    // Mod-local section table: section 0 loads at MOD_VRAM (sign-extended gpr).
    section_addresses[0] = (int32_t)MOD_VRAM;

    // Base-game reference section table: all sections map to 0x80000000 so
    // REF_RELOC writes land in low rdram (safe for this isolated invocation).
    static int32_t ref_addrs[REF_SECTIONS];
    for (int i = 0; i < REF_SECTIONS; i++) {
        ref_addrs[i] = REF_BASE;
    }
    reference_section_addresses = ref_addrs;

    // Bind the one import mod_func_16 uses.
    imported_funcs[10] = recomp_get_config_u32_stub;
    CHECK(imported_funcs[10] != NULL, "bound imported_funcs[10] = recomp_get_config_u32 stub");

    // Fresh recomp context with a valid stack in rdram.
    recomp_context ctx;
    memset(&ctx, 0, sizeof(ctx));
    ctx.r29 = n64_to_gpr(0x807FFFF0); // sp near the top of the simulated 8 MB stack region

    printf("calling mod_func_16...\n");
    mod_func_16(g_rdram, &ctx);
    printf("returned.\n");

    CHECK(g_config_calls == 3, "import stub called 3 times (3 config keys)");

    // Config values the stub returned (1) must have been stored into the mod's
    // own data section at the offsets the function writes.
    CHECK(rdram_u8(MOD_VRAM + MOD_DATA_KEY0_BYTE) == 1, "mod data byte[0] = 1 (config stored)");
    CHECK(rdram_u8(MOD_VRAM + MOD_DATA_KEY1_BYTE) == 1, "mod data byte[1] = 1 (config stored)");
    CHECK(rdram_u8(MOD_VRAM + MOD_DATA_KEY2_BYTE) == 1, "mod data byte[2] = 1 (config stored)");

    // The function's computed constants must have been written into base-game
    // data through REF_RELOC. Traced from the emitted C with config=1 (the
    // non-branch path is taken): block 1 stores 0x25C/0x25D, block 2 stores
    // 0x25E, block 3 stores 0x260/0x261.
    CHECK(rdram_u16(REF_BASE + REF0 + 0x88) == 0x25C, "base data +0x7BC8 = 0x25C");
    CHECK(rdram_u16(REF_BASE + REF0 + 0x94) == 0x25D, "base data +0x7BD4 = 0x25D");
    CHECK(rdram_u16(REF_BASE + REF1 + 0x16C) == 0x25E, "base data +0x7AF0 = 0x25E");
    CHECK(rdram_u16(REF_BASE + REF2 + 0x40) == 0x260, "base data +0x7DCC = 0x260");
    CHECK(rdram_u16(REF_BASE + REF2 + 0x4C) == 0x261, "base data +0x7DD8 = 0x261");
    CHECK(rdram_u16(REF_BASE + REF3 + 0x40) == 0x260, "base data +0x7E80 = 0x260");
    CHECK(rdram_u16(REF_BASE + REF3 + 0x4C) == 0x261, "base data +0x7E8C = 0x261");

    printf("\nreference writes:\n");
    printf("  +0x7BC8=%04X +0x7BD4=%04X +0x7AF0=%04X +0x7DCC=%04X +0x7DD8=%04X +0x7E80=%04X +0x7E8C=%04X\n",
           rdram_u16(REF_BASE + REF0 + 0x88), rdram_u16(REF_BASE + REF0 + 0x94),
           rdram_u16(REF_BASE + REF1 + 0x16C), rdram_u16(REF_BASE + REF2 + 0x40),
           rdram_u16(REF_BASE + REF2 + 0x4C), rdram_u16(REF_BASE + REF3 + 0x40),
           rdram_u16(REF_BASE + REF3 + 0x4C));

    printf("\n%d failure(s)\n", failures);
    free(g_rdram);
    return failures == 0 ? 0 : 1;
}
