#!/usr/bin/env python3
"""normalize_rom.py - DinoPad-owned ROM byte-order normalization + fingerprint
validation (N64 cartridge formats), matching the behavior DinoPad will use in
the native Files import flow (PaperPad semantics, DinoPad fingerprint).

N64 ROM cartridges appear in three byte orders:
  .z64  big-endian      header magic 0x80371240
  .v64  byte-swapped    header magic 0x37804012  (16-bit halves swapped)
  .n64  little-endian   header magic 0x40123780  (word bytes reversed)

DinoPad normalizes any of these to big-endian (.z64) and verifies the exact
supported ROM fingerprint (December 2000 Dinosaur Planet prototype, MD5
49f7bb346ade39d1915c22e090ffd748).

Usage:
  normalize_rom.py <input>            # print NORMALIZED|ALREADY|WRONG-FORMAT
  normalize_rom.py <input> --out <p>  # write normalized big-endian ROM
  normalize_rom.py --self-test        # run unit tests, exit 0 on pass
"""
from __future__ import annotations

import hashlib
import sys

SUPPORTED_ROM_MD5 = "49f7bb346ade39d1915c22e090ffd748"

MAGIC_Z64 = 0x80371240  # big-endian
MAGIC_V64 = 0x37804012  # 16-bit byte-swapped
MAGIC_N64 = 0x40123780  # word-reversed (little-endian)


def detect_byte_order(data: bytes) -> str:
    """Return 'z64' (big-endian), 'v64' (byte-swapped), 'n64' (little-endian),
    or 'unknown' based on the header magic."""
    if len(data) < 4:
        return "unknown"
    magic = (data[0] << 24) | (data[1] << 16) | (data[2] << 8) | data[3]
    if magic == MAGIC_Z64:
        return "z64"
    if magic == MAGIC_V64:
        return "v64"
    if magic == MAGIC_N64:
        return "n64"
    return "unknown"


def swap16(data: bytes) -> bytes:
    # Swap each 16-bit word; preserve any trailing odd byte unchanged.
    swapped = b"".join(data[i : i + 2][::-1] for i in range(0, len(data) - 1, 2))
    if len(data) % 2:
        swapped += data[-1:]
    return swapped


def swap32(data: bytes) -> bytes:
    # Reverse each 32-bit word; preserve any trailing 1-3 bytes unchanged.
    swapped = b"".join(data[i : i + 4][::-1] for i in range(0, len(data) - 3, 4))
    remainder = len(data) % 4
    if remainder:
        swapped += data[-remainder:]
    return swapped


def normalize(data: bytes) -> bytes:
    """Normalize any supported cartridge format to big-endian .z64 bytes."""
    order = detect_byte_order(data)
    if order == "z64":
        return data
    if order == "v64":
        return swap16(data)
    if order == "n64":
        return swap32(data)
    return data  # caller must reject via detect_byte_order


def validate_fingerprint(data: bytes) -> bool:
    """True when the normalized big-endian bytes match the supported ROM MD5."""
    return hashlib.md5(normalize(data)).hexdigest() == SUPPORTED_ROM_MD5


def _make_test_rom(order: str) -> bytes:
    """Build a fake-but-valid cartridge: real header magic in the right byte
    order, arbitrary payload, deterministic for tests."""
    payload = bytes(range(256)) * 4  # 1024 bytes
    if order == "z64":
        header = MAGIC_Z64.to_bytes(4, "big")
        body = header + payload
    elif order == "v64":
        body = swap16(MAGIC_Z64.to_bytes(4, "big") + payload)
    else:
        body = swap32(MAGIC_Z64.to_bytes(4, "big") + payload)
    return body


def self_test() -> int:
    failures = 0

    def check(cond: bool, name: str) -> None:
        nonlocal failures
        print(("PASS" if cond else "FAIL") + f": {name}")
        if not cond:
            failures += 1

    # Byte-order detection
    z64 = _make_test_rom("z64")
    v64 = _make_test_rom("v64")
    n64 = _make_test_rom("n64")
    check(detect_byte_order(z64) == "z64", "detect big-endian .z64")
    check(detect_byte_order(v64) == "v64", "detect byte-swapped .v64")
    check(detect_byte_order(n64) == "n64", "detect little-endian .n64")
    check(detect_byte_order(b"\x00\x00") == "unknown", "reject short input")
    check(detect_byte_order(b"\xde\xad\xbe\xef" + b"x" * 32) == "unknown",
          "reject unknown magic")

    # Normalization round-trips: v64/n64 normalize back to the z64 bytes.
    check(normalize(z64) == z64, "z64 normalization is identity")
    check(normalize(v64) == z64, "v64 normalizes to big-endian")
    check(normalize(n64) == z64, "n64 normalizes to big-endian")
    check(swap16(swap16(z64)) == z64, "swap16 is an involution")
    check(swap32(swap32(z64)) == z64, "swap32 is an involution")

    # Round-trip the swap functions on odd-length tail handling (len % 2/4).
    # Partial trailing words are preserved byte-for-byte (never fabricated);
    # real N64 ROMs are 40 MiB (a multiple of both 2 and 4), so this only
    # matters for defensive input handling.
    odd16 = b"\x01\x02\x03"
    check(swap16(odd16) == b"\x02\x01\x03", "swap16 swaps words, preserves odd tail byte")
    check(swap16(swap16(odd16)) == odd16, "swap16 involution with odd tail")
    odd32 = b"\x01\x02\x03"
    check(swap32(odd32) == odd32, "swap32 preserves partial trailing word byte-for-byte")
    check(swap32(swap32(odd32)) == odd32, "swap32 involution with partial tail")
    check(swap32(b"\x01\x02\x03\x04\x05") == b"\x04\x03\x02\x01\x05",
          "swap32 swaps words, preserves trailing byte")

    # Fingerprint check is intentionally strict: test payloads must not match
    # the real ROM, so validate_fingerprint must return False for them.
    check(not validate_fingerprint(z64), "fake payload fails the real fingerprint")

    # Real-ROM fingerprint test only runs when DINO_NORMALIZE_ROM is set to a
    # path (private; never auto-detected in the repo).
    import os
    real = os.environ.get("DINO_NORMALIZE_ROM")
    if real:
        try:
            with open(real, "rb") as fh:
                rom = fh.read()
            order = detect_byte_order(rom)
            print(f"note: real ROM detected as {order}")
            check(order in ("z64", "v64", "n64"), "real ROM has a supported byte order")
            check(validate_fingerprint(rom), "real ROM matches the supported MD5")
        except OSError as exc:
            check(False, f"could not read DINO_NORMALIZE_ROM: {exc}")

    print(f"\nnormalize_rom self-test: {'PASS' if failures == 0 else 'FAIL'}"
          f" ({failures} failures)")
    return 0 if failures == 0 else 1


def main(argv: list[str]) -> int:
    if "--self-test" in argv:
        return self_test()

    if len(argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2

    path = argv[1]
    out = None
    if "--out" in argv:
        idx = argv.index("--out")
        if idx + 1 < len(argv):
            out = argv[idx + 1]

    try:
        with open(path, "rb") as fh:
            data = fh.read()
    except OSError as exc:
        print(f"ERROR: cannot read {path}: {exc}", file=sys.stderr)
        return 1

    order = detect_byte_order(data)
    if order == "unknown":
        print("WRONG-FORMAT")
        return 3

    if not validate_fingerprint(data):
        print("UNSUPPORTED-REVISION")
        return 4

    print("NORMALIZED" if order != "z64" else "ALREADY")
    if out:
        normalized = normalize(data)
        with open(out, "wb") as fh:
            fh.write(normalized)
        print(f"wrote {out} ({len(normalized)} bytes, big-endian)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
