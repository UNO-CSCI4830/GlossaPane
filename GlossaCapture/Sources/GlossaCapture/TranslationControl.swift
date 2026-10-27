import Foundation

/// FR1: Start and Stop Translation.
///
/// This small controller sits above `CaptureController`. It owns the source
/// selected by the UI and gives the rest of the app one start/stop control.
/// Capture events are forwarded to the integration pipeline (FR20), while the
/// stop hook lets the overlay layer clear anything currently displayed.
public actor TranslationControl {
    public static let noSourceMessage = "Please select a source first"

    public enum State: Equatable, Sendable {
        case stopped
        case running
    }

    public enum ControlError: Error, Equatable, Sendable {
        case noSourceSelected

        public var userMessage: String {
            TranslationControl.noSourceMessage
        }
    }

    public typealias EventHandler = @Sendable (CaptureEvent) async -> Void
    public typealias StopHandler = @Sendable () async -> Void

    private let startCapture: @Sendable (CaptureSource, @escaping EventHandler) async throws -> Void
    private let stopCapture: @Sendable () async -> Void
    private let onStopped: StopHandler

    public private(set) var selectedSource: CaptureSource?
    public private(set) var state: State = .stopped

    /// Production initializer. It connects directly to AJ's `CaptureController`.
    public init(
        captureController: CaptureController,
        onStopped: @escaping StopHandler = {}
    ) {
        self.startCapture = { source, handler in
            try await captureController.start(source: source, onEvent: handler)
        }
        self.stopCapture = {
            await captureController.stop()
        }
        self.onStopped = onStopped
    }

    /// Test/integration initializer. It also makes the control easy to connect
    /// to another capture implementation without changing FR1 logic.
    public init(
        startCapture: @escaping @Sendable (CaptureSource, @escaping EventHandler) async throws -> Void,
        stopCapture: @escaping @Sendable () async -> Void,
        onStopped: @escaping StopHandler = {}
    ) {
        self.startCapture = startCapture
        self.stopCapture = stopCapture
        self.onStopped = onStopped
    }

    /// Called by the source picker (display, window, or region).
    public func selectSource(_ source: CaptureSource?) {
        selectedSource = source
    }

    /// Starts the capture pipeline for the currently selected source.
    ///
    /// If no source is selected, FR1 requires the exact message
    /// "Please select a source first" and capture must not start.
    public func start(onEvent: @escaping EventHandler) async throws {
        guard let selectedSource else {
            state = .stopped
            throw ControlError.noSourceSelected
        }

        do {
            try await startCapture(selectedSource, onEvent)
            state = .running
        } catch {
            state = .stopped
            throw error
        }
    }

    /// Stops capture/translation and asks the overlay layer to clear itself.
    public func stop() async {
        await stopCapture()
        state = .stopped
        await onStopped()
    }
}
