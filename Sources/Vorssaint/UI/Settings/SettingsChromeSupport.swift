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
