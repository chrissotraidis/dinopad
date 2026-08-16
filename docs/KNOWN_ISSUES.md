# DinoPad Known Issues

Last updated: 2026-08-16

This file tracks issues observed in the DinoPad port or its pinned upstream
baseline. Every entry is tied to dated evidence. Entries are ordered by
severity within each section.

## Automation / input delivery

### `osascript` keystrokes go to the frontmost app, not the DinoPad window

**Status:** Confirmed (2026-08-16, macOS); worked around in all sessions.

`osascript` System Events `key down/up` delivers keystrokes to whatever
application is frontmost. When the agent host (Codex) was frontmost, session
16's scripted A/WASD presses never reached the game: the game sat at GAME
SELECT for the whole session and the `[dinopad-in]` log stayed empty. The fix
is `.goal-loop/scratch-title-audio/sendkey.sh`, which first sets the DinoPad
process frontmost via System Events, then sends the held key. All subsequent
sessions (17-19) deliver input reliably. This is test-harness behavior, not a
game defect; the iOS shell will deliver input directly through the app, so
this finding applies to macOS smoke automation only.

Evidence: session 16 (no input reached the game, GAME SELECT unchanged),
sessions 17-19 (input delivered, gameplay responsive).

## Renderer / runtime

### RT64 Metal: "RenderPool in Metal is not implemented currently"

**Status:** Known RT64 upstream note; not fatal.

RT64 prints `RenderPool in Metal is not implemented currently. Resources are
created directly on device.` at startup on macOS. Resources are created on the
device directly, and first-frame rendering, the full boot sequence, the save
flow, and the opening cinematic all render correctly on arm64 macOS
(evidence: 2026-08-16). No action planned unless an RT64 upstream Metal
implementation lands.

## Input

### Name-entry keyboard navigation ignores the D-pad

**Status:** Confirmed prototype behavior (2026-08-16, macOS).

On the game's ENTER NAME screen, the on-screen keyboard cursor does **not**
move with the N64 D-pad (keyboard IJKL). It responds to the analog stick
(keyboard WASD). This is upstream game behavior in the December 2000
prototype's name-entry code, not a DinoPad regression. The default keyboard
mapping already provides WASD analog, so no DinoPad change is required for
keyboard use; the touch/controller shell port must map the analog stick, which
is the PaperPad behavior anyway.

Evidence: session 8 (d-pad navigation left the cursor on `A`), sessions 9-13
(analog navigation moved the cursor, measured per-press from screenshots).

### Name-entry keyboard cursor jumps +3 keys per right press

**Status:** Confirmed prototype quirk (2026-08-16, macOS).

On the ENTER NAME screen, a single analog right press moves the keyboard
highlight `A -> D -> G -> A` (row of 9, +3 with wrap) instead of one key.
Vertical movement lands the cursor on the bottom control row (`.` / `END`),
where a single right press reaches `END`. The quirk is in the prototype's
internal cursor-index mapping and matches the rendered layout only loosely.
DinoPad documents this in `docs/PLAYTEST_MATRIX.md` and works around it in
automated smoke input sequences (S x3 then D x1 reaches END from a fresh
name).

Evidence: measured glyph-brightness tracking across sessions 9-13.

## Game content (prototype, authentic)

### Opening subtitle typo: "floating moutain"

The opening cinematic subtitle reads "Something about a floating moutain
hidden within a storm." The misspelling is in the December 2000 prototype
assets and is preserved as-is (evidence: 2026-08-16 opening-subtitle.png).

## Build / tooling

### Default macOS window exceeds small screens

DinoPad's default window is 1600x960, which overflows a 1280x832pt (2560x1664
Retina) display. Use `--window-width 1024 --window-height 768` on small
screens, or pass explicit dimensions. Evidence capture helper
`scripts/capture-window.sh` requires a fitting window to produce a clean
window-only screenshot.
