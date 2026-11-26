// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation
import PocketKit
import Security

/// The pairing (with its key) in the iOS Keychain: on this device only, and
/// readable after the first unlock so the background battery report can
/// seal its box while the phone is locked.
///
/// It lives in an access group the app and its widgets both hold, so a
/// widget reads the Mac's box and sends a command itself. A pairing saved
/// before the widgets came sits in the app's own group: `share()` copies it
/// across on launch and leaves the old item as it was. A build that can't
/// sign the group (no team) keeps to the app's own items.
enum PairingStore {
    private static let service = "id.satuvisual.zenith.pocket"
    private static let account = "pairing"

    /// `$(AppIdentifierPrefix)id.satuvisual.zenith.pocket.shared`, from the
    /// Info.plist (the prefix is the team, known only when signed).
    private static var sharedGroup: String? {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "PocketKeychainGroup") as? String,
              !group.isEmpty, !group.hasPrefix(".") else { return nil }
        return group
    }

    private static func query(group: String? = nil) -> [String: Any] {
        var q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: service,
                                kSecAttrAccount as String: account]
        if let group { q[kSecAttrAccessGroup as String] = group }
        return q
    }

    /// Without a group the search covers every group this target holds: the
    /// shared one first for a widget, either for the app.
    static func load() -> PocketPairing? {
        for group in [sharedGroup, nil] {
            if let data = read(group: group), let pairing = try? JSONDecoder().decode(PocketPairing.self, from: data) {
                return pairing
            }
        }
        return nil
    }

    private static func read(group: String?) -> Data? {
        var request = query(group: group)
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }

    @discardableResult
    static func save(_ pairing: PocketPairing) -> Bool {
        guard let data = try? JSONEncoder().encode(pairing) else { return false }
        delete()
        return add(data, group: sharedGroup) || add(data, group: nil)
    }

    private static func add(_ data: Data, group: String?) -> Bool {
        var item = query(group: group)
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    /// Copies a pairing kept only in the app's own group into the shared one.
    static func share() {
        guard let group = sharedGroup, read(group: group) == nil, let data = read(group: nil) else { return }
        _ = add(data, group: group)
    }

    /// Every copy, in every group this target holds.
    static func delete() {
        for group in [sharedGroup, nil] { SecItemDelete(query(group: group) as CFDictionary) }
    }
}
