// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: terminal commands in the closed island: reading the hook's
/// files, naming the program without its arguments, what stays out, when a
/// command shows and how long its result stays, several terminals at once,
/// stale commands, and the `~/.zshrc` block (always on a temporary file).
enum CommandActivityTests {
    typealias Support = CommandActivitySupport

    static func run(_ suite: TestSuite) {
        parsing(suite)
        files(suite)
        redaction(suite)
        ignoreList(suite)
        clock(suite)
        thresholds(suite)
        multipleTerminals(suite)
        staleCleanup(suite)
        hookBlock(suite)
        zshrcText(suite)
        zshrcFile(suite)
        island(suite)
    }

    private static let base = Date(timeIntervalSince1970: 1_763_520_000)

    private static func start(_ id: String, _ command: String, at seconds: TimeInterval, pid: Int32? = 4242,
                              folder: String? = "zenith") -> Support.Event {
        Support.Event(id: id, phase: .start, time: base.addingTimeInterval(seconds), pid: pid, tty: "ttys003",
                      command: command, folder: folder)
    }

    private static func end(_ id: String, status: Int32, at seconds: TimeInterval) -> Support.Event {
        Support.Event(id: id, phase: .end, time: base.addingTimeInterval(seconds), status: status)
    }

    private static func at(_ seconds: TimeInterval) -> Date { base.addingTimeInterval(seconds) }

    // MARK: Parsing

    private static func parsing(_ suite: TestSuite) {
        let good = Data(#"{"id":"4242-7","pid":4242,"tty":"ttys003","start":1763520000.25,"cmd":"npm run build","cwd":"zenith"}"#.utf8)
        let event = Support.parse(good)
        suite.expect(event?.phase == .start && event?.id == "4242-7" && event?.pid == 4242 && event?.tty == "ttys003"
                     && event?.command == "npm run build" && event?.folder == "zenith"
                     && event?.time == Date(timeIntervalSince1970: 1_763_520_000.25),
                     "a start event reads its id, shell, time, command and folder")
        let ended = Support.parse(Data(#"{"id":"4242-7","status":1,"end":1763520042.5}"#.utf8))
        suite.expect(ended?.phase == .end && ended?.status == 1 && ended?.command == nil
                     && ended?.time == Date(timeIntervalSince1970: 1_763_520_042.5),
                     "an end event reads its status and time")
        let hookEscapes = Data(#"{"id":"1-1","pid":1,"tty":"","start":1763520000,"cmd":"echo \"a\" back\\slash","cwd":"my dir"}"#.utf8)
        suite.expect(Support.parse(hookEscapes)?.command == #"echo "a" back\slash"#
                     && Support.parse(hookEscapes)?.tty == nil,
                     "the hook's escaped quotes and backslashes read back, an empty tty is none")

        let partial: [String] = [
            #"{"id":"4242-7","start":1763520000}"#,                      // no command
            #"{"id":"4242-7","start":1763520000,"cmd":"   "}"#,         // blank command
            #"{"id":"4242-7","status":0}"#,                              // end without time
            #"{"id":"4242-7","end":1763520000}"#,                        // end without status
            #"{"start":1763520000,"cmd":"make"}"#,                       // no id
            #"{"id":"../x","start":1763520000,"cmd":"make"}"#,           // id that walks out
            #"{"id":"4242-7","start":"soon","cmd":"make"}"#,             // time as text
            #"{"id":"4242-7","start":true,"cmd":"make"}"#,               // time as a boolean
            #"{"id":"4242-7","start":12,"cmd":"make"}"#,                 // before 2001
            #"{"id":"4242-7","end":1763520000,"status":1.5}"#,           // fractional status
            #"{"id":"4242-7","start":1763520000,"cmd":"ma"#,             // cut short
        ]
        for text in partial {
            suite.expect(Support.parse(Data(text.utf8)) == nil, "a partial event is refused: \(text)")
        }
        let garbage: [Data] = [Data(), Data("not json".utf8), Data("[1,2]".utf8), Data([0xFF, 0xFE, 0x00]),
                               Data(("{\"id\":\"1-1\",\"start\":1763520000,\"cmd\":\"" + String(repeating: "a", count: 5000) + "\"}").utf8)]
        suite.expect(garbage.allSatisfy { Support.parse($0) == nil }, "garbage and oversized files are refused")
        suite.expect(Support.isValidID("123-4") && !Support.isValidID("123") && !Support.isValidID("a-1")
                     && !Support.isValidID("1-2-3") && !Support.isValidID("-1") && !Support.isValidID(""),
                     "ids are a pid and a counter")
    }

    private static func files(_ suite: TestSuite) {
        suite.expect(Support.fileName(id: "12-3", phase: .start) == "12-3.start.json"
                     && Support.kind(ofFile: "12-3.start.json") == .event(id: "12-3", phase: .start)
                     && Support.kind(ofFile: "12-3.end.json") == .event(id: "12-3", phase: .end),
                     "event files name their command and phase")
        suite.expect(Support.kind(ofFile: "12-3.start.tmp") == .temporary
                     && Support.kind(ofFile: ".DS_Store") == .foreign && Support.kind(ofFile: "x.y.json") == .foreign
                     && Support.kind(ofFile: "12-3.middle.json") == .foreign,
                     "half-written and unknown files are told apart")
        suite.expect(!Support.removesLeftover(.temporary, age: 5) && Support.removesLeftover(.temporary, age: 61)
                     && Support.removesLeftover(.foreign, age: 120)
                     && !Support.removesLeftover(.event(id: "1-1", phase: .start), age: 99_999),
                     "a temporary file is given a minute to be renamed; event files are the tracker's to decide")
        let ordered = Support.ordered([end("1-1", status: 0, at: 9), start("1-2", "make", at: 3),
                                       start("1-1", "make", at: 1)])
        suite.expect(ordered.map { "\($0.id).\($0.phase)" } == ["1-1.start", "1-2.start", "1-1.end"],
                     "starts are applied before ends, each in time order")
    }

    // MARK: Redaction

    private static func redaction(_ suite: TestSuite) {
        let cases: [(String, String?)] = [
            ("npm run build", "npm"),
            ("./build.sh --test", "./build.sh"),
            ("../tools/deploy.sh prod", "deploy.sh"),
            ("/usr/bin/make -j8 install", "make"),
            ("sudo make install", "make"),
            ("sudo -u deploy -E ./release.sh --token abc", "./release.sh"),
            ("env API_KEY=hunter2 TOKEN=abc docker build .", "docker"),
            ("env -i PATH=/bin swift build", "swift"),
            ("API_KEY=hunter2 npm run deploy", "npm"),
            ("FOO='a b' BAR=\"c d\" cargo build --release", "cargo"),
            ("nice -n 15 ./build.sh --test", "./build.sh"),
            ("time xcrun swift test", "swift"),
            ("timeout 600 terraform apply -auto-approve", "terraform"),
            ("cd web && npm run build", "npm"),
            ("export TOKEN=abc; ./deploy.sh", "./deploy.sh"),
            ("(cd api; go build ./...)", "go"),
            ("docker build -t app . | tee build.log", "docker"),
            ("\\rm -rf build", "rm"),
            ("cd ..", "cd"),
            ("  ", nil),
            ("FOO=1", nil),
        ]
        for (command, expected) in cases {
            suite.expect(Support.program(of: command) == expected,
                         "\(command) names \(expected ?? "nothing"), got \(Support.program(of: command) ?? "nothing")")
        }
        // Nothing past the program, nor any assignment's value, ever reaches what the island shows.
        let secrets = ["hunter2", "abc", "--token", "TOKEN", "API_KEY", "a b", "prod", "-auto-approve", "PATH", "-j8", "="]
        let shown = cases.compactMap { Support.program(of: $0.0) }
        suite.expect(!shown.contains { name in secrets.contains { name.contains($0) } },
                     "no argument or secret leaks into a shown name: \(shown)")
        suite.expect(Support.displayName(String(repeating: "x", count: 80))?.count == Support.maxProgramLength,
                     "a long program name is shortened")
        suite.expect(Support.displayName("./run\u{7}.sh") == "./run.sh", "control characters never reach the island")
        suite.expect(Support.sanitizedFolder(String(repeating: "f", count: 60))?.count == Support.maxFolderLength
                     && Support.sanitizedFolder("/") == nil,
                     "a folder name is bounded")
    }

    // MARK: Ignore list

    private static func ignoreList(_ suite: TestSuite) {
        let ignored = [
            "vim notes.md", "nvim .", "less log.txt", "man zsh", "ssh prod", "top", "htop", "tail -f app.log",
            "tail -n 50 -F app.log", "claude", "claude --resume", "codex", "python3", "node", "irb", "psql db",
            "sudo -s", "caffeinate", "npm run dev", "npm start", "pnpm dev", "yarn dev:web", "bun run dev",
            "npx vite", "next dev", "vite", "docker compose up", "docker run -it ubuntu bash", "kubectl logs -f api",
            "git log", "python -m http.server", "rails s", "journalctl -f", "log stream", "ping example.com",
            "cd app && npm run dev", "watch -n1 ls", "tmux attach",
        ]
        for command in ignored {
            suite.expect(Support.isIgnored(command), "\(command) never ends on its own and stays out")
        }
        let shown = [
            "./build.sh --test", "npm run build", "npm test", "docker build .", "docker compose up -d",
            "python3 train.py", "node scripts/migrate.js", "tail -n 100 app.log", "swift build", "vercel deploy --prod",
            "git push", "git clone https://example.com/repo", "ping -c 3 example.com", "brew upgrade", "make",
            "cargo build --release", "terraform apply", "rsync -a src dst",
        ]
        for command in shown {
            suite.expect(!Support.isIgnored(command), "\(command) ends on its own and can show")
        }
        let extra = Support.extraIgnored(" make, terraform  /usr/local/bin/k6 ,,")
        suite.expect(extra == ["make", "terraform", "k6"], "the person's additions are names, parted by commas or spaces")
        suite.expect(Support.isIgnored("make -j8", extra: extra) && Support.isIgnored("sudo terraform plan", extra: extra)
                     && !Support.isIgnored("cargo build", extra: extra),
                     "added programs stay out, wrappers or not")
    }

    // MARK: Clock and thresholds

    private static func clock(_ suite: TestSuite) {
        suite.expect(Support.clock(0) == "0:00" && Support.clock(42.9) == "0:42" && Support.clock(185) == "3:05"
                     && Support.clock(599) == "9:59" && Support.clock(3599) == "59:59" && Support.clock(3730) == "1:02:10"
                     && Support.clock(-5) == "0:00" && Support.clock(.nan) == "0:00",
                     "the clock reads m:ss, then h:mm:ss from an hour")
        suite.expect(Support.clockTemplate(long: false).count >= Support.clock(3599).count
                     && Support.clockTemplate(long: true).count >= Support.clock(11 * 3600 + 3599).count,
                     "the clock's slot holds its widest reading, so its width never changes while it ticks")
    }

    private static func thresholds(_ suite: TestSuite) {
        let domain = "com.vorssaint.tests.command-activity"
        let defaults = UserDefaults(suiteName: domain)!
        defaults.removePersistentDomain(forName: domain)
        defer { defaults.removePersistentDomain(forName: domain) }
        suite.expect(Support.threshold(in: defaults) == 8 && !Support.isEnabled(in: defaults),
                     "off by default, showing after 8 seconds")
        defaults.set(15, forKey: DefaultsKey.notchCommandThreshold)
        suite.expect(Support.threshold(in: defaults) == 15, "a listed threshold is kept")
        defaults.set(7, forKey: DefaultsKey.notchCommandThreshold)
        suite.expect(Support.threshold(in: defaults) == 8, "anything else falls back to 8 seconds")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.notchCommandActivity] as? Bool == false
                     && Defaults.registeredDefaults[DefaultsKey.notchCommandThreshold] as? Int == 8
                     && Defaults.registeredDefaults[DefaultsKey.notchCommandShowsFolder] as? Bool == false
                     && Defaults.registeredDefaults[DefaultsKey.notchCommandLastEvent] == nil,
                     "the options are registered (so backed up), the last event is not")

        let configuration = Support.Configuration(threshold: 8)
        var tracker = Support.Tracker()
        suite.expect(tracker.apply(start("1-1", "./build.sh --test", at: 0), configuration: configuration, now: at(0)),
                     "a running command keeps its start file")
        suite.expect(tracker.activity(now: at(7.9), configuration: configuration) == nil,
                     "a quick command never flashes")
        suite.expect(tracker.nextChange(after: at(1), configuration: configuration) == at(8),
                     "the activity is due to change as the command passes the threshold")
        suite.expect(tracker.activity(now: at(8), configuration: configuration)
                        == .running(id: "1-1", program: "./build.sh", folder: nil, start: at(0), others: 0, long: false),
                     "after 8 seconds it shows the program, the folder only when asked")
        suite.expect(tracker.activity(now: at(8), configuration: Support.Configuration(threshold: 8, showsFolder: true))?
                        .folder == "zenith",
                     "Show folder adds the folder's name")
        suite.expect(tracker.activity(now: at(3601), configuration: configuration)?.isLong == true,
                     "past an hour the clock asks for its wider slot")
        suite.expect(!tracker.apply(end("1-1", status: 0, at: 42), configuration: configuration, now: at(42)),
                     "an ended command's files go")
        suite.expect(tracker.activity(now: at(43), configuration: configuration)
                        == .finished(id: "1-1", program: "./build.sh", folder: nil, duration: 42, succeeded: true),
                     "the result shows with the total time")
        suite.expect(tracker.nextChange(after: at(43), configuration: configuration) == at(48),
                     "and is due to leave after 6 seconds")
        suite.expect(tracker.activity(now: at(48), configuration: configuration) == nil, "then it clears")
        tracker.removeStale(now: at(48), isAlive: { _ in true })
        suite.expect(tracker.finished == nil, "a spent result is dropped")

        var quick = Support.Tracker()
        quick.apply(start("2-1", "make", at: 0), configuration: configuration, now: at(0))
        quick.apply(end("2-1", status: 2, at: 5), configuration: configuration, now: at(5))
        suite.expect(quick.activity(now: at(5), configuration: configuration) == nil && quick.running.isEmpty,
                     "a command that ends before the threshold never shows, not even its result")

        var failed = Support.Tracker()
        failed.apply(start("3-1", "npm run build", at: 0), configuration: configuration, now: at(0))
        failed.apply(end("3-1", status: 1, at: 30), configuration: configuration, now: at(30))
        if case .finished(_, _, _, _, let succeeded)? = failed.activity(now: at(31), configuration: configuration) {
            suite.expect(!succeeded, "a non-zero status is a failure")
        } else {
            suite.expect(false, "a failed command shows its result")
        }

        var late = Support.Tracker()
        late.apply(start("4-1", "make", at: 0), configuration: configuration, now: at(0))
        late.apply(end("4-1", status: 0, at: 30), configuration: configuration, now: at(300))
        suite.expect(late.activity(now: at(300), configuration: configuration) == nil,
                     "an end read long after it happened is not news")

        var ignored = Support.Tracker()
        suite.expect(!ignored.apply(start("5-1", "vim notes.md", at: 0), configuration: configuration, now: at(0))
                     && ignored.running.isEmpty && ignored.activity(now: at(100), configuration: configuration) == nil,
                     "an ignored command is never tracked and its file goes at once")
        suite.expect(!ignored.apply(end("9-9", status: 0, at: 3), configuration: configuration, now: at(3)),
                     "an end whose start is unknown is dropped")
    }

    // MARK: Several terminals

    private static func multipleTerminals(_ suite: TestSuite) {
        let configuration = Support.Configuration(threshold: 5)
        var tracker = Support.Tracker()
        tracker.apply(start("100-1", "./build.sh --test", at: 0, pid: 100), configuration: configuration, now: at(0))
        tracker.apply(start("200-1", "docker build .", at: 3, pid: 200), configuration: configuration, now: at(3))
        tracker.apply(start("300-1", "vim x", at: 4, pid: 300), configuration: configuration, now: at(4))
        suite.expect(tracker.running.count == 2, "each terminal's command is tracked, ignored ones aside")
        suite.expect(tracker.apply(start("100-1", "./build.sh --test", at: 0, pid: 100), configuration: configuration,
                                   now: at(6)) && tracker.running.count == 2,
                     "reading a start again changes nothing")
        if case .running(let id, _, _, _, let others, _)? = tracker.activity(now: at(6), configuration: configuration) {
            suite.expect(id == "100-1" && others == 0, "only the commands past the threshold count")
        } else { suite.expect(false, "a command past the threshold shows") }
        if case .running(let id, _, _, _, let others, _)? = tracker.activity(now: at(9), configuration: configuration) {
            suite.expect(id == "100-1" && others == 1, "the first one keeps its place while another joins (+1)")
        } else { suite.expect(false, "two commands show as one with a count") }
        suite.expect(tracker.activity(now: at(9), configuration: configuration).map(Support.detail) == "./build.sh +1"
                     && tracker.activity(now: at(9), configuration: Support.Configuration(threshold: 5, showsFolder: true))
                        .map(Support.detail) == "./build.sh +1 · zenith",
                     "the count follows the program, then the folder when asked for")
        tracker.apply(end("100-1", status: 0, at: 20), configuration: configuration, now: at(20))
        suite.expect(tracker.activity(now: at(21), configuration: configuration)?.id == "100-1"
                     && tracker.activity(now: at(21), configuration: configuration)?.isRunning == false,
                     "the one that ended says so first")
        suite.expect(tracker.activity(now: at(26), configuration: configuration)?.id == "200-1"
                     && tracker.activity(now: at(26), configuration: configuration)?.isRunning == true,
                     "then the other terminal's command shows again")
    }

    // MARK: Stale cleanup

    private static func staleCleanup(_ suite: TestSuite) {
        let configuration = Support.Configuration()
        var tracker = Support.Tracker()
        tracker.apply(start("10-1", "make", at: 0, pid: 10), configuration: configuration, now: at(0))
        tracker.apply(start("11-1", "make", at: 0, pid: 11), configuration: configuration, now: at(0))
        tracker.apply(start("12-1", "make", at: 0, pid: nil), configuration: configuration, now: at(0))
        let gone = tracker.removeStale(now: at(60), isAlive: { $0 != 11 })
        suite.expect(gone == ["11-1"] && tracker.running.count == 2, "a command whose shell closed is dropped")
        suite.expect(tracker.removeStale(now: at(12 * 3600 - 1), isAlive: { _ in true }).isEmpty,
                     "a long command is kept while its shell lives")
        suite.expect(tracker.removeStale(now: at(12 * 3600), isAlive: { _ in true }) == ["10-1", "12-1"]
                     && tracker.running.isEmpty,
                     "after 12 hours a command is stale, as from a crashed shell")
        var old = Support.Tracker()
        suite.expect(!old.apply(start("13-1", "make", at: 0), configuration: configuration, now: at(13 * 3600)),
                     "a start file older than 12 hours is never tracked")
    }

    // MARK: The hook

    private static let folder = "/Users/me/Library/Application Support/id.satuvisual.zenith/Commands"

    private static func hookBlock(_ suite: TestSuite) {
        let block = Support.hookBlock(folder: folder)
        let lines = block.components(separatedBy: "\n")
        suite.expect(lines.first == Support.beginMarker && lines.dropLast().last == Support.endMarker
                     && block.hasSuffix("\n"),
                     "the block is marked at both ends")
        suite.expect(block.contains("_zenith_cmd_dir='\(folder)'"), "the folder is passed in, quoted")
        suite.expect(Support.hookBlock(folder: "/tmp/it's here").contains(#"'/tmp/it'\''s here'"#),
                     "a quote in the folder stays quoted")
        suite.expect(Support.shellUnquoted(Support.shellQuoted("/a b/it's")) == "/a b/it's",
                     "a quoted folder reads back")
        for piece in ["add-zsh-hook preexec", "precmd_functions=(_zenith_cmd_precmd", "zf_mv -f", ">|", "2>/dev/null",
                      "[[ -o interactive ]]", "$1 != [[:space:]]*", "EPOCHREALTIME", "local s=$?"] {
            suite.expect(block.contains(piece), "the hook uses \(piece)")
        }
        // No external program runs on each command: no command substitution
        // (the one `$((` is arithmetic), no backticks, no /bin/mv.
        suite.expect(block.components(separatedBy: "$(").count == block.components(separatedBy: "$((").count
                     && !block.contains("`") && !block.contains("/bin/mv") && !block.contains(" mv "),
                     "the hook runs builtins only")
    }

    private static func zshrcText(_ suite: TestSuite) {
        let block = Support.hookBlock(folder: folder)
        let original = "export PATH=\"$HOME/bin:$PATH\"\nalias gs='git status'\n"
        guard let installed = Support.installingHook(block, into: original) else {
            suite.expect(false, "the block installs into a plain .zshrc"); return
        }
        suite.expect(installed.hasPrefix(original) && installed.hasSuffix(block) && installed.contains("\n\n" + Support.beginMarker),
                     "the block is appended after a blank line; the rest stays")
        suite.expect(Support.installingHook(block, into: installed) == installed, "installing again changes nothing")
        suite.expect(Support.hookState(in: installed) == .installed(folder: folder)
                     && Support.hookState(in: original) == .missing,
                     "the status reads the installed folder")
        suite.expect(Support.removingHook(from: installed) == original, "removing restores the file exactly")
        suite.expect(Support.removingHook(from: original) == original, "removing without a block changes nothing")

        let other = Support.hookBlock(folder: "/elsewhere/Commands")
        let middle = "# top\n\n" + other + "\n# after\nsetopt autocd\n"
        let moved = Support.installingHook(block, into: middle)
        suite.expect(moved == "# top\n\n" + block + "\n# after\nsetopt autocd\n",
                     "another build's block is replaced in place, the lines around it kept")
        suite.expect(Support.removingHook(from: moved ?? "") == "# top\n\n# after\nsetopt autocd\n",
                     "removing from the middle keeps what follows")
        let twice = Support.installingHook(block, into: middle + "\n" + other)
        suite.expect(twice.map { $0.components(separatedBy: Support.beginMarker).count - 1 } == 1,
                     "two blocks become one")

        suite.expect(Support.installingHook(block, into: "") == block, "an empty file gets just the block")
        suite.expect(Support.removingHook(from: block) == "", "and loses it again")
        suite.expect(Support.installingHook(block, into: "no newline") == "no newline\n\n" + block,
                     "a file without a final newline gets one before the block")

        let damaged = "a\n" + Support.beginMarker + "\nb\n"
        suite.expect(Support.hookState(in: damaged) == .damaged && Support.installingHook(block, into: damaged) == nil
                     && Support.removingHook(from: damaged) == nil,
                     "an unfinished block is never guessed at")
        suite.expect(Support.hookState(in: "x\n" + Support.endMarker + "\n") == .damaged, "a lone end marker too")
    }

    /// On temporary files only; the real ~/.zshrc is never touched.
    private static func zshrcFile(_ suite: TestSuite) {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent("zenith-zshrc-\(UUID().uuidString)", isDirectory: true)
        defer { try? manager.removeItem(at: root) }
        guard (try? manager.createDirectory(at: root, withIntermediateDirectories: true)) != nil else {
            suite.expect(false, "a temporary folder for the .zshrc tests"); return
        }
        let real = manager.homeDirectoryForCurrentUser.appendingPathComponent(".zshrc").standardizedFileURL.path
        let block = Support.hookBlock(folder: folder)

        let rc = root.appendingPathComponent("zshrc")
        suite.expect(rc.standardizedFileURL.path != real, "the test file is not the real ~/.zshrc")
        let original = "# mine\nalias ll='ls -la'\n"
        try? Data(original.utf8).write(to: rc)
        try? manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: rc.path)
        suite.expect(Support.editHook(at: rc, install: block) == .changed, "installing writes the file")
        suite.expect(Support.editHook(at: rc, install: block) == .unchanged, "installing twice leaves it alone")
        let text = (try? String(contentsOf: rc, encoding: .utf8)) ?? ""
        suite.expect(text.hasPrefix(original) && Support.hookState(in: text) == .installed(folder: folder),
                     "the file holds the old content and the block")
        let mode = (try? manager.attributesOfItem(atPath: rc.path))?[.posixPermissions] as? NSNumber
        suite.expect(mode?.intValue == 0o600, "the file keeps its permissions")
        suite.expect(Support.editHook(at: rc, install: nil) == .changed
                     && (try? String(contentsOf: rc, encoding: .utf8)) == original,
                     "removing gives the original back")
        suite.expect(Support.editHook(at: rc, install: nil) == .unchanged, "removing twice leaves it alone")

        // A dotfile manager's link: the target changes, the link stays a link.
        let target = root.appendingPathComponent("dotfiles-zshrc")
        let link = root.appendingPathComponent("linked-zshrc")
        try? Data(original.utf8).write(to: target)
        try? manager.createSymbolicLink(at: link, withDestinationURL: target)
        suite.expect(Support.editHook(at: link, install: block) == .changed, "a linked file is edited")
        let linkKind = (try? manager.attributesOfItem(atPath: link.path))?[.type] as? FileAttributeType
        suite.expect(linkKind == .typeSymbolicLink
                     && Support.hookState(in: (try? String(contentsOf: target, encoding: .utf8)) ?? "") != .missing,
                     "through its link, which stays a link")

        let missing = root.appendingPathComponent("absent-zshrc")
        suite.expect(Support.editHook(at: missing, install: nil) == .unchanged
                     && !manager.fileExists(atPath: missing.path),
                     "removing from a missing file creates nothing")
        suite.expect(Support.editHook(at: missing, install: block) == .changed
                     && (try? String(contentsOf: missing, encoding: .utf8)) == block,
                     "installing into a missing file creates it with the block")

        let damaged = root.appendingPathComponent("damaged-zshrc")
        let broken = "a\n" + Support.beginMarker + "\n"
        try? Data(broken.utf8).write(to: damaged)
        suite.expect(Support.editHook(at: damaged, install: block) == .damaged
                     && (try? String(contentsOf: damaged, encoding: .utf8)) == broken,
                     "a damaged file is left exactly as it was")
    }

    // MARK: Island

    private static func island(_ suite: TestSuite) {
        suite.expect(NotchSupport.compactActivities(timer: false, downloads: true, agents: true, calendar: true,
                                                   music: true, vercel: true, command: true)
                        == [.downloads, .agents, .vercel, .command, .calendar, .music]
                     && NotchSupport.compactActivity(timer: false, downloads: false, music: true, command: true) == .command,
                     "a terminal command follows Vercel and comes before an event and music")
        suite.expect(!NotchSupport.compactActivities(timer: false, downloads: false, agents: false, calendar: false,
                                                    music: false).contains(.command),
                     "no command, no activity")
        suite.expect(NotchCompactActivity.command.module == .controls && NotchCompactActivity.command.symbol == "terminal"
                     && NotchCompactActivity.command.title(.enUS) == "Terminal",
                     "the command has no page of its own and opens the island home")
        for language in AppLanguage.allCases {
            let text = ZenithStrings.commandActivity(language)
            suite.expect(text.seconds.contains("%d") && text.lastEvent.contains("%@")
                         && ![text.toggle, text.section, text.install, text.remove, text.copy].contains { $0.isEmpty },
                         "\(language.rawValue) has the command activity's text")
        }
    }
}
