// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: Privacy Blur's text, for its Settings page. English in every
// language, by the owner's decision, as Mechakey's. Settings search still
// finds the page by Indonesian aliases (PrivacyBlurSearch).

struct ZenithPrivacyBlurStrings {
    // Page.
    let title = "Privacy Blur"
    let subtitle = "Blur each chat, message, name and photo so people around you can’t read them. Hover one to peek, the app keeps working underneath."
    let enable = "Enable Privacy Blur"
    let enableHint = "Off, nothing watches your apps and no overlay is drawn."

    // Accessibility.
    let accessibilityNeeded = "Privacy Blur finds each chat, message and photo, and follows your chat windows as they move, through Accessibility. Without it each window blurs whole and catches up a moment later."
    let openAccessibility = "Allow Accessibility"

    // Stage.
    let stageCaption = "Each item gets its own blur, just above the app’s window. Clicks go straight through."
    let stageBlurred = "Blurred"
    let stageHover = "Hover"
    let stageSharing = "Sharing"

    // Apps.
    let appsSection = "Apps"
    let appsFooter = "Privacy Blur draws over these apps’ windows. It reads only where things sit in them, never what they say, and changes nothing inside them."
    let addApp = "Add App"
    let add = "Add"
    let addOtherApp = "Other App…"
    let remove = "Remove"
    let notInstalled = "Not installed on this Mac"
    let running = "Open"
    let notRunning = "Not open"
    let noApps = "Add an app to blur its windows."

    // What to blur.
    let itemsSection = "What to blur"
    let itemsFooter = "Each item blurs on its own and clears when you hover it. Zenith finds them by their shape in the app’s Accessibility tree; it never reads what they say."
    let blurMode = "Blur"
    let modeItems = "Each item"
    let modeItemsExperimental = "Each item (experimental)"
    let modeWindow = "Whole window"
    let modeCaption = "Each item blurs chat rows, bubbles, names and photos one by one. Whole window covers it all with one pane, for apps Zenith doesn’t know."
    let messages = "All messages in chat"
    let messagesCaption = "Every bubble in the open chat."
    let previews = "Last messages preview"
    let previewsCaption = "The last message under each chat in the list."
    let media = "Media preview"
    let mediaCaption = "Photos, videos and stickers in the chat, apart from text."
    let avatars = "Profile pictures"
    let avatarsCaption = "The photos in the chat list and the open chat’s header."
    let names = "Group/user names"
    let namesCaption = "The names in the chat list and the open chat’s header."
    let input = "Blur typing input"
    let inputCaption = "The field you type your message in."
    let itemsNeedAccessibility = "Each item needs Accessibility to find the items. Without it the whole window blurs."
    let windowOnlyNote = "Apps set to Whole window, and any app while Zenith can’t make out its layout, blur whole: hovering clears a circle around the pointer."
    let genericNote = "For apps other than WhatsApp, Each item blurs every text block, picture and text field Zenith can find. It hasn’t been tuned for them yet."

    // Blur.
    let blurSection = "Blur"
    let strength = "Strength"
    let strengthCaption = "How much frost covers the blur. Strong is close to solid."
    let subtle = "Subtle"
    let strong = "Strong"

    // Revealing.
    let revealSection = "Revealing"
    let hoverReveal = "Reveal items on hover"
    let hoverRevealCaption = "The item under the pointer clears for you to read; the rest stays blurred. On a window blurred whole, a circle around the pointer clears."
    let noDelay = "No transition delay"
    let noDelayCaption = "Items clear as soon as the pointer reaches them, without the short rest first."
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

    func title(_ mode: PrivacyBlurMode, generic: Bool) -> String {
        switch mode {
        case .items: return generic ? modeItemsExperimental : modeItems
        case .window: return modeWindow
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
                          "privasi", "buram", "sembunyikan chat", "sembunyikan pesan",
                          "samarkan", "kaburkan", "rahasia", "berbagi layar", "presentasi",
                          "foto profil", "nama grup", "pratinjau pesan"]

    static func keywords(_ language: AppLanguage) -> [String] {
        let text = ZenithStrings.privacyBlur(language)
        return [text.enable, text.appsSection, text.itemsSection, text.messages, text.previews, text.media,
                text.avatars, text.names, text.input, text.strength, text.hoverReveal, text.noDelay, text.shortcut,
                text.presentation]
    }
}
