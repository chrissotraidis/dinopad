#include "runtime/mods.hpp"

#include <cstdint>
#include <cstdio>
#include <fstream>
#include <iterator>
#include <vector>

#if defined(__APPLE__)
#include <TargetConditionals.h>
#endif

#include "dinopad/restoration.hpp"
#include "librecomp/mods.hpp"
#include "renderer/renderer.hpp"
#include "runtime/support.hpp"

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

#if defined(__APPLE__) && TARGET_OS_IPHONE
std::vector<uint8_t>& restoration_data() {
    static std::vector<uint8_t> bytes;
    if (!bytes.empty()) {
        return bytes;
    }

    const auto path = get_program_path() / "dinomod_restoration_data.nrm";
    std::ifstream stream(path, std::ios::binary);
    if (!stream) {
        std::fprintf(stderr,
                     "ERROR: bundled restoration data is missing: %s\n",
                     path.c_str());
        std::abort();
    }
    bytes.assign(std::istreambuf_iterator<char>(stream),
                 std::istreambuf_iterator<char>());
    if (bytes.empty()) {
        std::fprintf(stderr, "ERROR: bundled restoration data is empty\n");
        std::abort();
    }
    std::fprintf(stderr,
                 "Bundled restoration data registered (%zu bytes; "
                 "filesystem mods disabled)\n",
                 bytes.size());
    return bytes;
}
#endif

}  // namespace

void register_mods(bool restoration_enabled) {
    recomp::mods::set_scanning_enabled(restoration_enabled);
#if defined(__APPLE__) && TARGET_OS_IPHONE
    recomp::mods::set_filesystem_scanning_enabled(false);
#endif

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

    if (restoration_enabled) {
        dinopad::restoration::register_static_code();
#if defined(__APPLE__) && TARGET_OS_IPHONE
        const auto& data = restoration_data();
        recomp::mods::register_embedded_mod(
            "dinomod_enhanced", std::span<const uint8_t>{data});
#endif
    }
}

}  // namespace dino::runtime
