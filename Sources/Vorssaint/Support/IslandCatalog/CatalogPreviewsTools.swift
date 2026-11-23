// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

#if VORSSAINT_DEVELOPMENT
import AppKit
import SwiftUI

/// Zenith fork: the tool and info pages of Settings with their preview cards
/// (`ONLY=readme-preview-tools`), for checking the cards by eye. Quick Tools
/// is drawn once per state and for the two features with pictures of their
/// own, landed on a feature as the sidebar would.
@MainActor
extension CatalogShots {
    static var readmePreviewsTools: [CatalogShot] {
        [
            quickTools("readme-preview-tools-quick-panel", landing: nil),
            quickTools("readme-preview-tools-quick-windows", landing: .scratchpad),
            quickTools("readme-preview-tools-quick-apps", landing: .micMute),
            quickTools("readme-preview-tools-quick-cleaning", landing: .cleaningMode),
            quickTools("readme-preview-tools-quick-wallpaper", landing: .wallpaper),
            settings("readme-preview-tools-cleaner", page: .cleaner),
            settings("readme-preview-tools-cleaner-whatsapp", page: .cleaner,
                     preferences: [DefaultsKey.whatsAppDownloadsEnabled: true]) {
                SettingsRouter.shared.cleanerTool = "whatsApp"
            },
            settings("readme-preview-tools-homebrew", page: .homebrew),
            settings("readme-preview-tools-uninstaller", page: .uninstaller),
            settings("readme-preview-tools-kill-process", page: .killProcess),
            settings("readme-preview-tools-port-manager", page: .portManager),
            settings("readme-preview-tools-advanced", page: .advanced),
            settings("readme-preview-tools-about", page: .about, visible: false, settle: 3),
            settings("readme-preview-tools-release-notes", page: .releaseNotes),
            settings("readme-preview-tools-support", page: .support),
        ]
    }

    /// Quick Tools opened on `landing`'s section, or on the page itself.
    private static func quickTools(_ id: String, landing: SettingsSectionAnchor?) -> CatalogShot {
        settings(id, page: .quickTools) {
            SettingsRouter.shared.request(FeatureSettingsDestination(.quickTools, sectionAnchor: landing))
        }
    }
}
#endif
