// controller_virtual_smoke.cpp - DinoPad hardware-free controller verification.
//
// Verifies the SDL gamecontroller -> N64 input path that the pinned
// dino-recomp uses, without requiring physical hardware:
//   - attach a virtual game controller (SDL_JoystickAttachVirtual)
//   - open it as an SDL_GameController (same call the game makes on
//     SDL_CONTROLLERDEVICEADDED)
//   - drive buttons/axes via SDL_JoystickSetVirtualButton/Axis
//   - confirm SDL_GameControllerGetButton/GetAxis (the exact calls in
//     src/input/input.cpp controller_button_state/controller_axis_state)
//     report the expected values
//   - confirm the default_n64_controller_mappings semantics (A=SOUTH ->
//     0x8000, B=WEST -> 0x4000, START -> 0x1000, dpad, analog axes)
//
// Build:
//   c++ -std=c++17 -O2 tools/controller_virtual_smoke.cpp -o build-tools/controller_virtual_smoke \
//       -I build-tools/sdl2-install/include -L build-tools/sdl2-install/lib \
//       -lSDL2 -Wl,-rpath,$PWD/build-tools/sdl2-install/lib
#include <SDL.h>
#include <cstdio>
#include <cstring>
#include <cstdint>

static int failures = 0;
static int checks = 0;

static void check(bool ok, const char* what) {
    checks++;
    if (!ok) {
        failures++;
        printf("FAIL: %s\n", what);
    } else {
        printf("PASS: %s\n", what);
    }
}

// Mirrors dino::input defaults (src/input/input.cpp default_n64_controller_mappings).
static uint16_t n64_buttons(SDL_GameController* c) {
    uint16_t b = 0;
    if (SDL_GameControllerGetButton(c, SDL_CONTROLLER_BUTTON_A)) b |= 0x8000;  // A
    if (SDL_GameControllerGetButton(c, SDL_CONTROLLER_BUTTON_X))  b |= 0x4000;  // B
    if (SDL_GameControllerGetButton(c, SDL_CONTROLLER_BUTTON_START)) b |= 0x1000;  // Start
    if (SDL_GameControllerGetButton(c, SDL_CONTROLLER_BUTTON_DPAD_UP))    b |= 0x0800;
    if (SDL_GameControllerGetButton(c, SDL_CONTROLLER_BUTTON_DPAD_RIGHT)) b |= 0x0100;
    if (SDL_GameControllerGetButton(c, SDL_CONTROLLER_BUTTON_DPAD_DOWN))  b |= 0x0400;
    if (SDL_GameControllerGetButton(c, SDL_CONTROLLER_BUTTON_DPAD_LEFT))  b |= 0x0200;
    if (SDL_GameControllerGetButton(c, SDL_CONTROLLER_BUTTON_LEFTSHOULDER)) b |= 0x0020; // L
    return b;
}

int main() {
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMECONTROLLER | SDL_INIT_JOYSTICK) < 0) {
        printf("FATAL: SDL_Init failed: %s\n", SDL_GetError());
        return 2;
    }

    // Virtual Xbox 360-style controller: 15 buttons, 6 axes.
    SDL_VirtualJoystickDesc desc;
    std::memset(&desc, 0, sizeof(desc));
    desc.version = SDL_VIRTUAL_JOYSTICK_DESC_VERSION;
    desc.type = SDL_JOYSTICK_TYPE_GAMECONTROLLER;
    desc.naxes = 6;
    desc.nbuttons = 15;
    desc.nhats = 0;
    desc.vendor_id = 0x045E;  // Microsoft
    desc.product_id = 0x028E; // Xbox 360 controller
    desc.name = "DinoPad Virtual Controller";

    int jid = SDL_JoystickAttachVirtual(SDL_JOYSTICK_TYPE_GAMECONTROLLER, desc.naxes, desc.nbuttons, desc.nhats);
    check(jid >= 0, "SDL_JoystickAttachVirtual creates a virtual controller");
    if (jid < 0) {
        printf("  error: %s\n", SDL_GetError());
        return 2;
    }

    // Same open path the game runs on SDL_CONTROLLERDEVICEADDED.
    SDL_GameController* controller = SDL_GameControllerOpen(jid);
    check(controller != nullptr, "SDL_GameControllerOpen succeeds on the virtual device");
    if (controller == nullptr) {
        printf("  error: %s\n", SDL_GetError());
        return 2;
    }

    // Poll the event queue like the game does; a real device would emit
    // CONTROLLERDEVICEADDED here, and the game would open it the same way.
    SDL_Event ev;
    int added = 0;
    while (SDL_PollEvent(&ev)) {
        if (ev.type == SDL_CONTROLLERDEVICEADDED) added++;
    }
    printf("note: controller device events observed during poll: %d\n", added);

    // Buttons: drive each and confirm the exact SDL call the game makes.
    SDL_Joystick* joy = SDL_GameControllerGetJoystick(controller);
    check(joy != nullptr, "SDL_GameControllerGetJoystick works");

    SDL_JoystickSetVirtualButton(joy, SDL_CONTROLLER_BUTTON_A, SDL_PRESSED);
    SDL_JoystickUpdate();  // the game's poll loop calls this every frame
    check(SDL_GameControllerGetButton(controller, SDL_CONTROLLER_BUTTON_A) == SDL_PRESSED,
          "A button reads pressed via the same SDL call the game uses");
    check((n64_buttons(controller) & 0x8000) != 0, "A maps to N64 bit 0x8000 (default mapping)");

    SDL_JoystickSetVirtualButton(joy, SDL_CONTROLLER_BUTTON_X, SDL_PRESSED);
    SDL_JoystickSetVirtualButton(joy, SDL_CONTROLLER_BUTTON_START, SDL_PRESSED);
    SDL_JoystickSetVirtualButton(joy, SDL_CONTROLLER_BUTTON_DPAD_UP, SDL_PRESSED);
    SDL_JoystickUpdate();
    check((n64_buttons(controller) & 0x4000) != 0, "B (X) maps to N64 bit 0x4000");
    check((n64_buttons(controller) & 0x1000) != 0, "Start maps to N64 bit 0x1000");
    check((n64_buttons(controller) & 0x0800) != 0, "D-pad Up maps to N64 bit 0x0800");

    // Analog: full left stick X.
    SDL_JoystickSetVirtualAxis(joy, SDL_CONTROLLER_AXIS_LEFTX, 32767);
    SDL_JoystickUpdate();
    float axis_val = SDL_GameControllerGetAxis(controller, SDL_CONTROLLER_AXIS_LEFTX) * (1 / 32768.0f);
    check(axis_val > 0.95f && axis_val <= 1.0f,
          "left stick X reads ~+1.0 through SDL_GameControllerGetAxis (same call as game)");

    SDL_JoystickSetVirtualAxis(joy, SDL_CONTROLLER_AXIS_LEFTY, -32768);
    SDL_JoystickUpdate();
    axis_val = SDL_GameControllerGetAxis(controller, SDL_CONTROLLER_AXIS_LEFTY) * (1 / 32768.0f);
    check(axis_val < -0.95f,
          "left stick Y reads ~-1.0 (same call as game)");

    // Trigger axes (Z and R use SDL_CONTROLLER_AXIS_TRIGGERLEFT/RIGHT + 1 as
    // ControllerAnalog with positive range).
    SDL_JoystickSetVirtualAxis(joy, SDL_CONTROLLER_AXIS_TRIGGERLEFT, 32767);
    SDL_JoystickUpdate();
    float z_val = SDL_GameControllerGetAxis(controller, SDL_CONTROLLER_AXIS_TRIGGERLEFT) * (1 / 32768.0f);
    check(z_val > 0.95f, "left trigger (Z) reads ~+1.0 via the game's Z binding path");

    SDL_GameControllerClose(controller);
    SDL_JoystickDetachVirtual(jid);
    SDL_Quit();

    printf("\ncontroller_virtual_smoke: %d checks, %d failures\n", checks, failures);
    return failures == 0 ? 0 : 1;
}
