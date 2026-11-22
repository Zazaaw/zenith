// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import Darwin
import SystemConfiguration

/// Zenith fork: lock this Mac and check on it from an iPhone.
///
/// While the switch is on, this watches `<container>/remote/requests/` with a
/// DispatchSource (no polling) and answers each request the forced-command
/// script (RemoteScript) leaves there: `lock` locks the screen at once with
/// the same lock Quick Toggles uses; `status` answers a few English lines
/// (RemoteStatusText). Requests are checked (fresh, known, small) and
/// limited to 10 a minute. Nothing else ever runs: no unlock, no command.
/// Off, the request folders and the process id go, so the script answers
/// "Zenith isn't running" without asking.
///
/// It also edits `~/.ssh/authorized_keys` for Settings, touching only the
/// lines it added (RemoteAuthorizedKeys), and reads whether Remote Login and
/// Tailscale are ready.
final class RemoteControlService: ObservableObject {
    static let shared = RemoteControlService()

    struct LogEntry: Identifiable, Equatable {
        enum Outcome: Equatable { case done, refused }
        let id = UUID()
        let date: Date
        let device: String
        let verb: RemoteVerb?
        let outcome: Outcome
    }

    struct Readiness: Equatable {
        var checking = false
        /// Port 22 answers on this Mac.
        var remoteLogin: Bool?
        var tailscaleInstalled: Bool?
        var tailscale: RemoteTailscale.Status?
        /// What the Shortcut connects to: the Tailscale name, else the local host name.
        var host: String?
    }

    @Published private(set) var running = false
    @Published private(set) var log: [LogEntry] = []
    @Published private(set) var devices: [RemoteDevice] = []
    @Published private(set) var readiness = Readiness()
    @Published private(set) var testing = false
    @Published private(set) var testOutput: String?

    private let queue = DispatchQueue(label: "com.vorssaint.zenith.remote", qos: .utility)
    // Main thread.
    private var limiter = RemoteRateLimiter()
    private var observers: [NSObjectProtocol] = []
    private var lockedAt: Date?
    private var unlockedAt: Date?
    private var sampler: PowerSampler?
    // Owned by `queue`.
    private var source: DispatchSourceFileSystemObject?

    private init() {}

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: DefaultsKey.zenithRemoteEnabled) }

    /// `<Application Support>/<bundle id>/remote`.
    static var folderURL: URL? {
        PrivateFileStore.containerURL?.appendingPathComponent(RemoteControl.folderName, isDirectory: true)
    }

    static var scriptURL: URL? {
        folderURL?.appendingPathComponent(RemoteControl.scriptName, isDirectory: false)
    }

    static var sshFolder: URL {
        URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true).appendingPathComponent(".ssh", isDirectory: true)
    }

    // MARK: Lifecycle

    /// At launch and whenever the switch changes. The script is kept up to
    /// date whenever it exists, since authorized_keys may still point at it.
    func syncWithPreferences() {
        guard Self.isEnabled else {
            stop()
            queue.async { Self.refreshScriptIfInstalled() }
            return
        }
        guard !running else { return }
        running = true
        limiter = RemoteRateLimiter()
        observeLock()
        queue.async { [self] in
            guard Self.writeScript(), let folder = Self.folderURL else { return }
            let requests = folder.appendingPathComponent(RemoteControl.requestsName, isDirectory: true)
            let responses = folder.appendingPathComponent(RemoteControl.responsesName, isDirectory: true)
            guard PrivateFileStore.createDirectory(at: requests),
                  PrivateFileStore.createDirectory(at: responses) else { return }
            var excluded = folder
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? excluded.setResourceValues(values)
            PrivateFileStore.write(Data("\(getpid())\n".utf8),
                                   to: folder.appendingPathComponent(RemoteControl.pidName))
            openWatcher(requests)
            scan()
        }
    }

    /// Off (or never on): the watcher and the lock observers stop, and the
    /// request folders and the process id go, also after a crash left them.
    func stop() {
        running = false
        observers.forEach { DistributedNotificationCenter.default().removeObserver($0) }
        observers = []
        sampler = nil
        queue.async { [self] in
            source?.cancel()
            source = nil
            guard let folder = Self.folderURL else { return }
            for name in [RemoteControl.pidName, RemoteControl.requestsName, RemoteControl.responsesName] {
                try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
            }
        }
    }

    // MARK: Script

    @discardableResult
    private static func writeScript() -> Bool {
        guard let script = scriptURL, let folder = folderURL,
              PrivateFileStore.createDirectory(at: folder) else { return false }
        let text = Data(RemoteScript.text(folder: folder.path).utf8)
        if (try? Data(contentsOf: script)) == text { return true }
        return PrivateFileStore.write(text, to: script)
    }

    /// An update may change the script; one already written follows it.
    private static func refreshScriptIfInstalled() {
        guard let script = scriptURL, FileManager.default.fileExists(atPath: script.path) else { return }
        writeScript()
    }

    // MARK: Watching (on `queue`)

    private func openWatcher(_ folder: URL) {
        source?.cancel()
        let descriptor = open(folder.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor,
                                                               eventMask: [.write, .delete, .rename], queue: queue)
        source.setEventHandler { [weak self, unowned source] in
            guard let self else { return }
            if !source.data.isDisjoint(with: [.delete, .rename]) {
                // The folder went away: make it again and keep watching.
                guard PrivateFileStore.createDirectory(at: folder) else { return }
                self.openWatcher(folder)
            }
            self.scan()
        }
        source.setCancelHandler { close(descriptor) }
        self.source = source
        source.resume()
    }

    /// Reads and removes every request, and anything left too long.
    private func scan() {
        guard let folder = Self.folderURL else { return }
        let manager = FileManager.default
        let requests = folder.appendingPathComponent(RemoteControl.requestsName, isDirectory: true)
        let responses = folder.appendingPathComponent(RemoteControl.responsesName, isDirectory: true)
        let now = Date()
        for name in (try? manager.contentsOfDirectory(atPath: requests.path)) ?? [] {
            let url = requests.appendingPathComponent(name)
            let attributes = try? manager.attributesOfItem(atPath: url.path)
            let modified = attributes?[.modificationDate] as? Date
            guard name.hasSuffix("." + RemoteControl.requestExtension) else {
                // A request still being written, or something that is not one.
                if let modified, now.timeIntervalSince(modified) > RemoteControl.staleResponse {
                    try? manager.removeItem(at: url)
                }
                continue
            }
            let id = String(name.dropLast(RemoteControl.requestExtension.count + 1))
            let size = (attributes?[.size] as? NSNumber)?.intValue ?? 0
            let isFile = attributes?[.type] as? FileAttributeType == .typeRegular
            let data = isFile && size <= RemoteControl.maximumRequestBytes ? (try? Data(contentsOf: url)) : nil
            try? manager.removeItem(at: url)
            let result = data.map { RemoteRequestParser.parse($0, id: id, modified: modified, now: now) }
                ?? (RemoteRequestParser.isValidID(id) ? .failure(.tooLarge) : .failure(.badID))
            DispatchQueue.main.async { [self] in
                guard let answer = handle(result) else { return }
                queue.async {
                    PrivateFileStore.write(RemoteRequestParser.response(status: answer.status, text: answer.text),
                                           to: responses.appendingPathComponent(id))
                }
            }
        }
        for name in (try? manager.contentsOfDirectory(atPath: responses.path)) ?? [] {
            let url = responses.appendingPathComponent(name)
            if let modified = (try? manager.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date,
               now.timeIntervalSince(modified) > RemoteControl.staleResponse {
                try? manager.removeItem(at: url)
            }
        }
    }

    // MARK: Answering (main thread)

    private func handle(_ result: Result<RemoteRequest, RemoteRequestError>) -> (status: Int32, text: String)? {
        guard running else { return (1, RemoteText.notRunning) }
        let request: RemoteRequest
        switch result {
        case .success(let value): request = value
        case .failure(.badID): return nil
        case .failure(.stale):
            record(device: "", verb: nil, outcome: .refused)
            return (1, RemoteText.expired)
        case .failure:
            record(device: "", verb: nil, outcome: .refused)
            return (2, RemoteText.unknown)
        }
        guard limiter.allow(at: Date()) else {
            record(device: request.device, verb: request.verb, outcome: .refused)
            return (1, RemoteText.tooMany)
        }
        record(device: request.device, verb: request.verb, outcome: .done)
        let macBook = PowerSampler.hasInternalBattery
        switch request.verb {
        case .status:
            let locked = Self.screenLocked()
            let text = RemoteStatusText.make(statusInput(locked: locked), now: Date())
            // Seen at the Mac, the island says who looked; locked, it stays quiet.
            if !locked { NotchService.shared.showZenithBurst(.remote(ZenithRemoteBurst(device: request.device))) }
            return (0, text)
        case .lock:
            if Self.screenLocked() { return (0, RemoteText.alreadyLocked(macBook: macBook)) }
            ZenithRemoteLockMark.mark(device: request.device)
            let immediate = QuickTogglesService.shared.lockScreenForRemote()
            lockedAt = Date()
            return (0, immediate ? RemoteText.locked(macBook: macBook) : RemoteText.screenSaver)
        }
    }

    private func record(device: String, verb: RemoteVerb?, outcome: LogEntry.Outcome) {
        log.insert(LogEntry(date: Date(), device: device, verb: verb, outcome: outcome), at: 0)
        if log.count > RemoteControl.logLimit { log.removeLast(log.count - RemoteControl.logLimit) }
    }

    // MARK: Status (main thread)

    private func statusInput(locked: Bool) -> RemoteStatusInput {
        var input = RemoteStatusInput()
        input.locked = locked
        input.since = locked ? lockedAt : inUseSince()
        if PowerSampler.hasInternalBattery {
            let sampler = self.sampler ?? PowerSampler(smc: nil)
            self.sampler = sampler
            let reading = sampler.sample()
            if reading.hasBattery, let percent = reading.chargePercent {
                input.batteryPercent = percent
                switch ZenithChargeState.of(external: reading.externalConnected, charging: reading.isCharging,
                                            percent: percent) {
                case .charging: input.charge = .charging
                case .held: input.charge = .held
                case .full: input.charge = .full
                case .onBattery: input.charge = .onBattery
                }
            }
        }
        input.jobs = ZenithLockScreenJobs.shared.items.filter { !$0.finished }.map { job in
            RemoteStatusInput.Job(title: RemoteStatusText.jobTitle(prefix: Self.prefix(job.source), label: job.label),
                                  fraction: job.fraction)
        }
        if let playback = NotchMusicService.shared.playback, playback.isPlaying {
            input.title = playback.track.title
            input.artist = playback.track.artist
        }
        input.wakaTimeSeconds = MainActor.assumeIsolated { () -> Double? in
            let service = WakaTimeService.shared
            let key = WakaTimeSupport.dayKey(Date())
            if let today = service.today, today.date == key { return today.totalSeconds }
            return service.history[key]
        }
        return input
    }

    private static func prefix(_ source: ZenithLockScreenJobSource) -> String? {
        switch source {
        case .export: return "Export"
        case .cardImport: return "Import"
        case .backup: return "Backup"
        case .vercel: return "Vercel"
        case .command: return nil
        }
    }

    /// The last unlock seen, or the last wake, or the boot.
    private func inUseSince() -> Date? {
        [unlockedAt, Self.kernelTime("kern.waketime"), Self.kernelTime("kern.boottime")].compactMap { $0 }.max()
    }

    private static func kernelTime(_ name: String) -> Date? {
        var value = timeval()
        var size = MemoryLayout<timeval>.stride
        guard sysctlbyname(name, &value, &size, nil, 0) == 0, value.tv_sec > 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(value.tv_sec) + TimeInterval(value.tv_usec) / 1_000_000)
    }

    static func screenLocked() -> Bool {
        (CGSessionCopyCurrentDictionary() as? [String: Any])?["CGSSessionScreenIsLocked"] as? Bool ?? false
    }

    private func observeLock() {
        let center = DistributedNotificationCenter.default()
        observers = [
            center.addObserver(forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) {
                [weak self] _ in self?.lockedAt = Date()
            },
            center.addObserver(forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) {
                [weak self] _ in self?.unlockedAt = Date()
            },
        ]
    }

    // MARK: Settings

    /// Reads whether Remote Login answers and how Tailscale names this Mac,
    /// off the main thread; nothing is changed.
    func checkReadiness() {
        guard !readiness.checking else { return }
        readiness.checking = true
        DispatchQueue.global(qos: .utility).async {
            let remoteLogin = Self.portAnswers(22)
            let installed = FileManager.default.fileExists(atPath: RemoteTailscale.appPath)
            var tailscale: RemoteTailscale.Status?
            if installed, FileManager.default.isExecutableFile(atPath: RemoteTailscale.cliPath) {
                // The App Store build is the GUI's binary too; run from an
                // app rather than a terminal it tries to open its window and
                // fails, unless told to be the CLI.
                var environment = ProcessInfo.processInfo.environment
                environment[RemoteTailscale.cliModeVariable] = "1"
                let result = BoundedProcessRunner.run(RemoteTailscale.cliPath, ["status", "--json"], timeout: 5,
                                                      maxOutputBytes: 2_000_000, environment: environment)
                if !result.timedOut { tailscale = RemoteTailscale.parse(result.output) }
            }
            let local = RemoteTailscale.localHost(SCDynamicStoreCopyLocalHostName(nil) as String?)
            DispatchQueue.main.async {
                self.readiness = Readiness(checking: false, remoteLogin: remoteLogin, tailscaleInstalled: installed,
                                           tailscale: tailscale, host: tailscale?.host ?? local)
            }
        }
    }

    /// Whether something accepts a connection on `port` at 127.0.0.1, within a second.
    private static func portAnswers(_ port: UInt16) -> Bool {
        let socketFD = socket(AF_INET, SOCK_STREAM, 0)
        guard socketFD >= 0 else { return false }
        defer { close(socketFD) }
        _ = fcntl(socketFD, F_SETFL, fcntl(socketFD, F_GETFL, 0) | O_NONBLOCK)
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        let started = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(socketFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if started == 0 { return true }
        guard errno == EINPROGRESS else { return false }
        var poller = pollfd(fd: socketFD, events: Int16(POLLOUT), revents: 0)
        guard poll(&poller, 1, 1_000) == 1 else { return false }
        var error: Int32 = 0
        var length = socklen_t(MemoryLayout<Int32>.size)
        guard getsockopt(socketFD, SOL_SOCKET, SO_ERROR, &error, &length) == 0 else { return false }
        return error == 0
    }

    func reloadDevices() {
        queue.async { [self] in
            let list = RemoteAuthorizedKeys.devices(ssh: Self.sshFolder)
            DispatchQueue.main.async { self.devices = list }
        }
    }

    /// Adds the iPhone's key with its one restricted line; the script it
    /// points at is written first.
    func addDevice(key text: String, name: String, completion: @escaping (RemoteAuthorizedKeys.Outcome) -> Void) {
        guard let key = RemotePublicKey.parse(text) else { completion(.invalidKey); return }
        queue.async { [self] in
            let outcome: RemoteAuthorizedKeys.Outcome
            if Self.writeScript(), let script = Self.scriptURL {
                outcome = RemoteAuthorizedKeys.add(key, name: name, script: script.path, ssh: Self.sshFolder)
            } else {
                outcome = .failed
            }
            let list = RemoteAuthorizedKeys.devices(ssh: Self.sshFolder)
            DispatchQueue.main.async {
                self.devices = list
                completion(outcome)
            }
        }
    }

    func removeDevice(_ device: RemoteDevice, completion: @escaping (RemoteAuthorizedKeys.Outcome) -> Void) {
        queue.async { [self] in
            let outcome = RemoteAuthorizedKeys.remove(device.key.blob, ssh: Self.sshFolder)
            let list = RemoteAuthorizedKeys.devices(ssh: Self.sshFolder)
            DispatchQueue.main.async {
                self.devices = list
                completion(outcome)
            }
        }
    }

    /// Runs the status request through the script on this Mac, the way the
    /// iPhone's SSH command does, and keeps what it printed.
    func runTest() {
        guard running, !testing, let script = Self.scriptURL else { return }
        testing = true
        testOutput = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let result = BoundedProcessRunner.run("/bin/sh", [script.path], timeout: 8, maxOutputBytes: 8_192,
                                                  environment: ["SSH_ORIGINAL_COMMAND": "status Test",
                                                                "PATH": "/usr/bin:/bin"])
            let text = String(decoding: result.output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            DispatchQueue.main.async {
                self.testOutput = result.timedOut ? RemoteText.noAnswer : text
                self.testing = false
            }
        }
    }
}
