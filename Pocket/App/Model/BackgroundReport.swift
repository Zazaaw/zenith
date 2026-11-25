// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import BackgroundTasks
import Foundation
import PocketKit

/// Keeps Zenith's Batteries current while Pocket is closed: iOS wakes the
/// app now and then (as often as it judges, at most every half hour here),
/// and the phone's battery goes into its box. No live channel is opened.
enum BackgroundReport {
    static let identifier = "id.satuvisual.zenith.pocket.report"
    static let interval: TimeInterval = 30 * 60

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: interval)
        try? BGTaskScheduler.shared.submit(request)
    }

    /// One refresh: the next one is asked for first, so a refresh cut short
    /// still keeps the chain going.
    static func run() async {
        schedule()
        guard let pairing = PairingStore.load(), let report = await PhoneBattery.report() else { return }
        try? await PocketLink(pairing: pairing, me: .phone).putBox(pairing.phoneBoxID, report)
    }
}
