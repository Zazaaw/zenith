// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Zenith fork: Beautify's card on the Screenshot page. The heading comes
/// from the section and the switch is Zenith's own, so nothing here reaches
/// upstream's Settings search catalogs.
struct ScreenshotBeautifySettingsSection: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.screenshotBeautifyAfterCapture) private var afterCapture = false

    private var text: ZenithBeautifyStrings { ZenithStrings.beautify(l10n.language) }

    // Zenith fork: a section of Settings → Screenshot, in the kit.
    var body: some View {
        ZenithSection(text.title, anchor: .zenithBeautify, footer: text.settingsCaption) { // Settings search lands here
            ZenithRow(text.afterCapture, isOn: $afterCapture, info: text.afterCaptureCaption)
        }
    }
}
