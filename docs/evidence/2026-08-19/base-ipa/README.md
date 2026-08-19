# DinoMod-free base IPA

Date: 2026-08-19

DinoPad's base distribution was built in the isolated `build-ios-base` tree
with `DINOPAD_ENABLE_STATIC_RESTORATION=OFF`. Its private base AOT copy restores
the original 330 function definitions that the development-only DinoMod
dispatch generator renames; it does not alter the stable Restored build tree.

## Artifact record

- App: DinoPad 0.1.0 (build 1), arm64, iOS/iPadOS 15.0+
- IPA: `DinoPad-0.1.0-build.1-base-unsigned-candidate.ipa`
- IPA size: 13,426,461 bytes
- IPA entries: 51, all under `Payload/DinoPad.app/`
- Executable SHA-256:
  `89917ef9251a390b978e9db32bff78768d0e40fc1549d2b18af2eb61498a898a`
- IPA SHA-256:
  `3f1b1d83052c2ed3b52b89ebb5f8befb7ed7894c1caba6babccd7636a66ac517`

The app and extracted IPA passed the physical-iOS package audit: arm64, iOS 15
minimum, unsigned, system-only runtime dependencies, test harness absent, exact
privacy manifest, complete compiler-derived primary notice corpus, and no ROM,
save, log, private path, credential, or provisioning material.

The strict base-distribution compliance gate passed. The app contains neither
`dinomod_restoration_data.nrm` nor the DinoMod/static-restoration integration
markers. The strict Restored gate remains separately red because the official
DinoMod 0.9.3 GitHub and Thunderstore packages publish no redistribution
license.

This IPA was not installed and no device container was modified. A final public
release still requires a clean `v0.1.0` tag so the release workflow can produce
the exact matching source archive beside it.
