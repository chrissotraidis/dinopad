# Physical-device release-boundary evidence

Date: 2026-08-17

Goal: keep deterministic Simulator automation available for regression testing
without shipping its environment-driven entry points, simulated-touch selectors,
or adversarial privacy fixtures in physical-device/release builds.

## Result

- `DINOPAD_ENABLE_TEST_HARNESS` defaults to `OFF`.
- `scripts/build-ios-simulator.sh` opts in explicitly; its Release Simulator
  binary retains the harness and passed the complete guarded 8-second
  input/lifecycle smoke.
- `scripts/build-ios-device.sh` forces the option off, preventing a stale CMake
  cache from enabling it in a physical build.
- The rebuilt unsigned device executable is arm64, platform `IOS`, minimum iOS
  15.0, 21,670,752 bytes, and SHA-256
  `6852b86e8bd7145318e61949c42ed7475f251b944f84aae261d549bfe8cd452c`.
- Its strings contain no Simulator automation environment key, simulated-touch
  or `ForTesting` selector, automation phase, adversarial path/UUID fixture,
  personal build path, or likely credential.
- `scripts/check-package-safety.sh` also verifies unsigned state, system-only
  dynamic dependencies, no `LC_RPATH`, no ROM/save/log/signing/private output,
  and the exact sanitized restoration package audit hash
  `2ee8befb8ee724e776f52b7654eb2202ae9f6971d716df1aafc5346e617be5e1`.
- A copied test-enabled Simulator app is rejected as a negative control.
- Guard cleanup reported zero booted Simulators and no DinoPad process.

## Commands

```sh
scripts/build-ios-simulator.sh
scripts/build-ios-device.sh
scripts/check-package-safety.sh
scripts/runtime-guard.sh iphone-simulator <UDID> scripts/smoke-ios.sh
cmake --build build-macos --parallel 4 --target DinoPad
ctest --test-dir build-macos --output-on-failure
```

The physical runtime matrix remains externally blocked by the absence of a
connected device and signing identity. This evidence does not authorize public
redistribution of the sanitized DinoMod data and does not close missing
license/notice or progression gates.
