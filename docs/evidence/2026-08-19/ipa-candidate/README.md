# Unsigned IPA candidate

Date: 2026-08-19

The physical-iOS app was rebuilt unsigned with test harnesses disabled, then
packaged twice from the same audited input. Both deterministic package runs
produced the same SHA-256.

## Candidate record

- App: DinoPad 0.1.0 (build 1), arm64, iOS/iPadOS 15.0+
- IPA filename: `DinoPad-0.1.0-build.1-unsigned-candidate.ipa`
- IPA size: 51,753,016 bytes
- IPA entries: 52, all under `Payload/DinoPad.app/`
- App executable SHA-256:
  `7927bed6d2d7dc2eb874fc3cd0215108975a2f3b9061a46b63b07d04252e5a9a`
- IPA SHA-256:
  `9be9b85dc255f9c383ea1f47f555bfa8132e96ef7e3f92bd500f882a6e04abee`

The app and extracted IPA payload passed `check-package-safety.sh`: physical
iOS arm64, iOS 15 minimum, unsigned, system-only dependencies, test harness
absent, exact privacy manifest and compiled notices, audited restoration data,
and no ROM, save, log, private path, credential, or provisioning material.

The candidate was not installed and no device container was modified during
this packaging run. It remains a private candidate. `package-ios.sh --release`
correctly fails closed on the root-license, GPL corresponding-source, DinoMod
permission, ROM-derived AOT rights, and final notice-review gates.
