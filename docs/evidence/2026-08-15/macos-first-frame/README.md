# Evidence: First Metal frame on macOS arm64 (GAME SELECT screen)

Date: 2026-08-15
Target: macOS arm64 (Apple M2, macOS 26.5, Xcode 26.6)
Goal: Link the DinoPad macOS executable and render the first Metal frame

## Commands

```sh
cmake -S . -B build-macos -G Ninja -DCMAKE_BUILD_TYPE=Release -DSDL2_DIR=.../sdl2-install
cmake --build build-macos --parallel 4 --target DinoPad
# private launch scratch with the user ROM stored as dino.z64 (fingerprint verified):
<build-macos>/DinoPad --skip-launcher
```

## Result

- PASS: `DinoPad` executable (arm64, 26.9 MB) links the full stack: base game AOT, recompiled patches, RmlUi launcher (bypassed via --skip-launcher), RT64 Metal, N64ModernRuntime, NFD, SDL2 static.
- PASS: the game boots the December 2000 prototype to the **GAME SELECT** screen (three NEW slots, COPY/ERASE, Dino line-art, "A-SELECT B-CANCEL") rendered through RT64 Metal. Screenshot: `game_select.png`.
- PASS: stable session: no crash or fatal renderer error over a 45+ second run; DLL overlays (1..192) load and register during boot.
- PASS: Metal renderer initialized (RT64 prints "RenderPool in Metal is not implemented currently"; resources are created directly on device - known RT64 Metal note, not fatal).

## Root causes fixed this cycle

| Issue | Fix |
|---|---|
| Boot crash `Failed to find function at 0x804D6290` (DLL registration never fired) | Link order: recompiled patches must precede base game code. Generated functions are weak symbols and the first definition wins; upstream links `PatchesLib RecompiledFuncs`. Fixed in CMakeLists.txt (patches before base). |
| Crash in `debug_ui::backend::begin()` each game tick | imgui debug overlay has no Metal backend; disabled init hooks and per-tick entry points on Apple (patches/dino-recomp/0002). |
| `get_bundle_resource_directory` / `dispatch_on_ui_thread` undefined on macOS | DinoPad-owned `src/app/dinopad_support.mm`. |
| Homebrew sdl2-compat picked up by find_package(SDL2) | SDL2_DIR pointed at the installed static SDL2 prefix (build-tools/sdl2-install). |

## Log excerpt (bounded)

```text
Failed to preload executable!
SVG plugin initialised.
Loaded font face 'PriskaSerif-NotThatFat' [weight=500] ...
RenderPool in Metal is not implemented currently. Resources are created directly on device.
SDL Video Driver: cocoa
Device Name: Apple M2
Initializing recomp heap at offset 0x01000000 with size 0x1F000000
Initialized RDRAM at 0x300000000
[reasset] Map 83 contains a zero size object setup (offset 0x0)!
```

## Not verified

- Title screen / gameplay / audio / input / saves (next goals).
- RmlUi launcher rendering on Metal (bypassed with --skip-launcher).

## Cleanup

- macOS DinoPad process: stopped (SIGKILL after capture)
- booted Simulators: 0
- runtime lock: released
