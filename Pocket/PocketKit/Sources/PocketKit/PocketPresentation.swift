// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// How a value is coloured. Colour only ever marks a status, and always
/// next to words that say the same, so each app maps these to its palette.
public enum PocketTone: String, Hashable, Sendable {
    /// Primary text: nothing to flag.
    case plain
    /// Secondary text: unknown, old or away.
    case quiet
    case good
    case info
    case attention
    case alert
    case progress
}

/// The hero every tab opens with: a bold lead with the value in its tone,
/// then the rest of the sentence in regular weight, e.g.
/// "**Your MacBook is at 47%,** and charging."
public struct PocketSentence: Hashable, Sendable {
    public var lead: String
    public var value: String
    /// Still bold, right after the value (a comma, a full stop, or nothing).
    public var after: String
    public var rest: String
    public var tone: PocketTone

    public init(lead: String, value: String, after: String = "", rest: String, tone: PocketTone) {
        self.lead = lead; self.value = value; self.after = after; self.rest = rest; self.tone = tone
    }

    /// The whole sentence as plain text (accessibility, tests).
    public var text: String {
        let first = lead + value + after
        return rest.isEmpty ? first : first + " " + rest
    }
}

/// A short labelled status, shown as a pill.
public struct PocketBadge: Hashable, Sendable {
    public var text: String
    public var tone: PocketTone
    public init(_ text: String, _ tone: PocketTone) { self.text = text; self.tone = tone }
}

/// How recent what the phone knows about the Mac is.
public enum PocketFreshness: Hashable, Sendable {
    /// Nothing heard from this Mac yet.
    case never
    /// The newest state came over the live channel.
    case live
    /// The newest state came from the Mac's box, written at that time.
    case recent(Date)
    /// Nothing for longer than the Mac ever stays quiet: asleep or off.
    case away(Date)

    public var isReachable: Bool {
        switch self {
        case .live, .recent: return true
        case .never, .away: return false
        }
    }
}

/// One battery on the Devices tab: the Mac's, this iPhone's, or one of the
/// accessories Zenith reads on the Mac.
public struct PocketBatteryItem: Hashable, Sendable, Identifiable {
    public enum Role: String, Hashable, Sendable { case mac, thisPhone, accessory }

    public var id: String
    public var role: Role
    public var name: String
    /// Zenith's Batteries kind ("headphones", "keyboard", …).
    public var kind: String
    public var percent: Int?
    public var charging: Bool
    /// The Mac on power but held (a charge limit).
    public var pluggedIn: Bool
    /// Set when the reading is a last-known level from that time.
    public var seenAt: Date?

    public init(id: String, role: Role, name: String, kind: String, percent: Int?, charging: Bool,
                pluggedIn: Bool = false, seenAt: Date? = nil) {
        self.id = id; self.role = role; self.name = name; self.kind = kind; self.percent = percent
        self.charging = charging; self.pluggedIn = pluggedIn; self.seenAt = seenAt
    }
}

/// Zenith Pocket's words and numbers, on plain values, so the iPhone and the
/// Watch say the same thing and it can be tested without a screen.
public enum PocketPresentation {
    /// The Mac rewrites its box at least every 15 minutes while awake, so a
    /// state older than this means it is asleep, off or offline.
    public static let offlineAfter: TimeInterval = 20 * 60
    /// At or below this a battery is low (red, and the Devices dot).
    public static let lowBattery = 20
    /// Further out than this, a keep-awake end means "until turned off".
    static let indefinitely: TimeInterval = 10 * 365 * 24 * 3600

    // MARK: Time

    /// "42m", "1h", "3h 10m".
    public static func duration(minutes: Int) -> String {
        let minutes = max(0, minutes)
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m)m" }
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    /// Whole minutes, rounded down ("3h 4m" of coding).
    public static func duration(seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return duration(minutes: 0) }
        return duration(minutes: Int(max(0, seconds) / 60))
    }

    /// "just now", "4m ago", "3h ago", "2d ago". A time ahead of `now` (the
    /// Mac's clock runs ahead) counts as now.
    public static func ago(_ date: Date, now: Date) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        return "\(hours / 24)d ago"
    }

    /// "in 5h 41m", or "now" once it has come.
    public static func countdown(to date: Date, now: Date) -> String {
        let seconds = date.timeIntervalSince(now)
        guard seconds >= 60 else { return "now" }
        return "in " + duration(minutes: Int(seconds / 60))
    }

    /// A track position: "1:42", "1:02:03".
    public static func clock(_ seconds: TimeInterval) -> String {
        let total = seconds.isFinite ? Int(max(0, seconds)) : 0
        let h = total / 3600, m = total / 60 % 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    // MARK: Freshness

    /// `heardAt` is the newest state's time (the Mac's clock, capped at now);
    /// `live` whether that state came over the channel rather than the box.
    public static func freshness(heardAt: Date?, live: Bool, now: Date) -> PocketFreshness {
        guard let heardAt else { return .never }
        let at = min(heardAt, now)
        if now.timeIntervalSince(at) > offlineAfter { return .away(at) }
        return live ? .live : .recent(at)
    }

    /// The small line under the hero when the state is not live, nil when it is.
    public static func updatedLine(_ freshness: PocketFreshness, now: Date) -> String? {
        switch freshness {
        case .live, .never: return nil
        case .recent(let at): return "updated " + ago(at, now: now)
        case .away(let at): return "last heard " + ago(at, now: now)
        }
    }

    // MARK: Home

    public static func homeBadge(_ freshness: PocketFreshness) -> PocketBadge {
        switch freshness {
        case .live, .recent: return PocketBadge("Online", .good)
        case .away: return PocketBadge("Offline", .quiet)
        case .never: return PocketBadge("Waiting", .quiet)
        }
    }

    /// "MacBook" for a Mac with a battery, otherwise "Mac".
    public static func macNoun(_ state: PocketMacState?) -> String {
        state?.battery == nil ? "Mac" : "MacBook"
    }

    public static func batteryTone(percent: Int, charging: Bool) -> PocketTone {
        if charging { return .good }
        if percent <= 10 { return .alert }
        if percent <= lowBattery { return .attention }
        return .good
    }

    public static func homeSentence(_ state: PocketMacState?, freshness: PocketFreshness) -> PocketSentence {
        guard let state else {
            return PocketSentence(lead: "Waiting for ", value: "your Mac", after: ".",
                                  rest: "Keep Zenith open on it, with iPhone & Watch turned on.", tone: .quiet)
        }
        if case .away = freshness {
            return PocketSentence(lead: "Your \(macNoun(state)) is ", value: "away", after: ",",
                                  rest: "asleep, off or offline.", tone: .quiet)
        }
        guard let battery = state.battery else {
            return PocketSentence(lead: "Your Mac is ", value: "online", after: ",",
                                  rest: state.locked ? "and locked." : "and unlocked.", tone: .good)
        }
        let rest: String
        if battery.charging {
            rest = "and charging."
        } else if battery.pluggedIn == true {
            rest = "and plugged in."
        } else if let minutes = battery.minutesRemaining {
            rest = "and has \(duration(minutes: minutes)) left."
        } else {
            rest = "and on battery."
        }
        return PocketSentence(lead: "Your MacBook is at ", value: "\(battery.percent)%", after: ",", rest: rest,
                              tone: batteryTone(percent: battery.percent, charging: battery.charging))
    }

    /// The note beside the battery meter; it adds to the sentence, never repeats it.
    public static func batteryNote(_ battery: PocketMacState.Battery) -> String {
        if battery.charging {
            if battery.percent >= 100 { return "full" }
            return battery.minutesRemaining.map { "full in " + duration(minutes: $0) } ?? "charging"
        }
        if battery.pluggedIn == true { return "on power · not charging" }
        return "on battery"
    }

    // MARK: Today

    /// "goal 4h · swift 71%".
    public static func codingNote(_ coding: PocketMacState.Coding) -> String {
        var parts: [String] = []
        if let goal = coding.goalSeconds, goal > 0 { parts.append("goal " + duration(seconds: TimeInterval(goal))) }
        if let language = coding.topLanguage, !language.isEmpty {
            parts.append(language.lowercased() + (coding.topLanguagePercent.map { " \($0)%" } ?? ""))
        }
        return parts.isEmpty ? "today" : parts.joined(separator: " · ")
    }

    /// Today's share of the goal, nil without one.
    public static func codingProgress(_ coding: PocketMacState.Coding) -> Double? {
        guard let goal = coding.goalSeconds, goal > 0 else { return nil }
        return min(1, max(0, Double(coding.seconds) / Double(goal)))
    }

    // MARK: Control

    /// Minutes of keep-awake left; nil when off, ended, or until turned off.
    public static func awakeMinutesLeft(_ until: Date?, now: Date) -> Int? {
        guard let until, !isIndefinite(until, now: now) else { return nil }
        let seconds = until.timeIntervalSince(now)
        return seconds > 0 ? Int((seconds / 60).rounded(.up)) : nil
    }

    public static func isIndefinite(_ until: Date, now: Date) -> Bool {
        until.timeIntervalSince(now) > indefinitely
    }

    public static func controlBadge(_ state: PocketMacState?, freshness: PocketFreshness) -> PocketBadge {
        guard let state, freshness.isReachable else { return PocketBadge("Offline", .quiet) }
        return state.locked ? PocketBadge("Locked", .good) : PocketBadge("Unlocked", .info)
    }

    public static func controlSentence(_ state: PocketMacState?, freshness: PocketFreshness, now: Date) -> PocketSentence {
        guard let state, freshness.isReachable else {
            return PocketSentence(lead: "Your Mac is ", value: "out of reach", after: ".",
                                  rest: "Controls work again once it's online.", tone: .quiet)
        }
        if let until = state.awakeUntil, isIndefinite(until, now: now) {
            return PocketSentence(lead: "Your Mac stays ", value: "awake", after: ",",
                                  rest: "until you turn it off.", tone: .attention)
        }
        if let minutes = awakeMinutesLeft(state.awakeUntil, now: now) {
            return PocketSentence(lead: "Your Mac stays awake ", value: duration(minutes: minutes),
                                  rest: "then sleeps.", tone: .attention)
        }
        return PocketSentence(lead: "Your Mac ", value: "sleeps", rest: "as usual.", tone: .plain)
    }

    /// "nina · 1:42 / 3:58".
    public static func nowPlayingLine(_ playing: PocketMacState.NowPlaying, elapsed: TimeInterval?) -> String {
        var parts: [String] = []
        if !playing.artist.isEmpty { parts.append(playing.artist) }
        if let elapsed, let duration = playing.duration {
            parts.append(clock(elapsed) + " / " + clock(duration))
        }
        if !playing.playing { parts.append("paused") }
        return parts.joined(separator: " · ")
    }

    /// The position now: the Mac's reading at `sentAt`, counted on while playing.
    public static func elapsed(_ playing: PocketMacState.NowPlaying, sentAt: Date, now: Date) -> TimeInterval? {
        guard let start = playing.elapsed else { return nil }
        var value = start
        if playing.playing { value += max(0, now.timeIntervalSince(sentAt)) }
        if let duration = playing.duration { value = min(duration, value) }
        return max(0, value)
    }

    // MARK: Agents

    public static func agentsBadge(_ state: PocketMacState?) -> PocketBadge {
        guard let state else { return PocketBadge("Quiet", .quiet) }
        if !state.questions.isEmpty { return PocketBadge("Pending", .attention) }
        if state.sessions.contains(where: { $0.status == .running }) { return PocketBadge("In progress", .progress) }
        return PocketBadge("Quiet", .quiet)
    }

    public static func agentsSentence(_ state: PocketMacState?) -> PocketSentence {
        let questions = state?.questions.count ?? 0
        if questions > 0 {
            return PocketSentence(lead: "Claude has ", value: questions == 1 ? "1 question" : "\(questions) questions",
                                  rest: "waiting on you.", tone: .attention)
        }
        let running = state?.sessions.filter { $0.status == .running } ?? []
        if running.count == 1 {
            return PocketSentence(lead: "Claude is ", value: "working", rest: "on \(running[0].project).", tone: .progress)
        }
        if running.count > 1 {
            return PocketSentence(lead: "Claude is ", value: "working", rest: "on \(running.count) sessions.", tone: .progress)
        }
        return PocketSentence(lead: "Claude is ", value: "all quiet", after: ".", rest: "Nothing is waiting on you.", tone: .good)
    }

    /// What a question asks, from the tool it waits to run.
    public static func questionTitle(_ question: PocketMacState.AgentQuestion) -> String {
        switch question.tool.lowercased() {
        case "bash": return "Run a command?"
        case "edit", "multiedit", "notebookedit": return "Edit a file?"
        case "write": return "Write a file?"
        case "read": return "Read a file?"
        case "webfetch": return "Open a web page?"
        case "websearch": return "Search the web?"
        case "claude code", "": return "Go ahead?"
        default: return "Use \(question.tool)?"
        }
    }

    /// What it touches, as the Mac kept it; a command reads as a prompt line.
    public static func questionDetail(_ question: PocketMacState.AgentQuestion) -> String? {
        let detail = question.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !detail.isEmpty else { return nil }
        return question.tool.lowercased() == "bash" ? "$ " + detail : detail
    }

    public static func sessionBadge(_ session: PocketMacState.AgentSession) -> PocketBadge {
        switch session.status {
        case .running: return PocketBadge("In progress", .progress)
        case .waiting: return PocketBadge("Pending", .attention)
        case .done: return PocketBadge("Done", .good)
        }
    }

    /// "running · 4m", "waiting · 2m", "18m ago".
    public static func sessionLine(_ session: PocketMacState.AgentSession, now: Date) -> String {
        let since = Int(max(0, now.timeIntervalSince(session.since)) / 60)
        switch session.status {
        case .running: return "running · " + duration(minutes: since)
        case .waiting: return "waiting · " + duration(minutes: since)
        case .done: return ago(session.since, now: now)
        }
    }

    // MARK: Devices

    /// The Mac first, then this iPhone, then the Mac's accessories.
    public static func batteryItems(_ state: PocketMacState?, phone: PocketDeviceReport.Device?) -> [PocketBatteryItem] {
        var items: [PocketBatteryItem] = []
        if let state, let battery = state.battery {
            items.append(PocketBatteryItem(id: "mac", role: .mac, name: state.macName, kind: "mac", percent: battery.percent,
                                           charging: battery.charging, pluggedIn: battery.pluggedIn == true))
        }
        if let phone {
            items.append(PocketBatteryItem(id: "this-phone", role: .thisPhone, name: phone.name, kind: phone.kind.rawValue,
                                           percent: phone.percent, charging: phone.charging))
        }
        for accessory in state?.accessories ?? [] {
            items.append(PocketBatteryItem(id: "accessory-" + accessory.id, role: .accessory, name: accessory.name,
                                           kind: accessory.kind, percent: accessory.percent, charging: accessory.charging,
                                           seenAt: accessory.seenAt))
        }
        return items
    }

    /// The lowest battery that is draining and read just now, among this
    /// iPhone and the Mac's accessories (the Mac has Home to itself).
    public static func lowest(_ items: [PocketBatteryItem]) -> PocketBatteryItem? {
        items.filter { $0.role != .mac && $0.percent != nil && !$0.charging && $0.seenAt == nil }
            .min { ($0.percent ?? 0) < ($1.percent ?? 0) }
    }

    public static func isLow(_ item: PocketBatteryItem) -> Bool {
        guard let percent = item.percent else { return false }
        return percent <= lowBattery && !item.charging && item.seenAt == nil
    }

    public static func devicesBadge(_ items: [PocketBatteryItem]) -> PocketBadge {
        guard let lowest = lowest(items) else { return PocketBadge("Quiet", .quiet) }
        return isLow(lowest) ? PocketBadge("Low", .alert) : PocketBadge("All good", .good)
    }

    public static func devicesSentence(_ items: [PocketBatteryItem]) -> PocketSentence {
        guard let lowest = lowest(items), let percent = lowest.percent else {
            return PocketSentence(lead: "No battery ", value: "to watch", after: ".",
                                  rest: "Zenith lists them as it sees them.", tone: .quiet)
        }
        let (noun, plural) = noun(lowest)
        if isLow(lowest) {
            return PocketSentence(lead: noun + (plural ? " are at " : " is at "), value: "\(percent)%", after: ",",
                                  rest: plural ? "charge them soon." : "charge it soon.", tone: .alert)
        }
        let name = lowest.role == .thisPhone ? "This iPhone" : lowest.name
        return PocketSentence(lead: "Every battery is ", value: "fine", after: ".",
                              rest: "\(name) is lowest, at \(percent)%.", tone: .good)
    }

    /// How the hero names a device: "Your earbuds", "Your keyboard", or its own name.
    static func noun(_ item: PocketBatteryItem) -> (String, plural: Bool) {
        if item.role == .thisPhone { return ("Your iPhone", false) }
        let name = item.name.lowercased()
        switch item.kind {
        case "headphones":
            return name.contains("airpods") || name.contains("buds") ? ("Your earbuds", true) : ("Your headphones", true)
        case "watch": return ("Your Apple Watch", false)
        case "iphone": return ("Your iPhone", false)
        case "ipad": return ("Your iPad", false)
        case "keyboard", "mouse", "trackpad", "speaker": return ("Your " + item.kind, false)
        case "gamepad": return ("Your controller", false)
        default: return (item.name.isEmpty ? "A device" : item.name, false)
        }
    }

    /// The row's small line: "charging", "this iphone", "seen 2h ago" …
    public static func itemMeta(_ item: PocketBatteryItem, now: Date) -> String {
        switch item.role {
        case .mac:
            return item.charging ? "charging" : item.pluggedIn ? "plugged in" : "on battery"
        case .thisPhone:
            return item.charging ? "charging · this iphone" : "this iphone"
        case .accessory:
            if let seen = item.seenAt { return "seen " + ago(seen, now: now) }
            if item.percent == nil { return "no reading" }
            return item.charging ? "charging" : item.kind == "other" ? "accessory" : item.kind
        }
    }

    public static func itemTone(_ item: PocketBatteryItem) -> PocketTone {
        if item.seenAt != nil || item.percent == nil { return .quiet }
        if item.charging { return .good }
        return isLow(item) ? .alert : .plain
    }

    /// An SF Symbol for the row.
    public static func symbolName(_ item: PocketBatteryItem) -> String {
        switch item.kind {
        case "mac": return "laptopcomputer"
        case "iphone": return "iphone"
        case "ipad": return "ipad"
        case "watch": return "applewatch"
        case "headphones": return item.name.lowercased().contains("buds") || item.name.lowercased().contains("airpods") ? "earbuds" : "headphones"
        case "keyboard": return "keyboard"
        case "mouse": return "computermouse"
        case "trackpad": return "rectangle.and.hand.point.up.left"
        case "speaker": return "hifispeaker"
        case "gamepad": return "gamecontroller"
        default: return "wave.3.right.circle"
        }
    }

    // MARK: Island bar

    /// Which tabs carry a dot: Agents when Claude asks, Devices when a battery is low.
    public static func attention(_ state: PocketMacState?, phone: PocketDeviceReport.Device?) -> (agents: Bool, devices: Bool) {
        let items = batteryItems(state, phone: phone)
        return (!(state?.questions.isEmpty ?? true), lowest(items).map(isLow) ?? false)
    }

    // MARK: Commands

    /// What the phone says once the Mac answered a command.
    public static func resultLine(_ result: PocketCommandResult, for command: PocketCommand?) -> String {
        if let message = result.message, !message.isEmpty { return message }
        guard result.ok else { return "Your Mac couldn't do that." }
        switch command {
        case .lock?: return "Your Mac is locked."
        case .keepAwake(let minutes)?: return keepAwakeLine(minutes)
        case .media?, .answer?, .refresh?, nil: return "Done."
        }
    }

    static func keepAwakeLine(_ minutes: Int?) -> String {
        guard let minutes else { return "Your Mac sleeps as usual." }
        return minutes == 0 ? "Your Mac stays awake until you turn it off." : "Your Mac stays awake for \(duration(minutes: minutes))."
    }

    /// Shown when a command got no answer in time.
    public static let noAnswer = "Your Mac didn't answer. It may be asleep."
    /// Shown instead of sending when the Mac is out of reach.
    public static let unreachable = "Your Mac is out of reach right now."
}
