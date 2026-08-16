# Evidence: native macOS ROM import and rejection

Date: 2026-08-16  
Target: macOS arm64 (Apple M2, macOS 26.5, Xcode 26.6)  
Cycle-start commit: `615e9cc`  
Result: **PASS**

## Result

- The smoke drove the actual AppKit `NSOpenPanel` through System Events; it did
  not call a test-only importer.
- A disposable 64 MiB z64 fixture with one payload byte changed was selected
  first. DinoPad visibly reported Unsupported ROM and left no `dino.z64` in
  the empty destination root.
- The same picker then selected a private v64 fixture produced by swapping each
  byte pair of the supported ROM.
- DinoPad normalized the selected input and atomically stored a big-endian file
  beginning `80371240` with MD5
  `49f7bb346ade39d1915c22e090ffd748`.
- The accepted-import runtime marker appeared and the native DinoPad home became
  available immediately.
- All source/variant/destination files lived in ignored disposable storage and
  were removed by a path-validated cleanup trap. The runtime guard ended with
  no DinoPad process and zero booted Simulators.

## Command

```sh
DINOPAD_IMPORT_EVIDENCE_DIR=docs/evidence/2026-08-16/macos-native-rom-import \
  scripts/runtime-guard.sh macos scripts/smoke-native-rom-import-macos.sh
```

`invalid-rom-rejected.png` and `imported-home.png` are window-only captures.
