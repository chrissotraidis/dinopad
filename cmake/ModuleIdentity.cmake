function(dinopad_module_identity root output)
    find_package(Python3 REQUIRED COMPONENTS Interpreter)
    file(GLOB_RECURSE contract_sources CONFIGURE_DEPENDS
        "${root}/apple/module/*.h" "${root}/apple/module/*.cpp"
        "${root}/patches/*.patch" "${root}/cmake/*.cmake" "${root}/cmake/*/CMakeLists.txt")
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS ${contract_sources}
        "${root}/dependencies.lock.json" "${root}/CMakeLists.txt"
        "${root}/scripts/module_build.py" "${root}/scripts/build-game-module.py"
        "${root}/scripts/setup-module-source.py" "${root}/scripts/module-identity.py"
        "${root}/scripts/apply-module-patches.py"
        "${root}/cmake/module-host-tools/windows-utf8.manifest"
        "${root}/tools/normalize_rom.py")
    execute_process(COMMAND "${Python3_EXECUTABLE}" "${root}/scripts/module-identity.py"
        OUTPUT_VARIABLE identity OUTPUT_STRIP_TRAILING_WHITESPACE COMMAND_ERROR_IS_FATAL ANY)
    set(${output} "${identity}" PARENT_SCOPE)
endfunction()
