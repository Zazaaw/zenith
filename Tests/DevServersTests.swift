// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Darwin
import Foundation

/// Zenith fork: dev servers. Classification, naming, addresses, grouping,
/// announcing and the kill confirmation run on sample processes; one check
/// opens a real listener on a random loopback port and finds it through the
/// Port Manager's own lsof listing and the kernel probe. No process is ever
/// signalled.
enum DevServersTests {
    static func run(_ suite: TestSuite) {
        classification(suite)
        ignoring(suite)
        naming(suite)
        addresses(suite)
        uptime(suite)
        grouping(suite)
        procArgs(suite)
        extras(suite)
        coalescing(suite)
        killConfirmation(suite)
        notice(suite)
        settings(suite)
        island(suite)
        liveListener(suite)
        strings(suite)
    }

    private static let home = "/Users/dev"
    private static let context = DevServersContext(ownPID: 99_999, uid: 501, home: home)

    private static func process(_ name: String, _ arguments: [String], path: String = "", cwd: String? = "/Users/dev/Code/app",
                                uid: UInt32? = 501, pid: Int32 = 4321, parentPID: Int32 = 1, parent: String = "zsh",
                                projectFile: Bool = false) -> DevServerProcess {
        DevServerProcess(pid: pid, name: name, path: path, arguments: arguments, cwd: cwd, uid: uid, parentPID: parentPID,
                         parentName: parent, startedAt: Date(timeIntervalSince1970: 1_795_000_000),
                         startMicros: 1_795_000_000_000_000, hasProjectFile: projectFile)
    }

    private static func kind(_ process: DevServerProcess, port: Int = 3000,
                             extras: DevServersExtras = DevServersExtras()) -> DevServerKind? {
        DevServersClassifier.kind(of: process, port: port, extras: extras, context: context)
    }

    // MARK: Classification

    private static func classification(_ suite: TestSuite) {
        let cases: [(DevServerProcess, Int, DevServerKind?, String)] = [
            (process("node", ["next-server (v15.0.3)"]), 3000, .next, "Next's renamed server process"),
            (process("node", ["node", "/Users/dev/Code/app/node_modules/.bin/next", "dev"]), 3000, .next, "next dev"),
            (process("node", ["node", "/Users/dev/Code/app/node_modules/next/dist/server/lib/start-server.js"]), 3000, .next,
             "Next's server by its package path"),
            (process("node", ["node", "/Users/dev/Code/app/node_modules/.bin/vite", "--host"]), 5173, .vite, "vite"),
            (process("node", ["node", "/Users/dev/Code/app/node_modules/vite/bin/vite.js"]), 5173, .vite, "vite by its bin file"),
            (process("bun", ["bun", "--bun", "vite"]), 5173, .vite, "vite run by Bun"),
            (process("node", ["node", "/Users/dev/Code/app/node_modules/nuxi/bin/nuxi.mjs", "dev"]), 3000, .nuxt,
             "Nuxt before the Vite it drives"),
            (process("node", ["node", "/Users/dev/Code/app/node_modules/.bin/astro", "dev"]), 4321, .astro, "astro dev"),
            (process("node", ["node", "/Users/dev/Code/app/node_modules/.bin/remix", "vite:dev"]), 5173, .remix, "remix"),
            (process("node", ["node", "/Users/dev/Code/app/node_modules/.bin/webpack-dev-server"]), 8080, .webpack,
             "webpack-dev-server"),
            (process("node", ["node", "/Users/dev/Code/app/node_modules/.bin/webpack", "serve"]), 8080, .webpack, "webpack serve"),
            (process("bun", ["bun", "run", "--hot", "src/index.ts"], projectFile: true), 3000, .bun, "a Bun server in a project"),
            (process("deno", ["deno", "task", "dev"]), 8000, .deno, "deno task dev"),
            (process("node", ["node", "server.js"], projectFile: true), 4000, .node, "node in a folder with package.json"),
            (process("node", ["node", "--watch", "server.js"]), 4000, .node, "node with a watcher"),
            (process("node", ["node", "/Users/dev/tools/helper.js"]), 4000, nil, "node with no project or dev task"),
            (process("node", ["node", "server.js"], cwd: "/", projectFile: true), 4000, nil, "node run from the root"),
            (process("php", ["php", "artisan", "serve"]), 8000, .laravel, "php artisan serve"),
            (process("php", ["/opt/homebrew/bin/php", "-S", "127.0.0.1:8000",
                             "/Users/dev/Code/app/vendor/laravel/framework/src/Illuminate/Foundation/resources/server.php"]),
             8000, .laravel, "the built-in server artisan serve starts"),
            (process("php", ["php", "-S", "localhost:8080"]), 8080, .php, "php -S"),
            (process("php-fpm", ["php-fpm: master process (/opt/homebrew/etc/php-fpm.conf)"]), 9000, nil, "php-fpm"),
            (process("Python", ["/Library/Developer/CommandLineTools/usr/bin/python3", "-m", "http.server", "8000"],
                     path: "/Library/Developer/CommandLineTools/Library/Frameworks/Python3.framework/Versions/3.9/Resources/Python.app/Contents/MacOS/Python"),
             8000, .pythonHTTP, "python -m http.server, from Python.app inside its framework"),
            (process("python3.12", ["/Users/dev/Code/api/.venv/bin/python3", "/Users/dev/Code/api/.venv/bin/uvicorn",
                                    "main:app", "--reload"]), 8000, .uvicorn, "uvicorn"),
            (process("Python", ["python3", "-m", "uvicorn", "main:app"]), 8000, .uvicorn, "python -m uvicorn"),
            (process("Python", ["python3", "-m", "flask", "run"]), 5000, .flask, "python -m flask run"),
            (process("Python", ["python3", "/Users/dev/Code/api/.venv/bin/flask", "run", "--debug"]), 5000, .flask, "flask run"),
            (process("Python", ["python3", "manage.py", "runserver"]), 8000, .django, "manage.py runserver"),
            (process("Python", ["python3", "manage.py", "migrate"]), 8000, nil, "a Django command that serves nothing"),
            (process("main", ["/var/folders/xy/T/go-build3456/b001/exe/main"],
                     path: "/private/var/folders/xy/T/go-build3456/b001/exe/main", parent: "go"), 8080, .go, "go run"),
            (process("main", ["./tmp/main"], path: "/Users/dev/Code/svc/tmp/main", parent: "air"), 8080, .go, "air"),
            (process("pkg.test", ["/var/folders/xy/T/go-build1/b001/pkg.test"],
                     path: "/private/var/folders/xy/T/go-build1/b001/pkg.test", parent: "go"), 51234, nil,
             "a go test binary's test server"),
            (process("dart", ["/Users/dev/flutter/bin/cache/dart-sdk/bin/dart", "--packages=/x",
                              "/Users/dev/flutter/bin/cache/flutter_tools.snapshot", "run", "-d", "chrome"]),
             54000, .flutter, "flutter run"),
            (process("ruby", ["ruby", "bin/rails", "s"]), 3000, .rails, "rails s"),
            (process("ruby", ["ruby", "bin/rails", "server", "-p", "3001"]), 3001, .rails, "rails server"),
            (process("ruby", ["puma 6.4.2 (tcp://127.0.0.1:3000) [blog]"]), 3000, .rails, "Puma under its own title"),
            (process("ruby", ["ruby", "bin/rails", "console"]), 3000, nil, "a Rails console"),
            (process("com.docker.backend", ["com.docker.backend"],
                     path: "/Applications/Docker.app/Contents/MacOS/com.docker.backend"), 54321, .supabase,
             "Supabase's local API, forwarded by Docker"),
            (process("com.docker.backend", ["com.docker.backend"],
                     path: "/Applications/Docker.app/Contents/MacOS/com.docker.backend"), 5432, .docker, "a Docker port forward"),
            (process("docker-proxy", ["docker-proxy", "-proto", "tcp"]), 8080, .docker, "docker-proxy"),
            (process("OrbStack Helper", ["OrbStack Helper"], path: "/Applications/OrbStack.app/Contents/Frameworks/x"), 6379,
             .docker, "OrbStack's forward"),
            (process("caddy", ["caddy", "run"]), 2019, nil, "an unlisted server"),
        ]
        for (process, port, expected, label) in cases {
            suite.expect(kind(process, port: port) == expected, "classifies \(label)")
        }
        suite.expect(DevServerKind.allCases.filter { $0 != .custom }.allSatisfy { !$0.title.isEmpty && !$0.monogram.isEmpty },
                     "every framework has a name and a monogram")
        suite.expect(!DevServerKind.docker.killable && !DevServerKind.supabase.killable && DevServerKind.next.killable,
                     "Docker's forwards never offer Kill, which would stop Docker itself")
    }

    // MARK: Ignoring

    private static func ignoring(_ suite: TestSuite) {
        let everything = DevServersExtras(ports: [5000, 7000, 3000], names: ["controlcenter", "node", "zenith"])
        let controlCenter = process("ControlCenter", ["/System/Library/CoreServices/ControlCenter.app/Contents/MacOS/ControlCenter"],
                                    path: "/System/Library/CoreServices/ControlCenter.app/Contents/MacOS/ControlCenter")
        suite.expect(kind(controlCenter, port: 5000, extras: everything) == nil,
                     "AirPlay's receiver on 5000 is never a dev server, even when 5000 is listed")
        suite.expect(kind(process("rapportd", ["rapportd"], path: "/usr/libexec/rapportd"), port: 3000, extras: everything) == nil,
                     "a service in /usr/libexec is the system's")
        suite.expect(kind(process("rapportd", ["rapportd"]), port: 3000, extras: everything) == nil,
                     "a known system service is left out by name too")
        suite.expect(kind(process("node", ["next-server (v15.0.3)"], pid: context.ownPID)) == nil,
                     "Zenith's own process is never listed")
        suite.expect(kind(process("Zenith", ["Zenith"]), port: 3000, extras: everything) == nil,
                     "Zenith is never listed by name")
        suite.expect(kind(process("node", ["next-server (v15.0.3)"], uid: 502)) == nil,
                     "another person's server is not this person's")
        suite.expect(kind(process("node", ["node", "dev"], path: "/Library/Application Support/Adobe/CCLibrary.app/Contents/libs/node",
                                  projectFile: true), port: 3000, extras: everything) == nil,
                     "a node an app bundles is the app's")
        suite.expect(kind(process("launchd", ["launchd"], path: "/sbin/launchd"), port: 3000, extras: everything) == nil,
                     "launchd is never one")
    }

    // MARK: Naming

    private static func naming(_ suite: TestSuite) {
        func project(_ cwd: String?) -> String? { DevServersNaming.project(cwd: cwd, home: home) }
        suite.expect(project("/Users/dev/Developer/Swift-portfolio") == "Swift-portfolio", "the folder's name is the project")
        suite.expect(project("/Users/dev/Developer/Swift-portfolio/") == "Swift-portfolio", "a trailing slash changes nothing")
        suite.expect(project("/Users/dev/monorepo/apps/web") == "web", "a monorepo app keeps its own name")
        suite.expect(project("/Users/dev/Code/shop/node_modules/.bin") == "shop", "a server run from node_modules is its project's")
        suite.expect(project("/Users/dev/Code/blog/src") == "blog" && project("/Users/dev/Code/site/public") == "site",
                     "a generic folder inside a project gives way to the project")
        suite.expect(project("/Users/dev") == nil && project("/Users/dev/") == nil, "the home folder names no project")
        suite.expect(project("/") == nil && project(nil) == nil && project("") == nil, "no folder names no project")

        let server = DevServer(id: "pid:1@1", kind: .next, pid: 1234, processName: "node", project: "Swift-portfolio",
                               ports: [3000], port: 3000, startedAt: nil, startMicros: 1)
        suite.expect(server.title == "Swift-portfolio" && server.framework == "Next.js" && server.monogram == "N",
                     "a row leads with the project and names the framework")
        let bare = DevServer(id: "pid:2@1", kind: .vite, pid: 1235, processName: "node", project: nil,
                             ports: [5173], port: 5173, startedAt: nil, startMicros: 1)
        suite.expect(bare.title == "Vite", "without a project the framework leads")
        let listed = DevServer(id: "pid:3@1", kind: .custom, pid: 1236, processName: "caddy", project: "site",
                               ports: [2019], port: 2019, startedAt: nil, startMicros: 1)
        suite.expect(listed.framework == "caddy" && listed.monogram == "C", "a listed process is named for itself")
    }

    // MARK: Addresses

    private static func addresses(_ suite: TestSuite) {
        for endpoint in ["127.0.0.1:3000", "[::1]:5173", "*:8000", "0.0.0.0:8080", "[::]:4000", "127.0.1.1:3000",
                         "localhost:3000"] {
            suite.expect(DevServersFormat.isLocal(endpoint), "\(endpoint) is reached on localhost")
        }
        for endpoint in ["192.168.1.20:3000", "[fe80::1]:3000", "10.0.0.5:8080", "3000", ""] {
            suite.expect(!DevServersFormat.isLocal(endpoint), "\(endpoint) is not this Mac's loopback or wildcard")
        }
        suite.expect(DevServersFormat.port(ofEndpoint: "[::1]:5173") == 5173 && DevServersFormat.port(ofEndpoint: "*:8000") == 8000
                     && DevServersFormat.port(ofEndpoint: "127.0.0.1:0") == nil,
                     "the port comes off IPv4 and IPv6 endpoints")
        suite.expect(DevServersFormat.host(ofEndpoint: "[::1]:5173") == "::1" && DevServersFormat.host(ofEndpoint: "*:80") == "*",
                     "IPv6 brackets come off the host")
        suite.expect(DevServersFormat.host(port: 3000) == "localhost:3000", "the host reads as a browser has it")
        suite.expect(DevServersFormat.url(port: 3000)?.absoluteString == "http://localhost:3000"
                     && DevServersFormat.url(port: 5173)?.absoluteString == "http://localhost:5173",
                     "IPv4, IPv6 and wildcard binds all open on localhost")
        suite.expect(DevServersFormat.url(port: 0) == nil && DevServersFormat.url(port: 70_000) == nil, "no URL without a port")
        let server = DevServer(id: "pid:1@1", kind: .next, pid: 1234, processName: "node", project: "Swift-portfolio",
                               ports: [3000], port: 3000, startedAt: nil, startMicros: 1)
        suite.expect(DevServersFormat.noticeTitle(server) == "Next.js · Swift-portfolio · localhost:3000",
                     "the notice reads framework, project and host")
        let bare = DevServer(id: "docker:5432@1", kind: .docker, pid: 77, processName: "com.docker.backend", project: nil,
                             ports: [5432], port: 5432, startedAt: nil, startMicros: 1)
        suite.expect(DevServersFormat.noticeTitle(bare) == "Docker · localhost:5432", "without a project it leaves it out")
    }

    private static func uptime(_ suite: TestSuite) {
        suite.expect(DevServersFormat.uptime(42) == "0:42" && DevServersFormat.uptime(723) == "12:03",
                     "under an hour reads minutes and seconds")
        let hours: TimeInterval = 11_112 // 3:05:12
        suite.expect(DevServersFormat.uptime(hours) == "3:05:12", "under a day reads hours too")
        let days: TimeInterval = 184_000 // 2 days, 3:06:40
        suite.expect(DevServersFormat.uptime(days) == "2d 03:06", "days read days, hours and minutes")
        suite.expect(DevServersFormat.uptime(-5) == "0:00" && DevServersFormat.uptime(.nan) == "0:00", "no negative uptime")
        let shapes: [(TimeInterval, TimeInterval)] = [(59, 3599), (3600, 86_399), (86_400, 9 * 86_400 + 86_399)]
        for (shape, widest) in shapes {
            let template = DevServersFormat.uptimeTemplate(shape)
            let reading = DevServersFormat.uptime(widest)
            suite.expect(template.count >= reading.count, "the slot for \(reading) is as wide as the widest of its shape")
        }
    }

    // MARK: Grouping

    private static func grouping(_ suite: TestSuite) {
        let processes: [Int32: DevServerProcess] = [
            100: process("node", ["next-server (v15.0.3)"], cwd: "/Users/dev/Code/Swift-portfolio", pid: 100),
            200: process("node", ["node", "/x/node_modules/.bin/vite"], cwd: "/Users/dev/Code/admin", pid: 200),
            300: process("Python", ["python3", "-m", "uvicorn", "main:app", "--reload"], cwd: "/Users/dev/Code/api", pid: 300),
            301: process("Python", ["python3", "-c", "from multiprocessing.spawn import spawn_main"],
                         cwd: "/Users/dev/Code/api", pid: 301, parentPID: 300),
            400: process("com.docker.backend", ["com.docker.backend"], path: "/Applications/Docker.app/Contents/MacOS/com.docker.backend",
                         cwd: "/", pid: 400),
            500: process("rapportd", ["rapportd"], path: "/usr/libexec/rapportd", pid: 500),
        ]
        let listeners = [
            DevServersListener(pid: 100, port: 3000, address: "*:3000"),
            DevServersListener(pid: 100, port: 3000, address: "[::]:3000"),
            DevServersListener(pid: 200, port: 5173, address: "[::1]:5173"),
            DevServersListener(pid: 200, port: 24678, address: "127.0.0.1:24678"),
            DevServersListener(pid: 300, port: 8000, address: "127.0.0.1:8000"),
            DevServersListener(pid: 301, port: 8000, address: "127.0.0.1:8000"),
            DevServersListener(pid: 400, port: 54321, address: "127.0.0.1:54321"),
            DevServersListener(pid: 400, port: 54322, address: "127.0.0.1:54322"),
            DevServersListener(pid: 400, port: 54323, address: "127.0.0.1:54323"),
            DevServersListener(pid: 400, port: 54324, address: "127.0.0.1:54324"),
            DevServersListener(pid: 400, port: 5432, address: "127.0.0.1:5432"),
            DevServersListener(pid: 400, port: 6379, address: "*:6379"),
            DevServersListener(pid: 500, port: 49152, address: "*:49152"),
            DevServersListener(pid: 600, port: 9999, address: "127.0.0.1:9999"),
            DevServersListener(pid: 200, port: 4000, address: "192.168.1.20:4000"),
        ]
        let servers = DevServersScanner.servers(listeners, process: { processes[$0] }, context: context)
        suite.expect(servers.map(\.port) == [3000, 5173, 5432, 6379, 8000, 54323],
                     "one row per server, sorted by port: \(servers.map(\.port))")
        let next = servers.first { $0.kind == .next }
        suite.expect(next?.ports == [3000] && next?.project == "Swift-portfolio",
                     "IPv4 and IPv6 binds of one port are one server, named for its folder")
        let vite = servers.first { $0.kind == .vite }
        suite.expect(vite?.ports == [5173, 24678] && vite?.port == 5173,
                     "a process on two local ports is one server, its first port the URL's; a LAN bind is left out")
        let uvicorn = servers.first { $0.kind == .uvicorn }
        suite.expect(uvicorn?.pid == 300 && servers.filter { $0.kind == .uvicorn }.count == 1,
                     "a forked worker sharing its parent's socket is the parent")
        let supabase = servers.first { $0.kind == .supabase }
        suite.expect(supabase?.ports == [54321, 54322, 54323, 54324] && supabase?.port == 54323 && supabase?.project == nil,
                     "Supabase's stack is one row that opens Studio")
        suite.expect(servers.filter { $0.kind == .docker }.map(\.port) == [5432, 6379]
                     && servers.filter { $0.kind == .docker }.allSatisfy { $0.project == nil && !$0.canKill },
                     "each Docker forward is its own row, without a project and without Kill")
        suite.expect(Set(servers.map(\.id)).count == servers.count, "every row has its own id")
        let entries = [PortManagerEntry(port: 3000, protocolName: "TCP", address: "*:3000", pid: 100, processName: "node",
                                        startedAt: nil),
                       PortManagerEntry(port: 53, protocolName: "UDP", address: "*:53", pid: 100, processName: "node",
                                        startedAt: nil)]
        suite.expect(DevServersScanner.listeners(entries) == [DevServersListener(pid: 100, port: 3000, address: "*:3000")],
                     "only the Port Manager's TCP listeners are read")
        let parsed = PortManagerSupport.parseLsof("p100\ncnode\nPTCP\nn*:3000\nTST=LISTEN\nn[::1]:3000\n")
        suite.expect(DevServersScanner.servers(DevServersScanner.listeners(parsed), process: { processes[$0] }, context: context)
                        .map(\.kind) == [.next],
                     "lsof's own output reads through the Port Manager's parser")
    }

    private static func procArgs(_ suite: TestSuite) {
        func buffer(argc: Int32, _ strings: [String], padding: Int = 3) -> [UInt8] {
            var bytes = withUnsafeBytes(of: argc.littleEndian) { Array($0) }
            bytes += Array("/usr/local/bin/node".utf8) + [UInt8](repeating: 0, count: padding)
            for string in strings { bytes += Array(string.utf8) + [0] }
            return bytes
        }
        suite.expect(DevServersProcArgs.arguments(buffer(argc: 3, ["node", "server.js", "--watch", "PATH=/usr/bin", "HOME=/x"]))
                        == ["node", "server.js", "--watch"],
                     "argv is read and the environment after it is not")
        suite.expect(DevServersProcArgs.arguments(buffer(argc: 3, ["next-server (v15.0.3)", "", ""])) == ["next-server (v15.0.3)"],
                     "a process that renamed itself keeps its new title")
        suite.expect(DevServersProcArgs.arguments([1, 0]) == [] && DevServersProcArgs.arguments(buffer(argc: 0, ["x"])) == [],
                     "a short or empty buffer gives nothing")
    }

    private static func extras(_ suite: TestSuite) {
        suite.expect(DevServersExtras.ports(from: "3000, 8080 9000-9002;4000") == [3000, 4000, 8080, 9000, 9001, 9002],
                     "ports and ranges split by commas, spaces or semicolons")
        suite.expect(DevServersExtras.ports(from: "70000, abc, 0, 10-5, 1-1000") == [],
                     "what is not a port, a backwards range or a huge range adds nothing")
        suite.expect(DevServersExtras.names(from: " Caddy, hugo ;\nphp-fpm") == ["caddy", "hugo", "php-fpm"],
                     "names are matched without case")
        let caddy = process("caddy", ["/opt/homebrew/bin/caddy", "run"])
        suite.expect(kind(caddy, port: 2019, extras: DevServersExtras(ports: "", names: "caddy")) == .custom
                     && kind(caddy, port: 2019, extras: DevServersExtras(ports: "2019", names: "")) == .custom,
                     "a listed name or port makes a dev server")
        suite.expect(kind(process("node", ["node", "/x/node_modules/.bin/vite"]), port: 2019,
                          extras: DevServersExtras(ports: "2019", names: "")) == .vite,
                     "a recognised framework keeps its name on a listed port")
    }

    // MARK: Coalescing

    private static func server(_ project: String?, port: Int, start: UInt64) -> DevServer {
        DevServer(id: "pid:\(start)@\(start)", kind: .next, pid: Int32(start), processName: "node", project: project,
                  ports: [port], port: port, startedAt: nil, startMicros: start)
    }

    private static func coalescing(_ suite: TestSuite) {
        var announcer = DevServersAnnouncer()
        let portfolio = server("Swift-portfolio", port: 3000, start: 1)
        suite.expect(announcer.update([portfolio], now: 0).isEmpty, "what already runs at the first look is the baseline")
        let admin = server("admin", port: 5173, start: 2)
        suite.expect(announcer.update([portfolio, admin], now: 10).map(\.id) == [admin.id], "a new server is announced")
        let restarted = server("admin", port: 5173, start: 3)
        suite.expect(announcer.update([portfolio, restarted], now: 20).isEmpty, "a hot restart in place stays quiet")
        suite.expect(announcer.update([portfolio], now: 30).isEmpty, "a server going says nothing")
        suite.expect(announcer.update([portfolio, server("admin", port: 5173, start: 4)], now: 45).isEmpty,
                     "coming back within 30 seconds of last being seen is the same server restarting")
        for look in stride(from: 50.0, through: 80, by: 10) { _ = announcer.update([portfolio], now: look) }
        suite.expect(announcer.update([portfolio, server("admin", port: 5173, start: 5)], now: 90).map(\.project) == ["admin"],
                     "coming back after longer is announced again, and what kept running is not")
        suite.expect(announcer.update([portfolio, server("admin", port: 5174, start: 6)], now: 95).count == 1,
                     "the same project on another port is another server")
        let twins = [server("api", port: 8000, start: 7), server("api", port: 8000, start: 8)]
        suite.expect(announcer.update(twins + [portfolio], now: 100).count == 1, "two of the same key in one look announce once")
        announcer.reset()
        suite.expect(announcer.update([portfolio, server("new", port: 4000, start: 9)], now: 110).isEmpty,
                     "after a reset the next look is a baseline again")
        suite.expect(portfolio.coalescingKey == "Swift-portfolio|3000"
                     && server(nil, port: 3000, start: 1).coalescingKey == "Next.js|3000",
                     "the key is the project, or the framework, and the port")
    }

    // MARK: Kill

    private static func killConfirmation(_ suite: TestSuite) {
        var kill = DevServersKillConfirmation()
        suite.expect(kill.press("a", now: 0) == .confirm && kill.isConfirming("a", now: 1) && !kill.isStopping("a"),
                     "a first click asks Kill?")
        suite.expect(!kill.isConfirming("b", now: 1), "only that row asks")
        suite.expect(kill.press("a", now: 2.5) == .kill && kill.isStopping("a") && !kill.isConfirming("a", now: 2.5),
                     "a second click within the window stops it")
        suite.expect(kill.press("a", now: 2.6) == .ignored, "a server already stopping takes no more clicks")
        suite.expect(kill.press("b", now: 3) == .confirm && kill.press("c", now: 3.5) == .confirm
                     && !kill.isConfirming("b", now: 3.5) && kill.isConfirming("c", now: 3.5),
                     "asking on another row moves the question there")
        suite.expect(kill.press("b", now: 4) == .confirm, "so the first row asks again rather than stopping")
        suite.expect(!kill.isConfirming("b", now: 4 + DevServersKillConfirmation.window + 0.01),
                     "the question lapses after the window")
        kill.expire(now: 4 + DevServersKillConfirmation.window + 0.01)
        suite.expect(kill.confirming == nil && kill.press("b", now: 10) == .confirm, "a late click asks again")
        kill.cancel()
        suite.expect(kill.confirming == nil, "cancelling drops the question")
        _ = kill.press("d", now: 20)
        kill.keep(["b", "c"])
        suite.expect(!kill.isStopping("a") && kill.confirming == nil, "a server that left is no longer stopping or asked about")
        suite.expect(DevServersKillConfirmation.window == 3 && DevServersKillConfirmation.escalation == 3,
                     "SIGKILL follows SIGTERM after 3 seconds")
        suite.expect(!DevServer(id: "x", kind: .vite, pid: 10, processName: "node", project: nil, ports: [5173], port: 5173,
                                startedAt: nil, startMicros: nil).canKill,
                     "a server whose start time is unknown cannot be killed, so a reused pid is never signalled")
    }

    // MARK: Notice

    private static func notice(_ suite: TestSuite) {
        suite.expect(ZenithNotice.Kind.devServer.priority == 1 && ZenithNoticeTiming.duration(.devServer) == 5
                     && ZenithNoticeQueue.lifetime(.devServer) == 20,
                     "a new server's notice is low priority, stays 5 seconds and waits up to 20")
        var queue = ZenithNoticeQueue()
        let url = URL(string: "http://localhost:3000")!
        func notice(_ title: String) -> ZenithNotice {
            ZenithNotice(kind: .devServer, key: ZenithNoticeKey.devServer("Swift-portfolio|3000"), title: title,
                         subtitle: "", accessory: .action("Open"), action: .openURL(url))
        }
        suite.expect(queue.enqueue(notice("a"), now: 0) == .queued && queue.enqueue(notice("b"), now: 1) == .coalesced,
                     "the same project and port waiting is updated in place")
        suite.expect(queue.next(now: 2)?.action == .openURL(url), "a click opens the server")
    }

    // MARK: Settings

    private static func settings(_ suite: TestSuite) {
        let name = "com.vorssaint.tests.dev-servers"
        guard let defaults = UserDefaults(suiteName: name) else {
            suite.expect(false, "the isolated defaults suite opens")
            return
        }
        defaults.removePersistentDomain(forName: name)
        defer { defaults.removePersistentDomain(forName: name) }
        let fresh = DevServersOptions.current(in: defaults)
        suite.expect(fresh.enabled && fresh.announces && !fresh.indicator && fresh.extras == DevServersExtras(),
                     "detection and the notice start on, the closed island's count off")
        suite.expect(fresh.watchesInBackground, "the notice needs a background look")
        defaults.set(false, forKey: DefaultsKey.notchDevServersAnnounce)
        suite.expect(!DevServersOptions.current(in: defaults).watchesInBackground,
                     "with neither the notice nor the count, nothing looks in the background")
        defaults.set(true, forKey: DefaultsKey.notchDevServersIndicator)
        suite.expect(DevServersOptions.current(in: defaults).watchesInBackground, "the count needs one too")
        defaults.set(false, forKey: DefaultsKey.notchDevServersEnabled)
        suite.expect(!DevServersOptions.current(in: defaults).watchesInBackground && !DevServersOptions.isEnabled(in: defaults),
                     "detection off stops everything")
        defaults.set("3000, 4000-4001", forKey: DefaultsKey.notchDevServersExtraPorts)
        defaults.set("Caddy", forKey: DefaultsKey.notchDevServersExtraNames)
        suite.expect(DevServersOptions.current(in: defaults).extras == DevServersExtras(ports: [3000, 4000, 4001], names: ["caddy"]),
                     "extra ports and names are read from their fields")
        let registered = Defaults.registeredDefaults
        suite.expect(registered[DefaultsKey.notchDevServersEnabled] as? Bool == true
                     && registered[DefaultsKey.notchDevServersAnnounce] as? Bool == true
                     && registered[DefaultsKey.notchDevServersIndicator] as? Bool == false
                     && registered[DefaultsKey.notchDevServersExtraPorts] as? String == ""
                     && registered[DefaultsKey.notchDevServersExtraNames] as? String == "",
                     "the section's settings are registered, so they join backups")
        defaults.set(true, forKey: DefaultsKey.notchDevServersEnabled)
        suite.expect(NotchSupport.modules(in: defaults).contains(.devServers), "the page shows while detection is on")
        defaults.set(false, forKey: DefaultsKey.notchDevServersEnabled)
        suite.expect(!NotchSupport.modules(in: defaults).contains(.devServers), "and leaves when it is off")
    }

    // MARK: Island

    private static func island(_ suite: TestSuite) {
        suite.expect(NotchSupport.compactActivities(timer: false, downloads: false, agents: false, calendar: false, music: true,
                                                    keepAwake: true, devServers: true) == [.music, .devServers, .keepAwake],
                     "the count waits behind music and goes before Keep Awake")
        suite.expect(NotchCompactActivity.devServers.module == .devServers, "a click on the count opens the page")
        suite.expect(NotchModule.devServers.shortcutKey == "l"
                     && Set(NotchModule.allCases.map(\.shortcutKey)).count == NotchModule.allCases.count,
                     "the page has a shortcut of its own")
        suite.expect(ZenithHomeWidget.devServers.module == .devServers
                     && ZenithHomeWidget.devServers.hex == ZenithIslandPalette.hex(.devServers),
                     "the home widget wears its page's colour")
        suite.expect(DevServerKind.allCases.allSatisfy { $0.hex != 0 }, "every framework has a tint")
    }

    // MARK: A real listener

    /// Opens a TCP listener on a random loopback port in this process, reads
    /// the listening ports the way the Port Manager does (the same lsof
    /// arguments and parser), and follows it through the probe and the
    /// scanner. Nothing is signalled; the socket closes at the end.
    private static func liveListener(_ suite: TestSuite) {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else {
            suite.expect(false, "a test socket opens")
            return
        }
        defer { close(fd) }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        guard bound == 0, listen(fd, 4) == 0 else {
            suite.expect(false, "the test socket listens on loopback")
            return
        }
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &length) }
        }
        let port = Int(UInt16(bigEndian: address.sin_port))
        suite.expect(port > 0, "the listener has a port")

        let lsof = Process()
        lsof.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        lsof.arguments = ["-nP", "+c0", "-iTCP", "-sTCP:LISTEN", "-F", "pcnPT"]
        let pipe = Pipe()
        lsof.standardOutput = pipe
        lsof.standardError = FileHandle.nullDevice
        do { try lsof.run() } catch {
            suite.expect(false, "lsof runs without privileges")
            return
        }
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        lsof.waitUntilExit()
        let own = ProcessInfo.processInfo.processIdentifier
        let entries = PortManagerSupport.parseLsof(output)
        let entry = entries.first { $0.pid == own && $0.port == port }
        suite.expect(entry != nil && entry?.address == "127.0.0.1:\(port)",
                     "the Port Manager's listing finds a listener this process opened")
        guard let entry else { return }

        let probed = DevServersProbe.process(pid: own, name: entry.processName)
        suite.expect(probed?.uid == getuid() && probed?.startMicros != nil && probed?.startedAt != nil,
                     "the probe reads the listener's owner and start without privileges")
        suite.expect(probed?.cwd == FileManager.default.currentDirectoryPath,
                     "the probe reads the process's folder: \(probed?.cwd ?? "nil")")
        suite.expect(probed.map { !$0.arguments.isEmpty && DevServersClassifier.basename($0.arguments[0]) == "metrics-tests" } == true,
                     "the probe reads the process's arguments")
        suite.expect(DevServersProbe.process(pid: -1, name: "") == nil, "a pid that is not there reads as nothing")

        let listeners = DevServersScanner.listeners(entries)
        let real = DevServersContext.current
        suite.expect(!DevServersScanner.servers(listeners, process: { DevServersProbe.process(pid: $0, name: "") },
                                                extras: DevServersExtras(ports: [port]), context: real)
                        .contains { $0.pid == own },
                     "the app's own listener is never a dev server")
        var elsewhere = real
        elsewhere.ownPID = 0
        let found = DevServersScanner.servers(listeners, process: { pid in
            pid == own ? DevServersProbe.process(pid: pid, name: entry.processName) : nil
        }, extras: DevServersExtras(ports: [port]), context: elsewhere)
        let mine = found.first { $0.pid == own }
        suite.expect(mine?.kind == .custom && mine?.port == port && mine?.host == "localhost:\(port)"
                     && mine?.project == DevServersNaming.project(cwd: FileManager.default.currentDirectoryPath, home: real.home)
                     && mine?.canKill == true,
                     "a listed port's listener is found, named for its folder and offered Kill")
    }

    // MARK: Strings

    private static func strings(_ suite: TestSuite) {
        for language in AppLanguage.allCases {
            let text = ZenithStrings.devServers(language)
            let values = Mirror(reflecting: text).children.compactMap { $0.value as? String }
            suite.expect(values.count == 25 && values.allSatisfy { !$0.isEmpty && !$0.contains("'") && !$0.contains("\u{2014}") },
                         "\(language.rawValue) words dev servers, with curly apostrophes and no em dash")
            suite.expect(text.runningFor.contains("%@") && text.running.contains("%@"), "\(language.rawValue) places its values")
        }
    }
}
