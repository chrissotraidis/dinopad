#!/usr/bin/env python3
"""Generate static replacement/hook wrappers and rename original definitions."""

from __future__ import annotations

import argparse
import re
import struct
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Redirect:
    function_index: int
    section_vrom: int
    function_vram: int
    flags: int


def parse_mod_symbols(path: Path) -> tuple[list[Redirect], list[Redirect]]:
    data = path.read_bytes()
    magic, version = struct.unpack_from("<8sI", data, 0)
    if magic != b"N64RSYMS" or version != 1:
        raise ValueError("unsupported mod symbol file")
    offset = 12
    counts = struct.unpack_from("<10I", data, offset)
    offset += 40
    (sections, dependencies, imports, dependency_events, replacements,
     exports, callbacks, events, hooks, string_size) = counts
    offset += string_size
    function_count = 0
    for _ in range(sections):
        header = struct.unpack_from("<7I", data, offset)
        offset += 28
        function_count += header[5]
        offset += header[5] * 8 + header[6] * 16
    offset += dependencies * 12 + imports * 12 + dependency_events * 12
    replacement_list = [
        Redirect(*struct.unpack_from("<4I", data, offset + index * 16))
        for index in range(replacements)
    ]
    offset += replacements * 16 + exports * 12 + callbacks * 8 + events * 8
    hook_list = [
        Redirect(*struct.unpack_from("<4I", data, offset + index * 16))
        for index in range(hooks)
    ]
    offset += hooks * 16
    if offset != len(data):
        raise ValueError("mod symbol file size does not match its tables")
    for redirect in replacement_list + hook_list:
        if redirect.function_index >= function_count:
            raise ValueError("redirect function index is out of range")
    return replacement_list, hook_list


def parse_base_symbols(path: Path) -> dict[tuple[int, int], str]:
    text = path.read_text(encoding="utf-8")
    arrays: dict[str, list[tuple[str, int]]] = {}
    for match in re.finditer(
        r"static FuncEntry (\w+)_funcs\[\] = \{(.*?)\n\};", text, re.DOTALL
    ):
        arrays[match.group(1)] = [
            (name, int(offset, 16))
            for name, offset in re.findall(
                r"\.func = (\w+), \.offset = 0x([0-9A-Fa-f]+)", match.group(2)
            )
        ]
    result: dict[tuple[int, int], str] = {}
    section_pattern = re.compile(
        r"\.rom_addr = 0x([0-9A-Fa-f]+), \.ram_addr = 0x([0-9A-Fa-f]+),"
        r".*?\.funcs = (\w+)_funcs"
    )
    for rom_text, ram_text, array_name in section_pattern.findall(text):
        rom = int(rom_text, 16)
        ram = int(ram_text, 16)
        for name, offset in arrays[array_name]:
            result[(rom, ram + offset)] = name
    if not result:
        raise ValueError("no base function symbols found")
    return result


def rename_originals(source_roots: list[Path], names: list[str]) -> None:
    files: list[Path] = []
    for root in source_roots:
        files.extend(root.glob("*.c"))
        files.extend(root.glob("*.cpp"))
    for name in names:
        original = f"dinopad_original_{name}"
        definition = re.compile(rf"(RECOMP_FUNC void\s+){re.escape(name)}(\s*\()")
        renamed = re.compile(rf"RECOMP_FUNC void\s+{re.escape(original)}\s*\(")
        changed = 0
        existing = 0
        for path in files:
            text = path.read_text(encoding="utf-8")
            new_text, count = definition.subn(rf"\1{original}\2", text)
            if count:
                path.write_text(new_text, encoding="utf-8")
                changed += count
            existing += len(renamed.findall(new_text))
        if changed + existing == 0:
            raise ValueError(f"no original definition found for {name}")


def render(
    replacements: list[tuple[Redirect, str]], hooks: list[tuple[Redirect, str]]
) -> str:
    replacement_by_target: dict[str, int] = {}
    for redirect, target in replacements:
        if target in replacement_by_target:
            raise ValueError(f"duplicate replacement target {target}")
        replacement_by_target[target] = redirect.function_index

    slot_by_definition: dict[tuple[int, int, bool], int] = {}
    hooks_by_target: dict[str, tuple[list[int], list[int]]] = {}
    for redirect, target in hooks:
        at_return = bool(redirect.flags & 1)
        definition = (redirect.section_vrom, redirect.function_vram, at_return)
        slot = slot_by_definition.setdefault(definition, len(slot_by_definition))
        entry, returned = hooks_by_target.setdefault(target, ([], []))
        slots = returned if at_return else entry
        if slot not in slots:
            slots.append(slot)

    overlap = set(replacement_by_target) & set(hooks_by_target)
    if overlap:
        raise ValueError(f"replacement/hook target overlap: {sorted(overlap)}")

    targets = sorted(set(replacement_by_target) | set(hooks_by_target))
    mod_indices = sorted(
        set(replacement_by_target.values())
        | {redirect.function_index for redirect, _ in hooks}
    )
    lines = [
        "// Generated by tools/generate_static_dispatch.py. Do not edit.",
        '#include "recomp.h"',
        "",
        "extern void dinopad_static_run_hook(uint8_t*, recomp_context*, unsigned long);",
        "static int dinopad_static_dispatch_enabled = 0;",
        "void dinopad_static_dispatch_set_enabled(int enabled) {",
        "    dinopad_static_dispatch_enabled = enabled;",
        "}",
        "",
    ]
    for index in mod_indices:
        lines.append(f"void mod_func_{index}(uint8_t*, recomp_context*);")
    for target in targets:
        lines.append(f"void dinopad_original_{target}(uint8_t*, recomp_context*);")
    lines.append("")

    for target in targets:
        lines.append(f"void {target}(uint8_t* rdram, recomp_context* ctx) {{")
        lines.append("    if (!dinopad_static_dispatch_enabled) {")
        lines.append(f"        dinopad_original_{target}(rdram, ctx);")
        lines.append("        return;")
        lines.append("    }")
        if target in replacement_by_target:
            lines.append(f"    mod_func_{replacement_by_target[target]}(rdram, ctx);")
        else:
            entry, returned = hooks_by_target[target]
            for slot in entry:
                lines.append(f"    dinopad_static_run_hook(rdram, ctx, {slot});")
            lines.append(f"    dinopad_original_{target}(rdram, ctx);")
            for slot in returned:
                lines.append(f"    dinopad_static_run_hook(rdram, ctx, {slot});")
        lines.append("}")
        lines.append("")
    lines.append(
        f"// redirects: {len(replacement_by_target)} replacements, "
        f"{len(slot_by_definition)} hook slots, {len(targets)} wrappers"
    )
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("mod_symbols", type=Path)
    parser.add_argument("base_overlays", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("source_roots", nargs="+", type=Path)
    args = parser.parse_args()

    replacements, hooks = parse_mod_symbols(args.mod_symbols)
    base_symbols = parse_base_symbols(args.base_overlays)
    mapped_replacements = [(item, base_symbols[(item.section_vrom, item.function_vram)]) for item in replacements]
    mapped_hooks = [(item, base_symbols[(item.section_vrom, item.function_vram)]) for item in hooks]
    target_names = sorted({target for _, target in mapped_replacements + mapped_hooks})
    rename_originals(args.source_roots, target_names)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(render(mapped_replacements, mapped_hooks), encoding="utf-8")
    print(
        f"static-dispatch: replacements={len(replacements)} hooks={len(hooks)} "
        f"targets={len(target_names)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
