import Foundation

/// Whether the operating system allows this app to record the screen.
public enum PermissionStatus: Equatable, Sendable {
    case granted
    case notGranted
}

/// Anything that can check and request screen recording permission.
/// The real one asks macOS. The tests use a fake one.
public protocol ScreenRecordingPermission: Sendable {
    /// Checks the current permission without showing anything to the user.
    func currentStatus() -> PermissionStatus

    /// Asks the operating system for permission. macOS only shows its own
    /// prompt the first time; after that this just reports the status.
    func request() -> PermissionStatus

    /// Opens the Screen Recording page in the system privacy settings.
    @MainActor func openSystemSettings()
}

/// What the main window should do after the permission check (FR6).
public enum PermissionCheckResult: Equatable, Sendable {
    /// Capture may start.
    case granted
    /// Show `explanation` with an "Open System Settings" button. Do not start.
    case needsPermission(explanation: String)
}

/// FR6: Request Screen Recording Permission.
///
/// Call `checkBeforeStart()` when the user clicks Start. Nothing may be
/// captured unless it returns `.granted`. If the user closes the explanation
/// without granting permission, stay stopped and show `deniedMessage`.
public struct PermissionGate: Sendable {
    public static let explanation =
        "GlossaPane needs Screen Recording permission to read the text on your screen. "
        + "Screen images stay on this computer and are never saved. "
        + "Only the recognized text is sent for translation. "
        + "Turn on GlossaPane in System Settings > Privacy & Security > Screen Recording, then restart GlossaPane."

    public static let deniedMessage = "Screen recording permission is required"

    private let permission: any ScreenRecordingPermission

    public init(permission: any ScreenRecordingPermission) {
        self.permission = permission
    }

    /// Checks permission, and asks the system for it if it has not been given yet.
    public func checkBeforeStart() -> PermissionCheckResult {
        if permission.currentStatus() == .granted {
            return .granted
        }
        if permission.request() == .granted {
            return .granted
        }
        return .needsPermission(explanation: Self.explanation)
    }

    /// For the "Open System Settings" button next to the explanation.
    @MainActor public func openSystemSettings() {
        permission.openSystemSettings()
    }
}

#if os(macOS)
import AppKit
import CoreGraphics

/// Uses the macOS screen recording permission (Privacy & Security > Screen Recording).
public struct SystemScreenRecordingPermission: ScreenRecordingPermission {
    public static let settingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
    )!

    public init() {}

    public func currentStatus() -> PermissionStatus {
        CGPreflightScreenCaptureAccess() ? .granted : .notGranted
    }

    public func request() -> PermissionStatus {
        CGRequestScreenCaptureAccess() ? .granted : .notGranted
    }

    @MainActor public func openSystemSettings() {
        NSWorkspace.shared.open(Self.settingsURL)
    }
}
#endif
