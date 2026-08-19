#!/usr/bin/env python3
"""Undo DinoMod dispatch renames in a copied private base-AOT tree."""

from __future__ import annotations

import argparse
import pathlib
import re


DECLARATION = re.compile(
    r"^void dinopad_original_([A-Za-z0-9_]+)\(uint8_t\*, recomp_context\*\);$",
    re.MULTILINE,
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("dispatch", type=pathlib.Path)
    parser.add_argument("roots", nargs="+", type=pathlib.Path)
    args = parser.parse_args()

    names = sorted(set(DECLARATION.findall(args.dispatch.read_text(encoding="utf-8"))))
    if not names:
        raise ValueError("dispatch contains no renamed base functions")

    files: list[pathlib.Path] = []
    for root in args.roots:
        files.extend(root.glob("*.c"))
        files.extend(root.glob("*.cpp"))

    restored = 0
    for name in names:
        renamed = re.compile(
            rf"(RECOMP_FUNC void\s+)dinopad_original_{re.escape(name)}(\s*\()"
        )
        count = 0
        for path in files:
            source = path.read_text(encoding="utf-8")
            updated, replacements = renamed.subn(rf"\1{name}\2", source)
            if replacements:
                path.write_text(updated, encoding="utf-8")
                count += replacements
        if count < 1:
            raise ValueError(f"renamed definition is missing for {name}")
        restored += count

    leftovers = [
        str(path)
        for path in files
        if "dinopad_original_" in path.read_text(encoding="utf-8")
    ]
    if leftovers:
        raise ValueError(f"renamed definitions remain in: {leftovers}")
    print(f"base-aot: restored {restored} original function names in copied tree")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError) as exc:
        print(f"ERROR: {exc}")
        raise SystemExit(1)
