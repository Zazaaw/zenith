// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

#if VORSSAINT_DEVELOPMENT
import AppKit
import SwiftUI

/// Zenith fork: Settings → Appearance (`ONLY=appearance…`), in Dark and Light
/// Mode, with Gradient glass chosen so its sliders read enabled. The motion
/// previews stand still, so the pictures do not depend on their moment.
@MainActor
extension CatalogShots {
    static var appearance: [CatalogShot] {
        [("dark", NSAppearance.Name.darkAqua), ("light", .aqua)].map { suffix, name in
            var shot = settings("appearance-page-\(suffix)", page: .appearance, preferences: appearancePreferences,
                                settle: 1.5, height: 1640) {
                AppearanceSettingsPage.previewsPlay = false
                ZenithAppearance.shared.reload()
            }
            shot.appearance = name
            return shot
        }
    }

    private static var appearancePreferences: [String: Any] {
        [ZenithAppearanceDefaults.motionPreset: IslandMotionPreset.zenith.rawValue,
         ZenithAppearanceDefaults.glassStyle: IslandGlassStyle.gradient.rawValue,
         ZenithAppearanceDefaults.batterySaver: IslandBatterySaver.automatic.rawValue]
    }
}
#endif
