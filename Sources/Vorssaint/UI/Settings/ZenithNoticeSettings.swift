// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Zenith fork: the Notices card in Settings → Dynamic Island → Activity: one
/// switch per capsule notice, and where the battery ones start.
struct ZenithNoticeSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchNoticeBatteryLow) private var lowOn = true
    @AppStorage(DefaultsKey.notchNoticeBatteryLowLevel) private var low = 20
    @AppStorage(DefaultsKey.notchNoticeBatteryCritical) private var criticalOn = true
    @AppStorage(DefaultsKey.notchNoticeBatteryCriticalLevel) private var critical = 10
    @AppStorage(DefaultsKey.notchNoticeBatteryHigh) private var highOn = true
    @AppStorage(DefaultsKey.notchNoticeBatteryHighLevel) private var high = 80
    @AppStorage(DefaultsKey.notchNoticeCharger) private var chargerOn = true
    @AppStorage(DefaultsKey.notchNoticeAudio) private var audioOn = true
    @AppStorage(DefaultsKey.notchNoticeDownload) private var downloadOn = true

    private var text: ZenithNoticeStrings { ZenithStrings.notices(l10n.language) }
    private let hasBattery = PowerSampler.hasInternalBattery

    var body: some View {
        // A heading drawn here rather than through SettingsCard's title, whose
        // labels Settings search indexes from upstream's catalogs.
        VStack(alignment: .leading, spacing: 10) {
            Text(text.section)
                .font(ZenithType.sectionTitle)
                .tracking(ZenithType.sectionTitleTracking)
                .padding(.leading, 2)
                .accessibilityAddTraits(.isHeader)
            SettingsCard {
                if hasBattery {
                    thresholdRow(text.lowBattery, isOn: $lowOn, level: $low, choices: ZenithBatterySettings.lowChoices)
                    thresholdRow(text.veryLowBattery, isOn: $criticalOn, level: $critical,
                                 choices: ZenithBatterySettings.criticalChoices)
                    thresholdRow(text.chargeReaches, caption: text.chargeHint, isOn: $highOn, level: $high,
                                 choices: ZenithBatterySettings.highChoices)
                    ZenithSwitchRow(text.charger, isOn: $chargerOn) { Text(text.charger) }
                }
                ZenithSwitchRow(text.audio, isOn: $audioOn) { Text(text.audio) }
                ZenithSwitchRow(text.download, isOn: $downloadOn) { Text(text.download) }
                Text(text.caption)
                    .font(ZenithType.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onChange(of: lowOn) { _, _ in sync() }
        .onChange(of: criticalOn) { _, _ in sync() }
        .onChange(of: highOn) { _, _ in sync() }
        .onChange(of: chargerOn) { _, _ in sync() }
        .onChange(of: audioOn) { _, _ in sync() }
        .onChange(of: downloadOn) { _, _ in sync() }
    }

    private func sync() { ZenithNoticeCenter.shared.syncWithPreferences() }

    /// A switch, and while it is on, the level it starts at.
    private func thresholdRow(_ title: String, caption: String? = nil, isOn: Binding<Bool>, level: Binding<Int>,
                              choices: [Int]) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let caption {
                    Text(caption).font(ZenithType.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            if isOn.wrappedValue {
                Picker(title, selection: level) {
                    ForEach(choices, id: \.self) { Text("\($0)%").tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .toggleStyle(ZenithSwitchStyle())
        }
    }
}
