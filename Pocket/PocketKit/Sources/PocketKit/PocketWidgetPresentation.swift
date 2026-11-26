// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// MARK: The widgets' file

/// What the iPhone app leaves for its widgets in the App Group: the Mac's
/// newest state as the app heard it (trimmed further than the Watch's),
/// this iPhone's and its Watch's batteries, and since when the Mac shows
/// locked. The widgets read it, and write it again when they read the
/// Mac's box themselves.
public struct PocketWidgetSnapshot: Codable, Hashable, Sendable {
    public var mac: PocketWatchSnapshot?
    public var phone: PocketDeviceReport.Device?
    public var watch: PocketDeviceReport.Device?
    /// When the Mac's state first showed it locked after showing it unlocked
    /// (the Mac's clock); nil while unlocked, or when no unlocked state came
    /// before, since the state itself has no lock time.
    public var lockedSince: Date?

    public init(mac: PocketWatchSnapshot? = nil, phone: PocketDeviceReport.Device? = nil,
                watch: PocketDeviceReport.Device? = nil, lockedSince: Date? = nil) {
        self.mac = mac; self.phone = phone; self.watch = watch; self.lockedSince = lockedSince
    }

    /// With the Mac's state, when it is newer than the one kept (by when it
    /// was heard): trimmed, and the lock's time started, kept or cleared.
    public func with(_ state: PocketMacState, sentAt: Date, heardAt: Date) -> PocketWidgetSnapshot {
        if let mac, heardAt <= mac.heardAt { return self }
        var next = self
        next.mac = PocketWatchSnapshot(state: PocketWidgetPresentation.trimmed(state), sentAt: sentAt, heardAt: heardAt)
        if !state.locked {
            next.lockedSince = nil
        } else if let before = mac?.state, !before.locked {
            next.lockedSince = sentAt
        }
        return next
    }

    public func data() throws -> Data { try PocketWatchContext.encode(self) }

    public init(data: Data) throws { self = try PocketWatchContext.decode(PocketWidgetSnapshot.self, from: data) }
}

/// One small widget's words, in the Style Kit's sentence: the bold first
/// line (`lead`, `value` in its tone, `after`), the regular second line
/// (`rest`), and a mono line under them.
public struct PocketWidgetLines: Hashable, Sendable {
    /// The uppercase label on top ("MacBook Pro", "Claude · zenith").
    public var eyebrow: String
    public var sentence: PocketSentence
    public var meta: String?
    public var metaTone: PocketTone
    /// Claude waits on the person: the amber hairline and dot.
    public var needsYou: Bool

    public init(eyebrow: String, sentence: PocketSentence, meta: String? = nil, metaTone: PocketTone = .quiet,
                needsYou: Bool = false) {
        self.eyebrow = eyebrow; self.sentence = sentence; self.meta = meta; self.metaTone = metaTone; self.needsYou = needsYou
    }
}

// MARK: The widgets' words

/// What the iPhone's widgets, Lock Screen accessories and controls say, on
/// plain values so they can be tested without a screen.
public enum PocketWidgetPresentation {
    /// A saved state older than this is read again from the Mac's box.
    public static let refetchAfter: TimeInterval = 10 * 60
    /// A timeline asks for the next one this long after it starts.
    public static let timelineSpan: TimeInterval = 15 * 60
    /// The keep-awake length the control turns on.
    public static let awakeMinutes = 60

    /// The Watch's trim, and no last messages: the widgets never show them.
    public static func trimmed(_ state: PocketMacState) -> PocketMacState {
        var next = PocketWatchPresentation.trimmed(state)
        if var claude = next.claude {
            claude.sessions = claude.sessions.map { session in
                var s = session
                s.lastMessage = nil
                return s
            }
            next.claude = claude
        }
        return next
    }

    // MARK: Freshness

    /// The mono line: "updated just now", "updated 4m ago", "last known 2h ago".
    public static func freshnessLine(heardAt: Date?, now: Date) -> String? {
        switch PocketPresentation.freshness(heardAt: heardAt, live: false, now: now) {
        case .never, .live: return nil
        case .recent(let at): return "updated " + PocketPresentation.ago(at, now: now)
        case .away(let at): return "last known " + PocketPresentation.ago(at, now: now)
        }
    }

    static func reachable(_ mac: PocketWatchSnapshot?, now: Date) -> Bool {
        PocketPresentation.freshness(heardAt: mac?.heardAt, live: false, now: now).isReachable
    }

    private static func notPaired() -> PocketWidgetLines {
        PocketWidgetLines(eyebrow: "Pocket", sentence: PocketSentence(lead: "Not paired,", value: "", rest: "open Pocket.", tone: .quiet))
    }

    private static func waiting(_ eyebrow: String) -> PocketWidgetLines {
        PocketWidgetLines(eyebrow: eyebrow, sentence: PocketSentence(lead: "Waiting,", value: "", rest: "for your Mac.", tone: .quiet))
    }

    private static func away(_ eyebrow: String, _ mac: PocketWatchSnapshot, rest: String, now: Date) -> PocketWidgetLines {
        PocketWidgetLines(eyebrow: eyebrow, sentence: PocketSentence(lead: "Away,", value: "", rest: rest, tone: .quiet),
                          meta: freshnessLine(heardAt: mac.heardAt, now: now))
    }

    // MARK: Battery

    /// "At **47%**," / "charging." under the Mac's name.
    public static func battery(_ snapshot: PocketWidgetSnapshot?, paired: Bool, now: Date) -> PocketWidgetLines {
        guard paired else { return notPaired() }
        guard let mac = snapshot?.mac else { return waiting("Mac") }
        let state = mac.state
        let meta = freshnessLine(heardAt: mac.heardAt, now: now)
        guard let battery = state.battery else {
            if !reachable(mac, now: now) { return away(state.macName, mac, rest: "asleep or offline.", now: now) }
            return PocketWidgetLines(eyebrow: state.macName,
                                     sentence: PocketSentence(lead: "Online,", value: "", rest: "no battery here.", tone: .plain),
                                     meta: meta)
        }
        guard reachable(mac, now: now) else {
            return PocketWidgetLines(eyebrow: state.macName,
                                     sentence: PocketSentence(lead: "At ", value: "\(battery.percent)%", after: ",",
                                                              rest: "asleep or offline.", tone: .quiet),
                                     meta: meta)
        }
        return PocketWidgetLines(eyebrow: state.macName,
                                 sentence: PocketSentence(lead: "At ", value: "\(battery.percent)%", after: ",",
                                                          rest: batteryRest(battery),
                                                          tone: PocketPresentation.batteryTone(percent: battery.percent,
                                                                                               charging: battery.charging)),
                                 meta: meta)
    }

    /// "charging.", "full.", "plugged in.", "3h 10m left.", "on battery."
    static func batteryRest(_ battery: PocketMacState.Battery) -> String {
        if battery.charging { return battery.percent >= 100 ? "full." : "charging." }
        if battery.pluggedIn == true { return "plugged in." }
        if let minutes = battery.minutesRemaining { return PocketPresentation.duration(minutes: minutes) + " left." }
        return "on battery."
    }

    /// The bar's share, 0…1; nil without a battery.
    public static func batteryShare(_ snapshot: PocketWidgetSnapshot?) -> Double? {
        PocketWatchPresentation.batteryShare(snapshot?.mac?.state)
    }

    // MARK: Lock

    /// "Unlocked," / "tap to lock."; "Locked," / "since 09.41."; "Locked."
    public static func lock(_ snapshot: PocketWidgetSnapshot?, paired: Bool, now: Date) -> PocketWidgetLines {
        guard paired else { return notPaired() }
        guard let mac = snapshot?.mac else { return waiting("Mac") }
        let state = mac.state
        guard reachable(mac, now: now) else { return away(state.macName, mac, rest: "asleep or offline.", now: now) }
        let meta = freshnessLine(heardAt: mac.heardAt, now: now)
        guard state.locked else {
            return PocketWidgetLines(eyebrow: state.macName,
                                     sentence: PocketSentence(lead: "Unlocked,", value: "", rest: "tap to lock.", tone: .plain),
                                     meta: meta)
        }
        guard let since = snapshot?.lockedSince else {
            return PocketWidgetLines(eyebrow: state.macName, sentence: PocketSentence(lead: "Locked.", value: "", rest: "", tone: .plain),
                                     meta: meta)
        }
        return PocketWidgetLines(eyebrow: state.macName,
                                 sentence: PocketSentence(lead: "Locked,", value: "", rest: "since \(clock(since)).", tone: .plain),
                                 meta: meta)
    }

    /// Whether the lock button can do anything: a Mac in reach, unlocked.
    public static func canLock(_ snapshot: PocketWidgetSnapshot?, paired: Bool, now: Date) -> Bool {
        guard paired, let mac = snapshot?.mac else { return false }
        return reachable(mac, now: now) && !mac.state.locked
    }

    /// "09.41", as the Style Kit writes a time.
    public static func clock(_ date: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d.%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    // MARK: Claude

    /// "Your turn," / "18 min left."; "Working," / "editing Hero.swift.";
    /// "Claude is idle."
    public static func claude(_ snapshot: PocketWidgetSnapshot?, paired: Bool, now: Date) -> PocketWidgetLines {
        guard paired else { return notPaired() }
        guard let mac = snapshot?.mac else { return waiting("Claude") }
        let state = mac.state
        let session = PocketPresentation.claudeFocus(state.claude, chosen: nil)
        let eyebrow = session.map { "Claude · " + $0.project } ?? "Claude"
        guard reachable(mac, now: now) else { return away(eyebrow, mac, rest: "your Mac is asleep.", now: now) }
        let meta = freshnessLine(heardAt: mac.heardAt, now: now)
        func turn(_ rest: String, tap: String?) -> PocketWidgetLines {
            PocketWidgetLines(eyebrow: eyebrow, sentence: PocketSentence(lead: "Your turn,", value: "", rest: rest, tone: .plain),
                              meta: tap ?? meta, metaTone: tap == nil ? .quiet : .attention, needsYou: tap != nil)
        }
        if session?.state == .asking || !state.questions.isEmpty {
            return turn("it needs your OK.", tap: "tap to answer")
        }
        guard let session else { return idle(eyebrow, meta: meta) }
        switch session.state {
        case .waiting:
            if let left = claudeLeft(session, now: now) { return turn(left, tap: "tap to reply") }
            return turn("on your Mac.", tap: nil)
        case .working:
            let running = session.steps.last { $0.phase == .running }
            return PocketWidgetLines(eyebrow: eyebrow,
                                     sentence: PocketSentence(lead: "Working,", value: "",
                                                              rest: PocketPresentation.claudeActivity(running) + ".", tone: .plain),
                                     meta: meta)
        case .asking, .done:
            return idle(eyebrow, meta: meta)
        }
    }

    private static func idle(_ eyebrow: String, meta: String?) -> PocketWidgetLines {
        PocketWidgetLines(eyebrow: eyebrow, sentence: PocketSentence(lead: "Claude is idle.", value: "", rest: "", tone: .quiet),
                          meta: meta)
    }

    /// "18 min left.", "1h 5m left.", "under a minute left."; nil once a
    /// reply can't reach the held turn.
    public static func claudeLeft(_ session: PocketClaude.Session, now: Date) -> String? {
        guard let left = PocketPresentation.claudeWait(session, now: now)?.left else { return nil }
        if left < 60 { return "under a minute left." }
        let minutes = Int((left / 60).rounded(.up))
        return minutes < 60 ? "\(minutes) min left." : PocketPresentation.duration(minutes: minutes) + " left."
    }

    /// When the held turn stops waiting, for a timeline entry right after.
    public static func claudeDeadline(_ snapshot: PocketWidgetSnapshot?, now: Date) -> Date? {
        guard let state = snapshot?.mac?.state, let session = PocketPresentation.claudeFocus(state.claude, chosen: nil),
              let left = PocketPresentation.claudeWait(session, now: now)?.left else { return nil }
        return now.addingTimeInterval(left)
    }

    /// The Lock Screen's rectangle shows Claude while a session is busy or
    /// waits, and the Mac's battery otherwise.
    public static func rectangleShowsClaude(_ snapshot: PocketWidgetSnapshot?, now: Date) -> Bool {
        guard let mac = snapshot?.mac, reachable(mac, now: now) else { return false }
        if !mac.state.questions.isEmpty { return true }
        guard let session = PocketPresentation.claudeFocus(mac.state.claude, chosen: nil) else { return false }
        return session.state != .done
    }

    /// "Mac 47% · Claude waiting", "MacBook away", "Mac · waiting".
    public static func inline(_ snapshot: PocketWidgetSnapshot?, paired: Bool, now: Date) -> String {
        guard paired else { return "Pocket · not paired" }
        guard let mac = snapshot?.mac else { return "Mac · waiting" }
        return PocketWatchPresentation.inline(mac, now: now)
    }

    // MARK: Controls

    /// Keep-awake reads on while its end is still ahead.
    public static func awakeIsOn(_ snapshot: PocketWidgetSnapshot?, now: Date) -> Bool {
        guard let mac = snapshot?.mac, reachable(mac, now: now), let until = mac.state.awakeUntil else { return false }
        return until > now
    }

    /// The mic reads on unless the Mac said it is muted.
    public static func micIsOn(_ snapshot: PocketWidgetSnapshot?) -> Bool {
        !(snapshot?.mac?.state.sound?.micMuted ?? false)
    }

    // MARK: Timeline

    /// When a timeline's entries fall: every 5 minutes for the freshness
    /// line; every minute while a held turn counts down, and right after it
    /// ends; and right after the Mac would read as away.
    public static func entryDates(_ snapshot: PocketWidgetSnapshot?, now: Date) -> [Date] {
        let end = now.addingTimeInterval(timelineSpan)
        var dates = Set(stride(from: 0, to: timelineSpan, by: 5 * 60).map { now.addingTimeInterval($0) })
        if let deadline = claudeDeadline(snapshot, now: now) {
            for minute in stride(from: 60.0, to: min(deadline, end).timeIntervalSince(now), by: 60) {
                dates.insert(now.addingTimeInterval(minute))
            }
            if deadline < end { dates.insert(deadline.addingTimeInterval(1)) }
        }
        if let heard = snapshot?.mac?.heardAt {
            let away = min(heard, now).addingTimeInterval(PocketPresentation.offlineAfter + 1)
            if away > now, away < end { dates.insert(away) }
        }
        return dates.sorted()
    }

    /// The Smart Stack's score, as the Watch's.
    public static func relevance(_ snapshot: PocketWidgetSnapshot?, now: Date) -> Float {
        PocketWatchPresentation.relevance(snapshot?.mac, now: now)
    }

    /// Everything the widgets show apart from the time words (freshness, a
    /// held turn's countdown, which their timelines move on): when it
    /// changes, the app asks WidgetKit to reload them.
    public static func glance(_ snapshot: PocketWidgetSnapshot?, now: Date) -> String {
        let state = snapshot?.mac?.state
        let claude = claude(snapshot, paired: true, now: now)
        var parts = [battery(snapshot, paired: true, now: now).sentence.text,
                     lock(snapshot, paired: true, now: now).sentence.text,
                     claude.eyebrow + (claude.needsYou ? claude.sentence.lead + (claude.meta ?? "") : claude.sentence.text),
                     inline(snapshot, paired: true, now: now),
                     "\(awakeIsOn(snapshot, now: now))", "\(micIsOn(snapshot))", state?.macName ?? ""]
        let items = PocketPresentation.batteryItems(state, phone: snapshot?.phone, watch: snapshot?.watch, now: now)
        parts += items.prefix(4).map { "\($0.id):\($0.percent ?? -1):\($0.charging):\($0.seenAt != nil)" }
        return parts.joined(separator: "|")
    }
}
