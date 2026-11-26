// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation
import PocketKit
import Security

/// What the Watch app and its complications share.
///
/// The pairing (with its key) sits in the Watch's Keychain, on this device
/// only, in an access group both targets hold, so a complication can read
/// the Mac's box itself. The latest state goes into a small file in the App
/// Group's container, so a complication shows what the app last saw without
/// a request. Either may be missing (an older install, or a team that can't
/// sign the group): the Keychain then falls back to the app's own items and
/// the file to the app's own folder, and a complication fetches the box.
enum WatchVault {
    static let appGroup = "group.id.satuvisual.zenith.pocket"
    private static let service = "id.satuvisual.zenith.pocket.watch"
    private static let account = "pairing"
    private static let snapshotName = "snapshot.json"

    // MARK: Pairing

    /// `$(AppIdentifierPrefix)id.satuvisual.zenith.pocket.shared`, from the
    /// Info.plist (the prefix is the team, known only when signed).
    private static var accessGroup: String? {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "PocketKeychainGroup") as? String,
              !group.isEmpty, !group.hasPrefix(".") else { return nil }
        return group
    }

    private static func query(group: String?) -> [String: Any] {
        var q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: service,
                                kSecAttrAccount as String: account]
        if let group { q[kSecAttrAccessGroup as String] = group }
        return q
    }

    static func loadPairing() -> PocketPairing? {
        for group in [accessGroup, nil] {
            var request = query(group: group)
            request[kSecReturnData as String] = true
            request[kSecMatchLimit as String] = kSecMatchLimitOne
            var item: CFTypeRef?
            if SecItemCopyMatching(request as CFDictionary, &item) == errSecSuccess, let data = item as? Data,
               let pairing = try? JSONDecoder().decode(PocketPairing.self, from: data) {
                return pairing
            }
        }
        return nil
    }

    @discardableResult
    static func savePairing(_ pairing: PocketPairing) -> Bool {
        guard let data = try? JSONEncoder().encode(pairing) else { return false }
        deletePairing()
        for group in [accessGroup, nil] {
            var item = query(group: group)
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            if SecItemAdd(item as CFDictionary, nil) == errSecSuccess { return true }
        }
        return false
    }

    static func deletePairing() {
        for group in [accessGroup, nil] { SecItemDelete(query(group: group) as CFDictionary) }
    }

    // MARK: Snapshot

    private static var folder: URL? {
        if let shared = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) { return shared }
        return try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    }

    /// Whether the complications can read what the app writes.
    static var sharesFiles: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) != nil
    }

    static func loadSnapshot() -> PocketWatchSnapshot? {
        guard let url = folder?.appendingPathComponent(snapshotName), let data = try? Data(contentsOf: url) else { return nil }
        return try? PocketWatchContext.decode(PocketWatchSnapshot.self, from: data)
    }

    static func saveSnapshot(_ snapshot: PocketWatchSnapshot?) {
        guard let url = folder?.appendingPathComponent(snapshotName) else { return }
        guard let snapshot, let data = try? PocketWatchContext.encode(snapshot) else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    // MARK: The box

    /// The Mac's box, read straight from the relay, trimmed for the Watch.
    static func fetch(_ pairing: PocketPairing) async throws -> PocketWatchSnapshot? {
        guard let envelope = try await PocketCourier(pairing: pairing, me: .watch).macState() else { return nil }
        return PocketWatchSnapshot(state: PocketWatchPresentation.trimmed(envelope.body), sentAt: envelope.sentAt,
                                   heardAt: min(envelope.sentAt, Date()))
    }
}
