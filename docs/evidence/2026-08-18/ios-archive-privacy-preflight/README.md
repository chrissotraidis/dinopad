# Goals 31m/31n: unsigned iOS archive and privacy-report preflight

Date: 2026-08-18

## Purpose

Prepare a ROM-free, unsigned local Xcode archive that Organizer can inspect for
the final aggregate privacy report, without claiming that report has been
generated or that the app is releasable.

## Archive result

The generated `DinoPad` target is an iOS application. CMake now marks that
target, and only that target, installable in Xcode with `SKIP_INSTALL=NO` and
`INSTALL_PATH=/Applications`. Its static-library dependencies retain their
normal non-installable setting.

The following ignored, local-only command produced a clean 56 MiB archive
containing exactly one `Products/Applications/DinoPad.app`:

```sh
xcodebuild archive \
  -project build-ios-device/DinoPad.xcodeproj \
  -scheme DinoPad \
  -configuration Release \
  -sdk iphoneos \
  -archivePath .goal-loop/DinoPadPrivacyAuditTargetScoped.xcarchive \
  CODE_SIGNING_ALLOWED=NO
```

The archived app is arm64, targets iOS 15.0+, is unsigned, has no ROM/private
paths/test harness/signing residue, and contains the exact root
`PrivacyInfo.xcprivacy` declaration (no tracking or collected data; only the
known FileTimestamp, UserDefaults, and SystemBootTime required-reason entries).

These independent gates passed against the archived app:

```sh
scripts/check-package-safety.sh \
  .goal-loop/DinoPadPrivacyAuditTargetScoped.xcarchive/Products/Applications/DinoPad.app
python3 tools/validate_compiled_dependency_inventory.py --target ios-device
python3 tools/package_compiled_dependency_notices.py --target ios-device \
  --app .goal-loop/DinoPadPrivacyAuditTargetScoped.xcarchive/Products/Applications/DinoPad.app \
  --verify
```

The ordinary unsigned device build also remains green. Its build script passes
`SKIP_INSTALL=YES` so the development app remains at
`build-ios-device/Release-iphoneos/DinoPad.app`; it also removes only a stale
archive-generated symlink at that generated output path before rebuilding.
The exact archive-then-normal-build sequence was verified: the archive created
the symlink, the script replaced it with a real app directory, and its full
unsigned device package gate passed afterward.
This archive is an Organizer input only, never a distribution artifact.

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
