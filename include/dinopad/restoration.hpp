#ifndef DINOPAD_RESTORATION_HPP
#define DINOPAD_RESTORATION_HPP

namespace dinopad::restoration {

// Register the generated DinoMod code handle with N64ModernRuntime. The
// package manifest/symbols/assets still come from the private .nrm, but every
// executable function is resolved from code linked into DinoPad.
void register_static_code();

}  // namespace dinopad::restoration

#endif
