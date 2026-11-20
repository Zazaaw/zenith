// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Zenith fork: the QR codes' section on the Clipboard page: the level codes
/// are made at, the star in the middle, and the two shortcuts with their
/// switches. The heading is drawn here, with Zenith's own switches, so
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
        Section {
            Text(text.settingsCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 4) {
                Picker(text.correction, selection: $correction) {
                    ForEach(QRCorrection.allCases) { level in
                        Text("\(level.rawValue) · \(level.percent)%").tag(level.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(logo)
                Text(text.correctionCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ZenithSwitchRow(text.logo, isOn: $logo) { Text(text.logo) }
            if GlobalShortcutRole.zenithQR.isAvailable(using: { $0.isAvailable }) {
                ZenithSwitchRow(text.fromClipboard, isOn: $shortcutOn) { Text(text.fromClipboard) }
                    .onChange(of: shortcutOn) { _, _ in service.syncWithPreferences() }
                ShortcutPreferenceRow(role: .zenithQR, isEnabled: shortcutOn, label: text.fromClipboard) {
                    service.syncWithPreferences()
                }
                if shortcutOn, service.shortcutFailed {
                    Text(l10n.s.shortcutUnavailable)
                        .font(.caption)
                        .foregroundStyle(ZenithStatus.warning)
                }
            }
            if service.canScan {
                ZenithSwitchRow(text.scan, isOn: $scanOn) { Text(text.scan) }
                    .onChange(of: scanOn) { _, _ in service.syncWithPreferences() }
                ShortcutPreferenceRow(role: .zenithQRScan, isEnabled: scanOn, label: text.scan) {
                    service.syncWithPreferences()
                }
                if scanOn, service.scanShortcutFailed {
                    Text(l10n.s.shortcutUnavailable)
                        .font(.caption)
                        .foregroundStyle(ZenithStatus.warning)
                }
            }
            HStack(spacing: 8) {
                Button(text.newCode) { service.newCode() }
                Button(text.fromClipboard) { service.showClipboard() }
                if service.canScan {
                    Button(text.scan) { service.scanScreen() }
                }
            }
        } header: {
            Text(text.title)
        }
        .settingsFormSectionAnchor(.zenithQR) // Settings search lands here
    }
}
