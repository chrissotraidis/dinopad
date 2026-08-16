cmake_minimum_required(VERSION 3.20)

project(DinoPad LANGUAGES C CXX)

set(DINOPAD_VERSION "0.1.0")

if (APPLE)
    enable_language(OBJCXX)
endif()

set(CMAKE_C_STANDARD 17)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if (CMAKE_VERSION VERSION_GREATER_EQUAL "3.24.0")
    cmake_policy(SET CMP0135 NEW)
endif()

get_filename_component(DINOPAD_ROOT "${CMAKE_CURRENT_SOURCE_DIR}" ABSOLUTE)
set(DINO_RECOMP "${DINOPAD_ROOT}/ref/dino-recomp")
set(DINOPAD_AOT "${DINOPAD_ROOT}/generated/aot")
set(DINOPAD_SDL2_BUILD "${DINOPAD_ROOT}/build-macos-sdl2")

# Reproducible builds: do not embed the builder's absolute checkout path.
add_compile_options(
    "-ffile-prefix-map=${DINOPAD_ROOT}=."
    "-fmacro-prefix-map=${DINOPAD_ROOT}=.")

# Runtime headers required by the N64Recomp-generated C.
set(DINOPAD_RECOMP_INCLUDE_DIRS
    "${DINO_RECOMP}/include"
    "${DINO_RECOMP}/lib/N64ModernRuntime/ultramodern/include"
    "${DINO_RECOMP}/lib/N64ModernRuntime/librecomp/include"
    "${DINO_RECOMP}/lib/N64Recomp/include"
    # sse2neon provides <sse2neon.h> used by librecomp rsp_vu on aarch64.
    "${DINO_RECOMP}/lib/N64ModernRuntime/thirdparty/sse2neon")

if (NOT EXISTS "${DINOPAD_AOT}/RecompiledFuncs/funcs.h")
    message(FATAL_ERROR
        "Generated base AOT missing at ${DINOPAD_AOT}. "
        "Run scripts/generate-base.sh --rom <path> first.")
endif()

set(DINOPAD_AOT_COMPILE_OPTIONS
    -fno-strict-aliasing
    # N64ModernRuntime installs arm64 mod replacement trampolines by writing
    # 16 bytes at the start of a generated function. Tiny generated functions
    # can otherwise be only four bytes apart, allowing one replacement to
    # overwrite the next function. Keep every patchable AOT entry point on a
    # 16-byte boundary so each trampoline owns its complete write range.
    -falign-functions=16
    -Wno-unused-variable
    -Wno-implicit-function-declaration)

# Base recompiled game code (N64Recomp output, ROM-derived, private).
file(GLOB DINOPAD_FUNC_C_SOURCES "${DINOPAD_AOT}/RecompiledFuncs/*.c")
file(GLOB DINOPAD_FUNC_CXX_SOURCES "${DINOPAD_AOT}/RecompiledFuncs/*.cpp")
add_library(dinopad_base STATIC ${DINOPAD_FUNC_C_SOURCES} ${DINOPAD_FUNC_CXX_SOURCES})
target_include_directories(dinopad_base PRIVATE
    ${DINOPAD_RECOMP_INCLUDE_DIRS}
    "${DINOPAD_AOT}/RecompiledFuncs")
target_compile_options(dinopad_base PRIVATE ${DINOPAD_AOT_COMPILE_OPTIONS})

# Recompiled patch library (RecompPatcher output incl. embedded patch binary).
add_library(dinopad_patches STATIC
    "${DINOPAD_AOT}/RecompiledPatches/patches.c"
    "${DINOPAD_AOT}/RecompiledPatches/patches_bin.c")
target_include_directories(dinopad_patches PRIVATE
    ${DINOPAD_RECOMP_INCLUDE_DIRS}
    "${DINOPAD_AOT}/RecompiledPatches"
    "${DINOPAD_AOT}/RecompiledFuncs")
target_compile_options(dinopad_patches PRIVATE ${DINOPAD_AOT_COMPILE_OPTIONS})

# Audio microcode (RSPRecomp output).
add_library(dinopad_rsp STATIC "${DINOPAD_AOT}/rsp/aspMain.cpp")
target_include_directories(dinopad_rsp PRIVATE
    ${DINOPAD_RECOMP_INCLUDE_DIRS}
    "${DINOPAD_AOT}/RecompiledFuncs")
target_compile_options(dinopad_rsp PRIVATE -fno-strict-aliasing)

# ---- SDL2 (static, built by scripts/build-sdl2.sh) ------------------------
if (NOT EXISTS "${DINOPAD_SDL2_BUILD}/libSDL2.a")
    message(FATAL_ERROR
        "SDL2 static library missing at ${DINOPAD_SDL2_BUILD}. "
        "Run scripts/build-sdl2.sh first.")
endif()
add_library(dinopad_sdl2 STATIC IMPORTED)
set_target_properties(dinopad_sdl2 PROPERTIES
    IMPORTED_LOCATION "${DINOPAD_SDL2_BUILD}/libSDL2.a"
    INTERFACE_INCLUDE_DIRECTORIES "${DINOPAD_ROOT}/ref/SDL2/include")
# Force find_package(SDL2) in dependency subdirectories (e.g. RmlUi backends)
# to resolve to our static SDL2 build instead of the Homebrew sdl2-compat shim.
set(SDL2_DIR "${DINOPAD_SDL2_BUILD}" CACHE PATH "SDL2 CMake package config directory")

# ---- Renderer and UI dependency stack (pinned dino-recomp submodules) -----
set(RT64_STATIC TRUE CACHE BOOL "Build RT64 as a static library" FORCE)
if (APPLE)
    set(RT64_SDL_WINDOW_VULKAN FALSE CACHE BOOL "Use SDL windows for RT64 Vulkan" FORCE)
endif()
add_compile_definitions(HLSL_CPU)
set(LUNASVG_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(RMLUI_SVG_PLUGIN ON CACHE BOOL "" FORCE)
set(RMLUI_TESTS_ENABLED OFF CACHE BOOL "" FORCE)

add_subdirectory("${DINO_RECOMP}/lib/rt64" "${CMAKE_BINARY_DIR}/rt64")
add_subdirectory("${DINO_RECOMP}/lib/lunasvg")
add_subdirectory("${DINO_RECOMP}/lib/RmlUi")
target_compile_definitions(rmlui_core PRIVATE LUNASVG_BUILD_STATIC)
add_subdirectory("${DINO_RECOMP}/lib/N64ModernRuntime")

# ---- DinoPad runtime: pinned dino-recomp sources (launcher UI included) ---
set(DINOPAD_RUNTIME_SOURCES
    "${DINO_RECOMP}/src/config/config.cpp"
    "${DINO_RECOMP}/src/input/controls.cpp"
    "${DINO_RECOMP}/src/input/input.cpp"
    "${DINO_RECOMP}/src/runtime/audio.cpp"
    "${DINO_RECOMP}/src/runtime/gfx.cpp"
    "${DINO_RECOMP}/src/runtime/mods.cpp"
    "${DINO_RECOMP}/src/runtime/overlays.cpp"
    "${DINO_RECOMP}/src/runtime/patches.cpp"
    "${DINO_RECOMP}/src/runtime/preload.cpp"
    "${DINO_RECOMP}/src/runtime/rom_patcher.cpp"
    "${DINO_RECOMP}/src/runtime/rsp.cpp"
    "${DINO_RECOMP}/src/runtime/support.cpp"
    "${DINO_RECOMP}/src/runtime/threads.cpp"
    "${DINO_RECOMP}/src/recomp_api/common.cpp"
    "${DINO_RECOMP}/src/recomp_api/debug.cpp"
    "${DINO_RECOMP}/src/recomp_api/debug_ui_api.cpp"
    "${DINO_RECOMP}/src/recomp_api/dll.cpp"
    "${DINO_RECOMP}/src/recomp_api/fastcopy.cpp"
    "${DINO_RECOMP}/src/recomp_api/func_8001B4F0_hack.cpp"
    "${DINO_RECOMP}/src/recomp_api/general_api.cpp"
    "${DINO_RECOMP}/src/recomp_api/os_ai.cpp"
    "${DINO_RECOMP}/src/recomp_api/os_sp.cpp"
    "${DINO_RECOMP}/src/recomp_api/recomp_data_api.cpp"
    "${DINO_RECOMP}/src/debug_ui/backend.cpp"
    "${DINO_RECOMP}/src/debug_ui/debug_ui.cpp"
    "${DINO_RECOMP}/src/renderer/hooks.cpp"
    "${DINO_RECOMP}/src/renderer/renderer.cpp"
    "${DINO_RECOMP}/src/ui/ui_api.cpp"
    "${DINO_RECOMP}/src/ui/ui_api_events.cpp"
    "${DINO_RECOMP}/src/ui/ui_api_images.cpp"
    "${DINO_RECOMP}/src/ui/ui_color_hack.cpp"
    "${DINO_RECOMP}/src/ui/ui_config.cpp"
    "${DINO_RECOMP}/src/ui/ui_config_sub_menu.cpp"
    "${DINO_RECOMP}/src/ui/ui_elements.cpp"
    "${DINO_RECOMP}/src/ui/ui_launcher.cpp"
    "${DINO_RECOMP}/src/ui/ui_mod_details_panel.cpp"
    "${DINO_RECOMP}/src/ui/ui_mod_installer.cpp"
    "${DINO_RECOMP}/src/ui/ui_mod_menu.cpp"
    "${DINO_RECOMP}/src/ui/ui_prompt.cpp"
    "${DINO_RECOMP}/src/ui/ui_renderer.cpp"
    "${DINO_RECOMP}/src/ui/ui_rml_hacks.cpp"
    "${DINO_RECOMP}/src/ui/ui_state.cpp"
    "${DINO_RECOMP}/src/ui/ui_utils.cpp"
    "${DINO_RECOMP}/src/ui/core/ui_context.cpp"
    "${DINO_RECOMP}/src/ui/elements/ui_button.cpp"
    "${DINO_RECOMP}/src/ui/elements/ui_clickable.cpp"
    "${DINO_RECOMP}/src/ui/elements/ui_container.cpp"
    "${DINO_RECOMP}/src/ui/elements/ui_element.cpp"
    "${DINO_RECOMP}/src/ui/elements/ui_image.cpp"
    "${DINO_RECOMP}/src/ui/elements/ui_label.cpp"
    "${DINO_RECOMP}/src/ui/elements/ui_radio.cpp"
    "${DINO_RECOMP}/src/ui/elements/ui_scroll_container.cpp"
    "${DINO_RECOMP}/src/ui/elements/ui_slider.cpp"
    "${DINO_RECOMP}/src/ui/elements/ui_span.cpp"
    "${DINO_RECOMP}/src/ui/elements/ui_style.cpp"
    "${DINO_RECOMP}/src/ui/elements/ui_text_input.cpp"
    "${DINO_RECOMP}/src/ui/elements/ui_toggle.cpp"
    "${DINO_RECOMP}/src/ui/util/hsv.cpp")

add_library(dinopad_runtime STATIC ${DINOPAD_RUNTIME_SOURCES})
target_include_directories(dinopad_runtime PUBLIC
    ${DINOPAD_RECOMP_INCLUDE_DIRS}
    "${DINO_RECOMP}/src"
    "${DINO_RECOMP}/lib/concurrentqueue"
    "${DINO_RECOMP}/lib/RmlUi/Include"
    "${DINO_RECOMP}/lib/RmlUi/Backends"
    "${DINO_RECOMP}/lib/rt64/src"
    "${DINO_RECOMP}/lib/rt64/src/contrib"
    "${DINO_RECOMP}/lib/rt64/src/contrib/hlslpp/include"
    "${DINO_RECOMP}/lib/rt64/src/contrib/imgui"
    "${DINO_RECOMP}/lib/rt64/src/contrib/dxc/inc"
    "${DINO_RECOMP}/lib/rt64/src/contrib/Vulkan-Headers/include"
    "${DINO_RECOMP}/lib/rt64/src/contrib/D3D12MemoryAllocator/include"
    "${DINO_RECOMP}/lib/rt64/src/contrib/VulkanMemoryAllocator/include"
    "${DINO_RECOMP}/lib/rt64/src/contrib/nativefiledialog-extended/src/include"
    "${DINO_RECOMP}/lib/promptfont"
    "${DINO_RECOMP}/lib/GamepadMotionHelpers"
    "${DINO_RECOMP}/lib/SlotMap/slot_map"
    "${DINO_RECOMP}/lib/rt64/src/rhi"
    "${DINO_RECOMP}/lib/rt64/src/render"
    "${CMAKE_BINARY_DIR}/rt64/src"
    "${CMAKE_BINARY_DIR}/shaders"
    "${CMAKE_CURRENT_BINARY_DIR}"
    "${DINOPAD_AOT}/RecompiledFuncs")

# Replicate the upstream UI shader generation for the pinned recomp UI.
# build_*_shader() resolves DXC in the caller scope, so the DXC setup from the
# pinned dino-recomp CMakeLists (upstream duplicates it for the same reason)
# must be repeated here.
set (DXC_COMMON_OPTS "-I${DINO_RECOMP}/src")
set (DXC_DXIL_OPTS "-Wno-ignored-attributes")
set (DXC_SPV_OPTS "-spirv" "-fspv-target-env=vulkan1.0" "-fvk-use-dx-layout")
set (DXC_PS_OPTS "${DXC_COMMON_OPTS}" "-E" "PSMain" "-T ps_6_0" "-D DYNAMIC_RENDER_PARAMS")
set (DXC_VS_OPTS "${DXC_COMMON_OPTS}" "-E" "VSMain" "-T vs_6_0" "-D DYNAMIC_RENDER_PARAMS" "-fvk-invert-y")
if (APPLE)
    set (DXC "DYLD_LIBRARY_PATH=${DINO_RECOMP}/lib/rt64/src/contrib/dxc/lib/arm64" "${DINO_RECOMP}/lib/rt64/src/contrib/dxc/bin/arm64/dxc-macos")
endif()
build_vertex_shader(dinopad_runtime "ref/dino-recomp/shaders/InterfaceVS.hlsl" "shaders/InterfaceVS.hlsl")
build_pixel_shader(dinopad_runtime "ref/dino-recomp/shaders/InterfacePS.hlsl" "shaders/InterfacePS.hlsl")

target_compile_options(dinopad_runtime PUBLIC
    -fno-strict-aliasing
    -fms-extensions
    # Upstream is built with MSVC, which permits narrowing in braced init
    # lists; clang rejects it in the pinned UI sources (Apple portability).
    -Wno-c++11-narrowing)

target_link_libraries(dinopad_runtime PUBLIC
    rt64
    plume
    nfd
    libzstd_static
    rmlui_core
    rmlui_debugger
    lunasvg
    ultramodern
    librecomp
    # Order matters: generated functions are weak symbols, and the linker keeps
    # the first definition. The recompiled patch library must precede the base
    # game code so that patched functions (e.g. dll_load, init_dll_system)
    # replace their base counterparts (upstream links PatchesLib first).
    dinopad_patches
    dinopad_base
    dinopad_rsp
    dinopad_sdl2)

if (APPLE)
    target_link_libraries(dinopad_runtime PUBLIC
        "-framework Cocoa"
        "-framework Metal"
        "-framework QuartzCore"
        "-framework IOKit"
        "-framework CoreVideo"
        "-framework CoreAudio"
        "-framework AudioToolbox"
        "-framework ForceFeedback"
        "-framework Carbon"
        "-framework CoreHaptics"
        "-framework GameController")
endif()

# ---- DinoPad macOS executable (base port; first Metal frame) --------------
add_executable(DinoPad
    "${DINO_RECOMP}/src/main.cpp"
    "${DINO_RECOMP}/lib/RmlUi/Backends/RmlUi_Platform_SDL.cpp"
    "${DINOPAD_ROOT}/src/app/dinopad_support.mm")

target_include_directories(DinoPad PRIVATE
    ${DINOPAD_RECOMP_INCLUDE_DIRS}
    "${DINO_RECOMP}/src"
    "${DINO_RECOMP}/lib/concurrentqueue"
    "${DINO_RECOMP}/lib/RmlUi/Include"
    "${DINO_RECOMP}/lib/RmlUi/Backends"
    "${DINO_RECOMP}/lib/rt64/src"
    "${DINO_RECOMP}/lib/rt64/src/contrib"
    "${DINO_RECOMP}/lib/rt64/src/contrib/hlslpp/include"
    "${DINO_RECOMP}/lib/rt64/src/contrib/imgui"
    "${DINO_RECOMP}/lib/rt64/src/contrib/dxc/inc"
    "${DINO_RECOMP}/lib/rt64/src/contrib/Vulkan-Headers/include"
    "${DINO_RECOMP}/lib/rt64/src/contrib/nativefiledialog-extended/src/include"
    "${DINO_RECOMP}/lib/promptfont"
    "${DINO_RECOMP}/lib/GamepadMotionHelpers"
    "${DINO_RECOMP}/lib/SlotMap/slot_map"
    "${DINO_RECOMP}/lib/rt64/src/rhi"
    "${DINO_RECOMP}/lib/rt64/src/render"
    "${CMAKE_BINARY_DIR}/shaders"
    "${DINOPAD_AOT}/RecompiledFuncs")

target_compile_options(DinoPad PRIVATE
    -fno-strict-aliasing
    -fms-extensions)

target_link_libraries(DinoPad PRIVATE
    dinopad_runtime
    dinopad_sdl2)

if (APPLE AND NOT CMAKE_SYSTEM_NAME STREQUAL "iOS")
    # The N64ModernRuntime mod system patches base-game code at runtime
    # (replacement jumps via patch_func). On arm64 macOS, dyld requires the
    # __TEXT segment to be r-x and forces maxprot == initprot, so mprotect
    # cannot make code pages writable. Link the executable's code into a
    # dedicated __GAME segment that permits writes so mod replacements and
    # hooks can be installed. Apple's arm64 linker forces maxprot == initprot,
    # so the macOS feasibility target must start this segment rwx; the runtime
    # still switches each touched page back to r-x after its trampoline write.
    # The iOS production path will use static dispatch and must not rely on a
    # writable executable segment.
    target_link_options(DinoPad PRIVATE
        "-Wl,-rename_section,__TEXT,__text,__GAME,__text"
        "-Wl,-segprot,__GAME,rwx,rwx")
endif()

if (APPLE)
    target_link_libraries(DinoPad PRIVATE
        "-framework Cocoa"
        "-framework Metal"
        "-framework QuartzCore"
        "-framework IOKit"
        "-framework CoreVideo"
        "-framework CoreAudio"
        "-framework AudioToolbox"
        "-framework ForceFeedback"
        "-framework Carbon"
        "-framework CoreHaptics"
        "-framework GameController"
        "-framework Foundation")
endif()
