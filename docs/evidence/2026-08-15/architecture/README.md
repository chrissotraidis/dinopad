# Evidence: PaperPad and Dino Recompiled inventory, ARCHITECTURE.md

Date: 2026-08-15
Commit: 26f75f9 (scripts); inventory conducted against pinned checkouts
Target: none (source inventory, no runtime)

## Commands

```sh
find ref/paperpad/apple ref/paperpad/patches -type f
sed -n ... ref/dino-recomp/src/runtime/gfx.cpp        # create_window Apple gap
sed -n ... ref/dino-recomp/src/renderer/renderer.cpp  # Metal mapping + __APPLE__ core
sed -n ... ref/dino-recomp/src/runtime/support.cpp    # __APPLE__ paths/dialogs
sed -n ... ref/dino-recomp/CMakeLists.txt             # APPLE shader tooling present
sed -n ... ref/dino-recomp/src/runtime/preload.cpp    # ROM preload (Win32 path)
sed -n ... ref/paperpad/CMakeLists.txt                # iOS deployment target, RT64/SDL wiring
```

## Result

- PASS: inventory recorded in docs/ARCHITECTURE.md.
- Key findings: renderer has a Metal/`__APPLE__` path; `create_window` is the Apple blocker; `--skip-launcher` exists; PaperPad supplies a 30-patch Apple set and a 13-file app shell.

## Cleanup

- macOS DinoPad process: none launched (stopped)
- booted Simulators: 0
- runtime lock: released
