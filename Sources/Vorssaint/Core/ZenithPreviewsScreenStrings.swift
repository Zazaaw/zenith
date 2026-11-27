// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: the text of the preview cards on the Settings pages about the
// screen: General and the menu bar, Features, Energy, Monitor, Switcher,
// Dock, Window layout, Screen capture, Media and App updates. English in
// every language, like the shared card (ZenithSettingsPreviewStrings).

/// One preview: its name in the card's picker, what the picture shows, and
/// the name of the outlined part.
struct ZenithScreenPreviewText {
    let state: String
    let caption: String
    let part: String
}

struct ZenithPreviewsScreenStrings {
    // General and the menu bar.
    let look = ZenithScreenPreviewText(
        state: "Look",
        caption: "Zenith’s own windows and its menu bar panel take the look you pick on Appearance. The rest of the Mac keeps its own.",
        part: "Menu bar panel")
    let panel = ZenithScreenPreviewText(
        state: "Panel",
        caption: "Click Zenith’s icon in the menu bar and this panel opens, with the sections you pick below.",
        part: "Panel sections")
    let hider = ZenithScreenPreviewText(
        state: "Hider",
        caption: "Status items left of the divider tuck away, and come back when you click the arrow.",
        part: "Hidden items")

    // Sound.
    let mixer = ZenithScreenPreviewText(
        state: "Mixer",
        caption: "Each app gets its own volume in the panel’s sound section.",
        part: "Volume per app")
    let output = ZenithScreenPreviewText(
        state: "Output",
        caption: "Each press of the shortcut moves the sound to the next output you picked.",
        part: "Outputs in turn")
    let priority = ZenithScreenPreviewText(
        state: "Priority",
        caption: "When a device you rank higher connects, the Mac switches to it by itself.",
        part: "Device order")
    let musicBlock = ZenithScreenPreviewText(
        state: "Music",
        caption: "A media key no longer opens Music when nothing is playing.",
        part: "Blocked launch")

    // Features.
    let hub = ZenithScreenPreviewText(
        state: "Features",
        caption: "Each feature you turn on adds a part to the screen: readings in the menu bar, the island, previews over the Dock, the switcher. Turn one off and its part goes away.",
        part: "What features add")

    // Energy.
    let keepAwake = ZenithScreenPreviewText(
        state: "Awake",
        caption: "While it’s on, the menu bar icon lights up and the island shows the time left.",
        part: "Island strip")
    let brightness = ZenithScreenPreviewText(
        state: "Displays",
        caption: "The brightness keys reach external displays too, with the usual level on screen.",
        part: "Brightness level")
    let extraBrightness = ZenithScreenPreviewText(
        state: "Extra",
        caption: "On an XDR display, brightness goes past the usual maximum, for a bright room.",
        part: "Brightness past 100%")
    let bluetoothSleep = ZenithScreenPreviewText(
        state: "Bluetooth",
        caption: "Bluetooth turns off while the Mac sleeps, so headphones don’t stay connected to it, and comes back when it wakes.",
        part: "Bluetooth status")

    // Monitor.
    let monitorMenuBar = ZenithScreenPreviewText(
        state: "Menu bar",
        caption: "Live: the readings you pick below, as your menu bar shows them right now.",
        part: "Menu bar readings")
    let monitorPanel = ZenithScreenPreviewText(
        state: "Panel",
        caption: "Click the menu bar item for the panel: the blocks you pick below, with their graphs.",
        part: "Panel blocks")
    let fans = ZenithScreenPreviewText(
        state: "Fans",
        caption: "Fan speeds sit in the panel, where you set them by hand or leave them to the Mac.",
        part: "Fan control")

    // Switcher.
    let switcherWindows = ZenithScreenPreviewText(
        state: "Windows",
        caption: "Hold ⌘ and press Tab: the switcher steps through your windows, drawn as previews.",
        part: "Switcher")
    let switcherIcons = ZenithScreenPreviewText(
        state: "Icons",
        caption: "Hold ⌘ and press Tab: one large icon per app, with the windows of the picked one above it.",
        part: "Switcher")
    let switcherSimple = ZenithScreenPreviewText(
        state: "Simple",
        caption: "Hold ⌘ and press Tab: a row of icons under the picked app’s name, without previews.",
        part: "Switcher")

    // Dock.
    let dockPreview = ZenithScreenPreviewText(
        state: "Preview",
        caption: "Rest the pointer on a Dock icon to see that app’s windows, then click one to bring it forward.",
        part: "Window previews")
    let dockClick = ZenithScreenPreviewText(
        state: "Clicks",
        caption: "Click the icon of the app in front and its window minimizes into the Dock.",
        part: "Dock icon")
    let spacesOrder = ZenithScreenPreviewText(
        state: "Spaces",
        caption: "Your Spaces stay in the order you set, instead of moving by most recent use.",
        part: "Spaces")

    // Window layout.
    let snap = ZenithScreenPreviewText(
        state: "Snap",
        caption: "Drag a window to an edge, or press a shortcut, and it fills that part of the screen.",
        part: "Snap area")
    let maximize = ZenithScreenPreviewText(
        state: "Maximize",
        caption: "The green button fills the screen with the window, without a full screen Space.",
        part: "Green button")

    // Screen capture.
    let screenshot = ZenithScreenPreviewText(
        state: "Screenshot",
        caption: "Drag over any part of the screen. The capture lands in a thumbnail you can drag, edit or save.",
        part: "Selection")
    let scrolling = ZenithScreenPreviewText(
        state: "Scrolling capture",
        caption: "Select a window’s content and scroll: the pages are stitched into one tall image.",
        part: "Stitched image")
    let recording = ZenithScreenPreviewText(
        state: "Recording",
        caption: "Record the whole screen or a part of it, with a timer in the menu bar until you stop.",
        part: "Recording controls")
    let screenText = ZenithScreenPreviewText(
        state: "Copy text",
        caption: "Select text anywhere, even in a picture, and it’s copied as text.",
        part: "Copied text")
    let color = ZenithScreenPreviewText(
        state: "Color picker",
        caption: "A loupe follows the pointer. Click to copy the color under it.",
        part: "Loupe")

    // Media.
    let mediaVideo = ZenithScreenPreviewText(
        state: "Video",
        caption: "Drop a video in the panel and it comes out smaller, ready to send.",
        part: "Media in the panel")
    let mediaGIF = ZenithScreenPreviewText(
        state: "GIF",
        caption: "Turn a clip into a GIF, with its own size and frame rate.",
        part: "Media in the panel")
    let mediaImage = ZenithScreenPreviewText(
        state: "Image",
        caption: "Shrink an image or change its format, without its metadata.",
        part: "Media in the panel")
    let mediaText = ZenithScreenPreviewText(
        state: "Text",
        caption: "Drop an image or a PDF and copy the text in it.",
        part: "Media in the panel")

    // App updates.
    let updatesPanel = ZenithScreenPreviewText(
        state: "Panel",
        caption: "Apps with a newer version are listed in the panel, each with its own Update button.",
        part: "Update list")
    let updatesNotice = ZenithScreenPreviewText(
        state: "Notice",
        caption: "With checks on a schedule, a notification tells you when new versions are out.",
        part: "Notification")

    // Sample text drawn in the pictures.
    let keepAwakeToast = "Display stays on"
    let keepAwakeToastDetail = "Ends at 17.20 · on battery too"
    let studioDisplay = "Studio Display"
    let builtIn = "Built-in Display"
    let airPods = "AirPods Pro"
    let speakers = "MacBook Pro Speakers"
    let musicBlocked = "Music stayed closed"
    let bluetoothOff = "Bluetooth off while asleep"
    let bluetoothOn = "Bluetooth back on"
    let asleep = "Asleep"
    let windowsTitle = "Windows"
    let spacesKept = "Kept in your order"
    let desktop = "Desktop"
    let copied = "Copied"
    let copiedText = "Meeting moved to 3 pm"
    let updateAll = "Update All"
    let update = "Update"
    let updatesNoticeTitle = "3 app updates"
    let updatesNoticeBody = "Figma, Arc and Raycast have new versions."
    let compressed = "42 MB → 8.1 MB"
    let gifMade = "6.4 s · 12 fps"
    let imageShrunk = "4.2 MB → 640 KB"
    let textFound = "Text found: 214 words"
    let now = "now"
    let added = "Added"
    let monitorLabel = "Monitor"
    let islandLabel = "Dynamic Island"
    let dockLabel = "Dock"
    let switcherLabel = "Switcher"
    let cpu = "CPU"
    let memory = "Memory"
    let fan = "Fan"
    let auto = "Auto"
    let rpm = "2,400 rpm"
    let appMusic = "Music"
    let appSafari = "Safari"
    let appZoom = "Zoom"
    let appMail = "Mail"
    let appNotes = "Notes"
    let appFigma = "Figma"
    let appTerminal = "Terminal"
    let appArc = "Arc"
    let appRaycast = "Raycast"
    let figmaVersion = "124.5 → 124.6"
    let arcVersion = "1.62 → 1.63"
    let raycastVersion = "1.88 → 1.89"
    let videoFile = "Trip.mov"
    let gifFile = "Demo.gif"
    let imageFile = "Cover.heic"
    let pdfFile = "Brief.pdf"
    let selectionSize = "640 × 360"
    let colorHex = "#FF9F0A"
    let recordingTime = "0:12"
    let awakeTime = "1:20:00"
    let percent160 = "160%"

    static let shared = ZenithPreviewsScreenStrings()
}

extension ZenithStrings {
    /// English in every language (see the file's note).
    static func previewsScreen(_ language: AppLanguage) -> ZenithPreviewsScreenStrings { .shared }
}
