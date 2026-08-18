cmake_minimum_required(VERSION 3.20)

project(DinoPad LANGUAGES C CXX)

set(DINOPAD_VERSION "0.1.0")
set(DINOPAD_BUILD_NUMBER "1")

option(DINOPAD_ENABLE_TEST_HARNESS
    "Compile environment-driven iOS Simulator automation" OFF)

if (CMAKE_SYSTEM_NAME STREQUAL "iOS")
    set(CMAKE_OSX_DEPLOYMENT_TARGET "15.0" CACHE STRING "Minimum iOS version" FORCE)
    set(DINOPAD_IOS TRUE)
elseif(APPLE)
    set(CMAKE_OSX_DEPLOYMENT_TARGET "11.0" CACHE STRING "Minimum macOS version" FORCE)
endif()

if (APPLE)
    enable_language(OBJC OBJCXX)
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
set(DINOPAD_RESTORATION "${DINOPAD_ROOT}/generated/restoration")

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
    -Wno-unused-variable
    -Wno-implicit-function-declaration
    -Wno-shorten-64-to-32)

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
target_compile_options(dinopad_rsp PRIVATE
    -fno-strict-aliasing
    -Wno-shorten-64-to-32)

# ---- SDL2 -----------------------------------------------------------------
if (APPLE)
    # Build the pinned source in this build tree for both Apple platforms.
    # This keeps every SDL object on the same architecture and deployment
    # target as DinoPad, and prevents a stale host-installed package from
    # entering the macOS link through a dependency's find_package(SDL2).
    set(SDL_SHARED OFF CACHE BOOL "Build SDL shared library" FORCE)
    set(SDL_STATIC ON CACHE BOOL "Build SDL static library" FORCE)
    set(SDL_TEST OFF CACHE BOOL "Build SDL tests" FORCE)
    set(SDL_TESTS OFF CACHE BOOL "Build SDL tests" FORCE)
    unset(SDL2_DIR CACHE)
    add_subdirectory("${DINOPAD_ROOT}/ref/SDL2" "${CMAKE_BINARY_DIR}/sdl2")
    set(SDL2_INCLUDE_DIRS "${DINOPAD_ROOT}/ref/SDL2/include")
    set(SDL2_LIBRARIES SDL2::SDL2-static)
    add_library(dinopad_sdl2 INTERFACE)
    target_link_libraries(dinopad_sdl2 INTERFACE SDL2::SDL2-static)
else()
    find_package(SDL2 REQUIRED)
    add_library(dinopad_sdl2 INTERFACE)
    target_link_libraries(dinopad_sdl2 INTERFACE SDL2::SDL2)
endif()

# ---- Renderer and UI dependency stack (pinned dino-recomp submodules) -----
set(RT64_STATIC TRUE CACHE BOOL "Build RT64 as a static library" FORCE)
if (APPLE)
    set(RT64_SDL_WINDOW_VULKAN FALSE CACHE BOOL "Use SDL windows for RT64 Vulkan" FORCE)
endif()
if (DINOPAD_IOS)
    set(RT64_BUILD_TOOLS OFF CACHE BOOL "RT64 command-line tools" FORCE)
    set(FILE_TO_C_PATH "${DINOPAD_ROOT}/build-macos/rt64/src/tools/file_to_c/file_to_c"
        CACHE FILEPATH "Native host file_to_c")
    set(SPIRV_CROSS_MSL_PATH "${DINO_RECOMP}/lib/rt64/build/bin/spirv_cross_msl"
        CACHE FILEPATH "Native host spirv_cross_msl")
endif()
add_compile_definitions(HLSL_CPU)
set(LUNASVG_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(RMLUI_SVG_PLUGIN ON CACHE BOOL "" FORCE)
set(RMLUI_TESTS_ENABLED OFF CACHE BOOL "" FORCE)
if (DINOPAD_IOS)
    # Mobile setup/settings use UIKit; the skipped desktop launcher does not
    # need RmlUi's external FreeType or SVG font-rendering dependencies.
    set(RMLUI_FONT_ENGINE "none" CACHE STRING "RmlUi font engine" FORCE)
    set(RMLUI_SVG_PLUGIN OFF CACHE BOOL "" FORCE)
elseif(APPLE)
    # A host-installed FreeType dylib makes DinoPad.app depend on an absolute
    # Homebrew path. Build the exact pinned source as a self-contained static
    # library instead. Optional compression/image features are unnecessary for
    # the bundled TrueType UI fonts and would add more host dependencies.
    if (NOT EXISTS "${DINOPAD_ROOT}/ref/freetype/CMakeLists.txt")
        message(FATAL_ERROR
            "Pinned FreeType source missing. Run scripts/bootstrap.sh.")
    endif()
    set(BUILD_SHARED_LIBS OFF CACHE BOOL "Build shared libraries" FORCE)
    set(FT_DISABLE_ZLIB ON CACHE BOOL "Disable FreeType zlib" FORCE)
    set(FT_DISABLE_BZIP2 ON CACHE BOOL "Disable FreeType bzip2" FORCE)
    set(FT_DISABLE_PNG ON CACHE BOOL "Disable FreeType PNG" FORCE)
    set(FT_DISABLE_HARFBUZZ ON CACHE BOOL "Disable FreeType HarfBuzz" FORCE)
    set(FT_DISABLE_BROTLI ON CACHE BOOL "Disable FreeType Brotli" FORCE)
    set(SKIP_INSTALL_ALL ON CACHE BOOL "Do not install bundled FreeType" FORCE)
    add_subdirectory("${DINOPAD_ROOT}/ref/freetype"
        "${CMAKE_BINARY_DIR}/freetype" EXCLUDE_FROM_ALL)
    add_library(Freetype::Freetype ALIAS freetype)
endif()

add_subdirectory("${DINO_RECOMP}/lib/rt64" "${CMAKE_BINARY_DIR}/rt64")
add_subdirectory("${DINO_RECOMP}/lib/lunasvg")
add_subdirectory("${DINO_RECOMP}/lib/RmlUi")
target_compile_definitions(rmlui_core PRIVATE LUNASVG_BUILD_STATIC)
if (DINOPAD_IOS)
    set(N64MODERN_NO_DYNAMIC_CODE ON CACHE BOOL "Disable runtime code generation" FORCE)
endif()
add_subdirectory("${DINO_RECOMP}/lib/N64ModernRuntime")

# ---- Statically linked restoration module ---------------------------------
option(DINOPAD_ENABLE_STATIC_RESTORATION
    "Link the privately generated DinoMod restoration code" ON)
if (DINOPAD_ENABLE_STATIC_RESTORATION)
    foreach(required_file
            dinomod_enhanced.c
            dinomod_static_dispatch.c
            dinomod_static_exports.c
            dinomod_static_exports.h)
        if (NOT EXISTS "${DINOPAD_RESTORATION}/${required_file}")
            message(FATAL_ERROR
                "Generated restoration file missing: ${required_file}. "
                "Run scripts/generate-restoration.sh first.")
        endif()
    endforeach()

    add_library(dinopad_restoration STATIC
        "${DINOPAD_RESTORATION}/dinomod_enhanced.c"
        "${DINOPAD_RESTORATION}/dinomod_static_dispatch.c"
        "${DINOPAD_RESTORATION}/dinomod_static_exports.c"
        "${DINOPAD_ROOT}/src/restoration/static_mod_code.cpp")
    target_compile_definitions(dinopad_restoration PRIVATE DINOPAD_STATIC_MOD=1)
    target_include_directories(dinopad_restoration PRIVATE
        "${DINOPAD_ROOT}/include"
        "${DINOPAD_RESTORATION}"
        ${DINOPAD_RECOMP_INCLUDE_DIRS})
    target_compile_options(dinopad_restoration PRIVATE
        -fno-strict-aliasing
        -Wno-unused-variable
        -Wno-implicit-function-declaration
        -Wno-shorten-64-to-32)
    target_link_libraries(dinopad_restoration PUBLIC librecomp)
endif()

# ---- DinoPad runtime: pinned dino-recomp sources (launcher UI included) ---
set(DINOPAD_RUNTIME_SOURCES
    "${DINO_RECOMP}/src/config/config.cpp"
    "${DINO_RECOMP}/src/input/controls.cpp"
    "${DINO_RECOMP}/src/input/input.cpp"
    "${DINO_RECOMP}/src/runtime/audio.cpp"
    "${DINO_RECOMP}/src/runtime/gfx.cpp"
    "${DINOPAD_ROOT}/src/runtime/dinopad_mods.cpp"
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
    "${DINOPAD_ROOT}/include"
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

if (APPLE AND NOT DINOPAD_IOS)
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

# ---- DinoPad executable ----------------------------------------------------
set(DINOPAD_APP_SOURCES
    "${DINO_RECOMP}/src/main.cpp"
    "${DINO_RECOMP}/lib/RmlUi/Backends/RmlUi_Platform_SDL.cpp")

if (DINOPAD_IOS)
    list(APPEND DINOPAD_APP_SOURCES
        "${DINOPAD_ROOT}/apple/app/diagnostics.mm"
        "${DINOPAD_ROOT}/apple/app/home.mm"
        "${DINOPAD_ROOT}/apple/app/ios_main.mm"
        "${DINOPAD_ROOT}/apple/app/rom_setup.mm"
        "${DINOPAD_ROOT}/apple/app/settings.mm"
        "${DINOPAD_ROOT}/src/app/dinopad_support.mm")
else()
    list(APPEND DINOPAD_APP_SOURCES
        "${DINOPAD_ROOT}/src/app/dinopad_home.mm"
        "${DINOPAD_ROOT}/src/app/dinopad_support.mm")
endif()

add_executable(DinoPad ${DINOPAD_APP_SOURCES})

set_source_files_properties("${DINOPAD_ROOT}/src/app/dinopad_home.mm"
    PROPERTIES COMPILE_OPTIONS "-fobjc-arc")
set_source_files_properties("${DINOPAD_ROOT}/apple/app/ios_main.mm"
    PROPERTIES COMPILE_OPTIONS "-fobjc-arc")
set_source_files_properties("${DINOPAD_ROOT}/apple/app/home.mm"
    PROPERTIES COMPILE_OPTIONS "-fobjc-arc")
set_source_files_properties("${DINOPAD_ROOT}/apple/app/settings.mm"
    PROPERTIES COMPILE_OPTIONS "-fobjc-arc")
set_source_files_properties("${DINOPAD_ROOT}/apple/app/diagnostics.mm"
    PROPERTIES COMPILE_OPTIONS "-fobjc-arc")

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

target_compile_definitions(DinoPad PRIVATE
    DINOPAD_ENABLE_TEST_HARNESS=$<BOOL:${DINOPAD_ENABLE_TEST_HARNESS}>)

if (DINOPAD_ENABLE_STATIC_RESTORATION)
    target_link_libraries(DinoPad PRIVATE dinopad_restoration)
endif()

if (DINOPAD_IOS)
    set(DINOPAD_PRIVACY_MANIFEST "${DINOPAD_ROOT}/apple/app/PrivacyInfo.xcprivacy")
    set_source_files_properties("${DINOPAD_PRIVACY_MANIFEST}"
        PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
    target_sources(DinoPad PRIVATE "${DINOPAD_PRIVACY_MANIFEST}")

    if (DINOPAD_ENABLE_STATIC_RESTORATION)
        set(DINOPAD_RESTORATION_DATA
            "${DINOPAD_RESTORATION}/dinomod_restoration_data.nrm")
        if (NOT EXISTS "${DINOPAD_RESTORATION_DATA}")
            message(FATAL_ERROR
                "Generated restoration data package missing. "
                "Run scripts/generate-restoration.sh first.")
        endif()
        set_source_files_properties("${DINOPAD_RESTORATION_DATA}"
            PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
        target_sources(DinoPad PRIVATE "${DINOPAD_RESTORATION_DATA}")
    endif()

    configure_file(
        "${DINO_RECOMP}/lib/SDL_GameControllerDB/gamecontrollerdb.txt"
        "${CMAKE_BINARY_DIR}/recompcontrollerdb.txt"
        COPYONLY)
    set_source_files_properties("${CMAKE_BINARY_DIR}/recompcontrollerdb.txt"
        PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
    target_sources(DinoPad PRIVATE "${CMAKE_BINARY_DIR}/recompcontrollerdb.txt")
    set_target_properties(DinoPad PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_INFO_PLIST "${DINOPAD_ROOT}/apple/app/Info.plist.in"
        MACOSX_BUNDLE_BUNDLE_NAME "DinoPad"
        MACOSX_BUNDLE_GUI_IDENTIFIER "com.chrissotraidis.dinopad"
        MACOSX_BUNDLE_SHORT_VERSION_STRING "${DINOPAD_VERSION}"
        MACOSX_BUNDLE_BUNDLE_VERSION "${DINOPAD_BUILD_NUMBER}"
        OUTPUT_NAME "DinoPad"
        XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "15.0"
        XCODE_ATTRIBUTE_CODE_SIGN_STYLE Automatic
        XCODE_ATTRIBUTE_DEVELOPMENT_TEAM "${DEVELOPMENT_TEAM}"
        XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "com.chrissotraidis.dinopad"
        XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2")
    target_link_libraries(DinoPad PRIVATE
        SDL2::SDL2main
        SDL2::SDL2-static
        "-framework UIKit"
        "-framework Metal"
        "-framework QuartzCore"
        "-framework CoreGraphics"
        "-framework CoreVideo"
        "-framework CoreAudio"
        "-framework AudioToolbox"
        "-framework CoreHaptics"
        "-framework GameController"
        "-framework UniformTypeIdentifiers"
        "-framework Foundation")
elseif (APPLE)
    # In particular, fail if ld detects an object built for a newer macOS
    # deployment target than the executable.
    target_link_options(DinoPad PRIVATE "LINKER:-fatal_warnings")
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

# ---- DinoPad unit tests (host-only; deterministic input/latch/math) --------
if (NOT DINOPAD_IOS)
    enable_testing()
    add_executable(touch_unit_test tools/touch_unit_test.cpp)
    add_test(NAME touch_unit_test COMMAND touch_unit_test)
endif()
