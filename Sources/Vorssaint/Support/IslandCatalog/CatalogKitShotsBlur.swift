// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

#if VORSSAINT_DEVELOPMENT
import AppKit
import SwiftUI

/// Zenith fork: Privacy Blur's page on the Settings kit, for `ONLY=kit…`
/// beside the kit's own pages (CatalogKitShots). Turning it on in the
/// catalog's own defaults starts nothing: the page reads its switch, and the
/// service never runs while the catalog is quiet.
@MainActor
extension CatalogShots {
    static var kitBlurPages: [(String, SettingsPage, [String: Any], CGFloat)] {
        [
            ("privacy-blur", .privacyBlur, [PrivacyBlurDefaults.enabled: true], 1500),
            ("privacy-blur-parts", .privacyBlur,
             [PrivacyBlurDefaults.enabled: true,
              PrivacyBlurDefaults.apps: [PrivacyBlurPreset.whatsApp.id, PrivacyBlurPreset.discord.id],
              PrivacyBlurDefaults.regions: [PrivacyBlurPreset.whatsApp.id: ["chatList", "names"]],
              PrivacyBlurDefaults.when: PrivacyBlurWhen.whileSharing.rawValue,
              ZenithMoreOptionsRule.key("privacyBlur"): true], 1650),
        ]
    }
}
#endif
