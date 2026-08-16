#include <SDL.h>

extern "C" int dinopad_recomp_main(int argc, char **argv);

extern "C" int SDL_main(int, char **) {
    char app_name[] = "DinoPad";
    char skip_launcher[] = "--skip-launcher";
    char profile_flag[] = "--profile";
    char profile_name[] = "restored";
    char *arguments[] = {
        app_name,
        skip_launcher,
        profile_flag,
        profile_name,
        nullptr,
    };
    return dinopad_recomp_main(4, arguments);
}
