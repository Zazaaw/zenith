// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import Combine

// Zenith fork: dev servers for the island. The listening ports come from the
// Port Manager's own reader (PortManagerService, lsof, about 30 ms); the
// process behind each new one is read once from the kernel (DevServersProbe)
// and kept while it runs. It looks every 3 seconds while the page or its home
// widget is on screen, every 10 seconds while the notice or the closed
// island's count needs it, and not at all otherwise. Kill goes through the
// same identity-checked path the Port Manager uses (KillProcessService):
// SIGTERM, then SIGKILL if the same process is still there 3 seconds later.

final class DevServersService: ObservableObject {
    static let shared = DevServersService()

    /// Seconds between looks while the page or its widget shows, and in the background.
    static let visibleInterval: TimeInterval = 3
    static let backgroundInterval: TimeInterval = 10

    @Published private(set) var servers: [DevServer] = []
    @Published private(set) var hasLoaded = false
    /// lsof timed out on the last look; the list is the one before it.
    @Published private(set) var failed = false
    /// The closed island's count: nil while it should not show.
    @Published private(set) var indicator: Int?
    @Published private(set) var kill = DevServersKillConfirmation()
    /// The row whose URL was just copied.
    @Published private(set) var copiedID: String?

    private let queue = DispatchQueue(label: "com.vorssaint.zenith.dev-servers", qos: .utility)
    /// The queue's own: the process behind each pid, while the same process runs.
    private var processes: [Int32: DevServerProcess] = [:]
    private var options = DevServersOptions()
    private var active = false
    private var viewers = 0
    private var timer: Timer?
    private var interval: TimeInterval = 0
    private var scanning = false
    private var announcer = DevServersAnnouncer()
    private var announcing = false
    private var confirmWork: DispatchWorkItem?
    private var copiedWork: DispatchWorkItem?

    private init() {}

    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    // MARK: Lifecycle

    /// Called with every island preference sync and from the section's options.
    func syncWithPreferences() {
        options = DevServersOptions.current()
        active = options.enabled && NotchSupport.isEnabled()
        guard active else {
            stop()
            return
        }
        // Turned on again, announcing starts from what runs now.
        if options.announces != announcing {
            announcing = options.announces
            announcer.reset()
        }
        publishIndicator()
        schedule()
    }

    /// Detection off or the island stopped: no more looking in the background
    /// (a page still on screen, as in Settings' preview, keeps its own looks).
    func stop() {
        active = false
        announcing = false
        announcer.reset()
        if indicator != nil { indicator = nil }
        schedule()
    }

    /// The page or the home widget appeared; while any shows, it looks often.
    func shown() {
#if VORSSAINT_DEVELOPMENT
        // Zenith fork: the island catalog draws sample data only.
        if IslandCatalog.isRendering { return }
#endif
        viewers += 1
        options = DevServersOptions.current()
        schedule()
        refresh()
    }

    /// Whether a look may run: detection on, and the island running or a page showing.
    private var looks: Bool { options.enabled && (active || viewers > 0) }

    func hidden() {
        viewers = max(0, viewers - 1)
        schedule()
    }

    private func schedule() {
        let wanted: TimeInterval = !options.enabled ? 0
            : viewers > 0 ? Self.visibleInterval
            : active && options.watchesInBackground ? Self.backgroundInterval : 0
        guard wanted != interval else { return }
        let startsBackground = interval == 0 && wanted > 0
        interval = wanted
        timer?.invalidate()
        timer = nil
        guard wanted > 0 else { return }
        let timer = Timer(timeInterval: wanted, repeats: true) { [weak self] _ in self?.refresh() }
        timer.tolerance = wanted * 0.2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        // The first background look is the baseline the notice compares with.
        if startsBackground { refresh() }
    }

    // MARK: Looking

    func refresh() {
        guard looks, !scanning else { return }
        scanning = true
        let extras = options.extras
        let context = DevServersContext.current
        queue.async { [weak self] in
            guard let self else { return }
            let entries = PortManagerService.zenithListeners()
            let servers = entries.map { self.servers(from: $0, extras: extras, context: context) }
            DispatchQueue.main.async { self.apply(servers) }
        }
    }

    /// On the queue: the listing's dev servers, reading only processes not seen before.
    private func servers(from entries: [PortManagerEntry], extras: DevServersExtras,
                         context: DevServersContext) -> [DevServer] {
        let listeners = DevServersScanner.listeners(entries)
        let names = Dictionary(entries.map { ($0.pid, $0.processName) }, uniquingKeysWith: { first, _ in first })
        let pids = Set(listeners.map(\.pid))
        processes = processes.filter { pids.contains($0.key) }
        return DevServersScanner.servers(listeners, process: { pid in
            let start = DevServersProbe.bsdInfo(pid).map { $0.pbi_start_tvsec &* 1_000_000 &+ $0.pbi_start_tvusec }
            if let cached = self.processes[pid], cached.startMicros == start { return cached }
            let read = DevServersProbe.process(pid: pid, name: names[pid] ?? "")
            self.processes[pid] = read
            return read
        }, extras: extras, context: context)
    }

    private func apply(_ result: [DevServer]?) {
        scanning = false
        guard looks else { return }
        failed = result == nil
        guard let result else { return }
        hasLoaded = true
        if result != servers { servers = result }
        var kill = self.kill
        kill.keep(Set(result.map(\.id)))
        if kill != self.kill { self.kill = kill }
        publishIndicator()
        guard active, announcing else { return }
        for server in announcer.update(result, now: now) {
            ZenithNoticeCenter.shared.devServerStarted(server)
        }
    }

    private func publishIndicator() {
        let count = active && options.indicator && hasLoaded && !servers.isEmpty ? servers.count : nil
        if count != indicator { indicator = count }
    }

    // MARK: Actions

    func open(_ server: DevServer) {
        guard let url = server.url, NSWorkspace.shared.open(url) else {
            NSSound.beep()
            return
        }
    }

    func copyURL(_ server: DevServer) {
        guard let url = server.url?.absoluteString else { return }
        GeneralPasteboardAccess.shared.async({
            NSPasteboard.general.clearContents()
            NSPasteboard.general.declareVorssaintSource()
            return NSPasteboard.general.setString(url, forType: .string)
        }, then: { [weak self] copied in
            guard let self else { return }
            guard copied else {
                NSSound.beep()
                return
            }
            self.copiedID = server.id
            self.copiedWork?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.copiedID = nil }
            self.copiedWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: work)
        })
    }

    /// The first click asks "Kill?", a second one within 3 seconds stops it.
    func pressKill(_ server: DevServer) {
        guard server.canKill else { return }
        var kill = self.kill
        let outcome = kill.press(server.id, now: now)
        self.kill = kill
        switch outcome {
        case .confirm:
            confirmWork?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                var kill = self.kill
                kill.expire(now: self.now)
                if kill != self.kill { self.kill = kill }
            }
            confirmWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + DevServersKillConfirmation.window + 0.05, execute: work)
        case .kill:
            confirmWork?.cancel()
            terminate(server)
        case .ignored:
            break
        }
    }

    func cancelKill() {
        guard kill.confirming != nil else { return }
        var kill = self.kill
        kill.cancel()
        self.kill = kill
    }

    /// SIGTERM through the Port Manager's kill path, then SIGKILL if the very
    /// same process (pid and start time) is still there.
    private func terminate(_ server: DevServer) {
        guard let start = server.startMicros else { return }
        let killer = KillProcessService.shared
        killer.kill(pid: server.pid, name: server.processName, startedAt: start, force: false) { [weak self] in
            self?.refresh()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + DevServersKillConfirmation.escalation) { [weak self] in
            if KillProcessService.startTime(for: server.pid) == start {
                killer.kill(pid: server.pid, name: server.processName, startedAt: start, force: true) {
                    self?.refresh()
                }
            } else {
                self?.refresh()
            }
        }
    }
}

#if VORSSAINT_DEVELOPMENT
// Zenith fork: sample state for the island catalog (IslandCatalog,
// `--render-island-catalog`), which draws the island offscreen. Nothing else
// calls this, and the release build does not have it.
extension DevServersService {
    func catalogPose(servers: [DevServer], indicator: Int?) {
        self.servers = servers
        self.indicator = indicator
        hasLoaded = true
        failed = false
    }
}
#endif
