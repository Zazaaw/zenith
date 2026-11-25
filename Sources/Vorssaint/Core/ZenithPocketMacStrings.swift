// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: the Mac tab's switches on Settings → iPhone & Watch. English
// in every language, like the rest of the page.

struct ZenithPocketMacStrings {
    let shareClipboard = "Clipboard"
    let shareClipboardCaption = "Your latest copied text on the phone, to paste there. Passwords that apps mark as secret never enter the history."
    let allowQuit = "Let the phone quit apps"
    let allowQuitCaption = "Your iPhone can ask one of this Mac’s busiest apps to quit, as ⌘Q would. Never Zenith or a part of macOS."

    /// Every string, for the coverage tests.
    var all: [String] {
        Mirror(reflecting: self).children.compactMap { $0.value as? String }
    }
}

extension ZenithStrings {
    /// English in every language (see the file's note).
    static func pocketMac(_ language: AppLanguage) -> ZenithPocketMacStrings {
        ZenithPocketMacStrings()
    }
}
