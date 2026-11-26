// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

#if VORSSAINT_DEVELOPMENT
import AppKit
import SwiftUI

/// Zenith fork: Orbit, the Features page (`ONLY=orbit…`), in Dark and Light
/// Mode, with a few features left off so Get shows beside Open, and an
/// item's detail sheet.
@MainActor
extension CatalogShots {
    static var orbit: [CatalogShot] {
        var shots: [CatalogShot] = []
        for (suffix, appearance) in [("dark", NSAppearance.Name.darkAqua), ("light", .aqua)] {
            var page = settings("orbit-page-\(suffix)", page: .features, preferences: orbitPreferences,
                                settle: 1.5, height: 1500) {
                Permissions.shared.catalogPoseBroadGrants()
            }
            page.appearance = appearance
            shots.append(page)
            var sheet = CatalogShot(id: "orbit-detail-\(suffix)", kind: .window, preferences: orbitPreferences,
                                    setup: { Permissions.shared.catalogPoseBroadGrants() }, settle: 1) {
                let item = OrbitCatalog.item(.feature(.mixer))!
                let view = OrbitDetailSheet(item: item, state: .on, onAction: {}, onTurnOff: {}, onDone: {})
                return (AnyView(view), CGSize(width: 480, height: 520))
            }
            sheet.appearance = appearance
            shots.append(sheet)
        }
        return shots
    }

    /// Some features left uninstalled and some Zenith pages switched off,
    /// as on a Mac that has not added everything.
    private static var orbitPreferences: [String: Any] {
        var values: [String: Any] = [
            DefaultsKey.zenithMeetingsEnabled: false,
            TranslateDefaults.enabled: true,
            PocketDefaults.enabled: true,
            DefaultsKey.faceUnlockEnabled: false,
        ]
        let off: [AppFeature] = [.fanControl, .killProcess, .portManager, .focusFollowsMouse, .wallpaper,
                                 .notchMascot, .audioPriority, .scrollZoom, .spacesOrder, .quitApps,
                                 .diskImageInstaller, .scrollHorizontal, .linearScroll, .scrollSpeed]
        for feature in off { values[feature.availabilityKey] = false }
        return values
    }
}
#endif
