// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: Settings → iPhone & Watch → Watchtower. English in every
// language, like the rest of the page; Settings search also finds it by the
// Indonesian words its owner types (PocketWatchtowerSearch).

struct ZenithPocketWatchtowerStrings {
    let title = "Watchtower"
    let caption = "Your iPhone tells you when a site goes down or a deploy fails, and when work on this Mac was never pushed or backed up."

    // Sites.
    let watchSites = "Watch sites"
    let watchSitesCaption = "Checked every 10 minutes while Zenith Pocket is on. Only the address is asked; nothing is sent with it."
    let sitePrompt = "example.com"
    let add = "Add"
    let remove = "Remove"
    let noSites = "No sites yet. Add the ones you’d want to hear about when they go down."
    let invalidSite = "That doesn’t look like a web address. Try example.com or https://example.com/blog."
    let tooManySites = "Watchtower watches up to {n} sites."
    let alreadyListed = "That site is already on the list."

    // Deploys.
    let deploys = "Deploys"
    let deploysCaption = "Optional. With a token, Watchtower also says how the latest deploy of a Vercel or Netlify site went. Tokens stay on this Mac and only go to that host’s API."
    let vercel = "Vercel"
    let vercelShared = "Uses the token saved for the island’s Vercel page."
    let vercelMissing = "No Vercel token yet. Paste one to see Vercel deploys here and in the island."
    let netlify = "Netlify"
    let netlifySaved = "Personal access token saved."
    let netlifyMissing = "Paste a personal access token (User settings → Applications)."
    let tokenPrompt = "Token"
    let save = "Save"
    let tokenInvalid = "That doesn’t look like a token."

    // Safety.
    let watchSafety = "Watch your work"
    let watchSafetyCaption = "Every 30 minutes, repos with commits never pushed, changes never committed or no remote, plus Time Machine and free disk space. Read only: Zenith never changes a repo."
    let folder = "Folder"
    let folderCaption = "Repos up to three folders deep."
    let choose = "Choose…"
    let reset = "Use ~/Developer"
    let choosePrompt = "Scan This Folder"

    func limit(_ value: Int) -> String {
        tooManySites.replacingOccurrences(of: "{n}", with: String(value))
    }

    /// Every string, for the coverage tests.
    var all: [String] {
        Mirror(reflecting: self).children.compactMap { $0.value as? String }
    }
}

extension ZenithStrings {
    /// English in every language (see the file’s note).
    static func pocketWatchtower(_ language: AppLanguage) -> ZenithPocketWatchtowerStrings {
        ZenithPocketWatchtowerStrings()
    }
}

/// Settings search: the section by its English words and Indonesian ones.
enum PocketWatchtowerSearch {
    static let aliases = ["watchtower", "uptime", "site down", "website down", "monitor site", "vercel", "netlify",
                          "deploy", "certificate", "ssl", "unpushed", "not pushed", "backup", "time machine",
                          "situs", "situs mati", "web mati", "website mati", "pantau situs", "pantau web", "cek situs",
                          "belum di push", "belum push", "kerjaan aman", "cadangan"]

    static func keywords(_ language: AppLanguage) -> [String] {
        let text = ZenithStrings.pocketWatchtower(language)
        return [text.title, text.watchSites, text.deploys, text.vercel, text.netlify, text.watchSafety, text.folder]
    }
}
