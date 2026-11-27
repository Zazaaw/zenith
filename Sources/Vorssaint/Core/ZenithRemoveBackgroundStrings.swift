// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: Remove Background's text, for its card, its Settings page, its
// Command Bar row and the Shelf's menu. English in every language, by the
// owner's decision, as Mechakey's. Settings search still finds the page by
// Indonesian aliases (RemoveBackgroundSearch).

struct ZenithRemoveBackgroundStrings {
    // Page.
    let title = "Remove Background"
    let subtitle = "Lift the subject out of a picture as a transparent PNG, on this Mac with Apple’s Vision."
    let enable = "Enable Remove Background"
    let enableHint = "Off, nothing runs and the shortcut is free."

    // Where it works.
    let triggersSection = "Where it works"
    let shortcut = "Shortcut"
    let shortcutCaption = "With Finder in front, removes the background of the selected pictures. Anywhere else, of the picture on the clipboard."
    let commandBarRow = "Remove Background from Clipboard"
    let commandBarCaption = "A row in the Command Bar while Remove Background is on."
    let shelfRow = "Shelf"
    let shelfCaption = "Right-click a picture on the Shelf and choose Remove Background."
    let automationNote = "The first time, macOS asks to let Zenith read Finder’s selection."

    // Result.
    let resultSection = "Result"
    let output = "Save the result"
    let outputCaption = "Beside the original saves name (no background).png in the same folder. A copied picture that is not a file always goes back to the clipboard."
    let framing = "Canvas"
    let framingCaption = "Keep the picture’s size with a transparent background, or crop the result to the subject."
    let footnote = "Everything runs on this Mac. Nothing is uploaded."

    // Stage.
    let stageCaption = "The subject lifted off its background"
    let stageBefore = "Original"
    let stageAfter = "No background"
    let stageCropped = "Cropped"
    let chipLocal = "On this Mac"

    // Card.
    let working = "Removing background…"
    let nothing = "Copy a picture, or select one in Finder, then press the shortcut."
    let clipboardNothing = "The clipboard holds no picture."
    let failed = "The picture could not be read."
    let reveal = "Reveal"
    let copy = "Copy"
    let copied = "Copied"
    let openSettings = "Settings"

    /// Every string, for the coverage tests.
    var all: [String] {
        Mirror(reflecting: self).children.compactMap { $0.value as? String }
    }
}

extension ZenithStrings {
    /// English in every language (see the file's note).
    static func removeBackground(_ language: AppLanguage) -> ZenithRemoveBackgroundStrings {
        ZenithRemoveBackgroundStrings()
    }
}

/// Settings search: the page by its English words and the Indonesian ones its
/// owner types.
enum RemoveBackgroundSearch {
    static let aliases = ["remove background", "remove bg", "background remover", "cutout", "cut out", "subject",
                          "transparent", "transparent png", "lift subject", "no background",
                          "hapus latar", "hapus background", "hapus bg", "buang background", "latar transparan",
                          "potong objek", "objek"]

    static func keywords(_ language: AppLanguage) -> [String] {
        let text = ZenithStrings.removeBackground(language)
        return [text.enable, text.shortcut, text.output, text.framing, text.commandBarRow]
    }
}
