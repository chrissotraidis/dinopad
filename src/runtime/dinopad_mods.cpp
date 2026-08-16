#include "runtime/mods.hpp"

#include <vector>

#include "dinopad/restoration.hpp"
#include "librecomp/mods.hpp"
#include "renderer/renderer.hpp"

namespace dino::runtime {
namespace {

void enable_texture_pack(recomp::mods::ModContext& context,
                         const recomp::mods::ModHandle& mod) {
    dino::renderer::enable_texture_pack(context, mod);
}

void disable_texture_pack(recomp::mods::ModContext&,
                          const recomp::mods::ModHandle& mod) {
    dino::renderer::disable_texture_pack(mod);
}

void reorder_texture_pack(recomp::mods::ModContext&) {
    dino::renderer::trigger_texture_pack_update();
}

}  // namespace

void register_mods() {
    recomp::mods::ModContentType texture_pack_content_type{
        .content_filename = "rt64.json",
        .allow_runtime_toggle = true,
        .on_enabled = enable_texture_pack,
        .on_disabled = disable_texture_pack,
        .on_reordered = reorder_texture_pack,
    };
    const auto texture_pack_content_type_id =
        recomp::mods::register_mod_content_type(texture_pack_content_type);
    recomp::mods::register_mod_container_type(
        "rtz", std::vector{texture_pack_content_type_id}, false);

    dinopad::restoration::register_static_code();
}

}  // namespace dino::runtime
