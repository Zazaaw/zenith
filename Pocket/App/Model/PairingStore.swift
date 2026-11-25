// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation
import PocketKit
import Security

/// The pairing (with its key) in the iOS Keychain: on this device only, and
/// readable after the first unlock so the background battery report can
/// seal its box while the phone is locked.
enum PairingStore {
    private static let service = "id.satuvisual.zenith.pocket"
    private static let account = "pairing"

    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    static func load() -> PocketPairing? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(PocketPairing.self, from: data)
    }

    @discardableResult
    static func save(_ pairing: PocketPairing) -> Bool {
        guard let data = try? JSONEncoder().encode(pairing) else { return false }
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    static func delete() {
        SecItemDelete(query as CFDictionary)
    }
}
