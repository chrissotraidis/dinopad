#!/usr/bin/env python3
"""Verify that every linked N64Recomp AOT entry point is 16-byte aligned.

N64ModernRuntime's arm64 replacement trampoline overwrites 16 bytes at the
start of a recompiled function. A four-byte leaf function followed immediately
by another generated function caused the first full DinoMod load to corrupt the
second entry point. This check makes that build invariant explicit.
"""

from __future__ import annotations

import argparse
import re
import subprocess
from pathlib import Path


DECLARATION = re.compile(
    r"^\s*void\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(uint8_t\s*\*\s*rdram,\s*"
    r"recomp_context\s*\*\s*ctx\s*\)\s*;"
)
NM_SYMBOL = re.compile(
    r"^([0-9a-fA-F]+)\s+\([^)]*\)\s+weak external\s+(_\S+)$"
)


def declared_functions(headers: list[Path]) -> set[str]:
    names: set[str] = set()
    for header in headers:
        for line in header.read_text(encoding="utf-8").splitlines():
            match = DECLARATION.match(line)
            if match:
                names.add(match.group(1))
    return names


def linked_weak_symbols(binary: Path) -> dict[str, int]:
    result = subprocess.run(
        ["nm", "-nm", str(binary)],
        check=True,
        capture_output=True,
        text=True,
    )
    symbols: dict[str, int] = {}
    for line in result.stdout.splitlines():
        match = NM_SYMBOL.match(line)
        if match:
            # Mach-O nm prefixes C symbols with one underscore.
            symbols[match.group(2)[1:]] = int(match.group(1), 16)
    return symbols


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("binary", type=Path)
    parser.add_argument("headers", nargs="+", type=Path)
    args = parser.parse_args()

    names = declared_functions(args.headers)
    symbols = linked_weak_symbols(args.binary)
    missing = sorted(names - symbols.keys())
    misaligned = sorted(
        (name, symbols[name]) for name in names & symbols.keys()
        if symbols[name] % 16 != 0
    )

    for name, address in misaligned:
        print(f"MISALIGNED: 0x{address:016x} {name}")

    checked = len(names) - len(missing)
    print(
        f"patchable-aot: checked={checked} native_overrides={len(missing)} "
        f"misaligned={len(misaligned)} alignment=16"
    )
    # Declarations absent from the weak-symbol table are intentionally
    # interposed by native runtime implementations and are not trampoline
    # targets in the generated code segment.
    return 1 if not checked or misaligned else 0


if __name__ == "__main__":
    raise SystemExit(main())
