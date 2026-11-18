// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Zenith fork: what the lock screen may show, one switch each.
///
/// Upstream shows every activity whose island section is on. Zenith keeps that
/// as the starting point (every switch on) and lets each one be turned off for
/// the lock screen alone, without touching the island.
enum NotchLockScreenItem: String, CaseIterable, Identifiable {
    case music, timer, agents, downloads, calendar

    var id: String { rawValue }

    var defaultsKey: String {
        switch self {
        case .music: return DefaultsKey.notchLockScreenMusic
        case .timer: return DefaultsKey.notchLockScreenTimer
        case .agents: return DefaultsKey.notchLockScreenAgents
        case .downloads: return DefaultsKey.notchLockScreenDownloads
        case .calendar: return DefaultsKey.notchLockScreenCalendar
        }
    }

    /// The island section it mirrors, for its name and symbol.
    var module: NotchModule {
        switch self {
        case .music: return .music
        case .timer: return .timer
        case .agents: return .agents
        case .downloads: return .downloads
        case .calendar: return .calendar
        }
    }

    func isOn(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: defaultsKey) as? Bool ?? true
    }
}

/// One switch per lock screen item, in the Lock Screen card.
struct NotchLockScreenItemToggles: View {
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        ForEach(NotchLockScreenItem.allCases) { item in
            NotchLockScreenItemRow(item: item, title: item.module.title(l10n.language))
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
        _isOn = AppStorage(wrappedValue: true, item.defaultsKey)
    }

    // A plain toggle rather than SettingsRow: the titles are the island's own
    // section names, already searchable as those sections.
    var body: some View {
        Toggle(isOn: $isOn) {
            Label(title, systemImage: item.module.symbol)
                .foregroundStyle(.secondary)
        }
        .toggleStyle(TrailingSwitchToggleStyle())
        .padding(.leading, 40)
        .padding(.vertical, 2)
    }
}
