# Evidence: ROM byte-order normalizer + fingerprint validation (DinoPad-owned)

Date: 2026-08-16
Target: host tool (macOS arm64, Python 3)
Goal: Add the plan-listed `tools/normalize_rom.py` (ROM byte-order
normalization and fingerprint validation) and its unit tests
Result: **PASS**

DinoPad commit: 0e03822 (this evidence set follows)

## What was added

`tools/normalize_rom.py`:

- Detects N64 cartridge byte order from the header magic:
  - `.z64` big-endian `0x80371240`
  - `.v64` byte-swapped `0x37804012`
  - `.n64` little-endian `0x40123780`
- Normalizes `.v64`/`.n64` to big-endian (16-bit / word-swap) with defensive
  partial-word handling.
- Validates the exact supported ROM fingerprint (December 2000 Dinosaur
  Planet prototype, MD5 `49f7bb346ade39d1915c22e090ffd748`).
- CLI: `normalize_rom.py <input> [--out <path>]` and `--self-test`.

This is the DinoPad-owned logic that the native Files import flow will call
(PaperPad semantics, DinoPad fingerprint), per the plan's first-run flow and
unit-test contract (ROM byte-order normalization, fingerprint validation).

## Verification

- `python3 tools/normalize_rom.py --self-test`: **16/16 PASS**
  (detection, normalization round-trips, swap involutions, odd-tail
  handling, strict fingerprint rejection of fake payloads).
- Real private ROM: detected as `.z64` big-endian and matching the supported
  MD5 (`DINO_NORMALIZE_ROM=<path> --self-test` -> PASS; CLI reports ALREADY).
- `scripts/build-macos-app.sh` now stages/validates the ROM through this
  tool (replacing the plain md5 check); app-bundle build still PASSes and
  stays ROM-free.

## Notes

- Two initial self-test failures (trailing-byte handling in swap16/swap32)
  were real edge-case bugs in the first draft; fixed so partial trailing
  words are preserved byte-for-byte. Real N64 ROMs are 40 MiB (multiple of 2
  and 4), so this is defensive-only, but the tests now lock the behavior.
- No app or Simulator was launched; no runtime lock used.

## Commands

```sh
python3 tools/normalize_rom.py --self-test
DINO_NORMALIZE_ROM="$HOME/Library/Application Support/DinoPad/dino.z64" \
  python3 tools/normalize_rom.py --self-test
python3 tools/normalize_rom.py "$HOME/Library/Application Support/DinoPad/dino.z64"
./scripts/build-macos-app.sh
```
