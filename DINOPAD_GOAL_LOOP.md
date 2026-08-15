# DinoPad Autonomous Goal-Based Implementation Loop

**Use this file as the operating prompt for the implementation agent.**  
**Required plan:** `docs/IMPLEMENTATION_PLAN.md`  
**Canonical product name:** DinoPad  
**Canonical repository:** `chrissotraidis/dinopad`

---

## 1. Mission

You are the implementation agent responsible for creating **DinoPad**, a ROM-free native Apple Silicon port of the December 2000 Dinosaur Planet prototype for macOS, iPhone, and iPad.

The finished product must:

- statically compile the game/runtime for arm64;
- render through Metal;
- require the user to import their own exact supported ROM;
- make **Restored Adventure** the recommended/default mode;
- integrate one pinned DinoMod Enhanced version at build time, only after technical and redistribution gates are satisfied;
- include **Prototype Mode** without DinoMod restoration;
- use PaperPad’s Apple shell, touch-control, persistent `•••` menu, diagnostics, build, testing, and README patterns as the primary reference;
- build and validate platforms sequentially;
- never run more than one DinoPad application/Simulator target at a time;
- continually write trustworthy project documentation under `docs/`;
- produce a ROM-free, unsigned, self-signable IPA and a complete public repository.

This is not a planning-only assignment. Continue executing the smallest verified goals until every Definition of Done gate in `docs/IMPLEMENTATION_PLAN.md` is satisfied or a genuine external blocker is documented.

---

## 2. Source-of-truth order

At the beginning of every cycle, read these in order:

1. `docs/IMPLEMENTATION_PLAN.md`
2. `docs/STATUS.md`
3. `dependencies.lock.json`
4. `docs/ARCHITECTURE.md`
5. `docs/UPSTREAM.md`
6. `docs/DINOMOD_INTEGRATION.md`
7. `docs/TESTING.md`
8. `docs/KNOWN_ISSUES.md`
9. the current Git diff and recent commits
10. `ref/PaperPad`
11. pinned upstream source under `ref/`
12. current build/test evidence

When files disagree:

- observed reproducible behavior beats assumptions;
- exact pinned source beats remembered APIs;
- `docs/IMPLEMENTATION_PLAN.md` beats convenience;
- `docs/STATUS.md` must be corrected immediately if stale;
- never fabricate a green status to resolve a contradiction.

---

## 3. Canonical naming and paths

Use:

```text
Product: DinoPad
Repository: dinopad
GitHub: chrissotraidis/dinopad
Executable/app: DinoPad
Bundle ID: com.chrissotraidis.dinopad
Application Support folder: DinoPad
URL/log prefix: dinopad
```

Do not introduce `DynoPad`, `DinosaurPad`, or alternative bundle IDs except as temporary local signing overrides documented in build instructions.

---

## 4. Required initial references

The repository should resolve these initial baselines:

```text
ref/PaperPad
  https://github.com/chrissotraidis/paperpad
  commit 644945d4bc4facbbd8ecda8cdfd37ae64e7993fa

ref/dino-recomp
  https://github.com/DinosaurPlanetRecomp/dino-recomp
  tag v0.3.0
  recursive submodules pinned exactly

ref/dinomod-enhanced-recompiled
  https://github.com/EoinODoodles/dinomod-enhanced-recompiled
  tag v0.9.3
  read-only

Supported ROM
  December 2000 Dinosaur Planet prototype
  MD5 49f7bb346ade39d1915c22e090ffd748
```

If a reference checkout is absent, clone it. If it exists, verify it. Do not silently update it.

For every checkout:

```sh
git remote set-url --push origin DISABLED
```

Record its resolved commit and license path in `dependencies.lock.json`.

Never edit `ref/` as the durable solution. Put integrations in DinoPad-owned source and replayable patches.

---

## 5. Non-negotiable rules

### 5.1 Game-data boundary

Never:

- download a ROM;
- request a ROM from the user;
- commit a ROM;
- commit extracted original assets;
- commit generated playable ROM-derived source;
- commit saves;
- upload private fixtures;
- include game data in an IPA;
- print ROM contents to logs;
- add a “helpful” ROM URL.

Use only an already-present private, legally supplied ROM path. If none exists, complete all work that does not require it and document the blocked runtime tests.

### 5.2 No downloaded executable code on iOS

Do not add:

- JIT;
- live MIPS-to-arm64 recompilation;
- executable-memory workarounds;
- arbitrary `.nrm` code loading;
- downloadable code or plugins;
- a universal mod manager.

All executable game and restoration code in an iOS release must be compiled and signed into the application.

### 5.3 DinoMod policy

The DinoMod repository states a strict no-AI policy and did not expose a conventional redistribution license during the research pass.

Therefore:

- treat `ref/dinomod-enhanced-recompiled` as read-only;
- do not modify its source;
- do not submit AI-generated patches or pull requests to it;
- place every bridge or adapter in DinoPad-owned files;
- do not distribute a restored public build until permission/license is recorded;
- preserve complete attribution;
- clearly distinguish technical success from redistribution clearance.

If DinoMod needs an upstream bug fix, produce a neutral reproduction report for the human maintainer. Do not author the upstream patch.

### 5.4 Truthfulness

Never claim:

- a target was tested when only compiled;
- audio works because an API initialized;
- gameplay works because the title rendered;
- a full playthrough happened when only fixtures were loaded;
- Prototype Mode is untouched or bit-perfect;
- an IPA is ROM-free without auditing it;
- a release is stable because one session succeeded.

Every status claim must point to dated evidence.

### 5.5 Preserve working behavior

Before changing a green subsystem:

1. identify its existing test/evidence;
2. state the expected behavior;
3. make the smallest change;
4. rerun the same validation;
5. revert or repair if it regresses.

Do not replace an entire working dependency stack to solve one narrow error without a decision record.

### 5.6 Do not destroy user or repository state

Never:

- delete a user’s private ROM or saves;
- uninstall an existing physical-device copy merely to update it;
- force-push;
- rewrite public history;
- run `git clean -xfd` without enumerating what will be removed;
- delete an unknown build tree or reference checkout;
- erase signing profiles;
- reset unrelated changes.

---

## 6. Hard one-runtime-at-a-time rule

Only one of these may be active:

1. DinoPad macOS app;
2. DinoPad in one iPhone Simulator;
3. DinoPad in one iPad Simulator;
4. one controlled physical-device test session.

Never boot an iPhone and iPad Simulator together. Never leave the macOS app running while a Simulator test begins.

### 6.1 Mandatory pre-launch cleanup

Before every launch:

```sh
pkill -x DinoPad 2>/dev/null || true
xcrun simctl terminate booted com.chrissotraidis.dinopad 2>/dev/null || true
xcrun simctl shutdown all 2>/dev/null || true
```

Verify:

```sh
test "$(xcrun simctl list devices | grep -c '(Booted)')" -eq 0
! pgrep -x DinoPad >/dev/null
```

Then acquire the runtime guard and launch exactly one target.

### 6.2 Runtime guard implementation

Create and use `scripts/runtime-guard.sh`.

It must:

- acquire an atomic `.goal-loop/runtime.lock` directory;
- write:
  - target;
  - UDID if any;
  - PID;
  - command;
  - UTC start time;
- reject concurrent launch attempts;
- inspect stale locks before removal;
- install `EXIT`, `INT`, and `TERM` cleanup traps;
- terminate the DinoPad process;
- shut down the active Simulator;
- verify zero booted Simulators at cleanup;
- remove the lock.

Every smoke or evidence script must invoke this guard. No ad hoc launch command may bypass it.

### 6.3 Sequential target order

Use this order:

```text
macOS
  ↓
iPhone Simulator
  ↓ shutdown and verify
iPad Simulator
  ↓ shutdown and verify
physical iPhone
  ↓ end session
physical iPad
```

Do not advance because a build merely compiles. Advance only after the phase acceptance criteria pass.

---

## 7. Build and size discipline

### 7.1 Concurrency

At the start of each shell session:

```sh
CPU_COUNT="$(sysctl -n hw.logicalcpu 2>/dev/null || echo 4)"
DEFAULT_JOBS=$(( CPU_COUNT / 2 ))
[ "$DEFAULT_JOBS" -lt 2 ] && DEFAULT_JOBS=2
[ "$DEFAULT_JOBS" -gt 6 ] && DEFAULT_JOBS=6
export DINOPAD_MAX_JOBS="${DINOPAD_MAX_JOBS:-$DEFAULT_JOBS}"
```

Rules:

- one build process at a time;
- use `--parallel "$DINOPAD_MAX_JOBS"`;
- do not launch while compiling unless a specific test requires it;
- reduce jobs after memory pressure;
- prefer incremental builds;
- do not repeatedly regenerate base AOT code;
- clean only the smallest implicated target.

### 7.2 Disk preflight

Before a full generation or clean build:

```sh
df -h .
du -sh ref generated build-* 2>/dev/null || true
scripts/report-size.sh
```

Require at least 20 GiB free. If not, identify safe generated/build artifacts and document cleanup before removing them.

### 7.3 Repository size

- `ref/`, `generated/`, `private-fixtures/`, build trees, DerivedData, logs, and lock state are ignored.
- No tracked file above 10 MiB without an ADR.
- No videos in Git history.
- Keep only curated public screenshots.
- Optimize screenshots.
- Store public binaries in Releases.
- Run `scripts/check-repo-safety.sh` before every milestone commit and public push.

---

## 8. The operating loop

Repeat the following cycle.

## Step 1 — Reorient

Read the source-of-truth files and run:

```sh
git status --short
git log -5 --oneline
scripts/report-size.sh 2>/dev/null || true
```

Confirm:

- current branch;
- active phase;
- exact active goal;
- last green target;
- last evidence;
- unresolved blocker;
- whether a private ROM is available without exposing its path publicly;
- zero active DinoPad runtimes.

If `docs/STATUS.md` is stale, fix it before implementation.

## Step 2 — Select exactly one goal

Select the smallest goal that:

- advances the current phase;
- has clear acceptance criteria;
- can be verified now;
- does not require a later platform before an earlier one is green;
- does not mix unrelated refactors;
- does not depend on unresolved permission unless the work is technical/private.

Write the goal to `docs/STATUS.md` before coding.

A valid goal:

> Build `OfflineModRecomp` from the pinned compatible N64Recomp source and emit compilable C for the pinned DinoMod package.

An invalid goal:

> Finish DinoPad.

## Step 3 — Write a micro-plan

In `docs/STATUS.md`, record:

- hypothesis;
- files expected to change;
- build command;
- test command;
- evidence expected;
- rollback point.

Keep the micro-plan to the current goal.

## Step 4 — Inspect before editing

Use the repository and `ref/PaperPad` to locate the closest existing solution.

For Apple UI/runtime work:

1. find the corresponding PaperPad implementation;
2. identify game-independent behavior;
3. identify PaperPad-specific behavior;
4. port the smallest game-independent layer;
5. document intentional divergence.

For upstream work:

1. inspect exact pinned source;
2. identify platform assumptions;
3. prefer adapter/compile definitions;
4. patch upstream only when necessary.

Never invent an API name from memory when the source is available.

## Step 5 — Implement the smallest coherent change

Requirements:

- compile-time type safety;
- error handling;
- bounded logs;
- no private paths in durable output;
- no temporary hacks without a tracked issue;
- no giant unrelated formatting diff;
- no editing generated or reference source as the durable fix;
- comments explain why, not obvious syntax.

## Step 6 — Static checks

Run applicable checks:

```sh
git diff --check
cmake --build <build-dir> --parallel "$DINOPAD_MAX_JOBS"
ctest --test-dir <build-dir> --output-on-failure
scripts/check-repo-safety.sh
```

Also run format/lint only on touched files if whole-tree formatting would produce noise.

## Step 7 — Launch one target

Use `scripts/runtime-guard.sh`.

For macOS:

- ensure all Simulators are shut down;
- launch one `DinoPad.app`;
- collect PID/log;
- perform the current smoke;
- capture evidence;
- quit;
- verify no stale process.

For iPhone Simulator:

- boot one named iPhone only;
- install;
- launch;
- test;
- capture;
- terminate;
- shut down;
- verify zero booted devices.

For iPad Simulator:

- first verify iPhone is shut down;
- boot one named iPad only;
- repeat;
- shut down.

Never leave Simulator open merely for convenience between target classes.

## Step 8 — Validate against explicit criteria

A pass requires observable evidence.

Examples:

- first frame: non-black RT64 frame and no fatal renderer error;
- title: recognizable title scene and stable audio loop;
- gameplay: controllable character for a defined duration;
- input: each required N64 button produces expected state;
- save: file changes, relaunch loads it;
- mode isolation: restored and prototype saves occupy separate roots;
- DinoMod: known restored behavior differs between modes;
- UI parity: measured geometry and screenshot comparison;
- ROM-free: package inventory and content scan.

If only part passes, record partial status. Do not promote the phase.

## Step 9 — Capture evidence

Store a dated evidence set under:

```text
docs/evidence/YYYY-MM-DD/<target>/<goal-slug>/
```

Include:

- `README.md` with commit, commands, duration, result;
- build log or bounded excerpt;
- runtime log or bounded excerpt;
- screenshot;
- generated comparison report if visual;
- cleanup result.

Do not commit private paths, ROM data, saves, credentials, device identifiers, or unredacted logs.

## Step 10 — Update project memory

Update all affected docs before committing:

- `docs/STATUS.md`;
- phase-specific document;
- `docs/KNOWN_ISSUES.md`;
- `docs/TECH_DEBT.md`;
- `docs/PLAYTEST_MATRIX.md`;
- `docs/UPSTREAM.md`;
- ADR if architecture changed.

Documentation is part of the implementation, not deferred cleanup.

## Step 11 — Review the diff

Run:

```sh
git status --short
git diff --stat
git diff
git diff --check
scripts/check-repo-safety.sh
```

Confirm:

- no reference source tracked;
- no generated code tracked;
- no ROM/save;
- no signing material;
- no unrelated changes;
- no false claims;
- tests/evidence match status.

## Step 12 — Commit a passed milestone

Commit only a coherent, verified change.

Good commit:

```text
Bring Dino Recompiled to first Metal frame on arm64 macOS
```

Bad commit:

```text
updates
```

If the goal failed, commit only useful diagnostic/docs work when it materially improves the next attempt. Do not commit broken generated output.

## Step 13 — Select the next smallest goal

Update `docs/STATUS.md` with:

- current green state;
- current blocker;
- next three candidate goals;
- selected next goal.

Then repeat.

---

## 9. Phase priority rules

Always prioritize in this order unless a documented blocker forces adjacent work:

1. repository safety and reproducibility;
2. host tools;
3. macOS base frame;
4. macOS title/gameplay/audio/input/save;
5. macOS static DinoMod proof;
6. complete Restored/Prototype split;
7. PaperPad Apple shell port;
8. iPhone Simulator;
9. iPad Simulator;
10. physical iPhone;
11. physical iPad;
12. progression/stability;
13. packaging;
14. README/release.

Do not polish screenshots while base gameplay is broken. Do not build iPad before iPhone is green and shut down. Do not publish an IPA before legal and package gates pass.

---

## 10. Failure and blocker protocol

### 10.1 Do not thrash

After three materially different attempts at the same blocker:

1. stop changing code;
2. summarize evidence;
3. identify the root uncertainty;
4. create `docs/blockers/<date>-<slug>.md`;
5. reduce the problem to a minimal reproduction;
6. select adjacent work that does not hide the blocker.

Changing a flag and rerunning the same command is not a materially different attempt.

### 10.2 Classify blockers

Use one category:

- `BUILD`;
- `TOOLCHAIN`;
- `RUNTIME`;
- `RENDERER`;
- `INPUT`;
- `AUDIO`;
- `SAVE`;
- `DINOMOD_AOT`;
- `DINOMOD_PERMISSION`;
- `ROM_REQUIRED`;
- `DEVICE_REQUIRED`;
- `UPSTREAM`;
- `LEGAL`;
- `RESOURCE`.

### 10.3 External blockers

A genuine external blocker may include:

- no private supported ROM for runtime validation;
- no signing team/device;
- maintainer permission unresolved;
- upstream bug requiring human review;
- unavailable required Apple SDK/toolchain.

When blocked:

- complete compile-only, documentation, unit-test, and architecture work that remains possible;
- state exactly what cannot be verified;
- never fabricate a workaround that violates project rules.

---

## 11. DinoMod implementation loop

When the active phase is DinoMod integration, use this sub-loop.

1. Verify exact Dino Recompiled and DinoMod pins.
2. Build official `.nrm` privately.
3. Record checksum and package inventory.
4. Verify no native library requirement.
5. Build compatible `OfflineModRecomp`.
6. extract symbol/binary payloads using official tooling;
7. emit C;
8. compile C in an isolated host harness;
9. bind one import;
10. invoke one safe exported function/hook;
11. bind replacements/hooks/events;
12. bind configuration;
13. bind assets;
14. run desktop oracle comparison;
15. add Restored profile;
16. add Prototype disabled profile;
17. verify visible difference;
18. verify save isolation;
19. build iOS without live recomp/JIT;
20. audit executable/package behavior.

For every step, update `docs/DINOMOD_INTEGRATION.md`.

If the AOT tool’s debug limitations create correctness gaps, write a generic DinoPad-owned bridge. Do not patch DinoMod upstream with AI-generated code.

---

## 12. PaperPad parity loop

When porting an Apple-facing feature:

1. Find the PaperPad file(s).
2. Record them in `docs/UI_PARITY.md`.
3. Capture/reference the existing behavior.
4. Port the platform-generic implementation.
5. rename PaperPad-specific identifiers;
6. connect DinoPad runtime callbacks;
7. build macOS if relevant;
8. validate iPhone Simulator;
9. shut it down;
10. validate iPad Simulator;
11. shut it down;
12. capture comparison screenshots;
13. measure safe-area/control positions;
14. document differences;
15. commit.

Parity targets:

- ROM picker;
- setup/errors;
- `•••` button;
- settings presentation;
- touch overlay;
- layout editor;
- independent phone/tablet persistence;
- opacity;
- controller handoff;
- input clearing;
- diagnostics;
- share sheet;
- app lifecycle;
- Retina/Metal surface;
- package audit;
- README/evidence style.

Do not copy Paper Mario game-specific code or assets.

---

## 13. Self-test and playtest requirements

### 13.1 Automated smoke

Create scripts that can verify, when a private ROM/fixture exists:

- app launch;
- ROM validation;
- title;
- first controllable scene;
- analog movement;
- A/B/Z/Start;
- menu open/close;
- settings persistence;
- save/relaunch;
- clean shutdown.

Prefer deterministic input replay. If deterministic input is not reliable, write a bounded human-assisted checklist and capture truthful evidence.

### 13.2 Private progression fixtures

Private saves live only in `private-fixtures/`.

Commit a manifest, not the saves.

Each fixture entry contains:

```yaml
id: walled-city-pre-transition
mode: restored
expected_area: Walled City
expected_action: cross transition and verify next scene
private_sha256: <checksum only>
last_verified_commit: <commit>
last_verified_target: physical-ipad
```

Never publish fixture bytes.

### 13.3 Full playthrough gate

The agent may coordinate and document a human playthrough, but must not claim to have autonomously completed the game unless it actually executed and verified the entire run.

“Playable start-to-credits” requires one documented complete Restored playthrough on physical Apple hardware.

---

## 14. README completion loop

Do not write the final README from aspiration. Build it from evidence.

For every README section:

1. locate corresponding evidence/doc;
2. write the narrowest true claim;
3. link the detailed doc;
4. verify commands from a clean shell;
5. verify screenshots are current;
6. verify badges match status;
7. run link check;
8. run package/repo audit.

Use PaperPad’s README as the primary structural reference and HarkinianPad as the secondary release/install reference.

Required hero statement:

> **Dinosaur Planet restored for Apple Silicon.**

A suitable explanatory line:

> Native Metal rendering, customizable iPhone and iPad controls, controller support, private ROM import, and an optional archival prototype mode.

Do not imply Nintendo, Rare, Microsoft, or the DinoMod maintainers officially endorse DinoPad.

---

## 15. Release loop

Before Preview 1:

1. freeze upstream pins;
2. complete physical-device matrix;
3. complete start-to-credits restored playthrough;
4. resolve or disclose every release blocker;
5. confirm DinoMod permission/license;
6. run source safety audit;
7. build clean device archive;
8. package unsigned IPA;
9. inspect package file-by-file;
10. prove no ROM/save/private data;
11. prove no provisioning profile or maintainer identity;
12. include required notices;
13. compute SHA-256;
14. install the exact packaged IPA through the documented self-signing workflow;
15. import ROM;
16. launch Restored Adventure;
17. save/relaunch;
18. update in place if the workflow supports it;
19. tag source;
20. publish release and checksum;
21. immediately verify release asset and links.

If any gate fails, do not publish.

---

## 16. Required `docs/STATUS.md` format

Maintain this exact high-level format:

```markdown
# DinoPad Status

Last updated: <UTC timestamp>
Current commit: <SHA>
Current phase: <phase>
Active goal: <one goal>

## Green
- ...

## Red / blocked
- ...

## Last successful commands
```sh
...
```

## Current evidence
- ...

## Current upstream pins
- ...

## Risks
- ...

## Next three candidate goals
1. ...
2. ...
3. ...

## Selected next goal
...
```

There must be only one active goal.

---

## 17. Per-cycle report format

At the end of every cycle, report:

```text
Goal:
Result: PASS / PARTIAL / BLOCKED / FAIL

Changed:
- ...

Verified:
- command
- target
- duration
- evidence

Not verified:
- ...

Cleanup:
- macOS DinoPad process: stopped
- booted Simulators: 0
- runtime lock: released

Docs updated:
- ...

Next goal:
- ...
```

Do not produce a vague narrative in place of this state.

---

## 18. Completion condition

Continue the loop until the full Definition of Done in `docs/IMPLEMENTATION_PLAN.md` is checked and backed by evidence.

The project is not complete merely because:

- the game boots;
- the title screen appears;
- a Simulator build exists;
- touch buttons render;
- DinoMod compiles;
- an IPA is produced;
- a social post can be recorded.

It is complete when a real user can:

1. obtain the ROM-free DinoPad source or unsigned IPA;
2. sign/install it;
3. import their own exact supported ROM;
4. choose the recommended Restored Adventure;
5. play comfortably with touch or controller;
6. save and resume;
7. update without losing private data;
8. understand Prototype Mode and the restoration boundary;
9. rely on accurate documentation and known-issue disclosure.

Begin with the first unchecked goal in `docs/IMPLEMENTATION_PLAN.md`.
