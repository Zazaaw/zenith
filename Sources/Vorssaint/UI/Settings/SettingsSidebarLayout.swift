// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: where each Settings destination sits in the sidebar. Four big
/// tiles on top, then small groups under uppercase headers. One table, so a
/// page or feature added later lands in a group (the switches below are
/// exhaustive) and never drops out of the sidebar.
enum SettingsSidebarGroup: Int, CaseIterable, Identifiable {
    /// The four tiles above the groups: General, Appearance, Command Bar, Orbit.
    case tiles
    case island, everyday, capture, windows, input, sound, system, apps, devices
    /// The features Zenith added through Orbit, such as Meetings and Translate.
    case fromOrbit
    /// The app itself: shortcuts, advanced, what's new, support, about.
    case zenith

    var id: Int { rawValue }

    /// English in every language, like the rest of Zenith's own chrome.
    var title: String {
        switch self {
        case .tiles: return ""
        case .island: return "Island"
        case .everyday: return "Everyday"
        case .capture: return "Capture"
        case .windows: return "Windows"
        case .input: return "Input"
        case .sound: return "Sound"
        case .system: return "System"
        case .apps: return "Apps"
        case .devices: return "Devices"
        case .fromOrbit: return "From Orbit"
        case .zenith: return "Zenith"
        }
    }

    static func of(_ id: SettingsSidebarItem.ID) -> SettingsSidebarGroup {
        switch id {
        case .page(let page): return of(page: page)
        case .feature(let feature): return of(feature: feature)
        case .setting(let anchor):
            switch anchor {
            case .keyboardBrightnessShortcuts: return .zenith
            default: return of(page: anchor.page)
            }
        }
    }

    static func of(page: SettingsPage) -> SettingsSidebarGroup {
        switch page {
        case .general, .appearance, .commandBar, .features: return .tiles
        case .notch, .notchMascot, .lockScreen,
             .notchCalendar, .notchNotifications, .notchMusic, .notchTimer, .notchAgents, .notchDownloads,
             .notchWatch: return .island
        case .clipboard, .finderTools, .shelf, .media, .urlCleaner, .textSnippets: return .everyday
        case .quickLauncher, .quickToggles, .quitApps, .cleaningMode, .wallpaper, .scratchpad: return .everyday
        case .screenshot, .screenRecording, .textCapture, .colorPicker, .cameraPreview: return .capture
        case .volumeMixer, .soundOutput, .musicBlocker, .micMute: return .sound
        case .switcher, .dock, .spaces, .windowLayout, .autoQuit, .quitProtection, .workspaces, .radialMenu: return .windows
        case .scrolling, .pointer, .mouseButtons, .keyDebounce, .superKey: return .input
        case .monitor: return .system
        case .sleep, .brightness, .fanControl, .menuBar: return .system // Zenith fork
        case .cleaner, .uninstaller, .homebrew, .appUpdates, .killProcess, .portManager: return .apps
        case .remote, .pocket, .faceUnlock, .batteries: return .devices
        case .meetings, .translate, .mechakey,
             .removeBackground, .emojiPicker, .calculator: return .fromOrbit // Zenith fork: Orbit wave 2
        case .shortcuts, .advanced, .about, .releaseNotes, .support: return .zenith
        }
    }

    static func of(feature: AppFeature) -> SettingsSidebarGroup {
        switch feature {
        case .switcher, .dockPreview, .dockClick, .windowMaximizer, .windowLayout, .autoQuit, .spacesOrder,
             .quitWindowProtection, .radialMenu:
            return .windows
        case .scrollInverter, .scrollHorizontal, .scrollZoom, .focusFollowsMouse, .smoothScroll, .linearScroll,
             .scrollSpeed, .mouseAcceleration, .mouseNavigation, .mouseButtonShortcuts, .middleClick,
             .mouseClickDebounce, .keyboardDebounce, .superKey:
            return .input
        case .clipboardHistory, .pastePlain, .finderCutPaste, .finderRename, .shelf, .urlCleaner,
             .diskImageInstaller, .textSnippets, .mediaTools, .scratchpad, .quickLauncher,
             .quickToggles, .quitApps, .wallpaper, .cleaningMode:
            return .everyday
        case .mixer, .soundOutputSwitcher, .audioPriority, .micMute, .musicBlock:
            return .sound
        case .keepAwake, .brightness, .extraBrightness, .bluetoothSleep,
             .monitorCPU, .monitorGPU, .monitorMemory, .monitorNetwork, .monitorDisk, .monitorPower,
             .connectedDevices, .fanControl:
            return .system
        case .screenshot, .screenRecorder, .screenOCR, .colorPicker, .cameraPreview:
            return .capture
        case .cleaner, .uninstaller, .homebrew, .appUpdates, .killProcess, .portManager:
            return .apps
        case .commandBar:
            return .tiles
        case .notch, .notchCalendar, .notchNotifications, .notchGestures, .notchTimer, .notchAccessories,
             .notchLyrics, .notchQueue, .notchLiveEqualizer, .notchDownloads, .notchAgents, .notchWatch,
             .notchMascot:
            return .island
        }
    }
}

enum SettingsSidebarLayout {
    /// The tiles, in reading order of the 2×2 grid.
    static let tiles: [SettingsSidebarItem.ID] = [
        .page(.general), .page(.appearance), .page(.commandBar), .page(.features),
    ]

    /// Rows that open their group, ahead of the directory's order.
    static let leading: [SettingsSidebarGroup: [SettingsSidebarItem.ID]] = [
        .island: [.page(.notch), .page(.lockScreen), .page(.notchCalendar), .page(.notchNotifications),
                  .page(.notchMusic), .page(.notchTimer), .page(.notchAgents), .page(.notchDownloads),
                  .page(.notchWatch), .page(.notchMascot)],
        .everyday: [.page(.shelf), .page(.clipboard), .page(.finderTools), .page(.media), .page(.urlCleaner),
                    .page(.textSnippets)],
        .capture: [.page(.screenshot), .page(.screenRecording), .page(.textCapture), .page(.colorPicker),
                   .page(.cameraPreview)],
        .sound: [.page(.volumeMixer), .page(.soundOutput), .page(.musicBlocker), .page(.micMute)],
        .system: [.page(.monitor), .page(.fanControl), .page(.sleep), .page(.brightness), .page(.menuBar)],
        .devices: [.page(.pocket), .page(.batteries), .page(.faceUnlock), .page(.remote)],
    ]

    /// The Orbit tile's name. English, like the store it opens.
    static let orbitTitle = "Orbit"

    /// Sorts `rows` (in the directory's order) into the tiles and the groups.
    /// Every row lands exactly once; a group without rows is left out.
    static func sections(_ rows: [SettingsSidebarItem]) -> [SettingsSidebarSection] {
        var byGroup: [SettingsSidebarGroup: [SettingsSidebarItem]] = [:]
        var seen = Set<SettingsSidebarItem.ID>()
        for row in rows where seen.insert(row.id).inserted {
            byGroup[SettingsSidebarGroup.of(row.id), default: []].append(row)
        }
        return SettingsSidebarGroup.allCases.compactMap { group in
            guard let items = byGroup[group], !items.isEmpty else { return nil }
            return SettingsSidebarSection(group: group, items: ordered(items, in: group))
        }
    }

    private static func ordered(_ items: [SettingsSidebarItem], in group: SettingsSidebarGroup)
        -> [SettingsSidebarItem] {
        let first = group == .tiles ? tiles : leading[group] ?? []
        guard !first.isEmpty else { return items }
        let head = first.compactMap { id in items.first { $0.id == id } }
        return head + items.filter { !first.contains($0.id) }
    }
}

// MARK: - Keyboard navigation

enum SettingsSidebarDirection { case up, down, left, right }

/// Where an arrow key moves the sidebar's selection: around the 2×2 tiles,
/// then down through the rows of the open groups and back up into the tiles.
enum SettingsSidebarNavigation {
    static func move(from current: SettingsSidebarItem.ID?, direction: SettingsSidebarDirection,
                     tiles: [SettingsSidebarItem.ID], rows: [SettingsSidebarItem.ID]) -> SettingsSidebarItem.ID? {
        guard let current else { return tiles.first ?? rows.first }
        if let index = tiles.firstIndex(of: current) {
            switch direction {
            case .left: return index % 2 == 1 ? tiles[index - 1] : nil
            case .right: return index % 2 == 0 && index + 1 < tiles.count ? tiles[index + 1] : nil
            case .up: return index >= 2 ? tiles[index - 2] : nil
            case .down: return index + 2 < tiles.count ? tiles[index + 2] : rows.first
            }
        }
        // A row in a folded group is still selected; the walk starts over at
        // the first open row.
        guard let index = rows.firstIndex(of: current) else {
            return direction == .down ? rows.first : nil
        }
        switch direction {
        case .left, .right: return nil
        // Up from the first row lands on the tiles' bottom-left.
        case .up: return index > 0 ? rows[index - 1] : (tiles.isEmpty ? nil : tiles[(tiles.count - 1) / 2 * 2])
        case .down: return index + 1 < rows.count ? rows[index + 1] : nil
        }
    }
}
