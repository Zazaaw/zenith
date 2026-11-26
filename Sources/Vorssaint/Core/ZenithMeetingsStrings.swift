// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: Meetings' text: Settings → Meetings, the island's notice
// and its strip. English in every language, by the owner's decision, as
// Batteries' and Face Unlock's. Settings search still finds it by
// Indonesian aliases (MeetingsSearch).

struct ZenithMeetingsStrings {
    // Page.
    let title = "Meetings"
    let subtitle = "Join calls from the island, and keep an eye on the mic while you’re in one."
    let enable = "Enable Meetings"
    let enableHint = "A notice with Join before each call in your calendar, and a strip while it’s live."

    // Calendar access, shared with the island's Calendar.
    let calendarAccess = "Calendar access"
    let calendarAccessHint = "Meetings reads the same calendars as the island’s Calendar. Nothing leaves this Mac."
    let calendarAccessGranted = "Zenith can read your calendars."
    let calendarAccessMissing = "Zenith can’t read your calendars yet."
    let allowAccess = "Allow Access"
    let openPrivacy = "Open System Settings…"
    let calendars = "Calendars"
    let calendarsHint = "Shared with the island’s Calendar: a calendar left out here is left out there too."

    // Before.
    let before = "Before a call"
    let lead = "Show the notice"
    let leadHint = "Title, time and Join, once per meeting. Click Join to open the call in its app or browser."
    let minutesBefore = "{n} min before"

    // During.
    let during = "During a call"
    let showsStrip = "Show the strip during calls"
    let showsStripHint = "The title, how long it’s run, the mic with mute, and a dot while the camera is on. Live while another app uses the mic during a meeting, or after you join from the notice."
    let muteNeedsFeature = "Mute in the strip uses Mic Mute, which is turned off in Features."

    // Providers.
    let providers = "Providers"
    let providersHint = "Links from the providers turned off here are ignored."

    // Notice and strip.
    let join = "Join"
    let startsIn = "In {n} min"
    let startsNow = "Starting now"
    let startedAgo = "Started {n} min ago"
    let untitled = "{provider} call"
    let mute = "Mute"
    let unmute = "Unmute"
    let micLive = "Microphone on"
    let micMuted = "Microphone muted"
    let cameraOn = "Camera on"
    let elapsedLabel = "Call time"

    /// Every string, for the coverage tests.
    var all: [String] {
        Mirror(reflecting: self).children.compactMap { $0.value as? String }
    }

    func minutes(_ count: Int) -> String {
        minutesBefore.replacingOccurrences(of: "{n}", with: "\(count)")
    }
}

extension ZenithStrings {
    /// English in every language (see the file's note).
    static func meetings(_ language: AppLanguage) -> ZenithMeetingsStrings {
        ZenithMeetingsStrings()
    }
}

/// Settings search: the page by its English words and the Indonesian ones its
/// owner types.
enum MeetingsSearch {
    static let aliases = ["meeting", "meetings", "call", "calls", "video call", "zoom", "google meet", "meet",
                          "teams", "microsoft teams", "webex", "slack huddle", "huddle", "facetime", "whereby",
                          "jitsi", "join", "rapat", "meeting online", "rapat online", "panggilan", "panggilan video",
                          "gabung rapat", "vidcall", "mic", "mute"]

    static func keywords(_ language: AppLanguage) -> [String] {
        let text = ZenithStrings.meetings(language)
        return [text.enable, text.lead, text.showsStrip, text.providers, text.join]
    }
}
