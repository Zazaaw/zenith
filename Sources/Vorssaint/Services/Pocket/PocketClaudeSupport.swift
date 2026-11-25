// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: Zenith Pocket's Claude Code part on plain values, so it can be
/// tested without the hooks, the files or the relay: the phone's `PocketClaude`
/// built from the hook tracker's sessions, the usage the island reads, the end
/// of Claude's last reply read from its transcript, and Away mode's waiting
/// sessions and replies (see `ClaudeHooksSupport.hookScript`).
enum PocketClaudeRules {
    static let maximumSessions = 8
    static let maximumSteps = 8
    static let maximumMessage = 600
    static let maximumReply = 4000
    /// Done this long ago, a session reads as ended rather than waiting.
    static let idleAfter: TimeInterval = 30 * 60
    /// How much of a transcript's end is read for the last reply.
    static let transcriptTail = 256 * 1024
    /// How long the Mac waits for the hook to take a reply it wrote (the
    /// hook looks once a second).
    static let handoverWait: TimeInterval = 4

    // MARK: What the phone is told

    static let sharingOff = "Sharing Claude Code is off on this Mac."
    static let hooksNeeded = "Connect or update Claude Code's hooks in Zenith first: Settings, Dynamic Island, AI agents."
    static let awayOnLine = "Away mode is on. A finished turn waits up to 10 minutes for your reply."
    static let awayOffLine = "Away mode is off. Claude stops as usual."
    static let awayIsOff = "Turn on Away mode first."
    static let emptyReply = "Write something to send."
    static let longReply = "That reply is too long. Keep it under 4,000 characters."
    static let badSession = "That session isn't on this Mac."
    static let notWaiting = "That session isn't waiting for a reply anymore."
    static let sent = "Sent. Claude is on it."
    static let missed = "Claude stopped waiting before your reply arrived."
    static let couldNotWrite = "Zenith couldn't hand your reply to Claude."

    // MARK: The state

    /// The end of Claude's reply for the turn that finished at `finished`.
    struct Message: Equatable {
        let finished: Date
        let text: String
    }

    static func claude(sessions: [ClaudeHooksSupport.Session], messages: [String: Message], waiting: Set<String>,
                       usage: PocketClaude.Usage?, away: Bool, now: Date) -> PocketClaude {
        let shown = sessions.prefix(maximumSessions).map {
            session($0, message: messages[$0.id], acceptsReply: away && waiting.contains($0.id), now: now)
        }
        return PocketClaude(sessions: shown, usage: usage, away: away)
    }

    static func session(_ session: ClaudeHooksSupport.Session, message: Message?, acceptsReply: Bool,
                        now: Date) -> PocketClaude.Session {
        let state: PocketClaude.Session.State
        var waitingSince: Date?
        switch session.state {
        case .working:
            state = .working
        case .waiting(.permission):
            state = .asking
            waitingSince = session.waitingSince
        case .waiting(.input):
            state = .waiting
            // Claude Code's "idle" notice comes a minute after the turn ended.
            waitingSince = session.finished ?? session.waitingSince
        case .done:
            let finished = session.finished ?? session.lastEvent
            state = !acceptsReply && now.timeIntervalSince(finished) > idleAfter ? .done : .waiting
            waitingSince = finished
        }
        // A reply belongs to the turn it ended; once Claude works again it is old.
        let said = state != .working && message != nil && message?.finished == session.finished ? message?.text : nil
        let writes = session.steps.filter { $0.writes && $0.phase != .failed }
        let steps = session.steps.suffix(maximumSteps).map { step in
            PocketClaude.Step(id: step.id, tool: step.toolName, target: step.target, phase: phase(step.phase),
                              added: step.added, removed: step.removed, startedAt: step.startedAt ?? session.turnStarted)
        }
        return PocketClaude.Session(
            id: session.id, project: session.folder.isEmpty ? "Claude Code" : session.folder, state: state,
            turnStartedAt: session.turnStarted, waitingSince: waitingSince, lastMessage: said, steps: steps,
            filesChanged: Set(writes.compactMap(\.target)).count,
            added: writes.compactMap(\.added).reduce(0, +), removed: writes.compactMap(\.removed).reduce(0, +),
            acceptsReply: acceptsReply && state != .working && state != .asking)
    }

    private static func phase(_ phase: ClaudeHooksSupport.Step.Phase) -> PocketClaude.Step.Phase {
        switch phase {
        case .running: return .running
        case .done: return .done
        case .failed: return .failed
        }
    }

    /// Claude's allowance and spend as the island's agents page reads them;
    /// nil until the usage reader has loaded or when it knows nothing of Claude.
    static func usage(_ snapshot: AgentUsageSnapshot, now: Date) -> PocketClaude.Usage? {
        guard snapshot.loaded else { return nil }
        let windows = snapshot.limits[.claude]?.windows ?? []
        let session = windows.first { $0.kind == .session && $0.scope == nil }.map { AgentLimitSupport.current($0, at: now) }
        let week = windows.first { $0.kind == .weekly && $0.scope == nil }.map { AgentLimitSupport.current($0, at: now) }
        let today = snapshot.usage(.today).byProvider[.claude]
        let seven = snapshot.usage(.week).byProvider[.claude]
        // Without a reading from the account, the local 5-hour block still says when it renews.
        let block = snapshot.claudeBlock.flatMap { $0.end > now ? $0.end : nil }
        let usage = PocketClaude.Usage(
            windowPercent: session.map { percent($0.usedPercent) },
            windowResetsAt: session.flatMap { AgentLimitSupport.displayedReset($0, now: now) } ?? block,
            weekPercent: week.map { percent($0.usedPercent) },
            costToday: today.map(\.cost), costWeek: seven.map(\.cost),
            tokensToday: today.map(\.tokens.total))
        return usage == PocketClaude.Usage() ? nil : usage
    }

    private static func percent(_ value: Double) -> Int {
        value.isFinite ? Int(min(100, max(0, value)).rounded()) : 0
    }

    // MARK: The transcript

    /// The text of the last main-thread assistant message in the end of a
    /// transcript (JSON lines). A first line cut by the read is skipped.
    static func lastAssistantText(tail: Data, cutAtStart: Bool) -> String? {
        var lines = tail.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: true)
        if cutAtStart, !lines.isEmpty { lines.removeFirst() }
        for line in lines.reversed() {
            guard let object = (try? JSONSerialization.jsonObject(with: Data(line))) as? [String: Any],
                  object["type"] as? String == "assistant", object["isSidechain"] as? Bool != true,
                  let message = object["message"] as? [String: Any] else { continue }
            let text: String
            if let content = message["content"] as? String {
                text = content
            } else if let content = message["content"] as? [[String: Any]] {
                text = content.compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }
                    .joined(separator: "\n\n")
            } else {
                continue
            }
            let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty { return clean }
        }
        return nil
    }

    /// The end of `text`, at most `limit` characters, from a word's start,
    /// with an ellipsis when cut.
    static func ending(_ text: String, limit: Int = maximumMessage) -> String {
        guard text.count > limit else { return text }
        var tail = Substring(text.suffix(limit - 1))
        if let space = tail.prefix(40).firstIndex(where: \.isWhitespace) { tail = tail[tail.index(after: space)...] }
        return "…" + tail.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Reads the last reply from the transcript at `path`; nil when it can't.
    static func readLastMessage(path: String) -> String? {
        guard ClaudeHooksSupport.transcriptPath(path) != nil,
              let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd() else { return nil }
        let start = size > UInt64(transcriptTail) ? size - UInt64(transcriptTail) : 0
        guard (try? handle.seek(toOffset: start)) != nil, let data = try? handle.readToEnd() else { return nil }
        return lastAssistantText(tail: data, cutAtStart: start > 0).map { ending($0) }
    }

    // MARK: Away mode

    /// A Stop hook holding a turn: its script's pid and when it gives up.
    struct Waiting: Equatable {
        let pid: Int32
        let deadline: Date
    }

    /// `<session>.waiting` as the script writes it: "pid deadline".
    static func waiting(_ text: String) -> Waiting? {
        let parts = text.split(whereSeparator: \.isWhitespace)
        guard parts.count == 2, let pid = Int32(parts[0]), pid > 1, let seconds = Double(parts[1]),
              seconds.isFinite, seconds > 0 else { return nil }
        return Waiting(pid: pid, deadline: Date(timeIntervalSince1970: seconds))
    }

    /// The session a file in the away folder belongs to, and what it is.
    enum AwayFile: Equatable {
        case waiting(session: String)
        case reply(session: String, pid: Int32)
        case other
    }

    static func awayFile(_ name: String) -> AwayFile {
        if name.hasSuffix(".waiting") {
            let session = String(name.dropLast(8))
            return ClaudeHooksSupport.isValidID(session) ? .waiting(session: session) : .other
        }
        if name.hasSuffix(".reply") {
            let parts = name.dropLast(6).split(separator: ".")
            guard parts.count == 2, ClaudeHooksSupport.isValidID(String(parts[0])), let pid = Int32(parts[1]) else { return .other }
            return .reply(session: String(parts[0]), pid: pid)
        }
        return .other
    }

    static func replyName(session: String, pid: Int32) -> String { "\(session).\(pid).reply" }

    /// Whether a hook is still holding: before its deadline and its process alive.
    static func holds(_ waiting: Waiting, now: Date, alive: (Int32) -> Bool) -> Bool {
        now < waiting.deadline && alive(waiting.pid)
    }

    enum ReplyCheck: Equatable {
        /// The text as Claude gets it.
        case send(String)
        case refuse(String)
    }

    /// Whether a reply from the phone may go to `session`: Away on, a
    /// session holding for it, and 1 to 4000 characters once trimmed.
    static func check(reply text: String, session: String, away: Bool, holding: Bool) -> ReplyCheck {
        guard away else { return .refuse(awayIsOff) }
        guard ClaudeHooksSupport.isValidID(session) else { return .refuse(badSession) }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .refuse(emptyReply) }
        guard trimmed.count <= maximumReply else { return .refuse(longReply) }
        guard holding else { return .refuse(notWaiting) }
        return .send(trimmed)
    }

    /// What the hook prints for Claude Code: carry on, with the reply as the
    /// reason (Claude reads the reason as its next instruction).
    static func hookAnswer(_ reply: String) -> Data {
        let reason = "The user replied from their phone (Zenith Pocket):\n\n" + reply
        let object: [String: String] = ["decision": "block", "reason": reason]
        return (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data()
    }
}
