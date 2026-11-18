// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation
import Security

/// Zenith fork: the personal WakaTime token, kept in the login Keychain and
/// nowhere else (not in preferences, settings backups or the config file).
enum WakaTimeTokenStore {
    private static let service = "id.satuvisual.zenith.wakatime"
    private static let account = "personal-token"

    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    static func read() -> String? {
        var item: CFTypeRef?
        var search = query
        search[kSecReturnData as String] = true
        search[kSecMatchLimit as String] = kSecMatchLimitOne
        guard SecItemCopyMatching(search as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data, let token = String(data: data, encoding: .utf8),
              !token.isEmpty else { return nil }
        return token
    }

    @discardableResult
    static func save(_ token: String) -> Bool {
        let value = Data(token.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
        guard !value.isEmpty else { return false }
        let update = SecItemUpdate(query as CFDictionary, [kSecValueData as String: value] as CFDictionary)
        if update == errSecSuccess { return true }
        guard update == errSecItemNotFound else { return false }
        var add = query
        add[kSecValueData as String] = value
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        add[kSecAttrLabel as String] = "Zenith WakaTime token"
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    static func delete() {
        SecItemDelete(query as CFDictionary)
    }
}
