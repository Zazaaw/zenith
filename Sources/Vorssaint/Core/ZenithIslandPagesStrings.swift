// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: the text the Dynamic Island page adds around its settings:
// its hero and the Modules grid (Calendar, Notifications, Now Playing, Timer,
// AI Agents, Downloads, Watch, Companion) with each module's settings. The
// settings themselves keep their localized labels; these lines are English
// in every language, like the kit's.

struct ZenithIslandPagesStrings {
    // The Modules grid.
    let modules = "Modules"
    let modulesFooter = "A module’s switch shows it in the island. Click a module for its settings below."
    let showInIsland = "Show in the island"
    let showInIslandHint = "The module joins the open island, where the sections bar reaches it."
    let moduleSettings = "Module settings"
    let moduleBelowHint = "Its settings are in Modules, further down this page."

    // Dynamic Island.
    let compactChip = "Compact"
    let spaciousChip = "Spacious"
    let customChip = "Custom size"
    let clickChip = "Opens on click"
    let hoverChip = "Opens on hover"
    let companion = "Companion"
    let companionHint = "The star that lives in the island, how it looks and when it visits."
    let on = "On"
    let off = "Off"

    // The sections' subtitles.
    let calendarSubtitle = "Today’s events and what comes next, with a countdown before each one."
    let notificationsSubtitle = "Notifications in the island, with quick replies from where they land."
    let musicSubtitle = "What’s playing, its lyrics, what’s up next and the sound as it moves."
    let timerSubtitle = "A focus timer in the island, counting down beside the camera."
    let agentsSubtitle = "Your coding agents’ tokens, limits and live turns, from Claude, Codex and others."
    let downloadsSubtitle = "Downloads as they arrive, from the folder you choose."
    let watchSubtitle = "Watch part of the screen and hear when it changes."
    let mascotSubtitle = "A little star with eyes that lives in the island, rests beside the camera and drops by."

    // Section titles on the sections' pages.
    let access = "Access"
    let countdown = "Countdown"
    let banners = "Banners"
    let replies = "Replies"
    let nowPlaying = "Now playing"
    let lyricsAndQueue = "Lyrics and up next"
    let timer = "Timer"
    let agents = "Agents"
    let accounts = "Accounts"
    let folder = "Folder"
    let watching = "Watching"

    // Chips.
    func agentCount(_ count: Int) -> String { count == 1 ? "1 agent" : "\(count) agents" }
    let granted = "Calendar access on"
    let needsAccess = "Needs calendar access"
    let lyricsOn = "Lyrics"
    let queueOn = "Up next"
    let equalizerOn = "Live equalizer"
    let soundOn = "With sound"
    let silent = "Silent"

    /// Every string, for the coverage tests.
    var all: [String] {
        Mirror(reflecting: self).children.compactMap { $0.value as? String }
    }
}

extension ZenithStrings {
    /// English in every language (see the file's note).
    static func islandPages(_ language: AppLanguage) -> ZenithIslandPagesStrings {
        ZenithIslandPagesStrings()
    }
}
