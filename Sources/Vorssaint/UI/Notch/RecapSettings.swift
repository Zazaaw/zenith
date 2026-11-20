// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Zenith fork: the Today section's options in Settings → Dynamic Island →
/// Content: the daily notice, its time, weekdays only, and which sources the
/// recap reads. Switches are `ZenithSwitchRow`, so nothing here joins the
/// settings search index.
struct RecapSettingsView: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchRecapEnabled) private var enabled = true
    @AppStorage(DefaultsKey.notchRecapMinutes) private var minutes = RecapSettings.defaultMinutes
    @AppStorage(DefaultsKey.notchRecapWeekdaysOnly) private var weekdaysOnly = false
    @AppStorage(DefaultsKey.notchRecapHiddenSources) private var hidden = ""

    private var text: ZenithRecapStrings { ZenithStrings.recap(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZenithSwitchRow(text.dailyRecap, isOn: $enabled) {
                label(text.dailyRecap, caption: text.dailyRecapCaption)
            }
            HStack(spacing: 12) {
                Text(text.showAt)
                Spacer(minLength: 12)
                DatePicker(text.showAt, selection: time, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.stepperField)
                    .fixedSize()
            }
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.5)
            ZenithSwitchRow(text.weekdaysOnly, isOn: $weekdaysOnly) { Text(text.weekdaysOnly) }
                .disabled(!enabled)
                .opacity(enabled ? 1 : 0.5)
            Divider().padding(.vertical, 2)
            Text(text.include).font(ZenithType.emphasis)
            ForEach(RecapSource.allCases) { source in
                ZenithSwitchRow(title(source), isOn: included(source)) {
                    HStack(spacing: 8) {
                        Image(systemName: source.symbol)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(ZenithIslandPalette.color(hex: source.hex))
                            .frame(width: 18)
                            .accessibilityHidden(true)
                        Text(title(source))
                    }
                }
            }
            Text(text.includeCaption).font(ZenithType.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onChange(of: enabled) { _, _ in
            RecapService.shared.settingsChanged()
            ZenithNoticeCenter.shared.syncWithPreferences()
        }
        .onChange(of: minutes) { _, _ in RecapService.shared.settingsChanged() }
        .onChange(of: weekdaysOnly) { _, _ in RecapService.shared.settingsChanged() }
    }

    /// The chosen time as today's date at it, for the picker.
    private var time: Binding<Date> {
        Binding(get: {
            let start = Calendar.current.startOfDay(for: Date())
            return RecapSchedule.moment(on: start, settings: RecapSettings(minutes: minutes)) ?? start
        }, set: { date in
            minutes = RecapSettings.clamped(RecapSchedule.minutes(of: date))
        })
    }

    private func included(_ source: RecapSource) -> Binding<Bool> {
        Binding(get: { !RecapSettings.decodeHidden(hidden).contains(source) }, set: { on in
            var set = RecapSettings.decodeHidden(hidden)
            if on { set.remove(source) } else { set.insert(source) }
            hidden = RecapSettings.encodeHidden(set)
        })
    }

    private func title(_ source: RecapSource) -> String {
        switch source {
        case .coding: return text.sourceCoding
        case .deploys: return text.sourceDeploys
        case .github: return text.sourceGitHub
        case .terminal: return text.sourceTerminal
        case .photos: return text.sourceImports
        case .exports: return text.sourceExports
        case .agents: return text.sourceAgents
        }
    }

    private func label(_ title: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(caption).font(ZenithType.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
