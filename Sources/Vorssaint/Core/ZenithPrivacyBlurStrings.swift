// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: Privacy Blur's text, for its Settings page. English in every
// language, by the owner's decision, as Mechakey's. Settings search still
// finds the page by Indonesian aliases (PrivacyBlurSearch).

struct ZenithPrivacyBlurStrings {
    // Page.
    let title = "Privacy Blur"
    let subtitle = "Frost your chats so people around you can’t read them. Hover to peek, the app keeps working underneath."
    let enable = "Enable Privacy Blur"
    let enableHint = "Off, nothing watches your apps and no overlay is drawn."

    // Accessibility.
    let accessibilityNeeded = "Privacy Blur follows your chat windows as they move through Accessibility. Without it the blur still works, but catches up a moment later."
    let openAccessibility = "Allow Accessibility"

    // Stage.
    let stageCaption = "A frosted pane sits just above the app’s window. Clicks go straight through."
    let stageBlurred = "Blurred"
    let stageHover = "Hover"
    let stageSharing = "Sharing"

    // Apps.
    let appsSection = "Apps"
    let appsFooter = "Privacy Blur draws a pane over these apps’ windows. Nothing is read from them or injected into them."
    let addApp = "Add App"
    let add = "Add"
    let addOtherApp = "Other App…"
    let remove = "Remove"
    let notInstalled = "Not installed on this Mac"
    let running = "Open"
    let notRunning = "Not open"
    let noApps = "Add an app to blur its windows."

    // Regions.
    let regionsSection = "What to blur"
    let regionsFor = "Regions for"
    let regionsCaption = "Everything always fits. The parts follow where each app usually puts its columns."
    let everything = "Everything"
    let everythingDetail = "The whole window, in two panes"
    let chatList = "Chat list"
    let chatListDetail = "The column of conversations"
    let messages = "Messages"
    let messagesDetail = "The open conversation"
    let names = "Names & photos"
    let namesDetail = "The conversation’s header and the list’s photos"
    let listEdge = "Chat list width"
    let listEdgeCaption = "Where the chat list ends, from the window’s left edge. Match it to the app if it moved."
    let resetListEdge = "Reset"
    let defaultListEdge = "The app’s usual width"
    let namesNote = "Names in the chat list sit beside their messages: blur the Chat list to hide them too."

    // Blur.
    let blurSection = "Blur"
    let strength = "Strength"
    let strengthCaption = "How much frost covers the blur. Strong is close to solid."
    let subtle = "Subtle"
    let strong = "Strong"

    // Revealing.
    let revealSection = "Revealing"
    let hover = "Hover reveals"
    let hoverCaption = "Moving the pointer over a blurred window shows what is under it, for you alone to read."
    let hoverOff = "Nothing"
    let hoverRegion = "The part under the pointer"
    let hoverCircle = "A circle around the pointer"
    let holdKey = "Hold to reveal all"
    let holdKeyCaption = "While you hold this key alone, every blurred window clears."
    let holdNone = "Off"
    let holdOption = "Option ⌥"
    let holdControl = "Control ⌃"
    let holdCommand = "Command ⌘"
    let revealWhileTyping = "Reveal while typing"
    let revealWhileTypingCaption = "The app’s window clears while you type in it, and frosts again a moment after."
    let shortcut = "Shortcut"
    let shortcutCaption = "Pauses the blur, or starts it while it is waiting for a share. The next change in sharing hands back to the rules."

    // When.
    let whenSection = "When"
    let when = "Blur"
    let whenCaption = "Always, or only while other people can see your screen."
    let whenAlways = "Always"
    let whenSharing = "Only while sharing"
    let presentation = "Presentation mode"
    let presentationCaption = "Counts as sharing until you turn it off: for calls Zenith can’t see."
    let detectionNote = "Zenith notices a mirrored display (a projector, a TV, AirPlay) and the screen watchers macOS reports, such as Screen Sharing. A call in Zoom, Meet or Teams doesn’t always show: turn on Presentation mode, or press the shortcut."
    let sharingNow = "Sharing now"
    let notSharing = "Not sharing"
    let paused = "Paused"

    // Chips.
    func appCount(_ count: Int) -> String { count == 1 ? "1 app" : "\(count) apps" }

    /// Every string, for the coverage tests.
    var all: [String] {
        Mirror(reflecting: self).children.compactMap { $0.value as? String }
    }

    func title(_ region: PrivacyBlurRegion) -> String {
        switch region {
        case .everything: return everything
        case .chatList: return chatList
        case .messages: return messages
        case .names: return names
        }
    }

    func detail(_ region: PrivacyBlurRegion) -> String {
        switch region {
        case .everything: return everythingDetail
        case .chatList: return chatListDetail
        case .messages: return messagesDetail
        case .names: return namesDetail
        }
    }

    func title(_ hover: PrivacyBlurHover) -> String {
        switch hover {
        case .off: return hoverOff
        case .region: return hoverRegion
        case .circle: return hoverCircle
        }
    }

    func title(_ key: PrivacyBlurHoldKey) -> String {
        switch key {
        case .none: return holdNone
        case .option: return holdOption
        case .control: return holdControl
        case .command: return holdCommand
        }
    }

    func title(_ when: PrivacyBlurWhen) -> String {
        switch when {
        case .always: return whenAlways
        case .whileSharing: return whenSharing
        }
    }
}

extension ZenithStrings {
    /// English in every language (see the file's note).
    static func privacyBlur(_ language: AppLanguage) -> ZenithPrivacyBlurStrings {
        ZenithPrivacyBlurStrings()
    }
}

/// Settings search: the page by its English words and the Indonesian ones its
/// owner types.
enum PrivacyBlurSearch {
    static let aliases = ["privacy blur", "privacy", "blur", "blur chat", "hide chat", "hide messages", "frost",
                          "whatsapp", "telegram", "screen sharing", "presentation", "shoulder surfing",
                          "privasi", "buram","sembunyikan chat", "sembunyikan pesan",
                          "samarkan", "kaburkan", "rahasia", "berbagi layar", "presentasi"]

    static func keywords(_ language: AppLanguage) -> [String] {
        let text = ZenithStrings.privacyBlur(language)
        return [text.enable, text.appsSection, text.regionsSection, text.strength, text.hover, text.shortcut,
                text.presentation]
    }
}
