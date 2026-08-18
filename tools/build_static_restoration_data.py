#!/usr/bin/env python3
"""Build a deterministic DinoMod data package with all MIPS code removed."""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
import zipfile
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class ModSection:
    file_offset: int
    vram: int
    rom_size: int
    functions: tuple[tuple[int, int], ...]


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def parse_mod_symbols(data: bytes) -> list[ModSection]:
    if len(data) < 52:
        raise ValueError("mod symbol file is truncated")
    magic, version = struct.unpack_from("<8sI", data)
    if magic != b"N64RSYMS" or version != 1:
        raise ValueError("only N64RSYMS version 1 is supported")

    counts = struct.unpack_from("<10I", data, 12)
    (section_count, dependency_count, import_count, dependency_event_count,
     replacement_count, export_count, callback_count, event_count, hook_count,
     string_size) = counts
    offset = 52 + string_size
    if offset > len(data):
        raise ValueError("mod symbol string table is truncated")

    sections: list[ModSection] = []
    function_count = 0
    for _ in range(section_count):
        if offset + 28 > len(data):
            raise ValueError("mod section table is truncated")
        _, file_offset, vram, rom_size, _, num_funcs, num_relocs = (
            struct.unpack_from("<7I", data, offset)
        )
        offset += 28
        if offset + num_funcs * 8 + num_relocs * 16 > len(data):
            raise ValueError("mod function or relocation table is truncated")
        functions = tuple(
            struct.unpack_from("<2I", data, offset + index * 8)
            for index in range(num_funcs)
        )
        for function_offset, function_size in functions:
            if function_offset + function_size > rom_size:
                raise ValueError("mod function extends beyond its section")
        offset += num_funcs * 8 + num_relocs * 16
        function_count += num_funcs
        sections.append(ModSection(file_offset, vram, rom_size, functions))

    table_bytes = (
        dependency_count * 12
        + import_count * 12
        + dependency_event_count * 12
        + replacement_count * 16
        + export_count * 12
        + callback_count * 8
        + event_count * 8
        + hook_count * 16
    )
    offset += table_bytes
    if offset != len(data):
        raise ValueError("mod symbol file size does not match its tables")
    if function_count == 0:
        raise ValueError("mod symbol file contains no functions")
    return sections


def parse_executable_segments(data: bytes) -> list[tuple[int, int]]:
    if len(data) < 52 or data[:4] != b"\x7fELF":
        raise ValueError("mod ELF is missing or invalid")
    if data[4] != 1 or data[5] != 2:
        raise ValueError("mod ELF must be 32-bit big-endian")

    header = struct.unpack_from(">16sHHIIIIIHHHHHH", data)
    _, elf_type, machine, _, _, program_offset, _, _, _, program_size, \
        program_count, _, _, _ = header
    if elf_type != 2 or machine != 8:
        raise ValueError("mod ELF must be a MIPS executable")
    if program_size != 32:
        raise ValueError("unexpected ELF program-header size")

    segments: list[tuple[int, int]] = []
    for index in range(program_count):
        offset = program_offset + index * program_size
        if offset + program_size > len(data):
            raise ValueError("ELF program-header table is truncated")
        segment_type, _, vram, _, file_size, _, flags, _ = struct.unpack_from(
            ">8I", data, offset
        )
        if segment_type == 1 and flags & 1 and file_size:
            segments.append((vram, file_size))
    if not segments:
        raise ValueError("mod ELF has no executable load segment")
    return segments


def map_code_ranges(
    sections: list[ModSection], segments: list[tuple[int, int]], binary_size: int
) -> list[tuple[int, int]]:
    ranges: list[tuple[int, int]] = []
    for vram, size in segments:
        matches = [
            section for section in sections
            if section.vram <= vram
            and vram + size <= section.vram + section.rom_size
        ]
        if len(matches) != 1:
            raise ValueError("executable ELF segment does not map to one mod section")
        section = matches[0]
        start = section.file_offset + (vram - section.vram)
        end = start + size
        if end > binary_size:
            raise ValueError("executable ELF segment extends beyond mod binary")
        ranges.append((start, end))

    ranges.sort()
    for (_, previous_end), (start, _) in zip(ranges, ranges[1:]):
        if start < previous_end:
            raise ValueError("executable ELF segments overlap")
    for section in sections:
        for function_offset, function_size in section.functions:
            start = section.file_offset + function_offset
            end = start + function_size
            if not any(code_start <= start and end <= code_end
                       for code_start, code_end in ranges):
                raise ValueError("declared mod function is outside executable segments")
    return ranges


def zip_member(name: str, data: bytes) -> tuple[zipfile.ZipInfo, bytes]:
    info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
    info.compress_type = zipfile.ZIP_DEFLATED
    info.external_attr = 0o100644 << 16
    return info, data


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--elf", required=True, type=Path)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--symbols", required=True, type=Path)
    parser.add_argument("--binary", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--audit-output", type=Path)
    args = parser.parse_args()

    manifest = args.manifest.read_bytes()
    symbols = args.symbols.read_bytes()
    original_binary = args.binary.read_bytes()
    elf = args.elf.read_bytes()

    manifest_json = json.loads(manifest)
    if manifest_json.get("id") != "dinomod_enhanced":
        raise ValueError("unexpected restoration mod ID")
    if manifest_json.get("native_libraries"):
        raise ValueError("restoration package declares native libraries")

    sections = parse_mod_symbols(symbols)
    code_ranges = map_code_ranges(
        sections, parse_executable_segments(elf), len(original_binary)
    )
    sanitized_binary = bytearray(original_binary)
    original_code_nonzero = 0
    for start, end in code_ranges:
        original_code_nonzero += sum(byte != 0 for byte in sanitized_binary[start:end])
        sanitized_binary[start:end] = bytes(end - start)
    if original_code_nonzero == 0:
        raise ValueError("executable ELF segments were already empty")
    if any(sanitized_binary[start:end] != bytes(end - start)
           for start, end in code_ranges):
        raise ValueError("failed to erase all executable bytes")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(
        args.output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9
    ) as archive:
        for name, contents in (
            ("mod.json", manifest),
            ("mod_syms.bin", symbols),
            ("mod_binary.bin", bytes(sanitized_binary)),
        ):
            info, payload = zip_member(name, contents)
            archive.writestr(info, payload)

    with zipfile.ZipFile(args.output, "r") as archive:
        if archive.namelist() != ["mod.json", "mod_syms.bin", "mod_binary.bin"]:
            raise ValueError("data package contains unexpected members")
        if archive.testzip() is not None:
            raise ValueError("data package failed ZIP integrity validation")

    audit = {
        "format": 1,
        "mod_id": manifest_json["id"],
        "package_members": ["mod.json", "mod_syms.bin", "mod_binary.bin"],
        "executable_segments_removed": len(code_ranges),
        "executable_bytes_removed": sum(end - start for start, end in code_ranges),
        "original_executable_nonzero_bytes": original_code_nonzero,
        "binary_bytes": len(sanitized_binary),
        "source_binary_sha256": sha256(original_binary),
        "sanitized_binary_sha256": sha256(sanitized_binary),
        "symbols_sha256": sha256(symbols),
        "package_sha256": sha256(args.output.read_bytes()),
    }
    if args.audit_output:
        args.audit_output.parent.mkdir(parents=True, exist_ok=True)
        args.audit_output.write_text(
            json.dumps(audit, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
    print(json.dumps(audit, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
