// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Zenith fork: the design overlay's card on the Screenshot page: its
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

    // Zenith fork: a section of Settings → Screenshot, in the kit.
    var body: some View {
        ZenithSection(text.title, anchor: .zenithDesignOverlay, // Settings search lands here
                      footer: ZenithStrings.dropZones(l10n.language).overlayMoved) {
            ZenithRow(text.title, info: text.caption) {
                HStack(spacing: 8) {
                    Button(text.choose) { service.chooseImage() }
                    Button(text.paste) { service.pasteFromClipboard() }
                }
            }
            ZenithShortcutSwitchRows(title: text.shortcut, role: .designOverlay, isOn: $shortcutOn,
                                     failed: service.shortcutRegistrationFailed) {
                service.syncWithPreferences()
            }
            ZenithRow(text.defaultOpacity, value: $opacity, in: DesignOverlaySupport.opacityRange,
                      valueLabel: "\(Int((opacity * 100).rounded()))%")
            ZenithRow(text.defaultBlend, selection: $blend, info: text.blendCaption) {
                Text(text.normal).tag(DesignOverlayBlend.normal.rawValue)
                Text(text.difference).tag(DesignOverlayBlend.difference.rawValue)
                Text(text.invert).tag(DesignOverlayBlend.invert.rawValue)
            }
            ZenithRow(text.grid, selection: $preset, info: text.gridCaption) {
                ForEach(DesignOverlayGridPreset.allCases) { choice in
                    Text(choice.grid.label).tag(choice.rawValue)
                }
            }
        }
    }
}
