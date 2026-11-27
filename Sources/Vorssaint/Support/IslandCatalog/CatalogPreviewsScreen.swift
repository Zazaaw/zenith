// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

#if VORSSAINT_DEVELOPMENT
import AppKit
import SwiftUI

/// Zenith fork: the preview cards of the Settings pages about the screen
/// (`ONLY=readme-preview-screen`): each page in its window, opened on its
/// sections, then every picture alone at the card's size.
@MainActor
extension CatalogShots {
    static var previewsScreen: [CatalogShot] {
        let pages: [(String, FeatureSettingsDestination, [String: Any])] = [
            ("general", FeatureSettingsDestination(.general), [:]),
            ("menu-bar", FeatureSettingsDestination(.menuBar), [:]),
            ("mixer", FeatureSettingsDestination(.general, sectionAnchor: .mixer), [:]),
            ("features", FeatureSettingsDestination(.features), [:]),
            ("sleep", FeatureSettingsDestination(.sleep), [:]),
            ("brightness", FeatureSettingsDestination(.brightness), [:]),
            ("monitor", FeatureSettingsDestination(.monitor),
             [DefaultsKey.menuBarCPU: true, DefaultsKey.menuBarMemory: true, DefaultsKey.menuBarNetwork: true]),
            ("switcher", FeatureSettingsDestination(.switcher), [:]),
            ("dock", FeatureSettingsDestination(.dock, sectionAnchor: .dockClick), [:]),
            ("window-layout", FeatureSettingsDestination(.windowLayout), [:]),
            ("screen-capture", FeatureSettingsDestination(.screenshot), [:]),
            ("media", FeatureSettingsDestination(.media), [:]),
            ("app-updates", FeatureSettingsDestination(.appUpdates), [:]),
        ]
        let windows = pages.map { name, destination, preferences in
            CatalogShot(id: "readme-preview-screen-page-\(name)", kind: .window, preferences: preferences, setup: {
                SettingsRouter.shared.request(destination)
                SettingsWindowVisibility.shared.set(true)
            }, teardown: {
                SettingsWindowVisibility.shared.set(false)
            }, settle: 1.5) {
                (AnyView(SettingsView()), CGSize(width: 1000, height: 700))
            }
        }
        // The picture at the card's size in a 1000-point Settings window.
        let size = CGSize(width: 494, height: (494 / 2.2).rounded())
        let pictures = ZenithScreenScene.allCases.map { scene in
            CatalogShot(id: "readme-preview-screen-picture-\(scene.rawValue)", kind: .screen,
                        preferences: [DefaultsKey.menuBarCPU: true, DefaultsKey.menuBarMemory: true], settle: 0.6) {
                let view = ZenithScreenPicture(scene: scene)
                    .frame(width: size.width, height: size.height)
                    .clipShape(RoundedRectangle(cornerRadius: ZenithRadius.card, style: .continuous))
                return (AnyView(view), size)
            }
        }
        return windows + pictures
    }
}
#endif
