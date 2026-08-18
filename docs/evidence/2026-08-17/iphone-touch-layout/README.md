# Evidence: persisted iPhone/iPad touch-layout editor

Date: 2026-08-17
Target: iPhone 17 Pro Simulator, arm64, iOS 26.5
Goal: implement and verify Goal 28a's independent phone/tablet touch-layout editor
Result: **PASS**

## Product behavior

The native `•••` menu now exposes `Customize Touch Layout`, `Reset Phone
Layout`, and `Reset Tablet Layout`; the prior layout placeholder is gone. The
editor follows the pinned PaperPad interaction model and adds explicit session
Cancel: users can move controls, link/unlink the D-pad or C-button group, resize,
cycle per-control opacity, hide/show buttons, reset, undo the latest operation,
save with Done, or discard the whole editing session with Cancel. Hidden controls
remain visible as dashed targets while editing.

Phone and tablet values are complete dictionaries under separate versioned
NSUserDefaults keys. Loading rejects non-numeric/non-finite values and clamps
coordinates, size, and opacity. Movement clamps the complete target inside the
current safe-area bounds; linked groups clamp as a unit. Gameplay input is
cleared on entry and remains inactive during editing, while dismissal restores
normal touch handling and the safe-area menu button.

## Deterministic proof

`scripts/smoke-ios-layout.sh` runs only through the runtime guard and starts from
a clean app data container. Its first process seeds a tablet-only sentinel,
holds A, enters editing, verifies input clears, verifies full-session Cancel,
moves linked D-pad and C-button groups, changes A size/opacity/visibility,
verifies one-step Undo, forces a movement beyond both screen axes to verify
safe-area clamping, commits, and confirms gameplay touch resumes.

A second process loads the same defaults and independently verifies that
movement, size, opacity, visibility, and both link flags survived relaunch. It
proves the tablet sentinel was not contaminated, resets the phone while retaining
the tablet value, then resets the tablet while retaining phone defaults. A third
launch presents the real native menu for visual evidence.

- `editor-edited.png`: committed custom layout reopened in editing mode; hidden A
  remains recoverable as a dashed selected target.
- `editor-reset.png`: phone defaults after independent reset, with the complete
  eight-action editor toolbar.
- `menu.png`: real native menu showing separate customize and phone/tablet reset
  actions.
- `runtime-excerpt.txt`: all in-app deterministic assertions from both processes.
- `result.txt`: bounded script outcome and policy checks.

The guarded run found no crash and cleanup left no DinoPad process and zero
booted Simulators. The final arm64 app bundle remained ROM-free.

## Regressions and audits

After the implementation, the guarded iPhone input/lifecycle, native home/live
restart, Files import/replacement, and embedded Restored title/gameplay smokes
all passed. The macOS app build, 21-check touch unit test, disposable profile
isolation smoke, repository safety/25-file patch lock, and clean patch replay all
passed. iPad Simulator and physical-device layout usability remain later-phase
acceptance work; this milestone proves independent tablet serialization and
defaults without claiming an iPad visual run.
