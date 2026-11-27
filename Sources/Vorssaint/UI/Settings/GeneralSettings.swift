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

    // Zenith fork: the kit's reference system page (docs/SETTINGS-KIT.md): the
    // system header, the preview on the stage, then sections of compact rows.
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZenithSystemHeader(title: l10n.s.tabGeneral, subtitle: text.pageDescription)
                ZenithScreenPreviewCard(group: .general, current: .look)
                startup
                if AppFeature.keepAwake.isAvailable {
                    shortcut
                }
                feedback
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

    private var startup: some View {
        ZenithSection {
            // Waiting on approval it is still registered, so it reads on and
            // switching it off unregisters it, which also clears the note.
            ZenithRow(l10n.s.launchAtLogin, info: text.launchAtLoginCaption,
                      essential: loginRegistration == .needsApproval ? l10n.s.launchAtLoginNeedsApproval : nil,
                      warning: loginRegistration == .needsApproval ? nil : loginError) {
                HStack(spacing: 8) {
                    if loginPending { ProgressView().controlSize(.small) }
                    ZenithRowSwitch(title: l10n.s.launchAtLogin, isOn: Binding(
                        get: { loginRegistration != .off },
                        set: { setLaunchAtLogin($0) }
                    ))
                    .disabled(loginPending)
                }
            }
            if loginRegistration == .needsApproval {
                ZenithRow(l10n.s.launchAtLogin, button: l10n.s.permissionOpenSettings) {
                    SMAppService.openSystemSettingsLoginItems()
                }
            }
            ZenithRow(l10n.s.languageLabel, selection: $l10n.language) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }
        }
    }

    private var shortcut: some View {
        ZenithSection(l10n.s.globalHotkeySection) {
            ZenithRow(l10n.s.hotkeyToggle, isOn: $hotkeyEnabled, info: l10n.s.hotkeyCaption,
                      warning: hotkeyEnabled && hotkeys.registrationFailed ? l10n.s.shortcutUnavailable : nil)
                .onChange(of: hotkeyEnabled) { _, enabled in
                    HotkeyManager.shared.setEnabled(enabled)
                }
            ShortcutPreferenceRow(role: .keepAwake, isEnabled: hotkeyEnabled) {
                HotkeyManager.shared.syncWithPreferences()
            }
            .padding(.vertical, 9)
        }
    }

    private var feedback: some View {
        ZenithSection {
            ZenithRow(feedbackStrings.sectionTitle, info: feedbackStrings.sectionCaption,
                      button: feedbackStrings.openButton) {
                appDelegate()?.openFeedbackWindow()
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
