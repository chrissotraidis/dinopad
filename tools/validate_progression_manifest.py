#!/usr/bin/env python3
"""Validate public metadata for ignored private progression fixtures."""

from __future__ import annotations

import datetime as dt
import json
import pathlib
import re
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "docs" / "PROGRESSION_FIXTURES.json"
ENTRY_KEYS = {
    "id",
    "mode",
    "expected_area",
    "expected_action",
    "private_sha256",
    "known_risk",
    "last_verification_date",
    "last_verified_commit",
    "last_verified_target",
    "evidence",
}
TARGETS = {
    "macos",
    "iphone-simulator",
    "ipad-simulator",
    "physical-iphone",
    "physical-ipad",
}


def fail(message: str) -> None:
    raise ValueError(message)


def nonempty(entry: dict[str, object], key: str) -> str:
    value = entry.get(key)
    if not isinstance(value, str) or not value.strip():
        fail(f"{entry.get('id', '<unknown>')}: {key} must be a non-empty string")
    return value


def validate(path: pathlib.Path) -> int:
    data = json.loads(path.read_text(encoding="utf-8"))
    if set(data) != {"schema_version", "fixtures"}:
        fail("top level must contain only schema_version and fixtures")
    if data["schema_version"] != 1:
        fail("unsupported schema_version")
    fixtures = data["fixtures"]
    if not isinstance(fixtures, list) or not fixtures:
        fail("fixtures must be a non-empty list")

    seen: set[str] = set()
    for index, entry in enumerate(fixtures):
        if not isinstance(entry, dict):
            fail(f"fixture {index}: entry must be an object")
        if set(entry) != ENTRY_KEYS:
            missing = sorted(ENTRY_KEYS - set(entry))
            extra = sorted(set(entry) - ENTRY_KEYS)
            fail(f"fixture {index}: schema mismatch missing={missing} extra={extra}")

        fixture_id = nonempty(entry, "id")
        if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", fixture_id):
            fail(f"{fixture_id}: id must be lowercase kebab-case")
        if fixture_id in seen:
            fail(f"{fixture_id}: duplicate fixture id")
        seen.add(fixture_id)

        if nonempty(entry, "mode") not in {"restored", "prototype"}:
            fail(f"{fixture_id}: unsupported mode")
        nonempty(entry, "expected_area")
        nonempty(entry, "expected_action")
        nonempty(entry, "known_risk")

        checksum = nonempty(entry, "private_sha256")
        if not re.fullmatch(r"[0-9a-f]{64}", checksum):
            fail(f"{fixture_id}: private_sha256 must be 64 lowercase hex characters")
        commit = nonempty(entry, "last_verified_commit")
        if not re.fullmatch(r"[0-9a-f]{7,40}", commit):
            fail(f"{fixture_id}: last_verified_commit must be a Git object prefix")
        target = nonempty(entry, "last_verified_target")
        if target not in TARGETS:
            fail(f"{fixture_id}: unsupported last_verified_target")
        try:
            dt.date.fromisoformat(nonempty(entry, "last_verification_date"))
        except ValueError as exc:
            fail(f"{fixture_id}: invalid last_verification_date: {exc}")

        evidence = nonempty(entry, "evidence")
        if not evidence.startswith("docs/evidence/") or pathlib.PurePosixPath(evidence).is_absolute():
            fail(f"{fixture_id}: evidence must be a repository-relative docs/evidence path")
        evidence_path = (ROOT / evidence).resolve()
        if ROOT not in evidence_path.parents or not evidence_path.exists():
            fail(f"{fixture_id}: evidence path does not exist inside the repository")

        for key, value in entry.items():
            if key == "evidence" or not isinstance(value, str):
                continue
            if (
                pathlib.PurePosixPath(value).is_absolute()
                or value.startswith(("~/", "file://"))
                or re.match(r"^[A-Za-z]:[\\/]", value)
            ):
                fail(f"{fixture_id}: absolute/private path found in {key}")

    print(f"PROGRESSION MANIFEST: PASS ({len(fixtures)} fixture metadata entries; no private bytes or paths)")
    return 0


if __name__ == "__main__":
    manifest = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else DEFAULT_MANIFEST
    try:
        raise SystemExit(validate(manifest))
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
