// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

#if VORSSAINT_DEVELOPMENT
import AppKit
import SwiftUI

/// Zenith fork: the Everyday and Devices pages rebuilt with the Settings kit,
/// for `ONLY=kit…` beside the kit's own pages (CatalogKitShots).
@MainActor
extension CatalogShots {
    static var kitEverydayPages: [(String, SettingsPage, [String: Any], CGFloat)] {
        [
            ("shelf", .shelf, [DefaultsKey.shelfEnabled: true], 1900),
            ("clipboard", .clipboard, [DefaultsKey.clipboardHistoryEnabled: true,
                                       DefaultsKey.pastePlainEnabled: true], 1900),
            ("finder-tools", .finderTools, [DefaultsKey.finderCutPasteEnabled: true,
                                            DefaultsKey.finderRenameEnabled: true], 1500),
            ("media", .media, [:], 1500),
            ("url-cleaner", .urlCleaner, [DefaultsKey.urlCleanerEnabled: true], 1500),
            ("text-snippets", .textSnippets, [DefaultsKey.textSnippetsEnabled: true,
                                              DefaultsKey.snippetLibraryEnabled: true], 1300),
            ("batteries", .batteries, [BatteriesDefaults.enabled: true], 1600),
            ("pocket", .pocket, [PocketDefaults.enabled: true], 1800),
            ("remote", .remote, [DefaultsKey.zenithRemoteEnabled: true], 1800),
            ("face-unlock", .faceUnlock, [:], 1200),
        ]
    }
}
#endif
