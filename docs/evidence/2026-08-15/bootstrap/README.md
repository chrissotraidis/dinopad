# Evidence: Phase 0 repository bootstrap

Date: 2026-08-15
Commit: 7c42e58 (upstream pins; cycle commits 96f8377, 7c42e58)
Target: none (repository bootstrap, no runtime)

## Commands

```sh
git clone --branch v0.3.0 --recursive https://github.com/DinosaurPlanetRecomp/dino-recomp.git ref/dino-recomp
git clone --branch v0.9.3 https://github.com/EoinODoodles/dinomod-enhanced-recompiled.git ref/dinomod-enhanced-recompiled
git -C ref/<checkout> remote set-url --push origin DISABLED   # applied to all three checkouts
git -C ref/dinomod-enhanced-recompiled submodule update --init
./scripts/bootstrap.sh
./scripts/check-repo-safety.sh
./scripts/report-size.sh
./scripts/runtime-guard.sh macos sleep 4        # acquire/run/cleanup/release
./scripts/runtime-guard.sh macos echo rejected  # concurrent launch rejected, rc=1
```

## Result

- PASS: all three reference checkouts resolve to exact pins, worktrees clean, push URLs disabled.
- PASS: repository safety audit (8 checks) green.
- PASS: runtime guard acquires atomically, rejects concurrent launches, cleans up, releases the lock.
- PASS: bootstrap reproduces the pinned setup from scratch.

## Resolved pins

| Checkout | Ref | Commit |
|---|---|---|
| ref/paperpad | 644945d4bc4facbbd8ecda8cdfd37ae64e7993fa | 644945d4bc4facbbd8ecda8cdfd37ae64e7993fa |
| ref/dino-recomp | v0.3.0 | 725b2ede9cacc57968e0a028efed8df9235ba483 (9 submodules pinned) |
| ref/dinomod-enhanced-recompiled | v0.9.3 | d79e86be2304cba75216b0b98e9fb53ee99b7500 (2 submodules) |

## Cleanup

- macOS DinoPad process: none launched (stopped)
- booted Simulators: 0
- runtime lock: released
