// window_id.swift - print the CGWindowID and pixel bounds of the first
// on-screen window owned by the given process name.
//
// Usage: window_id <owner-name>
// Output: <id> <x> <y> <w> <h>  (pixel coordinates, global display space)
//
// Used by scripts/capture-window.sh to capture exactly the DinoPad window
// without including unrelated desktop content.

import CoreGraphics
import Foundation

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write("usage: window_id <owner-name>\n".data(using: .utf8)!)
    exit(2)
}
let owner = CommandLine.arguments[1]

let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
    exit(1)
}

for w in windows {
    guard let name = w[kCGWindowOwnerName as String] as? String, name == owner else {
        continue
    }
    guard let num = w[kCGWindowNumber as String] as? Int,
          let bounds = w[kCGWindowBounds as String] as? [String: Any] else {
        continue
    }
    let x = bounds["X"] as? Int ?? 0
    let y = bounds["Y"] as? Int ?? 0
    let bw = bounds["Width"] as? Int ?? 0
    let bh = bounds["Height"] as? Int ?? 0
    print("\(num) \(x) \(y) \(bw) \(bh)")
    exit(0)
}

exit(1)
