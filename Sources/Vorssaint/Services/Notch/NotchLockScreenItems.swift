// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

/// Zenith fork: what the lock screen may show, one switch each.
///
/// Upstream shows every activity whose island section is on. Zenith keeps that
/// as the starting point (every switch on) and lets each one be turned off for
/// the lock screen alone, without touching the island. Weather and reminders
/// have no island section and need a permission, so they start off and ask
/// for it only when switched on.
enum NotchLockScreenItem: String, CaseIterable, Identifiable {
    case music, timer, agents, downloads, calendar, wakatime
    case weather, reminders

    var id: String { rawValue }

    var defaultsKey: String {
        switch self {
        case .music: return DefaultsKey.notchLockScreenMusic
        case .timer: return DefaultsKey.notchLockScreenTimer
        case .agents: return DefaultsKey.notchLockScreenAgents
        case .downloads: return DefaultsKey.notchLockScreenDownloads
        case .calendar: return DefaultsKey.notchLockScreenCalendar
        case .wakatime: return DefaultsKey.notchLockScreenWakaTime
        case .weather: return DefaultsKey.notchLockScreenWeather
        case .reminders: return DefaultsKey.notchLockScreenReminders
        }
    }

    /// The island section it mirrors, for its name and symbol.
    var module: NotchModule? {
        switch self {
        case .music: return .music
        case .timer: return .timer
        case .agents: return .agents
        case .downloads: return .downloads
        case .calendar: return .calendar
        case .wakatime: return .wakatime
        case .weather, .reminders: return nil
        }
    }

    var symbol: String {
        switch self {
        case .weather: return "cloud.sun"
        case .reminders: return "checklist"
        default: return module?.symbol ?? "circle"
        }
    }

    func title(_ language: AppLanguage) -> String {
        switch self {
        case .weather: return ZenithStrings.lockScreenWidgets(language).weather
        case .reminders: return ZenithStrings.lockScreenWidgets(language).reminders
        default: return module?.title(language) ?? rawValue
        }
    }

    /// Items that need a permission start off.
    var isOnByDefault: Bool {
        switch self {
        case .weather, .reminders: return false
        default: return true
        }
    }

    func isOn(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: defaultsKey) as? Bool ?? isOnByDefault
    }
}

/// One switch per lock screen item, in the Lock Screen card.
struct NotchLockScreenItemToggles: View {
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        // WakaTime only on a Mac that has it.
        ForEach(NotchLockScreenItem.allCases.filter { $0 != .wakatime || WakaTimeSupport.hasConfiguration() }) { item in
            NotchLockScreenItemRow(item: item, title: item.title(l10n.language))
        }
    }
}

private struct NotchLockScreenItemRow: View {
    let item: NotchLockScreenItem
    let title: String
    @AppStorage private var isOn: Bool

    init(item: NotchLockScreenItem, title: String) {
        self.item = item
        self.title = title
        _isOn = AppStorage(wrappedValue: item.isOnByDefault, item.defaultsKey)
    }

    // A plain toggle rather than SettingsRow: the titles are the island's own
    // section names, already searchable as those sections.
    var body: some View {
        Toggle(isOn: $isOn) {
            Label(title, systemImage: item.symbol)
                .foregroundStyle(.secondary)
        }
        .toggleStyle(TrailingSwitchToggleStyle())
        .padding(.leading, 40)
        .padding(.vertical, 2)
        // The permission is asked for here, when the person turns the item on,
        // and never at launch or from the lock screen.
        .onChange(of: isOn) { _, on in
            guard on else { return }
            switch item {
            case .weather: WeatherService.shared.requestAccess()
            case .reminders: RemindersService.shared.requestAccess()
            default: break
            }
        }
        if isOn {
            switch item {
            case .weather: NotchLockScreenWeatherAccess()
            case .reminders: NotchLockScreenRemindersAccess()
            default: EmptyView()
            }
        }
    }
}

/// Under the Weather switch: where the data comes from, or what permission is missing.
private struct NotchLockScreenWeatherAccess: View {
    @ObservedObject private var weather = WeatherService.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let text = ZenithStrings.lockScreenWidgets(l10n.language)
        NotchLockScreenAccessNote(
            access: weather.access, caption: text.weatherCaption, needed: text.locationNeeded,
            denied: text.locationDenied, request: { weather.requestAccess() },
            openSettings: { weather.openLocationSettings() })
            .onAppear { weather.refreshAccess() }
    }
}

/// Under the Reminders switch: what shows, or what permission is missing.
private struct NotchLockScreenRemindersAccess: View {
    @ObservedObject private var reminders = RemindersService.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let text = ZenithStrings.lockScreenWidgets(l10n.language)
        NotchLockScreenAccessNote(
            access: reminders.access, caption: text.remindersCaption, needed: text.remindersNeeded,
            denied: text.remindersDenied, request: { reminders.requestAccess() },
            openSettings: { reminders.openRemindersSettings() })
            .onAppear { reminders.refreshAccess() }
            // Access changed in System Settings shows here when Zenith comes back.
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                reminders.refreshAccess()
            }
    }
}

private struct NotchLockScreenAccessNote: View {
    let access: LockScreenWidgetAccess
    let caption: String
    let needed: String
    let denied: String
    let request: () -> Void
    let openSettings: () -> Void
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch access {
            case .granted:
                Text(caption)
            case .notDetermined:
                Text(needed)
                Button(l10n.s.permissionRequest, action: request)
                    .controlSize(.small)
            case .denied:
                Text(denied)
                Button(l10n.s.permissionOpenSettings, action: openSettings)
                    .controlSize(.small)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 40 + 28)
        .padding(.bottom, 2)
    }
}
