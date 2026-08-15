cmake_minimum_required(VERSION 3.20)

project(DinoPad LANGUAGES C CXX)

set(DINOPAD_VERSION "0.1.0")

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
    -Wno-implicit-function-declaration)

# Base recompiled game code (N64Recomp output, ROM-derived, private).
file(GLOB DINOPAD_FUNC_C_SOURCES "${DINOPAD_AOT}/RecompiledFuncs/*.c")
add_library(dinopad_base STATIC ${DINOPAD_FUNC_C_SOURCES})
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
