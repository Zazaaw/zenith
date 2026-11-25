// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// MARK: Mac → phone

/// Everything the phone shows about the Mac, as of `PocketEnvelope.sentAt`.
/// Optional parts are nil when the Mac has nothing to say (no WakaTime key,
/// prayer times off, nothing playing …), and the phone hides them.
public struct PocketMacState: Codable, Hashable, Sendable {
    public struct Battery: Codable, Hashable, Sendable {
        public var percent: Int
        public var charging: Bool
        /// Minutes to full while charging, or left while on battery.
        public var minutesRemaining: Int?
        /// On power. With `charging` false this is a Mac held at a charge
        /// limit, which the phone says as "plugged in", not "on battery".
        /// Optional so a state from an older Zenith still reads.
        public var pluggedIn: Bool?
        public init(percent: Int, charging: Bool, minutesRemaining: Int? = nil, pluggedIn: Bool? = nil) {
            self.percent = percent; self.charging = charging; self.minutesRemaining = minutesRemaining; self.pluggedIn = pluggedIn
        }
    }

    public struct Coding: Codable, Hashable, Sendable {
        public var seconds: Int
        public var goalSeconds: Int?
        public var topLanguage: String?
        public var topLanguagePercent: Int?
        public init(seconds: Int, goalSeconds: Int? = nil, topLanguage: String? = nil, topLanguagePercent: Int? = nil) {
            self.seconds = seconds; self.goalSeconds = goalSeconds; self.topLanguage = topLanguage; self.topLanguagePercent = topLanguagePercent
        }
    }

    public struct Prayer: Codable, Hashable, Sendable {
        public var name: String
        public var at: Date
        public init(name: String, at: Date) { self.name = name; self.at = at }
    }

    /// One question a Claude Code session is waiting on.
    public struct AgentQuestion: Codable, Hashable, Sendable, Identifiable {
        public var id: String
        public var project: String
        public var tool: String
        /// What it wants to run or touch, already shortened by the Mac.
        public var detail: String
        public var askedAt: Date
        public init(id: String, project: String, tool: String, detail: String, askedAt: Date) {
            self.id = id; self.project = project; self.tool = tool; self.detail = detail; self.askedAt = askedAt
        }
    }

    public struct AgentSession: Codable, Hashable, Sendable, Identifiable {
        public enum Status: String, Codable, Sendable { case running, waiting, done }
        public var id: String
        public var project: String
        public var status: Status
        public var since: Date
        public init(id: String, project: String, status: Status, since: Date) {
            self.id = id; self.project = project; self.status = status; self.since = since
        }
    }

    public struct NowPlaying: Codable, Hashable, Sendable {
        public var title: String
        public var artist: String
        public var playing: Bool
        public var elapsed: TimeInterval?
        public var duration: TimeInterval?
        public init(title: String, artist: String, playing: Bool, elapsed: TimeInterval? = nil, duration: TimeInterval? = nil) {
            self.title = title; self.artist = artist; self.playing = playing; self.elapsed = elapsed; self.duration = duration
        }
    }

    /// A battery Zenith reads on the Mac side (AirPods, keyboards, …).
    public struct Accessory: Codable, Hashable, Sendable, Identifiable {
        public var id: String
        public var name: String
        public var kind: String
        public var percent: Int?
        public var charging: Bool
        public var seenAt: Date?
        public init(id: String, name: String, kind: String, percent: Int?, charging: Bool, seenAt: Date? = nil) {
            self.id = id; self.name = name; self.kind = kind; self.percent = percent; self.charging = charging; self.seenAt = seenAt
        }
    }

    public var macName: String
    public var battery: Battery?
    public var locked: Bool
    /// When keep-awake ends; `.distantFuture` for "until turned off"; nil when off.
    public var awakeUntil: Date?
    public var coding: Coding?
    public var nextPrayer: Prayer?
    public var questions: [AgentQuestion]
    public var sessions: [AgentSession]
    public var nowPlaying: NowPlaying?
    public var accessories: [Accessory]
    /// SHA-256 of the wallpaper thumbnail in its own box, so the phone only
    /// downloads it when it changed.
    public var wallpaperHash: String?

    public init(macName: String, battery: Battery? = nil, locked: Bool = false, awakeUntil: Date? = nil,
                coding: Coding? = nil, nextPrayer: Prayer? = nil, questions: [AgentQuestion] = [],
                sessions: [AgentSession] = [], nowPlaying: NowPlaying? = nil, accessories: [Accessory] = [],
                wallpaperHash: String? = nil) {
        self.macName = macName; self.battery = battery; self.locked = locked; self.awakeUntil = awakeUntil
        self.coding = coding; self.nextPrayer = nextPrayer; self.questions = questions; self.sessions = sessions
        self.nowPlaying = nowPlaying; self.accessories = accessories; self.wallpaperHash = wallpaperHash
    }
}

/// The wallpaper thumbnail (JPEG, small), in its own box.
public struct PocketWallpaper: Codable, Hashable, Sendable {
    public var jpeg: Data
    public init(jpeg: Data) { self.jpeg = jpeg }
}

// MARK: Phone → Mac

/// The phone's own battery and its Watch's, for Zenith's Batteries.
public struct PocketDeviceReport: Codable, Hashable, Sendable {
    public struct Device: Codable, Hashable, Sendable {
        public enum Kind: String, Codable, Sendable { case iphone, watch }
        public var kind: Kind
        public var name: String
        public var percent: Int
        public var charging: Bool
        public var readAt: Date
        public init(kind: Kind, name: String, percent: Int, charging: Bool, readAt: Date) {
            self.kind = kind; self.name = name; self.percent = percent; self.charging = charging; self.readAt = readAt
        }
    }
    public var devices: [Device]
    public init(devices: [Device]) { self.devices = devices }
}

/// What the phone or Watch may ask the Mac to do. Nothing else exists: no
/// unlock, no shell, no file access.
public enum PocketCommand: Codable, Hashable, Sendable {
    case lock
    /// nil minutes = off; 0 = until turned off.
    case keepAwake(minutes: Int?)
    case media(MediaAction)
    case answer(questionID: String, allow: Bool)
    /// Ask the Mac to publish its state now (the app just opened).
    case refresh

    public enum MediaAction: String, Codable, Sendable { case playPause, next, previous }
}

/// The Mac's reply to a command, so the phone can confirm or show why not.
public struct PocketCommandResult: Codable, Hashable, Sendable {
    public var commandID: UUID
    public var ok: Bool
    public var message: String?
    public init(commandID: UUID, ok: Bool, message: String? = nil) {
        self.commandID = commandID; self.ok = ok; self.message = message
    }
}

// MARK: Live messages

/// What travels over the Realtime channel. State goes both live (for an open
/// app) and into the box (for a closed one).
public enum PocketLive: Codable, Hashable, Sendable {
    case macState(PocketMacState)
    case report(PocketDeviceReport)
    case command(PocketCommand)
    case result(PocketCommandResult)
    case wallpaperChanged(hash: String)
}

public enum PocketPurpose {
    public static let live = "live"
    public static func box(_ id: String) -> String { "box/" + id }
}
