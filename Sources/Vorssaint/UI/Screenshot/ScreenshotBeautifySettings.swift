// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Zenith fork: Beautify's card on the Screen capture page. The heading comes
/// from the section and the switch is Zenith's own, so nothing here reaches
/// upstream's Settings search catalogs.
struct ScreenshotBeautifySettingsSection: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.screenshotBeautifyAfterCapture) private var afterCapture = false

    private var text: ZenithBeautifyStrings { ZenithStrings.beautify(l10n.language) }

    var body: some View {
        Section {
            Text(text.settingsCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ZenithSwitchRow(text.afterCapture, isOn: $afterCapture) { Text(text.afterCapture) }
            Text(text.afterCaptureCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } header: {
            Text(text.title)
        }
        .settingsFormSectionAnchor(.zenithBeautify) // Settings search lands here
    }
}
