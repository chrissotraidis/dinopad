# DinoPad Playtest Matrix

Last updated: 2026-08-16

Each row records a verified play session on a real target. "Verified" means
the run was executed, its input/log evidence was captured, and the result was
recorded. The autonomous loop may automate smoke/fixture tests; it never
claims a full playthrough it did not perform.

## Verified sessions

| Date | Target | Mode | Start | End state | Duration | Result | Input | Evidence |
|---|---|---|---|---|---|---|---|---|
| 2026-08-16 | macOS arm64 (M2) | Restored (static no-write dispatch; ordinary `.nrm`; no dylib) | Boot | Restored PRESS START -> Start/Options/English title | ~25 s | PASS | Keyboard A | docs/evidence/2026-08-16/dinomod-static-dispatch-macos/ |
| 2026-08-16 | macOS arm64 (M2) | Prototype (same static-dispatch binary; package absent) | Boot | Direct Game Select; restoration dispatch never activated | ~20 s | PASS | Keyboard A | docs/evidence/2026-08-16/dinomod-static-dispatch-macos/ |
| 2026-08-16 | macOS arm64 (M2) | Restored (statically linked code, ordinary `.nrm`, no dylib) | Boot | Restored PRESS START -> Start/Options/English title | ~25 s | PASS | Keyboard A | docs/evidence/2026-08-16/dinomod-static-macos/ |
| 2026-08-16 | macOS arm64 (M2) | Restored (full offline AOT feasibility) | Boot | Restored rolling demo -> PRESS START -> Start/Options/Language title -> Game Select | ~40 s | PASS | Keyboard A | docs/evidence/2026-08-16/dinomod-full-macos/ |
| 2026-08-16 | macOS arm64 (M2) | Prototype (same aligned build, mod disabled) | Boot | Direct Game Select after two A presses; restored title flow absent | ~20 s | PASS | Keyboard A | docs/evidence/2026-08-16/dinomod-full-macos/ |
| 2026-08-16 | macOS arm64 (M2) | Prototype (base) | Boot | Playable tutorial scene ("Krystal! Try shooting the cannon!") | ~5 min/session | PASS | Keyboard (A, WASD, Z), held-input displacement, cannon fire on A | docs/evidence/2026-08-16/macos-gameplay/ |
| 2026-08-16 | macOS arm64 (M2) | Prototype (base) | Boot | Opening cinematic + stable audio loop (95 s session) | ~2 min | PASS | Keyboard (A, WASD) | docs/evidence/2026-08-16/macos-title-audio/ |
| 2026-08-15 | macOS arm64 (M2) | Prototype (base) | Boot | First Metal frame / GAME SELECT | seconds | PASS | none | docs/evidence/2026-08-15/macos-first-frame/ |

## Not yet covered

- Restored/Prototype save isolation.
- Controller play.
- iPhone / iPad Simulator and physical devices (Phases 5-8).
- Chapter-boundary fixtures and progression (Phase 9).

## Known behavior quirks observed

- ENTER NAME cursor follows the analog stick, not the D-pad; +3 key jump per
  right press (upstream prototype behavior; see docs/KNOWN_ISSUES.md).
- Smoke input must hold keys (or use window activation) to guarantee delivery
  between game polls; see docs/KNOWN_ISSUES.md.
