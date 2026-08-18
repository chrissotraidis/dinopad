# Goal 31e self-contained macOS bundle evidence

Date: 2026-08-18 UTC

## Defects found

The prior app executable loaded FreeType from an absolute Homebrew path, which
in turn loaded Homebrew libpng. Bundle assembly also copied `build-macos/assets`
as an absolute symlink into the developer checkout. Its Info.plist claimed
macOS 11 while its original executable and standalone SDL objects had macOS 26
load commands. The app was runnable only on the build machine and strict
signature verification rejected the symlink.

## Fix

- Added FreeType `VER-2-13-3` at exact commit
  `42608f77f20749dd6ddc9e0536788eaad70ea4b5` to the dependency lock and
  push-disabled bootstrap/safety matrix.
- Built FreeType as a static library with external zlib, bzip2, PNG, HarfBuzz,
  and Brotli support disabled.
- Dereferenced the CMake asset symlink while assembling the app.
- Set the real Mach-O deployment target to macOS 11.0, moved pinned SDL2 into
  the Apple build tree so every object inherits that target, and made macOS
  linker warnings fatal.
- Added a package audit for architecture/platform/minimum, metadata, system-only
  runtime dependencies, symlinks, private paths, prohibited content, and ad-hoc
  signing.
- Aligned the bundle to version 0.1.0 build 1 and implemented the documented
  explicit `--rom` import with validate-before-replace behavior.

## Verification

- CMake reconfiguration selected pinned in-tree `Freetype::Freetype` and
  `SDL2::SDL2-static`, then rebuilt SDL2, `libfreetype.a`, RmlUi, RT64, and
  DinoPad successfully without a newer-target linker warning.
- `xcrun vtool -show-build` reports `platform MACOS` and `minos 11.0` for both
  the final executable and a representative in-tree SDL object.
- `otool -L` on the final executable reports only `/System/Library` frameworks
  and `/usr/lib` libraries; no Homebrew dependency remains.
- The 30 MB app contains no symlink. Strict deep code-signature verification
  passes with an ad-hoc signature.
- `scripts/check-macos-package-safety.sh` passes the final bundle.
- An empty explicit `--rom` negative control was rejected without changing the
  existing private staged ROM.
- The final Info.plist reports version 0.1.0 and build 1.
- `scripts/runtime-guard.sh macos scripts/smoke-macos.sh` passed 22/22 through
  Game Select, controllable gameplay, A/B/Z/Start/WASD input, save presence,
  and clean shutdown. Cleanup reported no DinoPad process and no booted
  Simulator. The large generated screenshots/log remain in ignored local
  `.goal-loop/` evidence rather than duplicating prior committed gameplay media.

This closes macOS host-path portability, not the separate rights/notices,
notarization, long-soak, or public-release gates.
