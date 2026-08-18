# Goal 31i: physical-iOS compiled dependency inventory

Date: 2026-08-18

This checkpoint extends Goal 31h's compiler-derived notice coverage to the
unsigned physical-iOS product. It is an engineering inventory and exact package
check, not legal interpretation or release clearance.

## Coverage result

- 1,032 current Xcode `.d` dependency files inspected.
- 2,578 unique pinned `ref/` source/header paths.
- 41 deepest-prefix ownership roots present; zero uncovered paths.
- Five macOS-only roots are declared as target exclusions and proved absent:
  FreeType, plainargs, RmlUi Containers, SLJIT, and SPIRV-Cross.
- 35 standalone license files copied byte-for-byte into the iOS app's
  `Notices/Compiled` tree.
- 6 target-present inline-primary notice roots remain null in the iOS index.
- Across macOS and iOS, 7 union inline-primary roots remain pending because
  plainargs is macOS-only.

## Build integration and verification

The device build stages notices before CMake configuration. CMake adds every
staged file to the iOS bundle resource phase, so future development-signed apps
will be signed with the notices already present rather than modified afterward.

- `python3 tools/validate_compiled_dependency_inventory.py`: PASS for macOS
  2,227/46 and iOS 2,578/41, both with zero uncovered.
- `scripts/build-ios-device.sh`: PASS; rebuilt unsigned arm64 device app.
- `scripts/check-package-safety.sh`: PASS, including exact graph, active target
  set, notice index/file bytes, iOS 15 minimum, system dependencies, test-harness
  absence, ROM/private-path absence, privacy manifest, sanitized restoration,
  and unsigned state.
- Removing one iOS standalone notice: correctly rejected.
- Falsely declaring macOS-only FreeType active on iOS: correctly rejected by
  actual dependency-set comparison.

No runtime code changed, so no physical or Simulator runtime claim is added.

## Remaining red gates

Reviewed extraction of inline notices and secondary-notice analysis remain open,
as do the root-license decision, GPL corresponding-source assembly, DinoMod
permission, ROM-derived AOT rights, physical-device runtime, progression, final
privacy, signing, and release artifact gates.
