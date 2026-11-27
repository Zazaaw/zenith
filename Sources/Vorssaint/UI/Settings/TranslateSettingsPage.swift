// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI
import Translation

/// Zenith fork: Settings → Translate, a feature page in the kit
/// (docs/SETTINGS-KIT.md). The hero with the switch, the shortcut, the
/// languages to read in, and which pairs are downloaded, with the system's
/// download prompt for a missing one (this window can show it; the card under
/// the pointer can't). Off by default; the page writes `TranslateDefaults`
/// and tells the service.
struct TranslateSettingsPage: View {
    private let text = ZenithStrings.translate(.enUS)

    var body: some View {
        if #available(macOS 15.0, *) {
            TranslateSettingsContent()
        } else {
            ZenithToolPage {
                ZenithHero(title: text.title, subtitle: text.subtitle, animation: .translate)
                // Search still lands here; the sections it names only exist from macOS 15 on.
                ZenithCallout(.info, text.needsMacOS15)
            }
        }
    }
}

@available(macOS 15.0, *)
private struct TranslateSettingsContent: View {
    @ObservedObject private var service = TranslateService.shared
    @ObservedObject private var permissions = Permissions.shared
    @AppStorage(TranslateDefaults.enabled) private var enabled = false
    @AppStorage(TranslateDefaults.shortcut) private var shortcut = TranslateService.defaultShortcut.storageValue
    @AppStorage(TranslateDefaults.target) private var target = ""
    @AppStorage(TranslateDefaults.secondTarget) private var secondTarget = ""
    @AppStorage(TranslateDefaults.showDetection) private var showDetection = true

    @State private var shortcutMessage: String?
    @State private var languages = TranslateLanguageCode.menu(TranslateLanguageCode.fallbackLanguages)
    @State private var statuses: [String: TranslatePairStatus] = [:]
    @State private var checkFrom = "en"
    @State private var checkTo = ""
    @State private var downloadConfiguration: TranslationSession.Configuration?
    @State private var downloadingKey: String?
    @State private var refresh = 0

    private let text = ZenithStrings.translate(.enUS)

    private var preferences: TranslatePreferences { TranslatePreferences.read() }
    private var system: (primary: String, second: String?) {
        TranslateLanguageCode.systemTargets(Locale.preferredLanguages)
    }

    /// The pairs the page reports on: the two languages both ways, and the pair being checked.
    private var pairs: [(from: String, to: String)] {
        let current = preferences
        var list: [(String, String)] = []
        if let second = current.second {
            list.append((second, current.primary))
            list.append((current.primary, second))
        }
        let to = checkTo.isEmpty ? current.primary : checkTo
        if checkFrom != to, !list.contains(where: { $0 == (checkFrom, to) }) { list.append((checkFrom, to)) }
        return list
    }

    var body: some View {
        ZenithToolPage {
            ZenithHero(title: text.title, subtitle: text.subtitle, chips: chips,
                       isOn: enabledBinding, switchLabel: text.enable, switchHint: text.enableCaption,
                       animation: .translate)
                .zenithSectionAnchor(.zenithTranslate, cornerRadius: ZenithKitSurface.heroRadius + 6, inset: 6)
            if enabled, !permissions.accessibility {
                ZenithCallout(.warning, text.accessibilityNeeded) {
                    Button(text.openAccessibility) { Permissions.shared.requestAccessibility() }
                }
            }
            // Kept in view while Translate is off, greyed, so the page reads
            // the same whichever way the switch is.
            VStack(alignment: .leading, spacing: 18) {
                ZenithSection(text.shortcutSection) { shortcutRow }
                languagesSection
                downloadsSection
            }
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.5)
        }
        // The system's download prompt, for a pair asked for here or by the card.
        .translationTask(downloadConfiguration) { session in
            do { try await session.prepareTranslation() } catch {}
            downloadingKey = nil
            refresh += 1
        }
        .task(id: "\(refresh)|\(target)|\(secondTarget)|\(checkFrom)|\(checkTo)") { await loadStatuses() }
        .task { languages = await TranslateEngine.supportedLanguages() }
        .onAppear {
            let current = preferences
            if checkTo.isEmpty { checkTo = current.primary }
            if TranslateLanguageCode.same(checkFrom, checkTo) {
                checkFrom = current.second ?? (current.primary == "en" ? "es" : "en")
            }
            takePendingDownload()
        }
        .onChange(of: service.pendingDownload) { _, _ in takePendingDownload() }
    }

    private var enabledBinding: Binding<Bool> {
        Binding(get: { enabled }, set: { on in
            enabled = on
            service.syncWithPreferences()
        })
    }

    /// The languages it reads in, and the shortcut.
    private var chips: [ZenithChip] {
        let current = preferences
        let pair = current.second.map { "\(TranslateLanguageCode.displayName($0)) ↔ \(TranslateLanguageCode.displayName(current.primary))" }
            ?? TranslateLanguageCode.displayName(current.primary)
        let keys = GlobalShortcut(storageValue: shortcut)?.displayString
        return [ZenithChip(pair)] + (keys.map { [ZenithChip($0)] } ?? [])
    }

    // MARK: Shortcut

    private var shortcutRow: some View {
        let s = L10n.shared.s
        let warning = shortcutMessage ?? (service.shortcutRefused ? s.shortcutNotCaptured : nil)
        return ZenithRow(text.shortcutTitle, info: text.shortcutCaption, warning: warning, shortcut: {
            ShortcutRecorderButton(
                shortcut: GlobalShortcut(storageValue: shortcut) ?? TranslateService.defaultShortcut,
                isEnabled: enabled,
                waitingTitle: s.shortcutPressKeys,
                emptyTitle: shortcut.isEmpty ? s.shortcutNone : nil,
                clearAction: {
                    shortcutMessage = nil
                    shortcut = ""
                    service.syncWithPreferences()
                },
                notCapturedAction: { shortcutMessage = s.shortcutNotCaptured },
                recordingChanged: { recording in if recording { shortcutMessage = nil } },
                invalidAction: { shortcutMessage = s.shortcutInvalid },
                captureAction: { captured in
                    if let owner = service.conflict(for: captured) {
                        shortcutMessage = s.shortcutConflictFormat.replacingOccurrences(of: "%@", with: owner)
                        return
                    }
                    shortcutMessage = nil
                    shortcut = captured.storageValue
                    service.syncWithPreferences()
                }
            )
        })
    }

    // MARK: Languages

    private var languagesSection: some View {
        ZenithSection(text.languagesSection, anchor: .zenithTranslateLanguages) {
            ZenithRow(text.target, selection: $target, info: text.targetCaption) {
                Text(text.name(text.systemLanguage, TranslateLanguageCode.displayName(system.primary))).tag("")
                Divider()
                ForEach(languages, id: \.self) { code in
                    Text(TranslateLanguageCode.displayName(code)).tag(code)
                }
            }
            ZenithRow(text.secondTarget, selection: $secondTarget, info: text.secondTargetCaption) {
                let fallback = TranslateLanguageCode.systemTargets(Locale.preferredLanguages,
                                                                   primary: preferences.primary).second
                Text(text.name(text.systemLanguage, fallback.map(TranslateLanguageCode.displayName) ?? text.none)).tag("")
                Text(text.none).tag(TranslateDefaults.noneValue)
                Divider()
                ForEach(languages, id: \.self) { code in
                    Text(TranslateLanguageCode.displayName(code)).tag(code)
                }
            }
            ZenithRow(text.showDetection, isOn: $showDetection, info: text.showDetectionCaption)
        }
    }

    // MARK: Downloads

    private var downloadsSection: some View {
        let current = preferences
        return ZenithSection(text.downloadsSection, anchor: .zenithTranslateDownloads, footer: text.downloadsCaption) {
            if let second = current.second {
                pairRow(from: second, to: current.primary)
                pairRow(from: current.primary, to: second)
            }
            ZenithRow(text.manageTitle, info: text.manageCaption, button: text.manageDownloads,
                      action: openLanguageSettings)
            ZenithMoreOptions(id: "translate.downloads") {
                ZenithRow(text.checkPair) {
                    HStack(spacing: 8) {
                        languagePicker(text.from, selection: $checkFrom)
                        Image(systemName: "arrow.right").font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        languagePicker(text.to, selection: $checkTo)
                    }
                }
                pairRow(from: checkFrom, to: checkTo.isEmpty ? current.primary : checkTo)
            }
        }
    }

    private func languagePicker(_ title: String, selection: Binding<String>) -> some View {
        Picker(title, selection: selection) {
            ForEach(languages, id: \.self) { code in
                Text(TranslateLanguageCode.displayName(code)).tag(code)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .fixedSize()
    }

    private func pairRow(from: String, to: String) -> some View {
        let key = Self.key(from, to)
        let status = statuses[key]
        return ZenithRow("\(TranslateLanguageCode.displayName(from)) → \(TranslateLanguageCode.displayName(to))") {
            HStack(spacing: 8) {
                if TranslateLanguageCode.same(from, to) {
                    EmptyView()
                } else if downloadingKey == key {
                    ProgressView().controlSize(.small)
                    Text(text.downloading).font(ZenithType.caption).foregroundStyle(.secondary)
                } else if let status {
                    statusChip(status)
                    if status == .notDownloaded {
                        Button(text.download) { startDownload(from: from, to: to) }
                    }
                } else {
                    Text(text.checking).font(ZenithType.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func statusChip(_ status: TranslatePairStatus) -> some View {
        let (label, color): (String, Color) = {
            switch status {
            case .installed: return (text.installed, ZenithStatus.success)
            case .notDownloaded: return (text.notDownloaded, ZenithStatus.warning)
            case .unsupported: return (text.unsupported, ZenithStatus.neutral)
            }
        }()
        return ZenithChip(label, dot: color)
    }

    // MARK: Work

    private static func key(_ from: String, _ to: String) -> String { from + ">" + to }

    private func loadStatuses() async {
        var found: [String: TranslatePairStatus] = [:]
        for pair in pairs where !TranslateLanguageCode.same(pair.from, pair.to) {
            found[Self.key(pair.from, pair.to)] = await TranslateEngine.status(from: pair.from, to: pair.to, text: "")
        }
        statuses = found
    }

    private func startDownload(from: String?, to: String) {
        downloadingKey = from.map { Self.key($0, to) }
        let configuration = TranslateEngine.configuration(from: from, to: to)
        if var existing = downloadConfiguration, existing.source == configuration.source,
           existing.target == configuration.target {
            existing.invalidate()
            downloadConfiguration = existing
        } else {
            downloadConfiguration = configuration
        }
    }

    /// A pair the card couldn't translate: shown as the pair being checked,
    /// and its download asked for right away.
    private func takePendingDownload() {
        guard let request = service.pendingDownload else { return }
        service.pendingDownload = nil
        if let from = request.from { checkFrom = from }
        checkTo = request.to
        UserDefaults.standard.set(true, forKey: ZenithMoreOptionsRule.key("translate.downloads"))
        startDownload(from: request.from, to: request.to)
    }

    private func openLanguageSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Localization-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }
}
