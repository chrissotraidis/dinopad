# Goal 31h: compiler-derived dependency and notice inventory

Date: 2026-08-18

This checkpoint replaces a broad “transitive dependency audit pending” claim
with fail-closed coverage derived from the current macOS Ninja dependency
database. It identifies and packages known standalone license texts but does
not claim legal interpretation or complete release notices.

## Coverage result

- 2,227 unique pinned `ref/` source/header paths used by the DinoPad target and
  its build prerequisites.
- 46 deepest-prefix component ownership roots.
- 0 uncovered dependency paths.
- 0 stale component records with no matching compiler dependency.
- Every primary notice source bound to an exact SHA-256.
- 39 standalone license files copied byte-for-byte into
  `Contents/Resources/Notices/Compiled`.
- 7 component roots with inline primary notice sources retained in the index
  with `package_path: null`; extraction and secondary-notice review remain open.

Deepest-prefix matching is intentional. It prevents a parent project's license
from silently claiming a nested vendored dependency that has its own notice.

## Verification

- `python3 tools/validate_compiled_dependency_inventory.py`: PASS, 2,227 files,
  46 components, 7 inline notice sources, zero uncovered.
- `scripts/build-macos-app.sh`: PASS, 39 standalone notices assembled and final
  29 MB app ad-hoc signed.
- `scripts/check-macos-package-safety.sh`: PASS, including exact notice index,
  file set, and source-byte comparisons.
- Removing one packaged standalone license: correctly rejected.
- Modifying the generated index: correctly rejected.
- Modifying a manifest notice hash: correctly rejected.
- `python3 tools/validate_package_rights_inventory.py`: PASS as an engineering
  inventory and now invokes compiler coverage first.
- `python3 tools/validate_package_rights_inventory.py --require-release-ready`:
  correctly returned 2 with no override.

No runtime code changed in this checkpoint, so the already-green Goal 31g
guarded 22/22 gameplay smoke remains the relevant runtime regression. Bundle
assembly and package auditing were rerun after the notice additions.

## Remaining red gates

Review/extraction of inline and possible secondary notices, equivalent iOS
compiler-graph coverage, the root license decision, exact GPL corresponding
source assembly, DinoMod permission, and ROM-derived AOT rights remain open.
Physical-device, progression, final privacy, signing, and release artifact gates
are unchanged.
