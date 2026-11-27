// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: the Emoji Picker's text, for its panel, its Settings page and
// its Command Bar row. English in every language, by the owner's decision, as
// Mechakey's. Settings search still finds the page by Indonesian aliases
// (EmojiPickerSearch).

struct ZenithEmojiPickerStrings {
    // Page.
    let title = "Emoji Picker"
    let subtitle = "Type a word, pick with the arrow keys, press Return. The emoji lands where you were typing."
    let enable = "Enable Emoji Picker"
    let enableHint = "Off, nothing runs and the shortcut is free."

    // Opening.
    let openSection = "Opening"
    let shortcut = "Shortcut"
    let shortcutCaption = "Opens the picker over the app you are typing in."
    let showInCommandBar = "Show in Command Bar"
    let showInCommandBarCaption = "An Emoji Picker row in the Command Bar opens the picker."

    // Picking.
    let pickingSection = "Picking"
    let skinTone = "Skin tone"
    let skinToneCaption = "For the hands and people that come in skin tones."
    let recentCount = "Recent and frequently used"
    let recentCountCaption = "How many emoji each row at the top of the picker holds. Zero hides them."
    let clearRecents = "Clear Recent"
    let clearRecentsCaption = "Forgets which emoji you picked. Kept on this Mac only."
    let accessibilityNeeded = "Zenith needs Accessibility to paste the emoji into the app in front."
    let openAccessibility = "Open Accessibility Settings"
    let licenceLine = "Emoji names and keywords from Unicode’s emoji data and CLDR, Unicode License v3. The Mac’s own font draws them."
    let showLicense = "Show License"
    let hideLicense = "Hide License"

    // Tones.
    let toneYellow = "Yellow"
    let toneLight = "Light"
    let toneMediumLight = "Medium Light"
    let toneMedium = "Medium"
    let toneMediumDark = "Medium Dark"
    let toneDark = "Dark"

    // Panel.
    let searchPlaceholder = "Search emoji"
    let noResults = "No emoji found"
    let hint = "↩ Insert   ⎋ Close"

    // Stage.
    let stageCaption = "Type to filter, the arrows to move, Return to insert"
    let stageBrowse = "Browse"
    let stageSearch = "Search"

    func tone(_ tone: CommandBarEmoji.SkinTone) -> String {
        switch tone {
        case .none: return toneYellow
        case .light: return toneLight
        case .mediumLight: return toneMediumLight
        case .medium: return toneMedium
        case .mediumDark: return toneMediumDark
        case .dark: return toneDark
        }
    }

    func emojiCount(_ count: Int) -> String { "\(count) emoji" }

    /// Every string, for the coverage tests.
    var all: [String] {
        Mirror(reflecting: self).children.compactMap { $0.value as? String }
    }
}

extension ZenithStrings {
    /// English in every language (see the file's note).
    static func emojiPicker(_ language: AppLanguage) -> ZenithEmojiPickerStrings {
        ZenithEmojiPickerStrings()
    }
}

enum EmojiPickerSearch {
    static let aliases = ["emoji", "emojis", "emoji picker", "emoticon", "smiley", "smileys", "emoji keyboard",
                          "character viewer", "skin tone", "kaomoji",
                          "pilih emoji", "pemilih emoji", "stiker", "ikon wajah", "warna kulit"]

    static func keywords(_ language: AppLanguage) -> [String] {
        let text = ZenithStrings.emojiPicker(language)
        return [text.enable, text.shortcut, text.skinTone, text.recentCount, text.showInCommandBar]
    }
}
