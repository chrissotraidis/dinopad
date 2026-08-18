#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// Presents DinoPad's native runtime settings and truthful status sheet from
// the supplied UIViewController. The implementation owns no ROM or save data.
void dinopad_present_settings(void* presenter_pointer);

#ifdef __cplusplus
}
#endif
