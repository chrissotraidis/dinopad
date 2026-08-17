#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// Blocks inside UIKit's run loop only when no valid private ROM is installed.
// Returns after the user imports the supported December 2000 Dinosaur Planet
// prototype, or when one is already present.
bool dinopad_prepare_rom_setup(void);

// Presents replace/remove controls above the running SDL view.
void dinopad_present_rom_manager(void* presenter_pointer);

#ifdef __cplusplus
}
#endif
