#!/usr/bin/env python3
"""Validate compiler-derived third-party coverage for Apple targets.

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


def compiler_dependencies(build_dir: pathlib.Path, dependency_format: str) -> set[str]:
    ref_root = str((ROOT / "ref").resolve()) + "/"
    dependencies: set[str] = set()
    if dependency_format == "ninja":
        result = subprocess.run(
            ["ninja", "-C", str(build_dir), "-t", "deps"],
            check=True,
            capture_output=True,
            text=True,
        )
        candidates = (line.strip() for line in result.stdout.splitlines())
    elif dependency_format == "xcode-depfiles":
        depfiles = sorted(build_dir.rglob("*.d"))
        if not depfiles:
            fail(f"no Xcode dependency files under {build_dir.relative_to(ROOT)}")
        candidates = (
            token
            for depfile in depfiles
            for token in depfile.read_text(encoding="utf-8", errors="replace")
                .replace("\\\n", " ")
                .split()
        )
    else:
        fail(f"unsupported dependency format: {dependency_format}")
    for candidate in candidates:
        if candidate.startswith(ref_root):
            dependencies.add(pathlib.Path(candidate).relative_to(ROOT).as_posix())
    if not dependencies:
        fail("Ninja dependency database contains no repository ref/ dependencies")
    return dependencies


def validate(manifest_path: pathlib.Path, selected_target: str | None) -> None:
    data = json.loads(manifest_path.read_text(encoding="utf-8"))
    expected_top = {
        "schema_version", "targets", "target_exclusions", "basis", "components"
    }
    if set(data) != expected_top:
        fail("top-level schema mismatch")
    if data["schema_version"] != 1:
        fail("unsupported schema version")
    if not isinstance(data["basis"], str) or not data["basis"].strip():
        fail("basis must be a non-empty string")
    targets = data["targets"]
    exclusions = data["target_exclusions"]
    if not isinstance(targets, dict) or set(targets) != {"macos", "ios-device"}:
        fail("targets must define macos and ios-device")
    if not isinstance(exclusions, dict) or set(exclusions) != set(targets):
        fail("target_exclusions must match targets")
    if selected_target is not None and selected_target not in targets:
        fail(f"unknown target: {selected_target}")

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

    target_names = [selected_target] if selected_target else list(targets)
    for target_name in target_names:
        target = targets[target_name]
        if not isinstance(target, dict) or set(target) != {"build_dir", "dependency_format"}:
            fail(f"{target_name}: target schema mismatch")
        build_value = target["build_dir"]
        dependency_format = target["dependency_format"]
        if not isinstance(build_value, str) or not isinstance(dependency_format, str):
            fail(f"{target_name}: build_dir and dependency_format must be strings")
        build_dir = repo_path(build_value, f"{target_name}.build_dir")
        dependencies = compiler_dependencies(build_dir, dependency_format)
        counts = {component_id: 0 for component_id, _ in normalized}
        for dependency in dependencies:
            matches = [
                (component_id, prefix)
                for component_id, prefix in normalized
                if dependency == prefix or dependency.startswith(prefix + "/")
            ]
            if not matches:
                fail(f"{target_name}: uncovered compiler dependency: {dependency}")
            deepest = max(len(prefix) for _, prefix in matches)
            winners = [
                (component_id, prefix)
                for component_id, prefix in matches
                if len(prefix) == deepest
            ]
            if len(winners) != 1:
                fail(f"{target_name}: ambiguous compiler dependency: {dependency}")
            counts[winners[0][0]] += 1

        excluded = exclusions[target_name]
        if not isinstance(excluded, list) or any(item not in seen_ids for item in excluded):
            fail(f"{target_name}: invalid target exclusions")
        actual = {component_id for component_id, count in counts.items() if count}
        expected = seen_ids - set(excluded)
        if actual != expected:
            missing = sorted(expected - actual)
            unexpected = sorted(actual - expected)
            fail(f"{target_name}: component-set mismatch; missing={missing}, unexpected={unexpected}")
        active_inline = sum(
            entry["notice_kind"] == "inline" and entry["id"] in actual
            for entry in components
        )
        print(
            f"COMPILED DEPENDENCY INVENTORY ({target_name}): VALID "
            f"({len(dependencies)} source/header files, {len(actual)} components, "
            f"{active_inline} inline notice sources, 0 uncovered)"
        )
    print("NOTE: compiler coverage is not license interpretation or shipped-notice completeness.")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=pathlib.Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--target", choices=("macos", "ios-device"))
    args = parser.parse_args()
    validate(args.manifest.resolve(), args.target)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, json.JSONDecodeError, subprocess.CalledProcessError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
