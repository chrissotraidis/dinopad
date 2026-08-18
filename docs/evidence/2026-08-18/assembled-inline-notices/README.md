# Goal 31j: assembled inline-primary dependency notices

Date: 2026-08-18

This checkpoint mechanically converts the seven union inline-primary notice
records from Goals 31h/31i into packaged files. It does not claim that a lawyer
or second reviewer has established complete notice obligations.

## Assemblies

Five tracked documents cover seven component records because ConcurrentQueue
and nlohmann/json are vendored in two ownership roots:

- ConcurrentQueue: simplified BSD block plus the embedded Jeff Preshing
  semaphore notice; the missing referenced Boost `LICENSE.md` is called out.
- nlohmann/json: primary MIT block plus visible Hedley, Grisu2, and UTF-8
  attribution notes from the amalgamated header.
- SSE2NEON: primary MIT block.
- miniz: visible MIT and public-domain/Unlicense blocks.
- plainargs: visible public-domain/Unlicense block.

Each assembly and its pinned inline source are independently SHA-256 bound in
`docs/COMPILED_DEPENDENCY_INVENTORY.json`.

## Verification

- Compiler coverage: PASS, macOS 2,227 paths/46 roots and physical iOS 2,578
  paths/41 roots, zero uncovered.
- macOS bundle rebuild/audit: PASS with 46 indexed component notice files.
- Unsigned physical-iOS rebuild/audit: PASS with 41 indexed component notice
  files, plus all existing arm64/iOS 15/privacy/restoration/ROM/test/signing
  checks.
- Modifying a packaged nlohmann/json assembly: correctly rejected.
- Modifying a manifest assembly hash: correctly rejected.
- Strict package-rights mode: correctly returned 2 with 5 blockers.

No runtime code changed; no new runtime or physical-device claim is made.

## Remaining red gates

Secondary-notice discovery and second-person rights/license completeness review
remain open. Root-license choice, GPL corresponding-source assembly, DinoMod
permission, ROM-derived AOT rights, physical devices, progression, final
privacy, signing, and release artifacts are unchanged blockers.
