# DinoPad release checklist

Last updated: 2026-08-19

This is the operational gate for any public DinoPad source archive, app bundle,
IPA, download, or release announcement. A successful build, package audit, or
Simulator playtest is not release approval. There is no override flag: do not
package or publish while any P0 gate below is red.

## Current gate status

| Gate | Priority | Status | Closure evidence |
|---|---|---|---|
| README and rights boundary match verified behavior | P0 | Green | [`README.md`](../README.md), [`RIGHTS_AND_LICENSES.md`](RIGHTS_AND_LICENSES.md) |
| macOS and iPhone/iPad Simulator builds and smokes | P1 | Green | Packaged macOS launcher, fresh keyboard defaults, fullscreen, and bounded memory smoke are current. [`STATUS.md`](STATUS.md), [`PLAYTEST_MATRIX.md`](PLAYTEST_MATRIX.md) |
| Physical iPhone product matrix | P0 | **Red** | Signed in-place install and Restored gameplay are user-observed; the recorded 30-minute audio/controller/lifecycle/thermal/memory/save/update matrix is incomplete. |
| Physical iPad product matrix | P0 | **Red** | Signed in-place install, Restored play, Xbox-controller input/reconnect, and current screenshots are user-observed; the complete recorded 60-minute tablet/audio/lifecycle/thermal/memory/update matrix is incomplete. |
| Restored start-to-credits and chapter fixture matrix | P0 | **Red** | One complete physical-device playthrough and chapter-boundary evidence required. |
| DinoPad-owned root license decision | P0 | **Red** | Root license file and scope decision required. |
| Complete shipped third-party licenses/notices | P0 | **Red** | Every 46/41 compiler-derived macOS/iOS root has a standalone or mechanically assembled inline-primary package notice; secondary and second-person legal review remain. [`COMPILED_DEPENDENCY_INVENTORY.json`](COMPILED_DEPENDENCY_INVENTORY.json) |
| Written DinoMod redistribution permission or removal | P0 | **Red** | Written permission/compatible published license, or a release configuration with all restricted integration removed, required. |
| Compiled game-AOT rights | P0 | **Red** | ROM-free binaries still contain private generated AOT. Rights determination or source-only local generation required. |
| App privacy manifest | P1 | Green | Exact packaged manifest and negative-control audit in [`privacy-manifest`](evidence/2026-08-17/privacy-manifest/). |
| Final transitive privacy report | P0 | **Red** | Goals 31m/31n produce a clean unsigned Organizer-input archive and pass its local app gates, but Xcode Organizer cannot open on this host until its 8.52 GiB iOS platform component is installed. Final Xcode privacy report and exact linked-SDK/API review remain required. |
| ROM-free unsigned IPA and clean self-sign install | P0 | **Red** | A deterministic ROM-free unsigned candidate is locally audited; publication, exact self-sign install/relaunch, and update evidence remain required. [`ipa-candidate`](evidence/2026-08-19/ipa-candidate/) |
| Source tag, artifact checksum, and source/artifact match | P0 | **Red** | Immutable tag, SHA-256, and reproducibility record required. |

The current project state is **not releasable**. Green engineering rows do not
offset a red P0 row.

## Stop conditions

Stop release work before producing or publishing a release archive or public
candidate if any of these is true:

- any P0 row above is red;
- the intended release commit is not clean and fully reviewed;
- the package would contain a ROM, save, private fixture, generated prohibited
  game asset, log, personal path, credential, signing identity, certificate,
  private key, provisioning profile, or executable mod payload;
- the source tag, packaged commit, and recorded checksum do not match;
- rights or privacy conclusions are inferred from a technical audit instead of
  being explicitly established;
- compiled ROM-derived AOT or a packaged font/art resource lacks an affirmative
  redistribution basis;
- the exact final artifact has not been installed and exercised through the
  documented self-signing workflow.

Do not create a convenience switch, environment variable, or approval note that
bypasses these stop conditions.

## Source release gate

- [ ] Record the intended commit and confirm `git status --short --branch` is
  clean.
- [ ] Review the complete commit diff and run `git diff --check`.
- [ ] Run `scripts/check-repo-safety.sh` and resolve every finding.
- [ ] Reproduce source setup with `scripts/bootstrap.sh` from clean pinned
  inputs; it verifies exact commits, disables push URLs, applies patches, and
  runs repository safety.
- [ ] Verify every pin in [`dependencies.lock.json`](../dependencies.lock.json)
  and every patch/checksum in [`UPSTREAM.md`](UPSTREAM.md).
- [ ] Confirm README, status, build, test, playtest, rights, and release claims
  describe only reproduced evidence.
- [ ] Search tracked text and images for personal paths, user names, private
  device identifiers, private logs, credentials, and game data.
- [ ] Add the root license decision and complete source-distribution notices.
- [ ] Confirm GPL corresponding-source and build-script obligations are met for
  the exact source release.
- [ ] Verify DinoMod redistribution is authorized for the exact material being
  published, or remove that material and its release claims.
- [ ] Create the source tag only after all source gates pass, then record the tag
  object and source archive SHA-256.

## Build matrix gate

Run from the intended clean release commit and retain command output:

```sh
scripts/build-macos-app.sh
scripts/check-macos-package-safety.sh build-macos/DinoPad.app
scripts/build-ios-simulator.sh
scripts/build-ios-device.sh
scripts/check-package-safety.sh build-ios-device/Release-iphoneos/DinoPad.app
```

- [ ] macOS output is native arm64 and passes its ROM/private-output audit.
- [ ] Simulator output is arm64, ROM-free, and used only for the documented
  iPhone/iPad regression matrix.
- [ ] Physical output is arm64 `iphoneos`, iOS 15+, and compiled with
  `DINOPAD_ENABLE_TEST_HARNESS=OFF`.
- [ ] The physical executable has only expected system runtime dependencies,
  no unexpected rpath, and no test selectors, keys, fixtures, or personal paths.
- [ ] The app-root `PrivacyInfo.xcprivacy` is byte-identical to the tracked file
  and passes the exact package audit.
- [ ] The final release build preserves the Restored/Prototype save and config
  namespaces and does not enable writable mod discovery or runtime code writes.

## Physical iPhone gate

- [ ] Build and sign locally without committing a team identifier, identity, or
  provisioning material.
- [ ] Install in place with bundle identifier `com.chrissotraidis.dinopad`; do
  not remove the existing data container.
- [ ] Exercise setup, valid/invalid ROM import, home, both profile paths, menu,
  settings, diagnostics, layout editing, and ROM replacement/removal.
- [ ] Verify physical landscape/orientation and safe areas, every touch input,
  simultaneous touches, controller connect/disconnect when available, and
  utility-menu access.
- [ ] Listen through title, file selection, File 1A transition, Mario's House,
  sustained music, and representative effects on speaker and available
  headphone/Bluetooth routes; check clipping, latency, and interruption recovery.
- [ ] Exercise background/foreground, audio interruption, controller reconnect,
  clean terminate/relaunch, saves, and diagnostics sharing.
- [ ] Complete at least 30 minutes of gameplay with no severe thermal
  throttling, memory termination, recurring crash, or growing audio latency.
- [ ] Install an update in place and prove the imported ROM, profile settings,
  and saves survive without copying a whole app-data container.
- [ ] Record sanitized device class, OS, duration, observations, crash review,
  and artifact SHA-256 without committing private device data.

## Physical iPad gate

- [ ] Repeat the full physical iPhone matrix on a supported iPad.
- [ ] Verify tablet-specific safe areas, layout persistence, larger menu/sheet
  presentation, orientation, and external keyboard when available.
- [ ] Complete at least 60 minutes of cumulative play with touch and
  controller-centric routes, audible audio, saves, and menu access.
- [ ] Verify no memory termination or severe thermal regression.
- [ ] Install an update in place and prove the imported ROM and both profiles'
  settings/saves survive.
- [ ] Record sanitized device class, OS, duration, observations, crash review,
  and artifact SHA-256 without committing private device data.

## Progression and stability gate

- [ ] Extend [`PROGRESSION_FIXTURES.json`](PROGRESSION_FIXTURES.json) beyond the
  single early-game fixture to meaningful chapter boundaries; keep fixture
  files private and ignored.
- [ ] Run every fixture's critical transition on the intended release build and
  record pass/fail evidence.
- [ ] Exercise known DinoMod progression repairs.
- [ ] Complete one human Restored start-to-credits playthrough on a physical
  Apple device. Automation and early-game soaks cannot substitute for it.
- [ ] Resolve every save-corrupting defect and every recurring crash lacking a
  recovery path.
- [ ] Complete longer soak, repeated lifecycle, repeated import, interrupted
  write, and corruption-recovery coverage.
- [ ] Keep Prototype claims limited to verified smoke behavior; completion is
  not required for that archival mode.

## Rights, notices, and privacy gate

- [ ] Decide and document the license and copyright scope for DinoPad-owned work.
- [ ] Satisfy Dino Recompiled GPL source and notice obligations for the exact
  combined release.
- [ ] Inventory every shipped direct and transitive dependency at its exact pin;
  include its required license, attribution, and notice text.
- [ ] Run `python3 tools/validate_compiled_dependency_inventory.py`; investigate
  every newly uncovered or stale macOS compiler dependency before packaging.
- [ ] Review both target inventories for secondary notices and obtain
  second-person legal/completeness review of the mechanically assembled corpus.
- [ ] Run
  `python3 tools/validate_package_rights_inventory.py --require-release-ready`
  against the exact macOS product; any nonzero result is a release stop.
- [ ] Obtain an explicit rights determination for compiled ROM-derived AOT or
  limit delivery to source-only local generation. Keep the selected-resource
  inventory exact if final package contents change.
- [ ] Obtain and archive written DinoMod integration/redistribution permission,
  or remove all material and claims requiring it.
- [ ] Preserve the ROM/game-data prohibition, non-affiliation language, and
  user-supplied-game-data instructions in the README and package.
- [ ] Generate the final Xcode privacy report, review required-reason API usage
  across the exact linked dependencies, and retain independently required SDK
  manifests. An audit-only unsigned archive can be created with
  `CODE_SIGNING_ALLOWED=NO`; use a prepared Xcode Organizer host and do not
  treat that archive as distributable.
- [ ] Confirm the privacy manifest and public disclosure match the final binary's
  real collection, tracking, and API behavior.

## Unsigned IPA package gate

Begin this section only after every P0 prerequisite above is green.

- [ ] Build a fresh device app with test harnesses off from the tagged commit.
- [ ] Bundle only reviewed app resources, the privacy manifest, complete notices,
  rights statement, and final self-signing/install guide.
- [ ] Remove `_CodeSignature`, `embedded.mobileprovision`, entitlements copied
  from local signing, and every maintainer-specific signing artifact.
- [ ] Produce a deterministic unsigned IPA with a documented command and stable
  file order/timestamps.
- [ ] Run `scripts/check-package-safety.sh` on the exact packaged app and perform
  a file-by-file archive review.
- [ ] Confirm no ROM, save, generated prohibited asset, private fixture/log/path,
  credential, profile, identity, certificate, or private key is present.
- [ ] Record the IPA SHA-256 and prove its binary/source metadata match the
  source tag.
- [ ] Self-sign and clean-install the exact published bytes using the documented
  consumer workflow; do not validate a separately rebuilt artifact.
- [ ] Relaunch, save, update in place, and confirm imported ROM/profile data
  preservation on both physical device classes.
- [ ] Publish only after a final second-person rights, package-content, claims,
  checksum, and link review.

## Release record

Copy this template into the release evidence directory:

```text
Version:
Source tag:
Commit:
Source archive SHA-256:
IPA SHA-256:
Build toolchain:
Package audit result:
Privacy report result:
Rights/notices reviewer and date:
DinoMod permission reference or removal proof:
Physical iPhone / OS / duration:
Physical iPad / OS / duration:
Start-to-credits device / duration:
Clean self-sign install result:
Update-in-place preservation result:
Known limitations:
Evidence paths:
```

## Current blockers

As of 2026-08-19, signed development builds have been installed in place on the
user's iPhone and iPad, and Restored gameplay plus iPad Xbox-controller use have
been observed without clearing mobile app data. That is meaningful progress,
but it does not close the formal physical matrices or start-to-credits gate.
The root license decision, final notice/legal review, transitive privacy report,
DinoMod redistribution permission, and compiled game-AOT rights also remain
unresolved. No source or binary release is authorized by this checklist's
existence.
