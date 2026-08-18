#pragma once

// Simulator automation is compiled only into explicit test builds. Physical
// device and release builds must not expose environment-driven automation or
// retain private-path fixtures in the application binary.
#ifndef DINOPAD_ENABLE_TEST_HARNESS
#define DINOPAD_ENABLE_TEST_HARNESS 0
#endif
