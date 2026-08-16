# Evidence: Title screen reached and stable audio loop verified (macOS arm64)

Date: 2026-08-16
Target: macOS arm64 (Apple M2, macOS 26.5, Xcode 26.6)
Goal: Reach the title screen and verify a stable audio loop on macOS
Result: PASS

DinoPad commit (cycle start): 10f6b1d (this cycle's commits follow)
Upstream pins: dino-recomp v0.3.0 = 725b2ed..., dinomod v0.9.3 =
d79e86b... (unchanged; see docs/STATUS.md)

## Commands

```sh
cmake -S . -B build-macos -G Ninja -DCMAKE_BUILD_TYPE=Release -DSDL2_DIR=.../sdl2-install
cmake --build build-macos --parallel 4 --target DinoPad
scripts/runtime-guard.sh macos bash <session-script>   # session scripts under .goal-loop/scratch-title-audio/
```

Launch: `build-macos/DinoPad --skip-launcher --window-width 1024 --window-height 768`
with `DINOPAD_LOG_INPUT=1`, `DINOPAD_LOG_AUDIO=1`, and
`DINOPAD_AUDIO_DUMP=<path>` for the audio-pipeline probe.

## Result

- PASS: the game boots through the December 2000 prototype flow on arm64
  macOS: N64 logo -> Rareware splash -> GAME SELECT -> ENTER NAME ->
  PLAY THIS GAME? -> opening cinematic. Screenshots:
  `boot-n64-logo.jpg`, `boot-rare-splash.jpg`, `game-select.jpg`,
  `name-entry-aaaaa.jpg`, `play-this-game.jpg`, `opening-subtitle.jpg`,
  `opening-dragon.jpg`, `opening-flight.jpg`.
- PASS: a new save is created and named through the game's ENTER NAME screen
  (name "AAAAA"), then confirmed via END -> "PLAY THIS GAME?" -> YES.
- PASS: the opening cinematic renders through RT64 Metal with subtitles
  (authentic prototype text, including its "moutain" typo).
- PASS: stable audio loop. The SDL audio device opens at 48000 Hz / 2 ch and
  `queue_samples` continuously fills it. Over a 95 s session the PCM probe
  captured 36 MB of float32 stereo audio; RMS ~0.09, peak ~0.51, mean spectral
  entropy 5.5 across 96 one-second windows (real, varied program audio, not
  silence or a test tone). No audio errors in the runtime log.
- PASS: stable session. No crash, renderer error, or audio underrun over the
  full menu flow plus the opening cinematic (~2 minutes, longest single
  session 95+ s of audio at stable queue depth).

## Input automation notes (macOS)

Keyboard input reaches the game end-to-end (Space = N64 A, WASD = analog,
Enter = Start, etc.). Held key presses are required for reliable delivery
through `osascript` (quick down/up taps can land between game polls and be
missed). The game's ENTER NAME keyboard responds to the analog stick, not the
D-pad, and its cursor jumps +3 keys per right press; see
`docs/KNOWN_ISSUES.md`.

## Not verified

- Controllable gameplay (input during the playable scene) is the next goal.
- Audio was verified as produced by the recompiled pipeline and queued to an
  opened SDL device; no acoustic playback check (speaker/headphones) was
  performed.
- RmlUi launcher rendering on Metal (still bypassed with --skip-launcher).

## Cleanup

- macOS DinoPad process: stopped (SIGKILL after capture)
- booted Simulators: 0
- runtime lock: released
