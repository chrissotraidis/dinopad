#!/usr/bin/env bash
# Produce an isolated base-game AOT tree from the private Restored development
# tree by undoing only DinoMod's generated dispatch renames.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT/generated/aot"
DESTINATION="$ROOT/generated/aot-base"
DISPATCH="$ROOT/generated/restoration/dinomod_static_dispatch.c"

[[ -d "$SOURCE/RecompiledFuncs" && -d "$SOURCE/RecompiledPatches" ]] || {
    echo "ERROR: private base AOT is missing; run scripts/generate-base.sh" >&2
    exit 1
}
[[ -f "$DISPATCH" ]] || {
    echo "ERROR: restoration dispatch map is missing; run scripts/generate-restoration.sh" >&2
    exit 1
}

rm -rf "$DESTINATION"
mkdir -p "$DESTINATION"
rsync -a "$SOURCE/" "$DESTINATION/"
python3 "$ROOT/tools/restore_base_aot_names.py" \
    "$DISPATCH" \
    "$DESTINATION/RecompiledFuncs" \
    "$DESTINATION/RecompiledPatches"

if rg -l 'dinopad_original_|mod_func_[0-9]+' \
        "$DESTINATION/RecompiledFuncs" "$DESTINATION/RecompiledPatches" | grep -q .; then
    echo "ERROR: base AOT copy still contains restoration dispatch symbols" >&2
    exit 1
fi
echo "Isolated base AOT ready: $DESTINATION"
