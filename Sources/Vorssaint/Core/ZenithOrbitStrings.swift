// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: the words of Orbit, the catalog of everything Zenith can do.
/// English only, by the owner's choice. A feature's longer description in
/// the detail sheet still comes from the strings Settings already shows.
struct ZenithOrbitStrings {
    let title = "Orbit"
    let subtitle = "Everything Zenith can do. Add what you need, leave the rest."
    let searchPlaceholder = "Search Orbit"
    let clearSearch = "Clear Search"

    // Buttons
    let get = "Get"
    let open = "Open"
    let turnOff = "Turn Off"
    let details = "Details"
    let done = "Done"
    let permissions = "Permissions"
    let unavailable = "Unavailable"

    // Sections
    let ourPicks = "Our Picks"
    let seeAll = "See All"
    let results = "Results"
    let noResults = "Nothing in Orbit matches that."
    let noneInstalled = "Nothing is on yet. Pick something from All and press Get."
    let featured = "New in Orbit"

    // States, for VoiceOver and the detail sheet
    let stateOn = "On"
    let stateOff = "Off"
    let stateNeedsPermission = "Needs permission"
    let needsFormat = "Needs %@"
    let alsoAddsFormat = "Works with %@. Get adds it too."
    let turnsOnInPage = "It is set up and switched on from its page in Settings."
    let partOfZenith = "Part of Zenith. Always here."
    let keepsSettings = "Turning it off keeps its settings for when it comes back."
    let runs = "Runs"
    let showsDetails = "Shows details"

    // Hero
    let heroText = "Your next call waits in the island. Join in one click, and see the mic while you talk."

    func category(_ category: OrbitCategory) -> String {
        switch category {
        case .all: return "All"
        case .island: return "Island"
        case .ai: return "AI"
        case .productivity: return "Productivity"
        case .media: return "Media"
        case .files: return "Files"
        case .capture: return "Capture"
        case .windows: return "Windows"
        case .input: return "Input"
        case .sound: return "Sound"
        case .system: return "System"
        case .devices: return "Devices"
        case .privacy: return "Privacy"
        case .installed: return "Installed"
        }
    }

    func name(_ id: OrbitItemID) -> String {
        switch id {
        case .feature(let feature): return Self.name(feature)
        case .page(let page): return Self.name(page)
        }
    }

    func summary(_ id: OrbitItemID) -> String {
        switch id {
        case .feature(let feature): return Self.summary(feature)
        case .page(let page): return Self.summary(page)
        }
    }

    private static func name(_ feature: AppFeature) -> String {
        switch feature {
        case .switcher: return "Window Switcher"
        case .dockPreview: return "Dock Preview"
        case .dockClick: return "Dock Click"
        case .windowMaximizer: return "Window Maximizer"
        case .windowLayout: return "Window Snap"
        case .autoQuit: return "Auto Quit"
        case .spacesOrder: return "Spaces Order"
        case .scrollInverter: return "Scroll Direction"
        case .scrollHorizontal: return "Horizontal Scroll"
        case .scrollZoom: return "Scroll Zoom"
        case .focusFollowsMouse: return "Focus Follows Mouse"
        case .smoothScroll: return "Smooth Scroll"
        case .linearScroll: return "Linear Scroll"
        case .scrollSpeed: return "Scroll Speed"
        case .mouseAcceleration: return "Mouse Acceleration"
        case .mouseNavigation: return "Mouse Navigation"
        case .mouseButtonShortcuts: return "Mouse Buttons"
        case .middleClick: return "Middle Click"
        case .mouseClickDebounce: return "Click Debounce"
        case .keyboardDebounce: return "Key Debounce"
        case .textSnippets: return "Text Snippets"
        case .superKey: return "Super Key"
        case .quitWindowProtection: return "Quit Protection"
        case .clipboardHistory: return "Clipboard"
        case .pastePlain: return "Paste as Plain Text"
        case .finderCutPaste: return "Cut and Paste"
        case .finderRename: return "Finder Rename"
        case .shelf: return "Shelf"
        case .urlCleaner: return "URL Cleaner"
        case .diskImageInstaller: return "Disk Image Installer"
        case .mixer: return "Volume Mixer"
        case .soundOutputSwitcher: return "Sound Output"
        case .audioPriority: return "Audio Priority"
        case .micMute: return "Mic Mute"
        case .musicBlock: return "Music Blocker"
        case .keepAwake: return "Keep Awake"
        case .brightness: return "Brightness"
        case .extraBrightness: return "Extra Brightness"
        case .bluetoothSleep: return "Bluetooth Sleep"
        case .quickLauncher: return "Quick Launcher"
        case .quickToggles: return "Quick Toggles"
        case .quitApps: return "Quit Apps"
        case .colorPicker: return "Color Picker"
        case .screenOCR: return "Text Capture"
        case .cleaningMode: return "Cleaning Mode"
        case .mediaTools: return "Media Tools"
        case .cleaner: return "Cleaner"
        case .uninstaller: return "Uninstaller"
        case .homebrew: return "Homebrew"
        case .appUpdates: return "App Updates"
        case .screenshot: return "Screenshot"
        case .cameraPreview: return "Camera Preview"
        case .radialMenu: return "Radial Menu"
        case .scratchpad: return "Scratchpad"
        case .commandBar: return "Command Bar"
        case .screenRecorder: return "Screen Recorder"
        case .wallpaper: return "Wallpaper"
        case .killProcess: return "Kill Process"
        case .portManager: return "Port Manager"
        case .notch: return "Dynamic Island"
        case .notchCalendar: return "Calendar"
        case .notchNotifications: return "Notifications"
        case .notchGestures: return "Island Gestures"
        case .notchTimer: return "Focus Timer"
        case .notchAccessories: return "Accessories"
        case .notchLyrics: return "Lyrics"
        case .notchQueue: return "Up Next"
        case .notchLiveEqualizer: return "Live Equalizer"
        case .notchDownloads: return "Downloads"
        case .notchAgents: return "Agents"
        case .notchWatch: return "Screen Watch"
        case .notchMascot: return "Mascot"
        case .monitorCPU: return "CPU"
        case .monitorGPU: return "GPU"
        case .monitorMemory: return "Memory"
        case .monitorNetwork: return "Network"
        case .monitorDisk: return "Disk"
        case .monitorPower: return "Power"
        case .connectedDevices: return "Connected Devices"
        case .fanControl: return "Fan Control"
        }
    }

    private static func summary(_ feature: AppFeature) -> String {
        switch feature {
        case .switcher: return "Every open window, one shortcut away"
        case .dockPreview: return "See an app’s windows by hovering its Dock icon"
        case .dockClick: return "Click a Dock icon to hide, minimize or cycle"
        case .windowMaximizer: return "Fill the screen without going full screen"
        case .windowLayout: return "Snap windows to halves, thirds and corners"
        case .autoQuit: return "Quit apps when their last window closes"
        case .spacesOrder: return "Keep your Spaces in the order you set"
        case .scrollInverter: return "Natural on the trackpad, classic on the mouse"
        case .scrollHorizontal: return "Hold a key to scroll sideways"
        case .scrollZoom: return "Zoom with a key and the scroll wheel"
        case .focusFollowsMouse: return "The window under the pointer takes focus"
        case .smoothScroll: return "Glide instead of jump on a mouse wheel"
        case .linearScroll: return "Every notch moves the same distance"
        case .scrollSpeed: return "Scroll faster or slower than macOS allows"
        case .mouseAcceleration: return "Move the pointer exactly as far as the mouse"
        case .mouseNavigation: return "Side buttons go back and forward"
        case .mouseButtonShortcuts: return "Give extra mouse buttons any shortcut"
        case .middleClick: return "Middle click from the trackpad"
        case .mouseClickDebounce: return "Stop a worn mouse from double clicking"
        case .keyboardDebounce: return "Ignore keys that repeat by themselves"
        case .textSnippets: return "Type a short word, get the whole text"
        case .superKey: return "One key that opens a layer of shortcuts"
        case .quitWindowProtection: return "Hold ⌘Q a moment before it quits"
        case .clipboardHistory: return "History, pins and smart previews"
        case .pastePlain: return "Paste without the formatting"
        case .finderCutPaste: return "Cut and paste files in Finder"
        case .finderRename: return "Rename many files at once"
        case .shelf: return "Park files in the island, drag them out later"
        case .urlCleaner: return "Strip tracking from links you copy"
        case .diskImageInstaller: return "Install apps from a disk image in one step"
        case .mixer: return "A volume slider for every app"
        case .soundOutputSwitcher: return "Switch speakers and headphones in a click"
        case .audioPriority: return "Pick the device that wins when it connects"
        case .micMute: return "Mute the mic everywhere with one shortcut"
        case .musicBlock: return "Keep Music from opening by itself"
        case .keepAwake: return "Keep the Mac awake for as long as you need"
        case .brightness: return "Brightness for every display, keys included"
        case .extraBrightness: return "Push an XDR display past its usual limit"
        case .bluetoothSleep: return "Bluetooth off while the Mac sleeps"
        case .quickLauncher: return "Your favorite apps in the menu bar panel"
        case .quickToggles: return "Dark Mode, hidden files and more in a click"
        case .quitApps: return "Quit every open app at once"
        case .colorPicker: return "Pick any color on screen"
        case .screenOCR: return "Copy the text inside any picture"
        case .cleaningMode: return "Lock the keyboard while you wipe it"
        case .mediaTools: return "Convert, resize and compress files"
        case .cleaner: return "Free space taken by caches and leftovers"
        case .uninstaller: return "Remove an app and everything it left"
        case .homebrew: return "Your Homebrew packages, without Terminal"
        case .appUpdates: return "Updates for every app, in one list"
        case .screenshot: return "Capture, mark up and share"
        case .cameraPreview: return "Check your look before a call"
        case .radialMenu: return "A ring of actions under the pointer"
        case .scratchpad: return "A note that is always one click away"
        case .commandBar: return "Search the Mac and run anything"
        case .screenRecorder: return "Record the screen, a window or an area"
        case .wallpaper: return "A fresh wallpaper whenever you like"
        case .killProcess: return "Stop a stuck process by name"
        case .portManager: return "See which app holds a port, and free it"
        case .notch: return "Music, timers and more around the camera"
        case .notchCalendar: return "Your next event, right under the camera"
        case .notchNotifications: return "Notifications that drop from the island"
        case .notchGestures: return "Swipe the island to skip or change volume"
        case .notchTimer: return "Timers that count down in the island"
        case .notchAccessories: return "AirPods and other batteries as they connect"
        case .notchLyrics: return "Sing along, line by line"
        case .notchQueue: return "What plays after this song"
        case .notchLiveEqualizer: return "Bars that dance with the music"
        case .notchDownloads: return "Downloads land in the island as they finish"
        case .notchAgents: return "Claude Code, Codex and others at a glance"
        case .notchWatch: return "Get told when a part of the screen changes"
        case .notchMascot: return "A small star that keeps you company"
        case .monitorCPU: return "Processor load and temperature"
        case .monitorGPU: return "Graphics load as you work"
        case .monitorMemory: return "Memory pressure and what uses it"
        case .monitorNetwork: return "Upload and download speed"
        case .monitorDisk: return "Free space and disk activity"
        case .monitorPower: return "Battery health, charge and draw"
        case .connectedDevices: return "Everything plugged in and paired"
        case .fanControl: return "Quiet or cool, by temperature"
        }
    }

    private static func name(_ page: SettingsPage) -> String {
        switch page {
        case .lockScreen: return "Lock Screen"
        case .meetings: return "Meetings"
        case .translate: return "Translate"
        case .mechakey: return "Mechakey"
        case .workspaces: return "Workspaces"
        case .pocket: return "Pocket"
        case .remote: return "iPhone Remote"
        case .batteries: return "Batteries"
        case .faceUnlock: return "Face Unlock"
        case .removeBackground: return "Remove Background" // Zenith fork: Orbit wave 2
        case .emojiPicker: return "Emoji Picker"
        case .calculator: return "Calculator"
        case .appLock: return "App Lock" // Zenith fork
        case .privacyBlur: return "Privacy Blur" // Zenith fork: Privacy
        default: return ""
        }
    }

    private static func summary(_ page: SettingsPage) -> String {
        switch page {
        case .lockScreen: return "Music, widgets and a clock while you are away"
        case .meetings: return "Join, mute and share from the island"
        case .translate: return "Select text anywhere, read it in your language"
        case .mechakey: return "Mechanical keyboard sounds as you type"
        case .workspaces: return "Set the Mac up for a kind of work in one click"
        case .pocket: return "Your Mac on iPhone, Watch and widgets"
        case .remote: return "Lock this Mac or check on it from your iPhone"
        case .batteries: return "Every device’s battery, and when to warn"
        case .faceUnlock: return "Unlock the Mac by looking at it"
        case .removeBackground: return "A transparent PNG of a picture’s subject" // Zenith fork: Orbit wave 2
        case .emojiPicker: return "Find an emoji by name and type it anywhere"
        case .calculator: return "Sums and functions, answered as you type"
        case .appLock: return "Touch ID, your face or your password before an app opens" // Zenith fork
        case .privacyBlur: return "Frost your chats from people looking at the screen" // Zenith fork: Privacy
        default: return ""
        }
    }
}

extension ZenithStrings {
    static let orbit = ZenithOrbitStrings()
}
