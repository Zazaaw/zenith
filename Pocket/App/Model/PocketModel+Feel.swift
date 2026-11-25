// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation
import PocketKit

/// What the look and feel of the app reads from the model: pull to refresh,
/// the island's "Claude is waiting" card, and how long this build has left.
extension PocketModel {
    /// Pull to refresh: asks the Mac for its state and waits (briefly) for
    /// it to land, so the spinner stays until there is something new.
    func refreshNow() async {
        let before = heardAt
        guard send(.refresh) else { return }
        for _ in 0..<12 {
            try? await Task.sleep(for: .milliseconds(250))
            if heardAt != before { return }
        }
    }

    /// The Claude Code session the island should open on: one holding for a
    /// reply from the phone (Away mode), or one that finished its turn in the
    /// last few minutes. A question for permission is `islandQuestion`'s.
    func waitingSession(now: Date = Date()) -> PocketClaude.Session? {
        guard let sessions = state?.claude?.sessions else { return nil }
        let waiting = sessions.filter { $0.state == .waiting }
        if let held = waiting.first(where: \.acceptsReply) { return held }
        return waiting
            .filter { now.timeIntervalSince($0.waitingSince ?? .distantPast) < Self.waitingFresh }
            .max { ($0.waitingSince ?? .distantPast) < ($1.waitingSince ?? .distantPast) }
    }

    /// A finished turn older than this no longer opens the island.
    static let waitingFresh: TimeInterval = 10 * 60

    // MARK: Provisioning

    /// When this build stops opening: a free Personal Team signs for seven
    /// days, so the date matters. nil outside a provisioned install.
    nonisolated static let buildExpires: Date? = provisioningExpiry()

    /// Whole days left before this build expires, when three or fewer.
    func expiryDaysLeft(now: Date = Date()) -> Int? {
        guard let expires = Self.buildExpires else { return nil }
        let days = Int((expires.timeIntervalSince(now) / 86_400).rounded(.down))
        return days <= 3 ? max(0, days) : nil
    }

    /// `embedded.mobileprovision` is a signed (CMS) wrapper around a plain
    /// XML plist; the plist is read straight out of the bytes.
    nonisolated private static func provisioningExpiry() -> Date? {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex) else { return nil }
        let plist = data.subdata(in: start.lowerBound..<end.upperBound)
        let object = try? PropertyListSerialization.propertyList(from: plist, format: nil)
        return (object as? [String: Any])?["ExpirationDate"] as? Date
    }
}
