// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: lock and check status from an iPhone (RemoteControlSupport):
/// reading requests, cleaning device names, the rate limit, the status
/// text, the authorized_keys edits and the forced-command script. Every
/// file lives in a temporary folder; the real ~/.ssh, Application Support
/// and preferences are never touched, nothing locks and nothing runs ssh.
enum RemoteControlTests {
    static func run(_ suite: TestSuite) {
        requests(suite)
        names(suite)
        rateLimit(suite)
        status(suite)
        island(suite)
        tailscale(suite)
        strings(suite)
        keys(suite)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("zenith-remote-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        guard (try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)) != nil else {
            suite.expect(false, "a temporary folder for the remote tests")
            return
        }
        authorizedKeysFile(suite, root: root)
        script(suite, root: root)
    }

    private static let now = Date(timeIntervalSince1970: 1_795_300_000)

    private static func request(_ lines: [String]) -> Data { Data((lines.joined(separator: "\n") + "\n").utf8) }

    // MARK: Requests

    private static func requests(_ suite: TestSuite) {
        let sent = "\(Int(now.timeIntervalSince1970) - 1)"
        let good = RemoteRequestParser.parse(request(["zenith-remote 1", "lock", sent, "Faiz’s iPhone"]),
                                             id: "1795299999-123-456", modified: now, now: now)
        suite.expect(good == .success(RemoteRequest(id: "1795299999-123-456", verb: .lock, device: "Faiz’s iPhone",
                                                    sent: now.addingTimeInterval(-1))),
                     "a fresh lock request reads its verb, device and time")
        let status = RemoteRequestParser.parse(request(["zenith-remote 1", "status", sent, ""]), id: "a-1",
                                               modified: nil, now: now)
        suite.expect((try? status.get())?.verb == .status && (try? status.get())?.device == "iPhone",
                     "a status request without a name is from “iPhone”")
        suite.expect(RemoteRequestParser.parse(request(["zenith-remote 1", "status", sent]), id: "a-2", modified: nil,
                                               now: now) != .failure(.malformed),
                     "the name line may be missing")

        for id in ["", "../x", "a/b", "a b", "x.req", String(repeating: "1", count: 65), "١٢٣"] {
            suite.expect(RemoteRequestParser.parse(request(["zenith-remote 1", "lock", sent]), id: id, modified: nil,
                                                   now: now) == .failure(.badID),
                         "a request named “\(id)” is refused")
        }
        let huge = Data(repeating: 0x61, count: RemoteControl.maximumRequestBytes + 1)
        suite.expect(RemoteRequestParser.parse(huge, id: "1", modified: nil, now: now) == .failure(.tooLarge),
                     "a request larger than the limit is refused")
        suite.expect(RemoteRequestParser.parse(request(["zenith-remote 2", "lock", sent]), id: "1", modified: nil,
                                               now: now) == .failure(.malformed),
                     "an unknown header is refused")
        suite.expect(RemoteRequestParser.parse(request(["zenith-remote 1", "lock", "soon"]), id: "1", modified: nil,
                                               now: now) == .failure(.malformed),
                     "a time that is not a number is refused")
        for verb in ["unlock", "LOCK", "rm -rf /", "status; lock", "run", ""] {
            suite.expect(RemoteRequestParser.parse(request(["zenith-remote 1", verb, sent]), id: "1", modified: nil,
                                                   now: now) == .failure(.unknownVerb),
                         "the verb “\(verb)” is refused")
        }
        let old = "\(Int(now.timeIntervalSince1970) - 11)"
        let ahead = "\(Int(now.timeIntervalSince1970) + 5)"
        suite.expect(RemoteRequestParser.parse(request(["zenith-remote 1", "lock", old]), id: "1", modified: nil,
                                               now: now) == .failure(.stale),
                     "a request older than 10 s is refused")
        suite.expect(RemoteRequestParser.parse(request(["zenith-remote 1", "lock", ahead]), id: "1", modified: nil,
                                               now: now) == .failure(.stale),
                     "a request from the future is refused")
        suite.expect(RemoteRequestParser.parse(request(["zenith-remote 1", "lock", sent]), id: "1",
                                               modified: now.addingTimeInterval(-30), now: now) == .failure(.stale),
                     "an old file is refused even when its text claims to be fresh")
        let answer = String(decoding: RemoteRequestParser.response(status: 0, text: "MacBook locked ✓"), as: UTF8.self)
        suite.expect(answer == "0\nMacBook locked ✓\n", "an answer is the exit status, then the text")
    }

    // MARK: Device names

    private static func names(_ suite: TestSuite) {
        let cases: [(String, String)] = [
            ("Faiz’s iPhone", "Faiz’s iPhone"),
            ("  Faiz’s   iPhone  ", "Faiz’s iPhone"),
            ("\"Faiz’s iPhone\"", "Faiz’s iPhone"),
            ("'Work iPhone'", "Work iPhone"),
            ("“Faiz’s iPhone”", "Faiz’s iPhone"),
            ("Faiz\u{202E}enohPi", "FaizenohPi"),
            ("a\u{0}b\u{7}c\nd\te", "a b c d e"),
            ("", "iPhone"),
            ("   ", "iPhone"),
            ("\"\"", "iPhone"),
            (String(repeating: "x", count: 50), String(repeating: "x", count: 40)),
            (String(repeating: "é", count: 45), String(repeating: "é", count: 40)),
            ("iPhone 📱", "iPhone 📱"),
        ]
        for (raw, expected) in cases {
            let clean = RemoteDeviceName.sanitize(raw)
            suite.expect(clean == expected, "“\(raw.debugDescription)” cleans to “\(expected)”, got “\(clean)”")
        }
        let everything = (0..<200).map { RemoteDeviceName.sanitize("dev\(Character(UnicodeScalar($0)!))ice") }
        suite.expect(everything.allSatisfy { name in
            name.count <= 40 && !name.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
        }, "no control character ever survives")
        suite.expect(RemoteDeviceName.short("Faiz’s iPhone") == "iPhone" && RemoteDeviceName.short("Faiz's iPad") == "iPad"
                     && RemoteDeviceName.short("Work iPhone") == "Work iPhone" && RemoteDeviceName.short("iPhone") == "iPhone",
                     "the welcome back says the kind of device")
    }

    // MARK: Rate limit

    private static func rateLimit(_ suite: TestSuite) {
        var limiter = RemoteRateLimiter()
        let first = (0..<10).map { limiter.allow(at: now.addingTimeInterval(Double($0))) }
        suite.expect(first.allSatisfy { $0 }, "ten requests in a minute pass")
        suite.expect(!limiter.allow(at: now.addingTimeInterval(20)), "the eleventh within the minute is refused")
        suite.expect(!limiter.allow(at: now.addingTimeInterval(59.5)), "still refused just before the minute is over")
        suite.expect(limiter.allow(at: now.addingTimeInterval(60.5)), "a minute after the first, one more passes")
    }

    // MARK: Status

    private static func status(_ suite: TestSuite) {
        var input = RemoteStatusInput()
        input.since = now.addingTimeInterval(-(3 * 3600 + 12 * 60))
        input.batteryPercent = 82
        input.charge = .charging
        input.jobs = [.init(title: RemoteStatusText.jobTitle(prefix: "Export", label: "DaVinci"), fraction: 0.623)]
        input.title = "Here With Me"
        input.artist = "d4vd"
        input.wakaTimeSeconds = 4 * 3600 + 56 * 60 + 10
        suite.expect(RemoteStatusText.make(input, now: now) == """
            Unlocked · in use 3h 12m
            Battery 82% · charging
            Export DaVinci 62%
            Here With Me · d4vd
            WakaTime today 4h 56m
            """, "the full status reads like the approved design")

        var locked = RemoteStatusInput()
        locked.locked = true
        locked.since = now.addingTimeInterval(-80 * 60)
        suite.expect(RemoteStatusText.make(locked, now: now) == "Locked · 1h 20m", "locked, it says for how long")
        locked.since = nil
        suite.expect(RemoteStatusText.make(locked, now: now) == "Locked", "locked since before Zenith knew: just Locked")
        suite.expect(RemoteStatusText.make(RemoteStatusInput(), now: now) == "Unlocked",
                     "only lines with data: an empty Mac says Unlocked")

        var more = RemoteStatusInput()
        more.batteryPercent = 140
        more.charge = .onBattery
        more.jobs = [.init(title: "Backup", fraction: nil), .init(title: "", fraction: 0.5),
                     .init(title: "a\nb", fraction: 2), .init(title: "x", fraction: 0.1), .init(title: "y", fraction: 0.2)]
        more.title = "Song"
        more.wakaTimeSeconds = 30
        let lines = RemoteStatusText.make(more, now: now).split(separator: "\n").map(String.init)
        suite.expect(lines == ["Unlocked", "Battery 100% · on battery", "Backup running", "a b 100%", "Song"],
                     "figures are clamped, a job without one is running, at most three jobs, a title without an artist, under a minute of WakaTime is left out: \(lines)")
        suite.expect(RemoteStatusText.jobTitle(prefix: "Import", label: "Import") == "Import"
                     && RemoteStatusText.jobTitle(prefix: nil, label: "npm run build") == "npm run build"
                     && RemoteStatusText.jobTitle(prefix: "Vercel", label: "") == "Vercel",
                     "a job's title says what it is once")
        suite.expect(RemoteDuration.text(40) == "40s" && RemoteDuration.text(0) == "1s" && RemoteDuration.text(45 * 60) == "45m"
                     && RemoteDuration.text(3600) == "1h" && RemoteDuration.text(26 * 3600) == "1d 2h"
                     && RemoteDuration.text(-5) == "1s" && RemoteDuration.text(.infinity) == "1s",
                     "durations are short and English")
    }

    // MARK: Island

    private static func island(_ suite: TestSuite) {
        let burst = ZenithIslandBurst(.remote(ZenithRemoteBurst(device: "Faiz’s iPhone")), start: now)
        suite.expect(burst.title == "Faiz’s iPhone" && burst.subtitle == "checked status" && burst.duration == 2
                     && burst.event == .timer && burst.module == nil,
                     "an iPhone checking shows its name and “checked status” for 2 s")
        suite.expect(ZenithIslandBurstLayout.contentWidth(burst) > 100
                     && ZenithIslandBurstLayout.minimumWidth(burst) == 320
                     && ZenithIslandBurstLayout.contentHeight(burst) == ZenithIslandBurstLayout.remoteRow,
                     "the status burst is one line")
        let prayer = ZenithIslandBurst(.prayer(ZenithPrayerBurst(symbol: "sun.max", title: "Waktunya Ashar", subtitle: "",
                                                                 nextLabel: "Next", next: nil)), start: now)
        suite.expect(!ZenithIslandBurstTiming.replaces(prayer, with: burst, at: now.addingTimeInterval(1)),
                     "an iPhone checking never cuts a prayer's time short")
        suite.expect(ZenithIslandBurstTiming.patience(burst.content) == 5, "an open island makes it wait at most 5 s")

        suite.expect(RemoteText.welcomeDetail(device: "Faiz’s iPhone", seconds: 80 * 60) == "Locked from iPhone · 1h 20m ago",
                     "the welcome back after a remote lock says so")
        suite.expect(RemoteText.lockedFrom("Faiz’s iPhone") == "Locked from Faiz’s iPhone" && RemoteText.justNow == "just now"
                     && ZenithLockIsland.remoteHold == 3,
                     "the lock screen island says who locked it, for about 3 s")
        suite.expect(ZenithLockIslandMoment.remoteLock(device: "a") != .farewell, "a remote lock replaces the farewell")
        suite.expect(RemoteText.locked(macBook: true) == "MacBook locked ✓", "the lock answer")

        ZenithRemoteLockMark.mark(device: "Faiz’s iPhone", at: now)
        suite.expect(ZenithRemoteLockMark.take(at: now.addingTimeInterval(2)) == "Faiz’s iPhone",
                     "the lock island takes the remote mark as the Mac locks")
        suite.expect(ZenithRemoteLockMark.take(at: now.addingTimeInterval(3)) == nil, "the mark is taken once")
        ZenithRemoteLockMark.mark(device: "x", at: now)
        suite.expect(ZenithRemoteLockMark.take(at: now.addingTimeInterval(11)) == nil,
                     "a mark nobody took in 10 s does not name a later lock")

        suite.expect(Defaults.registeredDefaults[DefaultsKey.zenithRemoteEnabled] == nil,
                     "the switch stays on this Mac: never in a settings backup, off unless turned on")
        suite.expect(FeatureVisibilitySupport.features(for: .remote).isEmpty, "the page is not gated by a hub feature")
        let aliases = ZenithSettingsSearch.pageAliases[.page(.remote)] ?? []
        suite.expect(["kunci dari iphone", "tailscale", "remote"].allSatisfy(aliases.contains),
                     "Settings search finds the page in English and Indonesian")
    }

    // MARK: Tailscale

    private static func tailscale(_ suite: TestSuite) {
        let json = #"{"Version":"1.80","BackendState":"Running","Self":{"HostName":"Faiz’s MacBook Pro","DNSName":"faizs-macbook-pro.tail1234.ts.net.","TailscaleIPs":["100.64.0.1"]}}"#
        suite.expect(RemoteTailscale.parse(Data(json.utf8)) == .init(running: true, host: "faizs-macbook-pro"),
                     "the MagicDNS name's first label is the host")
        let stopped = #"{"BackendState":"NeedsLogin","Self":{"DNSName":""}}"#
        suite.expect(RemoteTailscale.parse(Data(stopped.utf8)) == .init(running: false, host: nil),
                     "signed out, there is no host")
        suite.expect(RemoteTailscale.parse(Data("not json".utf8)) == nil, "anything else reads as nothing")
        suite.expect(RemoteTailscale.localHost("Faizs-MacBook-Pro") == "faizs-macbook-pro.local"
                     && RemoteTailscale.localHost(nil) == nil && RemoteTailscale.shortHost("bad name") == nil,
                     "without Tailscale the local host name stands in")
    }

    // MARK: Strings

    private static func strings(_ suite: TestSuite) {
        for language in AppLanguage.allCases {
            let text = ZenithStrings.remote(language)
            suite.expect(text.all.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                         && !text.all.contains { $0.contains("'") || $0.contains("—") }
                         && text.tailscaleConnected.contains("{host}")
                         && text.connected("faizs-macbook-pro").contains("faizs-macbook-pro"),
                         "\(language.rawValue) words iPhone Remote, with curly apostrophes and no em dash")
            suite.expect(!ZenithRemoteSearch.keywords(language).isEmpty, "\(language.rawValue) has search keywords")
        }
        suite.expect(RemoteScript.shortcutScript(.lock, device: "Faiz’s iPhone") == "lock \"Faiz’s iPhone\""
                     && RemoteScript.shortcutScript(.status, device: "") == "status \"iPhone\""
                     && RemoteScript.shortcutScript(.lock, device: "a\"b") == "lock \"ab\"",
                     "the Shortcut's scripts quote the device's name")
        suite.expect(RemoteScript.hardeningCommand.contains("PasswordAuthentication no")
                     && RemoteScript.hardeningCommand.contains("KbdInteractiveAuthentication no")
                     && RemoteScript.hardeningCommand.contains("sudo tee /etc/ssh/sshd_config.d/050-zenith.conf"),
                     "the hardening is a drop-in that sorts before macOS's own")
    }

    // MARK: authorized_keys (text)

    /// A well formed ed25519 key: the type, then 32 bytes.
    private static func key(_ seed: UInt8, type: String = "ssh-ed25519") -> String {
        var bytes: [UInt8] = []
        func string(_ data: [UInt8]) {
            let count = UInt32(data.count)
            bytes += [UInt8(count >> 24), UInt8(count >> 16 & 0xFF), UInt8(count >> 8 & 0xFF), UInt8(count & 0xFF)]
            bytes += data
        }
        string(Array(type.utf8))
        string([UInt8](repeating: seed, count: 32))
        return Data(bytes).base64EncodedString()
    }

    private static let script = "/Users/me/Library/Application Support/id.satuvisual.zenith/remote/zenith-remote"

    private static func keys(_ suite: TestSuite) {
        let blob = key(1)
        let parsed = RemotePublicKey.parse("ssh-ed25519 \(blob) shortcuts@iphone\n")
        suite.expect(parsed == RemotePublicKey(type: "ssh-ed25519", blob: blob), "a pasted public key reads")
        suite.expect(RemotePublicKey.parse("  \n ssh-ed25519   \(blob)  ") == parsed, "spaces and newlines around it are fine")
        for bad in ["", "hello", "ssh-ed25519", "ssh-ed25519 !!!notbase64", "ssh-rsa \(blob)", "ssh-dss \(key(2, type: "ssh-dss"))",
                    "ssh-ed25519 \(Data("short".utf8).base64EncodedString())",
                    "-----BEGIN OPENSSH PRIVATE KEY-----\nb3BlbnNzaC1rZXktdjEAAAAA\n-----END OPENSSH PRIVATE KEY-----"] {
            suite.expect(RemotePublicKey.parse(bad) == nil, "“\(bad.prefix(30))” is not taken as a key")
        }
        suite.expect(RemotePublicKey.parse("ecdsa-sha2-nistp256 \(key(3, type: "ecdsa-sha2-nistp256"))") != nil,
                     "other SSH key types are taken too")

        let key1 = parsed!
        let line = RemoteAuthorizedKeys.line(key: key1, name: "Faiz’s iPhone", script: script)
        suite.expect(line == "restrict,no-pty,no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command=\"/bin/sh '\(script)'\" ssh-ed25519 \(blob) zenith-remote:Faiz’s iPhone",
                     "the line is restricted, forced to the script and marked with the device: \(line ?? "nil")")
        suite.expect(RemoteAuthorizedKeys.line(key: key1, name: "x", script: "/a\"b") == nil
                     && RemoteAuthorizedKeys.line(key: key1, name: "x", script: "/a\nb") == nil,
                     "a script path the line could not carry is refused")
        suite.expect(RemoteScript.command(script: "/x/it's") == "/bin/sh '/x/it'\\''s'", "the script path is quoted")

        let other = "ssh-ed25519 \(key(9)) faiz@laptop"
        let existing = "# my keys\n\(other)\n"
        let (added, outcome) = RemoteAuthorizedKeys.adding(key1, name: "Faiz’s iPhone", script: script, to: existing)
        suite.expect(outcome == .changed && added == existing + line! + "\n", "adding appends one line and keeps the rest")
        suite.expect(RemoteAuthorizedKeys.adding(key1, name: "Faiz’s iPhone", script: script, to: added) == (added, .unchanged),
                     "adding the same key again changes nothing")
        let (renamed, renamedOutcome) = RemoteAuthorizedKeys.adding(key1, name: "Work iPhone", script: script, to: added)
        suite.expect(renamedOutcome == .changed && RemoteAuthorizedKeys.devices(in: renamed).map(\.name) == ["Work iPhone"]
                     && renamed.components(separatedBy: blob).count == 2,
                     "adding it with a new name replaces Zenith's own line, never doubles it")
        let (noNewline, _) = RemoteAuthorizedKeys.adding(key1, name: "a", script: script, to: other)
        suite.expect(noNewline.hasPrefix(other + "\n") && noNewline.hasSuffix("zenith-remote:a\n"),
                     "a file without a final newline gets one before the new line")
        let plain = "ssh-ed25519 \(blob) faiz@iphone\n"
        suite.expect(RemoteAuthorizedKeys.adding(key1, name: "x", script: script, to: plain) == (plain, .conflict),
                     "a key already there without the restrictions is a conflict, left alone")
        let optioned = "from=\"10.0.0.1\" ssh-ed25519 \(blob) zenith-remote:fake\n"
        suite.expect(RemoteAuthorizedKeys.adding(key1, name: "x", script: script, to: optioned).1 == .conflict
                     && RemoteAuthorizedKeys.devices(in: optioned).isEmpty,
                     "a line that only carries the marker is not Zenith's")

        let key2 = RemotePublicKey(type: "ssh-ed25519", blob: key(2))
        let (both, _) = RemoteAuthorizedKeys.adding(key2, name: "iPad", script: script, to: added)
        suite.expect(RemoteAuthorizedKeys.devices(in: both) == [RemoteDevice(name: "Faiz’s iPhone", key: key1),
                                                                RemoteDevice(name: "iPad", key: key2)],
                     "the devices read back in order, the path's spaces inside the quotes included")
        let (removed, removedOutcome) = RemoteAuthorizedKeys.removing(key1.blob, from: both)
        suite.expect(removedOutcome == .changed && removed.contains(other) && removed.hasPrefix("# my keys\n")
                     && RemoteAuthorizedKeys.devices(in: removed).map(\.name) == ["iPad"],
                     "removing takes only that device's line")
        suite.expect(RemoteAuthorizedKeys.removing(key(9), from: both).1 == .notFound,
                     "a key Zenith did not add is never removed")
        let (empty, _) = RemoteAuthorizedKeys.removing(key2.blob, from: removed)
        suite.expect(empty == existing, "adding then removing every device gives back the file as it was")
    }

    // MARK: authorized_keys (the file)

    fileprivate static func mode(_ url: URL) -> Int? {
        ((try? FileManager.default.attributesOfItem(atPath: url.path))?[.posixPermissions] as? NSNumber)?.intValue
    }

    private static func authorizedKeysFile(_ suite: TestSuite, root: URL) {
        let manager = FileManager.default
        let ssh = root.appendingPathComponent("home/.ssh", isDirectory: true)
        let file = ssh.appendingPathComponent("authorized_keys")
        let backup = ssh.appendingPathComponent("authorized_keys.zenith-backup")
        let key1 = RemotePublicKey(type: "ssh-ed25519", blob: key(1))
        let key2 = RemotePublicKey(type: "ssh-ed25519", blob: key(2))

        suite.expect(RemoteAuthorizedKeys.add(key1, name: "Faiz’s iPhone", script: script, ssh: ssh) == .changed,
                     "adding to a Mac without ~/.ssh works")
        suite.expect(mode(ssh) == 0o700 && mode(file) == 0o600, "~/.ssh is made 0700 and the file 0600")
        suite.expect(!manager.fileExists(atPath: backup.path), "with no file before, there is nothing to back up")
        let first = try? String(contentsOf: file, encoding: .utf8)
        suite.expect(RemoteAuthorizedKeys.add(key1, name: "Faiz’s iPhone", script: script, ssh: ssh) == .unchanged
                     && (try? String(contentsOf: file, encoding: .utf8)) == first && !manager.fileExists(atPath: backup.path),
                     "adding it again neither writes nor backs up")
        suite.expect(RemoteAuthorizedKeys.add(key2, name: "iPad", script: script, ssh: ssh) == .changed
                     && (try? String(contentsOf: backup, encoding: .utf8)) == first && mode(backup) == 0o600,
                     "before a change the file as it was is kept, 0600")
        suite.expect(RemoteAuthorizedKeys.devices(ssh: ssh).map(\.name) == ["Faiz’s iPhone", "iPad"], "both devices read back")
        try? manager.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file.path)
        suite.expect(RemoteAuthorizedKeys.remove(key1.blob, ssh: ssh) == .changed && mode(file) == 0o600
                     && RemoteAuthorizedKeys.devices(ssh: ssh).map(\.name) == ["iPad"],
                     "removing a device writes the file 0600 again")
        suite.expect(RemoteAuthorizedKeys.remove(key1.blob, ssh: ssh) == .notFound, "removing it twice changes nothing")

        // A user's own line stays, and blocks the same key.
        let mine = "ssh-ed25519 \(key(7)) me@laptop\n"
        try? Data(mine.utf8).write(to: file)
        suite.expect(RemoteAuthorizedKeys.add(RemotePublicKey(type: "ssh-ed25519", blob: key(7)), name: "x", script: script,
                                              ssh: ssh) == .conflict
                     && (try? String(contentsOf: file, encoding: .utf8)) == mine,
                     "the person's own line for the same key is left exactly as it was")

        // A link is never followed or replaced.
        let elsewhere = root.appendingPathComponent("elsewhere")
        try? Data(mine.utf8).write(to: elsewhere)
        try? manager.removeItem(at: file)
        try? manager.createSymbolicLink(at: file, withDestinationURL: elsewhere)
        suite.expect(RemoteAuthorizedKeys.add(key1, name: "x", script: script, ssh: ssh) == .isLink
                     && (try? String(contentsOf: elsewhere, encoding: .utf8)) == mine,
                     "an authorized_keys that is a link is left alone")
    }

    // MARK: The script

    private struct Run {
        let output: String
        let status: Int32
    }

    private static func runScript(_ path: URL, command: String?) -> Run {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [path.path]
        var environment = ["PATH": "/usr/bin:/bin"]
        if let command { environment["SSH_ORIGINAL_COMMAND"] = command }
        process.environment = environment
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return Run(output: "", status: -1) }
        let printed = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return Run(output: String(decoding: printed, as: UTF8.self), status: process.terminationStatus)
    }

    /// Stands in for the app: answers the first request it sees with
    /// `answer(request)`, and hands back what it read.
    private final class Responder: @unchecked Sendable {
        private let lock = NSLock()
        private var seen: [RemoteRequest] = []
        private var seenModes: [Int] = []
        var requests: [RemoteRequest] { lock.withLock { seen } }
        var modes: [Int] { lock.withLock { seenModes } }

        func start(folder: URL, answer: @escaping @Sendable (RemoteRequest) -> (Int32, String)) -> DispatchSemaphore {
            let done = DispatchSemaphore(value: 0)
            let requests = folder.appendingPathComponent(RemoteControl.requestsName)
            let responses = folder.appendingPathComponent(RemoteControl.responsesName)
            DispatchQueue.global().async {
                defer { done.signal() }
                for _ in 0..<150 {
                    let names = (try? FileManager.default.contentsOfDirectory(atPath: requests.path)) ?? []
                    if let name = names.first(where: { $0.hasSuffix(".req") }) {
                        let url = requests.appendingPathComponent(name)
                        let mode = RemoteControlTests.mode(url) ?? -1
                        self.lock.withLock { self.seenModes.append(mode) }
                        let data = (try? Data(contentsOf: url)) ?? Data()
                        try? FileManager.default.removeItem(at: url)
                        let id = String(name.dropLast(4))
                        guard case .success(let request) = RemoteRequestParser.parse(data, id: id, modified: nil, now: Date())
                        else { return }
                        self.lock.withLock { self.seen.append(request) }
                        let (status, text) = answer(request)
                        try? RemoteRequestParser.response(status: status, text: text)
                            .write(to: responses.appendingPathComponent(id), options: .atomic)
                        return
                    }
                    Thread.sleep(forTimeInterval: 0.02)
                }
            }
            return done
        }
    }

    private static func script(_ suite: TestSuite, root: URL) {
        let manager = FileManager.default
        let folder = root.appendingPathComponent("Application Support/it's zenith/remote", isDirectory: true)
        try? manager.createDirectory(at: folder, withIntermediateDirectories: true)
        let path = folder.appendingPathComponent(RemoteControl.scriptName)
        let text = RemoteScript.text(folder: folder.path, waitTenths: 15)
        try? Data(text.utf8).write(to: path)
        suite.expect(text.hasPrefix("#!/bin/sh\n# zenith-remote:") && text.contains("d='" + folder.path.replacingOccurrences(of: "'", with: "'\\''") + "'"),
                     "the script names itself and quotes its folder")
        let code = text.split(separator: "\n").filter { !$0.hasPrefix("#") }.joined(separator: "\n")
        suite.expect(!["curl", "nc ", "wget", "ssh ", "osascript", "python", "perl", "eval", "exec ", "unlock"].contains { code.contains($0) },
                     "the script uses no network, no interpreter and never evaluates what it is sent")
        suite.expect(RemoteScript.text(folder: "/x").contains("-lt 40 ]"), "the iPhone waits up to 4 s for the answer")

        // Zenith not running: no process id, or a dead one.
        let notRunning = runScript(path, command: "lock")
        suite.expect(notRunning.output == "Zenith isn't running\n" && notRunning.status == 1,
                     "without Zenith the script says so: \(notRunning.output)")
        let requests = folder.appendingPathComponent(RemoteControl.requestsName)
        let responses = folder.appendingPathComponent(RemoteControl.responsesName)
        try? manager.createDirectory(at: requests, withIntermediateDirectories: true)
        try? manager.createDirectory(at: responses, withIntermediateDirectories: true)
        let pid = folder.appendingPathComponent(RemoteControl.pidName)
        try? Data("999999\n".utf8).write(to: pid)
        suite.expect(runScript(path, command: "status").output == "Zenith isn't running\n", "a process id that is gone is not running")
        try? Data("12; rm -rf /\n".utf8).write(to: pid)
        suite.expect(runScript(path, command: "status").output == "Zenith isn't running\n", "a process id that is not a number is not running")
        try? Data("\(ProcessInfo.processInfo.processIdentifier)\n".utf8).write(to: pid)

        // Anything but lock or status.
        for command in [nil, "", "   ", "unlock", "rm -rf ~", "lock; reboot", "lockx", "sh -c id", "$(id)", "`id`"] as [String?] {
            let run = runScript(path, command: command)
            let leftovers = (try? manager.contentsOfDirectory(atPath: requests.path)) ?? []
            suite.expect(run.status == 2 && run.output == RemoteText.unknown + "\n" && leftovers.isEmpty,
                         "“\(command ?? "nil")” prints the usage, exits 2 and asks nothing: \(run.output)")
        }

        var modes: [Int] = []
        func ask(_ command: String, status: Int32 = 0, answer: String = "ok") -> (Run, RemoteRequest?) {
            let responder = Responder()
            let done = responder.start(folder: folder) { _ in (status, answer) }
            let run = runScript(path, command: command)
            done.wait()
            modes += responder.modes
            return (run, responder.requests.first)
        }

        let (locked, lockRequest) = ask("lock \"Faiz’s iPhone\"", answer: "MacBook locked ✓")
        suite.expect(locked.status == 0 && locked.output == "MacBook locked ✓\n" && lockRequest?.verb == .lock
                     && lockRequest?.device == "Faiz’s iPhone",
                     "lock with a quoted name reaches the app and prints its answer: \(locked.output)")
        let (_, curly) = ask("STATUS “Faiz’s iPhone”")
        suite.expect(curly?.verb == .status && curly?.device == "Faiz’s iPhone",
                     "smart quotes and a capital verb, as iOS may type them, still work: \(curly?.device ?? "nil")")
        let (_, bare) = ask("status")
        suite.expect(bare?.device == "iPhone", "no name means “iPhone”")
        // Process hands its environment over decomposed, so the test uses a character that has no decomposition.
        let (_, long) = ask("  status \t" + String(repeating: "界", count: 50) + "  \r")
        suite.expect(long?.device == String(repeating: "界", count: 40), "the name is cut to 40 characters: \(long?.device ?? "nil")")
        let (_, firstLine) = ask("status\nlock")
        suite.expect(firstLine?.verb == .status, "only the first line counts")
        let (_, control) = ask("status a\u{1}b\u{7f}c")
        suite.expect(control?.device == "abc", "control characters never reach the app")
        let (refused, _) = ask("lock", status: 1, answer: RemoteText.tooMany)
        suite.expect(refused.status == 1 && refused.output == RemoteText.tooMany + "\n", "the app's refusal is the script's exit status")
        let leftovers = ((try? manager.contentsOfDirectory(atPath: requests.path)) ?? [])
            + ((try? manager.contentsOfDirectory(atPath: responses.path)) ?? [])
        suite.expect(leftovers.isEmpty, "every request and answer is removed: \(leftovers)")

        // Zenith running but silent.
        let silent = runScript(path, command: "status")
        let stuck = (try? manager.contentsOfDirectory(atPath: requests.path)) ?? []
        suite.expect(silent.status == 1 && silent.output == "Zenith didn't answer\n" && stuck.isEmpty,
                     "without an answer the script gives up and takes its request back")
        suite.expect(!modes.isEmpty && modes.allSatisfy { $0 == 0o600 }, "requests are written 0600: \(modes)")
    }
}
