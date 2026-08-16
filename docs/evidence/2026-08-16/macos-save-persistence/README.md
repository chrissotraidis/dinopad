# Evidence: Flashram save persistence across relaunch (macOS arm64)

Date: 2026-08-16
Target: macOS arm64 (Apple M2, macOS 26.5, Xcode 26.6)
Goal: Verify saves (Flashram) persist across relaunch on macOS
Result: **PASS**

DinoPad commit (cycle): de4809e (this evidence set follows)
Upstream pins: dino-recomp v0.3.0 = 725b2ede9cacc57968e0a028efed8df9235ba483;
dinomod v0.9.3 = d79e86be... (unchanged)

## How DinoPad saves work (pinned source)

- N64ModernRuntime FlashRAM emulation (`librecomp/src/flash.cpp`) backs the
  December 2000 prototype's FlashRAM saving.
- The save image is 1 Mbit (128 KiB), stored at
  `~/Library/Application Support/DinoPad/saves/dino.bin` (config path set in
  `src/config/config.cpp`).
- A background saving thread coalesces writes; `update_save_file()` writes the
  buffer and rotates a `.bak` (see `librecomp/src/pi.cpp`).
- The game creates the save at name entry (ENTER NAME flow); GAME SELECT reads
  the image back on every boot.

## What was verified

1. **Save exists and is stable.** `dino.bin` (created 2026-08-16 02:30 by the
   name-entry flow) has SHA-256 `a62085a8...5516`; identical for
   `dino.bin` and `dino.bin.bak` before, between, and after two full launches
   (`hash1.txt`, `hash2.txt`, `hash3.txt`). No corruption across relaunch.
2. **GAME SELECT lists the persisted save.** After a clean relaunch,
   `b1_game_select_after_relaunch.png` shows the first slot occupied with
   "AAAAA" (read back from the flash image on disk).
3. **The save loads and reaches gameplay after relaunch.** Launch #2 selected
   the AAAAA slot, confirmed PLAY THIS GAME? -> YES, played through the
   opening sequence, and reached the playable tutorial scene
   (`b2_gameplay_after_relaunch.png`; input-responsive gameplay verified in
   `docs/evidence/2026-08-16/macos-gameplay/`).
4. **The save survives repeated relaunches.** The same image has now been
   loaded in sessions 15-21 (9+ guarded launches) without change or loss.

## Commands

```sh
scripts/runtime-guard.sh macos bash .goal-loop/scratch-title-audio/session21.sh
# hashes: shasum -a 256 "$HOME/Library/Application Support/DinoPad/saves/dino.bin"
```

Launch: `build-macos/DinoPad --skip-launcher --window-width 1024 --window-height 768`.

## Note on creating a second save

The prototype's ENTER NAME keyboard is flow-dependent: after typing 5
letters, S x3 + D x1 lands on END only from a fresh boot; when entering a
second save via GAME SELECT -> NEW, the same key sequence lands on the
backspace key (observed repeatedly in probes 20-28; see
`docs/KNOWN_ISSUES.md`). This does not affect the persistence claim above:
the existing save is created by the game's own name-entry flow (sessions
13/14) and has persisted across every relaunch since. Second-save creation
with a distinct name is a future automation goal (durable fix: native input
injection into the app rather than frontmost-app keystrokes).

## Cleanup

- Both launches terminated; 0 booted Simulators; runtime lock released.
