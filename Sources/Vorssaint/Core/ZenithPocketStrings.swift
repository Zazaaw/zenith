// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: Settings → iPhone & Watch, Zenith Pocket's page, and its
// preview card. English in every language, like Batteries and Face Unlock.
// Settings search still finds it by Indonesian aliases (PocketSearch). The
// names and numbers in the preview are made up.

struct ZenithPocketStrings {
    // Page.
    let title = "iPhone & Watch"
    let subtitle = "Zenith Pocket on your iPhone and Apple Watch: this Mac’s battery, Claude Code and what’s playing."
    let enable = "Turn on Zenith Pocket"
    let enableCaption = "Your iPhone and Watch show this Mac’s state and can lock it, keep it awake or control music."

    // Relay.
    let relay = "Relay"
    let relayCaption = "Your own Supabase project, where this Mac and your iPhone meet. Everything passing through it is sealed end to end: the relay never sees battery levels, commands or Claude’s questions."
    let projectURL = "Project URL"
    let projectURLPrompt = "https://your-project.supabase.co"
    let anonKey = "Public (anon) key"
    let anonKeyPrompt = "eyJhbGciOi…"
    let save = "Save"
    let forget = "Forget"
    let saved = "Saved"
    let changeUnpairs = "Saving a different relay unpairs your iPhone."
    let urlInvalid = "Use the project’s https URL, like https://your-project.supabase.co."
    let keyInvalid = "That doesn’t look like an anon key. It’s a long key with two dots in it."
    let keyIsSecret = "That’s the service_role key, which opens everything. Use the public anon key instead."
    let keyIsNewFormat = "Use the legacy anon key (Project Settings → API Keys → Legacy API keys)."

    // Pairing.
    let pairing = "Pairing"
    let pairPhone = "Pair iPhone"
    let pairCaption = "Show a code to scan with Zenith Pocket. It carries the key that seals everything between the two."
    let scanTitle = "Scan with Zenith Pocket"
    let stepOpen = "Open Zenith Pocket on your iPhone."
    let stepPair = "Tap Pair."
    let stepPoint = "Point the camera at this code."
    let scanWaiting = "Waiting for your iPhone…"
    let scanPrivate = "Anyone who scans this code can reach this Mac, so don’t share it."
    let cancel = "Cancel"
    let codeLabel = "Pairing code"
    let missingTitle = "Not ready to pair"
    let missingEnable = "Turn on Zenith Pocket above."
    let missingRelay = "Enter your relay above."
    let starting = "Starting…"

    // Paired.
    let paired = "Paired"
    let link = "Link"
    let linkLive = "Connected"
    let linkConnecting = "Connecting…"
    let linkOffline = "Offline"
    let lastMessage = "last message {time}"
    let waitingFirst = "Waiting for your iPhone’s first message"
    let noDevices = "No battery report yet. Open Zenith Pocket on your iPhone."
    let charging = "charging"
    let seen = "seen {time}"
    let justNow = "just now"
    let minutesAgo = "{n} min ago"
    let hoursAgo = "{n} h ago"
    let daysAgo = "{n} d ago"
    let unpair = "Unpair"
    let unpairQuestion = "Unpair {name}?"
    let unpairCaption = "The pairing’s key is forgotten. Your iPhone can no longer reach this Mac until you pair again."
    let deviceFallback = "iPhone"

    // Sharing.
    let sharing = "Sharing"
    let shareWallpaper = "Wallpaper"
    let shareWallpaperCaption = "This Mac’s wallpaper behind Zenith Pocket’s Home."
    let shareAgents = "Claude Code"
    let shareAgentsCaption = "What Claude Code is working on, and when it needs you."
    let shareNowPlaying = "Now playing"
    let shareNowPlayingCaption = "The song playing on this Mac, with play, pause and skip."
    let allowAnswers = "Let the phone answer Claude Code"
    let allowAnswersCaption = "Your iPhone can approve or deny Claude Code’s commands on this Mac. Leave it off unless you mean it."

    /// "{n} min" and friends.
    func count(_ template: String, _ value: Int) -> String {
        template.replacingOccurrences(of: "{n}", with: String(value))
    }

    func unpair(_ name: String) -> String { unpairQuestion.replacingOccurrences(of: "{name}", with: name) }

    func time(_ template: String, _ value: String) -> String {
        template.replacingOccurrences(of: "{time}", with: value)
    }

    /// Every string, for the coverage tests.
    var all: [String] {
        Mirror(reflecting: self).children.compactMap { $0.value as? String }
    }
}

/// The preview card's text: the states, the captions and the made-up
/// readings drawn on the phone.
struct ZenithPocketPreviewStrings {
    let unpaired = "Start"
    let scan = "Scan"
    let paired = "Paired"
    let unpairedCaption = "Before pairing, Zenith Pocket on your iPhone asks for this Mac."
    let pairingCaption = "This Mac shows a code; your iPhone scans it and keeps the key."
    let pairedCaption = "Paired, your iPhone shows this Mac. What it shows follows Sharing below."
    let pairingPart = "Pairing"
    let sharingPart = "Sharing"
    let appName = "Pocket"
    let welcomeTitle = "Your Mac,"
    let welcomeRest = " in your pocket."
    let pairButton = "Pair"
    let scanHint = "Point at the code on your Mac"
    let headlineBold = "Your MacBook is at 47%,"
    let headlineRest = " and charging."
    let macName = "MacBook Pro"
    let claude = "Claude Code"
    let claudeLine = "Editing PocketView.swift"
    let song = "Midnight City"
    let artist = "M83"
    let tabs = ["house.fill", "bolt.fill", "sparkles", "gearshape.fill"]
    let windowTitle = "iPhone & Watch"
    let windowPair = "Pair iPhone"
    let windowScan = "Scan with Zenith Pocket"
    let windowPaired = "iPhone 13 Pro"
    let windowPairedDetail = "43% · seen just now"
    let windowWatch = "Apple Watch"
    let windowWatchDetail = "89% · seen just now"
    let phoneTime = "9:41"
    let watchPercent = "47"

    static let shared = ZenithPocketPreviewStrings()
}

extension ZenithStrings {
    /// English in every language (see the file's note).
    static func pocket(_ language: AppLanguage) -> ZenithPocketStrings {
        ZenithPocketStrings()
    }
}

/// Settings search: the page by its English words and the Indonesian ones its
/// owner types.
enum PocketSearch {
    static let aliases = ["pocket", "zenith pocket", "companion", "iphone app", "watch app", "apple watch", "watch",
                          "hp", "handphone", "ponsel", "jam", "jam tangan", "pasangkan", "pasang", "sambungkan",
                          "qr", "scan qr hp", "scan", "supabase", "relay"]

    static func keywords(_ language: AppLanguage) -> [String] {
        let text = ZenithStrings.pocket(language)
        return [text.enable, text.relay, text.pairing, text.pairPhone, text.sharing]
    }
}
