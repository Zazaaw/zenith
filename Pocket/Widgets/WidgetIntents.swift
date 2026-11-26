// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppIntents
import PocketKit
import WidgetKit

/// A command from a widget, sent where it runs (the widget
/// extension): sealed as the iPhone over REST broadcast, as the Watch sends
/// its own. Nothing hears the Mac's reply here, so the Mac is asked for a
/// fresh box and the box is read until it shows the change (a few seconds
/// at most), then the widgets reload.
enum WidgetCommand {
    static let confirmDelays: [TimeInterval] = [2.5, 5]

    static func send(_ command: PocketCommand) async throws {
        guard let pairing = PairingStore.load() else { throw WidgetCommandError.notPaired }
        let before = await WidgetVault.current(pairing)
        guard PocketPresentation.freshness(heardAt: before.mac?.heardAt, live: false, now: Date()).isReachable else {
            throw WidgetCommandError.unreachable
        }
        let courier = PocketCourier(pairing: pairing, me: .phone)
        do {
            try await courier.send(.command(command))
        } catch {
            throw WidgetCommandError.failed
        }
        try? await Task.sleep(for: .seconds(1))
        _ = try? await courier.send(.command(.refresh))
        var waited: TimeInterval = 1
        for delay in confirmDelays {
            try? await Task.sleep(for: .seconds(max(0, delay - waited)))
            waited = delay
            let after = await WidgetVault.current(pairing, force: true)
            if let state = after.mac?.state,
               PocketWatchPresentation.confirms(command, before: before.mac?.state, after: state) != false { break }
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}

enum WidgetCommandError: Error, CustomLocalizedStringResourceConvertible {
    case notPaired, unreachable, failed

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notPaired: return "Open Pocket to pair it with your Mac."
        case .unreachable: return "Your Mac is out of reach right now."
        case .failed: return "Pocket couldn't reach your Mac. Try again."
        }
    }
}

struct LockMacIntent: AppIntent {
    static let title: LocalizedStringResource = "Lock Mac"
    static let description = IntentDescription("Locks your Mac through Zenith.")

    func perform() async throws -> some IntentResult {
        try await WidgetCommand.send(.lock)
        return .result()
    }
}
