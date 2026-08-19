# DinoPad rights and licensing boundary

Last updated: 2026-08-19

DinoPad is an independent, unofficial source-port project. It is not affiliated
with or endorsed by Nintendo, Rare, Microsoft, Dinosaur Planet Recompiled,
DinoMod Enhanced, PaperPad, or their contributors.

This document records the repository's current engineering boundary. It is not
legal advice and does not replace any dependency's license text.

## Game data and private output

The tracked repository does not distribute a Dinosaur Planet ROM, extracted
game asset, audio, model, texture, save, generated playable game source, private
fixture, or playable ROM-derived archive. Users must supply their own legally
obtained supported game data locally.

Do not commit, bundle, upload, attach to CI, link to, or request those files.
Private generation and runtime output belongs only in ignored locations such as
`generated/`, app containers, and local evidence scratch directories.

The executables are technically ROM-free but statically link AOT generated from
the user-supplied game program. That is a disclosed copyright-risk question,
not an unidentified dependency license. The upstream Dinosaur Planet:
Recompiled project publicly distributes the same form of static-recompilation
binary while requiring users to supply the original game. DinoPad records this
as an advisory and follows the same no-ROM/no-game-assets boundary; this
engineering classification is not legal advice.

Documentation screenshots show compatibility behavior captured from a locally
supplied game copy. They are evidence, not playable game data. Game names,
characters, copyrights, and trademarks remain the property of their respective
owners.

## Source and dependency rights

Every pinned source and transitive dependency retains its own license and rights
boundary. The complete combined tree must not be described as carrying one
blanket license.

Current top-level inventory:

| Component | Pin | Recorded license state |
|---|---|---|
| DinoPad-owned work | Current repository | GNU GPL version 3.0 only; scope in [`LICENSE_SCOPE.md`](LICENSE_SCOPE.md). |
| Dino Recompiled | v0.3.0 / `725b2ede9cacc57968e0a028efed8df9235ba483` | Upstream `COPYING` is GNU GPL version 3. |
| DinoMod Enhanced Recompiled | v0.9.3 / `d79e86be2304cba75216b0b98e9fb53ee99b7500` | No conventional redistribution license is declared at the pin; public integration is blocked pending written permission or a compatible published license. |
| PaperPad | `644945d4bc4facbbd8ecda8cdfd37ae64e7993fa` | Reference implementation with its own multi-project rights boundary; DinoPad does not copy Paper Mario game code, art, or branding. |
| SDL2 | release-2.32.10 / `5d249570393f7a37e037abf22cd6012a4cc56a71` | zlib license in upstream `LICENSE.txt`. |
| FreeType | VER-2-13-3 / `42608f77f20749dd6ddc9e0536788eaad70ea4b5` | FreeType License in upstream `LICENSE.TXT`; statically linked into macOS only with optional external dependencies disabled. |

Exact recursive pins are recorded in
[`dependencies.lock.json`](../dependencies.lock.json), and the maintained patch
inventory is in [`UPSTREAM.md`](UPSTREAM.md). Those files are engineering
inventories, not substitutes for the original license and notice files.

The package-specific engineering inventory is
[`PACKAGE_RIGHTS_INVENTORY.json`](PACKAGE_RIGHTS_INVENTORY.json), validated by
`tools/validate_package_rights_inventory.py`. Its first macOS pass proves exact
pins/license-text hashes for 17 directly linked components and exact hashes for
8 selected packaged resources. A second compiler-derived inventory maps all
2,187 current macOS `ref/` source/header dependencies to 45 deepest-prefix
ownership roots; physical iOS maps 2,578 paths to 41 roots. The apps index exact
copies of the applicable standalone license files plus mechanically assembled
inline-primary notices for all six target-present inline roots. Every 45/41
component root therefore has a package entry. The package removes DinoFont, Noto Emoji, the
unproven game logo, and Krazoa artwork; its remaining Lato faces have exact
attribution and SIL OFL 1.1 text in the app. These engineering inventories do
not claim legal advice. The repository now has a GPL-3.0-only root license, a
matching tracked-source archive workflow, and complete automated primary-notice
coverage for both products. Additional human notice review and the generated
game-AOT question are disclosed advisories rather than fabricated missing
licenses. Strict release mode passes for the audited base build and fails for a
Restored build only on DinoMod redistribution permission.

## DinoMod restoration boundary

Technical development has proven static arm64 restoration dispatch and a
sanitized non-executable data package. That proof does not grant permission to
redistribute DinoMod code or data. Until the permission gate is closed:

- do not publish a Restored DinoPad binary;
- do not commit the generated restoration package or converted output;
- do not describe the integration as licensed or release-ready;
- keep Prototype and Restored technical evidence distinct from redistribution
  authorization.

See [`DINOMOD_INTEGRATION.md`](DINOMOD_INTEGRATION.md) for the exact technical
and permission status.

## Release packages

DinoPad 0.1.0 publishes the audited DinoMod-free base IPA and matching source
archive. For that release and every later artifact, the project must:

1. build from the exact tagged GPL-3.0-only source snapshot;
2. publish the matching source archive, build scripts, patches, pins, license,
   and compiled notice corpus beside the binary;
3. for Restored Adventure, obtain and record DinoMod redistribution permission;
   otherwise use the audited base build that excludes all DinoMod material;
4. complete the selected release's physical-device and progression gates;
5. prove the package contains no ROM, save, generated prohibited asset, private
   log, path, signing identity, or provisioning profile;
6. tie the artifact and SHA-256 checksum to the matching source tag.

The operational release gate is [`RELEASE_CHECKLIST.md`](RELEASE_CHECKLIST.md);
the product requirements remain in
[`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md). Neither document authorizes
distribution while a required gate remains open.
