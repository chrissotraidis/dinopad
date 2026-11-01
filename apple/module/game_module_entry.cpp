#include "game_module.h"

extern "C" void recomp_entrypoint(uint8_t*, recomp_context*);
gpr get_entrypoint_address();
extern RspUcodeFunc aspMain;
namespace dino::runtime { void register_overlays(); void register_patches(); }

extern "C" __attribute__((visibility("default")))
const DinoPadGameModule* dinopad_get_game_module() {
    static const DinoPadGameModule module{
        dinopad_game_module_version, sizeof(DinoPadGameModule), DINOPAD_MODULE_ID,
        get_entrypoint_address, recomp_entrypoint, aspMain,
        dino::runtime::register_overlays, dino::runtime::register_patches
    };
    return &module;
}
