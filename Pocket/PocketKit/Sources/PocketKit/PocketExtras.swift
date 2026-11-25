// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// The second round of what the Mac tells the phone: Claude Code in detail,
// the Mac's health and sound, Zenith's own tools, the watched sites and the
// safety of the person's work. Each part rides on `PocketMacState` as an
// optional field, so a state from an older Zenith (or a part the person
// turned off) simply reads as nil and the phone hides it.

// MARK: Claude Code

public struct PocketClaude: Codable, Hashable, Sendable {
    public struct Step: Codable, Hashable, Sendable, Identifiable {
        public enum Phase: String, Codable, Sendable { case running, done, failed }
        public var id: String
        /// Claude Code's tool name: Read, Edit, Write, Bash, Grep, Task, WebFetch …
        public var tool: String
        /// The file, command or query, already shortened by the Mac.
        public var target: String?
        public var phase: Phase
        public var added: Int?
        public var removed: Int?
        public var startedAt: Date
        public init(id: String, tool: String, target: String? = nil, phase: Phase, added: Int? = nil, removed: Int? = nil, startedAt: Date) {
            self.id = id; self.tool = tool; self.target = target; self.phase = phase; self.added = added; self.removed = removed; self.startedAt = startedAt
        }
    }

    public struct Session: Codable, Hashable, Sendable, Identifiable {
        public enum State: String, Codable, Sendable {
            /// Running tools.
            case working
            /// Done with its turn, waiting for the next prompt.
            case waiting
            /// Asking for permission.
            case asking
            /// Ended or idle for a while.
            case done
        }
        public var id: String
        public var project: String
        public var state: State
        public var turnStartedAt: Date?
        public var waitingSince: Date?
        /// The end of Claude's last message, trimmed by the Mac (≤ 600 characters).
        public var lastMessage: String?
        /// The latest steps of this turn, oldest first (≤ 8).
        public var steps: [Step]
        public var filesChanged: Int
        public var added: Int
        public var removed: Int
        /// True while this session's Stop hook is holding for a reply from the
        /// phone (Away mode): `.claudeReply` for it will reach Claude.
        public var acceptsReply: Bool
        public init(id: String, project: String, state: State, turnStartedAt: Date? = nil, waitingSince: Date? = nil,
                    lastMessage: String? = nil, steps: [Step] = [], filesChanged: Int = 0, added: Int = 0, removed: Int = 0,
                    acceptsReply: Bool = false) {
            self.id = id; self.project = project; self.state = state; self.turnStartedAt = turnStartedAt; self.waitingSince = waitingSince
            self.lastMessage = lastMessage; self.steps = steps; self.filesChanged = filesChanged; self.added = added; self.removed = removed
            self.acceptsReply = acceptsReply
        }
    }

    public struct Usage: Codable, Hashable, Sendable {
        /// Share of the current 5-hour window used, 0…100.
        public var windowPercent: Int?
        public var windowResetsAt: Date?
        public var weekPercent: Int?
        public var costToday: Double?
        public var costWeek: Double?
        public var tokensToday: Int?
        public init(windowPercent: Int? = nil, windowResetsAt: Date? = nil, weekPercent: Int? = nil,
                    costToday: Double? = nil, costWeek: Double? = nil, tokensToday: Int? = nil) {
            self.windowPercent = windowPercent; self.windowResetsAt = windowResetsAt; self.weekPercent = weekPercent
            self.costToday = costToday; self.costWeek = costWeek; self.tokensToday = tokensToday
        }
    }

    public var sessions: [Session]
    public var usage: Usage?
    /// Away mode: the Mac holds a finished turn for a reply from the phone.
    public var away: Bool
    public init(sessions: [Session] = [], usage: Usage? = nil, away: Bool = false) {
        self.sessions = sessions; self.usage = usage; self.away = away
    }
}

// MARK: The Mac's health and sound

public struct PocketHealth: Codable, Hashable, Sendable {
    public struct Process: Codable, Hashable, Sendable, Identifiable {
        public var id: Int32 { pid }
        public var pid: Int32
        public var name: String
        public var cpu: Double
        public init(pid: Int32, name: String, cpu: Double) { self.pid = pid; self.name = name; self.cpu = cpu }
    }
    public var cpuPercent: Int
    public var temperature: Double?
    public var memoryPercent: Int?
    public var diskFree: Int64?
    public var diskTotal: Int64?
    /// Bytes per second.
    public var networkDown: Int64?
    public var networkUp: Int64?
    /// The busiest processes (≤ 5).
    public var top: [Process]
    public init(cpuPercent: Int, temperature: Double? = nil, memoryPercent: Int? = nil, diskFree: Int64? = nil, diskTotal: Int64? = nil,
                networkDown: Int64? = nil, networkUp: Int64? = nil, top: [Process] = []) {
        self.cpuPercent = cpuPercent; self.temperature = temperature; self.memoryPercent = memoryPercent; self.diskFree = diskFree
        self.diskTotal = diskTotal; self.networkDown = networkDown; self.networkUp = networkUp; self.top = top
    }
}

public struct PocketSound: Codable, Hashable, Sendable {
    public struct Output: Codable, Hashable, Sendable, Identifiable {
        public var id: String
        public var name: String
        /// "speakers", "headphones", "airpods", "display", "bluetooth", "other".
        public var kind: String
        public var current: Bool
        public init(id: String, name: String, kind: String, current: Bool) { self.id = id; self.name = name; self.kind = kind; self.current = current }
    }
    public var volume: Int
    public var muted: Bool
    public var micMuted: Bool?
    public var outputs: [Output]
    public init(volume: Int, muted: Bool, micMuted: Bool? = nil, outputs: [Output] = []) {
        self.volume = volume; self.muted = muted; self.micMuted = micMuted; self.outputs = outputs
    }
}

// MARK: Zenith's own tools

public struct PocketTools: Codable, Hashable, Sendable {
    public struct Workspace: Codable, Hashable, Sendable, Identifiable {
        public var id: String
        public var name: String
        public var symbol: String?
        public init(id: String, name: String, symbol: String? = nil) { self.id = id; self.name = name; self.symbol = symbol }
    }
    public struct Timer: Codable, Hashable, Sendable {
        public var label: String
        public var endsAt: Date?
        /// Left when paused.
        public var remaining: TimeInterval?
        public var paused: Bool
        public init(label: String, endsAt: Date? = nil, remaining: TimeInterval? = nil, paused: Bool = false) {
            self.label = label; self.endsAt = endsAt; self.remaining = remaining; self.paused = paused
        }
    }
    public struct DevServer: Codable, Hashable, Sendable, Identifiable {
        public var id: Int { port }
        public var port: Int
        public var process: String
        public var project: String?
        public init(port: Int, process: String, project: String? = nil) { self.port = port; self.process = process; self.project = project }
    }
    public struct Event: Codable, Hashable, Sendable {
        public var title: String
        public var start: Date
        public var end: Date?
        public init(title: String, start: Date, end: Date? = nil) { self.title = title; self.start = start; self.end = end }
    }
    public struct Download: Codable, Hashable, Sendable {
        public var name: String
        public var progress: Double?
        public init(name: String, progress: Double? = nil) { self.name = name; self.progress = progress }
    }
    public var workspaces: [Workspace]
    public var timer: Timer?
    public var devServers: [DevServer]
    public var nextEvent: Event?
    public var downloads: [Download]
    /// The latest text clips, newest first (≤ 10), only when the person shares the clipboard.
    public var clips: [String]
    public init(workspaces: [Workspace] = [], timer: Timer? = nil, devServers: [DevServer] = [], nextEvent: Event? = nil,
                downloads: [Download] = [], clips: [String] = []) {
        self.workspaces = workspaces; self.timer = timer; self.devServers = devServers; self.nextEvent = nextEvent
        self.downloads = downloads; self.clips = clips
    }
}

// MARK: Sites and safety

public struct PocketSites: Codable, Hashable, Sendable {
    public struct Site: Codable, Hashable, Sendable, Identifiable {
        public enum Status: String, Codable, Sendable { case up, down, paused, slow, unknown }
        public var id: String { url }
        public var url: String
        public var name: String
        public var status: Status
        public var httpStatus: Int?
        public var latencyMs: Int?
        public var checkedAt: Date?
        /// "vercel", "netlify", or nil.
        public var host: String?
        public var deployState: String?
        public var deployedAt: Date?
        public var certificateExpiresAt: Date?
        /// When the site entered its current status, as far as the Mac saw
        /// it ("down since 9.40"); nil when not known.
        public var since: Date? = nil
        public init(url: String, name: String, status: Status, httpStatus: Int? = nil, latencyMs: Int? = nil, checkedAt: Date? = nil,
                    host: String? = nil, deployState: String? = nil, deployedAt: Date? = nil, certificateExpiresAt: Date? = nil,
                    since: Date? = nil) {
            self.url = url; self.name = name; self.status = status; self.httpStatus = httpStatus; self.latencyMs = latencyMs
            self.checkedAt = checkedAt; self.host = host; self.deployState = deployState; self.deployedAt = deployedAt
            self.certificateExpiresAt = certificateExpiresAt; self.since = since
        }
    }
    public var sites: [Site]
    public init(sites: [Site] = []) { self.sites = sites }
}

public struct PocketSafety: Codable, Hashable, Sendable {
    public struct Repo: Codable, Hashable, Sendable, Identifiable {
        public var id: String { path }
        public var name: String
        /// Relative to the scanned folder, e.g. "personal/zenith".
        public var path: String
        public var branch: String?
        public var unpushed: Int
        public var uncommitted: Int
        public var hasRemote: Bool
        public init(name: String, path: String, branch: String? = nil, unpushed: Int, uncommitted: Int, hasRemote: Bool) {
            self.name = name; self.path = path; self.branch = branch; self.unpushed = unpushed; self.uncommitted = uncommitted; self.hasRemote = hasRemote
        }
    }
    public var repos: [Repo]
    public var scannedAt: Date?
    public var timeMachineConfigured: Bool?
    public var lastBackup: Date?
    public var diskFreePercent: Int?
    /// How many repos need the person in all, when `repos` was capped.
    public var reposAtRisk: Int? = nil
    /// The scanned folder as the person sees it, e.g. "~/Developer".
    public var folder: String? = nil
    public init(repos: [Repo] = [], scannedAt: Date? = nil, timeMachineConfigured: Bool? = nil, lastBackup: Date? = nil, diskFreePercent: Int? = nil,
                reposAtRisk: Int? = nil, folder: String? = nil) {
        self.repos = repos; self.scannedAt = scannedAt; self.timeMachineConfigured = timeMachineConfigured
        self.lastBackup = lastBackup; self.diskFreePercent = diskFreePercent; self.reposAtRisk = reposAtRisk; self.folder = folder
    }
}

// MARK: Drops (phone → Mac files)

/// A file the phone left in one of the drop boxes for the Mac to collect.
public struct PocketDrop: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable { case photo, file }
    public var name: String
    public var kind: Kind
    public var data: Data
    public init(name: String, kind: Kind, data: Data) { self.name = name; self.kind = kind; self.data = data }
    /// A drop's sealed box must stay under the relay's limit (350 000
    /// characters). The data is base64 inside the JSON and base64 again once
    /// sealed, so it stays under this many bytes (see `fitBytes`).
    public static let maxBytes = 180_000
}

extension PocketPairing {
    /// Four drop slots, reused in turn, so drops never grow the relay table.
    public static let dropSlots = 4
    public func dropBoxID(_ slot: Int) -> String { derive("box/drop/\(slot % Self.dropSlots)") }
    /// The now-playing artwork (JPEG), when the person shares now playing.
    public var artworkBoxID: String { derive("box/artwork") }
}
