// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Settings → Clipboard. Zenith fork: rebuilt with the Settings kit. The
/// history's switch is the hero's, then its preview, the window's layout as
/// pictures, the history's shortcut and what it keeps (rarer choices under
/// More options), Paste as plain text, privacy and auto clear, and QR codes.
/// Pasting a copied image as a file moved to Finder Tools, beside the Finder
/// paste it belongs to.
struct ClipboardSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var history = ClipboardHistoryService.shared
    @ObservedObject private var pastePlain = PastePlainService.shared
    @ObservedObject private var permissions = Permissions.shared
    @State private var clearingIDs: [UUID: Date]?
    @AppStorage(DefaultsKey.pastePlainEnabled) private var pastePlainEnabled = false
    @AppStorage(DefaultsKey.clipboardHistoryEnabled) private var enabled = false
    @AppStorage(DefaultsKey.clipboardHistoryLimit) private var limit = 50
    @AppStorage(DefaultsKey.clipboardHistoryRetentionDays) private var retentionDays = 0
    @AppStorage(DefaultsKey.clipboardHistoryFilterSensitiveText) private var skipSensitive = false
    @AppStorage(DefaultsKey.clipboardHistoryIncludeImagesFiles) private var includeImagesFiles = true
    @AppStorage(DefaultsKey.clipboardHistoryShortcutEnabled) private var shortcutEnabled = true
    @AppStorage(DefaultsKey.clipboardHistoryShowSourceAppIcons) private var showSourceAppIcons = false
    @AppStorage(DefaultsKey.clipboardHistoryLayout) private var historyLayout = ClipboardHistoryLayout.list
    @AppStorage(DefaultsKey.clipboardHistoryMenuBarPreview) private var menuBarPreview = false
    @AppStorage(DefaultsKey.clipboardHistoryMenuBarPreviewLength)
    private var menuBarPreviewLength = Defaults.defaultClipboardMenuBarPreviewLength
    @AppStorage(DefaultsKey.panelUtilityClipboard) private var showInPanel = true
    @AppStorage(DefaultsKey.clipboardAutoClearOnDelay) private var autoClearOnDelay = false
    @AppStorage(DefaultsKey.clipboardAutoClearDelay)
    private var autoClearDelay = Defaults.defaultClipboardAutoClearDelay
    @AppStorage(DefaultsKey.clipboardAutoClearOnSleep) private var autoClearOnSleep = false
    @AppStorage(DefaultsKey.clipboardAutoClearOnDisplaySleep) private var autoClearOnDisplaySleep = false
    @AppStorage(DefaultsKey.clipboardAutoClearOnScreenLock) private var autoClearOnScreenLock = false

    private let page = ZenithStrings.everyday(.enUS)

    private var text: ClipboardFeatureStrings {
        FeatureStrings.clipboard(l10n.language)
    }

    private var retentionText: ClipboardRetentionStrings {
        FeatureStrings.clipboardRetention(l10n.language)
    }

    private var historyAvailable: Bool { AppFeature.clipboardHistory.isAvailable }

    var body: some View {
        ScrollView {
            ZenithPageColumn {
                hero
                if AppFeature.pastePlain.isAvailable, pastePlainEnabled, !permissions.accessibility {
                    ZenithPermissionSection(kind: .accessibility)
                }
                ZenithClipboardPreviewCard()
                if historyAvailable {
                    layoutPicker
                    historySection
                }
                if AppFeature.pastePlain.isAvailable {
                    pastePlainSection
                }
                if historyAvailable {
                    privacySection
                }
                autoClearSection
                QRSettingsSection() // Zenith fork: QR codes.
            }
        }
        .onAppear {
            limit = Defaults.sanitizedClipboardHistoryLimit(limit)
            retentionDays = Defaults.sanitizedClipboardHistoryRetentionDays(retentionDays)
            autoClearDelay = Defaults.sanitizedClipboardAutoClearDelay(autoClearDelay)
            menuBarPreviewLength = Defaults.sanitizedClipboardMenuBarPreviewLength(menuBarPreviewLength)
        }
        .onChange(of: limit) { _, value in
            let sanitized = Defaults.sanitizedClipboardHistoryLimit(value)
            if sanitized != value { limit = sanitized }
            ClipboardHistoryService.shared.trimToLimit()
        }
        .onChange(of: retentionDays) { _, value in
            let sanitized = Defaults.sanitizedClipboardHistoryRetentionDays(value)
            if sanitized != value { retentionDays = sanitized }
            ClipboardHistoryService.shared.trimToLimit()
        }
        // No syncWithPreferences() here, unlike the auto-clear toggles: the
        // running poll reads this value from UserDefaults on every tick, so a
        // new delay takes effect on the next one. Syncing would just tear the
        // timer down and restart the wait.
        .onChange(of: autoClearDelay) { _, value in
            let sanitized = Defaults.sanitizedClipboardAutoClearDelay(value)
            if sanitized != value { autoClearDelay = sanitized }
        }
        .onChange(of: menuBarPreviewLength) { _, value in
            let sanitized = Defaults.sanitizedClipboardMenuBarPreviewLength(value)
            if sanitized != value { menuBarPreviewLength = sanitized }
        }
    }

    // MARK: Hero

    @ViewBuilder private var hero: some View {
        if historyAvailable {
            ZenithHero(title: text.title, subtitle: text.caption, chips: chips,
                       isOn: Binding(get: { enabled }, set: { on in
                           enabled = on
                           ClipboardHistoryService.shared.syncWithPreferences()
                       }),
                       switchLabel: text.enable, switchHint: text.localNote, animation: .clipboard)
                .zenithSectionAnchor(.clipboardHistory, cornerRadius: ZenithKitSurface.heroRadius + 6, inset: 6)
        } else {
            ZenithHero(title: text.title, subtitle: l10n.s.pastePlainCaption, chips: chips, animation: .clipboard)
        }
    }

    private var chips: [ZenithChip] {
        var chips: [ZenithChip] = []
        if historyAvailable {
            chips.append(ZenithChip(page.clipboardItems(history.entries.count),
                                    dot: enabled && history.isRunning ? ZenithStatus.success : nil))
            chips.append(ZenithChip(page.clipboardKeeps(limitLabel(limit))))
        }
        if AppFeature.pastePlain.isAvailable, pastePlainEnabled {
            chips.append(ZenithChip(page.clipboardPlainOn))
        }
        return chips
    }

    private func limitLabel(_ value: Int) -> String {
        value == 0 ? text.limitUnlimited : "\(value)"
    }

    // MARK: Layout

    /// Not disabled with capture off: the window still opens on the saved items.
    private var layoutPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZenithSectionTitle(text.historyLayout)
            ZenithVisualPicker(text.historyLayout, selection: $historyLayout, options: [
                ZenithPickerOption(ClipboardHistoryLayout.list, text.historyLayoutList),
                ZenithPickerOption(ClipboardHistoryLayout.cards, text.historyLayoutCards),
            ], minimumTileWidth: 150, tileHeight: 70) { layout, _ in
                ClipboardLayoutArt(cards: layout == .cards)
            }
        }
    }

    // MARK: History

    private var historySection: some View {
        ZenithSection(page.clipboardHistory) {
            ZenithRow(text.shortcut, isOn: $shortcutEnabled, info: text.shortcutCaption)
                .onChange(of: shortcutEnabled) { _, _ in ClipboardHistoryService.shared.syncHotkey() }
                .disabled(!enabled)
            ShortcutPreferenceRow(role: .clipboard,
                                  isEnabled: enabled && shortcutEnabled,
                                  additionalConflict: WindowLayoutService.shared.shortcutConflictTitle) {
                ClipboardHistoryService.shared.syncHotkey()
            }
            .padding(.vertical, 8)
            if enabled, shortcutEnabled, history.shortcutRegistrationFailed {
                ZenithRowStatus(text: l10n.s.shortcutUnavailable, symbol: "exclamationmark.triangle.fill",
                                color: ZenithStatus.warning)
            }
            ZenithRow(text.limit, selection: $limit) {
                ForEach(Defaults.allowedClipboardHistoryLimits, id: \.self) { value in
                    Text(limitLabel(value)).tag(value)
                }
            }
            .disabled(!enabled)
            ZenithRow(text.includeImagesFiles, isOn: $includeImagesFiles, info: text.includeImagesFilesCaption)
                .disabled(!enabled)
            savedRow
            ZenithMoreOptions(id: "clipboard") {
                ZenithRow(retentionText.title, selection: $retentionDays, info: retentionText.caption) {
                    ForEach(Defaults.allowedClipboardHistoryRetentionDays, id: \.self) { value in
                        Text(retentionText.label(days: value)).tag(value)
                    }
                }
                .disabled(!enabled)
                ZenithRow(text.showSourceAppIconsInList, isOn: $showSourceAppIcons)
                // It keeps working with capture off: the panel entry stays,
                // saying so, and still opens the saved items.
                ZenithRow(text.showInPanel, isOn: $showInPanel)
                ZenithRow(text.menuBarPreview, isOn: $menuBarPreview, info: text.menuBarPreviewCaption)
                    .disabled(!enabled)
                ZenithRow(text.menuBarPreviewLength) {
                    HStack(spacing: 6) {
                        TextField("", value: $menuBarPreviewLength, formatter: Self.menuBarPreviewLengthFormatter)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel(text.menuBarPreviewLength)
                        Text(text.menuBarPreviewLengthSuffix).foregroundStyle(.secondary)
                    }
                }
                .disabled(!enabled || !menuBarPreview)
            }
        }
    }

    /// What the history holds now, its window, and clearing what is not pinned.
    private var savedRow: some View {
        ZenithRow(page.clipboardSaved) {
            HStack(spacing: 8) {
                Text("\(history.pinnedEntries.count) \(text.pinned) · \(history.recentEntries.count) \(text.recent)")
                    .font(ZenithType.caption)
                    .foregroundStyle(.secondary)
                Button(text.clearRecent) {
                    clearingIDs = history.recentEntriesSnapshot
                }
                .disabled(history.recentEntries.isEmpty)
                .modifier(ClipboardClearRecentConfirmation(entryIDs: $clearingIDs))
                Button(page.clipboardOpenHistory) {
                    ClipboardHistoryService.shared.showHistoryWindow()
                }
                .disabled(history.entries.isEmpty)
            }
        }
    }

    private static let menuBarPreviewLengthFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = NSNumber(value: Defaults.allowedClipboardMenuBarPreviewLengthRange.lowerBound)
        formatter.maximum = NSNumber(value: Defaults.allowedClipboardMenuBarPreviewLengthRange.upperBound)
        formatter.usesGroupingSeparator = false
        return formatter
    }()

    // MARK: Paste as plain text

    private var pastePlainSection: some View {
        ZenithSection(l10n.s.pastePlainName, anchor: .pastePlain) {
            ZenithRow(l10n.s.pastePlainName, isOn: $pastePlainEnabled, info: l10n.s.pastePlainCaption)
                .onChange(of: pastePlainEnabled) { _, _ in PastePlainService.shared.syncWithPreferences() }
            ShortcutPreferenceRow(role: .pastePlain, isEnabled: pastePlainEnabled) {
                PastePlainService.shared.syncWithPreferences()
            }
            .padding(.vertical, 8)
            if pastePlainEnabled, pastePlain.shortcutRegistrationFailed {
                ZenithRowStatus(text: l10n.s.shortcutUnavailable, symbol: "exclamationmark.triangle.fill",
                                color: ZenithStatus.warning)
            }
        }
    }

    // MARK: Privacy

    private var privacySection: some View {
        ZenithSection(page.clipboardPrivacy, footer: text.localNote) {
            ZenithRow(text.skipSensitive, isOn: $skipSensitive, info: text.skipSensitiveCaption)
                .disabled(!enabled)
            ClipboardIgnoredAppsList()
                .padding(.vertical, 8)
                .disabled(!enabled)
        }
    }

    // MARK: Auto clear

    // Never disabled by the capture toggle, unlike the rows above: emptying
    // the pasteboard is a security setting in its own right, and someone who
    // keeps no history is exactly who reaches for it.
    private var autoClearSection: some View {
        ZenithSection(page.clipboardAutoClear, footer: text.autoClearCaption) {
            ZenithRow(text.autoClearEnable) {
                HStack(spacing: 8) {
                    TextField("", value: $autoClearDelay, formatter: Self.delayFieldFormatter)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                        .disabled(!autoClearOnDelay)
                        .accessibilityLabel(text.autoClearSecondsSuffix)
                    Text(text.autoClearSecondsSuffix).foregroundStyle(.secondary)
                    ZenithRowSwitch(title: text.autoClearEnable, isOn: $autoClearOnDelay)
                }
            }
            .onChange(of: autoClearOnDelay) { _, _ in ClipboardAutoClearService.shared.syncWithPreferences() }
            ZenithMoreOptions(id: "clipboard.autoClear") {
                ZenithRow(text.autoClearOnSleep, isOn: $autoClearOnSleep)
                    .onChange(of: autoClearOnSleep) { _, _ in ClipboardAutoClearService.shared.syncWithPreferences() }
                ZenithRow(text.autoClearOnDisplaySleep, isOn: $autoClearOnDisplaySleep)
                    .onChange(of: autoClearOnDisplaySleep) { _, _ in
                        ClipboardAutoClearService.shared.syncWithPreferences()
                    }
                ZenithRow(text.autoClearOnScreenLock, isOn: $autoClearOnScreenLock)
                    .onChange(of: autoClearOnScreenLock) { _, _ in
                        ClipboardAutoClearService.shared.syncWithPreferences()
                    }
            }
        }
    }

    private static let delayFieldFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = NSNumber(value: Defaults.allowedClipboardAutoClearDelayRange.lowerBound)
        formatter.maximum = NSNumber(value: Defaults.allowedClipboardAutoClearDelayRange.upperBound)
        formatter.usesGroupingSeparator = false
        return formatter
    }()
}

/// The history window's layout as a picture: rows of a list, or cards side by side.
private struct ClipboardLayoutArt: View {
    let cards: Bool

    var body: some View {
        Group {
            if cards {
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        card(lines: 3 - index % 2).frame(width: 30, height: 40)
                    }
                }
            } else {
                VStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        HStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 2).fill(Color.primary.opacity(0.45)).frame(width: 8, height: 8)
                            Capsule().fill(Color.primary.opacity(0.6)).frame(width: index == 1 ? 52 : 70, height: 4)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 6)
                        .frame(width: 100, height: 14)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.1)))
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func card(lines: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(0..<lines, id: \.self) { line in
                Capsule().fill(Color.primary.opacity(0.6)).frame(width: line == lines - 1 ? 12 : 20, height: 3)
            }
            Spacer(minLength: 0)
        }
        .padding(5)
        .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.1)))
    }
}
