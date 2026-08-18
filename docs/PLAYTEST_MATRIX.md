# DinoPad Playtest Matrix

Last updated: 2026-08-17

Each row records a verified play session on a real target. "Verified" means
the run was executed, its input/log evidence was captured, and the result was
recorded. The autonomous loop may automate smoke/fixture tests; it never
claims a full playthrough it did not perform.

## Verified sessions

| Date | Target | Mode | Start | End state | Duration | Result | Input | Evidence |
|---|---|---|---|---|---|---|---|---|
| 2026-08-17 | iPhone 17 Pro Simulator, iOS 26.5 arm64 | Restored | Native home with private game-created `AAAAA` save | Controllable ship-deck tutorial, live through ten-minute boundary | 600 s | PASS | UIKit touch analog + A; actual N64 poll | docs/evidence/2026-08-17/iphone-phase5/ |
| 2026-08-17 | iPhone 17 Pro Simulator, iOS 26.5 arm64 | Restored relaunch, same install | Persisted profile-local `AAAAA` save | Controllable ship-deck tutorial at late input frame 26,685 | ~4.5 min | PASS | Full 7-suite touch/lifecycle matrix plus gameplay analog + A | docs/evidence/2026-08-17/iphone-phase5/ |
| 2026-08-16 | macOS arm64 (M2) | Restored (native home primary action) | Native DinoPad home | Restored PRESS START; static no-write dispatch active | ~20 s | PASS | Native button + keyboard A | docs/evidence/2026-08-16/macos-native-home/ |
| 2026-08-16 | macOS arm64 (M2) | Prototype (native home warned action) | Native DinoPad home + archival warning | Direct Game Select; restoration absent | ~25 s | PASS | Native buttons + keyboard A | docs/evidence/2026-08-16/macos-native-home/ |
| 2026-08-16 | macOS arm64 (M2) | Restored (`--profile restored`, disposable isolated root) | Boot | Restored PRESS START; Prototype save unchanged | ~25 s | PASS | Keyboard A | docs/evidence/2026-08-16/macos-profiles/ |
| 2026-08-16 | macOS arm64 (M2) | Prototype (`--profile prototype`, same disposable root) | Boot | Direct Game Select; no restoration activation; Restored save unchanged | ~20 s | PASS | Keyboard A | docs/evidence/2026-08-16/macos-profiles/ |
| 2026-08-16 | macOS arm64 (M2) | Restored (static no-write dispatch; ordinary `.nrm`; no dylib) | Boot | Restored PRESS START -> Start/Options/English title | ~25 s | PASS | Keyboard A | docs/evidence/2026-08-16/dinomod-static-dispatch-macos/ |
| 2026-08-16 | macOS arm64 (M2) | Prototype (same static-dispatch binary; package absent) | Boot | Direct Game Select; restoration dispatch never activated | ~20 s | PASS | Keyboard A | docs/evidence/2026-08-16/dinomod-static-dispatch-macos/ |
| 2026-08-16 | macOS arm64 (M2) | Restored (statically linked code, ordinary `.nrm`, no dylib) | Boot | Restored PRESS START -> Start/Options/English title | ~25 s | PASS | Keyboard A | docs/evidence/2026-08-16/dinomod-static-macos/ |
| 2026-08-16 | macOS arm64 (M2) | Restored (full offline AOT feasibility) | Boot | Restored rolling demo -> PRESS START -> Start/Options/Language title -> Game Select | ~40 s | PASS | Keyboard A | docs/evidence/2026-08-16/dinomod-full-macos/ |
| 2026-08-16 | macOS arm64 (M2) | Prototype (same aligned build, mod disabled) | Boot | Direct Game Select after two A presses; restored title flow absent | ~20 s | PASS | Keyboard A | docs/evidence/2026-08-16/dinomod-full-macos/ |
| 2026-08-16 | macOS arm64 (M2) | Prototype (base) | Boot | Playable tutorial scene ("Krystal! Try shooting the cannon!") | ~5 min/session | PASS | Keyboard (A, WASD, Z), held-input displacement, cannon fire on A | docs/evidence/2026-08-16/macos-gameplay/ |
| 2026-08-16 | macOS arm64 (M2) | Prototype (base) | Boot | Opening cinematic + stable audio loop (95 s session) | ~2 min | PASS | Keyboard (A, WASD) | docs/evidence/2026-08-16/macos-title-audio/ |
| 2026-08-15 | macOS arm64 (M2) | Prototype (base) | Boot | First Metal frame / GAME SELECT | seconds | PASS | none | docs/evidence/2026-08-15/macos-first-frame/ |

## Not yet covered

- Controller play.
- iPad Simulator and physical devices (Phases 6-8).
- Chapter-boundary fixtures and progression (Phase 9).

## Known behavior quirks observed

- ENTER NAME cursor follows the analog stick, not the D-pad; +3 key jump per
  right press (upstream prototype behavior; see docs/KNOWN_ISSUES.md).
- Smoke input must hold keys (or use window activation) to guarantee delivery
  between game polls; see docs/KNOWN_ISSUES.md.
