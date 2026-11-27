// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Zenith fork: Settings → Fan Control, built with the Settings kit, out of
/// the Monitor page. The fans are set from the menu bar panel; this page
/// says whether the panel shows them and whether the menu bar shows their
/// speed.
struct FanControlSettingsPage: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @AppStorage(DefaultsKey.panelShowFanControl) private var showFanControl = true
    @AppStorage(DefaultsKey.menuBarFanSpeed) private var fanSpeedInMenuBar = false

    private let page = ZenithStrings.systemApps(.enUS)
    private var strings: FanControlFeatureStrings { FeatureStrings.fanControl(l10n.language) }

    var body: some View {
        ScrollView {
            ZenithPageColumn {
                ZenithHero(title: strings.title, subtitle: page.fanSubtitle, chips: chips,
                           animation: .fanControl)
                if let reason = AppFeature.fanControl.hardwareUnsupportedReason {
                    ZenithCallout(.info, reason)
                }
                ZenithScreenPreviewCard(group: .fans)
                ZenithSection(strings.title, anchor: .fanControl, footer: l10n.s.betaFeatureWarning) {
                    ZenithRow(strings.showInPanel, isOn: $showFanControl, info: strings.settingsCaption,
                              badge: l10n.s.betaBadge)
                    if SystemMonitor.fanTelemetryAvailable {
                        ZenithRow(strings.menuBarTitle, isOn: $fanSpeedInMenuBar)
                    }
                }
            }
        }
    }

    private var chips: [ZenithChip] {
        var chips = [ZenithChip(page.fanBeta)]
        if showFanControl { chips.append(ZenithChip(page.fanPanel)) }
        if !SystemMonitor.fanTelemetryAvailable { chips.append(ZenithChip(page.fanNoFans)) }
        return chips
    }
}
