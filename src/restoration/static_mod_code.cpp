#include "dinopad/restoration.hpp"

#include <memory>
#include <sstream>
#include <string>

#include "dinomod_static_exports.h"
#include "librecomp/mods.hpp"
#include "librecomp/overlays.hpp"
#include "recompiler/context.h"

namespace dinopad::restoration {
namespace {

class StaticModCodeHandle final : public recomp::mods::ModCodeHandle {
public:
    StaticModCodeHandle(const N64Recomp::Context& context,
                        const recomp::mods::ModCodeHandleInputs& inputs) {
        size_t reference_count = 0;
        for (const auto& section : context.sections) {
            for (const auto& reloc : section.relocs) {
                if (reloc.type == N64Recomp::RelocType::R_MIPS_26 &&
                    reloc.reference_symbol &&
                    context.is_regular_reference_section(reloc.target_section)) {
                    ++reference_count;
                }
            }
        }

        is_good_ = context.functions.size() == DINOPAD_MOD_FUNCTION_COUNT &&
                   context.import_symbols.size() <= DINOPAD_MOD_IMPORT_COUNT &&
                   reference_count <= DINOPAD_MOD_REFERENCE_COUNT &&
                   context.sections.size() <= DINOPAD_MOD_SECTION_COUNT;
        if (!is_good_) {
            return;
        }

        dinopad_mod_base_event_index = inputs.base_event_index;
        dinopad_mod_recomp_trigger_event = inputs.recomp_trigger_event;
        dinopad_mod_get_function = inputs.get_function;
        dinopad_mod_cop0_status_write = inputs.cop0_status_write;
        dinopad_mod_cop0_status_read = inputs.cop0_status_read;
        dinopad_mod_switch_error = inputs.switch_error;
        dinopad_mod_do_break = inputs.do_break;
        dinopad_mod_reference_section_addresses = inputs.reference_section_addresses;
    }

    bool good() final { return is_good_; }
    uint32_t get_api_version() final { return dinopad_mod_recomp_api_version; }

    void set_imported_function(size_t import_index,
                               recomp::mods::GenericFunction function) final {
        if (import_index >= DINOPAD_MOD_IMPORT_COUNT) {
            is_good_ = false;
            return;
        }
        dinopad_mod_imported_funcs[import_index] =
            std::get<recomp_func_t*>(function);
    }

    recomp::mods::CodeModLoadError populate_reference_symbols(
        const N64Recomp::Context& context, std::string& error_param) final {
        size_t reference_index = 0;
        for (const auto& section : context.sections) {
            for (const auto& reloc : section.relocs) {
                if (reloc.type != N64Recomp::RelocType::R_MIPS_26 ||
                    !reloc.reference_symbol ||
                    !context.is_regular_reference_section(reloc.target_section)) {
                    continue;
                }
                if (reference_index >= DINOPAD_MOD_REFERENCE_COUNT) {
                    return recomp::mods::CodeModLoadError::InvalidReferenceSymbol;
                }

                recomp_func_t* function =
                    recomp::overlays::get_func_by_section_index_function_offset(
                        reloc.target_section, reloc.target_section_offset);
                if (function == nullptr) {
                    std::ostringstream details;
                    details << std::hex << "section: " << reloc.target_section
                            << " func offset: 0x" << reloc.target_section_offset;
                    error_param = details.str();
                    return recomp::mods::CodeModLoadError::InvalidReferenceSymbol;
                }
                dinopad_mod_reference_symbol_funcs[reference_index++] = function;
            }
        }
        return recomp::mods::CodeModLoadError::Good;
    }

    uint32_t get_base_event_index() final {
        return dinopad_mod_base_event_index;
    }

    void set_local_section_address(size_t section_index, int32_t address) final {
        if (section_index >= DINOPAD_MOD_SECTION_COUNT) {
            is_good_ = false;
            return;
        }
        dinopad_mod_section_addresses[section_index] = address;
    }

    recomp::mods::GenericFunction get_function_handle(size_t function_index) final {
        if (function_index >= DINOPAD_MOD_FUNCTION_COUNT) {
            is_good_ = false;
            return static_cast<recomp_func_t*>(nullptr);
        }
        return dinopad_mod_functions[function_index];
    }

private:
    bool is_good_ = false;
};

std::unique_ptr<recomp::mods::ModCodeHandle> make_static_code_handle(
    const N64Recomp::Context& context,
    const recomp::mods::ModCodeHandleInputs& inputs) {
    return std::make_unique<StaticModCodeHandle>(context, inputs);
}

}  // namespace

void register_static_code() {
    recomp::mods::register_static_mod_code("dinomod_enhanced", make_static_code_handle);
}

}  // namespace dinopad::restoration
