# Evidence: graceful RT64 Metal shutdown on macOS

Date: 2026-08-16
Target: macOS arm64 (Apple M2, macOS 26.5, Xcode 26.6)
Cycle-start commit: `8205112`
Result: **PASS (5/5 native window closes, no new crash report)**

## Failure reproduced before the fix

Closing DinoPad during launcher startup previously produced `EXC_BAD_ACCESS`
on the `RT64 Present` thread. The crash was in `objc_release` while the
thread-local autorelease pool drained. At the same time, the graphics thread
was destroying `RT64::PresentQueue`, and the main thread was joining the
runtime event threads. The focused, sanitized stack is in
`crash-before-fix.txt`.

The failure was separate from the generated-code trampoline crash documented
in the full DinoMod evidence. It was a Metal worker lifetime/Objective-C
ownership problem exposed by orderly shutdown.

## Fix

- Stop and join RT64's present and workload queues before Metal-owned
  application resources are destroyed.
- Make queue `stop()` operations idempotent and clear joined thread pointers.
- Add explicit autorelease pools to RT64 worker-thread entry points and the
  per-present loop.
- Balance Plume Metal ownership: do not release autoreleased objects, and
  retain encoders whose later cleanup releases them.

The changes are replayable from:

- `patches/rt64/0001-metal-worker-autorelease-lifetime.patch`
- `patches/plume/0001-metal-ownership-balance.patch`

## Regression

`scripts/smoke-graceful-shutdown-macos.sh` launched the rebuilt binary five
times. Each run opened the native launcher window, closed it through the
standard macOS close button (SDL quit path), exited with status 0, and left no
DinoPad process. The DiagnosticReports count remained 10 before and after the
five runs. The outer runtime guard also confirmed zero booted Simulators.

```sh
cmake --build build-macos --parallel 4 --target DinoPad
scripts/runtime-guard.sh macos \
  scripts/smoke-graceful-shutdown-macos.sh 5
```

See `result.txt` for the compact command result. Per-run raw logs remain in
ignored `.goal-loop/` state because they contain machine-local asset paths.
