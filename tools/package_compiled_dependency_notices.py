#!/usr/bin/env python3
"""Assemble or verify hash-bound standalone notices for compiled dependencies."""

from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import shutil
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "docs" / "COMPILED_DEPENDENCY_INVENTORY.json"
DEFAULT_APP = ROOT / "build-macos" / "DinoPad.app"
TARGETS = {"macos", "ios-device"}


def fail(message: str) -> None:
    raise ValueError(message)


def sha256(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def expected_index(target: str) -> tuple[dict[str, object], dict[pathlib.PurePosixPath, pathlib.Path]]:
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    excluded = set(data["target_exclusions"][target])
    assemblies = {entry["id"]: entry for entry in data["inline_notice_assemblies"]}
    copies: dict[pathlib.PurePosixPath, pathlib.Path] = {}
    records: list[dict[str, object]] = []
    for component in data["components"]:
        if component["id"] in excluded:
            continue
        source_rel = pathlib.PurePosixPath(component["notice_source"])
        source = ROOT / source_rel
        if sha256(source) != component["sha256"]:
            fail(f"notice source hash mismatch: {component['id']}")
        package_source = source
        package_hash = component["sha256"]
        if component["notice_kind"] == "file":
            destination = pathlib.PurePosixPath(component["id"]) / source_rel.name
        else:
            assembly = assemblies[component["id"]]
            package_source = ROOT / assembly["path"]
            package_hash = assembly["sha256"]
            if sha256(package_source) != package_hash:
                fail(f"assembled notice hash mismatch: {component['id']}")
            destination = pathlib.PurePosixPath(component["id"]) / package_source.name
        if destination in copies:
            fail(f"duplicate notice destination: {destination}")
        copies[destination] = package_source
        package_rel = destination.as_posix()
        records.append(
            {
                "id": component["id"],
                "coverage_prefix": component["coverage_prefix"],
                "notice_kind": component["notice_kind"],
                "notice_source": component["notice_source"],
                "sha256": component["sha256"],
                "package_path": package_rel,
                "package_sha256": package_hash,
            }
        )
    index = {
        "schema_version": 1,
        "target": target,
        "basis": "Generated from docs/COMPILED_DEPENDENCY_INVENTORY.json; inline package files are mechanically assembled primary notices and do not close secondary-notice or legal review.",
        "components": records,
    }
    return index, copies


def encoded_index(index: dict[str, object]) -> bytes:
    return (json.dumps(index, indent=2, sort_keys=True) + "\n").encode("utf-8")


def assemble(target: str, destination: pathlib.Path) -> None:
    index, copies = expected_index(target)
    if destination.exists():
        shutil.rmtree(destination)
    destination.mkdir(parents=True)
    for relative, source in copies.items():
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
    (destination / "INDEX.json").write_bytes(encoded_index(index))
    print(
        f"Compiled dependency notices assembled: {len(copies)} component notice files, "
        "including mechanically assembled inline-primary notices"
    )


def verify(target: str, destination: pathlib.Path) -> None:
    index, copies = expected_index(target)
    expected_files = {pathlib.PurePosixPath("INDEX.json"), *copies.keys()}
    actual_files = {
        path.relative_to(destination)
        for path in destination.rglob("*")
        if path.is_file()
    }
    if actual_files != {pathlib.Path(path) for path in expected_files}:
        missing = sorted(str(path) for path in expected_files - {pathlib.PurePosixPath(path.as_posix()) for path in actual_files})
        extra = sorted(str(path) for path in {pathlib.PurePosixPath(path.as_posix()) for path in actual_files} - expected_files)
        fail(f"notice file set mismatch; missing={missing}, extra={extra}")
    if (destination / "INDEX.json").read_bytes() != encoded_index(index):
        fail("compiled notice INDEX.json mismatch")
    for relative, source in copies.items():
        packaged = destination / relative
        if packaged.read_bytes() != source.read_bytes():
            fail(f"compiled notice differs from source: {relative}")
    print(
        f"Compiled dependency notices verified: {len(copies)} component notice files, "
        "including mechanically assembled inline-primary notices"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", choices=sorted(TARGETS), default="macos")
    parser.add_argument("--app", type=pathlib.Path)
    parser.add_argument("--destination", type=pathlib.Path)
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    if args.app is not None and args.destination is not None:
        fail("--app and --destination are mutually exclusive")
    if args.destination is not None:
        destination = args.destination.resolve()
    else:
        app = (args.app or DEFAULT_APP).resolve()
        if args.target == "macos":
            destination = app / "Contents" / "Resources" / "Notices" / "Compiled"
        else:
            destination = app / "Notices" / "Compiled"
    if args.verify:
        verify(args.target, destination)
    else:
        assemble(args.target, destination)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
