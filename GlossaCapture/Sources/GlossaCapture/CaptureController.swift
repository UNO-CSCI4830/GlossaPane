import Foundation

/// Anything that can take one picture of a capture source.
/// The real one uses ScreenCaptureKit. The tests use a fake one.
public protocol ScreenCapturer: Sendable {
    func capture(_ source: CaptureSource) async throws -> CapturedFrame
}

public enum CaptureError: Error, Equatable, Sendable {
    /// Screen recording permission has not been granted (FR6).
    case permissionDenied
    /// The selected source has empty or impossible values.
    case invalidSource
    /// The display or window could not be found (closed, unplugged, minimized).
    case sourceNotFound(String)
    /// The system failed to capture the image.
    case failed(String)

    /// Short message the main window can show to the user.
    public var userMessage: String {
        switch self {
        case .permissionDenied:
            return PermissionGate.deniedMessage
        case .invalidSource:
            return "Please select a source first"
        case .sourceNotFound, .failed:
            return CaptureController.captureFailedMessage
        }
    }
}

/// What happened in one capture cycle.
public enum CaptureEvent: Equatable, Sendable {
    /// 2 percent or more of the pixels changed. Send this frame to OCR (FR8).
    case changed(CapturedFrame)
    /// Less than 2 percent changed. Skip OCR and keep the current overlays (FR8).
    case unchanged
    /// The capture failed. It will be tried again on the next cycle (FR7).
    case captureFailed(consecutiveFailures: Int)
    /// 3 captures failed in a row, so capture has stopped. Stop translation
    /// and show `message` (FR7).
    case stopped(message: String)
}

/// FR7: Capture Selected Source (and runs FR8 on every frame).
///
/// While running, it captures the selected source once every second, checks
/// whether the image changed, and reports each result through `onEvent`.
/// It will not start without screen recording permission (FR6).
public actor CaptureController {
    public static let defaultInterval: Duration = .seconds(1)
    public static let maxConsecutiveFailures = 3
    public static let captureFailedMessage = "Screen capture failed"

    private let capturer: any ScreenCapturer
    private let permission: any ScreenRecordingPermission
    private let interval: Duration
    private var detector: ChangeDetector

    private var source: CaptureSource?
    private var consecutiveFailures = 0
    private var loopTask: Task<Void, Never>?
    private var runID = 0

    public private(set) var isRunning = false

    public init(
        capturer: any ScreenCapturer,
        permission: any ScreenRecordingPermission,
        interval: Duration = CaptureController.defaultInterval,
        changeThreshold: Double = ChangeDetector.defaultThreshold
    ) {
        self.capturer = capturer
        self.permission = permission
        self.interval = interval
        self.detector = ChangeDetector(threshold: changeThreshold)
    }

    /// Starts capturing `source` once per interval. Each cycle's result is
    /// passed to `onEvent`. Starting again replaces the previous source.
    ///
    /// Throws `CaptureError.permissionDenied` if screen recording is not
    /// allowed, and `CaptureError.invalidSource` if the source is not valid.
    public func start(
        source: CaptureSource,
        onEvent: @escaping @Sendable (CaptureEvent) async -> Void
    ) throws {
        try begin(source: source)
        let id = runID
        loopTask = Task {
            await self.runLoop(id: id, onEvent: onEvent)
        }
    }

    /// Stops capturing and forgets the last frame (NFR4).
    public func stop() {
        isRunning = false
        source = nil
        consecutiveFailures = 0
        detector.reset()
        loopTask?.cancel()
        loopTask = nil
    }

    /// Checks permission and the source, and resets state. `start` calls this;
    /// tests call it directly so they can run cycles without waiting.
    func begin(source: CaptureSource) throws {
        guard permission.currentStatus() == .granted else {
            throw CaptureError.permissionDenied
        }
        guard source.isValid else {
            throw CaptureError.invalidSource
        }
        stop()
        runID += 1
        self.source = source
        isRunning = true
    }

    /// Runs one capture cycle. Returns nil if capture is not running, or if it
    /// was stopped or restarted while the capture was in progress.
    public func runCycle() async -> CaptureEvent? {
        guard isRunning, let source else { return nil }
        let id = runID

        do {
            let frame = try await capturer.capture(source)
            guard isRunning, id == runID else { return nil }
            consecutiveFailures = 0
            switch detector.evaluate(frame) {
            case .process:
                return .changed(frame)
            case .skip:
                return .unchanged
            }
        } catch {
            guard isRunning, id == runID else { return nil }
            consecutiveFailures += 1
            if consecutiveFailures >= Self.maxConsecutiveFailures {
                stop()
                return .stopped(message: Self.captureFailedMessage)
            }
            return .captureFailed(consecutiveFailures: consecutiveFailures)
        }
    }

    private func runLoop(id: Int, onEvent: @Sendable (CaptureEvent) async -> Void) async {
        let clock = ContinuousClock()
        var nextCapture = clock.now

        while isRunning, id == runID, !Task.isCancelled {
            if let event = await runCycle() {
                await onEvent(event)
                if case .stopped = event { return }
            }

            // Keep a steady once-per-interval pace. If a capture took longer
            // than the interval, start the next one right away.
            nextCapture = nextCapture.advanced(by: interval)
            let now = clock.now
            if nextCapture < now {
                nextCapture = now
            }
            do {
                try await clock.sleep(until: nextCapture, tolerance: nil)
            } catch {
                return  // cancelled by stop()
            }
        }
    }
}
