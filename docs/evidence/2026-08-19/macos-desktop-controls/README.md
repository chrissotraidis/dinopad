# macOS desktop controls smoke

Target: packaged arm64 `DinoPad.app` on Mac15,9, macOS 26.5.2.

The guarded smoke starts Prototype Mode with a disposable data root and fresh
bindings, then verifies the actual N64 input log for WASD, A/B/Z/Start, all C
buttons, the D-pad, and L/R. It also verifies an Option+Return transition from
960x752 window geometry to 1728x1084 fullscreen geometry, observes resident
memory for 45 warm seconds, and performs bounded guarded cleanup. Graceful
window-close behavior remains covered by the dedicated repeated shutdown smoke.

`memory.tsv`, `windowed.png`, and `result.txt` are retained here. The same smoke
also generates a detailed `runtime.log`, which remains ignored because runtime
logs can contain private local state. Run the evidence flow with:

```sh
DINOPAD_ALLOW_UI_AUTOMATION=1 \
  scripts/runtime-guard.sh macos scripts/smoke-desktop-controls-macos.sh
```

This interactive automation takes over the active Mac window, keyboard, and
fullscreen Space for about two minutes. The final uninterrupted rerun was not
performed after the user asked that UI automation stop; see `result.txt`.

Physical left-click A and right-click B remain a manual acceptance item because
macOS filters synthetic mouse-button injection from the automation harness.
The mappings themselves are part of the fresh-profile defaults.
