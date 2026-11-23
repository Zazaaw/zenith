// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: the text of the preview cards on the tool and info pages of
// Settings (Quick Tools, Cleaner, Homebrew, Uninstaller, Kill Process, Port
// Manager, Advanced, About, What’s New, Support). English in every language,
// like the rest of Zenith’s own pages. The sample rows the pictures show are
// made up, so no scan, process list or Homebrew call runs for a picture.

struct ZenithPreviewsToolsStrings {
    // Quick Tools.
    let quickPanelState = "Panel"
    let quickWindowsState = "Windows"
    let quickAppsState = "Apps"
    let quickLauncher = "Quick panel"
    let quickToggles = "Quick toggles"
    let quitApps = "Quit apps"
    let micMute = "Mute microphone"
    let cameraPreview = "Camera preview"
    let wallpaper = "Wallpaper"
    let scratchpad = "Scratchpad"
    let cleaningMode = "Cleaning mode"
    let quickPanelCaption = "The quick panel floats over any app with your tools, and the toggles wait in the menu bar panel."
    let quickWindowsCaption = "A scratchpad for quick notes and a mirror of your camera, each in its own floating window."
    let quickAppsCaption = "Quit every open app in one go, and mute the microphone with the island showing it."
    let quickWallpaperCaption = "Pick a wallpaper from the menu bar panel; Zenith can set it on every display."
    let quickCleaningCaption = "Cleaning mode locks the keyboard so you can wipe it, and blacks out the screen unless you keep it visible."

    // Quick Tools samples.
    let sampleKeepAwake = "Keep awake"
    let sampleCleaner = "Cleaner"
    let sampleToggles = "Toggles"
    let sampleMic = "Mute mic"
    let sampleText = "Copy text"
    let sampleColor = "Pick color"
    let sampleClipboard = "Clipboard"
    let sampleLayout = "Layout"
    let sampleCleaning = "Cleaning"
    let sampleHomebrew = "Homebrew"
    let sampleCamera = "Camera"
    let sampleNotes = "Scratchpad"
    let sampleDarkMode = "Dark mode"
    let sampleHiddenFiles = "Show hidden files"
    let sampleDesktopIcons = "Hide desktop icons"
    let sampleEmptyTrash = "Empty Trash"
    let sampleNoteTitle = "Thursday"
    let sampleNoteLines = ["Send the invoice to Rina", "Book the studio for Friday", "Export the logo in SVG", "Call back about the print run"]
    let sampleMicMuted = "Microphone muted"
    let sampleQuitting = "Quitting 5 apps…"
    let sampleCleaningTitle = "Keyboard locked for cleaning"
    let sampleCleaningHint = "Press Escape 5 times to unlock"
    let sampleCleaningUnlock = "Unlock"
    let sampleWallpapers = "Wallpapers"
    let sampleAllDisplays = "On every display"

    // Cleaner.
    let cleanerState = "Cleaner"
    let whatsAppState = "WhatsApp"
    let cleanerCaption = "Scans caches, logs and developer files, then shows what is safe to clean and how much space it frees."
    let whatsAppCaption = "Finds the files WhatsApp saved to Downloads and sends the ones past your limit to the Trash."
    let cleanerTitle = "Cleaner"
    let cleanerScanning = "Scanning…"
    let cleanerSafe = "Safe to clean"
    let cleanerOptional = "Optional"
    let cleanerCaches = "App caches"
    let cleanerLogs = "Logs"
    let cleanerDeveloper = "Developer files"
    let cleanerLogin = "Old login items"
    let cleanerOptionalRow = "Leftovers, Trash and old screenshots"
    let cleanerButton = "Clean 4.6 GB"
    let whatsAppTitle = "WhatsApp downloads"
    let whatsAppFolder = "Downloads"
    let whatsAppKeep = "Kept"
    let whatsAppTrash = "To Trash"
    let whatsAppButton = "Move 3 to Trash · 412 MB"

    // Homebrew.
    let homebrewCaption = "Your formulae and casks with the updates waiting, in the menu bar panel and on this page."
    let homebrewTitle = "Homebrew"
    let homebrewSearch = "Search"
    let homebrewInstalled = "Installed"
    let homebrewUpdates = "3 updates"
    let homebrewUpdatesLeft = "2 updates"
    let homebrewUpgradeAll = "Upgrade all"
    let homebrewUpgrading = "Upgrading…"

    // Uninstaller.
    let uninstallerCaption = "Drop an app to see the files it left around the Mac, with their sizes, before anything moves to the Trash."
    let uninstallerTitle = "Uninstaller"
    let uninstallerApp = "Lumen"
    let uninstallerAppDetail = "Version 2.4 · 312 MB"
    let uninstallerFound = "5 files found"
    let uninstallerButton = "Move to Trash · 2.0 GB"

    // Kill Process.
    let killCaption = "Every running process with its CPU and memory. Quit one from this page or from the Command Bar."
    let killQuery = "kill"
    let killButton = "Kill"
    let killQuit = "Quit"

    // Port Manager.
    let portCaption = "The ports open on this Mac and the process behind each, so a stuck dev server is one click away."
    let portTitle = "Port Manager"
    let portFilter = "Filter ports"
    let portAllInterfaces = "All interfaces"
    let portKill = "Kill"

    // Advanced.
    let advancedCaption = "What these tools reach: your settings file, the permissions Zenith holds, and the app itself."
    let advancedBackup = "Settings backup"
    let advancedBackupDetail = "Export, import, config file"
    let advancedPermissions = "Permissions"
    let advancedPermissionsDetail = "Accessibility and more"
    let advancedUninstall = "Uninstall"
    let advancedUninstallDetail = "App, preferences, caches"

    // About.
    let aboutCaption = "The app, its version and the studio behind it."
    func aboutVersion(_ version: String) -> String { "Version \(version)" }
    let aboutBy = "by"

    // What’s New.
    let notesCaption = "The highlights of this version. The full list follows below."
    let notesTitle = "What’s new"
    let notesFallback = "Fixes and refinements across the app."

    // Support.
    let supportCaption = "Zenith is free. A star on GitHub or a coffee keeps it growing."
    let supportLine = "Made with care, free for everyone."
    let supportStar = "Star"
    let supportCoffee = "Coffee"

    static let shared = ZenithPreviewsToolsStrings()
}
