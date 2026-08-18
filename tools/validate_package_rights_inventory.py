#!/usr/bin/env python3
"""Validate the engineering inventory behind the macOS rights release gate.

This verifies pins, license-text hashes, link evidence, and selected packaged
resource hashes. It deliberately does not interpret licenses or grant release
permission. ``--require-release-ready`` is fail-closed while any recorded
rights blocker remains.
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
DEFAULT_MANIFEST = ROOT / "docs" / "PACKAGE_RIGHTS_INVENTORY.json"
DEFAULT_APP = ROOT / "build-macos" / "DinoPad.app"
STATES = {"notice-recorded", "notice-missing", "rights-unresolved", "restricted"}
TARGETS = {"macos"}
COMPONENT_KEYS = {
    "id",
    "name",
    "targets",
    "source_root",
    "commit",
    "link_tokens",
    "license_files",
    "state",
    "note",
}
LICENSE_KEYS = {"path", "sha256"}
RESOURCE_KEYS = {
    "id",
    "source_path",
    "package_path",
    "sha256",
    "state",
    "note",
}
BLOCKER_KEYS = {"id", "summary", "required_closure"}


def fail(message: str) -> None:
    raise ValueError(message)


def sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def text(entry: dict[str, object], key: str, *, allow_empty: bool = False) -> str:
    value = entry.get(key)
    if not isinstance(value, str) or (not allow_empty and not value.strip()):
        fail(f"{entry.get('id', '<unknown>')}: {key} must be a string"
             + ("" if allow_empty else " and must not be empty"))
    return value


def repo_path(value: str, label: str, *, must_exist: bool = True) -> pathlib.Path:
    pure = pathlib.PurePosixPath(value)
    if pure.is_absolute() or ".." in pure.parts or value.startswith(("~/", "file://")):
        fail(f"{label}: path must be repository-relative: {value}")
    resolved = (ROOT / pure).resolve()
    if resolved != ROOT and ROOT not in resolved.parents:
        fail(f"{label}: path escapes repository: {value}")
    if must_exist and not resolved.exists():
        fail(f"{label}: path does not exist: {value}")
    return resolved


def git_head(path: pathlib.Path) -> str:
    result = subprocess.run(
        ["git", "-C", str(path), "rev-parse", "HEAD"],
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def final_link_command() -> str:
    result = subprocess.run(
        ["ninja", "-C", str(ROOT / "build-macos"), "-t", "commands", "DinoPad"],
        check=True,
        capture_output=True,
        text=True,
    )
    candidates = [line for line in result.stdout.splitlines() if " -o DinoPad " in line]
    if len(candidates) != 1:
        fail(f"expected one final DinoPad linker command, found {len(candidates)}")
    return candidates[0]


def validate(manifest_path: pathlib.Path, app: pathlib.Path, require_ready: bool) -> int:
    data = json.loads(manifest_path.read_text(encoding="utf-8"))
    expected_top = {
        "schema_version",
        "audited_target",
        "basis",
        "components",
        "packaged_resources",
        "release_blockers",
    }
    if set(data) != expected_top:
        fail(f"top-level schema mismatch: expected {sorted(expected_top)}")
    if data["schema_version"] != 1:
        fail("unsupported schema_version")
    if data["audited_target"] != "macos":
        fail("audited_target must be macos")
    if not isinstance(data["basis"], str) or not data["basis"].strip():
        fail("basis must be a non-empty string")

    command = final_link_command()
    seen: set[str] = set()
    blocked_states: list[str] = []
    components = data["components"]
    if not isinstance(components, list) or not components:
        fail("components must be a non-empty list")
    for index, component in enumerate(components):
        if not isinstance(component, dict) or set(component) != COMPONENT_KEYS:
            fail(f"component {index}: schema mismatch")
        component_id = text(component, "id")
        if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", component_id):
            fail(f"{component_id}: id must be lowercase kebab-case")
        if component_id in seen:
            fail(f"{component_id}: duplicate id")
        seen.add(component_id)
        text(component, "name")
        text(component, "note")

        targets = component["targets"]
        if not isinstance(targets, list) or not targets or set(targets) - TARGETS:
            fail(f"{component_id}: invalid targets")
        state = text(component, "state")
        if state not in STATES:
            fail(f"{component_id}: invalid state {state}")
        if state != "notice-recorded":
            blocked_states.append(f"component:{component_id}:{state}")

        source_root = text(component, "source_root", allow_empty=True)
        commit = text(component, "commit", allow_empty=True)
        if bool(source_root) != bool(commit):
            fail(f"{component_id}: source_root and commit must both be set or both be empty")
        if source_root:
            source_path = repo_path(source_root, f"{component_id}.source_root")
            if not re.fullmatch(r"[0-9a-f]{40}", commit):
                fail(f"{component_id}: commit must be 40 lowercase hex characters")
            actual_commit = git_head(source_path)
            if actual_commit != commit:
                fail(f"{component_id}: expected {commit}, found {actual_commit}")

        tokens = component["link_tokens"]
        if not isinstance(tokens, list) or not tokens:
            fail(f"{component_id}: link_tokens must be a non-empty list")
        for token in tokens:
            if not isinstance(token, str) or not token or token not in command:
                fail(f"{component_id}: link token missing from DinoPad build: {token!r}")

        licenses = component["license_files"]
        if not isinstance(licenses, list):
            fail(f"{component_id}: license_files must be a list")
        if state == "notice-recorded" and not licenses:
            fail(f"{component_id}: notice-recorded component needs a license file")
        for license_index, license_entry in enumerate(licenses):
            if not isinstance(license_entry, dict) or set(license_entry) != LICENSE_KEYS:
                fail(f"{component_id}: license {license_index} schema mismatch")
            license_path = repo_path(
                text(license_entry, "path"), f"{component_id}.license_files[{license_index}]"
            )
            if source_root and license_path != source_path and source_path not in license_path.parents:
                fail(f"{component_id}: license file is outside the pinned source root")
            expected_hash = text(license_entry, "sha256")
            if not re.fullmatch(r"[0-9a-f]{64}", expected_hash):
                fail(f"{component_id}: invalid license SHA-256")
            actual_hash = sha256(license_path)
            if actual_hash != expected_hash:
                fail(f"{component_id}: license hash mismatch for {license_path}")

    resources = data["packaged_resources"]
    if not isinstance(resources, list) or not resources:
        fail("packaged_resources must be a non-empty list")
    for index, resource in enumerate(resources):
        if not isinstance(resource, dict) or set(resource) != RESOURCE_KEYS:
            fail(f"resource {index}: schema mismatch")
        resource_id = text(resource, "id")
        if resource_id in seen:
            fail(f"{resource_id}: duplicate id")
        seen.add(resource_id)
        state = text(resource, "state")
        if state not in STATES:
            fail(f"{resource_id}: invalid state {state}")
        if state != "notice-recorded":
            blocked_states.append(f"resource:{resource_id}:{state}")
        text(resource, "note")
        expected_hash = text(resource, "sha256")
        if not re.fullmatch(r"[0-9a-f]{64}", expected_hash):
            fail(f"{resource_id}: invalid SHA-256")
        source = repo_path(text(resource, "source_path"), f"{resource_id}.source_path")
        package_rel = text(resource, "package_path")
        package_pure = pathlib.PurePosixPath(package_rel)
        if package_pure.is_absolute() or ".." in package_pure.parts:
            fail(f"{resource_id}: package_path must be relative")
        packaged = (app / package_pure).resolve()
        if app.resolve() not in packaged.parents or not packaged.is_file():
            fail(f"{resource_id}: packaged resource missing: {package_rel}")
        source_hash = sha256(source)
        package_hash = sha256(packaged)
        if source_hash != expected_hash or package_hash != expected_hash:
            fail(
                f"{resource_id}: hash mismatch source={source_hash} package={package_hash} "
                f"expected={expected_hash}"
            )

    blockers = data["release_blockers"]
    if not isinstance(blockers, list):
        fail("release_blockers must be a list")
    blocker_ids: set[str] = set()
    for index, blocker in enumerate(blockers):
        if not isinstance(blocker, dict) or set(blocker) != BLOCKER_KEYS:
            fail(f"release blocker {index}: schema mismatch")
        blocker_id = text(blocker, "id")
        if blocker_id in blocker_ids:
            fail(f"{blocker_id}: duplicate release blocker")
        blocker_ids.add(blocker_id)
        text(blocker, "summary")
        text(blocker, "required_closure")

    print(
        "PACKAGE RIGHTS INVENTORY: VALID "
        f"({len(components)} linked components, {len(resources)} selected resources, "
        f"{len(blocked_states)} unresolved states, {len(blockers)} release blockers)"
    )
    for item in blocked_states:
        print(f"  BLOCKED STATE: {item}")
    for blocker in blockers:
        print(f"  RELEASE BLOCKER: {blocker['id']} - {blocker['summary']}")

    if require_ready and (blocked_states or blockers):
        print("RELEASE RIGHTS GATE: FAIL (no override)", file=sys.stderr)
        return 2
    print("NOTE: inventory integrity is not legal clearance or release approval.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=pathlib.Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--app", type=pathlib.Path, default=DEFAULT_APP)
    parser.add_argument("--require-release-ready", action="store_true")
    args = parser.parse_args()
    return validate(args.manifest.resolve(), args.app.resolve(), args.require_release_ready)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, json.JSONDecodeError, subprocess.CalledProcessError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
