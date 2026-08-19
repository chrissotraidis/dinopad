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
STATES = {"notice-recorded", "notice-missing", "advisory-reviewed", "permission-required"}
BLOCKING_STATES = {"notice-missing", "permission-required"}
PROFILES = {"base", "restored"}
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
RESOLVED_KEYS = {"id", "summary", "evidence"}
BLOCKER_KEYS = {"id", "applies_to", "summary", "required_closure"}
ADVISORY_KEYS = {"id", "summary", "basis"}


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


def validate_base_artifact(app: pathlib.Path) -> None:
    executable = app / "DinoPad"
    if not executable.is_file():
        fail(f"base artifact executable is missing: {executable}")
    if (app / "dinomod_restoration_data.nrm").exists():
        fail("base artifact contains DinoMod restoration data")
    strings = subprocess.run(
        ["strings", "-a", str(executable)],
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    markers = (
        "dinomod_enhanced",
        "Restored Adventure",
        "Static restoration dispatch enabled",
        "Bundled static restoration",
        "Bundled restoration data registered",
    )
    present = [marker for marker in markers if marker in strings]
    if present:
        fail(f"base artifact contains DinoMod integration markers: {present}")


def validate(
    manifest_path: pathlib.Path,
    app: pathlib.Path,
    require_ready: bool,
    distribution_profile: str,
    artifact_app: pathlib.Path | None,
) -> int:
    subprocess.run(
        [sys.executable, str(ROOT / "tools" / "validate_compiled_dependency_inventory.py")],
        check=True,
    )
    data = json.loads(manifest_path.read_text(encoding="utf-8"))
    expected_top = {
        "schema_version",
        "audited_target",
        "basis",
        "components",
        "packaged_resources",
        "resolved_requirements",
        "release_blockers",
        "release_advisories",
    }
    if set(data) != expected_top:
        fail(f"top-level schema mismatch: expected {sorted(expected_top)}")
    if data["schema_version"] != 2:
        fail("unsupported schema_version")
    if data["audited_target"] != "macos":
        fail("audited_target must be macos")
    if not isinstance(data["basis"], str) or not data["basis"].strip():
        fail("basis must be a non-empty string")

    command = final_link_command()
    seen: set[str] = set()
    blocked_states: list[tuple[str, str, str]] = []
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
        if state in BLOCKING_STATES:
            blocked_states.append(("component", component_id, state))

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
        if state in BLOCKING_STATES:
            blocked_states.append(("resource", resource_id, state))
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

    resolved = data["resolved_requirements"]
    if not isinstance(resolved, list):
        fail("resolved_requirements must be a list")
    requirement_ids: set[str] = set()
    for index, requirement in enumerate(resolved):
        if not isinstance(requirement, dict) or set(requirement) != RESOLVED_KEYS:
            fail(f"resolved requirement {index}: schema mismatch")
        requirement_id = text(requirement, "id")
        if requirement_id in requirement_ids:
            fail(f"{requirement_id}: duplicate requirement")
        requirement_ids.add(requirement_id)
        text(requirement, "summary")
        repo_path(text(requirement, "evidence"), f"{requirement_id}.evidence")

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
        applies_to = blocker["applies_to"]
        if (not isinstance(applies_to, list) or not applies_to or
                set(applies_to) - PROFILES):
            fail(f"{blocker_id}: invalid applies_to profiles")
        text(blocker, "summary")
        text(blocker, "required_closure")

    advisories = data["release_advisories"]
    if not isinstance(advisories, list):
        fail("release_advisories must be a list")
    advisory_ids: set[str] = set()
    for index, advisory in enumerate(advisories):
        if not isinstance(advisory, dict) or set(advisory) != ADVISORY_KEYS:
            fail(f"release advisory {index}: schema mismatch")
        advisory_id = text(advisory, "id")
        if advisory_id in advisory_ids:
            fail(f"{advisory_id}: duplicate release advisory")
        advisory_ids.add(advisory_id)
        text(advisory, "summary")
        text(advisory, "basis")

    applicable_states = [
        item for item in blocked_states
        if not (distribution_profile == "base" and item[1] == "dinomod-enhanced")
    ]
    applicable_blockers = [
        blocker for blocker in blockers
        if distribution_profile in blocker["applies_to"]
    ]
    if artifact_app is not None and distribution_profile == "base":
        validate_base_artifact(artifact_app)
    if require_ready and distribution_profile == "base" and artifact_app is None:
        fail("base release validation requires --artifact-app")

    print(
        "PACKAGE RIGHTS INVENTORY: VALID "
        f"({len(components)} linked components, {len(resources)} selected resources, "
        f"{len(resolved)} resolved requirements, {len(advisories)} advisories)"
    )
    for requirement in resolved:
        print(f"  RESOLVED: {requirement['id']} - {requirement['summary']}")
    for advisory in advisories:
        print(f"  ADVISORY: {advisory['id']} - {advisory['summary']}")
    for kind, item_id, state in applicable_states:
        print(f"  BLOCKED STATE: {kind}:{item_id}:{state}")
    for blocker in applicable_blockers:
        print(f"  RELEASE BLOCKER: {blocker['id']} - {blocker['summary']}")

    if require_ready and (applicable_states or applicable_blockers):
        print(
            f"RELEASE COMPLIANCE GATE ({distribution_profile}): FAIL (no override)",
            file=sys.stderr,
        )
        return 2
    if require_ready:
        print(f"RELEASE COMPLIANCE GATE ({distribution_profile}): PASS")
    print("NOTE: advisories are disclosed risks, not unidentified license failures.")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=pathlib.Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--app", type=pathlib.Path, default=DEFAULT_APP)
    parser.add_argument("--require-release-ready", action="store_true")
    parser.add_argument("--distribution-profile", choices=sorted(PROFILES), default="restored")
    parser.add_argument("--artifact-app", type=pathlib.Path)
    args = parser.parse_args()
    artifact_app = args.artifact_app.resolve() if args.artifact_app is not None else None
    return validate(
        args.manifest.resolve(),
        args.app.resolve(),
        args.require_release_ready,
        args.distribution_profile,
        artifact_app,
    )


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, json.JSONDecodeError, subprocess.CalledProcessError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
