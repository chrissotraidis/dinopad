#ifndef DINOPAD_MOD_RECOMP_H
#define DINOPAD_MOD_RECOMP_H

// DinoPad-owned ABI header for statically compiled DinoMod code.
//
// OfflineModRecomp emits C that includes "mod_recomp.h" and declares its
// runtime-facing ABI there. The pinned N64Recomp tree does not ship this
// header, so DinoPad owns it. It must stay ABI-compatible with what
// N64ModernRuntime's mod loader resolves at runtime:
//
//   recomp_api_version, imported_funcs, reference_symbol_funcs,
//   base_event_index, recomp_trigger_event, get_function,
//   cop0_status_write, cop0_status_read, switch_error, do_break,
//   reference_section_addresses, section_addresses
//
// The emitted C defines the five runtime bindings that recomp.h declares as
// functions (get_function, cop0_status_write/read, switch_error, do_break)
// as *function pointers* instead. Rename the recomp.h declarations out of the
// way during the include, then let the emitted definitions take over.
//
// See docs/DINOMOD_INTEGRATION.md for the full bridge contract.

#include <stdint.h>
#include <stdlib.h>

#define get_function recomp_h_orig_get_function
#define cop0_status_write recomp_h_orig_cop0_status_write
#define cop0_status_read recomp_h_orig_cop0_status_read
#define switch_error recomp_h_orig_switch_error
#define do_break recomp_h_orig_do_break
#define section_addresses recomp_h_orig_section_addresses

#include "recomp.h"

#undef get_function
#undef cop0_status_write
#undef cop0_status_read
#undef switch_error
#undef do_break
#undef section_addresses

// When the offline output is linked into DinoPad, keep its writable ABI
// globals distinct from identically named runtime functions. The generated C
// continues to use its original names; the preprocessor gives the linked
// definitions a private, stable prefix. The diagnostic dylib build omits this
// define and retains OfflineModRecomp's ordinary export names.
#if defined(DINOPAD_STATIC_MOD)
#define recomp_api_version dinopad_mod_recomp_api_version
#define imported_funcs dinopad_mod_imported_funcs
#define reference_symbol_funcs dinopad_mod_reference_symbol_funcs
#define base_event_index dinopad_mod_base_event_index
#define recomp_trigger_event dinopad_mod_recomp_trigger_event
#define get_function dinopad_mod_get_function
#define cop0_status_write dinopad_mod_cop0_status_write
#define cop0_status_read dinopad_mod_cop0_status_read
#define switch_error dinopad_mod_switch_error
#define do_break dinopad_mod_do_break
#define reference_section_addresses dinopad_mod_reference_section_addresses
#define section_addresses dinopad_mod_section_addresses
#endif

// Exported mod globals are placed in a dedicated section so a loader can
// enumerate them without relying on symbol-name dlsym alone. This matches the
// approach the pinned dino-recomp patches use for their RECOMP_EXPORT.
#if defined(_MSC_VER)
#define RECOMP_EXPORT __declspec(selectany)
#elif defined(__APPLE__)
// Mach-O section specifiers require a segment and section separated by a comma.
#define RECOMP_EXPORT __attribute__((section("__DATA,recomp_export")))
#else
#define RECOMP_EXPORT __attribute__((section(".recomp_export")))
#endif

// Data-relocation helpers. The emitted C calls these as REF_RELOC_HI16/
// REF_RELOC_LO16 for references into the *base game's* loaded sections, so
// they index reference_section_addresses (populated by the runtime). The
// plain RELOC_HI16/RELOC_LO16 from recomp.h cover references into the mod's
// own section_addresses array.
#define REF_RELOC_HI16(section_index, offset) \
    HI16(reference_section_addresses[(section_index)] + (offset))

#define REF_RELOC_LO16(section_index, offset) \
    LO16(reference_section_addresses[(section_index)] + (offset))

#endif // DINOPAD_MOD_RECOMP_H
