// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Zenith fork: the design overlay's card on the Screen capture page: its
/// shortcut, the opacity and blend it opens with, the grid preset, the
/// island's Overlay zone, and two ways to open it right now. The heading is
/// drawn here, with Zenith's own switches, so nothing here reaches upstream's
/// Settings search catalogs.
struct DesignOverlaySettingsSection: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = DesignOverlayService.shared
    @AppStorage(DefaultsKey.designOverlayShortcutEnabled) private var shortcutOn = true
    @AppStorage(DefaultsKey.designOverlayDefaultOpacity) private var opacity = DesignOverlaySupport.defaultOpacity
    @AppStorage(DefaultsKey.designOverlayDefaultBlend) private var blend = DesignOverlayBlend.normal.rawValue
    @AppStorage(DefaultsKey.designOverlayGridPreset) private var preset = DesignOverlayGridPreset.desktop.rawValue

    private var text: ZenithDesignOverlayStrings { ZenithStrings.designOverlay(l10n.language) }

    var body: some View {
        Section {
            Text(text.caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ZenithSwitchRow(text.shortcut, isOn: $shortcutOn) { Text(text.shortcut) }
                .onChange(of: shortcutOn) { _, _ in service.syncWithPreferences() }
            ShortcutPreferenceRow(role: .designOverlay, isEnabled: shortcutOn) {
                service.syncWithPreferences()
            }
            if shortcutOn, service.shortcutRegistrationFailed {
                Text(l10n.s.shortcutUnavailable)
                    .font(.caption)
                    .foregroundStyle(ZenithStatus.warning)
            }
            HStack(spacing: 12) {
                Text(text.defaultOpacity)
                Spacer(minLength: 12)
                Slider(value: $opacity, in: DesignOverlaySupport.opacityRange)
                    .frame(maxWidth: 180)
                    .labelsHidden()
                Text("\(Int((opacity * 100).rounded()))%")
                    .font(ZenithType.mono(11))
                    .monospacedDigit()
                    .frame(width: 38, alignment: .trailing)
            }
            VStack(alignment: .leading, spacing: 4) {
                Picker(text.defaultBlend, selection: $blend) {
                    Text(text.normal).tag(DesignOverlayBlend.normal.rawValue)
                    Text(text.difference).tag(DesignOverlayBlend.difference.rawValue)
                    Text(text.invert).tag(DesignOverlayBlend.invert.rawValue)
                }
                .pickerStyle(.segmented)
                Text(text.blendCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 4) {
                Picker(text.grid, selection: $preset) {
                    ForEach(DesignOverlayGridPreset.allCases) { choice in
                        Text(choice.grid.label).tag(choice.rawValue)
                    }
                }
                Text(text.gridCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            // The island's Overlay zone is switched with the other drop zones, in Shelf settings.
            Text(ZenithStrings.dropZones(l10n.language).overlayMoved)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button(text.choose) { service.chooseImage() }
                Button(text.paste) { service.pasteFromClipboard() }
            }
        } header: {
            Text(text.title)
        }
        .settingsFormSectionAnchor(.zenithDesignOverlay) // Settings search lands here
    }
}
