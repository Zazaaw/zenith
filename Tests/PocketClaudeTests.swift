// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: Zenith Pocket's Claude Code part: the phone's sessions built
/// from the hook tracker, usage from the island's reader, the end of Claude's
/// reply read from a transcript, Away mode's replies and their checks, the
/// Stop hook's longer timeout in `settings.json` (text only, never the real
/// file), and the hook script holding a turn only while Away mode is on.
enum PocketClaudeTests {
    typealias Rules = PocketClaudeRules
    typealias Support = ClaudeHooksSupport

    static func run(_ suite: TestSuite) {
        building(suite)
        usage(suite)
        transcript(suite)
        replies(suite)
        settings(suite)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("zenith-pocket-claude-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        guard (try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)) != nil else {
            suite.expect(false, "a temporary folder for the Pocket Claude tests")
            return
        }
        transcriptFile(suite, root: root)
        script(suite, root: root)
    }

    private static let now = Date(timeIntervalSince1970: 1_795_000_000)
    private static func ago(_ seconds: TimeInterval) -> Date { now.addingTimeInterval(-seconds) }

    private static func step(_ id: String, _ tool: String, _ target: String?, _ phase: Support.Step.Phase,
                             added: Int? = nil, removed: Int? = nil, at: TimeInterval) -> Support.Step {
        Support.Step(id: id, tool: tool, target: target, phase: phase, added: added, removed: removed, startedAt: ago(at))
    }

    private static func session(_ id: String, _ state: Support.Session.State, steps: [Support.Step] = [],
                                finished: Date? = nil, waitingSince: Date? = nil) -> Support.Session {
        Support.Session(id: id, folder: "zenith", state: state, steps: steps, turnStarted: ago(300),
                        lastEvent: ago(10), finished: finished, waitingSince: waitingSince)
    }

    // MARK: Building

    private static func building(_ suite: TestSuite) {
        let steps = [
            step("t1", "Read", "PocketService.swift", .done, at: 240),
            step("t2", "Edit", "PocketService.swift", .done, added: 24, removed: 6, at: 180),
            step("t3", "Edit", "PocketTests.swift", .done, added: 12, removed: 0, at: 120),
            step("t4", "Write", "Broken.swift", .failed, added: 99, removed: 0, at: 100),
            step("t5", "Bash", "build.sh", .running, at: 84),
        ]
        let working = Rules.session(session("a", .working, steps: steps), message: nil, acceptsReply: true, now: now)
        suite.expect(working.state == .working && working.steps.count == 5 && working.steps.last?.phase == .running
                     && working.steps.last?.startedAt == ago(84) && working.turnStartedAt == ago(300),
                     "a working session carries its steps with their start")
        suite.expect(working.filesChanged == 2 && working.added == 36 && working.removed == 6,
                     "the turn counts the files written and their lines, a failed write left out")
        suite.expect(!working.acceptsReply, "a working session never accepts a reply")

        let many = (0..<20).map { step("s\($0)", "Read", "f\($0)", .done, at: TimeInterval(100 - $0)) }
        let long = Rules.session(session("b", .working, steps: many), message: nil, acceptsReply: false, now: now)
        suite.expect(long.steps.count == Rules.maximumSteps && long.steps.first?.id == "s12" && long.steps.last?.id == "s19",
                     "the phone gets the latest steps, oldest first")

        let mcp = Rules.session(session("m", .working, steps: [step("x", "mcp__github__create_issue", nil, .running, at: 1)]),
                                message: nil, acceptsReply: false, now: now)
        suite.expect(mcp.steps.first?.tool == "create_issue", "an MCP tool goes by its own name")

        let finished = ago(60)
        let message = Rules.Message(finished: finished, text: "All tests pass. Commit?")
        let done = Rules.session(session("c", .done, steps: steps, finished: finished), message: message,
                                 acceptsReply: true, now: now)
        suite.expect(done.state == .waiting && done.waitingSince == finished && done.lastMessage == "All tests pass. Commit?"
                     && done.acceptsReply,
                     "a finished turn waits for the next prompt, with what Claude said")
        let older = Rules.session(session("c", .done, finished: ago(5)), message: message, acceptsReply: false, now: now)
        suite.expect(older.lastMessage == nil, "a reply read for an earlier turn is not shown for a later one")
        let workingAgain = Rules.session(session("c", .working, finished: finished), message: message, acceptsReply: false, now: now)
        suite.expect(workingAgain.lastMessage == nil, "once Claude works again its last reply is old")

        let idle = Rules.session(session("d", .done, finished: ago(Rules.idleAfter + 60)), message: nil, acceptsReply: false, now: now)
        suite.expect(idle.state == .done, "a turn finished long ago reads as ended")
        let held = Rules.session(session("d", .done, finished: ago(Rules.idleAfter + 60)), message: nil, acceptsReply: true, now: now)
        suite.expect(held.state == .waiting && held.acceptsReply, "a turn a hook still holds keeps waiting")

        let idlePrompt = Rules.session(session("e", .waiting(.input), finished: ago(120), waitingSince: ago(60)),
                                       message: nil, acceptsReply: false, now: now)
        suite.expect(idlePrompt.state == .waiting && idlePrompt.waitingSince == ago(120),
                     "Claude Code's idle notice keeps the wait from when the turn ended")
        let asking = Rules.session(session("f", .waiting(.permission), waitingSince: ago(30)), message: nil,
                                   acceptsReply: true, now: now)
        suite.expect(asking.state == .asking && asking.waitingSince == ago(30) && !asking.acceptsReply,
                     "a permission question is asking, never open to a reply")

        let all = (0..<12).map { session("s\($0)", .working) }
        let claude = Rules.claude(sessions: all, messages: [:], waiting: ["s0", "s1"], usage: nil, away: false, now: now)
        suite.expect(claude.sessions.count == Rules.maximumSessions && !claude.away
                     && claude.sessions.allSatisfy { !$0.acceptsReply },
                     "at most eight sessions; nothing accepts a reply with Away mode off")
        let away = Rules.claude(sessions: [session("w", .done, finished: ago(10)), session("x", .done, finished: ago(10))],
                                messages: [:], waiting: ["w"], usage: nil, away: true, now: now)
        suite.expect(away.away && away.sessions.map(\.acceptsReply) == [true, false],
                     "only a session whose hook holds accepts a reply")
        let project = Rules.session(Support.Session(id: "n", folder: "", state: .working, turnStarted: now, lastEvent: now),
                                    message: nil, acceptsReply: false, now: now)
        suite.expect(project.project == "Claude Code", "a session without a folder still has a name")
    }

    // MARK: Usage

    private static func usage(_ suite: TestSuite) {
        suite.expect(Rules.usage(AgentUsageSnapshot(), now: now) == nil, "nothing before the reader has loaded")
        var snapshot = AgentUsageSnapshot(loaded: true, now: now)
        suite.expect(Rules.usage(snapshot, now: now) == nil, "nothing when the reader knows nothing of Claude")
        snapshot.limits[.claude] = AgentLimits(provider: .claude, windows: [
            AgentLimitWindow(id: "5h", kind: .session, minutes: 300, scope: nil, usedPercent: 61.6, resetsAt: now.addingTimeInterval(3_600)),
            AgentLimitWindow(id: "7d-opus", kind: .weekly, minutes: nil, scope: "opus", usedPercent: 90, resetsAt: nil),
            AgentLimitWindow(id: "7d", kind: .weekly, minutes: nil, scope: nil, usedPercent: 33.2, resetsAt: nil),
        ], observedAt: now, source: .account)
        var today = AgentPeriodUsage()
        today.byProvider[.claude] = AgentTotals(tokens: AgentTokens(input: 1_000, output: 500), cost: 4.25)
        var week = AgentPeriodUsage()
        week.byProvider[.claude] = AgentTotals(cost: 31.5)
        snapshot.periods[.today] = today
        snapshot.periods[.week] = week
        let usage = Rules.usage(snapshot, now: now)
        suite.expect(usage?.windowPercent == 62 && usage?.windowResetsAt == now.addingTimeInterval(3_600)
                     && usage?.weekPercent == 33 && usage?.costToday == 4.25 && usage?.costWeek == 31.5
                     && usage?.tokensToday == 1_500,
                     "the 5-hour and plan-wide weekly windows, and today's and the week's spend")
        let renewed = Rules.usage(snapshot, now: now.addingTimeInterval(7_200))
        suite.expect(renewed?.windowPercent == 0, "a window that renewed since it was read has nothing spent")

        var local = AgentUsageSnapshot(loaded: true, now: now)
        local.claudeBlock = AgentBlock(start: ago(3_600), end: now.addingTimeInterval(4 * 3_600), totals: AgentTotals())
        let block = Rules.usage(local, now: now)
        suite.expect(block?.windowPercent == nil && block?.windowResetsAt == now.addingTimeInterval(4 * 3_600),
                     "without the account's reading the local 5-hour block still says when it renews")
    }

    // MARK: Transcript

    private static func line(_ object: [String: Any]) -> String {
        String(decoding: (try? JSONSerialization.data(withJSONObject: object)) ?? Data(), as: UTF8.self)
    }

    private static func assistant(_ content: Any, sidechain: Bool = false) -> String {
        line(["type": "assistant", "isSidechain": sidechain, "message": ["role": "assistant", "content": content]])
    }

    private static func transcript(_ suite: TestSuite) {
        let lines = [
            line(["type": "user", "message": ["role": "user", "content": "run the tests"]]),
            assistant([["type": "text", "text": "Running them now."], ["type": "tool_use", "name": "Bash", "input": [:]]]),
            line(["type": "user", "message": ["role": "user", "content": [["type": "tool_result", "content": "ok"]]]]),
            assistant([["type": "text", "text": "All 96 suites pass."], ["type": "text", "text": "Want me to commit?"]]),
            assistant([["type": "text", "text": "A subagent's note."]], sidechain: true),
            assistant([["type": "tool_use", "name": "TodoWrite", "input": [:]]]),
            line(["type": "system", "content": "Stop hook"]),
            "{ not json",
        ]
        let tail = Data(lines.joined(separator: "\n").utf8)
        suite.expect(Rules.lastAssistantText(tail: tail, cutAtStart: false) == "All 96 suites pass.\n\nWant me to commit?",
                     "the last main-thread assistant text, skipping tools, subagents and other lines")
        suite.expect(Rules.lastAssistantText(tail: Data(lines[0].utf8), cutAtStart: false) == nil,
                     "no reply in the tail reads as nothing")
        let cut = Data((#"rt of a line", "text": "cut"}]}}"# + "\n" + assistant("A plain string reply.")).utf8)
        suite.expect(Rules.lastAssistantText(tail: cut, cutAtStart: true) == "A plain string reply.",
                     "a first line cut by the read is skipped, and a plain string content reads")
        let cutOnly = Data(assistant("Only line").utf8)
        suite.expect(Rules.lastAssistantText(tail: cutOnly, cutAtStart: true) == nil,
                     "a tail that starts mid-line drops that line")

        suite.expect(Rules.ending("short") == "short", "a short reply stays whole")
        let wordCount = Rules.maximumMessage / 5 + 500
        let words = (0..<wordCount).map { "word\($0)" }.joined(separator: " ")
        let end = Rules.ending(words)
        suite.expect(end.count <= Rules.maximumMessage && end.hasPrefix("…word") && end.hasSuffix("word\(wordCount - 1)"),
                     "a reply over the limit keeps its end, from a word's start")
        let typical = (0..<1_100).map { "word\($0)" }.joined(separator: " ")
        suite.expect(Rules.ending(typical) == typical, "a long but ordinary reply (≈ 9 000 characters) stays whole")
        let solid = String(repeating: "x", count: Rules.maximumMessage + 1_000)
        suite.expect(Rules.ending(solid).count == Rules.maximumMessage, "a reply without spaces is cut to the limit")
    }

    private static func transcriptFile(_ suite: TestSuite, root: URL) {
        let file = root.appendingPathComponent("session-1.jsonl")
        var text = assistant([["type": "text", "text": "Early reply."]]) + "\n"
        let filler = line(["type": "user", "message": ["role": "user", "content": String(repeating: "z", count: 1_000)]])
        for _ in 0..<400 { text += filler + "\n" }
        text += assistant([["type": "text", "text": "The latest reply."]]) + "\n"
        try? Data(text.utf8).write(to: file)
        suite.expect(Rules.readLastMessage(path: file.path) == "The latest reply.",
                     "the last reply is read from the end of a transcript larger than the read")
        suite.expect(Rules.readLastMessage(path: root.appendingPathComponent("missing.jsonl").path) == nil
                     && Rules.readLastMessage(path: root.path + "/../" + root.lastPathComponent + "/session-1.jsonl") == nil
                     && Rules.readLastMessage(path: "relative/session.jsonl") == nil,
                     "a missing file, a path with .. or a relative path read nothing")
        suite.expect(Support.transcriptPath("/Users/me/.claude/projects/x/abc.jsonl") != nil
                     && Support.transcriptPath("/etc/passwd") == nil && Support.transcriptPath("/a/\u{0007}.jsonl") == nil,
                     "only an absolute .jsonl path is taken from the hook")
    }

    // MARK: Replies

    private static func replies(_ suite: TestSuite) {
        suite.expect(Rules.check(reply: "Commit it", session: "s1", away: false, holding: true) == .refuse(Rules.awayIsOff),
                     "no reply without Away mode")
        suite.expect(Rules.check(reply: "Commit it", session: "../x", away: true, holding: true) == .refuse(Rules.badSession),
                     "a session id that isn't one is refused")
        suite.expect(Rules.check(reply: " \n\t ", session: "s1", away: true, holding: true) == .refuse(Rules.emptyReply),
                     "an empty reply is refused")
        let longest = String(repeating: "a", count: Rules.maximumReply)
        suite.expect(Rules.check(reply: "  " + longest + "\n", session: "s1", away: true, holding: true) == .send(longest)
                     && Rules.check(reply: longest + "b", session: "s1", away: true, holding: true) == .refuse(Rules.longReply),
                     "a reply of up to 4000 characters, trimmed, goes; a longer one does not")
        suite.expect(Rules.check(reply: "Commit it", session: "s1", away: true, holding: false) == .refuse(Rules.notWaiting),
                     "a session whose hook stopped holding takes no reply")
        suite.expect(Rules.check(reply: "Ship it, \"now\" 🚀", session: "s-1_a", away: true, holding: true) == .send("Ship it, \"now\" 🚀"),
                     "a legitimate reply with quotes and emoji goes as written")

        let answer = Rules.hookAnswer("Run the tests\nthen \"commit\"")
        let object = (try? JSONSerialization.jsonObject(with: answer)) as? [String: String]
        suite.expect(object?["decision"] == "block" && object?["reason"]?.hasSuffix("Run the tests\nthen \"commit\"") == true,
                     "the hook's answer tells Claude Code to carry on with the reply")

        suite.expect(Rules.waiting("4242 1795000600\n") == Rules.Waiting(pid: 4242, deadline: Date(timeIntervalSince1970: 1_795_000_600))
                     && Rules.waiting("") == nil && Rules.waiting("1 5") == nil && Rules.waiting("abc 5") == nil,
                     "a waiting file reads as its pid and deadline")
        let held = Rules.Waiting(pid: 4242, deadline: now.addingTimeInterval(60))
        suite.expect(Rules.holds(held, now: now, alive: { _ in true }) && !Rules.holds(held, now: now, alive: { _ in false })
                     && !Rules.holds(held, now: now.addingTimeInterval(61), alive: { _ in true }),
                     "a hook holds while alive and before its deadline")
        suite.expect(Rules.awayFile("abc-1.waiting") == .waiting(session: "abc-1")
                     && Rules.awayFile("abc-1.4242.reply") == .reply(session: "abc-1", pid: 4242)
                     && Rules.awayFile(Rules.replyName(session: "abc", pid: 7)) == .reply(session: "abc", pid: 7)
                     && Rules.awayFile("on") == .other && Rules.awayFile("abc.waiting.99.tmp") == .other
                     && Rules.awayFile(".waiting") == .other && Rules.awayFile("a.b.c.reply") == .other,
                     "the away folder's files are told apart")
    }

    // MARK: Settings

    private static let command = ClaudeHooksSettings.command(script: "/Users/me/Library/Application Support/id.satuvisual.zenith/zenith-claude-hook.sh")

    private static func settings(_ suite: TestSuite) {
        typealias Settings = ClaudeHooksSettings
        suite.expect(Settings.stopTimeout > Support.awayWait && Settings.timeout(for: "Stop") == Settings.stopTimeout
                     && Settings.timeout(for: "PreToolUse") == Settings.timeout,
                     "Stop's timeout covers Away mode's wait; the others stay short")
        let installed = Settings.installing(command: command, into: "{\n  \"model\": \"opus\"\n}\n") ?? ""
        let object = (try? JSONSerialization.jsonObject(with: Data(installed.utf8))) as? [String: Any]
        let hooks = object?["hooks"] as? [String: Any]
        func timeout(_ event: String) -> Int? {
            (((hooks?[event] as? [[String: Any]])?.first?["hooks"] as? [[String: Any]])?.first?["timeout"]) as? Int
        }
        suite.expect(timeout("Stop") == Settings.stopTimeout && timeout("PreToolUse") == Settings.timeout
                     && timeout("UserPromptSubmit") == Settings.timeout,
                     "the merge gives Stop the long timeout and every other event the short one")
        suite.expect(Settings.state(of: installed, command: command) == .connected, "that merge is connected")
        suite.expect(Settings.fragment(command: command).contains("\"timeout\": \(Settings.stopTimeout)"),
                     "the alert shows Stop's longer timeout before anything is written")

        // Hooks merged before Away mode: Stop with 5 s would be cancelled mid-wait.
        let before = installed.replacingOccurrences(of: "\"timeout\": \(Settings.stopTimeout)", with: "\"timeout\": 5")
        suite.expect(before != installed && Settings.state(of: before, command: command) == .outdated,
                     "a Stop handler from before Away mode reads as needing an update")
        suite.expect(Settings.installing(command: command, into: before) == installed,
                     "connecting again brings the longer timeout, without doubling anything")
        let decimal = installed.replacingOccurrences(of: "\"timeout\": \(Settings.stopTimeout)", with: "\"timeout\": \(Settings.stopTimeout).5")
        suite.expect(Settings.state(of: decimal, command: command) == .connected, "a longer timeout set by hand is fine")
    }

    // MARK: Script

    private final class Hook {
        let process = Process()
        let output = Pipe()
        private var data = Data()
        private let lock = NSLock()

        init?(script: URL, payload: String) {
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = [script.path]
            let input = Pipe()
            process.standardInput = input
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            output.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let chunk = handle.availableData
                self?.lock.withLock { self?.data.append(chunk) }
            }
            do { try process.run() } catch { return nil }
            input.fileHandleForWriting.write(Data(payload.utf8))
            try? input.fileHandleForWriting.close()
        }

        /// Waits at most `seconds`; whether it ended.
        func wait(_ seconds: TimeInterval) -> Bool {
            let deadline = Date().addingTimeInterval(seconds)
            while process.isRunning, Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }
            return !process.isRunning
        }

        var printed: String {
            Thread.sleep(forTimeInterval: 0.1)
            output.fileHandleForReading.readabilityHandler = nil
            let rest = output.fileHandleForReading.readDataToEndOfFile()
            return lock.withLock { String(decoding: data + rest, as: UTF8.self) }
        }

        func kill() { if process.isRunning { process.terminate() } }
    }

    private static func waitFor(_ seconds: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return condition()
    }

    private static func script(_ suite: TestSuite, root: URL) {
        let manager = FileManager.default
        let folder = root.appendingPathComponent("Agents", isDirectory: true)
        let away = URL(fileURLWithPath: Support.awayFolder(beside: folder.path), isDirectory: true)
        let flag = away.appendingPathComponent("on")
        let script = root.appendingPathComponent("hook.sh")
        let text = Support.hookScript(folder: folder.path)
        try? Data(text.utf8).write(to: script)
        try? manager.createDirectory(at: folder, withIntermediateDirectories: true)
        try? manager.createDirectory(at: away, withIntermediateDirectories: true)
        suite.expect(away.lastPathComponent == Support.awayFolderName && away.deletingLastPathComponent().path == root.path
                     && text.contains("a='" + away.path + "'"),
                     "Away mode's folder sits beside the hook's, never inside the folder the app sweeps")
        let stop = #"{"session_id":"abc-1","cwd":"/x","hook_event_name":"Stop","stop_hook_active":false,"transcript_path":"/Users/me/.claude/projects/-x/abc-1.jsonl"}"#
        func events() -> [Support.Event] {
            let names = (try? manager.contentsOfDirectory(atPath: folder.path)) ?? []
            defer { for name in names { try? manager.removeItem(at: folder.appendingPathComponent(name)) } }
            return names.compactMap { try? Data(contentsOf: folder.appendingPathComponent($0)) }.compactMap(Support.parse)
        }

        // Away off: Stop returns at once, prints nothing, and still reports.
        let started = Date()
        if let hook = Hook(script: script, payload: stop) {
            let ended = hook.wait(5)
            suite.expect(ended && Date().timeIntervalSince(started) < 3 && hook.printed.isEmpty && hook.process.terminationStatus == 0,
                         "without Away mode a finished turn returns at once and prints nothing")
        } else { suite.expect(false, "the hook runs") }
        let reported = events()
        suite.expect(reported.count == 1 && reported.first?.kind == .stop
                     && reported.first?.transcript == "/Users/me/.claude/projects/-x/abc-1.jsonl",
                     "a finished turn tells the app where its transcript is")
        suite.expect(((try? manager.contentsOfDirectory(atPath: away.path)) ?? []).isEmpty,
                     "without Away mode nothing is announced")

        // A flag from before the choice ("1") waits the default.
        try? Data("1\n".utf8).write(to: flag)
        // Away on, any other event: as before.
        if let hook = Hook(script: script, payload: #"{"session_id":"abc-1","cwd":"/x","hook_event_name":"PreToolUse","tool_name":"Read","tool_input":{"file_path":"/x/a.md"}}"#) {
            suite.expect(hook.wait(5) && hook.printed.isEmpty, "Away mode never holds anything but a finished turn")
        }
        _ = events()

        // Away on, Stop: it announces itself, waits, and prints the reply it was given.
        if let hook = Hook(script: script, payload: stop) {
            let waitingFile = away.appendingPathComponent("abc-1.waiting")
            let announced = waitFor(5) { manager.fileExists(atPath: waitingFile.path) }
            let held = (try? String(contentsOf: waitingFile, encoding: .utf8)).flatMap(Rules.waiting)
            suite.expect(announced && held?.pid == hook.process.processIdentifier && hook.process.isRunning
                         && (held.map { abs($0.deadline.timeIntervalSinceNow - TimeInterval(Support.awayDefaultWait)) < 10 } ?? false),
                         "with Away mode a finished turn announces its pid and deadline and holds")
            // A reply for another pid (a turn that ended) is never read.
            let stray = away.appendingPathComponent(Rules.replyName(session: "abc-1", pid: 1))
            try? Rules.hookAnswer("stale").write(to: stray)
            Thread.sleep(forTimeInterval: 1.3)
            suite.expect(hook.process.isRunning, "a reply meant for another hook is not taken")
            try? manager.removeItem(at: stray)
            let answer = Rules.hookAnswer("Commit it")
            if let held { try? answer.write(to: away.appendingPathComponent(Rules.replyName(session: "abc-1", pid: held.pid))) }
            let ended = hook.wait(5)
            suite.expect(ended && hook.printed == String(decoding: answer, as: UTF8.self) && hook.process.terminationStatus == 0,
                         "the reply is printed for Claude Code as given")
            suite.expect(((try? manager.contentsOfDirectory(atPath: away.path)) ?? []) == ["on"],
                         "the hook cleans up its announcement and the reply")
            hook.kill()
        } else { suite.expect(false, "the hook runs") }
        _ = events()

        // Away turned off while it holds: it lets the turn end, printing nothing.
        if let hook = Hook(script: script, payload: stop) {
            _ = waitFor(5) { manager.fileExists(atPath: away.appendingPathComponent("abc-1.waiting").path) }
            try? manager.removeItem(at: flag)
            let ended = hook.wait(4)
            suite.expect(ended && hook.printed.isEmpty
                         && !manager.fileExists(atPath: away.appendingPathComponent("abc-1.waiting").path),
                         "turning Away mode off lets a held turn end at once, printing nothing")
            hook.kill()
        }
        _ = events()

        // The chosen wait comes from the flag, capped at a day.
        for (written, expected) in [("1800", 1800), ("999999", Support.awayWait)] {
            let file = away.appendingPathComponent("abc-1.waiting")
            try? manager.removeItem(at: file)
            try? Data("\(written)\n".utf8).write(to: flag)
            if let hook = Hook(script: script, payload: stop) {
                _ = waitFor(5) { manager.fileExists(atPath: file.path) }
                let held = (try? String(contentsOf: file, encoding: .utf8)).flatMap(Rules.waiting)
                suite.expect(held.map { abs($0.deadline.timeIntervalSinceNow - TimeInterval(expected)) < 10 } ?? false,
                             "a flag of \(written) s holds a finished turn \(expected) s")
                hook.kill()
                _ = waitFor(5) { !manager.fileExists(atPath: file.path) }
            }
            _ = events()
        }

        // Zenith's folder gone (the feature off) while it holds: same.
        try? Data("1\n".utf8).write(to: flag)
        if let hook = Hook(script: script, payload: stop) {
            _ = waitFor(5) { manager.fileExists(atPath: away.appendingPathComponent("abc-1.waiting").path) }
            try? manager.removeItem(at: folder)
            suite.expect(hook.wait(4) && hook.printed.isEmpty, "with Zenith's folder gone a held turn ends too")
            hook.kill()
        }
    }
}
