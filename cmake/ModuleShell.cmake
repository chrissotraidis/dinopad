function(dinopad_module_shell target)
    include("${DINOPAD_ROOT}/cmake/ModuleIdentity.cmake")
    dinopad_module_identity("${DINOPAD_ROOT}" identity)
    target_sources(${target} PRIVATE "${DINOPAD_ROOT}/apple/module/game_module_loader.cpp")
    target_include_directories(${target} PRIVATE "${DINOPAD_ROOT}/apple/module")
    target_compile_definitions(${target} PRIVATE "DINOPAD_MODULE_ID=\"${identity}\"")
    # Keep one app-owned runtime, including callbacks referenced only by the
    # private module. No translated code belongs in these public libraries.
    target_link_options(${target} PRIVATE "-Wl,-export_dynamic"
        "-Wl,-force_load,$<TARGET_FILE:dinopad_runtime>"
        "-Wl,-force_load,$<TARGET_FILE:librecomp>"
        "-Wl,-force_load,$<TARGET_FILE:ultramodern>")
endfunction()
