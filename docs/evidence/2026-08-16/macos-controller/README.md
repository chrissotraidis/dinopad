# Evidence: SDL gamecontroller -> N64 input path verified (macOS arm64)

Date: 2026-08-16
Target: macOS arm64 (Apple M2, macOS 26.5, Xcode 26.6)
Goal: Verify controller input (SDL gamepad) on macOS
Result: **PARTIAL - code path verified hardware-free; physical play BLOCKED
(external hardware not connected)**

DinoPad commit: d6510b9 (this evidence set follows)
Upstream pins: dino-recomp v0.3.0 = 725b2ede9cacc57968e0a028efed8df9235ba483;
dinomod v0.9.3 = d79e86be... (unchanged)

## What was verified

`tools/controller_virtual_smoke.cpp` attaches a **virtual** SDL game controller
(SDL_JoystickAttachVirtual, Xbox-style) and exercises the exact SDL calls the
pinned game makes:

- `SDL_GameControllerOpen` on the device (same call the game runs on
  SDL_CONTROLLERDEVICEADDED in `src/input/input.cpp`).
- `SDL_GameControllerGetButton` / `SDL_GameControllerGetAxis` (the exact calls
  in `controller_button_state` / `controller_axis_state`) after a joystick
  poll update, mirroring the game's per-frame `poll_inputs`.
- The default N64 controller mapping semantics
  (`default_n64_controller_mappings` in `src/input/input.cpp`):
  A=SOUTH->0x8000, B=WEST->0x4000, Start->0x1000, D-pad Up->0x0800,
  left stick axes ~+/-1.0, left trigger (Z binding) ~+1.0.

Result: **11/11 checks PASS** (0 failures), no physical hardware involved.
Build: see tools/controller_virtual_smoke.cpp header comment.

## External blocker: no controller connected

- Paired controllers: 8BitDo Lite 2 (E4:17:D8:0D:C0:E9) and Xbox Wireless
  Controller (68:6C:E6:72:A9:19), both Bluetooth **Not Connected**
  (`system_profiler SPBluetoothDataType`).
- SDL enumerates 0 joysticks (`SDL_NumJoysticks() == 0` in a probe).
- No USB gamepad present.
- No prior DinoPad session logged `Controller added` (no
  SDL_CONTROLLERDEVICEADDED event ever observed at runtime).

Physical-controller play (connect a pad, reach gameplay, verify analog +
buttons map to N64 inputs, connect/disconnect handoff) therefore cannot be
completed on this machine right now. This is a release-gate item, not a code
defect: the game's controller code path is compiled in (SDL_INIT_GAMECONTROLLER
in gfx.cpp), the mappings file is staged (build-macos/recompcontrollerdb.txt),
and the SDL layer is verified above.

## Commands

```sh
c++ -std=c++17 -O2 tools/controller_virtual_smoke.cpp -o build-tools/controller_virtual_smoke \
    -I build-tools/sdl2-install/include/SDL2 -L build-tools/sdl2-install/lib -lSDL2 \
    -framework Cocoa -framework Metal -framework QuartzCore -framework IOKit -framework CoreVideo \
    -framework CoreAudio -framework AudioToolbox -framework ForceFeedback -framework Carbon \
    -framework CoreHaptics -framework GameController -framework Foundation \
    -Wl,-rpath,$PWD/build-tools/sdl2-install/lib
./build-tools/controller_virtual_smoke
```

## Cleanup

- No DinoPad app or Simulator was launched (harness only); runtime lock
  untouched.
