import Foundation
import Security

/// Thin wrapper around the Keychain for storing auth tokens.
/// Service name is the bundle ID so iOS and Mac Catalyst share an item store
/// (the OS handles the divergence transparently).
struct KeychainService {
    enum Key: String {
        case accessToken = "auth.access_token"
        case refreshToken = "auth.refresh_token"
        case dohToken = "dns.doh_token"
        case cachedUserJSON = "auth.cached_user"
    }

    static func set(_ value: String, for key: Key) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.bundleID,
            kSecAttrAccount as String: key.rawValue,
        ]
        let attrs: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    static func get(_ key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.bundleID,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data, let s = String(data: data, encoding: .utf8) else {
            return nil
        }
        return s
    }

    static func delete(_ key: Key) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.bundleID,
            kSecAttrAccount as String: key.rawValue,
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func clearAll() {
        for key in [Key.accessToken, .refreshToken, .dohToken, .cachedUserJSON] {
            delete(key)
        }
    }
}
