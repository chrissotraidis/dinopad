# Physical-device Phase 7 preflight

Date: 2026-08-17 (America/Chicago)

Commit under test: `e3ca0bf` plus the pending device-build script/documentation.

## Available external state

- `xcrun devicectl list devices` JSON result: zero known devices.
- Valid code-signing identities reported by the local keychain: zero.
- No device name, identifier, team identifier, certificate, provisioning profile,
  or signing material is recorded here.

This is a genuine external blocker for signing, installation, launch, and the
30-minute physical iPhone matrix. It does not block an unsigned device compile.

## Unsigned device build

`scripts/build-ios-device.sh` completed successfully against Xcode 26.6 and the
iPhoneOS 26.5 SDK. Its audited output is ignored at
`build-ios-device/Release-iphoneos/DinoPad.app`.

| Check | Result |
|---|---|
| Mach-O architectures | PASS: arm64 only |
| `LC_BUILD_VERSION` platform | PASS: IOS, minimum iOS 15.0, SDK 26.5 |
| Bundle ROM extensions | PASS: zero `.z64`, `.v64`, `.n64`, `.rom` files |
| Signing state in unsigned mode | PASS: no `_CodeSignature`, no `embedded.mobileprovision` |
| Bundle size | 60,334,080 bytes |
| Executable SHA-256 | `78836b9d989b459f34f5f9519d1c5e5b7cbd7c2d004d0025b5814654063e2dec` |

The script supports explicit personal-development signing through
`--team TEAM_ID`; it never stores or infers a team identifier. Optional Xcode
provisioning-network access requires the separate
`--allow-provisioning-updates` flag.

## Resume condition

When a supported iPhone and valid personal Apple Development identity are
available, rerun the read-only inventory, build with `--team`, install through
`xcrun devicectl`, and execute every Phase 7 acceptance criterion. Do not claim
physical orientation, audio, thermal, controller, save-update, or gameplay
evidence from this compile-only result.
