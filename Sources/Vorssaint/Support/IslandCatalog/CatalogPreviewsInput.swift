// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

#if VORSSAINT_DEVELOPMENT
import AppKit
import SwiftUI

/// Zenith fork: the preview cards of the mouse, keyboard, files and clipboard
/// pages, each page in its Settings window (`ONLY=readme-previews-input`).
/// The pictures stand on their still phase, as with Reduce Motion on.
@MainActor
extension CatalogShots {
    static var previewsInput: [CatalogShot] {
        let pages: [(String, SettingsPage)] = [
            ("mouse", .mouse), ("key-debounce", .keyDebounce), ("super-key", .superKey), ("cut-paste", .cutPaste),
            ("auto-quit", .autoQuit), ("quit-protection", .quitProtection), ("url-cleaner", .urlCleaner),
            ("clipboard", .clipboard), ("text-snippets", .textSnippets), ("radial-menu", .radialMenu),
            ("shortcuts", .shortcuts),
        ]
        let routed: [(String, AppFeature)] = [
            ("mouse-smooth", .smoothScroll), ("mouse-focus", .focusFollowsMouse), ("mouse-debounce", .mouseClickDebounce),
            ("mouse-middle-click", .middleClick), ("cut-paste-rename", .finderRename), ("clipboard-plain", .pastePlain),
        ]
        return pages.map { settings("readme-previews-input-\($0.0)", page: $0.1) }
            + routed.map { id, feature in
                settings("readme-previews-input-\(id)", page: feature.settingsDestination.page) {
                    previewRoute(to: feature)
                }
            }
    }

    /// Opens `feature` as its sidebar row does, but keeps the page at its top,
    /// where the preview card is, instead of scrolling to the section.
    private static func previewRoute(to feature: AppFeature) {
        let router = SettingsRouter.shared
        router.request(feature.settingsDestination, sidebarFeature: feature)
        if let pending = router.pendingDestinationRequest { router.consumeDestinationRequest(id: pending.id) }
    }
}
#endif
