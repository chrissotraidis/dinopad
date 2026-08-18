# Goal 31l: unsigned physical-iOS rebuild and package audit

Date: 2026-08-18T07:32:09Z

Target: unsigned physical-iOS (`iphoneos`) arm64 application

Result: **PASS — package preparation only**

## Purpose

Rebuild the unsigned device product after compiler-derived notice assembly
changed package inputs, then verify the current app has the expected release
engineering boundary. This does not install or run the app on a physical device
and is not release approval.

## Preconditions

- Disk free before the build: 25 GiB (the project gate is 20 GiB).
- No booted Simulator and no DinoPad process.
- Physical devices: none discovered.
- Valid code-signing identities: none discovered.

## Commands and outcomes

```sh
scripts/build-ios-device.sh
scripts/check-package-safety.sh build-ios-device/Release-iphoneos/DinoPad.app
python3 tools/validate_compiled_dependency_inventory.py --target ios-device
python3 tools/package_compiled_dependency_notices.py \
  --target ios-device --app build-ios-device/Release-iphoneos/DinoPad.app --verify
python3 tools/validate_package_rights_inventory.py
python3 tools/validate_package_rights_inventory.py --require-release-ready
git diff --check
scripts/check-repo-safety.sh
```

- The 58 MiB app is arm64-only, `platform IOS`, and iOS 15.0+.
- The unsigned app has no `_CodeSignature` or provisioning profile.
- The fail-closed package audit passed: no ROM/save/log/private paths, no
  Simulator harness selectors/keys/fixtures, system runtime dependencies only,
  exact privacy manifest, and exact sanitized restoration data.
- The compiler graph covered 2,578 source/header paths across 41 device-target
  components, with zero uncovered paths. All 41 package notices, including six
  mechanically assembled inline-primary notices, verified byte-for-byte.
- Repository safety and the 26-patch lock passed.
- Strict rights validation returned its expected exit status 2. Its five
  blockers (root license, GPL corresponding source, DinoMod permission,
  ROM-derived AOT rights, and secondary-notice legal review) remain release
  stops.

## Not verified

Physical install, ROM import, orientation, touch/controller/audio/lifecycle,
thermal/memory behavior, save/update persistence, diagnostics sharing, and
progression require a connected supported device and valid Apple Development
identity/provision.
