import Foundation
@testable import GlossaCapture

/// A 10 x 10 frame (100 pixels), so 1 changed pixel = 1 percent.
func makeFrame(changedPixels: Int = 0, width: Int = 10, height: Int = 10, source: CaptureSource = .display(id: "1")) -> CapturedFrame {
    var pixels = [UInt32](repeating: 0xFF00_0000, count: width * height)
    for index in 0..<min(changedPixels, pixels.count) {
        pixels[index] = 0xFFFF_FFFF
    }
    return CapturedFrame(
        width: width,
        height: height,
        pixels: pixels,
        screenFrame: ScreenRect(x: 0, y: 0, width: Double(width), height: Double(height)),
        scale: 1,
        source: source
    )
}

/// Pretends to be the macOS permission.
final class FakePermission: ScreenRecordingPermission, @unchecked Sendable {
    private let lock = NSLock()
    private var status: PermissionStatus
    private let grantOnRequest: Bool
    private var _requestCount = 0
    private var _settingsOpened = 0

    init(status: PermissionStatus, grantOnRequest: Bool = false) {
        self.status = status
        self.grantOnRequest = grantOnRequest
    }

    var requestCount: Int { lock.withLock { _requestCount } }
    var settingsOpened: Int { lock.withLock { _settingsOpened } }

    func currentStatus() -> PermissionStatus {
        lock.withLock { status }
    }

    func request() -> PermissionStatus {
        lock.withLock {
            _requestCount += 1
            if grantOnRequest { status = .granted }
            return status
        }
    }

    @MainActor func openSystemSettings() {
        lock.withLock { _settingsOpened += 1 }
    }
}

/// Returns the queued results in order, then repeats the last one.
actor FakeCapturer: ScreenCapturer {
    enum Step {
        case frame(CapturedFrame)
        case fail
    }

    private var steps: [Step]
    private(set) var captureCount = 0

    init(_ steps: [Step]) {
        self.steps = steps
    }

    func capture(_ source: CaptureSource) async throws -> CapturedFrame {
        captureCount += 1
        let step = steps.count > 1 ? steps.removeFirst() : steps[0]
        switch step {
        case .frame(let frame):
            return frame
        case .fail:
            throw CaptureError.failed("fake failure")
        }
    }
}
