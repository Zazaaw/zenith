// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation
import PocketKit

/// What the iPhone app and its widgets share, besides the pairing
/// (`PairingStore`): a small file in the App Group's container with the
/// Mac's newest state, this iPhone's and its Watch's batteries. The app
/// writes it as it hears the Mac; a widget reads it, and reads the Mac's
/// box itself (and writes the file) when it is old or missing. A build that
/// can't sign the group keeps the file in its own folder, where only that
/// target sees it.
enum WidgetVault {
    static let appGroup = "group.id.satuvisual.zenith.pocket"
    private static let fileName = "widgets.json"

    private static var url: URL? {
        let folder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
            ?? (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
        return folder?.appendingPathComponent(fileName)
    }

    static func load() -> PocketWidgetSnapshot? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? PocketWidgetSnapshot(data: data)
    }

    /// nil removes the file (unpaired).
    static func save(_ snapshot: PocketWidgetSnapshot?) {
        guard let url else { return }
        guard let snapshot, let data = try? snapshot.data() else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    /// The file, with the Mac's box read straight from the relay when what
    /// it holds is older than `refetchAfter` (or the file is missing), and
    /// saved again when the box was newer. `force` reads the box regardless.
    static func current(_ pairing: PocketPairing, now: Date = Date(), force: Bool = false) async -> PocketWidgetSnapshot {
        let saved = load() ?? PocketWidgetSnapshot()
        let age = now.timeIntervalSince(saved.mac?.heardAt ?? .distantPast)
        guard force || age > PocketWidgetPresentation.refetchAfter,
              let envelope = try? await PocketCourier(pairing: pairing, me: .phone).macState() else { return saved }
        // Reread: the app may have written while the box was on its way.
        let latest = load() ?? saved
        let next = latest.with(envelope.body, sentAt: envelope.sentAt, heardAt: min(envelope.sentAt, Date()))
        if next != latest { save(next) }
        return next
    }
}
