#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// Presents DinoPad's native UIKit home before SDL startup and blocks until the
// user selects Restored Adventure (0) or confirms Prototype Mode (1).
int dinopad_present_home(void);

#ifdef __cplusplus
}
#endif
