// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: the tabs of Settings → Lock Screen, in the order they show.
/// Each tab holds one search anchor, so a search result that lands on the
/// page opens the tab its section is in.
enum ZenithLockScreenSettingsTab: String, CaseIterable, Identifiable {
    case wallpaper, music, terminal, full

    var id: String { rawValue }

    static let fallback: Self = .wallpaper

    /// The anchor Settings search lands on inside this tab.
    var anchor: SettingsSectionAnchor {
        switch self {
        case .wallpaper: return .zenithLockScreen
        case .music: return .zenithLockScreenMusic
        case .terminal: return .zenithLockScreenTerminal
        case .full: return .zenithLockScreenLyrics
        }
    }

    /// The tab that holds an anchor, nil for one outside this page.
    init?(anchor: SettingsSectionAnchor?) {
        guard let tab = Self.allCases.first(where: { $0.anchor == anchor }) else { return nil }
        self = tab
    }

    /// The tab last shown, or the first one.
    static func stored(_ raw: String?) -> Self {
        raw.flatMap(Self.init(rawValue:)) ?? fallback
    }
}
