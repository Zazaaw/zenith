// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Satu Visual

import SwiftUI

struct AppUpdatesSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var updates = AppUpdatesService.shared
    @AppStorage(DefaultsKey.appUpdatesCheckFrequency)
    private var frequencyRaw = AppUpdatesSupport.CheckFrequency.off.rawValue
    @AppStorage(DefaultsKey.appUpdatesNotify) private var notify = true
    @AppStorage(DefaultsKey.appUpdatesIncludeHomebrewApps) private var includeHomebrewApps = true
    @AppStorage(DefaultsKey.appUpdatesIncludeAppStore) private var includeAppStore = true
    @AppStorage(DefaultsKey.appUpdatesIncludeOnlineCatalog)
    private var includeOnlineCatalog = true
    @AppStorage(DefaultsKey.panelUtilityAppUpdates) private var showInPanel = true

    private var text: AppUpdateStrings { FeatureStrings.appUpdates(l10n.language) }

    private let page = ZenithStrings.systemApps(.enUS)

    // Zenith fork: built with the Settings kit: the hero, the preview, the
    // list of updates in a grouped card, when to check, and where from.
    var body: some View {
        let frequency = AppUpdatesSupport.CheckFrequency.sanitized(frequencyRaw)
        ScrollView {
            ZenithPageColumn {
                ZenithHero(title: text.pageTitle, subtitle: page.updatesSubtitle, chips: chips,
                           animation: .appUpdates)
                ZenithScreenPreviewCard(group: .appUpdates) // Zenith fork
                VStack(alignment: .leading, spacing: 8) {
                    ZenithSectionTitle(page.updatesList)
                    AppUpdatesListView()
                        .padding(16)
                        .zenithGroupBackground()
                    ZenithFootnote(text.caption)
                }
                ZenithSection(text.frequencyLabel,
                              footer: updates.nextCheck.map { String(format: text.nextCheckFormat, nextCheckText($0)) }) {
                    ZenithRow(text.frequencyLabel, selection: frequencyBinding) {
                        Text(text.frequencyOff).tag(AppUpdatesSupport.CheckFrequency.off)
                        Text(text.frequencyDaily).tag(AppUpdatesSupport.CheckFrequency.daily)
                        Text(text.frequencyWeekly).tag(AppUpdatesSupport.CheckFrequency.weekly)
                    }
                    ZenithRow(text.notifyToggle, isOn: $notify)
                        .disabled(frequency == .off)
                        .onChange(of: notify) { _, value in
                            guard value else { return }
                            Notifier.requestPermission()
                        }
                    ZenithRow(text.showInPanel, isOn: $showInPanel)
                }
                ZenithSection(text.sourcesTitle) {
                    ZenithRow(text.includeHomebrewToggle, isOn: $includeHomebrewApps)
                        .disabled(includeHomebrewApps && enabledSourceCount == 1)
                        .onChange(of: includeHomebrewApps) { _, _ in
                            updates.sourceSelectionDidChange()
                        }
                    ZenithRow(text.includeStoreToggle, isOn: $includeAppStore, info: text.includeStoreCaption)
                        .disabled(includeAppStore && enabledSourceCount == 1)
                        .onChange(of: includeAppStore) { _, _ in
                            updates.sourceSelectionDidChange()
                        }
                    ZenithRow(text.includeOnlineToggle, isOn: $includeOnlineCatalog, info: text.includeOnlineCaption)
                        .disabled(includeOnlineCatalog && enabledSourceCount == 1)
                        .onChange(of: includeOnlineCatalog) { _, _ in
                            updates.sourceSelectionDidChange()
                        }
                }
            }
        }
        .onAppear { updates.checkIfNeeded() }
    }

    private var chips: [ZenithChip] {
        if updates.isChecking { return [ZenithChip(page.updatesChecking)] }
        let count = updates.items.count
        return [count == 0 ? ZenithChip(page.updatesUpToDate, dot: ZenithStatus.success)
                           : ZenithChip(page.updatesCount(count), dot: ZenithStatus.warning)]
    }

    private var frequencyBinding: Binding<AppUpdatesSupport.CheckFrequency> {
        Binding {
            AppUpdatesSupport.CheckFrequency.sanitized(frequencyRaw)
        } set: { frequency in
            frequencyRaw = frequency.rawValue
            AppUpdatesService.shared.syncWithPreferences()
            if frequency != .off, notify { Notifier.requestPermission() }
        }
    }

    private var enabledSourceCount: Int {
        [includeHomebrewApps, includeAppStore, includeOnlineCatalog].filter { $0 }.count
    }

    private func nextCheckText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = .current
        return formatter.string(from: date)
    }
}
