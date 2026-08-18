# Goal 31m: unsigned iOS archive and privacy-report preflight

Date: 2026-08-18

## Purpose

Prepare a ROM-free, unsigned local Xcode archive that Organizer can inspect for
the final aggregate privacy report, without claiming that report has been
generated or that the app is releasable.

## Archive result

The generated `DinoPad` target is an iOS application, but its ordinary Xcode
build settings resolve to `SKIP_INSTALL=YES` and an empty install path. A plain
`xcodebuild archive` therefore succeeded yet produced only a 4 KiB archive shell
with no application payload.

The following ignored, local-only command produced a 96 MiB archive containing
a 56 MiB `Products/Applications/DinoPad.app`:

```sh
xcodebuild archive \
  -project build-ios-device/DinoPad.xcodeproj \
  -scheme DinoPad \
  -configuration Release \
  -sdk iphoneos \
  -archivePath .goal-loop/DinoPadPrivacyAuditPackaged.xcarchive \
  CODE_SIGNING_ALLOWED=NO SKIP_INSTALL=NO INSTALL_PATH=/Applications
```

The archived app is arm64, targets iOS 15.0+, is unsigned, has no ROM/private
paths/test harness/signing residue, and contains the exact root
`PrivacyInfo.xcprivacy` declaration (no tracking or collected data; only the
known FileTimestamp, UserDefaults, and SystemBootTime required-reason entries).

These independent gates passed against the archived app:

```sh
scripts/check-package-safety.sh \
  .goal-loop/DinoPadPrivacyAuditPackaged.xcarchive/Products/Applications/DinoPad.app
python3 tools/validate_compiled_dependency_inventory.py --target ios-device
python3 tools/package_compiled_dependency_notices.py --target ios-device \
  --app .goal-loop/DinoPadPrivacyAuditPackaged.xcarchive/Products/Applications/DinoPad.app \
  --verify
```

The global archive overrides also install static-library byproducts beside the
app in `Products/Applications`. This archive is an Organizer input only, never
a distribution artifact.

## Organizer blocker

Xcode 26.6 opened its first-launch component chooser instead of Organizer. The
required iOS 26.5 platform component is not installed and Xcode requests an
8.52 GiB download; its optional predictive code-completion model requests an
additional 2 GiB. Neither was installed during this audit because that is a
material host change outside this goal.

Apple's documented aggregate-report workflow is to create an archive, open it
in Organizer, and choose **Generate Privacy Report**. No command-line report
generator was present in this Xcode installation. Consequently this evidence
does not claim an aggregate privacy report, transitive-SDK review, App Store
acceptance, signing, installation, or physical-device validation.

## Resume

On an authorized host with the iOS platform component installed, open the local
archive in Xcode Organizer, generate and retain the report, and reconcile it
with the exact final linked-SDK/API inventory before closing the P0 privacy
gate. Apple documents the Organizer workflow at
<https://developer.apple.com/documentation/bundleresources/describing-data-use-in-privacy-manifests>.
