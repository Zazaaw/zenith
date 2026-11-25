// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI

/// Zenith Pocket: the Mac's battery, Keep Awake, the lock, Claude Code's
/// sessions and the batteries Zenith reads, from the iPhone.
@main
struct PocketApp: App {
    @State private var model = PocketModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
                // The iPhone Camera app opens Zenith's QR code here.
                .onOpenURL { url in
                    if !model.open(url) { model.show("That isn't a Zenith pairing code.", ok: false) }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: model.becameActive()
            case .background: model.movedToBackground()
            default: break
            }
        }
        .backgroundTask(.appRefresh(BackgroundReport.identifier)) {
            await BackgroundReport.run()
        }
    }
}
