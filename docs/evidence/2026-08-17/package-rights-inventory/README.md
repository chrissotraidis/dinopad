# Goal 31f package-rights inventory evidence

Date: 2026-08-18 UTC
Predecessor commit: `852c1d8`

## Scope

This is an engineering inventory of the exact local macOS development product,
not legal advice or redistribution clearance. The validator checks the final
Ninja link graph and selected app resources against tracked metadata; it does
not infer rights from technical package hygiene.

## Verified inventory

- 17 directly linked components resolve to exact Git commits and expected
  static-archive tokens.
- Every recorded license text matches its pinned SHA-256.
- 10 selected bundled fonts/art/license resources are byte-identical to their pinned
  source files.
- The generated controller database was separately confirmed byte-identical to
  the pinned SDL database plus the maintained extra mapping input; its differing
  source-only hash was expected concatenation, not stale output.

Command:

```sh
python3 tools/validate_package_rights_inventory.py
```

Result: inventory valid, with 10 unresolved/restricted component/resource
states and 6 release blockers reported explicitly.

A temporary manifest with the Dino Recompiled license SHA-256 replaced by all
zeros was rejected with exit 1 and `license hash mismatch`; the tracked manifest
was not modified.

## Fail-closed release control

Command:

```sh
python3 tools/validate_package_rights_inventory.py --require-release-ready
```

Result: exit 2 and `RELEASE RIGHTS GATE: FAIL (no override)`, as required.

The newly explicit blockers include rights for compiled private ROM-derived AOT
despite raw-ROM absence, DinoFont provenance, missing Noto/Lato notices, and
game-logo/Krazoa artwork provenance. Existing root-license, GPL
corresponding-source, DinoMod permission, and complete transitive/iOS notice
work remain red. No package or release is authorized.
