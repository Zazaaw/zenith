// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI
import WatchKit

/// Zenith Pocket on the Apple Watch: the Mac, Claude Code, what plays and
/// the batteries, a page each. It reaches the relay over HTTPS only (no
/// socket, which watchOS keeps from ordinary apps), and gets its pairing
/// from the iPhone app.
@main
struct PocketWatchApp: App {
    @State private var model = WatchModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchRoot()
                .environment(model)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: model.becameActive()
            case .background:
                model.resignedActive()
                BackgroundRefresh.schedule()
            default: break
            }
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.identifier)) {
            await BackgroundRefresh.run(model)
        }
    }
}

/// While the app is closed, watchOS wakes it now and then (more often with
/// a Pocket complication on the face): the Watch's battery goes to the
/// iPhone and the Mac's box to the complications.
enum BackgroundRefresh {
    static let identifier = "id.satuvisual.zenith.pocket.watch.refresh"
    static let interval: TimeInterval = 30 * 60

    @MainActor
    static func schedule() {
        WKApplication.shared().scheduleBackgroundRefresh(withPreferredDate: Date(timeIntervalSinceNow: interval),
                                                         userInfo: identifier as NSString) { _ in }
    }

    @MainActor
    static func run(_ model: WatchModel) async {
        schedule()
        await model.backgroundRefresh()
    }
}
