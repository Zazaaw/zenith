// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI
import ServiceManagement

/// App-wide startup settings. Zenith fork: the theme moved to Settings → Appearance.
struct GeneralSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var hotkeys = HotkeyManager.shared
    // Seeded from the stored choice so the switch does not flash off while
    // the status read is still on its way.
    @State private var loginRegistration: LaunchAtLoginSupport.Registration =
        UserDefaults.standard.bool(forKey: DefaultsKey.launchAtLoginWanted) ? .enabled : .off
    @State private var loginError: String?
    @State private var loginPending = false
    @State private var loginRefreshID = UUID()
    @AppStorage(DefaultsKey.hotkeyEnabled) private var hotkeyEnabled = true

    private var text: GeneralSettingsStrings { FeatureStrings.generalSettings(l10n.language) }
    private var feedbackStrings: FeedbackStrings { FeatureStrings.feedback(l10n.language) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsPageHeader(title: l10n.s.tabGeneral, subtitle: text.pageDescription)
                ZenithScreenPreviewCard(group: .general, current: .look) // Zenith fork
                basicsCard
                if AppFeature.keepAwake.isAvailable {
                    shortcutCard
                }
                feedbackCard
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .onAppear { refreshLaunchAtLogin() }
        .onReceive(NotificationCenter.default.publisher(
            for: LaunchAtLoginSupport.settingsRefreshRequested)) { _ in
            refreshLaunchAtLogin()
        }
    }

    private var basicsCard: some View {
        SettingsCard {
            SettingsRow(symbol: "laptopcomputer", title: l10n.s.launchAtLogin,
                        caption: text.launchAtLoginCaption) {
                HStack {
                    if loginPending { ProgressView().controlSize(.small) }
                    // Waiting on approval it is still registered, so it reads on and
                    // switching it off unregisters it, which also clears the note.
                    Toggle(l10n.s.launchAtLogin, isOn: Binding(
                        get: { loginRegistration != .off },
                        set: { setLaunchAtLogin($0) }
                    ))
                        .labelsHidden()
                        .toggleStyle(ZenithSwitchStyle())
                        .disabled(loginPending)
                }
            }
            if loginRegistration == .needsApproval {
                Text(l10n.s.launchAtLoginNeedsApproval)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(l10n.s.permissionOpenSettings) {
                    SMAppService.openSystemSettingsLoginItems()
                }
            } else if let loginError {
                Text(loginError)
                    .font(.caption)
                    .foregroundStyle(ZenithStatus.error)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            SettingsRow(symbol: "globe", title: l10n.s.languageLabel) {
                Picker(l10n.s.languageLabel, selection: $l10n.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
        }
    }

    private var shortcutCard: some View {
        SettingsCard(title: l10n.s.globalHotkeySection) {
            SettingsRow(symbol: "keyboard", title: l10n.s.hotkeyToggle, caption: l10n.s.hotkeyCaption) {
                Toggle(l10n.s.hotkeyToggle, isOn: $hotkeyEnabled)
                    .labelsHidden()
                    .toggleStyle(ZenithSwitchStyle())
                    .onChange(of: hotkeyEnabled) { _, enabled in
                        HotkeyManager.shared.setEnabled(enabled)
                    }
            }
            ShortcutPreferenceRow(role: .keepAwake, isEnabled: hotkeyEnabled) {
                HotkeyManager.shared.syncWithPreferences()
            }
            .padding(.leading, settingsRowTextInset)
            if hotkeyEnabled, hotkeys.registrationFailed {
                Text(l10n.s.shortcutUnavailable)
                    .font(.caption)
                    .foregroundStyle(ZenithStatus.warning)
                    .padding(.leading, settingsRowTextInset)
            }
        }
    }

    private var feedbackCard: some View {
        SettingsCard {
            SettingsRow(symbol: "bubble.left.and.text.bubble.right", title: feedbackStrings.sectionTitle,
                        caption: feedbackStrings.sectionCaption) {
                Button(feedbackStrings.openButton) {
                    appDelegate()?.openFeedbackWindow()
                }
            }
        }
    }

    // Reads come with every visit and activation, so they update the switch
    // quietly; only a change makes it wait. A read that replaces a change's
    // answer runs after that change, so it frees the switch too.
    private func refreshLaunchAtLogin() {
        let requestID = UUID()
        loginRefreshID = requestID
        LaunchAtLogin.refresh { registration in
            guard loginRefreshID == requestID else { return }
            loginRegistration = registration
            loginError = nil
            loginPending = false
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        let requestID = UUID()
        loginRefreshID = requestID
        // Hold the switch where the user put it while the system answers,
        // instead of letting it spring back until the change lands.
        loginRegistration = enabled ? .enabled : .off
        loginError = nil
        loginPending = true
        LaunchAtLogin.setEnabled(enabled) { registration, error in
            guard loginRefreshID == requestID else { return }
            loginRegistration = registration
            // Approval guidance follows current system status, including on a
            // fresh page, instead of retaining an error from a previous attempt.
            loginError = registration == .needsApproval ? nil : error?.localizedDescription
            loginPending = false
        }
    }

}

/// The idle menu bar glyph, tinted white for dark surfaces.
struct MenuBarGlyph: View {
    /// Observed so the previews follow a newly chosen symbol right away.
    @AppStorage(DefaultsKey.menuBarIconSymbol) private var symbolName = ""

    var body: some View {
        Group {
            if let image = BlackHoleGlyph.mark(symbolName: Defaults.sanitizedMenuBarIconSymbol(symbolName)) {
                Image(nsImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
        .foregroundStyle(.white)
    }
}
