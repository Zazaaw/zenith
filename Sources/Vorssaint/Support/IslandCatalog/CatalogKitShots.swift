// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

#if VORSSAINT_DEVELOPMENT
import AppKit
import SwiftUI

/// Zenith fork: the Settings kit's pages (`ONLY=kit…`), in Dark and Light
/// Mode: the two reference pages (Mechakey, a feature page with its hero;
/// General, a system page) and pages left as they were, which take the new
/// look through the restyled cards, rows, headers and previews. The art
/// stands still (an offscreen window counts as covered), so every shot shows
/// the kit's still frame.
@MainActor
extension CatalogShots {
    static var kit: [CatalogShot] {
        let pages: [(String, SettingsPage, [String: Any], CGFloat)] = [
            ("mechakey", .mechakey, [MechakeyDefaults.enabled: true], 1180),
            ("mechakey-open", .mechakey, [MechakeyDefaults.enabled: true,
                                          ZenithMoreOptionsRule.key("mechakey"): true], 1180),
            ("general", .general, [:], 1080),
            ("translate", .translate, [TranslateDefaults.enabled: true], 1300),
            ("shortcuts", .shortcuts, [:], 1000),
        ] + kitEverydayPages
        var shots: [CatalogShot] = []
        for (name, page, preferences, height) in pages {
            for (suffix, appearance) in [("dark", NSAppearance.Name.darkAqua), ("light", .aqua)] {
                var shot = settings("kit-\(name)-\(suffix)", page: page, preferences: preferences, settle: 1.5,
                                    height: height)
                shot.appearance = appearance
                shots.append(shot)
            }
        }
        return shots + kitIsland // Zenith fork: the Island group's pages (CatalogKitShotsIsland)
    }
}
#endif
