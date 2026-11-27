// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Zenith fork: the QR codes' section on the Clipboard page, in the Settings
/// kit: the two shortcuts with their switches and the three actions first,
/// then the level codes are made at and the star in the middle under More
/// options. The heading is drawn here, with Zenith's own switches, so
/// nothing here reaches upstream's Settings search catalogs.
struct QRSettingsSection: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = QRService.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @AppStorage(DefaultsKey.zenithQRCorrection) private var correction = QRCorrection.medium.rawValue
    @AppStorage(DefaultsKey.zenithQRLogo) private var logo = false
    @AppStorage(DefaultsKey.zenithQRShortcutEnabled) private var shortcutOn = true
    @AppStorage(DefaultsKey.zenithQRScanShortcutEnabled) private var scanOn = true

    private var text: ZenithQRStrings { ZenithStrings.qr(l10n.language) }

    var body: some View {
        ZenithSection(text.title, anchor: .zenithQR, footer: text.settingsCaption) {
            if GlobalShortcutRole.zenithQR.isAvailable(using: { $0.isAvailable }) {
                ZenithRow(text.fromClipboard, isOn: $shortcutOn)
                    .onChange(of: shortcutOn) { _, _ in service.syncWithPreferences() }
                ShortcutPreferenceRow(role: .zenithQR, isEnabled: shortcutOn) {
                    service.syncWithPreferences()
                }
                .padding(.vertical, 8)
                if shortcutOn, service.shortcutFailed {
                    ZenithRowStatus(text: l10n.s.shortcutUnavailable, symbol: "exclamationmark.triangle.fill",
                                    color: ZenithStatus.warning)
                }
            }
            if service.canScan {
                ZenithRow(text.scan, isOn: $scanOn)
                    .onChange(of: scanOn) { _, _ in service.syncWithPreferences() }
                ShortcutPreferenceRow(role: .zenithQRScan, isEnabled: scanOn) {
                    service.syncWithPreferences()
                }
                .padding(.vertical, 8)
                if scanOn, service.scanShortcutFailed {
                    ZenithRowStatus(text: l10n.s.shortcutUnavailable, symbol: "exclamationmark.triangle.fill",
                                    color: ZenithStatus.warning)
                }
            }
            HStack(spacing: 8) {
                Button(text.newCode) { service.newCode() }
                Button(text.fromClipboard) { service.showClipboard() }
                if service.canScan {
                    Button(text.scan) { service.scanScreen() }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            ZenithMoreOptions(id: "clipboard.qr") {
                ZenithRow(text.correction, selection: $correction, info: text.correctionCaption) {
                    ForEach(QRCorrection.allCases) { level in
                        Text(verbatim: "\(level.rawValue) · \(level.percent)%").tag(level.rawValue)
                    }
                }
                .disabled(logo)
                ZenithRow(text.logo, isOn: $logo)
            }
        }
    }
}
