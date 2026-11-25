// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// The Claude tab's words: what a session is doing as a sentence, its steps'
/// times, the turn and usage lines, and why a reply can't go yet.
extension PocketPresentation {
    /// Away mode's wait when the Mac doesn't say (an older Zenith).
    public static let claudeReplyWindow: TimeInterval = 10 * 60
    /// The waits the phone offers; 0 is "until I'm back".
    public static let awayChoices = [10, 30, 60, 120, 0]

    public static func awayChoiceLabel(_ minutes: Int) -> String {
        minutes == 0 ? "Until I'm back" : duration(minutes: minutes)
    }

    /// The Away row's caption for the chosen wait.
    public static func awayCaption(on: Bool, minutes: Int?) -> String {
        guard on else { return "Claude stops as usual. Turn it on before you leave the Mac." }
        let wait = minutes ?? 10
        let span = wait == 0 ? "until you're back (a day at most)" : "up to \(duration(minutes: wait))"
        return "A finished turn waits \(span) for your reply. Unlocking the Mac turns it off."
    }
    public static let claudeReplyLimit = 4000

    /// Quick replies: what the chip says and what it writes.
    public static let claudeTemplates: [(title: String, text: String)] = [
        ("Continue", "Continue."),
        ("Commit it", "Commit it."),
        ("Run the tests", "Run the tests."),
        ("Explain the diff", "Explain the diff."),
    ]

    /// The session picked, while it lasts, or the one that most needs a look
    /// (the Mac sends them waiting first).
    public static func claudeFocus(_ claude: PocketClaude?, chosen: String?) -> PocketClaude.Session? {
        guard let claude else { return nil }
        return claude.sessions.first { $0.id == chosen } ?? claude.sessions.first
    }

    public static func claudeTone(_ state: PocketClaude.Session.State) -> PocketTone {
        switch state {
        case .working: return .progress
        case .waiting, .asking: return .attention
        case .done: return .quiet
        }
    }

    public static func claudeBadge(_ session: PocketClaude.Session?) -> PocketBadge {
        guard let session else { return PocketBadge("Quiet", .quiet) }
        switch session.state {
        case .working: return PocketBadge("Working", .progress)
        case .waiting: return PocketBadge("Your turn", .attention)
        case .asking: return PocketBadge("Needs you", .attention)
        case .done: return PocketBadge("Idle", .quiet)
        }
    }

    /// "**Claude is running the tests,** 4m into this turn."
    public static func claudeSentence(_ session: PocketClaude.Session?, now: Date) -> PocketSentence {
        guard let session else {
            return PocketSentence(lead: "Claude is ", value: "all quiet", after: ".", rest: "No session is running.", tone: .good)
        }
        switch session.state {
        case .working:
            let running = session.steps.last { $0.phase == .running }
            let into = session.turnStartedAt.map { Int(max(0, now.timeIntervalSince($0)) / 60) } ?? 0
            let rest = into < 1 ? "just into this turn." : duration(minutes: into) + " into this turn."
            return PocketSentence(lead: "Claude is ", value: claudeActivity(running), after: ",", rest: rest, tone: .progress)
        case .waiting:
            return PocketSentence(lead: "Claude is ", value: "done", after: ",", rest: "and waiting for you.", tone: .attention)
        case .asking:
            return PocketSentence(lead: "Claude ", value: "needs your OK", after: ",", rest: "a question on your Mac.", tone: .attention)
        case .done:
            let since = session.waitingSince.map { ago($0, now: now) } ?? "a while ago"
            return PocketSentence(lead: "Claude is ", value: "idle", after: ",", rest: "last turn ended " + since + ".", tone: .quiet)
        }
    }

    /// What a running step reads as in the hero: "running the tests",
    /// "editing Hero.swift", "thinking" between tools.
    public static func claudeActivity(_ step: PocketClaude.Step?) -> String {
        guard let step else { return "thinking" }
        let target = step.target.flatMap { $0.isEmpty ? nil : $0 }
        switch step.tool {
        case "Bash":
            guard let program = target else { return "running a command" }
            let tests: Set<String> = ["pytest", "jest", "vitest", "rspec", "phpunit", "mocha", "ctest"]
            return tests.contains(program.lowercased()) ? "running the tests" : "running " + program
        case "Edit", "MultiEdit", "NotebookEdit": return target.map { "editing " + $0 } ?? "editing"
        case "Write": return target.map { "writing " + $0 } ?? "writing a file"
        case "Read": return target.map { "reading " + $0 } ?? "reading"
        case "Grep", "Glob", "LS": return "searching the code"
        case "WebFetch": return "reading the web"
        case "WebSearch": return "searching the web"
        case "Task", "Agent": return "running an agent"
        default: return "using " + step.tool
        }
    }

    /// A running step's clock ("1:24"); a finished one's age ("4m", "now").
    public static func claudeStepTime(_ step: PocketClaude.Step, now: Date) -> String {
        let seconds = max(0, now.timeIntervalSince(step.startedAt))
        if step.phase == .running { return clock(seconds) }
        if seconds < 60 { return "now" }
        let minutes = Int(seconds / 60)
        return minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h"
    }

    /// "3 files", "1 file", "No files".
    public static func claudeFiles(_ session: PocketClaude.Session) -> String {
        switch session.filesChanged {
        case 0: return "No files"
        case 1: return "1 file"
        default: return "\(session.filesChanged) files"
        }
    }

    public static func claudeUsageTone(percent: Int) -> PocketTone {
        percent >= 85 ? .alert : percent >= 60 ? .attention : .good
    }

    /// "resets in 1h 12m".
    public static func claudeResets(_ usage: PocketClaude.Usage, now: Date) -> String? {
        guard let at = usage.windowResetsAt, at > now else { return nil }
        let left = countdown(to: at, now: now)
        return left == "now" ? "resets now" : "resets " + left
    }

    /// "$4.25", "$0.08", "$1,204".
    public static func claudeCost(_ dollars: Double) -> String {
        let value = dollars.isFinite ? max(0, dollars) : 0
        if value >= 1000 { return "$" + value.formatted(.number.precision(.fractionLength(0)).locale(Locale(identifier: "en_US"))) }
        return String(format: "$%.2f", value)
    }

    /// Why a reply can't go to `session` now; nil when it can.
    public static func claudeReplyBlocker(_ session: PocketClaude.Session, away: Bool, reachable: Bool) -> String? {
        if !reachable { return "Your Mac is out of reach. Replies work again once Zenith is back." }
        switch session.state {
        case .working: return "Claude is working. You can reply when this turn ends."
        case .asking: return "Claude is asking for permission. That's answered on your Mac."
        case .waiting, .done: break
        }
        if !away { return "Turn on Away mode, and the next turn that ends waits for your reply." }
        if !session.acceptsReply { return "This turn isn't waiting anymore. The next one that ends will." }
        return nil
    }

    /// "Claude waits 7m more" while a reply can still reach it.
    public static func claudeWaitLeft(_ session: PocketClaude.Session, now: Date) -> String? {
        guard session.acceptsReply else { return nil }
        let left: TimeInterval
        if let deadline = session.replyDeadline {
            left = deadline.timeIntervalSince(now)
        } else if let since = session.waitingSince {
            left = claudeReplyWindow - now.timeIntervalSince(since)
        } else {
            return nil
        }
        guard left > 0 else { return nil }
        return left < 60 ? "Claude waits less than a minute more" : "Claude waits \(duration(minutes: Int(left / 60))) more"
    }

    /// Whether a draft may be sent: something to say, within the limit.
    public static func claudeReplyFits(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= claudeReplyLimit
    }
}
