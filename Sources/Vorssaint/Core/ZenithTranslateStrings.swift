// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: Translate's text, for its card, its Settings page
// (Settings → Translate) and its Command Bar row. English in every language,
// by the owner's decision, as Batteries' and Face Unlock's. Settings search
// still finds the page by Indonesian aliases (TranslateSearch).

struct ZenithTranslateStrings {
    // Page.
    let title = "Translate"
    let subtitle = "Select text anywhere, press a shortcut, read it in your language. On this Mac, with Apple’s Translation."
    let enable = "Enable Translate"
    let enableCaption = "Off, nothing runs and the shortcut is free."
    let needsMacOS15 = "Translate needs macOS 15 or later."

    // Shortcut.
    let shortcutSection = "Shortcut"
    let shortcutTitle = "Translate selection"
    let shortcutCaption = "Reads the selected text. When an app doesn’t share it, Zenith copies it and puts your clipboard back."
    let accessibilityNeeded = "Zenith needs Accessibility to read the selected text."
    let openAccessibility = "Open Accessibility Settings"

    // Languages.
    let languagesSection = "Languages"
    let target = "Translate into"
    let targetCaption = "The language you read in."
    let secondTarget = "When it’s already in that language"
    let secondTargetCaption = "Translate into this one instead, such as Indonesian ↔ English."
    let systemLanguage = "System ({name})"
    let none = "None"
    let showDetection = "Show detected language"
    let showDetectionCaption = "The card says which language it found, and how sure it is."

    // Downloads.
    let downloadsSection = "Downloaded languages"
    let downloadsCaption = "Translation runs on this Mac. Each pair needs its languages downloaded once."
    let checking = "Checking…"
    let installed = "Installed"
    let notDownloaded = "Not downloaded"
    let unsupported = "Not supported"
    let download = "Download…"
    let downloading = "Downloading…"
    let manageDownloads = "Manage in System Settings"
    let manageTitle = "Translation languages"
    let manageCaption = "Language & Region → Translation Languages lists and removes what’s downloaded."
    let checkPair = "Check a pair"
    let from = "From"
    let to = "To"

    // Card.
    let detected = "Detected"
    let detect = "Detect Language"
    let swap = "Swap Languages"
    let copy = "Copy"
    let copied = "Copied"
    let replace = "Replace"
    let speak = "Speak"
    let stop = "Stop"
    let translating = "Translating…"
    let nothingSelected = "Select some text first, then press the shortcut again."
    let clipboardEmpty = "The clipboard has no text to translate."
    let alreadyIn = "This is already in {name}."
    let chooseSecond = "Pick a second language in Settings to translate it the other way."
    let pairNotDownloaded = "{from} → {to} isn’t downloaded yet."
    let pairUnsupported = "{from} → {to} can’t be translated on this Mac."
    let failed = "Couldn’t translate this."
    let truncated = "Only the first {n} characters were translated."
    let openSettings = "Settings…"
    let unknownLanguage = "Unknown"

    // Command Bar.
    let translateClipboard = "Translate Clipboard"

    func name(_ template: String, _ value: String) -> String {
        template.replacingOccurrences(of: "{name}", with: value)
    }

    func pair(_ template: String, from: String, to: String) -> String {
        template.replacingOccurrences(of: "{from}", with: from).replacingOccurrences(of: "{to}", with: to)
    }

    func count(_ template: String, _ value: Int) -> String {
        template.replacingOccurrences(of: "{n}", with: String(value))
    }

    /// Every string, for the coverage tests.
    var all: [String] {
        Mirror(reflecting: self).children.compactMap { $0.value as? String }
    }
}

extension ZenithStrings {
    /// English in every language (see the file's note).
    static func translate(_ language: AppLanguage) -> ZenithTranslateStrings {
        ZenithTranslateStrings()
    }
}

/// Settings search: the page by its English words and the Indonesian ones its
/// owner types.
enum TranslateSearch {
    static let aliases = ["translate", "translation", "translator", "language", "languages", "detect language",
                          "terjemah", "terjemahan", "terjemahkan", "penerjemah", "alih bahasa", "bahasa",
                          "bahasa inggris", "bahasa indonesia", "english", "indonesian"]

    static func keywords(_ language: AppLanguage) -> [String] {
        let text = ZenithStrings.translate(language)
        return [text.enable, text.shortcutTitle, text.target, text.downloadsSection]
    }
}
