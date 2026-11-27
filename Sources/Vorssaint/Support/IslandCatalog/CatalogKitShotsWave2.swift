// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

#if VORSSAINT_DEVELOPMENT
import AppKit
import SwiftUI

/// Zenith fork: Orbit wave 2's pages on the Settings kit (Remove Background,
/// the Emoji Picker, the Calculator), for `ONLY=kit…` beside the kit's own
/// pages (CatalogKitShots). Turning a feature on in the catalog's own
/// defaults registers nothing: the page reads its switch, no service starts.
@MainActor
extension CatalogShots {
    static var kitWave2Pages: [(String, SettingsPage, [String: Any], CGFloat)] {
        [
            ("remove-background", .removeBackground, [RemoveBackgroundDefaults.enabled: true], 1150),
            ("emoji-picker", .emojiPicker, [EmojiPickerDefaults.enabled: true, EmojiPickerDefaults.skinTone: "medium"], 1350),
            ("calculator", .calculator, [CalculatorDefaults.enabled: true], 1100),
        ]
    }

    /// The Calculator's island page.
    static var pagesWave2: [CatalogShot] {
        [page(.calculator, preferences: [CalculatorDefaults.enabled: true])]
    }
}
#endif
