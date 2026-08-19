# DinoPad license scope

DinoPad-owned source, scripts, patches, and documentation are distributed
under the GNU General Public License version 3.0 only (`GPL-3.0-only`), as set
out in the repository's root [`LICENSE`](../LICENSE).

This grant covers only material owned by DinoPad contributors. It does not
relicense third-party projects, game data, generated game code, screenshots,
trademarks, or other material whose rights belong to their respective owners.
Each dependency retains the terms recorded in its original license file and in
the repository's compiled-dependency inventory.

Public binaries based on GNU GPL components must be accompanied by the exact
corresponding DinoPad source snapshot, build scripts, maintained patches, and
license/notice corpus used for that binary. `scripts/package-release-source.sh`
creates and audits that matching source archive from a clean tagged commit.

DinoMod Enhanced is not covered by DinoPad's license. A public build containing
its converted code or data still requires a redistribution grant from its
rightsholders. The base/Prototype build excludes that integration.
