import Foundation

/// The source category remembered by FR19. The exact display/window/region is
/// intentionally not persisted because FR19 only asks for the last source type.
public enum SavedSourceType: String, Codable, Equatable, Sendable {
    case display
    case window
    case region

    public init(source: CaptureSource) {
        switch source {
        case .display:
            self = .display
        case .window:
            self = .window
        case .region:
            self = .region
        }
    }
}

/// FR19 settings that survive between launches.
public struct UserSettings: Codable, Equatable, Sendable {
    public static let defaults = UserSettings(
        targetLanguage: "English",
        lastSourceType: nil
    )

    public var targetLanguage: String
    public var lastSourceType: SavedSourceType?

    public init(targetLanguage: String, lastSourceType: SavedSourceType?) {
        self.targetLanguage = targetLanguage
        self.lastSourceType = lastSourceType
    }
}

/// FR19: Save User Settings.
///
/// Settings are stored as one Codable value in UserDefaults. Keeping both
/// values together makes damaged/incomplete data easy to detect: loading falls
/// back to English + no source selected instead of crashing.
public final class UserSettingsStore: @unchecked Sendable {
    private static let storageKey = "GlossaPane.UserSettings.v1"

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func save(_ settings: UserSettings) {
        var normalized = settings
        if normalized.targetLanguage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            normalized.targetLanguage = UserSettings.defaults.targetLanguage
        }

        guard let data = try? encoder.encode(normalized) else {
            return
        }
        defaults.set(data, forKey: Self.storageKey)
    }

    /// Convenience used by the UI when the user changes language/source.
    public func save(targetLanguage: String, source: CaptureSource?) {
        save(UserSettings(
            targetLanguage: targetLanguage,
            lastSourceType: source.map(SavedSourceType.init(source:))
        ))
    }

    /// Loads saved settings. Missing or damaged data safely returns FR19's
    /// required defaults: English and no source selected.
    public func load() -> UserSettings {
        guard
            let data = defaults.data(forKey: Self.storageKey),
            let settings = try? decoder.decode(UserSettings.self, from: data),
            !settings.targetLanguage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return .defaults
        }
        return settings
    }

    /// Useful for sign-out/reset flows and for tests.
    public func reset() {
        defaults.removeObject(forKey: Self.storageKey)
    }
}
