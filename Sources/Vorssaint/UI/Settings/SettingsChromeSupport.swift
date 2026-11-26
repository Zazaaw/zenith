// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: what a double-click on the Settings window's top does, after
/// the system's own choice (Desktop & Dock › Double-click a window's title bar
/// to). The window has no visible title bar, so its drag areas ask this.
enum SettingsTitleBarDoubleClick: Equatable {
    case zoom, minimize, none

    /// `AppleActionOnDoubleClick` names the choice; older systems only kept
    /// `AppleMiniaturizeOnDoubleClick`. Fill has no public call, so it zooms.
    static func action(setting: String?, legacyMinimize: Bool) -> Self {
        switch setting {
        case "Minimize": return .minimize
        case "None": return .none
        case "Maximize", "Zoom", "Fill": return .zoom
        default: return legacyMinimize ? .minimize : .zoom
        }
    }

    static func current(_ defaults: UserDefaults = .standard) -> Self {
        action(setting: defaults.string(forKey: "AppleActionOnDoubleClick"),
               legacyMinimize: defaults.bool(forKey: "AppleMiniaturizeOnDoubleClick"))
    }
}

/// Zenith fork: the Mac account the sidebar's account card shows. Read from
/// this Mac only (the login picture, full name, account type and computer
/// name); nothing is logged or sent anywhere.
struct SettingsAccountSummary: Equatable {
    enum Kind: Equatable {
        case admin, standard

        /// English, like the rest of the sidebar's own chrome.
        var title: String {
            switch self {
            case .admin: return "Admin"
            case .standard: return "Standard"
            }
        }
    }

    var name: String
    var kind: Kind?
    var computer: String

    var initials: String { ZenithLockScreenInitials.of(name) }

    /// "Admin · MacBook Pro", leaving out whichever part is unknown.
    var subtitle: String {
        [kind?.title, computer.trimmingCharacters(in: .whitespacesAndNewlines)]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    /// The full name, or the short login name when the account has none.
    static func displayName(fullName: String, userName: String) -> String {
        let full = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        return full.isEmpty ? userName.trimmingCharacters(in: .whitespacesAndNewlines) : full
    }

    /// The fixed identity the offscreen renders show, so no picture of the
    /// README carries a real account.
    static let placeholder = SettingsAccountSummary(name: "Jane Appleseed", kind: .admin, computer: "MacBook Pro")
}
