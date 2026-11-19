// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: a long-running terminal command in the closed island.
///
/// A small zsh hook (`hookBlock`) writes one JSON file when a command starts
/// and one when it ends into `<container>/Commands/`. The app watches that
/// folder (CommandActivityService), and everything it decides lives here:
/// reading the files, naming the program without its arguments, which
/// programs never end on their own and stay out, when a command has run long
/// enough to show, how long its result stays, and when a command is stale.
///
/// Privacy: the island only ever shows the program (`npm run build` is
/// `npm`), and the folder's name only when asked. Arguments can hold secrets,
/// so they are read once to pick the program and never kept.
enum CommandActivitySupport {
    static let symbol = "terminal"
    static let folderName = "Commands"
    /// Seconds a command runs before the island shows it.
    static let thresholds = [5, 8, 15, 30]
    static let defaultThreshold = 8
    /// How long the ✓ or ✗ stays once a command ends.
    static let resultDuration: TimeInterval = 6
    /// A command still running after this long belongs to a shell that died.
    static let staleAge: TimeInterval = 12 * 3600
    /// While something runs, how often the shells behind it are looked at.
    static let livenessInterval: TimeInterval = 30
    /// A half-written temporary file older than this was left by a crash.
    static let orphanAge: TimeInterval = 60
    /// From an hour on the clock reads h:mm:ss and needs a wider slot.
    static let longClock: TimeInterval = 3600
    static let maxFileSize = 4096
    static let maxProgramLength = 32
    static let maxFolderLength = 40

    // MARK: Preferences

    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: DefaultsKey.notchCommandActivity)
    }

    static func threshold(in defaults: UserDefaults = .standard) -> Int {
        let stored = defaults.integer(forKey: DefaultsKey.notchCommandThreshold)
        return thresholds.contains(stored) ? stored : defaultThreshold
    }

    static func configuration(in defaults: UserDefaults = .standard) -> Configuration {
        Configuration(threshold: TimeInterval(threshold(in: defaults)),
                      showsFolder: defaults.bool(forKey: DefaultsKey.notchCommandShowsFolder),
                      extraIgnored: extraIgnored(defaults.string(forKey: DefaultsKey.notchCommandIgnored) ?? ""))
    }

    /// The person's own additions to the ignore list: program names parted
    /// by commas or spaces, compared by name without a path.
    static func extraIgnored(_ stored: String) -> Set<String> {
        Set(stored.split(whereSeparator: { $0 == "," || $0.isWhitespace })
            .map { baseName(String($0)) }.filter { !$0.isEmpty })
    }

    struct Configuration: Equatable, Sendable {
        var threshold: TimeInterval = TimeInterval(CommandActivitySupport.defaultThreshold)
        var showsFolder = false
        var extraIgnored: Set<String> = []
    }

    // MARK: Events

    /// One file the hook wrote: a command starting, or one ending.
    struct Event: Equatable, Sendable {
        enum Phase: String, Sendable { case start, end }
        let id: String
        let phase: Phase
        /// When it started or ended.
        let time: Date
        var pid: Int32?
        var tty: String?
        /// Start only: the command line, read once to name the program.
        var command: String?
        /// Start only: the working folder's name.
        var folder: String?
        /// End only: the exit status.
        var status: Int32?
    }

    /// Reads one event file. Anything partial, oversized or of another shape
    /// is nil, and the caller deletes it.
    static func parse(_ data: Data) -> Event? {
        guard !data.isEmpty, data.count <= maxFileSize,
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let id = object["id"] as? String, isValidID(id) else { return nil }
        let pid = integer(object["pid"]).flatMap { $0 > 0 && $0 <= Int(Int32.max) ? Int32($0) : nil }
        if let start = timestamp(object["start"]) {
            guard let command = object["cmd"] as? String,
                  !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return Event(id: id, phase: .start, time: start, pid: pid,
                         tty: (object["tty"] as? String).flatMap { $0.isEmpty ? nil : String($0.prefix(32)) },
                         command: String(command.prefix(1024)),
                         folder: (object["cwd"] as? String).flatMap(sanitizedFolder))
        }
        if let end = timestamp(object["end"]), let status = integer(object["status"]),
           status >= Int(Int32.min), status <= Int(Int32.max) {
            return Event(id: id, phase: .end, time: end, pid: pid, status: Int32(status))
        }
        return nil
    }

    /// The hook's ids are the shell's pid and a counter, `4242-17`.
    static func isValidID(_ id: String) -> Bool {
        let parts = id.split(separator: "-", omittingEmptySubsequences: false)
        return id.count <= 40 && parts.count == 2
            && parts.allSatisfy { !$0.isEmpty && $0.allSatisfy { $0.isASCII && $0.isNumber } }
    }

    private static func number(_ value: Any?) -> NSNumber? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        return number
    }

    private static func integer(_ value: Any?) -> Int? {
        guard let double = number(value)?.doubleValue, double.isFinite, double == double.rounded(),
              abs(double) < 1e15 else { return nil }
        return Int(double)
    }

    /// Seconds since 1970 from the shell's `$EPOCHREALTIME`, after 2001.
    private static func timestamp(_ value: Any?) -> Date? {
        guard let seconds = number(value)?.doubleValue, seconds.isFinite,
              seconds > 1_000_000_000, seconds < 10_000_000_000 else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    // MARK: Files

    enum FileKind: Equatable {
        case event(id: String, phase: Event.Phase)
        /// The hook's half-written file, renamed into place a moment later.
        case temporary
        /// Anything else, which the folder never needs.
        case foreign
    }

    static func fileName(id: String, phase: Event.Phase) -> String { "\(id).\(phase.rawValue).json" }

    static func kind(ofFile name: String) -> FileKind {
        if name.hasSuffix(".tmp") { return .temporary }
        guard name.hasSuffix(".json") else { return .foreign }
        let parts = name.dropLast(5).split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2, let phase = Event.Phase(rawValue: String(parts[1])),
              isValidID(String(parts[0])) else { return .foreign }
        return .event(id: String(parts[0]), phase: phase)
    }

    /// A temporary or unknown file goes once it is clearly left over; an
    /// event file is read, then kept or deleted by the tracker.
    static func removesLeftover(_ kind: FileKind, age: TimeInterval) -> Bool {
        switch kind {
        case .event: return false
        case .temporary, .foreign: return age > orphanAge
        }
    }

    /// Starts before ends, each in the order they happened, so a command that
    /// started and ended between two looks is followed through.
    static func ordered(_ events: [Event]) -> [Event] {
        events.sorted { lhs, rhs in
            if lhs.phase != rhs.phase { return lhs.phase == .start }
            return lhs.time != rhs.time ? lhs.time < rhs.time : lhs.id < rhs.id
        }
    }

    // MARK: Program

    /// The command that names a line: its program and what follows it.
    struct Invocation: Equatable {
        /// As typed: `./build.sh`, `/usr/bin/make`, `npm`.
        let program: String
        let arguments: [String]
        /// Only a wrapper with nothing after it, like `sudo -s` or `caffeinate`.
        var bare = false
    }

    /// The part of a line worth naming. Of `cd app && npm run build` that is
    /// npm: setup in front (cd, export, source) is passed over.
    static func invocation(of command: String) -> Invocation? {
        var first: Invocation?
        for segment in segments(words(command)) {
            guard let invocation = segmentInvocation(segment) else { continue }
            if first == nil { first = invocation }
            if !preludes.contains(baseName(invocation.program)) { return invocation }
        }
        return first
    }

    /// The program's name as the island shows it, never an argument: a
    /// script run from here keeps its `./`, anything else loses its path.
    static func displayName(_ program: String) -> String? {
        let name = program.hasPrefix("./") && !program.dropFirst(2).contains("/") && program.count > 2
            ? program : baseName(program)
        let clean = String(name.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) })
            .trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty, !isAssignment(clean) else { return nil }
        return clean.count > maxProgramLength ? String(clean.prefix(maxProgramLength - 1)) + "…" : clean
    }

    /// The name the island shows for a whole line, or nil when it names nothing.
    static func program(of command: String) -> String? {
        invocation(of: command).flatMap { displayName($0.program) }
    }

    static func baseName(_ word: String) -> String {
        let trimmed = word.hasSuffix("/") ? String(word.dropLast()) : word
        return trimmed.split(separator: "/").last.map(String.init) ?? ""
    }

    static func sanitizedFolder(_ name: String) -> String? {
        let clean = String(name.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) })
            .trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty, clean != "/" else { return nil }
        return clean.count > maxFolderLength ? String(clean.prefix(maxFolderLength - 1)) + "…" : clean
    }

    /// Setup that comes before the real work on a line.
    static let preludes: Set<String> = [
        "cd", "pushd", "popd", "export", "unset", "set", "setopt", "echo", "print", "printf", "true", "false",
        "clear", "source", ".", "local", "typeset", "declare", "alias", "eval", "test", "[", "[[", "sleep", "rm",
        "mkdir", "touch",
    ]

    private static let operators: Set<String> = [";", "&&", "||", "|", "|&", "&", "(", ")", "{", "}", "!", "\n"]

    /// Shell words, quotes and escapes resolved, with control operators as
    /// words of their own. Bounded: only the front of a line is ever needed.
    static func words(_ line: String, limit: Int = 48) -> [String] {
        var words: [String] = []
        var current = ""
        var inWord = false
        var quote: Character?
        var escaping = false
        var characters = Array(line.prefix(1024))
        characters.append(" ")
        var index = 0
        func flush() {
            if inWord { words.append(current) }
            current = ""
            inWord = false
        }
        while index < characters.count, words.count < limit {
            let character = characters[index]
            index += 1
            if escaping { current.append(character); inWord = true; escaping = false; continue }
            if let open = quote {
                if character == open { quote = nil }
                else if character == "\\" && open == "\"" { escaping = true }
                else { current.append(character) }
                continue
            }
            switch character {
            case "\\": escaping = true; inWord = true
            case "'", "\"": quote = character; inWord = true
            case " ", "\t": flush()
            case "\n", ";", "(", ")", "{", "}":
                flush()
                words.append(String(character))
            case "&", "|":
                flush()
                var symbol = String(character)
                if index < characters.count, characters[index] == character || (character == "|" && characters[index] == "&") {
                    symbol.append(characters[index])
                    index += 1
                }
                words.append(symbol)
            default:
                current.append(character)
                inWord = true
            }
        }
        return words
    }

    static func segments(_ words: [String]) -> [[String]] {
        var segments: [[String]] = [[]]
        for word in words {
            if operators.contains(word) { if !(segments.last?.isEmpty ?? true) { segments.append([]) } }
            else { segments[segments.count - 1].append(word) }
        }
        return segments.filter { !$0.isEmpty }
    }

    static func isAssignment(_ word: String) -> Bool {
        guard let equals = word.firstIndex(of: "="), equals != word.startIndex else { return false }
        let name = word[..<equals]
        return name.first.map { $0 == "_" || $0.isLetter } == true
            && name.allSatisfy { $0 == "_" || ($0.isASCII && ($0.isLetter || $0.isNumber)) }
    }

    /// Wrappers that run another program, with their options that take a value.
    private static let wrappers: [String: Set<String>] = [
        "sudo": ["-u", "-g", "-h", "-p", "-C", "-D", "-R", "-T", "-U", "--user", "--group", "--host", "--prompt"],
        "doas": ["-u", "-C"],
        "env": ["-u", "-C", "-S", "-P", "--unset", "--chdir"],
        "nice": ["-n"],
        "nohup": [], "time": [], "command": [], "builtin": [], "exec": ["-a"], "noglob": [], "nocorrect": [],
        "caffeinate": ["-t", "-w"],
        "timeout": ["-s", "-k", "--signal", "--kill-after"],
        "gtimeout": ["-s", "-k", "--signal", "--kill-after"],
        "xcrun": ["--sdk", "--toolchain"],
        "arch": [],
    ]

    private static func segmentInvocation(_ words: [String]) -> Invocation? {
        var index = 0
        var wrapper: String?
        while index < words.count {
            let word = words[index]
            if isAssignment(word) { index += 1; continue }
            let name = baseName(word)
            guard let valued = wrappers[name] else {
                return Invocation(program: word, arguments: Array(words[(index + 1)...]))
            }
            wrapper = word
            index += 1
            while index < words.count {
                let option = words[index]
                if option == "--" { index += 1; break }
                if name == "env", isAssignment(option) { index += 1; continue }
                guard option.hasPrefix("-"), option.count > 1 else { break }
                index += valued.contains(option) ? 2 : 1
            }
            // timeout's first word is the duration.
            if name == "timeout" || name == "gtimeout" { index += 1 }
        }
        return wrapper.map { Invocation(program: $0, arguments: [], bare: true) }
    }

    // MARK: Ignore list

    /// Editors, pagers, remote and full-screen programs, chat agents and
    /// interactive database shells: they wait on the person, not the other
    /// way round, so they never show.
    static let interactivePrograms: Set<String> = [
        "vi", "vim", "nvim", "gvim", "mvim", "view", "vimdiff", "nano", "pico", "emacs", "emacsclient", "micro",
        "hx", "helix", "kak", "joe", "ne", "less", "more", "most", "man", "info", "ssh", "mosh", "telnet", "sftp",
        "ftp", "top", "htop", "btop", "atop", "glances", "nvtop", "watch", "tmux", "screen", "zellij", "byobu",
        "claude", "codex", "aider", "gemini", "opencode", "copilot", "cursor-agent", "fzf", "lazygit",
        "lazydocker", "tig", "gitui", "ranger", "yazi", "nnn", "lf", "mc", "k9s", "ncdu", "psql", "mysql",
        "sqlite3", "redis-cli", "mongosh", "mongo", "irb", "pry", "ipython", "bpython", "ptpython", "iex",
        "ghci", "jshell", "su", "login", "fg", "nodemon", "webpack-dev-server", "uvicorn", "gunicorn", "ngrok",
        "http-server", "live-server", "foreman", "overmind",
    ]

    /// Interactive when run with nothing to run: a REPL or a shell.
    static let replPrograms: Set<String> = [
        "python", "python3", "node", "deno", "bun", "ruby", "lua", "luajit", "R", "swift", "julia", "scala",
        "clj", "clojure", "php", "perl", "erl", "kotlin", "tclsh", "bc", "dc", "bash", "zsh", "sh", "fish",
        "nu", "elixir", "ocaml", "racket", "guile", "cat",
    ]

    /// Package scripts that start a server or a watcher.
    private static let serverScripts: Set<String> = ["dev", "start", "serve", "watch", "preview", "storybook"]

    static func isIgnored(_ command: String, extra: Set<String> = []) -> Bool {
        guard let invocation = invocation(of: command) else { return true }
        return isIgnored(invocation, extra: extra)
    }

    static func isIgnored(_ invocation: Invocation, extra: Set<String> = []) -> Bool {
        if invocation.bare { return true }
        let name = baseName(invocation.program)
        if extra.contains(name) || interactivePrograms.contains(name) { return true }
        let arguments = invocation.arguments
        let operands = arguments.filter { !$0.hasPrefix("-") }
        if replPrograms.contains(name) {
            if operands.isEmpty || operands.first == "repl" || arguments.contains("-i") { return true }
        }
        return neverEnds(name, arguments: arguments, operands: operands, extra: extra)
    }

    /// A short flag group such as `-fn` that holds `letter`.
    private static func hasFlag(_ arguments: [String], _ letter: Character, long: String? = nil) -> Bool {
        arguments.contains { argument in
            if let long, argument == long || argument.hasPrefix(long + "=") { return true }
            return argument.hasPrefix("-") && !argument.hasPrefix("--") && argument.dropFirst().contains(letter)
        }
    }

    private static func interactiveContainer(_ arguments: [String]) -> Bool {
        hasFlag(arguments, "i", long: "--interactive") || hasFlag(arguments, "t", long: "--tty")
    }

    private static func neverEnds(_ name: String, arguments: [String], operands: [String],
                                  extra: Set<String>) -> Bool {
        let first = operands.first
        let second = operands.dropFirst().first
        switch name {
        case "tail": return hasFlag(arguments, "f", long: "--follow") || hasFlag(arguments, "F")
        case "journalctl", "stern": return hasFlag(arguments, "f", long: "--follow") || name == "stern"
        case "log": return first == "stream"
        case "ping": return !arguments.contains { $0.hasPrefix("-c") }
        case "git": return ["log", "diff", "show", "blame", "reflog", "help"].contains(first ?? "")
        case "docker", "podman":
            if first == "compose" { return second == "up" && !hasFlag(arguments, "d", long: "--detach") }
            if first == "logs" { return hasFlag(arguments, "f", long: "--follow") }
            if first == "run" || first == "exec" { return interactiveContainer(arguments) }
            return first == "attach" || first == "stats" || first == "events"
        case "docker-compose", "podman-compose":
            return first == "up" && !hasFlag(arguments, "d", long: "--detach")
        case "kubectl", "oc":
            if first == "logs" { return hasFlag(arguments, "f", long: "--follow") }
            if first == "exec" || first == "run" { return interactiveContainer(arguments) }
            if first == "get" { return hasFlag(arguments, "w", long: "--watch") }
            return ["port-forward", "proxy", "attach", "edit"].contains(first ?? "")
        case "npm", "pnpm", "yarn", "bun":
            // `npm start`, `npm run dev`, `pnpm dev`, `yarn dev:web`.
            guard let script = ["run", "run-script"].contains(first ?? "") ? second : first else { return false }
            return serverScripts.contains(String(script.prefix(while: { $0 != ":" })))
        case "npx", "pnpx", "bunx":
            guard let index = arguments.firstIndex(where: { !$0.hasPrefix("-") }) else { return false }
            return isIgnored(Invocation(program: arguments[index], arguments: Array(arguments[(index + 1)...])),
                             extra: extra)
        case "bundle":
            guard first == "exec", let index = arguments.firstIndex(of: "exec"), index + 1 < arguments.count else {
                return false
            }
            return isIgnored(Invocation(program: arguments[index + 1], arguments: Array(arguments[(index + 2)...])),
                             extra: extra)
        case "next", "nuxt", "nuxi", "astro", "remix", "wrangler", "netlify", "turbo", "expo", "vercel", "ng",
             "react-native", "gatsby", "svelte-kit", "eleventy", "parcel":
            return ["dev", "start", "serve", "develop", "watch"].contains(first ?? "")
        case "vite": return first == nil || ["dev", "serve", "preview"].contains(first ?? "")
        case "vitest": return first == nil || first == "watch" || first == "dev"
        case "jest": return arguments.contains("--watch") || arguments.contains("--watchAll")
        case "tsc": return hasFlag(arguments, "w", long: "--watch")
        case "webpack": return first == "serve" || arguments.contains("--watch")
        case "rails": return ["server", "s", "console", "c", "dbconsole"].contains(first ?? "")
        case "php": return operands.contains("artisan") && (operands.contains("serve") || operands.contains("tinker"))
        case "hugo": return first == "server" || first == "serve"
        case "jekyll", "mkdocs": return first == "serve"
        case "flask": return first == "run" || first == "shell"
        case "cargo": return first == "watch"
        case "python", "python3":
            if let module = arguments.firstIndex(of: "-m"), module + 1 < arguments.count {
                return ["http.server", "pdb", "asyncio"].contains(arguments[module + 1])
            }
            return operands.contains("runserver") || operands.contains("shell")
        case "firebase": return first?.hasPrefix("emulators") == true || first == "serve"
        case "ollama": return first == "run" || first == "serve"
        default: return false
        }
    }

    // MARK: Tracking

    struct Running: Equatable, Sendable {
        let id: String
        let pid: Int32?
        let start: Date
        let program: String
        let folder: String?
    }

    struct Finished: Equatable, Sendable {
        let id: String
        let program: String
        let folder: String?
        let start: Date
        let end: Date
        let succeeded: Bool
        var duration: TimeInterval { max(0, end.timeIntervalSince(start)) }
    }

    /// What the closed island shows.
    enum Activity: Equatable, Sendable {
        /// The longest-running command shown, with how many more run beside it.
        case running(id: String, program: String, folder: String?, start: Date, others: Int, long: Bool)
        case finished(id: String, program: String, folder: String?, duration: TimeInterval, succeeded: Bool)

        var id: String {
            switch self {
            case .running(let id, _, _, _, _, _), .finished(let id, _, _, _, _): return id
            }
        }

        var program: String {
            switch self {
            case .running(_, let program, _, _, _, _), .finished(_, let program, _, _, _): return program
            }
        }

        var folder: String? {
            switch self {
            case .running(_, _, let folder, _, _, _), .finished(_, _, let folder, _, _): return folder
            }
        }

        /// The clock needs room for hours.
        var isLong: Bool {
            switch self {
            case .running(_, _, _, _, _, let long): return long
            case .finished(_, _, _, let duration, _): return duration >= CommandActivitySupport.longClock
            }
        }

        var isRunning: Bool {
            if case .running = self { return true }
            return false
        }
    }

    /// The text right of the camera: the program, how many more run beside
    /// it, and its folder when asked for: `npm +1 · zenith`.
    static func detail(_ activity: Activity) -> String {
        var text = activity.program
        if case .running(_, _, _, _, let others, _) = activity, others > 0 { text += " +\(others)" }
        if let folder = activity.folder { text += " · " + folder }
        return text
    }

    /// The commands running in every terminal, and the one that just ended.
    struct Tracker: Equatable, Sendable {
        private(set) var running: [String: Running] = [:]
        private(set) var finished: Finished?

        init() {}

        /// Applies one event. True keeps its file: a running command's start,
        /// so a restarted app still knows it. Everything else is done with.
        @discardableResult
        mutating func apply(_ event: Event, configuration: Configuration, now: Date) -> Bool {
            switch event.phase {
            case .start:
                if running[event.id] != nil { return true }
                guard now.timeIntervalSince(event.time) < staleAge, let command = event.command,
                      let invocation = invocation(of: command),
                      !isIgnored(invocation, extra: configuration.extraIgnored),
                      let program = displayName(invocation.program) else { return false }
                running[event.id] = Running(id: event.id, pid: event.pid, start: event.time, program: program,
                                            folder: event.folder)
                return true
            case .end:
                guard let run = running.removeValue(forKey: event.id) else { return false }
                let result = Finished(id: run.id, program: run.program, folder: run.folder, start: run.start,
                                      end: max(event.time, run.start), succeeded: event.status == 0)
                // Only a command that had shown says how it ended, and only while that is news.
                if result.duration >= configuration.threshold, now.timeIntervalSince(result.end) < resultDuration {
                    finished = result
                }
                return false
            }
        }

        /// Drops the commands whose shell is gone or that ran past `staleAge`,
        /// and a result whose moment has passed. Returns the dropped ids.
        @discardableResult
        mutating func removeStale(now: Date, isAlive: (Int32) -> Bool) -> [String] {
            if let finished, now.timeIntervalSince(finished.end) >= resultDuration { self.finished = nil }
            let stale = running.values.filter { run in
                now.timeIntervalSince(run.start) >= staleAge || run.pid.map { !isAlive($0) } == true
            }.map(\.id).sorted()
            stale.forEach { running.removeValue(forKey: $0) }
            return stale
        }

        func activity(now: Date, configuration: Configuration) -> Activity? {
            if let finished, now.timeIntervalSince(finished.end) < resultDuration {
                return .finished(id: finished.id, program: finished.program,
                                 folder: configuration.showsFolder ? finished.folder : nil,
                                 duration: finished.duration, succeeded: finished.succeeded)
            }
            let visible = running.values.filter { now.timeIntervalSince($0.start) >= configuration.threshold }
            // The one that started first stays put while others join it.
            guard let shown = visible.min(by: { $0.start != $1.start ? $0.start < $1.start : $0.id < $1.id })
            else { return nil }
            return .running(id: shown.id, program: shown.program,
                            folder: configuration.showsFolder ? shown.folder : nil, start: shown.start,
                            others: visible.count - 1, long: now.timeIntervalSince(shown.start) >= longClock)
        }

        /// The next moment the activity changes by itself: a command passing
        /// the threshold or the hour, or a result running out.
        func nextChange(after now: Date, configuration: Configuration) -> Date? {
            var moments: [Date] = []
            if let finished { moments.append(finished.end.addingTimeInterval(resultDuration)) }
            for run in running.values {
                moments.append(run.start.addingTimeInterval(configuration.threshold))
                moments.append(run.start.addingTimeInterval(longClock))
            }
            return moments.filter { $0 > now }.min()
        }
    }

    // MARK: Clock

    /// `0:42`, `3:05`, `1:02:10`.
    static func clock(_ seconds: TimeInterval) -> String {
        let total = seconds.isFinite ? max(0, Int(seconds.rounded(.down))) : 0
        let hours = total / 3600, minutes = total / 60 % 60, rest = total % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, rest)
            : String(format: "%d:%02d", minutes, rest)
    }

    /// The widest reading in the clock's slot, so its width never changes
    /// while it ticks.
    static func clockTemplate(long: Bool) -> String { long ? "00:00:00" : "00:00" }

    // MARK: Shell hook

    static let beginMarker = "# >>> zenith command activity >>>"
    static let endMarker = "# <<< zenith command activity <<<"
    private static let folderLinePrefix = "  typeset -g _zenith_cmd_dir="

    /// The block added to `~/.zshrc`. Builtins only, so a command costs no
    /// extra process: `print` writes a temporary file and `zf_mv` renames it
    /// into place, so the app never reads half a file. It prints nothing, a
    /// line typed with a leading space is skipped, and once the folder is
    /// gone (the feature is off) it does nothing but look for it.
    static func hookBlock(folder: String) -> String {
        """
        \(beginMarker)
        # Added by Zenith: tells the Dynamic Island when a command starts and
        # ends. Only the program name is shown. Remove it from Zenith settings
        # or delete this block. Lines typed with a leading space are skipped.
        if [[ -o interactive ]] && autoload -Uz add-zsh-hook 2>/dev/null \\
            && zmodload -F zsh/datetime p:EPOCHREALTIME 2>/dev/null \\
            && zmodload -F zsh/files b:zf_mv 2>/dev/null; then
        \(folderLinePrefix)\(shellQuoted(folder))
          typeset -g _zenith_cmd_id=${_zenith_cmd_id-}
          typeset -gi _zenith_cmd_n=${_zenith_cmd_n:-0}
          _zenith_cmd_write() {
            { print -rn -- "$2" >| "$_zenith_cmd_dir/$1.tmp" \\
                && zf_mv -f "$_zenith_cmd_dir/$1.tmp" "$_zenith_cmd_dir/$1.json" } 2>/dev/null
          }
          _zenith_cmd_preexec() {
            emulate -L zsh
            _zenith_cmd_id=
            [[ -d $_zenith_cmd_dir && $1 != [[:space:]]* ]] || return 0
            local c=${2[1,400]} d=${PWD:t}
            c=${c//\\\\/\\\\\\\\}; c=${c//\\"/\\\\\\"}; c=${c//[[:cntrl:]]/ }
            d=${d//\\\\/\\\\\\\\}; d=${d//\\"/\\\\\\"}; d=${d//[[:cntrl:]]/ }
            _zenith_cmd_id=$$-$(( ++_zenith_cmd_n ))
            _zenith_cmd_write $_zenith_cmd_id.start "{\\"id\\":\\"$_zenith_cmd_id\\",\\"pid\\":$$,\\"tty\\":\\"${TTY:t}\\",\\"start\\":$EPOCHREALTIME,\\"cmd\\":\\"$c\\",\\"cwd\\":\\"$d\\"}"
          }
          _zenith_cmd_precmd() {
            local s=$?
            [[ -n $_zenith_cmd_id ]] || return 0
            emulate -L zsh
            _zenith_cmd_write $_zenith_cmd_id.end "{\\"id\\":\\"$_zenith_cmd_id\\",\\"status\\":$s,\\"end\\":$EPOCHREALTIME}"
            _zenith_cmd_id=
          }
          add-zsh-hook preexec _zenith_cmd_preexec
          # First, so it reads the command's own exit status.
          precmd_functions=(_zenith_cmd_precmd ${precmd_functions:#_zenith_cmd_precmd})
        fi
        \(endMarker)

        """
    }

    /// Single-quoted for zsh, a quote inside closed and escaped.
    static func shellQuoted(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Reads a word written by `shellQuoted` (or any plain shell word).
    static func shellUnquoted(_ word: String) -> String {
        var result = ""
        var quoted = false
        var escaping = false
        for character in word {
            if escaping { result.append(character); escaping = false; continue }
            if quoted {
                if character == "'" { quoted = false } else { result.append(character) }
                continue
            }
            switch character {
            case "'": quoted = true
            case "\\": escaping = true
            default: result.append(character)
            }
        }
        return result
    }

    enum HookState: Equatable {
        case missing
        /// The folder the block writes to, nil when it cannot be read.
        case installed(folder: String?)
        /// A begin marker without its end, or the other way round.
        case damaged
    }

    /// The marked blocks' line ranges, or nil when a marker has no partner.
    private static func blockRanges(_ lines: [String]) -> [ClosedRange<Int>]? {
        var ranges: [ClosedRange<Int>] = []
        var open: Int?
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == beginMarker {
                if open != nil { return nil }
                open = index
            } else if trimmed == endMarker {
                guard let start = open else { return nil }
                ranges.append(start...index)
                open = nil
            }
        }
        return open == nil ? ranges : nil
    }

    static func hookState(in rc: String) -> HookState {
        let lines = rc.components(separatedBy: "\n")
        guard let ranges = blockRanges(lines) else { return .damaged }
        guard let block = ranges.first else { return .missing }
        let folder = lines[block].first { $0.hasPrefix(folderLinePrefix) }
            .map { shellUnquoted(String($0.dropFirst(folderLinePrefix.count))) }
        return .installed(folder: folder)
    }

    /// `rc` with `block` in it: the first marked block replaced, any other
    /// removed, or the block appended after a blank line. Everything else is
    /// kept as it was. Nil when a marker has lost its partner, so a file
    /// someone edited by hand is never guessed at.
    static func installingHook(_ block: String, into rc: String) -> String? {
        var lines = rc.components(separatedBy: "\n")
        guard let ranges = blockRanges(lines) else { return nil }
        let blockLines = block.hasSuffix("\n") ? block.dropLast().components(separatedBy: "\n")
            : block.components(separatedBy: "\n")
        guard let first = ranges.first else {
            var text = rc
            if !text.isEmpty, !text.hasSuffix("\n") { text += "\n" }
            if !text.isEmpty { text += "\n" }
            return text + blockLines.joined(separator: "\n") + "\n"
        }
        for range in ranges.dropFirst().reversed() { lines.removeSubrange(range) }
        lines.replaceSubrange(first, with: blockLines)
        return lines.joined(separator: "\n")
    }

    /// `rc` without the marked blocks and the blank line `installingHook`
    /// put before one. Nil when a marker has lost its partner.
    static func removingHook(from rc: String) -> String? {
        var lines = rc.components(separatedBy: "\n")
        guard let ranges = blockRanges(lines) else { return nil }
        for range in ranges.reversed() {
            var range = range
            if range.lowerBound > 0, lines[range.lowerBound - 1].trimmingCharacters(in: .whitespaces).isEmpty {
                range = (range.lowerBound - 1)...range.upperBound
            }
            lines.removeSubrange(range)
        }
        return lines.joined(separator: "\n")
    }

    enum HookEditResult: Equatable {
        case changed, unchanged, damaged, failed
    }

    /// Installs or removes the hook in the file at `url`, which is followed
    /// to its target when it is a link (dotfile managers link `~/.zshrc`),
    /// written atomically and left with the permissions it had.
    static func editHook(at url: URL, install block: String?) -> HookEditResult {
        let target = url.resolvingSymlinksInPath()
        let manager = FileManager.default
        let exists = manager.fileExists(atPath: target.path)
        let current: String
        if exists {
            guard let data = try? Data(contentsOf: target), let text = String(data: data, encoding: .utf8) else {
                return .failed
            }
            current = text
        } else {
            guard block != nil else { return .unchanged }
            current = ""
        }
        let edited = block.map { installingHook($0, into: current) } ?? removingHook(from: current)
        guard let edited else { return .damaged }
        guard edited != current else { return .unchanged }
        let permissions = (try? manager.attributesOfItem(atPath: target.path))?[.posixPermissions] as? NSNumber
        guard (try? Data(edited.utf8).write(to: target, options: .atomic)) != nil else { return .failed }
        try? manager.setAttributes([.posixPermissions: permissions ?? NSNumber(value: 0o644)],
                                   ofItemAtPath: target.path)
        return .changed
    }
}
