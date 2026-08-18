# iOS privacy-manifest evidence

Date: 2026-08-17

Goal: bundle a valid, truthful app privacy manifest in iPhone/iPad builds and
make its expected declaration part of the physical-device package gate.

## Declared behavior

`PrivacyInfo.xcprivacy` declares:

- tracking: false;
- tracking domains: none;
- collected data types: none;
- file-timestamp reasons `C617.1` (app-container metadata) and `3B52.1`
  (user-selected document metadata);
- UserDefaults reason `CA92.1` (app-only preferences);
- system-boot-time reason `35F9.1` (elapsed-time and timer calculations).

These categories match the native Files import, app-container save/config/log
metadata, `NSUserDefaults` touch layout/settings, and runtime timing behavior.
The reason set was checked against Apple Developer documentation on 2026-08-17:

- https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
- https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons
- https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk

## Verification

- `plutil -lint` passes the tracked manifest.
- CMake places an exact copy at `DinoPad.app/PrivacyInfo.xcprivacy` for both
  physical-iOS and Simulator products.
- `scripts/check-package-safety.sh` requires the file and checks the exact
  no-tracking/no-collection/category/reason structure.
- The unsigned device build passes the integrated package gate.
- A copied device app with `NSPrivacyTracking=true` is rejected as a negative
  control.

This closes the missing app-resource gap only. A final release must still
re-audit the complete linked dependency set and generated Xcode privacy report;
this evidence does not claim App Store acceptance or replace third-party SDK
manifests where independently required.
