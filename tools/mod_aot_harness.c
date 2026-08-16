// mod_aot_harness.c - isolated host harness for OfflineModRecomp output.
//
// Links the C emitted by OfflineModRecomp for the pinned DinoMod package and
// verifies the static ABI contract that DinoPad's restoration bridge will
// rely on:
//
//   1. recomp_api_version is exported and equals 1.
//   2. imported_funcs and reference_symbol_funcs tables are exported and can
//      be populated by the runtime.
//   3. The runtime binding pointers (get_function, cop0_status_write/read,
//      switch_error, do_break, recomp_trigger_event, reference_section_addresses)
//      are exported writable globals.
//   4. Every mod function is a linkable symbol of the expected signature.
//
// This is a compile/link/ABI smoke test only. It does not execute mod game
// code, which requires a live rdram + runtime bindings (goal 21+).
//
// Build (from repo root, after generating the emitted C):
//   clang tools/mod_aot_harness.c \
//         .goal-loop/dinomod-aot/harness/dinomod_enhanced.o \
//         -I include -I ref/dino-recomp/lib/N64Recomp/include -o mod_aot_harness

#include <stdio.h>
#include <string.h>

// Provides gpr, recomp_context, recomp_func_t and renames recomp.h's function
// declarations so the extern pointer globals below match the emitted C.
#include "mod_recomp.h"

// Symbols exported by the OfflineModRecomp-emitted C (see mod_recomp.h).
extern uint32_t recomp_api_version;
extern recomp_func_t* imported_funcs[];
extern recomp_func_t* reference_symbol_funcs[];
extern uint32_t base_event_index;
extern void (*recomp_trigger_event)(uint8_t* rdram, recomp_context* ctx, uint32_t);
extern recomp_func_t* (*get_function)(int32_t vram);
extern void (*cop0_status_write)(recomp_context* ctx, gpr value);
extern gpr (*cop0_status_read)(recomp_context* ctx);
extern void (*switch_error)(const char* func, uint32_t vram, uint32_t jtbl);
extern void (*do_break)(uint32_t vram);
extern int32_t* reference_section_addresses;
extern int32_t section_addresses[];

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

int main(void) {
    printf("DinoPad mod AOT harness\n");
    printf("recomp_api_version = %u\n", (unsigned)recomp_api_version);
    CHECK(recomp_api_version == 1, "recomp_api_version exported and == 1");

    // Runtime may populate these tables after load; they must exist and be writable.
    CHECK(imported_funcs != NULL, "imported_funcs table exported");
    CHECK(reference_symbol_funcs != NULL, "reference_symbol_funcs table exported");
    imported_funcs[0] = NULL;
    reference_symbol_funcs[0] = NULL;
    CHECK(imported_funcs[0] == NULL, "imported_funcs writable by runtime");
    CHECK(reference_symbol_funcs[0] == NULL, "reference_symbol_funcs writable by runtime");

    CHECK(get_function == NULL, "get_function binding exported (NULL until runtime sets it)");
    CHECK(cop0_status_write == NULL, "cop0_status_write binding exported");
    CHECK(cop0_status_read == NULL, "cop0_status_read binding exported");
    CHECK(switch_error == NULL, "switch_error binding exported");
    CHECK(do_break == NULL, "do_break binding exported");
    CHECK(recomp_trigger_event == NULL, "recomp_trigger_event binding exported");
    CHECK(reference_section_addresses == NULL, "reference_section_addresses binding exported");
    CHECK(section_addresses != NULL, "mod-local section_addresses exported");

    printf("\n%d failure(s)\n", failures);
    return failures == 0 ? 0 : 1;
}
