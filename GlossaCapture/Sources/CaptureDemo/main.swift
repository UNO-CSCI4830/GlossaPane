// Tries FR6, FR7 and FR8 on a real Mac.
//
// Usage:
//   swift run CaptureDemo list                          (show display and window ids)
//   swift run CaptureDemo display 1                     (capture a display for 10 seconds)
//   swift run CaptureDemo window 4521
//   swift run CaptureDemo region 100 200 500 300
//
// The first time, macOS asks for Screen Recording permission for the app that
// runs this (Terminal, iTerm, or Xcode). Turn it on, then restart that app.

import Foundation
import GlossaCapture

#if os(macOS)
@preconcurrency import ScreenCaptureKit

let args = Array(CommandLine.arguments.dropFirst())
let usage = "Usage: swift run CaptureDemo list | display <id> | window <id> | region <x> <y> <width> <height>"

// FR6: check permission before capturing anything.
let gate = PermissionGate(permission: SystemScreenRecordingPermission())
if case .needsPermission(let explanation) = gate.checkBeforeStart() {
    print(explanation)
    print(PermissionGate.deniedMessage)
    gate.openSystemSettings()
    exit(1)
}

let source: CaptureSource
switch args.first ?? "" {
case "list":
    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    print("Displays:")
    for display in content.displays {
        print("  \(display.displayID)   \(Int(display.width)) x \(Int(display.height))")
    }
    print("Windows:")
    for window in content.windows where window.isOnScreen && (window.title?.isEmpty == false) {
        let app = window.owningApplication?.applicationName ?? "?"
        print("  \(window.windowID)   \(app): \(window.title ?? "")")
    }
    exit(0)
case "display" where args.count == 2:
    source = .display(id: args[1])
case "window" where args.count == 2:
    source = .window(id: args[1])
case "region" where args.count == 5:
    let numbers = args.dropFirst().compactMap { Int($0) }
    guard numbers.count == 4 else { print(usage); exit(1) }
    source = .region(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])
default:
    print(usage)
    exit(1)
}

let controller = CaptureController(
    capturer: SystemScreenCapturer(),
    permission: SystemScreenRecordingPermission()
)

print("Capturing \(source) once per second for 10 seconds. Change something on screen to see FR8 work.")
do {
    try await controller.start(source: source) { event in
        let time = Date().formatted(date: .omitted, time: .standard)
        switch event {
        case .changed(let frame):
            print("\(time)  changed -> send to OCR   \(frame.width)x\(frame.height) px at \(frame.screenFrame)")
        case .unchanged:
            print("\(time)  unchanged -> skip, keep overlays")
        case .captureFailed(let count):
            print("\(time)  capture failed (\(count) in a row), trying again")
        case .stopped(let message):
            print("\(time)  stopped: \(message)")
        }
    }
} catch let error as CaptureError {
    print(error.userMessage)
    exit(1)
}

try await Task.sleep(for: .seconds(10))
await controller.stop()
print("Done.")
#else
print("CaptureDemo needs macOS (NFR6).")
#endif
