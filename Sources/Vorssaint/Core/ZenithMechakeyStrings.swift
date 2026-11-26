// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: Mechakey's text in Settings (Settings → Mechakey) and its
// credit in About. English in every language, by the owner's decision, as
// Batteries'. Settings search still finds it by Indonesian aliases
// (MechakeySearch).

struct ZenithMechakeyStrings {
    // Page.
    let title = "Mechakey"
    let subtitle = "Mechanical keyboard sounds as you type, from Mechvibes’ packs."
    let enable = "Enable Mechakey"
    let enableHint = "A switch’s sound for every key you press. Nothing you type is kept."

    // Input Monitoring.
    let accessNeeded = "Mechakey hears your keys through Input Monitoring. Allow Zenith there, then come back."
    let accessDenied = "Input Monitoring is off for Zenith, so Mechakey can’t hear your keys. Turn Zenith on in Input Monitoring."
    let openInputMonitoring = "Open Input Monitoring"
    let allowInputMonitoring = "Allow Input Monitoring"

    // Sound pack.
    let soundPack = "Sound pack"
    let preview = "Preview"
    let previewing = "Playing"
    let volume = "Volume"
    let volumeCaption = "Mechakey’s own level, under the Mac’s volume."

    // Typing.
    let typing = "Typing"
    let keyUp = "Key-up sounds"
    let keyUpCaption = "Each key sounds again as it comes back up, as a real switch does."
    let ignoreRepeat = "Ignore key repeat"
    let ignoreRepeatCaption = "A key held down sounds once, not on every repeat."
    let shortcut = "Toggle shortcut"
    let shortcutCaption = "Turns Mechakey on or off from anywhere."
    let secureInput = "Password fields stay silent: macOS keeps their keys from every app."

    // Packs.
    let clicky = "Clicky"
    let tactile = "Tactile"
    let linear = "Linear"
    let linearHeavy = "Linear, heavier"
    let topre = "Topre with PBT keycaps"

    // About.
    let credit = "Mechakey’s sound packs come from Mechvibes by Hải Nguyễn, used under the MIT License."
    let showLicense = "Show License"
    let hideLicense = "Hide License"

    /// A pack's line under its name, where there is one to say.
    func caption(for pack: MechakeyPack) -> String? {
        switch pack.id {
        case "cherry-mx-blue": return clicky
        case "cherry-mx-brown": return tactile
        case "cherry-mx-red": return linear
        case "cherry-mx-black": return linearHeavy
        case "topre-purple": return topre
        default: return nil
        }
    }

    /// Every string, for the coverage tests.
    var all: [String] {
        Mirror(reflecting: self).children.compactMap { $0.value as? String }
    }
}

extension ZenithStrings {
    /// English in every language (see the file's note).
    static func mechakey(_ language: AppLanguage) -> ZenithMechakeyStrings {
        ZenithMechakeyStrings()
    }
}

/// Settings search: the page by its English words and the Indonesian ones its
/// owner types.
enum MechakeySearch {
    static let aliases = ["mechakey", "keyboard sounds", "keyboard sound", "key sounds", "keystroke sound",
                          "typing sound", "typing sounds", "mechanical", "mechanical keyboard", "mechvibes",
                          "clicky", "cherry mx", "switch sound", "thock",
                          "suara keyboard", "bunyi keyboard", "suara ketik", "suara mengetik", "bunyi ketik",
                          "keyboard mekanik", "suara tombol"]

    static func keywords(_ language: AppLanguage) -> [String] {
        let text = ZenithStrings.mechakey(language)
        return [text.enable, text.soundPack, text.keyUp, text.ignoreRepeat, text.shortcut]
    }
}
