// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: the words the Input, Windows and quick tool pages add when
/// they open with a hero: titles of the pages that used to be sections,
/// subtitles and chips. English in every language, like the rest of
/// Zenith's own chrome; the rows keep their localized strings.
struct ZenithInputWindowsStrings {
    // Input.
    let scrollingTitle = "Scrolling"
    let scrollingSubtitle = "How the wheel and the trackpad scroll: direction, sideways, zoom, smoothness and speed."
    let pointerTitle = "Pointer"
    let pointerSubtitle = "How the pointer moves, and whether windows come forward under it."
    let mouseButtonsTitle = "Mouse Buttons"
    let mouseButtonsSubtitle = "Back and forward, shortcuts on extra buttons, the middle click and a filter for worn switches."
    let keyDebounceSubtitle = "Drops the extra presses a worn or chattering key sends."
    let superKeySubtitle = "One key held down stands for several modifiers at once."
    let direction = "Direction"
    let zoom = "Zoom"
    let scrollKey = "Key to hold"
    let tapToClick = "Tap to middle click"
    let shortcutsSection = "Shortcuts"
    let perKeySection = "Per key"
    let soloSection = "Pressed alone"
    let modifiersRow = "Stands for"

    // Windows.
    let switcherSubtitle = "Switch apps and windows from the keyboard, with previews or plain icons."
    let dockTitle = "Dock"
    let dockSubtitle = "Window previews over Dock icons, and what a click on an icon does."
    let spacesTitle = "Spaces"
    let spacesSubtitle = "Keeps your Spaces in the order you set, so macOS stops rearranging them."
    let windowLayoutSubtitle = "Snap windows to halves, thirds and corners, maximize with the green button."
    let autoQuitSubtitle = "Quits an app when you close its last window."
    let quitProtectionSubtitle = "Stops ⌘Q and ⌘W from closing things by accident."
    let workspacesSubtitle = "Open the apps, windows and settings of one way of working with a shortcut."
    let radialMenuSubtitle = "A ring of actions at the pointer, opened from a key or a mouse button."
    let layoutSection = "Layout"
    let previewsSize = "Preview size"
    let placementsSection = "Placements"
    let moreLayouts = "Thirds, quarters, sixths and corners"
    let maximizeSection = "Green button"
    let snapSection = "Snap"
    let onlyWhenOn = "Shows while Dock Preview is on."

    // Quick tools.
    let quickLauncherSubtitle = "A grid of Zenith’s tools, opened from a shortcut."
    let quickTogglesSubtitle = "Dark Mode, hidden files, the keyboard light and more, one click each in the panel."
    let quitAppsSubtitle = "Quit every app, or every app but the one in front, in one go."
    let cleaningModeSubtitle = "Locks the keyboard and the screen while you wipe them."
    let wallpaperSubtitle = "Choose the desktop picture from the panel."
    let scratchpadSubtitle = "A floating note for what you need for a moment."
    let open = "Open"
    let tryIt = "Try it"
    let keepsNotes = "Keeps notes"

    // Chips.
    let activeNow = "Active now"
    func onCount(_ on: Int, of total: Int) -> String { "\(on) of \(total) on" }
    func count(_ value: Int, _ one: String, _ many: String) -> String { "\(value) \(value == 1 ? one : many)" }
}

extension ZenithStrings {
    static func inputWindows(_ language: AppLanguage) -> ZenithInputWindowsStrings {
        ZenithInputWindowsStrings()
    }
}
