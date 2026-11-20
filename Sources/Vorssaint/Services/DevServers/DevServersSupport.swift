// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: dev servers in the island. The Port Manager's reader lists the
// TCP listeners (lsof, PortManagerService); DevServersProbe reads the process
// behind each one (its arguments, folder, owner and start); everything here
// decides what of it is a dev server and how it reads. Pure (Foundation only)
// and compiled into the tests: classification, naming, URLs, grouping,
// announcing with coalesced restarts, and the kill confirmation.

/// What a dev server runs on, as far as its process and command line tell.
enum DevServerKind: String, CaseIterable, Equatable {
    case next, vite, nuxt, astro, remix, webpack, bun, deno, node
    case laravel, php, pythonHTTP, uvicorn, flask, django, go, flutter, rails
    case supabase, docker
    /// A port or process name the person listed in Settings.
    case custom

    /// The framework's own name, never translated.
    var title: String {
        switch self {
        case .next: return "Next.js"
        case .vite: return "Vite"
        case .nuxt: return "Nuxt"
        case .astro: return "Astro"
        case .remix: return "Remix"
        case .webpack: return "webpack"
        case .bun: return "Bun"
        case .deno: return "Deno"
        case .node: return "Node.js"
        case .laravel: return "Laravel"
        case .php: return "PHP"
        case .pythonHTTP: return "Python"
        case .uvicorn: return "Uvicorn"
        case .flask: return "Flask"
        case .django: return "Django"
        case .go: return "Go"
        case .flutter: return "Flutter"
        case .rails: return "Rails"
        case .supabase: return "Supabase"
        case .docker: return "Docker"
        case .custom: return ""
        }
    }

    /// One or two letters on its tile. No brand marks: a monogram in the
    /// framework's tint reads at a glance and draws nobody's artwork.
    var monogram: String {
        switch self {
        case .next: return "N"
        case .vite: return "V"
        case .nuxt: return "Nu"
        case .astro: return "A"
        case .remix: return "Rx"
        case .webpack: return "W"
        case .bun: return "B"
        case .deno: return "D"
        case .node: return "JS"
        case .laravel: return "L"
        case .php: return "P"
        case .pythonHTTP: return "Py"
        case .uvicorn: return "Uv"
        case .flask: return "Fl"
        case .django: return "Dj"
        case .go: return "Go"
        case .flutter: return "F"
        case .rails: return "R"
        case .supabase: return "Sb"
        case .docker: return "Dk"
        case .custom: return ""
        }
    }

    /// sRGB 0xRRGGBB: the framework's own colour, pulled to the 300 and 400
    /// steps the island's palette uses so they read on its black.
    var hex: UInt32 {
        switch self {
        case .next: return 0xE5E7EB
        case .vite: return 0xA78BFA
        case .nuxt: return 0x34D399
        case .astro: return 0xFB923C
        case .remix: return 0x93C5FD
        case .webpack: return 0x7DD3FC
        case .bun: return 0xFDE68A
        case .deno: return 0xD1D5DB
        case .node: return 0x4ADE80
        case .laravel: return 0xF87171
        case .php: return 0xA5B4FC
        case .pythonHTTP: return 0xFACC15
        case .uvicorn: return 0x2DD4BF
        case .flask: return 0xCBD5E1
        case .django: return 0x86EFAC
        case .go: return 0x22D3EE
        case .flutter: return 0x38BDF8
        case .rails: return 0xFB7185
        case .supabase: return 0x6EE7B7
        case .docker: return 0x60A5FA
        case .custom: return 0x94A3B8
        }
    }

    /// Docker's backend forwards every container's port, so killing the
    /// process would stop Docker itself; those rows never offer Kill.
    var killable: Bool { self != .docker && self != .supabase }

    /// Each forwarded port is its own container, so Docker rows stay one per
    /// port; a process listening on several ports is one server.
    var groupsByProcess: Bool { self != .docker && self != .supabase }
}

/// The process behind a listener, as DevServersProbe reads it.
struct DevServerProcess: Equatable {
    var pid: Int32
    /// The command name lsof gives (`+c0`, so not cut at 16 characters).
    var name: String
    /// The executable's path, empty when the kernel did not give it.
    var path = ""
    /// argv, argv[0] first.
    var arguments: [String] = []
    /// Its current folder, the project for nearly every dev server.
    var cwd: String?
    var uid: UInt32?
    var parentPID: Int32 = 0
    var parentName = ""
    var startedAt: Date?
    /// The kernel start time in microseconds, the identity Kill checks.
    var startMicros: UInt64?
    /// A package.json, deno.json or bun lockfile in its folder.
    var hasProjectFile = false
}

/// Who is asking: the app's own process, the person's uid and home folder.
struct DevServersContext: Equatable {
    var ownPID: Int32
    var uid: UInt32
    var home: String

    static var current: DevServersContext {
        DevServersContext(ownPID: ProcessInfo.processInfo.processIdentifier, uid: getuid(),
                          home: FileManager.default.homeDirectoryForCurrentUser.path)
    }
}

/// Ports and process names the person also counts as dev servers.
struct DevServersExtras: Equatable {
    var ports: Set<Int> = []
    var names: Set<String> = []

    /// The most ports one range may add, so a typo cannot list half the machine.
    static let rangeLimit = 64

    init(ports: Set<Int> = [], names: Set<String> = []) {
        self.ports = ports
        self.names = names
    }

    init(ports text: String, names nameText: String) {
        self.init(ports: Self.ports(from: text), names: Self.names(from: nameText))
    }

    /// `3000, 8080 9000-9003`: numbers and ranges split by commas or spaces.
    static func ports(from text: String) -> Set<Int> {
        var result = Set<Int>()
        for token in text.split(whereSeparator: { $0 == "," || $0 == " " || $0 == ";" || $0.isNewline }) {
            let parts = token.split(separator: "-", omittingEmptySubsequences: false)
            if parts.count == 1, let port = Int(parts[0]), (1...65535).contains(port) {
                result.insert(port)
            } else if parts.count == 2, let low = Int(parts[0]), let high = Int(parts[1]),
                      (1...65535).contains(low), (1...65535).contains(high), low <= high,
                      high - low < rangeLimit {
                result.formUnion(low...high)
            }
        }
        return result
    }

    /// Process names, matched without regard to case.
    static func names(from text: String) -> Set<String> {
        Set(text.split(whereSeparator: { $0 == "," || $0 == ";" || $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty })
    }

    func matches(port: Int) -> Bool { ports.contains(port) }

    func matches(_ process: DevServerProcess) -> Bool {
        guard !names.isEmpty else { return false }
        let candidates = [process.name, (process.arguments.first.map(DevServersClassifier.basename) ?? "")]
        return candidates.contains { names.contains($0.lowercased()) }
    }
}

/// The section's switches, read from defaults.
struct DevServersOptions: Equatable {
    var enabled = true
    var announces = true
    var indicator = false
    var extras = DevServersExtras()

    static func current(in defaults: UserDefaults = .standard) -> DevServersOptions {
        func flag(_ key: String, _ fallback: Bool) -> Bool { defaults.object(forKey: key) as? Bool ?? fallback }
        return DevServersOptions(enabled: flag(DefaultsKey.notchDevServersEnabled, true),
                                 announces: flag(DefaultsKey.notchDevServersAnnounce, true),
                                 indicator: flag(DefaultsKey.notchDevServersIndicator, false),
                                 extras: DevServersExtras(ports: defaults.string(forKey: DefaultsKey.notchDevServersExtraPorts) ?? "",
                                                          names: defaults.string(forKey: DefaultsKey.notchDevServersExtraNames) ?? ""))
    }

    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: DefaultsKey.notchDevServersEnabled) as? Bool ?? true
    }

    /// Whether anything needs a check while the page is not on screen.
    var watchesInBackground: Bool { enabled && (announces || indicator) }
}

// MARK: - Classification

enum DevServersClassifier {
    /// Supabase's local stack: API, database, Studio and the mail catcher.
    static let supabasePorts = 54321...54324

    /// Folders the system's own services run from. A listener there is never
    /// a dev server, whatever the person listed.
    static let systemPrefixes = ["/System/", "/usr/libexec/", "/usr/sbin/", "/sbin/", "/Library/Apple/"]

    /// Services that run from elsewhere but are the system's all the same.
    static let systemNames: Set<String> = [
        "controlcenter", "rapportd", "sharingd", "airplayxpchelper", "mdnsresponder", "launchd", "remoted",
        "identityservicesd", "screensharingd", "screensharingagent", "cupsd", "useractivityd", "wifiagent",
    ]

    /// Docker Desktop, OrbStack and Colima forward container ports from these.
    static let dockerNames = ["com.docker", "docker", "vpnkit", "orbstack", "limactl"]

    static func basename(_ path: String) -> String {
        guard let slash = path.lastIndex(of: "/") else { return path }
        return String(path[path.index(after: slash)...])
    }

    /// Never shown: the system's services, Zenith itself, and anyone else's
    /// processes.
    static func isIgnored(_ process: DevServerProcess, context: DevServersContext) -> Bool {
        if process.pid == context.ownPID { return true }
        if let uid = process.uid, uid != context.uid { return true }
        let name = process.name.lowercased()
        if systemNames.contains(name) { return true }
        if ["zenith", "zenithdeveloper", "zenith (developer)", "vorssaint", "vorssaintdeveloper"].contains(name) {
            return true
        }
        let path = process.path
        if systemPrefixes.contains(where: { path.hasPrefix($0) }) { return true }
        // An app's own bundled helper (an Electron or Adobe node, say) is the
        // app's. Python runs from a Python.app inside its framework, though.
        if path.contains(".app/"), !path.contains(".framework/"), !path.contains("/Python.app/"), !isDocker(process) {
            return true
        }
        return false
    }

    static func isDocker(_ process: DevServerProcess) -> Bool {
        let name = process.name.lowercased()
        return name == "docker-proxy" || dockerNames.contains { name.hasPrefix($0) }
    }

    /// What the listener on `port` runs, or nil when it is not a dev server.
    static func kind(of process: DevServerProcess, port: Int, extras: DevServersExtras = DevServersExtras(),
                     context: DevServersContext) -> DevServerKind? {
        guard !isIgnored(process, context: context) else { return nil }
        if isDocker(process) {
            return supabasePorts.contains(port) ? .supabase : .docker
        }
        if supabasePorts.contains(port), process.name.lowercased().contains("supabase") { return .supabase }
        if let kind = framework(process) { return kind }
        if extras.matches(port: port) || extras.matches(process) { return .custom }
        return runtime(process)
    }

    /// A framework named by the process or its command line.
    static func framework(_ process: DevServerProcess) -> DevServerKind? {
        let line = ParsedLine(process)
        // Node and its kin, by the tool's bin or its package path. Nuxt,
        // Astro and Remix drive Vite inside, so they are asked first.
        if line.name.hasPrefix("next-server") || line.first.hasPrefix("next-server")
            || line.argumentsContain("/next/dist/")
            || (line.hasBin("next") && (line.has("dev") || line.has("start") || line.has("--turbo"))) {
            return .next
        }
        if line.hasBin("nuxi") || line.hasBin("nuxt") || line.argumentsContain("/nuxi/") || line.argumentsContain("/nuxt/bin") {
            return .nuxt
        }
        if line.hasBin("astro") || line.argumentsContain("/astro/astro.") { return .astro }
        if line.hasBin("remix") || line.hasBin("remix-serve") || line.argumentsContain("@remix-run/") { return .remix }
        if line.hasBin("vite") || line.argumentsContain("/vite/bin/") { return .vite }
        if line.hasBin("webpack-dev-server") || line.argumentsContain("webpack-dev-server")
            || (line.hasBin("webpack") && line.has("serve")) {
            return .webpack
        }
        // PHP: `php artisan serve` runs the built-in server as a child,
        // `php -S 127.0.0.1:8000 …/Illuminate/Foundation/resources/server.php`.
        if line.runtimeStarts(with: "php") {
            if line.hasBin("artisan") && line.has("serve") { return .laravel }
            if line.argumentsContain("/laravel/framework/") || line.argumentsContain("/illuminate/foundation/") {
                return .laravel
            }
            if line.has("-S") || line.hasBin("artisan") { return .php }
        }
        // Python.
        if line.runtimeStarts(with: "python") || line.hasBin("uvicorn") || line.hasBin("flask") {
            if line.module("http.server") || line.module("SimpleHTTPServer") { return .pythonHTTP }
            if line.module("uvicorn") || line.hasBin("uvicorn") || line.first.hasPrefix("uvicorn") { return .uvicorn }
            if (line.module("flask") || line.hasBin("flask")) && line.has("run") { return .flask }
            if (line.hasBin("manage.py") || line.hasBin("django-admin")) && line.has("runserver") { return .django }
        }
        // Ruby: `rails s`, or Puma, which renames itself to `puma 6.4.2 (tcp://…)`.
        if line.first.hasPrefix("puma ") || line.name == "puma" { return .rails }
        if line.runtimeStarts(with: "ruby") || line.hasBin("rails") {
            if line.hasBin("rails") && (line.has("s") || line.has("server")) { return .rails }
        }
        // Go: `go run` builds into a go-build folder and runs it as its
        // child; air runs its build (`tmp/main`) as its child.
        let parent = process.parentName.lowercased()
        // A test binary (`pkg.test`) opening a test server is not one.
        let built = process.path.isEmpty ? line.first : process.path.lowercased()
        if parent == "go" || parent == "air" || built.contains("/go-build"), !built.hasSuffix(".test") {
            return .go
        }
        // Flutter's tool is a Dart snapshot; `flutter run -d chrome` serves the web build from it.
        if line.runtimeStarts(with: "dart") && line.argumentsContain("flutter_tools") { return .flutter }
        return nil
    }

    /// A JavaScript runtime with a dev script: in a project folder, or run
    /// with a watcher or a dev task.
    static func runtime(_ process: DevServerProcess) -> DevServerKind? {
        let line = ParsedLine(process)
        let kind: DevServerKind
        if line.runtimeIs("node") { kind = .node }
        else if line.runtimeIs("bun") { kind = .bun }
        else if line.runtimeIs("deno") { kind = .deno }
        else { return nil }
        guard let cwd = process.cwd, cwd != "/" else { return nil }
        let indicators = ["dev", "--watch", "--hot", "watch", "serve", "nodemon", "tsx", "ts-node", "ts-node-dev"]
        guard process.hasProjectFile || indicators.contains(where: { line.has($0) || line.hasBin($0) }) else {
            return nil
        }
        return kind
    }

    /// The command line in the shapes the rules ask about.
    private struct ParsedLine {
        let name: String
        let first: String
        let arguments: [String]
        let lowered: [String]
        let bins: [String]

        init(_ process: DevServerProcess) {
            name = process.name.lowercased()
            first = (process.arguments.first ?? "").lowercased()
            arguments = process.arguments
            lowered = process.arguments.map { $0.lowercased() }
            bins = lowered.map { argument in
                var bin = DevServersClassifier.basename(argument)
                for suffix in [".js", ".mjs", ".cjs", ".ts"] where bin.hasSuffix(suffix) {
                    bin.removeLast(suffix.count)
                }
                return bin
            }
        }

        /// An argument exactly, as typed (`-S` and `-s` differ).
        func has(_ argument: String) -> Bool { arguments.dropFirst().contains(argument) }

        /// A tool by its bin: `node_modules/.bin/vite`, `vite/bin/vite.js`, `vite`.
        func hasBin(_ tool: String) -> Bool { bins.contains(tool) || name == tool }

        func argumentsContain(_ text: String) -> Bool { lowered.contains { $0.contains(text) } }

        /// `python -m uvicorn`.
        func module(_ module: String) -> Bool {
            let lowerModule = module.lowercased()
            return zip(lowered, lowered.dropFirst()).contains { $0 == "-m" && $1 == lowerModule }
        }

        /// The interpreter: `php`, `php8.3`, `Python`, `python3.12`.
        func runtimeStarts(with runtime: String) -> Bool {
            name.hasPrefix(runtime) || DevServersClassifier.basename(first).hasPrefix(runtime)
        }

        func runtimeIs(_ runtime: String) -> Bool {
            name == runtime || DevServersClassifier.basename(first) == runtime
        }
    }
}

// MARK: - Naming and addresses

enum DevServersNaming {
    /// Folders a server may run from inside its project, named for what they
    /// hold rather than for the project.
    static let genericFolders: Set<String> = ["src", "public", "dist", "build", "out", ".next", "tmp", "bin", ".bin"]

    /// The project's name from the process's folder: its last component,
    /// past a node_modules or a generic folder. Nil for the root, the home
    /// folder or no folder at all.
    static func project(cwd: String?, home: String) -> String? {
        guard var path = cwd?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty else { return nil }
        while path.count > 1, path.hasSuffix("/") { path.removeLast() }
        var components = path.split(separator: "/").map(String.init)
        if let modules = components.firstIndex(of: "node_modules") { components = Array(components[..<modules]) }
        while let last = components.last, genericFolders.contains(last.lowercased()), components.count > 1 {
            components.removeLast()
        }
        let standardHome = home.hasSuffix("/") && home.count > 1 ? String(home.dropLast()) : home
        let rebuilt = "/" + components.joined(separator: "/")
        guard let name = components.last, rebuilt != standardHome, rebuilt != "/" else { return nil }
        return name
    }
}

enum DevServersFormat {
    /// The host part of an lsof endpoint such as `127.0.0.1:3000`, `[::1]:5173` or `*:8000`.
    static func host(ofEndpoint endpoint: String) -> String? {
        guard let separator = endpoint.lastIndex(of: ":") else { return nil }
        var host = String(endpoint[..<separator])
        if host.hasPrefix("["), host.hasSuffix("]") { host = String(host.dropFirst().dropLast()) }
        return host.isEmpty ? nil : host
    }

    static func port(ofEndpoint endpoint: String) -> Int? {
        guard let separator = endpoint.lastIndex(of: ":"),
              let port = Int(endpoint[endpoint.index(after: separator)...]), (1...65535).contains(port) else { return nil }
        return port
    }

    /// Whether the endpoint is on this Mac's loopback or on every interface,
    /// IPv4 or IPv6, where `localhost` reaches it.
    static func isLocal(_ endpoint: String) -> Bool {
        guard let host = host(ofEndpoint: endpoint)?.lowercased() else { return false }
        if ["*", "0.0.0.0", "::", "::1", "localhost", "::ffff:127.0.0.1", "::ffff:0.0.0.0"].contains(host) { return true }
        return host.hasPrefix("127.")
    }

    /// `localhost:3000`, as a browser's address bar has it.
    static func host(port: Int) -> String { "localhost:\(port)" }

    /// `http://localhost:3000`. Loopback and wildcard binds, IPv4 or IPv6,
    /// all answer on localhost, which is what a framework prints too.
    static func url(port: Int) -> URL? {
        guard (1...65535).contains(port) else { return nil }
        var components = URLComponents()
        components.scheme = "http"
        components.host = "localhost"
        components.port = port
        return components.url
    }

    /// How long it has run: `0:42`, `12:03`, `3:05:12`, then `2d 03:05`.
    static func uptime(_ seconds: TimeInterval) -> String {
        let total = seconds.isFinite ? max(0, Int(seconds.rounded(.down))) : 0
        let days = total / 86_400, hours = total / 3600 % 24, minutes = total / 60 % 60, rest = total % 60
        if days > 0 { return String(format: "%dd %02d:%02d", days, hours, minutes) }
        if total >= 3600 { return String(format: "%d:%02d:%02d", hours, minutes, rest) }
        return String(format: "%d:%02d", minutes, rest)
    }

    /// The widest reading of the same shape, so the slot keeps its width while it ticks.
    static func uptimeTemplate(_ seconds: TimeInterval) -> String {
        seconds >= 86_400 ? "00d 00:00" : seconds >= 3600 ? "00:00:00" : "00:00"
    }

    /// The notice's line: `Next.js · Swift-portfolio · localhost:3000`.
    static func noticeTitle(_ server: DevServer) -> String {
        [server.framework, server.project, host(port: server.port)].compactMap { $0 }.filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

// MARK: - Servers

/// One dev server: a process (or a Docker port) and the ports it listens on.
struct DevServer: Identifiable, Equatable {
    /// Stable while the same process runs.
    let id: String
    let kind: DevServerKind
    let pid: Int32
    let processName: String
    let project: String?
    /// Sorted, the first one the URL's unless `primary` says otherwise.
    let ports: [Int]
    let port: Int
    let startedAt: Date?
    /// The kernel start time Kill checks, so a reused pid is never signalled.
    let startMicros: UInt64?

    /// The framework's name, or the process's for a listed one.
    var framework: String { kind == .custom ? processName : kind.title }
    /// What the row leads with: the project, or the framework without one.
    var title: String { project ?? framework }
    var host: String { DevServersFormat.host(port: port) }
    var url: URL? { DevServersFormat.url(port: port) }
    var monogram: String {
        kind == .custom ? String(processName.prefix(1)).uppercased() : kind.monogram
    }
    var canKill: Bool { kind.killable && startMicros != nil && pid > 1 }

    /// What a restart keeps: the same project (or framework) on the same port.
    var coalescingKey: String { "\(project ?? framework)|\(port)" }
}

/// A listener as the Port Manager reads it: lsof's endpoint and its process.
struct DevServersListener: Equatable {
    var pid: Int32
    var port: Int
    var address: String
}

enum DevServersScanner {
    /// The dev servers among the listeners. `process` reads a pid's process
    /// (the service caches it); a pid it cannot read is left out.
    static func servers(_ listeners: [DevServersListener], process: (Int32) -> DevServerProcess?,
                        extras: DevServersExtras = DevServersExtras(),
                        context: DevServersContext) -> [DevServer] {
        let local = listeners.filter { (1...65535).contains($0.port) && DevServersFormat.isLocal($0.address) }
        var processes: [Int32: DevServerProcess] = [:]
        for pid in Set(local.map(\.pid)) {
            if let read = process(pid) { processes[pid] = read }
        }
        // A forking server (uvicorn's reloader, a cluster) holds one socket
        // in several processes; the parent stands for them.
        var pidsByPort: [Int: Set<Int32>] = [:]
        for listener in local { pidsByPort[listener.port, default: []].insert(listener.pid) }
        struct Group { var kind: DevServerKind; var process: DevServerProcess; var ports: Set<Int> }
        var groups: [String: Group] = [:]
        for listener in local {
            guard let process = processes[listener.pid] else { continue }
            let sharing = pidsByPort[listener.port] ?? []
            if sharing.count > 1, sharing.contains(process.parentPID) { continue }
            guard let kind = DevServersClassifier.kind(of: process, port: listener.port, extras: extras,
                                                       context: context) else { continue }
            let key: String
            switch kind {
            case .supabase: key = "supabase"
            case .docker: key = "docker:\(listener.port)"
            default: key = "pid:\(process.pid)"
            }
            groups[key, default: Group(kind: kind, process: process, ports: [])].ports.insert(listener.port)
        }
        return groups.map { key, group in
            let ports = group.ports.sorted()
            // Supabase's Studio is the one worth opening in a browser.
            let primary = group.kind == .supabase && ports.contains(54323) ? 54323 : ports[0]
            // A forwarded port's process is Docker's, whose folder says nothing.
            let project = group.kind.groupsByProcess
                ? DevServersNaming.project(cwd: group.process.cwd, home: context.home) : nil
            return DevServer(id: "\(key)@\(group.process.startMicros ?? 0)", kind: group.kind, pid: group.process.pid,
                             processName: group.process.name, project: project, ports: ports, port: primary,
                             startedAt: group.process.startedAt, startMicros: group.process.startMicros)
        }
        .sorted { $0.port == $1.port ? $0.id < $1.id : $0.port < $1.port }
    }

    /// The listeners in a Port Manager listing: TCP only.
    static func listeners(_ entries: [PortManagerEntry]) -> [DevServersListener] {
        entries.filter { $0.protocolName == "TCP" }.map { DevServersListener(pid: $0.pid, port: $0.port, address: $0.address) }
    }
}

// MARK: - Process arguments

enum DevServersProcArgs {
    /// argv from a `KERN_PROCARGS2` buffer: argc, the executable's path,
    /// padding, then argc strings (the environment follows and is never read).
    static func arguments(_ bytes: [UInt8]) -> [String] {
        guard bytes.count >= 4 else { return [] }
        let argc = Int(bytes[0]) | Int(bytes[1]) << 8 | Int(bytes[2]) << 16 | Int(bytes[3]) << 24
        guard argc > 0, argc < 4096 else { return [] }
        var index = 4
        // The executable's path, then its padding.
        while index < bytes.count, bytes[index] != 0 { index += 1 }
        while index < bytes.count, bytes[index] == 0 { index += 1 }
        var result: [String] = []
        while index < bytes.count, result.count < argc {
            let start = index
            while index < bytes.count, bytes[index] != 0 { index += 1 }
            result.append(String(decoding: bytes[start..<index], as: UTF8.self))
            index += 1
        }
        // A runtime that renames itself (Node's process.title) blanks the rest.
        return result.filter { !$0.isEmpty }
    }
}

// MARK: - Announcing

/// Which servers are new enough to announce. The first look is a baseline:
/// what already runs says nothing. A server whose project and port were seen
/// within the window is the same one restarting (a hot reload, nodemon, air),
/// so it says nothing either.
struct DevServersAnnouncer {
    static let window: TimeInterval = 30

    private var lastSeen: [String: TimeInterval] = [:]
    private var hasBaseline = false

    /// Forget everything, as when announcing is turned back on.
    mutating func reset() {
        lastSeen = [:]
        hasBaseline = false
    }

    /// The servers to announce in this look, in their order.
    mutating func update(_ servers: [DevServer], now: TimeInterval) -> [DevServer] {
        lastSeen = lastSeen.filter { now - $0.value <= Self.window }
        var announced: [DevServer] = []
        var keys = Set<String>()
        for server in servers {
            let key = server.coalescingKey
            if hasBaseline, lastSeen[key] == nil, keys.insert(key).inserted { announced.append(server) }
            keys.insert(key)
        }
        for key in keys { lastSeen[key] = now }
        hasBaseline = true
        return announced
    }
}

// MARK: - Kill

/// Kill asks once more: the first click turns the button into "Kill?" for a
/// few seconds, a second click within them stops the server with SIGTERM,
/// and SIGKILL follows if it is still there after `escalation`.
struct DevServersKillConfirmation: Equatable {
    static let window: TimeInterval = 3
    static let escalation: TimeInterval = 3

    enum Outcome: Equatable { case confirm, kill, ignored }

    private(set) var confirming: (id: String, until: TimeInterval)?
    private(set) var stopping: Set<String> = []

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.confirming?.id == rhs.confirming?.id && lhs.confirming?.until == rhs.confirming?.until
            && lhs.stopping == rhs.stopping
    }

    func isConfirming(_ id: String, now: TimeInterval) -> Bool {
        guard let confirming else { return false }
        return confirming.id == id && now <= confirming.until
    }

    func isStopping(_ id: String) -> Bool { stopping.contains(id) }

    mutating func press(_ id: String, now: TimeInterval) -> Outcome {
        if stopping.contains(id) { return .ignored }
        if isConfirming(id, now: now) {
            confirming = nil
            stopping.insert(id)
            return .kill
        }
        confirming = (id, now + Self.window)
        return .confirm
    }

    /// The question lapses without a second click.
    mutating func expire(now: TimeInterval) {
        if let confirming, now > confirming.until { self.confirming = nil }
    }

    /// Escape, or a click elsewhere.
    mutating func cancel() { confirming = nil }

    /// The servers still listed: a stopped one that left is done.
    mutating func keep(_ ids: Set<String>) {
        stopping.formIntersection(ids)
        if let confirming, !ids.contains(confirming.id) { self.confirming = nil }
    }
}
