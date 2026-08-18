# DinoPad rights and licensing boundary

Last updated: 2026-08-18

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
| Dino Recompiled | v0.3.0 / `725b2ede9cacc57968e0a028efed8df9235ba483` | Upstream `COPYING` is GNU GPL version 3. |
| DinoMod Enhanced Recompiled | v0.9.3 / `d79e86be2304cba75216b0b98e9fb53ee99b7500` | No conventional redistribution license is declared at the pin; public integration is blocked pending written permission or a compatible published license. |
| PaperPad | `644945d4bc4facbbd8ecda8cdfd37ae64e7993fa` | Reference implementation with its own multi-project rights boundary; DinoPad does not copy Paper Mario game code, art, or branding. |
| SDL2 | release-2.32.10 / `5d249570393f7a37e037abf22cd6012a4cc56a71` | zlib license in upstream `LICENSE.txt`. |
| FreeType | VER-2-13-3 / `42608f77f20749dd6ddc9e0536788eaad70ea4b5` | FreeType License in upstream `LICENSE.TXT`; statically linked into macOS only with optional external dependencies disabled. |

Exact recursive pins are recorded in
[`dependencies.lock.json`](../dependencies.lock.json), and the maintained patch
inventory is in [`UPSTREAM.md`](UPSTREAM.md). Those files are engineering
inventories, not substitutes for the original license and notice files.

The repository currently has no root license file or complete assembled
third-party notice set. That absence is a release blocker. It must not be read
as a grant to redistribute DinoPad-owned material, and it does not remove GPL or
other obligations attached to incorporated upstream work.

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

No public DinoPad package exists. Before publishing source or a binary release,
the project must at minimum:

1. determine and state the license for DinoPad-owned work;
2. satisfy Dino Recompiled's GPL source and notice obligations;
3. collect the exact required license/notice files for every shipped dependency;
4. obtain and record DinoMod redistribution permission or remove all material
   requiring it;
5. complete physical-device and progression gates;
6. prove the package contains no ROM, save, generated prohibited asset, private
   log, path, signing identity, or provisioning profile;
7. tie the artifact and SHA-256 checksum to a matching source tag.

The operational release gate is [`RELEASE_CHECKLIST.md`](RELEASE_CHECKLIST.md);
the product requirements remain in
[`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md). Neither document authorizes
distribution while a required gate remains open.
