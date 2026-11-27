// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: the text the Island group's pages add around their settings
// (Settings → Dynamic Island, Calendar, Notifications, Music, Timer, Agents,
// Downloads, Watch, Mascot). The settings themselves keep their localized
// labels; these lines are English in every language, like the kit's.

struct ZenithIslandPagesStrings {
    // Every section's page.
    let showInIsland = "Show in the island"
    let showInIslandHint = "The section joins the open island, where the sections bar reaches it."
    let islandOff = "The Dynamic Island is off, so this section waits until it is on."
    let turnOnIsland = "Turn On the Island"
    let previewCaption = "The section in the open island, as it looks on this Mac."
    let moreOnIslandPage = "Its place among the sections is set on the Dynamic Island page."
    let openSection = "Open the section’s page"

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
    let modulePageHint = "This section has its own page in the Island group."

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
