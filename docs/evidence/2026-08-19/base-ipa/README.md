# DinoMod-free base IPA

Date: 2026-08-19

DinoPad's base distribution was built in the isolated `build-ios-base` tree
with `DINOPAD_ENABLE_STATIC_RESTORATION=OFF`. Its private base AOT copy restores
the original 330 function definitions that the development-only DinoMod
dispatch generator renames; it does not alter the stable Restored build tree.

## Artifact record

- App: DinoPad 0.1.0 (build 1), arm64, iOS/iPadOS 15.0+
- Original audited IPA: `DinoPad-0.1.0-base-unsigned.ipa`
- Public-facing successor name: `DinoPad-0.1.1-prototype-only-unsigned.ipa`
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

This exact base IPA was not installed and no device container was modified.
The `v0.1.0` release therefore describes package/build evidence, not hands-on
physical acceptance of the Prototype-only artifact. It publishes the exact
matching source archive beside the IPA.

## Prototype-only disclosure refresh

A refreshed 0.1.1 build-2 candidate was generated after adding explicit disclosure
and setup guidance inside the app. DinoPad Home says `Prototype Mode only`,
states that DinoMod Enhanced is not included, and links to the README's private
Restored self-build instructions. The strengthened binary audit requires all
three disclosures and still proves that DinoMod code/data is absent.

- Candidate: `DinoPad-0.1.1-build.2-prototype-only-unsigned-candidate.ipa`
- Executable SHA-256:
  `5a142df20b9238d298cbd7f40e8dc927133bde9e1c914ed02e7bf83dd453e5fb`
- Candidate IPA SHA-256:
  `549891a732b2dbec54d8606577a22648ce8b67c419c05bc82feeed466b4e6c78`

This refreshed file is a local candidate, not a claim that the existing hosted
release asset has already been replaced.

## Second-session render correction

DinoPad 0.1.2 build 3 aligns SDL's iOS Metal view and RT64's swap chain at the
same native pixel scale. The iPad-class regression launches Restored, returns
to DinoPad Home, and launches Prototype in the same process. Both sessions
report `points=1376x1032 pixels=2752x2064 drawable=2752x2064`; the test fails
if SDL pixels and the Metal drawable diverge.

- Candidate: `DinoPad-0.1.2-build.3-prototype-only-unsigned-candidate.ipa`
- Executable SHA-256:
  `7a1e765bc9c9b48ad334064fbb0b393a7dffda90aed2827e7361d8cbe575e08c`
- Candidate IPA SHA-256:
  `c3042e9b121586112061a8856c8dcece6eba7090df951bc3c012e4f31c155153`

The signed Restored development build was installed in place on the physical
iPad as 0.1.2 build 3. Readback proved the private ROM, Restored and Prototype
saves, profile settings/controller layouts, and preference plist remained
byte-identical. The user then exercised the exact mode -> Home -> mode flow on
that iPad and confirmed the second session rendered at the normal scale. This
closed the candidate's final physical visual publication gate.
