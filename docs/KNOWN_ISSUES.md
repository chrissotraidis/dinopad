# DinoPad Known Issues

Last updated: 2026-08-16

This file tracks issues observed in the DinoPad port or its pinned upstream
baseline. Every entry is tied to dated evidence. Entries are ordered by
severity within each section.

## Automation / input delivery

### iOS touch smoke is not yet deterministic

**Status:** Open test debt (2026-08-16, iPhone Simulator).

Digital touch delivery was verified through Computer Use coordinates and the
actual `[dinopad-in]` runtime log, but Simulator-window coordinates depend on
window scale/chrome. Analog drag did not produce a logged axis transition before
the pause point. Add a release-inert deterministic injection boundary or pure
input harness before treating the full touch matrix as regression-protected.

**Update 2026-08-17 (Goal 26c): Resolved.** A DinoPad-owned deterministic test harness in `apple/app/ios_main.mm` (DinoPadInputSmokeRunner, gated by the DINOPAD_RUN_INPUT_SMOKE environment variable) injects simulated touches directly through the same UIKit overlay path the runtime uses. Combined with a hardened `scripts/smoke-ios.sh` cleanup trap, the guarded 8-second run proves every digital N64 mask, all four analog cardinal directions with return-to-zero, simultaneous multi-touch, menu open/dismiss, background/foreground lifecycle, and controller handoff. Unit coverage lives in `tools/touch_unit_test.cpp` (21 ctest checks).

### `smoke-ios.sh` can wait on its console child after an early failure

**Status:** Open harness defect (2026-08-16).

A two-second diagnostic run raced the process-liveness check. The failure path
waited for `simctl launch --console` without first terminating the app/child and
needed runtime-guard interruption. Default 20/90-second green runs terminate
normally. Add a trap that always terminates the bundle and console child before
returning failure.

**Update 2026-08-17 (Goal 26c): Resolved.** The script now installs a single EXIT/INT/TERM trap that terminates the bundle, sends SIGTERM (then SIGKILL) to the `simctl launch --console` child, waits for it, and reaps it. Early failures can no longer block on the console process.

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

### iOS 26.5 headless Simulator preserves a portrait raw framebuffer

**Status:** Simulator limitation; physical-device verification required.

Both DinoPad and the pinned PaperPad Simulator app declare only landscape
orientations and set SDL's landscape hint, yet `simctl io screenshot` returns a
1206x2622 portrait raw framebuffer containing rotated landscape content. The
Simulator CLI exposes no orientation operation and rejects arbitrary landscape
screen geometry. Its GUI toolbar rotates the virtual hardware, but Metal frames
can appear black to Computer Use capture during transitions. Temporary UIWindow,
delegate, and public scene-geometry experiments did not change the headless raw
capture and were removed. Do not use private orientation APIs; validate final
presentation on physical iPhone/iPad.

### Resolved: RT64 Present worker crashed while draining its autorelease pool

**Status:** Fixed and regression-checked (2026-08-16, macOS).

An orderly launcher-window close could crash in `objc_release` on the
`RT64 Present` thread while the graphics thread destroyed `PresentQueue`.
RT64 now stops its present/workload queues before dependent Metal resources,
uses explicit autorelease pools on Apple worker threads, and makes queue
shutdown idempotent. Plume's Metal backend now balances encoder ownership and
does not release autoreleased descriptors, function names, or command buffers.
The rebuilt app passed five consecutive native closes with status 0 and no new
DiagnosticReports entry. Evidence:
`docs/evidence/2026-08-16/macos-graceful-shutdown/`.

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
move with the N64 D-pad (arrow keys in fresh DinoPad profiles). It responds to
the analog stick (keyboard WASD). This is upstream game behavior in the December 2000
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

### Second-save name entry: same END sequence lands on backspace

**Status:** Confirmed (2026-08-16, macOS); affects automated second-save
creation only.

The ENTER NAME keyboard's bottom control row (dot / ! / backspace / END)
handles right presses differently depending on how the name-entry screen was
reached. From a fresh boot (no save), typing 5 letters then S x3 + D x1 lands
on END (sessions 13/14). When opening ENTER NAME through GAME SELECT -> NEW
with an existing save present, the same S x3 + D x1 lands on the backspace
key, deleting the last letter (probes 20-28, repeatedly). Adaptive
measurement (session 13's `measure_bottom`) cycles dot <-> backspace and
never reaches END from the second-save flow. This is upstream prototype
behavior in the keyboard's internal cursor math, not a DinoPad regression.
The first save is created successfully by the game's own flow and persists
across relaunches (see `docs/evidence/2026-08-16/macos-save-persistence/`).
A distinct-named second save is deferred; the durable fix for automated input
is native input injection into the app rather than frontmost-app keystrokes.

Evidence: probe20-28 captures (`.goal-loop/probe2*-evidence/`), session 20
adaptive END attempt (discarded captures in
`.goal-loop/discarded-save-captures/`).

## Game content (prototype, authentic)

### Opening subtitle typo: "floating moutain"

The opening cinematic subtitle reads "Something about a floating moutain
hidden within a storm." The misspelling is in the December 2000 prototype
assets and is preserved as-is (evidence: 2026-08-16 opening-subtitle.png).

## Build / tooling

### Resolved: static restoration required writable executable code

**Status:** Fixed and regression-checked (2026-08-16, macOS).

The developer offline path installed 294 arm64 trampolines by rewriting
base-game entry points. DinoPad now generates build-time replacement/hook
wrappers and lets the static handle activate them without `patch_func`, JIT,
or any other runtime code write. The linked Mach-O has immutable `r-x`
`__TEXT` (`maxprot == initprot == 0x5`) and no `__GAME` segment. Restored and
base-fallback Prototype visual smokes both pass on the same binary. Evidence:
`docs/evidence/2026-08-16/dinomod-static-dispatch-macos/`.

### Resolved: 16-byte arm64 trampoline overwrote adjacent AOT function

**Status:** Fixed and regression-checked (2026-08-16).

The first full DinoMod offline load crashed because the four-byte
`__dll60_dll_60_update2` leaf function was immediately followed by
`__dll60_dll_60_draw`; the runtime's 16-byte trampoline for the first function
overwrote the second. All generated AOT functions now compile with 16-byte
alignment. `tools/check_patchable_aot.py` checks the linked binary and reports
11,162 patchable functions, zero misaligned.

### Default macOS window exceeds small screens

DinoPad's default window is 1600x960, which overflows a 1280x832pt (2560x1664
Retina) display. Use `--window-width 1024 --window-height 768` on small
screens, or pass explicit dimensions. Evidence capture helper
`scripts/capture-window.sh` requires a fitting window to produce a clean
window-only screenshot.

## External hardware blockers

### No connected game controller (physical-controller verification blocked)

**Status:** External blocker (2026-08-16); code path verified hardware-free.

The machine has two paired Bluetooth gamepads (8BitDo Lite 2 and Xbox
Wireless Controller) but both report **Not Connected**; SDL enumerates 0
joysticks and no USB pad is present. Physical-controller play (connect a pad,
reach gameplay, verify analog + button mapping, connect/disconnect handoff)
cannot be exercised on this machine until a controller is connected. This is
not a code defect: `tools/controller_virtual_smoke.cpp` verifies the exact
SDL gamecontroller calls the game makes (open, GetButton/GetAxis, N64 mapping
semantics) 11/11 via a virtual controller (evidence:
`docs/evidence/2026-08-16/macos-controller/`). Unblock when hardware is
available; then run a guarded session with the pad and record `Controller
added` in the runtime log plus gameplay screenshots.
