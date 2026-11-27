// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

#if VORSSAINT_DEVELOPMENT
import AppKit
import SwiftUI

/// Zenith fork: the Input, Windows and quick tool pages on the kit
/// (`ONLY=kit-iw`), in Dark and Light Mode, with their main switches on so
/// the options under them show.
@MainActor
extension CatalogShots {
    static var kitInputWindows: [CatalogShot] {
        let pages: [(String, SettingsPage, [String: Any], CGFloat)] = [
            ("scrolling", .scrolling, [DefaultsKey.smoothScrollEnabled: true, DefaultsKey.scrollHorizontalEnabled: true,
                                       ZenithMoreOptionsRule.key("scrolling.smooth"): true], 1500),
            ("pointer", .pointer, [DefaultsKey.focusFollowsMouseEnabled: true], 1000),
            ("mouse-buttons", .mouseButtons, [DefaultsKey.middleClickEnabled: true,
                                              DefaultsKey.mouseClickDebounceEnabled: true], 1500),
            ("key-debounce", .keyDebounce, [DefaultsKey.keyboardDebounceEnabled: true], 1000),
            ("super-key", .superKey, [DefaultsKey.superKeyEnabled: true], 1100),
            ("switcher", .switcher, [ZenithMoreOptionsRule.key("switcher"): true], 2000),
            ("dock", .dock, [DefaultsKey.dockPreviewEnabled: true], 1500),
            ("spaces", .spaces, [:], 800),
            ("window-layout", .windowLayout, [DefaultsKey.windowGestureEnabled: true], 1800),
            ("auto-quit", .autoQuit, [DefaultsKey.autoQuitEnabled: true], 1200),
            ("quit-protection", .quitProtection, [DefaultsKey.quitProtectionQuitEnabled: true], 1400),
            ("workspaces", .workspaces, [:], 1400),
            ("radial-menu", .radialMenu, [DefaultsKey.radialMenuEnabled: true], 1700),
            ("quick-launcher", .quickLauncher, [:], 900),
            ("quick-toggles", .quickToggles, [:], 900),
            ("quit-apps", .quitApps, [:], 1000),
            ("cleaning-mode", .cleaningMode, [:], 800),
            ("wallpaper", .wallpaper, [:], 800),
            ("scratchpad", .scratchpad, [ZenithMoreOptionsRule.key("scratchpad"): true], 1100),
        ]
        var shots: [CatalogShot] = []
        for (name, page, preferences, height) in pages {
            for (suffix, appearance) in [("dark", NSAppearance.Name.darkAqua), ("light", .aqua)] {
                var shot = settings("kit-iw-\(name)-\(suffix)", page: page, preferences: preferences, settle: 1.5,
                                    height: height)
                shot.appearance = appearance
                shots.append(shot)
            }
        }
        return shots
    }
}
#endif
