import Foundation

#if os(macOS)
import Security
#endif

/// Keeps the translation service key in the macOS Keychain, so it is never
/// written in the source code, a settings file, or a log (NFR3).
public enum APIKeyStore {

    #if os(macOS)

    private static let service = "GlossaPane.TranslationAPIKey"
    private static let account = "default"

    @discardableResult
    public static func save(_ key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)

        var add = query
        add[kSecValueData as String] = Data(key.utf8)
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    public static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    #else

    /// API key storage is unavailable outside macOS.
    /// This implementation exists only for cross-platform compilation.
    @discardableResult
    public static func save(_ key: String) -> Bool {
        return false
    }

    public static func load() -> String? {
        return nil
    }

    #endif
}
