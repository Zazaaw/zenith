// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

#if VORSSAINT_DEVELOPMENT
import AppKit
import SwiftUI

/// Zenith fork: the Privacy pages on the Settings kit (App Lock), for
/// `ONLY=kit…` beside the kit's own pages (CatalogKitShots). Turning App Lock
/// on in the catalog's own defaults starts nothing: the catalog runs quiet,
/// so no workspace observer, shield or prompt.
@MainActor
extension CatalogShots {
    static var kitPrivacyPages: [(String, SettingsPage, [String: Any], CGFloat)] {
        [
            ("app-lock", .appLock, [AppLockDefaults.enabled: true,
                                    AppLockDefaults.apps: ["com.apple.Notes", "com.apple.MobileSMS", "com.apple.Photos"]],
             1500),
        ]
    }
}
#endif
