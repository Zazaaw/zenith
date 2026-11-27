// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: the new words of the Everyday and Devices pages rebuilt with
// the Settings kit (Shelf, Clipboard, Finder Tools, Media Tools, URL Cleaner,
// Text Snippets, Batteries, iPhone & Watch, iPhone Remote, Face Unlock):
// section titles, hero subtitles and chips the old pages never had. English
// in every language, like the rest of Zenith's own chrome; the settings
// themselves keep their localized labels.

struct ZenithEverydayStrings {
    // Finder Tools.
    let finderTitle = "Finder Tools"
    let finderSubtitle = "Cut and paste files, rename with one key and install apps from disk images, right in Finder."
    let finderCutPaste = "Cut and paste"
    let finderRename = "Rename"
    let finderDiskImages = "Disk images"
    let finderDiskImagesFooter = "Zenith asks before it installs anything. These are the choices its prompt starts with."
    let finderReady = "Ready in Finder"

    // Clipboard.
    let clipboardHistory = "History"
    let clipboardPrivacy = "Privacy"
    let clipboardAutoClear = "Auto clear"
    let clipboardOpenHistory = "Open history"
    let clipboardSaved = "Saved items"
    let clipboardOff = "History off"
    let clipboardPlainOn = "Plain paste on"
    func clipboardItems(_ count: Int) -> String { count == 1 ? "1 item" : "\(count) items" }
    func clipboardKeeps(_ limit: String) -> String { "Keeps \(limit)" }

    // Shelf.
    let shelfOpening = "Opening the shelf"
    let shelfOpensIn = "Opens in"
    let shelfHow = "How it works"
    let shelfNoPermission = "No permission needed"

    // Media Tools.
    let mediaSubtitle = "Compress videos, make GIFs, convert and resize images and PDFs. Everything runs on this Mac."
    let mediaWorkspace = "Workspace"
    let mediaLocal = "On this Mac"

    // URL Cleaner.
    let urlTry = "Try a link"
    func urlSites(_ count: Int) -> String { count == 1 ? "1 rule set" : "\(count) rule sets" }
    func urlRules(_ count: Int) -> String { "\(count) parameters" }

    // Text Snippets.
    let snippetsExpansion = "Expansion"
    let snippetsList = "Snippets"
    func snippetsCount(_ count: Int) -> String { count == 1 ? "1 snippet" : "\(count) snippets" }

    // Batteries.
    func batteriesDevices(_ count: Int) -> String { count == 1 ? "1 device" : "\(count) devices" }
    func batteriesWarnAt(_ percent: Int) -> String { "Warns at \(percent)%" }

    // iPhone & Watch.
    let pocketPaired = "Paired"
    let pocketNotPaired = "Not paired"

    // iPhone Remote.
    let remoteReady = "Ready"
    let remoteNotReady = "Needs setup"
    let remoteValues = "Values to type"
    func remoteDevices(_ count: Int) -> String { count == 1 ? "1 device" : "\(count) devices" }

    // Face Unlock.
    let faceSetUpNeeded = "Set up Face Unlock to choose how it scans and recognizes you."
    let faceNotSetUp = "Not set up"
    func faceCount(_ count: Int) -> String { count == 1 ? "1 face" : "\(count) faces" }

    var all: [String] {
        Mirror(reflecting: self).children.compactMap { $0.value as? String }
    }
}

extension ZenithStrings {
    /// English in every language (see the file's note).
    static func everyday(_ language: AppLanguage) -> ZenithEverydayStrings {
        ZenithEverydayStrings()
    }
}
