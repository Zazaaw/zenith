// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation
import Security

/// Zenith fork: the personal WakaTime token, kept by `ZenithSecretStore` as an
/// owner-only file (see there for why not the Keychain).
///
/// Earlier builds kept it in the login Keychain. The first read without a file
/// moves it over once: that read may ask for the keychain password one last time.
enum WakaTimeTokenStore {
    private static let name = "wakatime-token"
    private static let legacyService = "id.satuvisual.zenith.wakatime"
    private static let legacyAccount = "personal-token"

    static func read() -> String? {
        if let token = ZenithSecretStore.read(name) { return token }
        guard let legacy = readLegacyKeychain() else { return nil }
        if ZenithSecretStore.save(legacy, as: name) { deleteLegacyKeychain() }
        return legacy
    }

    @discardableResult
    static func save(_ token: String) -> Bool {
        ZenithSecretStore.save(token, as: name)
    }

    static func delete() {
        ZenithSecretStore.delete(name)
        deleteLegacyKeychain()
    }

    // MARK: Legacy Keychain item

    private static var legacyQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: legacyService,
         kSecAttrAccount as String: legacyAccount]
    }

    private static func readLegacyKeychain() -> String? {
        var item: CFTypeRef?
        var search = legacyQuery
        search[kSecReturnData as String] = true
        search[kSecMatchLimit as String] = kSecMatchLimitOne
        guard SecItemCopyMatching(search as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data, let token = String(data: data, encoding: .utf8),
              !token.isEmpty else { return nil }
        return token
    }

    private static func deleteLegacyKeychain() {
        SecItemDelete(legacyQuery as CFDictionary)
    }
}
