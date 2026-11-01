cmake_minimum_required(VERSION 3.28)
project(DinoPadGameModule LANGUAGES C CXX)
if(NOT CMAKE_SYSTEM_NAME STREQUAL "iOS" OR NOT CMAKE_OSX_ARCHITECTURES STREQUAL "arm64")
    message(FATAL_ERROR "Use PadMint's arm64 iOS module toolchain")
endif()
get_filename_component(DINOPAD_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../.." ABSOLUTE)
set(DINOPAD_GENERATED "" CACHE PATH "Verified private output from build-game-module.py")
set(DINOPAD_SOURCE "${DINOPAD_ROOT}/ref/dino-recomp" CACHE PATH "Verified pinned public source")
find_package(Python3 REQUIRED COMPONENTS Interpreter)
execute_process(COMMAND "${Python3_EXECUTABLE}" "${DINOPAD_ROOT}/scripts/setup-module-source.py" --verify "${DINOPAD_SOURCE}"
    COMMAND_ERROR_IS_FATAL ANY)
execute_process(COMMAND "${Python3_EXECUTABLE}" "${DINOPAD_ROOT}/scripts/check-module-inputs.py" "${DINOPAD_GENERATED}"
    COMMAND_ERROR_IS_FATAL ANY)
include("${DINOPAD_ROOT}/cmake/ModuleIdentity.cmake")
dinopad_module_identity("${DINOPAD_ROOT}" identity)
set(runtime "${DINOPAD_SOURCE}/lib/N64ModernRuntime")
set(source "${DINOPAD_GENERATED}")
file(GLOB generated CONFIGURE_DEPENDS "${source}/RecompiledFuncs/*.c" "${source}/RecompiledFuncs/*.cpp")
add_library(DinoPadGame SHARED ${generated}
    "${source}/rsp/aspMain.cpp" "${source}/RecompiledPatches/patches.c" "${source}/RecompiledPatches/patches_bin.c"
    "${source}/src/runtime/overlays.cpp" "${source}/src/runtime/patches.cpp"
    "${DINOPAD_ROOT}/apple/module/game_module_entry.cpp")
set_target_properties(DinoPadGame PROPERTIES C_STANDARD 11 CXX_STANDARD 20 CXX_STANDARD_REQUIRED ON
    CXX_SCAN_FOR_MODULES OFF C_VISIBILITY_PRESET hidden CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN ON PREFIX "" OUTPUT_NAME "DinoPadGame")
target_include_directories(DinoPadGame PRIVATE "${DINOPAD_ROOT}/apple/module"
    "${source}/include" "${source}/RecompiledFuncs" "${source}/RecompiledPatches"
    "${DINOPAD_SOURCE}/lib/N64Recomp/include" "${runtime}/librecomp/include" "${runtime}/ultramodern/include"
    "${runtime}/thirdparty" "${runtime}/thirdparty/sse2neon" "${runtime}/thirdparty/concurrentqueue")
target_compile_definitions(DinoPadGame PRIVATE "DINOPAD_MODULE_ID=\"${identity}\"")
target_compile_options(DinoPadGame PRIVATE -fno-strict-aliasing -Wno-implicit-function-declaration
    -Wno-unused-variable -Wno-unused-but-set-variable "-ffile-prefix-map=${DINOPAD_ROOT}=.")
set_source_files_properties("${source}/RecompiledPatches/patches.c" PROPERTIES
    COMPILE_OPTIONS "-include;${DINOPAD_ROOT}/apple/module/patch_attributes.h;-include;${source}/RecompiledFuncs/funcs.h")
target_link_options(DinoPadGame PRIVATE "LINKER:-undefined,dynamic_lookup")
