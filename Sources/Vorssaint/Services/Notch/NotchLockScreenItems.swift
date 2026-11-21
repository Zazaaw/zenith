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
    /// The next prayer and the golden hour (SkyService): worked out offline,
    /// they start off so the lock screen line stays as it was.
    case prayer, golden

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
        case .prayer: return DefaultsKey.notchLockScreenPrayer
        case .golden: return DefaultsKey.notchLockScreenGolden
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
        case .weather, .reminders, .prayer, .golden: return nil
        }
    }

    var symbol: String {
        switch self {
        case .weather: return "cloud.sun"
        case .reminders: return "checklist"
        case .prayer: return "moon.stars"
        case .golden: return "sun.horizon"
        default: return module?.symbol ?? "circle"
        }
    }

    func title(_ language: AppLanguage) -> String {
        switch self {
        case .weather: return ZenithStrings.lockScreenWidgets(language).weather
        case .reminders: return ZenithStrings.lockScreenWidgets(language).reminders
        case .prayer: return ZenithStrings.sky(language).lockPrayer
        case .golden: return ZenithStrings.sky(language).lockGolden
        default: return module?.title(language) ?? rawValue
        }
    }

    /// Items that need a permission start off.
    var isOnByDefault: Bool {
        switch self {
        case .weather, .reminders, .prayer, .golden: return false
        default: return true
        }
    }

    func isOn(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: defaultsKey) as? Bool ?? isOnByDefault
    }
}

/// One switch per lock screen item, in Settings → Lock Screen. Zenith fork:
/// the terminal readout has a card of its own there (ZenithLockScreenSettings).
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
        ZenithSwitchRow(title, isOn: $isOn) {
            NotchLockScreenItemLabel(title: title, symbol: item.symbol)
        }
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
        .padding(.leading, 28)
        .padding(.bottom, 2)
    }
}

/// A lock screen item's icon and name, greyed while the lock screen is off.
struct NotchLockScreenItemLabel: View {
    let title: String
    let symbol: String
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Label(title, systemImage: symbol)
            .foregroundStyle(isEnabled ? .primary : .secondary)
    }
}
