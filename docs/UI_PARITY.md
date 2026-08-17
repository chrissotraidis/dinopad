# DinoPad / PaperPad Apple-Shell Parity

Last updated: 2026-08-17
Reference: pinned PaperPad commit `644945d4bc4facbbd8ecda8cdfd37ae64e7993fa`

PaperPad is the required behavioral reference for native arm64 N64 features and
Apple-shell quality. DinoPad must reach equivalent capability without copying
Paper Mario artwork, screenshots, branding, or game-specific assumptions.

Status meanings: **Green** implemented and evidenced; **Partial** implemented
but incomplete/unverified; **Open** not implemented; **Blocked** requires an
external dependency.

| Capability | PaperPad reference behavior | DinoPad status | Gap / intentional difference |
|---|---|---|---|
| Native arm64 static game code | No emulation/JIT dependency | Green on macOS and iPhone Simulator | Device build still open. |
| Mobile restored content | Static code plus application-owned data; no arbitrary executable mods | **Green iPhone Simulator (Goal 27c)** | The embedded package has its MIPS executable segment zeroed; writable mod scanning is disabled; iPad/device proof and redistribution permission remain open. |
| Metal presentation | SDL UIKit/AppKit window -> CAMetalLayer -> RT64 | Green first frame | Resize/orientation/device stress open. |
| ROM-free bundle | User imports exact supported ROM | **Green** macOS + iPhone Simulator | Device/IPA audit remains Phase 10. |
| ROM picker/normalization | `.z64/.v64/.n64`, exact revision, private normalized storage | **Green** macOS + iPhone Simulator **(Goal 27a)** | DinoPad validates its December 2000 prototype fingerprint; physical Files providers remain open. |
| First-run setup | Native controller before runtime | **Green** macOS + iPhone Simulator | iOS ROM setup and the post-setup mode chooser both precede SDL; device proof remains. |
| Restored/Prototype home | Primary recommended mode, explicit archival alternative | **Green iPhone Simulator (Goal 27b)** | Restored is primary; Prototype requires a prominent warning; both hand off isolated namespaces and quit-to-home can launch a second runtime. |
| Full N64 touch surface | Stick, D-pad, A/B/Z/L/R/Start/all C buttons | **Green** **(Goal 26c)** | All 14 digital masks verified end-to-end in the [dinopad-in] runtime poll on 2026-08-17; all 15 draw/wire correctly. |
| Touch tap latching | Short taps survive multiple runtime polls | **Green** | Six-poll latch + unit coverage present; used by the digital-mask smoke. |
| Analog response | Deadzone, nonlinear precision, cardinal bias/flick handling | **Green** **(Goal 26c)** | Deadzone/nonlinear/cardinal plus analog flick retention units in touch_unit_test.cpp; all 4 cardinal directions + diagonal multi-touch verified in the runtime poll on 2026-08-17. |
| Phone defaults | Grip-first compact layout | Partial | PaperPad-derived centers/sizes used; measured screenshot comparison not yet recorded. |
| Tablet defaults | Independent larger-device layout | Partial/code only | Never run on iPad Simulator. |
| Safe areas | Controls/menu avoid notch/Home indicator | Partial | Layout uses safe-area insets; orientation/device verification open. |
| Persistent `•••` menu | Always reachable, accessible, controller-independent | Partial | Button/menu and Quit to DinoPad Home work; full menu tree and Resume presentation polish remain open. |
| Modal input policy | Clear input and hide controls for menu/picker/settings/share | Partial | Menu and ROM manager do this (Goals 26c/27a); settings/share flows remain. |
| Layout editor | Move, group-link, resize, opacity, hide/show, reset, undo | Open | Must port behavior with DinoPad persistence keys. |
| Independent idiom persistence | Phone/tablet layouts do not contaminate each other | Open | Default selection is idiom-specific; editable persistence absent. |
| Touch enable/opacity | Persisted settings and live update | Partial | Storage exists; no complete settings UI. |
| Controller handoff | Connected controller hides gameplay controls, never menu | Partial | SDL events wired; real hardware/reconnect evidence open. |
| Input clearing/lifecycle | Resign/background/modal clears held state | **Green Simulator** | Goal 26c proves background/foreground and modal clearing; physical-device interruption evidence remains. |
| Audio controls/session | Master volume and mobile audio lifecycle | Partial | Audio renders; settings/interruption/route evidence open. |
| Display settings | Aspect/internal resolution/filter policy | Open mobile UI | Runtime has configuration; native bridge not implemented. |
| Diagnostics | Bounded private log, redaction, report/share | Open | Must use DinoPad naming and paths. |
| ROM manager | Replace/manage imported ROM from menu | **Green** macOS + iPhone Simulator **(Goal 27a)** | Replace/Remove UI and production import backend evidenced; physical device remains. |
| Save persistence | Private app storage survives relaunch/update | Green macOS; Open mobile proof | Restored/Prototype namespaces must remain isolated. |
| Physical controller play | SDL game controller mapping and handoff | Virtual path Green; physical Open | Requires connected hardware. |
| Native menu/settings accessibility | Labels, hints, readable form sheets | Partial | Menu button/actions accessible; canvas controls need accessibility elements. |
| iPhone/iPad packaging | ROM-free unsigned IPA | Open | Device build, audit, guide, and checksum open. |

## DinoPad-specific additions

These intentional differences are required rather than parity regressions:

- Restored Adventure is the primary/default mode.
- Prototype Mode requires a prominent incompleteness warning.
- Saves/configuration are isolated between Restored and Prototype.
- Restoration code is statically linked and dispatches without runtime writes.
- Mobile restoration data is embedded-only and sanitized of its MIPS executable segment.
- No arbitrary mod installation or downloaded executable code.
- Menu includes restoration settings/status and quit-to-DinoPad-home actions.

## Parity acceptance before Preview 1

- Every row above must be Green or explicitly waived in a release decision.
- Equivalent iPhone/iPad screenshots must measure menu placement within 8 points
  and default control centers within 12 points of PaperPad unless a Dinosaur
  Planet-specific control need is documented.
- Full N64 input, lifecycle, controller handoff, settings, diagnostics, ROM
  management, saves, and packaging must be evidenced on physical iPhone/iPad.
