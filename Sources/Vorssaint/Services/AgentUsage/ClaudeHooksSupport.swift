// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: Claude Code's own hooks, followed live in the island.
///
/// Claude Code runs a command at points of a session (a prompt sent, a tool
/// about to run and done, a notification, the turn ending). Zenith's command
/// is a small `sh` script (`hookScript`) that reads the hook's JSON and leaves
/// one small JSON file in `<container>/Agents/`. The app watches that folder
/// (`ClaudeHooksService`); everything it decides lives here: reading a file,
/// what a session is doing (its steps this turn, the file being written and
/// its added and removed lines, whether it needs the person), when the closed
/// island says so, and when a session is stale.
///
/// Privacy: the script keeps the session's id, the folder's name, the event,
/// the tool, a file's name (never its path) or a program's name (never its
/// arguments), how many lines an edit adds and removes, and, when a turn
/// ends, where Claude Code keeps the session's transcript (so Zenith Pocket
/// can show the end of Claude's reply). Prompts, commands, file contents and
/// notification messages are read by the script only to count or to pick a
/// name, and never written anywhere.
///
/// Zenith Pocket's Away mode: while `<container>/PocketAway/on` exists, the
/// script holds a finished turn (`Stop`) for a reply from the phone, at most
/// `awayWait` seconds; see `hookScript`.
enum ClaudeHooksSupport {
    static let folderName = "Agents"
    static let scriptName = "zenith-claude-hook.sh"
    /// Zenith fork: Away mode's folder, beside `Agents` (whose foreign files are swept).
    static let awayFolderName = "PocketAway"
    /// The longest a finished turn may wait for a reply from the phone: a day,
    /// for "until I'm back". The wait itself is the number of seconds in
    /// `<away>/on`, which Zenith writes from the person's choice.
    static let awayWait = 86_400
    /// The wait when `<away>/on` says nothing usable (or comes from before the choice).
    static let awayDefaultWait = 600
    static let maxFileSize = 4096
    /// Files read in one look; more than that were left while the app was away.
    static let maxFilesPerScan = 400
    /// Rows the page's checklist shows, and steps a turn keeps.
    static let shownSteps = 6
    static let keptSteps = 24
    /// A session silent this long ended without saying so.
    static let staleAge: TimeInterval = 2 * 3600
    /// How long the closed island says a session waits for input. A request
    /// for permission stays until it is answered.
    static let inputNoticeDuration: TimeInterval = 10 * 60
    /// How long the closed island shows ✓ once a turn ends, and the shortest
    /// turn that earns it.
    static let doneDuration: TimeInterval = 5
    static let doneMinimumTurn: TimeInterval = 10
    /// A half-written or foreign file older than this was left by a crash.
    static let orphanAge: TimeInterval = 60
    /// Tools that only keep Claude's own notes; no row of their own.
    static let quietTools: Set<String> = ["TodoWrite", "TodoRead"]
    static let writingTools: Set<String> = ["Edit", "MultiEdit", "Write", "NotebookEdit"]

    // MARK: Preferences

    /// The island runs, its AI section shows, and Claude is one of its agents.
    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        NotchAgentSupport.isEnabled(in: defaults) && NotchAgentSupport.providers(in: defaults).contains(.claude)
    }

    static func playsSound(in defaults: UserDefaults = .standard) -> Bool {
        chime(in: defaults) != .off
    }

    /// What happens when a session starts needing the person. The old sound
    /// switch, turned off, still means off until a choice is made here.
    static func chime(in defaults: UserDefaults = .standard) -> ClaudeChimeMode {
        if defaults.object(forKey: DefaultsKey.notchAgentsClaudeSound) as? Bool == false { return .off }
        return defaults.string(forKey: DefaultsKey.notchAgentsClaudeChime).flatMap(ClaudeChimeMode.init(rawValue:))
            ?? .soundAndIsland
    }

    /// Makes `mode` the choice, leaving the old switch behind.
    static func setChime(_ mode: ClaudeChimeMode, in defaults: UserDefaults = .standard) {
        defaults.set(mode.rawValue, forKey: DefaultsKey.notchAgentsClaudeChime)
        defaults.removeObject(forKey: DefaultsKey.notchAgentsClaudeSound)
    }

    // MARK: Events

    /// What a session asks of the person.
    enum Attention: String, Equatable, Sendable {
        /// A tool waits for permission.
        case permission
        /// Claude waits for the next prompt or an answer.
        case input
    }

    /// One file the hook wrote.
    struct Event: Equatable, Sendable {
        enum Kind: String, Sendable, CaseIterable {
            case prompt, pre, post, failure, notification, stop, end
        }

        let kind: Kind
        let session: String
        let time: Date
        var folder: String?
        var tool: String?
        var toolID: String?
        var target: String?
        var added: Int?
        var removed: Int?
        /// Claude Code's notification type, never its message.
        var notice: String?
        /// Zenith fork: where the session's transcript is, on `stop` only.
        var transcript: String?

        /// Events written in the same instant apply in the order they happen.
        var rank: Int {
            switch kind {
            case .prompt: return 0
            case .pre: return 1
            case .notification: return 2
            case .post, .failure: return 3
            case .stop: return 4
            case .end: return 5
            }
        }
    }

    /// Reads one event file. Anything partial, oversized or of another shape
    /// is nil, and the caller deletes it. A name the hook cut in the middle of
    /// a character still reads.
    static func parse(_ data: Data) -> Event? {
        guard !data.isEmpty, data.count <= maxFileSize else { return nil }
        let text = String(decoding: data, as: UTF8.self)
        guard let object = (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? [String: Any],
              integer(object["v"]) == 1,
              let kind = (object["event"] as? String).flatMap(Event.Kind.init(rawValue:)),
              let session = object["session"] as? String, isValidID(session),
              let seconds = number(object["time"])?.doubleValue, seconds.isFinite, seconds > 0 else { return nil }
        var event = Event(kind: kind, session: session, time: Date(timeIntervalSince1970: seconds))
        event.folder = (object["folder"] as? String).flatMap { cleaned($0, limit: 64) }
        if kind == .pre || kind == .post || kind == .failure {
            guard let tool = object["tool"] as? String, isValidTool(tool) else { return nil }
            event.tool = tool
            event.toolID = (object["id"] as? String).flatMap { isValidID($0) ? $0 : nil }
            event.target = (object["target"] as? String).flatMap { cleaned($0, limit: 96) }
            event.added = count(object["added"])
            event.removed = count(object["removed"])
        }
        if kind == .notification {
            event.notice = (object["notice"] as? String).flatMap { $0.isEmpty ? nil : String($0.prefix(40)) }
        }
        if kind == .stop {
            event.transcript = (object["transcript"] as? String).flatMap(transcriptPath)
        }
        return event
    }

    /// Zenith fork: a transcript path as Claude Code gives it: absolute, a
    /// `.jsonl` file, no `..` and no control characters; nil otherwise.
    static func transcriptPath(_ path: String) -> String? {
        guard path.hasPrefix("/"), path.hasSuffix(".jsonl"), path.utf8.count <= 1024,
              !path.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
              !path.split(separator: "/").contains("..") else { return nil }
        return path
    }

    static func isValidID(_ id: String) -> Bool {
        !id.isEmpty && id.count <= 64
            && id.unicodeScalars.allSatisfy { $0.isASCII && (CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_") }
    }

    static func isValidTool(_ tool: String) -> Bool {
        !tool.isEmpty && tool.count <= 64 && tool.unicodeScalars.allSatisfy {
            $0.isASCII && (CharacterSet.alphanumerics.contains($0) || "_.-".unicodeScalars.contains($0))
        }
    }

    /// A name without control characters or a path, at most `limit` characters.
    static func cleaned(_ text: String, limit: Int) -> String? {
        let name = String(text.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) && $0 != "\u{FFFD}" })
            .split(separator: "/").last.map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        return name.isEmpty ? nil : String(name.prefix(limit))
    }

    private static func number(_ value: Any?) -> NSNumber? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        return number
    }

    private static func integer(_ value: Any?) -> Int? {
        guard let number = number(value), number.doubleValue.rounded() == number.doubleValue,
              abs(number.doubleValue) < 1e15 else { return nil }
        return number.intValue
    }

    private static func count(_ value: Any?) -> Int? {
        integer(value).flatMap { (0...10_000_000).contains($0) ? $0 : nil }
    }

    /// What a notification asks for; nil for the ones that ask nothing (a
    /// sign-in that worked, a plugin's own). Without a type, which older
    /// Claude Code versions leave out, it is waiting for the person.
    static func attention(forNotice notice: String?) -> Attention? {
        switch notice {
        case "permission_prompt": return .permission
        case nil, "", "idle_prompt", "agent_needs_input", "elicitation_dialog", "elicitation_url_dialog": return .input
        default: return nil
        }
    }

    // MARK: Files

    enum FileKind: Equatable {
        case event
        /// A file the hook is still writing.
        case temporary
        case foreign
    }

    /// The hook writes `.<pid>.tmp` and renames it to `<pid>.json`.
    static func kind(ofFile name: String) -> FileKind {
        func digits(_ text: Substring) -> Bool { !text.isEmpty && text.count <= 12 && text.allSatisfy { $0.isASCII && $0.isNumber } }
        if name.hasSuffix(".json"), digits(name.dropLast(5)) { return .event }
        if name.hasPrefix("."), name.hasSuffix(".tmp"), digits(name.dropFirst().dropLast(4)) { return .temporary }
        return .foreign
    }

    /// Event files are read and deleted at once; anything else goes once
    /// it is old enough to have been left behind.
    static func removesLeftover(_ kind: FileKind, age: TimeInterval) -> Bool {
        kind != .event && age > orphanAge
    }

    /// Events in the order they happened: by when their file was written
    /// (to the nanosecond on APFS), then by what comes first in a turn.
    static func ordered(_ events: [(event: Event, written: Date)]) -> [Event] {
        events.sorted {
            $0.written != $1.written ? $0.written < $1.written
                : $0.event.time != $1.event.time ? $0.event.time < $1.event.time
                : $0.event.rank < $1.event.rank
        }.map(\.event)
    }

    // MARK: Sessions

    struct Step: Equatable, Identifiable, Sendable {
        enum Phase: Equatable, Sendable { case running, done, failed }

        let id: String
        let tool: String
        let target: String?
        var phase: Phase
        var added: Int?
        var removed: Int?
        /// Zenith fork: when the tool started, for Zenith Pocket's timeline.
        var startedAt: Date?

        var writes: Bool { ClaudeHooksSupport.writingTools.contains(tool) }

        /// The tool as the person knows it: an MCP tool by its own name.
        var toolName: String {
            guard tool.hasPrefix("mcp__") else { return tool }
            return tool.components(separatedBy: "__").last.flatMap { $0.isEmpty ? nil : $0 } ?? tool
        }

        /// "Read Notes.md", "Bash npm", "Grep".
        var title: String { target.map { toolName + " " + $0 } ?? toolName }
    }

    /// The file the page's card shows: the last one a step touched, with
    /// what this turn added to and removed from it.
    struct FileFocus: Equatable, Sendable {
        let name: String
        let tool: String
        let phase: Step.Phase
        let stepID: String
        /// Lines, for a file this turn wrote; nil for one it read.
        let added: Int?
        let removed: Int?

        var writes: Bool { ClaudeHooksSupport.writingTools.contains(tool) }
    }

    struct Session: Equatable, Identifiable, Sendable {
        enum State: Equatable, Sendable {
            case working
            case waiting(Attention)
            case done
        }

        let id: String
        var folder: String
        var state: State
        /// This turn's steps, the last `keptSteps`.
        var steps: [Step] = []
        var turnStarted: Date
        var lastEvent: Date
        var finished: Date?
        var waitingSince: Date?
        var counter = 0
        /// Zenith fork: the transcript the last `stop` named.
        var transcript: String?

        var shownSteps: [Step] { Array(steps.suffix(ClaudeHooksSupport.shownSteps)) }

        var file: FileFocus? {
            guard let last = steps.last(where: { $0.target != nil }), let name = last.target else { return nil }
            guard last.writes else {
                return FileFocus(name: name, tool: last.tool, phase: last.phase, stepID: last.id, added: nil, removed: nil)
            }
            let same = steps.filter { $0.writes && $0.target == name && $0.phase != .failed }
            let added = same.compactMap(\.added).reduce(0, +)
            let removed = same.compactMap(\.removed).reduce(0, +)
            return FileFocus(name: name, tool: last.tool, phase: last.phase, stepID: last.id, added: added, removed: removed)
        }

        /// Waiting first, then working, then done; the latest of each first.
        var rank: Int {
            switch state {
            case .waiting: return 0
            case .working: return 1
            case .done: return 2
            }
        }
    }

    /// The closed island's part: a session that needs the person, or one
    /// that just finished.
    struct Strip: Equatable, Sendable {
        enum Kind: Equatable, Sendable {
            case needsYou(Attention)
            case done
        }

        let session: String
        let folder: String
        let kind: Kind
    }

    struct Tracker: Equatable, Sendable {
        var sessions: [String: Session] = [:]

        /// Applies one event; whether anything changed.
        @discardableResult
        mutating func apply(_ event: Event, now: Date) -> Bool {
            guard now.timeIntervalSince(event.time) <= ClaudeHooksSupport.staleAge else { return false }
            if event.kind == .end { return sessions.removeValue(forKey: event.session) != nil }
            // A turn whose start Zenith missed has nothing to finish.
            if sessions[event.session] == nil, event.kind == .stop { return false }
            if sessions[event.session] == nil, event.kind == .notification,
               ClaudeHooksSupport.attention(forNotice: event.notice) == nil { return false }
            let before = sessions[event.session]
            var session = before ?? Session(id: event.session, folder: event.folder ?? "", state: .working,
                                            turnStarted: event.time, lastEvent: event.time)
            if let folder = event.folder, !folder.isEmpty { session.folder = folder }
            session.lastEvent = max(session.lastEvent, event.time)
            switch event.kind {
            case .prompt:
                session.steps = []
                session.state = .working
                session.turnStarted = event.time
                session.finished = nil
                session.waitingSince = nil
            case .pre:
                guard let tool = event.tool, !ClaudeHooksSupport.quietTools.contains(tool) else { break }
                session.counter += 1
                let id = event.toolID ?? "step-\(session.counter)"
                if session.steps.contains(where: { $0.id == id }) { break }
                if session.state == .done {
                    // Work after the turn ended, like a background agent's.
                    session.finished = nil
                }
                session.state = .working
                session.waitingSince = nil
                session.steps.append(Step(id: id, tool: tool, target: event.target, phase: .running,
                                          added: event.added, removed: event.removed, startedAt: event.time))
                if session.steps.count > ClaudeHooksSupport.keptSteps {
                    session.steps.removeFirst(session.steps.count - ClaudeHooksSupport.keptSteps)
                }
            case .post, .failure:
                guard let tool = event.tool, !ClaudeHooksSupport.quietTools.contains(tool) else { break }
                let phase: Step.Phase = event.kind == .post ? .done : .failed
                let index = event.toolID.flatMap { id in session.steps.lastIndex { $0.id == id } }
                    ?? session.steps.lastIndex { $0.tool == tool && $0.phase == .running && (event.toolID == nil || $0.id.hasPrefix("step-")) }
                if let index {
                    session.steps[index].phase = phase
                } else {
                    session.counter += 1
                    session.steps.append(Step(id: event.toolID ?? "step-\(session.counter)", tool: tool,
                                              target: event.target, phase: phase, startedAt: event.time))
                }
                if case .waiting = session.state { session.state = .working; session.waitingSince = nil }
            case .notification:
                guard let attention = ClaudeHooksSupport.attention(forNotice: event.notice) else { break }
                session.state = .waiting(attention)
                session.waitingSince = event.time
            case .stop:
                session.state = .done
                session.finished = event.time
                session.waitingSince = nil
                if let transcript = event.transcript { session.transcript = transcript }
                for index in session.steps.indices where session.steps[index].phase == .running {
                    session.steps[index].phase = .done
                }
            case .end:
                break
            }
            sessions[event.session] = session
            return before != session
        }

        /// Drops sessions silent for too long; whether any went.
        @discardableResult
        mutating func removeStale(now: Date) -> Bool {
            let stale = sessions.values.filter { now.timeIntervalSince($0.lastEvent) > ClaudeHooksSupport.staleAge }.map(\.id)
            for id in stale { sessions.removeValue(forKey: id) }
            return !stale.isEmpty
        }

        /// Waiting first, then working, then done; within each the latest first.
        func ordered() -> [Session] {
            sessions.values.sorted { a, b in
                if a.rank != b.rank { return a.rank < b.rank }
                let first = a.waitingSince ?? a.finished ?? a.lastEvent
                let second = b.waitingSince ?? b.finished ?? b.lastEvent
                return first != second ? first > second : a.id < b.id
            }
        }

        func strip(now: Date) -> Strip? {
            let waiting = sessions.values.filter { session in
                guard case .waiting(let attention) = session.state, let since = session.waitingSince else { return false }
                return attention == .permission || now.timeIntervalSince(since) < ClaudeHooksSupport.inputNoticeDuration
            }
            let latest = waiting.max { a, b in
                let first = a.waitingSince ?? .distantPast, second = b.waitingSince ?? .distantPast
                return first != second ? first < second : a.id > b.id
            }
            if let session = latest, case .waiting(let attention) = session.state {
                return Strip(session: session.id, folder: session.folder, kind: .needsYou(attention))
            }
            let done = sessions.values.filter { session in
                guard session.state == .done, let finished = session.finished else { return false }
                let shown = now.timeIntervalSince(finished)
                return shown >= 0 && shown < ClaudeHooksSupport.doneDuration
                    && finished.timeIntervalSince(session.turnStarted) >= ClaudeHooksSupport.doneMinimumTurn
            }
            if let session = done.max(by: { ($0.finished ?? .distantPast) < ($1.finished ?? .distantPast) }) {
                return Strip(session: session.id, folder: session.folder, kind: .done)
            }
            return nil
        }

        /// The next moment the strip or the sessions change on their own.
        func nextChange(after now: Date) -> Date? {
            var moments: [Date] = []
            for session in sessions.values {
                moments.append(session.lastEvent.addingTimeInterval(ClaudeHooksSupport.staleAge))
                if let finished = session.finished { moments.append(finished.addingTimeInterval(ClaudeHooksSupport.doneDuration)) }
                if case .waiting(.input) = session.state, let since = session.waitingSince {
                    moments.append(since.addingTimeInterval(ClaudeHooksSupport.inputNoticeDuration))
                }
            }
            return moments.filter { $0 > now }.min()
        }
    }

    /// The session the page shows: the one picked, while it lasts, or the
    /// one that most needs a look.
    static func focus(_ sessions: [Session], chosen: String?) -> Session? {
        sessions.first { $0.id == chosen } ?? sessions.first
    }

    // MARK: Hook script

    /// Single-quoted for `sh`, a quote inside closed and escaped.
    static func shellQuoted(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Zenith fork: Away mode's folder for a hook folder: its sibling.
    static func awayFolder(beside folder: String) -> String {
        (folder as NSString).deletingLastPathComponent + "/" + awayFolderName
    }

    /// The script Claude Code runs on every hook, writing into `folder`.
    /// One `awk` reads the JSON (no `jq`, no network), a temporary file is
    /// renamed into place so the app never reads half of one, nothing is
    /// printed and it always exits 0. Measured at about 5 ms for a usual
    /// event; a 2 MB file written at once takes about 0.2 s to count. Once the
    /// folder is gone (the feature is off) it only looks for it.
    ///
    /// Zenith fork, Away mode: only when `<away>/on` exists and the event is
    /// `Stop`, the script then announces `<away>/<session>.waiting` ("pid
    /// deadline") and looks once a second, for as many seconds as `<away>/on`
    /// holds (`awayDefaultWait` when unusable, never more than `awayWait`), for
    /// `<away>/<session>.<pid>.reply`, which Zenith writes as the complete
    /// `{"decision":"block","reason":…}` answer. Found, it prints that file,
    /// so Claude carries on with the reply. Away turned off, Zenith's folder
    /// gone or the time up, it prints nothing and the turn ends as usual.
    /// The reply carries the waiting script's pid, so a late one is never
    /// read by a later turn.
    static func hookScript(folder: String) -> String {
        #"""
        #!/bin/sh
        # zenith-claude-hook: tells Zenith's Dynamic Island what Claude Code is doing.
        # Added by Zenith (Settings > Dynamic Island > AI agents). It reads the hook's
        # JSON on stdin and leaves a few fields in Zenith's folder: the session, the
        # folder's name, the event, the tool, a file's name or a program's name, how
        # many lines an edit adds and removes, and where a finished turn's transcript
        # is. Prompts, commands, arguments, file contents and messages are never kept.
        # It uses no network and always exits 0. Once Zenith's folder is gone it does
        # nothing at all. Only with Zenith Pocket's Away mode on does a finished turn
        # wait (as long as Pocket asks, a day at most) for a reply sent from the paired iPhone, and
        # print it for Claude Code; otherwise it prints nothing.
        d=\#(shellQuoted(folder))
        a=\#(shellQuoted(awayFolder(beside: folder)))
        [ -d "$d" ] || exit 0
        t="$d/.$$.tmp"
        s=""
        [ -f "$a/on" ] && s="$a/.$$.sid"
        ZENITH_SID="$s" /usr/bin/awk '
        function value(k,   re, v) {
          re = "\"" k "\"[ \t\r\n]*:[ \t\r\n]*\"([^\"\\\\]|\\\\.)*\""
          if (!match(s, re)) return ""
          v = substr(s, RSTART, RLENGTH)
          sub(/^"[^"]*"[ \t\r\n]*:[ \t\r\n]*"/, "", v)
          return substr(v, 1, length(v) - 1)
        }
        function lines(v,   n, off, size, c, len, last) {
          len = length(v)
          if (len == 0 || len > 8388608) return 0
          for (off = 1; off <= len; off += size) {
            size = 4096
            c = substr(v, off, size)
            if (match(c, /\\+$/) && RLENGTH % 2 == 1) { size++; c = substr(v, off, size) }
            gsub(/\\\\/, "", c)
            last = c ~ /\\n$/
            n += gsub(/\\n/, "", c)
          }
          return last ? n : n + 1
        }
        function total(k,   re, rest, v, n) {
          re = "\"" k "\"[ \t\r\n]*:[ \t\r\n]*\"([^\"\\\\]|\\\\.)*\""
          rest = s; n = 0
          while (match(rest, re)) {
            v = substr(rest, RSTART, RLENGTH)
            rest = substr(rest, RSTART + RLENGTH)
            sub(/^"[^"]*"[ \t\r\n]*:[ \t\r\n]*"/, "", v)
            n += lines(substr(v, 1, length(v) - 1))
          }
          return n
        }
        function word(v, keep, size) {
          gsub("[^" keep "]", "", v)
          return substr(v, 1, size)
        }
        function name(p) {
          gsub(/\\\//, "/", p)
          gsub(/\\./, "", p)
          sub(/\/+$/, "", p)
          sub(/.*\//, "", p)
          gsub(/[\001-\037]/, "", p)
          return substr(p, 1, 96)
        }
        function program(c,   w, n, i, x, skip, wrap) {
          c = substr(c, 1, 300)
          gsub(/\\[nrt]/, " ", c)
          gsub(/\\\//, "/", c)
          gsub(/\\./, "", c)
          gsub(/[;&|()]/, " ; ", c)
          n = split(c, w, /[ \t]+/)
          for (i = 1; i <= n; i++) {
            x = w[i]
            if (x == "") continue
            if (x == ";") { skip = 0; wrap = 0; continue }
            if (skip) continue
            if (x == "cd" || x == "pushd" || x == "export" || x == "source" || x == ".") { skip = 1; continue }
            if (x ~ /^[A-Za-z_][A-Za-z0-9_]*=/) continue
            if (wrap && (x ~ /^-/ || x ~ /^[0-9.]+[smhd]?$/)) continue
            if (x == "sudo" || x == "env" || x == "nice" || x == "time" || x == "timeout" || x == "command" \
                || x == "exec" || x == "nohup" || x == "caffeinate" || x == "xcrun") { wrap = 1; continue }
            sub(/.*\//, "", x)
            return word(x, "A-Za-z0-9._+-", 32)
          }
          return ""
        }
        { s = s $0 "\n" }
        END {
          e = value("hook_event_name")
          if (e == "UserPromptSubmit") k = "prompt"
          else if (e == "PreToolUse") k = "pre"
          else if (e == "PostToolUse") k = "post"
          else if (e == "PostToolUseFailure") k = "failure"
          else if (e == "Notification") k = "notification"
          else if (e == "Stop") k = "stop"
          else if (e == "SessionEnd") k = "end"
          else exit 1
          id = word(value("session_id"), "A-Za-z0-9_-", 64)
          if (id == "") exit 1
          srand(); now = srand()
          o = "{\"v\":1,\"event\":\"" k "\",\"session\":\"" id "\",\"time\":" now
          f = name(value("cwd"))
          if (f != "") o = o ",\"folder\":\"" f "\""
          if (k == "pre" || k == "post" || k == "failure") {
            tool = word(value("tool_name"), "A-Za-z0-9_.-", 64)
            o = o ",\"tool\":\"" tool "\""
            use = word(value("tool_use_id"), "A-Za-z0-9_-", 64)
            if (use != "") o = o ",\"id\":\"" use "\""
            if (tool == "Bash") target = program(value("command"))
            else { p = value("file_path"); if (p == "") p = value("notebook_path"); target = name(p) }
            if (target != "") o = o ",\"target\":\"" target "\""
            if (k == "pre" && (tool == "Edit" || tool == "MultiEdit"))
              o = o ",\"added\":" total("new_string") ",\"removed\":" total("old_string")
            else if (k == "pre" && tool == "Write")
              o = o ",\"added\":" lines(value("content")) ",\"removed\":0"
          }
          if (k == "notification") o = o ",\"notice\":\"" word(value("notification_type"), "a-z_", 40) "\""
          if (k == "stop") {
            tp = value("transcript_path")
            if (tp ~ /^\/.*\.jsonl$/ && length(tp) <= 1024) o = o ",\"transcript\":\"" tp "\""
            if (ENVIRON["ZENITH_SID"] != "") { print id > (ENVIRON["ZENITH_SID"]); close(ENVIRON["ZENITH_SID"]) }
          }
          print o "}"
        }' > "$t" 2>/dev/null && /bin/mv -f "$t" "$d/$$.json" 2>/dev/null || /bin/rm -f "$t" 2>/dev/null
        [ -n "$s" ] || exit 0
        i=$(/bin/cat "$s" 2>/dev/null)
        /bin/rm -f "$s" 2>/dev/null
        case "$i" in ""|*[!A-Za-z0-9_-]*) exit 0 ;; esac
        w="$a/$i.waiting"
        r="$a/$i.$$.reply"
        l=$(/bin/cat "$a/on" 2>/dev/null)
        case "$l" in ""|*[!0-9]*) l=\#(awayDefaultWait) ;; esac
        [ "$l" -ge 60 ] 2>/dev/null || l=\#(awayDefaultWait)
        [ "$l" -le \#(awayWait) ] || l=\#(awayWait)
        e=$(( $(/bin/date +%s) + l ))
        /bin/rm -f "$r" 2>/dev/null
        printf '%s %s\n' "$$" "$e" > "$w.$$.tmp" 2>/dev/null && /bin/mv -f "$w.$$.tmp" "$w" 2>/dev/null || exit 0
        trap '/bin/rm -f "$w" "$r" 2>/dev/null; exit 0' HUP INT TERM
        n=0
        while [ "$n" -lt "$l" ] && [ -f "$a/on" ] && [ -d "$d" ]; do
          if [ -f "$r" ]; then
            /bin/cat "$r" 2>/dev/null
            /bin/rm -f "$r" "$w" 2>/dev/null
            exit 0
          fi
          /bin/sleep 1
          n=$((n + 1))
        done
        /bin/rm -f "$w" 2>/dev/null
        exit 0

        """#
    }
}

/// Zenith fork: what a Claude Code session waiting for the person does. The
/// sound never plays on its own: it always comes with the island's burst
/// naming the project, so it is never a chime with nothing to see.
enum ClaudeChimeMode: String, CaseIterable, Identifiable {
    case off
    case soundAndIsland

    var id: String { rawValue }
}

/// Zenith fork: keeps many sessions sitting idle from chiming every minute:
/// one session at most once every 3 minutes, and any at most once every 30 s.
struct ClaudeChimeLimiter: Equatable {
    static let perSession: TimeInterval = 180
    static let overall: TimeInterval = 30

    private(set) var lastBySession: [String: Date] = [:]
    private(set) var last: Date?

    /// Whether `session` may chime at `now`; when it may, the chime counts.
    mutating func allows(session: String, at now: Date) -> Bool {
        if let last, now.timeIntervalSince(last) < Self.overall { return false }
        if let previous = lastBySession[session], now.timeIntervalSince(previous) < Self.perSession { return false }
        lastBySession = lastBySession.filter { now.timeIntervalSince($0.value) < Self.perSession }
        lastBySession[session] = now
        last = now
        return true
    }
}
