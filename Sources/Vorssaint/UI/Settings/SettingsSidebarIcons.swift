// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

/// Zenith fork: the Orbit icon for every Settings destination, in one table.
/// A destination without an Orbit icon of its own keeps its SF Symbol, drawn
/// in the same squircle with its group's colours, so the sidebar stays even.
enum SettingsSidebarIcons {
    /// The Orbit icon's name (see `OrbitIcons`), or nil to draw `symbol` instead.
    static func orbitName(for id: SettingsSidebarItem.ID) -> String? {
        switch id {
        case .page(let page): return orbitName(page: page)
        case .feature(let feature): return orbitName(feature: feature)
        case .setting(let anchor):
            switch anchor {
            case .screenshotScrolling: return "Scrolling Screenshot"
            case .keyboardBrightnessShortcuts: return nil
            default: return orbitName(page: anchor.page)
            }
        }
    }

    static func orbitName(page: SettingsPage) -> String? {
        switch page {
        case .general: return "General"
        case .appearance: return "Appearance"
        case .commandBar: return "Command Bar"
        case .features: return "Orbit"
        case .notch: return "Dynamic Island"
        case .notchMascot: return "Mascot"
        case .lockScreen: return "Lock Screen"
        case .clipboard: return "Clipboard"
        case .shelf: return "Shelf"
        case .media: return "Media Tools"
        case .finderTools: return "Finder Tools"
        case .urlCleaner: return "URL Cleaner"
        case .textSnippets: return "Text Snippets"
        case .screenshot: return "Screenshot"
        case .switcher: return "Window Switcher"
        case .dock: return "Dock"
        case .spaces: return "Spaces"
        case .quickLauncher: return "Quick Launcher"
        case .quickToggles: return "Quick Toggles"
        case .quitApps: return "Quit Apps"
        case .cleaningMode: return "Cleaning Mode"
        case .wallpaper: return "Wallpaper"
        case .scratchpad: return "Scratchpad"
        case .windowLayout: return "Window Layout"
        case .autoQuit: return "Auto Quit"
        case .workspaces: return "Workspaces"
        case .radialMenu: return "Radial Menu"
        case .superKey: return "Super Key"
        case .sleep: return "Sleep" // Zenith fork: the System group's split pages
        case .brightness: return "Brightness"
        case .fanControl: return "Fan Control"
        case .menuBar: return "Menu Bar Hider"
        case .monitor: return "System Monitor"
        case .cleaner: return "Cleaner"
        case .uninstaller: return "Uninstaller"
        case .homebrew: return "Homebrew"
        case .appUpdates: return "App Updates"
        case .portManager: return "Port Manager"
        case .remote: return "iPhone Remote"
        case .pocket: return "Pocket"
        case .faceUnlock: return "Face Unlock"
        case .batteries: return "Batteries"
        case .meetings: return "Meetings"
        case .translate: return "Quick Translate"
        case .mechakey: return "Mechakey"
        case .removeBackground: return "Remove Background" // Zenith fork: Orbit wave 2
        case .emojiPicker: return "Emoji Picker"
        case .calculator: return "Calculator"
        case .appLock: return "App Lock" // Zenith fork
        case .privacyBlur: return "Privacy Blur" // Zenith fork: Privacy
        // Zenith fork: the island's sections, pages of their own.
        case .notchCalendar: return "Calendar"
        case .notchNotifications: return "Notifications"
        case .notchMusic: return "Music"
        case .notchTimer: return "Timer"
        case .notchAgents: return "Agents"
        case .notchDownloads: return "Downloads"
        case .notchWatch: return "Watch"
        case .volumeMixer: return "Volume Mixer"
        case .soundOutput: return "Sound Output"
        case .musicBlocker: return "Music Blocker"
        case .micMute: return "Mic Mute"
        case .screenRecording: return "Screen Recording"
        case .textCapture: return "Text Capture"
        case .colorPicker: return "Color Picker"
        case .cameraPreview: return "Camera Preview"
        // Zenith fork: the Mouse page, split.
        case .scrolling: return "Scrolling"
        case .pointer: return "Pointer"
        case .mouseButtons: return "Mouse Buttons"
        case .keyDebounce, .quitProtection, .killProcess,
             .shortcuts, .advanced, .about, .releaseNotes, .support:
            return nil
        }
    }

    static func orbitName(feature: AppFeature) -> String? {
        switch feature {
        case .switcher: return "Window Switcher"
        case .dockPreview: return "Dock Preview"
        case .windowLayout: return "Window Snap"
        case .autoQuit: return "Auto Quit"
        case .radialMenu: return "Radial Menu"
        case .smoothScroll: return "Smooth Scroll"
        case .superKey: return "Super Key"
        case .textSnippets: return "Text Snippets"
        case .clipboardHistory: return "Clipboard"
        case .shelf: return "Shelf"
        case .urlCleaner: return "URL Cleaner"
        case .mediaTools: return "Media Tools"
        case .scratchpad: return "Scratchpad"
        case .mixer: return "Volume Mixer"
        case .soundOutputSwitcher: return "Sound Output"
        case .musicBlock: return "Music Blocker"
        case .micMute: return "Mic Mute"
        case .keepAwake: return "Keep Awake"
        case .brightness: return "Brightness"
        case .cleaningMode: return "Cleaning Mode"
        case .screenshot: return "Screenshot"
        case .screenRecorder: return "Screen Recorder"
        case .screenOCR: return "Text Capture"
        case .colorPicker: return "Color Picker"
        case .cameraPreview: return "Camera Preview"
        case .cleaner: return "Cleaner"
        case .uninstaller: return "Uninstaller"
        case .homebrew: return "Homebrew"
        case .appUpdates: return "App Updates"
        case .portManager: return "Port Manager"
        case .commandBar: return "Command Bar"
        case .notch: return "Dynamic Island"
        case .notchCalendar: return "Calendar"
        case .notchNotifications: return "Notifications"
        case .notchTimer: return "Focus Timer"
        case .notchLyrics: return "Lyrics"
        case .notchAgents: return "Agents"
        case .notchMascot: return "Mascot"
        case .monitorCPU, .monitorGPU, .monitorMemory, .monitorNetwork, .monitorDisk: return "System Monitor"
        case .fanControl: return "Fan Control"
        // Zenith fork: the features of the Input and Windows pages draw their page's icon.
        case .dockClick: return "Dock"
        case .spacesOrder: return "Spaces"
        case .windowMaximizer: return "Window Layout"
        case .scrollInverter, .scrollHorizontal, .scrollZoom, .linearScroll, .scrollSpeed: return "Scrolling"
        case .focusFollowsMouse, .mouseAcceleration: return "Pointer"
        case .mouseNavigation, .mouseButtonShortcuts, .middleClick, .mouseClickDebounce: return "Mouse Buttons"
        case .quickLauncher: return "Quick Launcher"
        case .quickToggles: return "Quick Toggles"
        case .quitApps: return "Quit Apps"
        case .wallpaper: return "Wallpaper"
        case .quitWindowProtection,
             .keyboardDebounce, .pastePlain, .finderCutPaste, .finderRename, .diskImageInstaller,
             .audioPriority, .extraBrightness, .bluetoothSleep,
             .killProcess,
             .notchGestures, .notchAccessories, .notchQueue, .notchLiveEqualizer, .notchDownloads, .notchWatch,
             .monitorPower, .connectedDevices:
            return nil
        }
    }

    /// The SF Symbol a page's header draws when the kit has no icon for it,
    /// the one its sidebar row shows; nil for the pages `orbitName` covers.
    static func fallbackSymbol(page: SettingsPage) -> String? {
        switch page {
        case .keyDebounce: return "keyboard"
        case .quitProtection: return "shield.lefthalf.filled"
        case .killProcess: return "xmark.octagon"
        case .shortcuts: return "command"
        case .advanced: return "wrench.and.screwdriver"
        case .about: return "info.circle"
        case .releaseNotes: return "sparkles"
        case .support: return "heart.fill"
        default: return nil
        }
    }

    /// Whether a compact icon's colours are all near white, too pale for the
    /// Light Mode squircle.
    static func isPale(_ colors: [Color]) -> Bool {
        colors.allSatisfy { color in
            guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return false }
            return rgb.saturationComponent < 0.15 && rgb.brightnessComponent > 0.6
        }
    }

    /// The Orbit icon for `id`, when the table names one the kit has.
    static func orbitIcon(for id: SettingsSidebarItem.ID) -> OrbitIcon? {
        orbitName(for: id).flatMap(OrbitIcons.named)
    }
}

extension SettingsSidebarGroup {
    /// The colours a fallback symbol is filled with: the group's category
    /// tint (`ZenithCategoryTint`), and grey for Zenith's own pages, whose
    /// symbols sit among the monochrome tiles.
    var tint: [Color] {
        switch self {
        case .tiles, .zenith: return [Color(white: 0.72), Color(white: 0.42)]
        default: return ZenithCategoryTint.of(self).colors
        }
    }
}

/// A destination's icon at `size`: the Orbit icon when the table names one,
/// otherwise its SF Symbol on the same squircle in its group's colours.
/// `rich` draws the Orbit art (page headers); otherwise the compact symbol.
struct SettingsDestinationIcon: View {
    let id: SettingsSidebarItem.ID
    let symbol: String
    var size: CGFloat = 22
    var rich = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        OrbitRasterizedIcon(key: "destination|\(id)|\(symbol)|\(rich)", size: size) {
            if let icon = SettingsSidebarIcons.orbitIcon(for: id) {
                if rich {
                    OrbitIconView(icon: icon)
                } else if colorScheme == .light, SettingsSidebarIcons.isPale(icon.tint) {
                    // A near-white symbol (Command Bar) would vanish on the
                    // porcelain squircle; it takes the grey of the app's own group.
                    SettingsFallbackIcon(symbol: icon.compact, tint: SettingsSidebarGroup.zenith.tint)
                } else {
                    OrbitCompactIconView(icon: icon)
                }
            } else {
                SettingsFallbackIcon(symbol: symbol, tint: SettingsSidebarGroup.of(id).tint)
            }
        }
        .accessibilityHidden(true)
    }
}

/// An SF Symbol drawn like `OrbitCompactIconView`, at 100×100.
struct SettingsFallbackIcon: View {
    let symbol: String
    let tint: [Color]

    var body: some View {
        ZStack {
            OrbitIconBase()
            Image(systemName: symbol).font(.system(size: 50, weight: .bold))
                .foregroundStyle(LinearGradient(colors: tint, startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: .black.opacity(0.35), radius: 2, y: 2)
        }
        .frame(width: 100, height: 100)
    }
}

// MARK: - Page header icon

/// The icon the open page's header draws beside its title. Settings sets it
/// for the page it shows; a sheet or a nested header clears it.
struct SettingsPageIcon: Equatable {
    let id: SettingsSidebarItem.ID
    let symbol: String
}

private struct SettingsPageIconKey: EnvironmentKey {
    static let defaultValue: SettingsPageIcon? = nil
}

extension EnvironmentValues {
    var settingsPageIcon: SettingsPageIcon? {
        get { self[SettingsPageIconKey.self] }
        set { self[SettingsPageIconKey.self] = newValue }
    }
}
