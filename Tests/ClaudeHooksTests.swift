// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: Claude Code's hooks in the island: reading the hook's files,
/// what the script keeps and leaves out, its line counts, a session's steps,
/// file and state, the closed island's "needs you" and ✓, stale sessions,
/// and the merge into `settings.json` (always on temporary files, never
/// the real `~/.claude/settings.json`).
enum ClaudeHooksTests {
    typealias Support = ClaudeHooksSupport
    typealias Settings = ClaudeHooksSettings

    static func run(_ suite: TestSuite) {
        parsing(suite)
        files(suite)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("zenith-claude-hooks-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        guard (try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)) != nil else {
            suite.expect(false, "a temporary folder for the hook tests")
            return
        }
        script(suite, root: root)
        redaction(suite, root: root)
        lineCounting(suite, root: root)
        stateMachine(suite)
        island(suite)
        staleCleanup(suite)
        settingsText(suite)
        settingsFile(suite, root: root)
        preferences(suite)
    }

    private static let base = Date(timeIntervalSince1970: 1_795_140_000)
    private static func at(_ seconds: TimeInterval) -> Date { base.addingTimeInterval(seconds) }

    private static func event(_ kind: Support.Event.Kind, _ seconds: TimeInterval, session: String = "s1",
                              tool: String? = nil, id: String? = nil, target: String? = nil,
                              added: Int? = nil, removed: Int? = nil, notice: String? = nil,
                              folder: String? = nil) -> Support.Event {
        var event = Support.Event(kind: kind, session: session, time: at(seconds))
        event.folder = folder
        event.tool = tool
        event.toolID = id
        event.target = target
        event.added = added
        event.removed = removed
        event.notice = notice
        return event
    }

    // MARK: Parsing

    private static func parsing(_ suite: TestSuite) {
        let good = Support.parse(Data(#"{"v":1,"event":"pre","session":"abc-123","time":1795140000,"folder":"Swift","tool":"Edit","id":"toolu_01","target":"Hero.swift","added":22,"removed":6}"#.utf8))
        suite.expect(good?.kind == .pre && good?.session == "abc-123" && good?.time == at(0) && good?.folder == "Swift"
                     && good?.tool == "Edit" && good?.toolID == "toolu_01" && good?.target == "Hero.swift"
                     && good?.added == 22 && good?.removed == 6,
                     "a tool event reads its session, time, folder, tool, id, file and lines")
        let notice = Support.parse(Data(#"{"v":1,"event":"notification","session":"abc","time":1795140001,"notice":"permission_prompt"}"#.utf8))
        suite.expect(notice?.kind == .notification && notice?.notice == "permission_prompt" && notice?.folder == nil,
                     "a notification reads its type and no folder when none was written")
        let stop = Support.parse(Data(#"{"v":1,"event":"stop","session":"abc","time":1795140002}"#.utf8))
        suite.expect(stop?.kind == .stop && stop?.tool == nil, "a stop needs only its session and time")

        // Partial: something the event needs is missing or of another shape.
        let partial = [
            #"{"v":1,"event":"pre","time":1795140000,"tool":"Read"}"#,
            #"{"v":1,"event":"pre","session":"abc","time":1795140000}"#,
            #"{"v":1,"event":"pre","session":"abc","tool":"Read"}"#,
            #"{"event":"stop","session":"abc","time":1795140000}"#,
            #"{"v":2,"event":"stop","session":"abc","time":1795140000}"#,
            #"{"v":1,"event":"launch","session":"abc","time":1795140000}"#,
            #"{"v":1,"event":"stop","session":"a b","time":1795140000}"#,
            #"{"v":1,"event":"stop","session":"abc","time":true}"#,
            #"{"v":1,"event":"stop","session":"abc","time":-5}"#,
            #"{"v":1,"event":"pre","session":"abc","time":1795140000,"tool":"Re ad"}"#,
            #"{"v":1,"event":"pre","session":"abc","time":1795140000,"tool":"Rea"#
        ]
        suite.expect(partial.allSatisfy { Support.parse(Data($0.utf8)) == nil },
                     "a partial event, or one of another version or shape, is not read")
        // Garbage.
        let garbage: [Data] = [Data(), Data("not json".utf8), Data("[1,2]".utf8), Data("{}".utf8),
                               Data([0xFF, 0xFE, 0x00, 0x7B]),
                               Data(("{\"v\":1,\"event\":\"stop\",\"session\":\"abc\",\"time\":1,\"pad\":\""
                                     + String(repeating: "x", count: 5000) + "\"}").utf8)]
        suite.expect(garbage.allSatisfy { Support.parse($0) == nil }, "garbage and oversized files are not read")

        // Values are kept small and plain.
        let messy = Support.parse(Data(#"{"v":1,"event":"post","session":"abc","time":1795140000,"tool":"Read","target":"/Users/me/secret/Notes.md","added":-3,"removed":1.5,"folder":"a\u0007b"}"#.utf8))
        suite.expect(messy?.target == "Notes.md" && messy?.added == nil && messy?.removed == nil && messy?.folder == "ab",
                     "a path keeps only its name, odd counts and control characters go")
        var cut = Data(#"{"v":1,"event":"pre","session":"abc","time":1795140000,"tool":"Read","target":"caf"#.utf8)
        cut.append(contentsOf: [0xC3])
        cut.append(contentsOf: Data(#""}"#.utf8))
        suite.expect(Support.parse(cut)?.target == "caf",
                     "a name the hook cut inside a character still reads, without the broken byte")
        suite.expect(Support.attention(forNotice: "permission_prompt") == .permission
                     && Support.attention(forNotice: "idle_prompt") == .input
                     && Support.attention(forNotice: nil) == .input
                     && Support.attention(forNotice: "auth_success") == nil,
                     "permission prompts and waiting for input need the person; a sign-in does not")
    }

    private static func files(_ suite: TestSuite) {
        suite.expect(Support.kind(ofFile: "4242.json") == .event && Support.kind(ofFile: ".4242.tmp") == .temporary
                     && Support.kind(ofFile: "notes.json") == .foreign && Support.kind(ofFile: "4242.json.bak") == .foreign
                     && Support.kind(ofFile: ".DS_Store") == .foreign,
                     "the hook's files and temporaries are told from anything else")
        suite.expect(Support.removesLeftover(.temporary, age: 61) && !Support.removesLeftover(.temporary, age: 5)
                     && Support.removesLeftover(.foreign, age: 120) && !Support.removesLeftover(.event, age: 10_000),
                     "a temporary or foreign file goes once it is old; events are read, never left over")
        let pre = event(.pre, 0, tool: "Edit", id: "t1")
        let post = event(.post, 0, tool: "Edit", id: "t1")
        let prompt = event(.prompt, 0)
        let ordered = Support.ordered([(post, at(1)), (pre, at(1)), (prompt, at(0.5))])
        suite.expect(ordered.map(\.kind) == [.prompt, .pre, .post],
                     "events apply in the order their files were written, then in a turn's order")
    }

    // MARK: Script

    /// Runs the hook script on `payload` with `folder` as Zenith's folder;
    /// what it printed, its status, and the event file it left.
    private static func runHook(_ payload: String, root: URL, folder: URL)
        -> (stdout: String, status: Int32, written: String?) {
        let script = root.appendingPathComponent("hook.sh")
        try? Data(Support.hookScript(folder: folder.path).utf8).write(to: script)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [script.path]
        let input = Pipe(), output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return ("", -1, nil) }
        input.fileHandleForWriting.write(Data(payload.utf8))
        try? input.fileHandleForWriting.close()
        let printed = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        let written = names.first.flatMap { try? String(contentsOf: folder.appendingPathComponent($0), encoding: .utf8) }
        for name in names { try? FileManager.default.removeItem(at: folder.appendingPathComponent(name)) }
        return (String(decoding: printed, as: UTF8.self), process.terminationStatus, written)
    }

    private static func script(_ suite: TestSuite, root: URL) {
        let folder = root.appendingPathComponent("Agents it's", isDirectory: true)
        let text = Support.hookScript(folder: folder.path)
        suite.expect(text.hasPrefix("#!/bin/sh\n# zenith-claude-hook:")
                     && text.contains("d='" + root.path + "/Agents it'\\''s'") && text.hasSuffix("exit 0\n"),
                     "the script names itself, quotes its folder and always ends with exit 0")
        suite.expect(!["curl", "nc ", "wget", "osascript", "python", "jq "].contains { text.contains($0) },
                     "the script uses no network and no other interpreter")

        // Without the folder (the feature is off) it does nothing at all.
        let off = runHook(#"{"session_id":"s","hook_event_name":"Stop"}"#, root: root, folder: folder)
        suite.expect(off.status == 0 && off.stdout.isEmpty && !FileManager.default.fileExists(atPath: folder.path),
                     "with Zenith's folder gone the hook exits 0, prints nothing and writes nothing")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let payloads = [
            #"{"session_id":"abc-1","cwd":"/Users/me/Zenith","hook_event_name":"UserPromptSubmit","prompt":"hi"}"#,
            #"{"session_id":"abc-1","cwd":"/x","hook_event_name":"PreToolUse","tool_name":"Read","tool_input":{"file_path":"/x/Notes.md"},"tool_use_id":"toolu_1"}"#,
            #"{"session_id":"abc-1","cwd":"/x","hook_event_name":"PostToolUse","tool_name":"Read","tool_input":{"file_path":"/x/Notes.md"},"tool_response":{"filePath":"/x/Notes.md"},"tool_use_id":"toolu_1"}"#,
            #"{"session_id":"abc-1","cwd":"/x","hook_event_name":"PostToolUseFailure","tool_name":"Bash","tool_input":{"command":"false"},"tool_use_id":"toolu_2"}"#,
            #"{"session_id":"abc-1","cwd":"/x","hook_event_name":"Notification","message":"m","notification_type":"idle_prompt"}"#,
            #"{"session_id":"abc-1","cwd":"/x","hook_event_name":"Stop","stop_hook_active":false}"#,
            #"{"session_id":"abc-1","cwd":"/x","hook_event_name":"SessionEnd","reason":"exit"}"#
        ]
        let kinds: [Support.Event.Kind] = [.prompt, .pre, .post, .failure, .notification, .stop, .end]
        var read: [Support.Event] = []
        var quiet = true
        for payload in payloads {
            let result = runHook(payload, root: root, folder: folder)
            quiet = quiet && result.stdout.isEmpty && result.status == 0
            if let written = result.written, let parsed = Support.parse(Data(written.utf8)) { read.append(parsed) }
        }
        suite.expect(quiet, "the hook never prints and always exits 0")
        suite.expect(read.map(\.kind) == kinds && read.allSatisfy { $0.session == "abc-1" }
                     && read[0].folder == "Zenith" && read[1].target == "Notes.md" && read[1].toolID == "toolu_1"
                     && read[4].notice == "idle_prompt",
                     "every event the hook writes reads back in the app")
        suite.expect(abs((read.first?.time ?? .distantPast).timeIntervalSinceNow) < 120,
                     "the hook stamps the time it ran")

        for junk in ["", "garbage {{{", #"{"session_id":"s","hook_event_name":"SubagentStart"}"#,
                     #"{"hook_event_name":"Stop"}"#] {
            let result = runHook(junk, root: root, folder: folder)
            suite.expect(result.status == 0 && result.stdout.isEmpty && result.written == nil
                         && ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).isEmpty,
                         "input the hook cannot use leaves nothing behind: \(junk.prefix(20))")
        }
    }

    // MARK: Redaction

    private static func redaction(_ suite: TestSuite, root: URL) {
        let folder = root.appendingPathComponent("Redaction", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let secrets = ["hunter2", "TOPSECRET", "s3cr3t-token", "private/projects", "my prompt words", "Permission text",
                       "transcript-path", "file body line"]
        let payloads = [
            #"{"session_id":"s","transcript_path":"/Users/me/transcript-path.jsonl","cwd":"/Users/me/private/projects/App","hook_event_name":"UserPromptSubmit","prompt":"my prompt words with hunter2"}"#,
            #"{"session_id":"s","cwd":"/Users/me/App","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"cd /Users/me/private/projects && API_KEY=s3cr3t-token nice -n 15 /usr/local/bin/deploy --password hunter2 TOPSECRET","description":"Deploy with TOPSECRET"},"tool_use_id":"toolu_9"}"#,
            #"{"session_id":"s","cwd":"/Users/me/App","hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"/Users/me/private/projects/Secrets.swift","content":"file body line\nlet key = \"hunter2\"\n"},"tool_use_id":"toolu_10"}"#,
            #"{"session_id":"s","cwd":"/Users/me/App","hook_event_name":"PostToolUse","tool_name":"Bash","tool_input":{"command":"echo TOPSECRET"},"tool_response":{"stdout":"TOPSECRET hunter2","stderr":""},"tool_use_id":"toolu_11"}"#,
            #"{"session_id":"s","cwd":"/Users/me/App","hook_event_name":"Notification","message":"Permission text for hunter2","title":"TOPSECRET","notification_type":"permission_prompt"}"#,
            #"{"session_id":"s","cwd":"/Users/me/App","hook_event_name":"Stop","last_assistant_message":"Done with TOPSECRET"}"#
        ]
        var outputs: [String] = []
        for payload in payloads {
            if let written = runHook(payload, root: root, folder: folder).written { outputs.append(written) }
        }
        let all = outputs.joined(separator: "\n")
        suite.expect(outputs.count == payloads.count && !secrets.contains { all.contains($0) },
                     "prompts, commands, arguments, contents, messages and paths never reach Zenith's folder")
        let bash = outputs.count > 1 ? Support.parse(Data(outputs[1].utf8)) : nil
        let write = outputs.count > 2 ? Support.parse(Data(outputs[2].utf8)) : nil
        suite.expect(bash?.target == "deploy" && write?.target == "Secrets.swift" && write?.folder == "App",
                     "a command keeps only its program's name, a file only its own name")
        let programs: [(String, String)] = [
            ("npm run build -- --token=abc", "npm"), ("./build.sh --test", "build.sh"),
            ("sudo -E env FOO=1 make install", "make"), ("timeout 30s swift test", "swift"),
            ("(cd sub; cargo build)", "cargo"), ("git status && git push", "git")
        ]
        var named = true
        for (command, program) in programs {
            let payload = #"{"session_id":"s","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":""#
                + command + #""}}"#
            let target = runHook(payload, root: root, folder: folder).written.flatMap { Support.parse(Data($0.utf8)) }?.target
            if target != program { named = false; suite.expect(false, "\(command) names \(program), not \(target ?? "nothing")") }
        }
        suite.expect(named, "the program is found past variables, wrappers, their options and a cd")
    }

    // MARK: Line counting

    private static func lineCounting(_ suite: TestSuite, root: URL) {
        let folder = root.appendingPathComponent("Lines", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        func counts(_ tool: String, _ input: [String: Any]) -> (added: Int?, removed: Int?) {
            let payload: [String: Any] = ["session_id": "s", "hook_event_name": "PreToolUse", "tool_name": tool,
                                          "tool_input": input, "tool_use_id": "t"]
            guard let data = try? JSONSerialization.data(withJSONObject: payload),
                  let written = runHook(String(decoding: data, as: UTF8.self), root: root, folder: folder).written,
                  let event = Support.parse(Data(written.utf8)) else { return (nil, nil) }
            return (event.added, event.removed)
        }
        let edit = counts("Edit", ["file_path": "/a/Hero.swift", "old_string": "a\nb\nc\nd\ne\nf",
                                   "new_string": "let x = \"\\n\"\nline 2\n"])
        suite.expect(edit.added == 2 && edit.removed == 6,
                     "an edit counts the lines it adds and removes; a trailing newline ends a line, a written \\n is not one")
        let write = counts("Write", ["file_path": "/a/New.swift", "content": "1\n2\n3\n"])
        suite.expect(write.added == 3 && write.removed == 0, "a new file counts its lines as added")
        suite.expect(counts("Write", ["file_path": "/a/One", "content": "one line"]).added == 1
                     && counts("Write", ["file_path": "/a/Empty", "content": ""]).added == 0
                     && counts("Write", ["file_path": "/a/Blank", "content": "\n"]).added == 1
                     && counts("Write", ["file_path": "/a/CRLF", "content": "a\r\nb\r\n"]).added == 2,
                     "one line, none, a blank line, Windows line ends")
        suite.expect(counts("Write", ["file_path": "/a/Slash", "content": "a\\\nb\\\\n"]).added == 2,
                     "a backslash before a newline still ends the line; an escaped backslash before n does not")
        let escaped = runHook(#"{"session_id":"s","cwd":"\/Users\/me\/App","hook_event_name":"PreToolUse","tool_name":"Read","tool_input":{"file_path":"\/a\/b\/Notes.md"}}"#,
                              root: root, folder: folder).written.flatMap { Support.parse(Data($0.utf8)) }
        suite.expect(escaped?.target == "Notes.md" && escaped?.folder == "App",
                     "a path whose slashes are escaped still gives its name")
        let multi = counts("MultiEdit", ["file_path": "/a/Page.swift", "edits": [
            ["old_string": "x", "new_string": "y\nz"], ["old_string": "p\nq", "new_string": ""]]])
        suite.expect(multi.added == 2 && multi.removed == 3, "a multi-edit adds up its edits")
        let big = counts("Write", ["file_path": "/a/Big.swift", "content": String(repeating: "let a = \"x\\n\"\n", count: 20_000)])
        suite.expect(big.added == 20_000, "a large file counts every line, across the script's chunks")
        let read = counts("Read", ["file_path": "/a/Notes.md"])
        suite.expect(read.added == nil && read.removed == nil, "reading a file counts nothing")
    }

    // MARK: Sessions

    private static func stateMachine(_ suite: TestSuite) {
        var tracker = Support.Tracker()
        let now = at(100)
        tracker.apply(event(.prompt, 0), now: now)
        tracker.apply(event(.pre, 1, tool: "Read", id: "t1", target: "Notes.md"), now: now)
        var session = tracker.sessions["s1"]
        suite.expect(session?.state == .working && session?.steps.map(\.title) == ["Read Notes.md"]
                     && session?.steps.first?.phase == .running && session?.file?.name == "Notes.md"
                     && session?.file?.added == nil,
                     "a prompt starts a turn and a tool about to run is the current step")
        tracker.apply(event(.post, 2, tool: "Read", id: "t1"), now: now)
        tracker.apply(event(.pre, 3, tool: "Edit", id: "t2", target: "Hero.swift", added: 22, removed: 6), now: now)
        session = tracker.sessions["s1"]
        suite.expect(session?.steps.map(\.phase) == [.done, .running] && session?.file?.name == "Hero.swift"
                     && session?.file?.added == 22 && session?.file?.removed == 6 && session?.file?.phase == .running,
                     "a finished step is checked, the edit under way is the file with its lines")
        tracker.apply(event(.post, 4, tool: "Edit", id: "t2"), now: now)
        tracker.apply(event(.pre, 5, tool: "Edit", id: "t3", target: "Hero.swift", added: 2, removed: 0), now: now)
        suite.expect(tracker.sessions["s1"]?.file?.added == 24 && tracker.sessions["s1"]?.file?.removed == 6,
                     "the same file's lines add up over the turn")
        tracker.apply(event(.failure, 6, tool: "Edit", id: "t3"), now: now)
        suite.expect(tracker.sessions["s1"]?.steps.last?.phase == .failed && tracker.sessions["s1"]?.file?.added == 22,
                     "a failed edit is marked and its lines no longer count")

        // Permission: Claude Code asks after the tool's pre hook.
        tracker.apply(event(.pre, 7, tool: "Bash", id: "t4", target: "npm"), now: now)
        tracker.apply(event(.notification, 8, notice: "permission_prompt"), now: now)
        suite.expect(tracker.sessions["s1"]?.state == .waiting(.permission) && tracker.sessions["s1"]?.waitingSince == at(8),
                     "a permission prompt makes the session wait for the person")
        tracker.apply(event(.post, 9, tool: "Bash", id: "t4"), now: now)
        suite.expect(tracker.sessions["s1"]?.state == .working, "the tool running means it was answered")
        tracker.apply(event(.notification, 9.5, notice: "auth_success"), now: now)
        suite.expect(tracker.sessions["s1"]?.state == .working, "a notification that asks nothing changes nothing")

        // Out of order, twice, quiet tools.
        tracker.apply(event(.post, 10, tool: "Grep", id: "t5"), now: now)
        tracker.apply(event(.pre, 10, tool: "Grep", id: "t5"), now: now)
        tracker.apply(event(.pre, 11, tool: "TodoWrite", id: "t6"), now: now)
        let ids = tracker.sessions["s1"]?.steps.map(\.id) ?? []
        suite.expect(ids.filter { $0 == "t5" }.count == 1 && !ids.contains("t6")
                     && tracker.sessions["s1"]?.steps.last?.phase == .done,
                     "a step seen after its end stays done, once; Claude's own notes take no row")
        for index in 0..<30 {
            tracker.apply(event(.pre, 12 + Double(index) * 0.1, tool: "Read", id: "r\(index)", target: "F\(index).swift"), now: now)
        }
        session = tracker.sessions["s1"]
        suite.expect(session?.steps.count == Support.keptSteps && session?.shownSteps.count == Support.shownSteps
                     && session?.shownSteps.last?.id == "r29",
                     "the checklist shows the last six steps; a turn keeps a few more")
        tracker.apply(event(.stop, 20), now: now)
        session = tracker.sessions["s1"]
        suite.expect(session?.state == .done && session?.finished == at(20)
                     && session?.steps.allSatisfy { $0.phase != .running } == true,
                     "the turn ending finishes the session and every step left running")
        tracker.apply(event(.prompt, 30), now: now)
        suite.expect(tracker.sessions["s1"]?.steps.isEmpty == true && tracker.sessions["s1"]?.state == .working,
                     "a new prompt starts a fresh checklist")

        // Several sessions: the one waiting comes first, then the working, then the done.
        tracker.apply(event(.prompt, 31, session: "s2", folder: "Web"), now: now)
        tracker.apply(event(.prompt, 32, session: "s3", folder: "Api"), now: now)
        tracker.apply(event(.stop, 45, session: "s3"), now: now)
        tracker.apply(event(.notification, 40, session: "s2", notice: "idle_prompt"), now: now)
        let order = tracker.ordered().map(\.id)
        suite.expect(order == ["s2", "s1", "s3"], "waiting first, then working, then done")
        suite.expect(Support.focus(tracker.ordered(), chosen: nil)?.id == "s2"
                     && Support.focus(tracker.ordered(), chosen: "s3")?.id == "s3"
                     && Support.focus(tracker.ordered(), chosen: "gone")?.id == "s2",
                     "the page follows the session needing a look, or the one picked while it lasts")
        tracker.apply(event(.end, 50, session: "s3"), now: now)
        suite.expect(tracker.sessions["s3"] == nil, "a session that ends goes")
        var fresh = Support.Tracker()
        suite.expect(!fresh.apply(event(.stop, 0, session: "unknown"), now: now) && fresh.sessions.isEmpty,
                     "a turn whose start Zenith missed has nothing to finish")
        suite.expect(fresh.apply(event(.notification, 0, session: "late", notice: "permission_prompt"), now: now)
                     && fresh.sessions["late"]?.state == .waiting(.permission),
                     "a session first seen asking for permission still needs you")
    }

    // MARK: Closed island

    private static func island(_ suite: TestSuite) {
        var tracker = Support.Tracker()
        let now = at(0)
        tracker.apply(event(.prompt, 0, folder: "Zenith"), now: now)
        tracker.apply(event(.pre, 1, tool: "Bash", id: "b", target: "npm"), now: now)
        suite.expect(tracker.strip(now: at(2)) == nil, "a session at work leaves the island to the agents' reading")
        tracker.apply(event(.notification, 7, notice: "permission_prompt"), now: now)
        suite.expect(tracker.strip(now: at(8)) == Support.Strip(session: "s1", folder: "Zenith", kind: .needsYou(.permission))
                     && tracker.strip(now: at(5000)) != nil,
                     "a permission prompt shows \"needs you\" with the folder until it is answered")
        tracker.apply(event(.post, 9, tool: "Bash", id: "b"), now: now)
        suite.expect(tracker.strip(now: at(10)) == nil, "answered, it leaves")
        tracker.apply(event(.stop, 30), now: now)
        suite.expect(tracker.strip(now: at(31)) == Support.Strip(session: "s1", folder: "Zenith", kind: .done)
                     && tracker.strip(now: at(30 + Support.doneDuration + 0.1)) == nil,
                     "a turn ending shows ✓ for a moment, then clears")
        suite.expect(tracker.nextChange(after: at(31)) == at(30 + Support.doneDuration),
                     "the service wakes when the ✓ runs out")
        tracker.apply(event(.notification, 90, notice: "idle_prompt"), now: now)
        suite.expect(tracker.strip(now: at(91))?.kind == .needsYou(.input)
                     && tracker.strip(now: at(90 + Support.inputNoticeDuration + 1)) == nil
                     && tracker.sessions["s1"]?.state == .waiting(.input),
                     "waiting for input shows a while, then only the page says so")
        suite.expect(tracker.nextChange(after: at(91)) == at(90 + Support.inputNoticeDuration),
                     "and the service wakes when that wait leaves the island")

        var quick = Support.Tracker()
        quick.apply(event(.prompt, 0), now: now)
        quick.apply(event(.stop, 3), now: now)
        suite.expect(quick.strip(now: at(4)) == nil, "a quick reply earns no ✓")

        var two = Support.Tracker()
        two.apply(event(.notification, 1, session: "a", notice: "idle_prompt", folder: "One"), now: now)
        two.apply(event(.notification, 2, session: "b", notice: "permission_prompt", folder: "Two"), now: now)
        suite.expect(two.strip(now: at(3))?.folder == "Two", "the latest session to need you is the one shown")
    }

    // MARK: Stale

    private static func staleCleanup(_ suite: TestSuite) {
        var tracker = Support.Tracker()
        let now = at(0)
        tracker.apply(event(.prompt, 0, session: "old"), now: now)
        tracker.apply(event(.notification, 10, session: "old", notice: "permission_prompt"), now: now)
        tracker.apply(event(.prompt, 3000, session: "new"), now: now)
        suite.expect(tracker.nextChange(after: at(20)) == at(10 + Support.staleAge),
                     "the service wakes when the oldest session goes stale")
        suite.expect(tracker.removeStale(now: at(10 + Support.staleAge + 1)) && tracker.sessions["old"] == nil
                     && tracker.sessions["new"] != nil,
                     "a session silent for two hours goes, even one that was waiting")
        suite.expect(!tracker.removeStale(now: at(10 + Support.staleAge + 2)), "nothing more to drop")
        var late = Support.Tracker()
        suite.expect(!late.apply(event(.prompt, 0), now: at(Support.staleAge + 1)) && late.sessions.isEmpty,
                     "events left from long ago start nothing")
    }

    // MARK: settings.json

    private static let command = Settings.command(script: "/Users/me/Library/Application Support/com.vorssaint.zenith/zenith-claude-hook.sh")

    private static let original = """
    {
      "model": "opus",
      "env": {
        "BASH_DEFAULT_TIMEOUT_MS": "120000"
      },
      "permissions": {
        "allow": [
          "Bash(npm test:*)",
          "Read(~/notes/**)"
        ]
      },
      "hooks": {
        "PreToolUse": [
          {
            "matcher": "Bash",
            "hooks": [
              {
                "type": "command",
                "command": "~/.claude/guard.sh",
                "timeout": 1.50
              }
            ]
          }
        ],
        "Stop": [
          {
            "hooks": [
              {
                "type": "command",
                "command": "afplay /System/Library/Sounds/Glass.aiff"
              }
            ]
          }
        ]
      },
      "statusLine": {
        "type": "command",
        "command": "echo \\"✦ café\\""
      },
      "cleanupPeriodDays": 30,
      "includeCoAuthoredBy": false
    }

    """

    private static func settingsText(_ suite: TestSuite) {
        suite.expect(Settings.command(script: "/a b/it's/zenith-claude-hook.sh")
                     == #"[ -f '/a b/it'\''s/zenith-claude-hook.sh' ] && exec /bin/sh '/a b/it'\''s/zenith-claude-hook.sh'; exit 0"#,
                     "the command runs the script when it is there and exits 0 when it is not")
        let fragment = Settings.fragment(command: command)
        let parsed = (try? JSONSerialization.jsonObject(with: Data(fragment.utf8))) as? [String: Any]
        let hooks = parsed?["hooks"] as? [String: Any]
        let pre = ((hooks?["PreToolUse"] as? [[String: Any]])?.first)
        let prompt = ((hooks?["UserPromptSubmit"] as? [[String: Any]])?.first)
        let handler = (pre?["hooks"] as? [[String: Any]])?.first
        suite.expect(Set(hooks?.keys.map { $0 } ?? []) == Set(Settings.events.map(\.name))
                     && pre?["matcher"] as? String == "*" && prompt?["matcher"] == nil
                     && handler?["type"] as? String == "command" && handler?["command"] as? String == command
                     && handler?["timeout"] as? Int == Settings.timeout,
                     "the alert shows every event with its handler, matchers only where Claude Code reads them")

        guard let installed = Settings.installing(command: command, into: original) else {
            suite.expect(false, "installing into a settings file"); return
        }
        suite.expect(Settings.state(of: original, command: command) == .missing
                     && Settings.state(of: installed, command: command) == .connected,
                     "connected once every event runs this command")
        suite.expect(Settings.installing(command: command, into: installed) == installed,
                     "connecting again changes nothing")
        let object = (try? JSONSerialization.jsonObject(with: Data(installed.utf8))) as? [String: Any]
        let newHooks = object?["hooks"] as? [String: Any]
        let preGroups = newHooks?["PreToolUse"] as? [[String: Any]]
        let stopGroups = newHooks?["Stop"] as? [[String: Any]]
        suite.expect(object?["model"] as? String == "opus" && object?["cleanupPeriodDays"] as? Int == 30
                     && (object?["permissions"] as? [String: Any])?["allow"] as? [String] == ["Bash(npm test:*)", "Read(~/notes/**)"]
                     && preGroups?.count == 2 && preGroups?.first?["matcher"] as? String == "Bash"
                     && stopGroups?.count == 2
                     && ((object?["statusLine"] as? [String: Any])?["command"] as? String) == "echo \"✦ café\"",
                     "every other key and hook stays, the person's own hooks first")
        suite.expect(installed.contains("\"timeout\": 1.50") && installed.contains("✦ café")
                     && installed.range(of: "\"model\"")!.lowerBound < installed.range(of: "\"env\"")!.lowerBound
                     && installed.range(of: "\"statusLine\"")!.lowerBound < installed.range(of: "\"includeCoAuthoredBy\"")!.lowerBound
                     && installed.hasSuffix("}\n"),
                     "keys keep their order, numbers their spelling, text its characters, the file its last newline")
        suite.expect(Settings.removing(from: installed) == original,
                     "disconnecting gives the very same file back")

        // Another build's command, or an older one: replaced, never doubled.
        let other = Settings.command(script: "/Users/me/Library/Application Support/com.vorssaint.zenith.dev/zenith-claude-hook.sh")
        let otherInstalled = Settings.installing(command: other, into: original) ?? ""
        suite.expect(Settings.state(of: otherInstalled, command: command) == .outdated,
                     "another build's hooks read as needing an update")
        let replaced = Settings.installing(command: command, into: otherInstalled) ?? ""
        suite.expect(replaced == installed && !replaced.contains("zenith.dev"),
                     "connecting replaces another build's hooks instead of adding more")
        // A handler someone put beside Zenith's in its group stays.
        let shared = installed.replacingOccurrences(of: "\"timeout\": 5\n", with: "\"timeout\": 5\n          },\n          {\n            \"type\": \"command\",\n            \"command\": \"say hi\"\n", options: [], range: installed.range(of: "\"UserPromptSubmit\"").map { $0.lowerBound..<installed.endIndex })
        let sharedRemoved = Settings.removing(from: shared) ?? ""
        suite.expect(sharedRemoved.contains("say hi") && !sharedRemoved.contains(Settings.marker),
                     "only Zenith's own handlers are taken out")

        // Fresh and empty files.
        let fresh = Settings.installing(command: command, into: nil) ?? ""
        suite.expect(Settings.state(of: fresh, command: command) == .connected && Settings.removing(from: fresh) == "{}",
                     "a missing file gets just the hooks, and gives back an empty object")
        suite.expect(Settings.state(of: "{\n  \"hooks\": {}\n}", command: command) == .missing
                     && Settings.removing(from: "{\n  \"hooks\": {}\n}") == "{\n  \"hooks\": {}\n}",
                     "an empty hooks object the person left stays")
        // Unreadable.
        for bad in ["{ // comment\n}", "[1, 2]", "{\"hooks\": [1]}", "{\"a\": 1,}", "{\"a\": 01}", "{\"a\": \"\\ud800\"}"] {
            suite.expect(Settings.installing(command: command, into: bad) == nil,
                         "text that is not a settings object is never edited: \(bad.prefix(16))")
        }
        suite.expect(Settings.state(of: "{ nope", command: command) == .unreadable, "unreadable text says so")
        let roundTrip = #"{"a":[1,-2.5e+3,true,false,null,"\u00e9\n\"x\"\/"],"b":{}}"#
        suite.expect(ClaudeSettingsJSON.parse(roundTrip).map { ClaudeSettingsJSON.parse($0.serialized()) == $0 } == true,
                     "every JSON value reads back as written")
    }

    private static func settingsFile(_ suite: TestSuite, root: URL) {
        let manager = FileManager.default
        let real = Settings.settingsURL.standardizedFileURL.path
        let folder = root.appendingPathComponent("dot-claude", isDirectory: true)
        let file = folder.appendingPathComponent("settings.json")
        suite.expect(file.standardizedFileURL.path != real && !file.path.hasPrefix(manager.homeDirectoryForCurrentUser.path + "/.claude"),
                     "the test file is not the real ~/.claude/settings.json")
        try? manager.createDirectory(at: folder, withIntermediateDirectories: true)
        try? Data(original.utf8).write(to: file)
        try? manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)

        suite.expect(Settings.edit(at: file, install: command) == .changed, "connecting writes the file")
        let backup = folder.appendingPathComponent("settings.json" + Settings.backupSuffix)
        suite.expect((try? String(contentsOf: backup, encoding: .utf8)) == original,
                     "the old file is kept beside it first")
        let mode = (try? manager.attributesOfItem(atPath: file.path))?[.posixPermissions] as? NSNumber
        suite.expect(mode?.intValue == 0o600, "the file keeps its permissions")
        suite.expect(Settings.edit(at: file, install: command) == .unchanged, "connecting twice leaves it alone")
        let text = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
        suite.expect(Settings.state(of: text, command: command) == .connected, "the file is connected")
        suite.expect(Settings.edit(at: file, install: nil) == .changed
                     && (try? String(contentsOf: file, encoding: .utf8)) == original,
                     "disconnecting gives the original back")
        suite.expect(Settings.edit(at: file, install: nil) == .unchanged, "disconnecting twice leaves it alone")

        // A dotfile manager's link: the target changes, the link stays a link.
        let target = root.appendingPathComponent("dotfiles-settings.json")
        let link = folder.appendingPathComponent("linked.json")
        try? Data(original.utf8).write(to: target)
        try? manager.createSymbolicLink(at: link, withDestinationURL: target)
        suite.expect(Settings.edit(at: link, install: command) == .changed, "a linked file is edited")
        let linkKind = (try? manager.attributesOfItem(atPath: link.path))?[.type] as? FileAttributeType
        suite.expect(linkKind == .typeSymbolicLink
                     && Settings.state(of: try? String(contentsOf: target, encoding: .utf8), command: command) == .connected,
                     "through its link, which stays a link")

        // Missing and broken files.
        let missing = root.appendingPathComponent("new-home/.claude/settings.json")
        suite.expect(Settings.edit(at: missing, install: nil) == .unchanged && !manager.fileExists(atPath: missing.path),
                     "disconnecting a missing file creates nothing")
        suite.expect(Settings.edit(at: missing, install: command) == .changed
                     && Settings.state(of: try? String(contentsOf: missing, encoding: .utf8), command: command) == .connected,
                     "connecting creates the file and its folder")
        let broken = folder.appendingPathComponent("broken.json")
        try? Data("{ \"a\": 1, // note\n}".utf8).write(to: broken)
        suite.expect(Settings.edit(at: broken, install: command) == .unreadable
                     && (try? String(contentsOf: broken, encoding: .utf8)) == "{ \"a\": 1, // note\n}"
                     && !manager.fileExists(atPath: broken.path + Settings.backupSuffix),
                     "a file Zenith cannot read is never touched")
    }

    private static func preferences(_ suite: TestSuite) {
        suite.expect(Defaults.registeredDefaults[DefaultsKey.notchAgentsClaudeSound] as? Bool == true
                     && Defaults.registeredDefaults[DefaultsKey.notchAgentsClaudeLastEvent] == nil,
                     "the sound starts on; when the hook last wrote stays out of backups")
        let domain = "com.vorssaint.tests.claude-hooks"
        let defaults = UserDefaults(suiteName: domain)!
        defaults.removePersistentDomain(forName: domain)
        defer { defaults.removePersistentDomain(forName: domain) }
        suite.expect(Support.playsSound(in: defaults), "without a choice the sound plays")
        defaults.set(false, forKey: DefaultsKey.notchAgentsClaudeSound)
        suite.expect(!Support.playsSound(in: defaults), "turned off, it stays quiet")
    }
}
