## DinoPad RmlUi launcher on Metal (macOS)

Date: 2026-08-16 (captured 05:06-05:07 UTC, prior cycle; committed with this
cycle's docs). Target: macOS arm64 (DinoPad.app, RT64 Metal).
Result: PASS - the RmlUi launcher renders through Metal and its mod check works.

The Dino Recompiled v0.3.0 launcher (RmlUi) renders correctly through the
RT64 Metal path on arm64 macOS. The launcher shows the DINOSAUR PLANET title,
the main menu (Start game / Setup controls / Settings / Mods / Exit), and the
expected "Missing Dinomod Enhanced" warning dialog with Continue Anyway /
Cancel, which appears because the pinned DinoMod package is not yet installed
in the game's mod folder at runtime.

Screenshots:

- `m1_launcher.png` - launcher main menu rendered through Metal.
- `m2_after_start.png` - "Missing Dinomod Enhanced" warning dialog.
- `m3_flow.png` - dialog overlay with menu behind it.
- `l1_launcher.png`, `l2_launcher_later.png` - launcher menu (duplicate angles).

This closes the "RmlUi launcher not exercised on Metal" item from
docs/STATUS.md. The launcher is the upstream desktop UI; DinoPad will bypass it
with the native Apple shell (the game itself runs with --skip-launcher in
DinoPad's own app flow). The "Missing Dinomod Enhanced" dialog is upstream
launcher behavior that DinoPad's native home screen replaces with the
Restored/Prototype chooser.

The exact launch command for this capture is not recorded in the evidence
folder (captured in a prior cycle's guarded macOS session). The launcher
appears when DinoPad launches the game without `--skip-launcher`; the game
itself was verified separately with `--skip-launcher` in the DinoPad app flow.
