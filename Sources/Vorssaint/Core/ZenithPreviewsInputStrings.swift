// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: the preview cards' text on the mouse, keyboard, files and
// clipboard pages. English in every language, like the rest of Zenith's own
// pages (see ZenithSettingsPreviewStrings).

struct ZenithPreviewsInputStrings {
    // Mouse & Trackpad.
    let scroll = "Scroll"
    let pointer = "Pointer"
    let buttons = "Buttons"
    let mouse = "Mouse"
    let page = "Page"
    let wheelDown = "Wheel down"
    let pageMovesDown = "Page moves down"
    let pageMovesUp = "Page moves up"
    let pageMovesSideways = "Page moves sideways"
    let pageZooms = "Page zooms in"
    let notchByNotch = "Notch by notch"
    let smooth = "Smooth"
    let linesPerNotch = "lines per notch"
    let faster = "Faster while held"
    let focusFollows = "The window under the pointer gets the keys"
    let handSpeed = "Hand speed"
    let pointerTravel = "Pointer travel"
    let accelerated = "macOS curve"
    let linear = "Linear"
    let back = "Back"
    let forward = "Forward"
    let sideButton = "Side button"
    let missionControl = "Mission Control"
    let oneClick = "One click lands"
    let bounce = "Bounce, ignored"
    let threeFingerTap = "Three-finger tap"
    let opensInNewTab = "Opens in a new tab"
    let invertCaption = "Loops while you look: roll the wheel, see the page move. The mouse can scroll the classic way while the trackpad stays natural."
    let sidewaysCaption = "Hold the key and the wheel scrolls sideways, for timelines and wide sheets."
    let zoomCaption = "Hold the key and roll the wheel to zoom in and out where the pointer is."
    let smoothCaption = "Each notch glides instead of jumping, the way a trackpad scrolls."
    let linearCaption = "Every notch moves the page the same number of lines, however fast you roll."
    let speedCaption = "Hold the key to scroll faster through long pages."
    let focusCaption = "Move the pointer over a window and it takes the keyboard, without a click."
    let accelerationCaption = "With acceleration off, the pointer moves as far as your hand, at any speed."
    let navigationCaption = "The side buttons go back and forward in browsers, Finder and more."
    let buttonShortcutsCaption = "Give an extra mouse button a shortcut or a Spaces gesture."
    let debounceCaption = "A worn button that clicks twice is filtered, so one press is one click."
    let middleClickCaption = "Tap with three fingers or press the wheel for a middle click."

    // Key debounce.
    let without = "Without"
    let with = "With"
    let key = "Key"
    let typed = "Typed"
    let window = "Window"
    let oneLetter = "One letter lands"
    let twoLetters = "Two letters land"
    let debounceKeyCaption = "A worn key that fires twice in a moment types one letter, not two."
    let debounceOffCaption = "Without the filter, a worn key that fires twice types the letter twice."

    // Super key.
    let hold = "Hold"
    let tapAlone = "Tap alone"
    let holdKey = "Hold"
    let standsFor = "Stands for"
    let superHoldCaption = "Hold the key and it acts as all the modifiers you picked, so one finger makes a hyper shortcut."
    let superTapCaption = "Tap the key alone and it does what you chose below."
    let soloNothing = "Nothing"
    let soloCapsLock = "Caps Lock"
    let soloInputSource = "Next input source"
    let soloEscape = "Esc"

    // Cut & paste, rename.
    let cutPaste = "Cut & paste"
    let rename = "Rename"
    let desktop = "Desktop"
    let documents = "Documents"
    let cutPasteCaption = "⌘X marks the file, ⌘V in another folder moves it there."
    let renameCaption = "The rename shortcut opens the name field of the selected file."
    let sampleFile = "Report.pdf"
    let sampleImage = "IMG_2041.jpg"
    let renamedImage = "Holiday.jpg"

    // Auto quit.
    let autoQuitCaption = "Closing an app’s last window quits the app too, so the Dock only holds what you use."
    let closeLastWindow = "Last window closed"
    let appQuits = "App quits"

    // Quit protection.
    let holdToQuit = "Hold to quit"
    let pressTwice = "Press again to quit"
    let extraKey = "Add the extra key"
    let quitHoldCaption = "Hold the shortcut until the ring fills; a quick press does nothing."
    let quitDoubleCaption = "Press the shortcut twice in a row; one press only warns."
    let quitExtraCaption = "Only the shortcut with the extra key goes through."
    let closeWindow = "Close window"
    let quitApp = "Quit app"

    // URL cleaner.
    let copied = "Copied"
    let cleaned = "Clean link copied"
    let urlCaption = "Copy a link and its tracking parameters are taken out before you paste it."
    let rules = "Rules"
    let sampleHost = "example.com/item"
    let sampleTracking = ["?utm_source=news", "&utm_medium=mail", "&fbclid=Iw"]

    // Clipboard.
    let history = "History"
    let plainText = "Plain text"
    let qr = "QR"
    let historyCaption = "Everything you copy lands in a list, ready to paste again."
    let plainCaption = "Paste without the source’s fonts, colors and links."
    let qrCaption = "Turn what you copied into a QR code, or scan one on the screen."
    let sampleClips = ["Meeting moved to 3 pm", "https://example.com/docs", "#3B82F6", "Invoice 0142.pdf"]
    let richSample = "Quarterly results"
    let qrSample = "https://example.com"

    // Text snippets.
    let trigger = "Trigger"
    let library = "Library"
    let snippetCaption = "Type a trigger and it turns into the full text as you write."
    let libraryCaption = "Open the library with its shortcut and pick a snippet to paste."
    let sampleTrigger = ";addr"
    let sampleExpansion = "221B Baker Street, London"
    let sampleSnippets = [(";addr", "221B Baker Street, London"), (";thx", "Thanks, talk soon!"),
                          (";mail", "hello@example.com")]
    let searchSnippets = "Search snippets"

    // Radial menu.
    let radialCaption = "Press the trigger and a wheel of actions opens at the pointer; flick toward one to run it."
    let actions = "Actions"
    let wheelTrigger = "Trigger"
    let radialSamples = ["Safari", "Finder", "Screenshot", "Music", "Terminal", "Settings"]

    // Shortcuts.
    let shortcutsCaption = "Every global shortcut in one place. The keys light up for a few of yours."
    let keyboard = "Keyboard"

    /// Every string, for the coverage tests.
    var all: [String] {
        Mirror(reflecting: self).children.flatMap { child -> [String] in
            if let value = child.value as? String { return [value] }
            if let values = child.value as? [String] { return values }
            if let pairs = child.value as? [(String, String)] { return pairs.flatMap { [$0.0, $0.1] } }
            return []
        }
    }

    static let shared = ZenithPreviewsInputStrings()
}
