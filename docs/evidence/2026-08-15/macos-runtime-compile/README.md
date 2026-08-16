# Evidence: DinoPad runtime stack compiles for macOS arm64

Date: 2026-08-15
Commit: 66f1e69 (baseline; this goal adds the runtime build)
Target: none (compile-only milestone, no runtime launched)

## Commands

```sh
scripts/apply-patches.sh        # Apple window adapter + hlslpp labs fix (idempotent)
scripts/build-sdl2.sh           # native SDL2 2.32.10 static
cmake -S . -B build-macos -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build-macos --parallel 4
```

## Result

- PASS: RT64 (dino-planet fork) builds as a static library for macOS arm64 with the Metal RHI (rt64.a, plume Metal, nfd, zstd, re-spirv, file_to_c).
- PASS: RmlUi + lunasvg build for macOS arm64 (launcher UI retained per plan's "use them temporarily" path).
- PASS: N64ModernRuntime (ultramodern + librecomp) builds for macOS arm64.
- PASS: `dinopad_runtime` (all pinned dino-recomp sources: config, input, runtime, recomp_api, renderer, debug_ui, ui) compiles; libdinopad_runtime.a 3,263,240 bytes, arm64.
- PASS: `dinopad_base`/`dinopad_patches`/`dinopad_rsp` (generated AOT) compile and are linked into the graph.
- PASS: UI shaders (InterfaceVS/InterfacePS) compile via vendored dxc-macos into SPIR-V + MSL.
- PASS: repository safety audit green with the patch series applied; push URLs disabled on all nested reference repos.

## Apple port adaptations (all DinoPad-owned)

| Adaptation | Location |
|---|---|
| SDL Metal window path for create_window (PaperPad pattern) | patches/dino-recomp/0001-macos-sdl-metal-window.patch |
| hlslpp `labs` include fix (Apple clang) | patches/hlslpp/0001-scalar-labs.patch |
| DXC setup duplicated in caller scope (upstream does the same; its TODO comment) | CMakeLists.txt |
| MSVC-only narrowing in braced init tolerated via -Wno-c++11-narrowing | CMakeLists.txt |
| Generated-output symlinks in ref/dino-recomp (upstream relative includes) | RecompiledFuncs -> ../../generated/aot/RecompiledFuncs |

## Cleanup

- macOS DinoPad process: none launched (stopped)
- booted Simulators: 0
- runtime lock: released
