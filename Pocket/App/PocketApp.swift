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
    @AppStorage(ThemeChoice.key) private var theme = ThemeChoice.system
    /// The splash plays once per launch, not on every return to the app.
    @State private var splashDone = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                // The app arrives as the splash leaves, so its entrances
                // play in the crossfade instead of under the splash.
                if splashDone {
                    RootView()
                        .transition(.opacity)
                } else {
                    SplashView {
                        withAnimation(.easeOut(duration: 0.5)) { splashDone = true }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 1.04)))
                    .zIndex(1)
                }
            }
            .environment(model)
            .preferredColorScheme(theme.scheme)
            // The iPhone Camera app opens Zenith's QR code here, and a
            // widget its tab.
            .onOpenURL { url in
                if let tab = PocketModel.Tab(route: url) {
                    model.showingSettings = false
                    model.tab = tab
                } else if !model.open(url) { model.show("That isn't a Zenith pairing code.", ok: false) }
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
