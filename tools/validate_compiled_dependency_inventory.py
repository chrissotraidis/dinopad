#!/usr/bin/env python3
"""Validate compiler-derived third-party coverage for the macOS target.

The Ninja dependency database identifies every pinned source/header file used
to build the DinoPad target and its prerequisites. This validator requires each
such file under ref/ to map to exactly one deepest component prefix and binds
that component to an exact standalone or inline notice source. It inventories
notice ownership; it does not interpret licenses or prove package compliance.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re
import subprocess
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "docs" / "COMPILED_DEPENDENCY_INVENTORY.json"
ENTRY_KEYS = {"id", "coverage_prefix", "notice_source", "notice_kind", "sha256"}
NOTICE_KINDS = {"file", "inline"}


def fail(message: str) -> None:
    raise ValueError(message)


def repo_path(value: str, label: str) -> pathlib.Path:
    pure = pathlib.PurePosixPath(value)
    if pure.is_absolute() or ".." in pure.parts or value.startswith(("~/", "file://")):
        fail(f"{label}: path must be repository-relative: {value}")
    resolved = (ROOT / pure).resolve()
    if ROOT not in resolved.parents or not resolved.exists():
        fail(f"{label}: missing or outside repository: {value}")
    return resolved


def digest(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def compiler_dependencies(build_dir: pathlib.Path) -> set[str]:
    result = subprocess.run(
        ["ninja", "-C", str(build_dir), "-t", "deps"],
        check=True,
        capture_output=True,
        text=True,
    )
    ref_root = str((ROOT / "ref").resolve()) + "/"
    dependencies: set[str] = set()
    for line in result.stdout.splitlines():
        candidate = line.strip()
        if candidate.startswith(ref_root):
            dependencies.add(pathlib.Path(candidate).relative_to(ROOT).as_posix())
    if not dependencies:
        fail("Ninja dependency database contains no repository ref/ dependencies")
    return dependencies


def validate(manifest_path: pathlib.Path) -> None:
    data = json.loads(manifest_path.read_text(encoding="utf-8"))
    if set(data) != {"schema_version", "target", "build_dir", "basis", "components"}:
        fail("top-level schema mismatch")
    if data["schema_version"] != 1 or data["target"] != "macos":
        fail("unsupported schema version or target")
    if not isinstance(data["basis"], str) or not data["basis"].strip():
        fail("basis must be a non-empty string")
    build_value = data["build_dir"]
    if not isinstance(build_value, str):
        fail("build_dir must be a string")
    build_dir = repo_path(build_value, "build_dir")

    components = data["components"]
    if not isinstance(components, list) or not components:
        fail("components must be a non-empty list")
    seen_ids: set[str] = set()
    seen_prefixes: set[str] = set()
    normalized: list[tuple[str, str]] = []
    inline_count = 0
    for index, entry in enumerate(components):
        if not isinstance(entry, dict) or set(entry) != ENTRY_KEYS:
            fail(f"component {index}: schema mismatch")
        component_id = entry["id"]
        if not isinstance(component_id, str) or not re.fullmatch(
            r"[a-z0-9]+(?:-[a-z0-9]+)*", component_id
        ):
            fail(f"component {index}: invalid id")
        if component_id in seen_ids:
            fail(f"duplicate component id: {component_id}")
        seen_ids.add(component_id)

        prefix = entry["coverage_prefix"]
        if not isinstance(prefix, str):
            fail(f"{component_id}: coverage_prefix must be a string")
        prefix_path = repo_path(prefix, f"{component_id}.coverage_prefix")
        if not prefix_path.is_dir() or not prefix.startswith("ref/"):
            fail(f"{component_id}: coverage_prefix must be a ref/ directory")
        prefix = pathlib.PurePosixPath(prefix).as_posix()
        if prefix in seen_prefixes:
            fail(f"duplicate coverage_prefix: {prefix}")
        seen_prefixes.add(prefix)
        normalized.append((component_id, prefix))

        source = entry["notice_source"]
        if not isinstance(source, str):
            fail(f"{component_id}: notice_source must be a string")
        source_path = repo_path(source, f"{component_id}.notice_source")
        if not source_path.is_file():
            fail(f"{component_id}: notice_source must be a file")
        kind = entry["notice_kind"]
        if kind not in NOTICE_KINDS:
            fail(f"{component_id}: invalid notice_kind")
        inline_count += kind == "inline"
        expected = entry["sha256"]
        if not isinstance(expected, str) or not re.fullmatch(r"[0-9a-f]{64}", expected):
            fail(f"{component_id}: invalid SHA-256")
        if digest(source_path) != expected:
            fail(f"{component_id}: notice source hash mismatch")

    dependencies = compiler_dependencies(build_dir)
    counts = {component_id: 0 for component_id, _ in normalized}
    for dependency in dependencies:
        matches = [
            (component_id, prefix)
            for component_id, prefix in normalized
            if dependency == prefix or dependency.startswith(prefix + "/")
        ]
        if not matches:
            fail(f"uncovered compiler dependency: {dependency}")
        deepest = max(len(prefix) for _, prefix in matches)
        winners = [(component_id, prefix) for component_id, prefix in matches if len(prefix) == deepest]
        if len(winners) != 1:
            fail(f"ambiguous compiler dependency coverage: {dependency}")
        counts[winners[0][0]] += 1

    empty = sorted(component_id for component_id, count in counts.items() if count == 0)
    if empty:
        fail(f"stale component prefixes with zero compiler dependencies: {', '.join(empty)}")

    print(
        "COMPILED DEPENDENCY INVENTORY: VALID "
        f"({len(dependencies)} source/header files, {len(components)} components, "
        f"{inline_count} inline notice sources, 0 uncovered)"
    )
    print("NOTE: compiler coverage is not license interpretation or shipped-notice completeness.")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=pathlib.Path, default=DEFAULT_MANIFEST)
    args = parser.parse_args()
    validate(args.manifest.resolve())
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, json.JSONDecodeError, subprocess.CalledProcessError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
