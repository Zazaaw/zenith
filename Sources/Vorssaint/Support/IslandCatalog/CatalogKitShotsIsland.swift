// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

#if VORSSAINT_DEVELOPMENT
import AppKit
import SwiftUI

/// Zenith fork: the Island group's pages and the system pages around them
/// (`ONLY=kit-island…`), in Dark and Light Mode: the Dynamic Island page on
/// each tab and at each module of its Modules grid, Lock Screen, Appearance
/// and the app's own pages.
@MainActor
extension CatalogShots {
    static var kitIsland: [CatalogShot] {
        let island: [String: Any] = [DefaultsKey.notchEnabled: true]
        func with(_ extra: [String: Any]) -> [String: Any] { island.merging(extra) { $1 } }
        let pages: [(String, SettingsPage, NotchSettingsLocation?, [String: Any], CGFloat)] = [
            ("island", .notch, nil, island, 1500),
            ("island-content", .notch, .module(.controls), island, 1300),
            ("island-activity", .notch, .activity, island, 1900),
            ("island-behavior", .notch, .behavior, with([ZenithMoreOptionsRule.key("notch.behavior"): true]), 1800),
            // The Modules grid, scrolled to, with each module's settings under it.
            ("calendar", .notch, .module(.calendar), island, 1300),
            ("notifications", .notch, .module(.notifications), island, 1150),
            ("music", .notch, .module(.music), with([ZenithMoreOptionsRule.key("notchMusic"): true]), 1400),
            ("timer", .notch, .module(.timer), island, 1000),
            ("agents", .notch, .module(.agents), with([DefaultsKey.notchAgentsEnabled: true]), 2800),
            ("downloads", .notch, .module(.downloads), island, 1050),
            ("watch", .notch, .module(.watch), with([AppFeature.notchWatch.availabilityKey: true]), 1050),
            ("lockscreen", .lockScreen, nil, with([DefaultsKey.notchLockScreen: true]), 1500),
            ("mascot", .notch, .companion, with([DefaultsKey.notchMascotEnabled: true,
                                                AppFeature.notchMascot.availabilityKey: true]), 2100),
            ("appearance", .appearance, nil, [:], 1500),
            ("shortcuts", .shortcuts, nil, [:], 1300),
            ("advanced", .advanced, nil, [:], 1300),
            ("about", .about, nil, [:], 1300),
            ("whatsnew", .releaseNotes, nil, [:], 1000),
            ("support", .support, nil, [:], 1000),
        ]
        var shots: [CatalogShot] = []
        for (name, page, location, preferences, height) in pages {
            for (suffix, appearance) in [("dark", NSAppearance.Name.darkAqua), ("light", .aqua)] {
                var shot = settings("kit-island-\(name)-\(suffix)", page: page, preferences: preferences, settle: 1.5,
                                    height: height) {
                    if let location { SettingsRouter.shared.request(FeatureSettingsDestination(notch: location)) }
                }
                shot.appearance = appearance
                shots.append(shot)
            }
        }
        return shots
    }
}
#endif
