// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// MARK: iPhone → Watch

/// A state as one side last knew it: the Mac's body, the Mac's clock when it
/// was sent, and when it was heard (the newest of two snapshots wins).
public struct PocketWatchSnapshot: Codable, Hashable, Sendable {
    public var state: PocketMacState
    public var sentAt: Date
    public var heardAt: Date

    public init(state: PocketMacState, sentAt: Date, heardAt: Date) {
        self.state = state; self.sentAt = sentAt; self.heardAt = heardAt
    }

    /// The newer of two, by when each was heard; ties keep `a`.
    public static func newest(_ a: PocketWatchSnapshot?, _ b: PocketWatchSnapshot?) -> PocketWatchSnapshot? {
        guard let a else { return b }
        guard let b else { return a }
        return b.heardAt > a.heardAt ? b : a
    }
}

/// What the iPhone app hands its Watch over WatchConnectivity's application
/// context: the pairing (so the Watch reaches the relay itself), the state it
/// last heard, already trimmed for the Watch, and the iPhone's battery. A
/// context without a pairing means the iPhone unpaired.
public struct PocketWatchContext: Codable, Hashable, Sendable {
    public var pairing: PocketPairing?
    public var snapshot: PocketWatchSnapshot?
    public var phone: PocketDeviceReport.Device?

    public init(pairing: PocketPairing?, snapshot: PocketWatchSnapshot? = nil, phone: PocketDeviceReport.Device? = nil) {
        self.pairing = pairing; self.snapshot = snapshot; self.phone = phone
    }

    /// The one key it travels under.
    public static let key = "pocket"

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .millisecondsSince1970
        return e
    }()
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .millisecondsSince1970
        return d
    }()

    /// A property-list dictionary for `updateApplicationContext` and messages.
    public func dictionary() throws -> [String: Any] { [Self.key: try Self.encoder.encode(self)] }

    public init?(dictionary: [String: Any]) {
        guard let data = dictionary[Self.key] as? Data,
              let context = try? Self.decoder.decode(PocketWatchContext.self, from: data) else { return nil }
        self = context
    }

    // MARK: Messages

    /// The Watch asks for the context (it has no pairing yet, or just opened).
    public static let helloKey = "hello"
    /// A command the Watch couldn't send itself, for the iPhone to pass on.
    public static let commandKey = "command"
    /// The iPhone's answer to a passed-on command: whether it went out.
    public static let sentKey = "sent"

    public static func commandMessage(_ command: PocketCommand) throws -> [String: Any] {
        [commandKey: try encoder.encode(command)]
    }

    public static func command(from message: [String: Any]) -> PocketCommand? {
        guard let data = message[commandKey] as? Data else { return nil }
        return try? decoder.decode(PocketCommand.self, from: data)
    }

    /// The Watch's own battery, in the Watch's application context for its iPhone.
    public static let watchBatteryKey = "watchBattery"

    public static func watchBatteryMessage(_ device: PocketDeviceReport.Device) throws -> [String: Any] {
        [watchBatteryKey: try encoder.encode(device)]
    }

    public static func watchBattery(from message: [String: Any]) -> PocketDeviceReport.Device? {
        guard let data = message[watchBatteryKey] as? Data,
              let device = try? decoder.decode(PocketDeviceReport.Device.self, from: data), device.kind == .watch,
              (0...100).contains(device.percent) else { return nil }
        return device
    }

    /// For the snapshot file the Watch app writes for its complications.
    public static func encode<T: Encodable>(_ value: T) throws -> Data { try encoder.encode(value) }
    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T { try decoder.decode(type, from: data) }
}

// MARK: The Watch's words

/// What the Watch and its complications say, on plain values like
/// `PocketPresentation`, which it shares for everything the iPhone says too.
public enum PocketWatchPresentation {
    /// How much of Claude's last message the Watch keeps: its end.
    public static let messageTail = 1_200
    /// After a command, the Mac's box is read again at these delays, since
    /// the Watch can't hear the Mac's reply.
    public static let confirmDelays: [TimeInterval] = [2.5, 6, 12]

    // MARK: Trimming

    /// The state with only what the Watch shows, small enough for
    /// WatchConnectivity and a complication's file: no health, tools, sites,
    /// safety or wallpaper; Claude's sessions with the end of their last
    /// message and their latest step; the sound without its outputs.
    public static func trimmed(_ state: PocketMacState) -> PocketMacState {
        var next = PocketMacState(macName: state.macName, battery: state.battery, locked: state.locked,
                                  awakeUntil: state.awakeUntil, coding: state.coding, nextPrayer: state.nextPrayer,
                                  questions: Array(state.questions.prefix(3)), sessions: Array(state.sessions.prefix(4)),
                                  nowPlaying: state.nowPlaying, accessories: Array(state.accessories.prefix(12)),
                                  wallpaperHash: nil)
        if var claude = state.claude {
            claude.sessions = claude.sessions.prefix(4).map { session in
                var s = session
                s.lastMessage = s.lastMessage.map { tail($0, limit: messageTail) }
                s.steps = Array(s.steps.suffix(1))
                return s
            }
            next.claude = claude
        }
        if var sound = state.sound {
            sound.outputs = sound.outputs.filter(\.current)
            next.sound = sound
        }
        return next
    }

    /// The end of a long text, from a word boundary, after an ellipsis.
    public static func tail(_ text: String, limit: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        var end = String(trimmed.suffix(limit))
        if let space = end.firstIndex(where: \.isWhitespace), end.distance(from: end.startIndex, to: space) < 40 {
            end = String(end[end.index(after: space)...])
        }
        return "…" + end.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Claude

    /// One word for what Claude is doing, for the inline complication.
    public static func claudeWord(_ claude: PocketClaude?) -> String? {
        guard let session = PocketPresentation.claudeFocus(claude, chosen: nil) else { return nil }
        switch session.state {
        case .working: return "working"
        case .waiting: return "waiting"
        case .asking: return "asks"
        case .done: return "idle"
        }
    }

    /// A question waits on the Mac, or a turn is held for a reply.
    public static func needsYou(_ state: PocketMacState?) -> Bool {
        guard let state else { return false }
        if !state.questions.isEmpty { return true }
        return state.claude?.sessions.contains { $0.state == .asking || ($0.state == .waiting && $0.acceptsReply) } ?? false
    }

    // MARK: Complications

    /// "Mac 47% · Claude waiting", "Mac away", "Mac online".
    public static func inline(_ snapshot: PocketWatchSnapshot?, now: Date) -> String {
        guard let snapshot else { return "Pocket · not paired" }
        let freshness = PocketPresentation.freshness(heardAt: snapshot.heardAt, live: false, now: now)
        if case .away = freshness { return "\(PocketPresentation.macNoun(snapshot.state)) away" }
        let mac = snapshot.state.battery.map { "Mac \($0.percent)%" } ?? "Mac online"
        guard let word = claudeWord(snapshot.state.claude) else { return mac }
        return mac + " · Claude " + word
    }

    /// The Smart Stack's score, 0…1: high while Claude needs the person,
    /// middling for a turn that just ended or a low battery, low otherwise.
    public static func relevance(_ snapshot: PocketWatchSnapshot?, now: Date) -> Float {
        guard let snapshot else { return 0 }
        let freshness = PocketPresentation.freshness(heardAt: snapshot.heardAt, live: false, now: now)
        guard freshness.isReachable else { return 0.02 }
        let state = snapshot.state
        if needsYou(state) { return 1 }
        let sessions = state.claude?.sessions ?? []
        if sessions.contains(where: { $0.state == .waiting && now.timeIntervalSince($0.waitingSince ?? .distantPast) < 10 * 60 }) {
            return 0.6
        }
        if let battery = state.battery, !battery.charging, battery.percent <= PocketPresentation.lowBattery { return 0.5 }
        if sessions.contains(where: { $0.state == .working }) { return 0.3 }
        return 0.05
    }

    /// The battery as a share for a gauge, nil without one.
    public static func batteryShare(_ state: PocketMacState?) -> Double? {
        state?.battery.map { min(1, max(0, Double($0.percent) / 100)) }
    }

    // MARK: Commands

    /// Whether `after` shows that `command` took effect; nil when a state
    /// can't tell (a refresh, presence, a seek).
    public static func confirms(_ command: PocketCommand, before: PocketMacState?, after: PocketMacState) -> Bool? {
        switch command {
        case .lock:
            return after.locked
        case .keepAwake(let minutes):
            return minutes == nil ? after.awakeUntil == nil : after.awakeUntil != nil
        case .muteMic(let muted):
            guard let mic = after.sound?.micMuted else { return nil }
            return mic == muted
        case .setVolume(let volume):
            guard let sound = after.sound else { return nil }
            return abs(sound.volume - volume) <= 2
        case .setAway(let on):
            return after.claude.map { $0.away == on }
        case .setAwayWait(let minutes):
            return after.claude?.awayMinutes.map { $0 == minutes }
        case .claudeReply(let sessionID, _):
            guard let session = after.claude?.sessions.first(where: { $0.id == sessionID }) else { return true }
            return !(session.state == .waiting && session.acceptsReply)
        case .media(let action):
            guard let now = after.nowPlaying else { return nil }
            let was = before?.nowPlaying
            switch action {
            case .playPause: return was.map { $0.playing != now.playing }
            case .next, .previous: return was.map { $0.title != now.title || $0.artist != now.artist }
            }
        default:
            return nil
        }
    }

    /// What the Watch says while it checks, and once the state agrees.
    public static func sentLine(_ command: PocketCommand) -> String {
        switch command {
        case .lock: return "Locking your Mac…"
        case .keepAwake(let minutes): return minutes == nil ? "Letting your Mac sleep…" : "Keeping your Mac awake…"
        case .muteMic(let muted): return muted ? "Muting the mic…" : "Turning the mic on…"
        case .setAway(let on): return on ? "Turning Away on…" : "Turning Away off…"
        case .setAwayWait: return "Changing the wait…"
        case .claudeReply: return "Sending your reply…"
        default: return "Sent to your Mac…"
        }
    }

    public static func doneLine(_ command: PocketCommand) -> String {
        switch command {
        case .lock: return "Your Mac is locked."
        case .keepAwake(let minutes): return PocketPresentation.keepAwakeLine(minutes)
        case .muteMic(let muted): return muted ? "The mic is muted." : "The mic is on."
        case .setAway(let on): return on ? "Away is on." : "Away is off."
        case .setAwayWait(let minutes): return "Turns wait " + (minutes == 0 ? "until you're back." : PocketPresentation.duration(minutes: minutes) + ".")
        case .claudeReply: return "Claude got your reply."
        default: return "Done."
        }
    }

    /// Shown when the state never agreed in time.
    public static let unconfirmed = "Sent. Your Mac hasn't shown it yet."
}
