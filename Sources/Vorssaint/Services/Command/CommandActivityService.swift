// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: long-running terminal commands for the closed island.
///
/// The zsh hook writes a file into `<container>/Commands/` when a command
/// starts and when it ends; this service watches that folder with a
/// DispatchSource (no polling), reads and deletes the files on its own queue,
/// and publishes what the island shows on the main thread. Timers run only
/// for moments the activity changes by itself (a command passing the
/// threshold or the hour, a result running out) and, while something runs, a
/// look every 30 seconds at whether its shell is still there.
///
/// It runs only while the island runs with "Command activity" on. Turned off,
/// the folder goes too, and the hook, finding no folder, writes nothing.
final class CommandActivityService: ObservableObject {
    static let shared = CommandActivityService()

    /// What the closed island shows, nil when nothing has run long enough.
    @Published private(set) var activity: CommandActivitySupport.Activity?
    /// When the hook last wrote, kept on this Mac only (never backed up).
    @Published private(set) var lastEvent: Date?
    /// The folder the newest command started in, read from its shell when
    /// the start arrives (the hook itself writes only the folder's name).
    /// The Git page follows it to the repository; it is never shown or stored.
    @Published private(set) var latestDirectory: CommandDirectory?

    struct CommandDirectory: Equatable {
        let path: String
        let time: Date
    }

    private let queue = DispatchQueue(label: "com.vorssaint.zenith.command-activity", qos: .utility)
    /// Main thread: published values are accepted only while running.
    private var active = false

    // Owned by `queue`.
    private var source: DispatchSourceFileSystemObject?
    private var timer: DispatchSourceTimer?
    private var tracker = CommandActivitySupport.Tracker()
    private var configuration = CommandActivitySupport.Configuration()
    /// Start files already read, which stay while their command runs.
    private var applied = Set<String>()
    private var folder: URL?

    private init() {
        let stored = UserDefaults.standard.double(forKey: DefaultsKey.notchCommandLastEvent)
        lastEvent = stored > 0 ? Date(timeIntervalSince1970: stored) : nil
    }

    /// `<Application Support>/<bundle id>/Commands`, for this build's bundle id.
    static var folderURL: URL? {
        PrivateFileStore.containerURL?.appendingPathComponent(CommandActivitySupport.folderName, isDirectory: true)
    }

    static var zshrcURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".zshrc", isDirectory: false)
    }

    /// The block this build adds to `~/.zshrc`.
    static var hookBlock: String? {
        folderURL.map { CommandActivitySupport.hookBlock(folder: $0.path) }
    }

    // MARK: Lifecycle

    /// Called with every island preference sync.
    func syncWithPreferences() {
        guard CommandActivitySupport.isEnabled(), NotchSupport.isEnabled() else {
            stop(removingFolder: true)
            return
        }
        let configuration = CommandActivitySupport.configuration()
        let folder = Self.folderURL
        active = true
        queue.async { [self] in
            self.configuration = configuration
            if source == nil || self.folder != folder {
                closeWatcher()
                self.folder = folder
                openWatcher()
            }
            scan()
        }
    }

    /// The island stopped.
    func stop() { stop(removingFolder: true) }

    private func stop(removingFolder: Bool) {
        active = false
        if activity != nil { activity = nil }
        queue.async { [self] in
            closeWatcher()
            timer?.cancel()
            timer = nil
            tracker = CommandActivitySupport.Tracker()
            applied = []
            if removingFolder, let folder = folder ?? Self.folderURL {
                try? FileManager.default.removeItem(at: folder)
            }
            folder = nil
        }
    }

    // MARK: Watching (on `queue`)

    private func openWatcher() {
        guard let folder, PrivateFileStore.createDirectory(at: folder) else { return }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var excluded = folder
        try? excluded.setResourceValues(values)
        let descriptor = open(folder.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor,
                                                               eventMask: [.write, .delete, .rename], queue: queue)
        source.setEventHandler { [weak self, unowned source] in
            guard let self else { return }
            if !source.data.isDisjoint(with: [.delete, .rename]) {
                // The folder itself went away: make it again and keep watching.
                self.closeWatcher()
                self.openWatcher()
            }
            self.scan()
        }
        source.setCancelHandler { close(descriptor) }
        self.source = source
        source.resume()
    }

    private func closeWatcher() {
        source?.cancel()
        source = nil
    }

    /// Reads what the hook wrote since the last look, applies it in order,
    /// deletes what is done with, and publishes.
    private func scan() {
        guard let folder else { return }
        let manager = FileManager.default
        let now = Date()
        var events: [(name: String, event: CommandActivitySupport.Event)] = []
        let names = (try? manager.contentsOfDirectory(atPath: folder.path)) ?? []
        for name in names where !applied.contains(name) {
            let url = folder.appendingPathComponent(name, isDirectory: false)
            let attributes = try? manager.attributesOfItem(atPath: url.path)
            let age = (attributes?[.modificationDate] as? Date).map { now.timeIntervalSince($0) } ?? 0
            let kind = CommandActivitySupport.kind(ofFile: name)
            guard case .event(let id, let phase) = kind else {
                if CommandActivitySupport.removesLeftover(kind, age: age) { try? manager.removeItem(at: url) }
                continue
            }
            let size = (attributes?[.size] as? NSNumber)?.intValue ?? 0
            guard size <= CommandActivitySupport.maxFileSize,
                  let data = try? Data(contentsOf: url),
                  let event = CommandActivitySupport.parse(data), event.id == id, event.phase == phase else {
                try? manager.removeItem(at: url)
                continue
            }
            events.append((name, event))
        }
        let byEvent = Dictionary(events.map { ($0.event.id + "." + $0.event.phase.rawValue, $0.name) },
                                 uniquingKeysWith: { first, _ in first })
        for event in CommandActivitySupport.ordered(events.map(\.event)) {
            guard let name = byEvent[event.id + "." + event.phase.rawValue] else { continue }
            // The day's recap counts the commands long enough to have shown.
            if event.phase == .end, let run = tracker.running[event.id],
               event.time.timeIntervalSince(run.start) >= configuration.threshold {
                RecapService.record(.command(duration: event.time.timeIntervalSince(run.start), ended: event.time))
            }
            if tracker.apply(event, configuration: configuration, now: now) {
                applied.insert(name)
                continue
            }
            try? manager.removeItem(at: folder.appendingPathComponent(name, isDirectory: false))
            if event.phase == .end { removeStart(of: event.id) }
        }
        if !events.isEmpty {
            DispatchQueue.main.async { [weak self] in self?.noteEvent(now) }
        }
        let starts: [CommandActivitySupport.Event] = events.map(\.event).filter { $0.phase == .start && $0.pid != nil }
        let newest: CommandActivitySupport.Event? = starts.max { $0.time < $1.time }
        if let newest, let pid = newest.pid, let path = DevServersProbe.currentDirectory(pid) {
            let directory = CommandDirectory(path: path, time: newest.time)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.active, (self.latestDirectory?.time ?? .distantPast) < directory.time else { return }
                self.latestDirectory = directory
            }
        }
        refresh(now: now)
    }

    private func removeStart(of id: String) {
        let name = CommandActivitySupport.fileName(id: id, phase: .start)
        applied.remove(name)
        if let folder { try? FileManager.default.removeItem(at: folder.appendingPathComponent(name, isDirectory: false)) }
    }

    /// Drops stale commands, publishes, and waits for the next change.
    private func refresh(now: Date) {
        for id in tracker.removeStale(now: now, isAlive: Self.isAlive) { removeStart(of: id) }
        let next = tracker.activity(now: now, configuration: configuration)
        DispatchQueue.main.async { [weak self] in
            guard let self, self.active, self.activity != next else { return }
            self.activity = next
        }
        schedule(now: now)
    }

    private func schedule(now: Date) {
        timer?.cancel()
        timer = nil
        let change = tracker.nextChange(after: now, configuration: configuration)
        let liveness = tracker.running.isEmpty ? nil : now.addingTimeInterval(CommandActivitySupport.livenessInterval)
        guard let moment = [change, liveness].compactMap({ $0 }).min() else { return }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        // A threshold or a result lands on its second; a liveness look can drift.
        let leeway: DispatchTimeInterval = moment == change ? .milliseconds(20) : .seconds(3)
        timer.schedule(deadline: .now() + max(0, moment.timeIntervalSince(now)), leeway: leeway)
        timer.setEventHandler { [weak self] in self?.refresh(now: Date()) }
        self.timer = timer
        timer.resume()
    }

    /// A shell closed with its tab never runs its end hook.
    private static func isAlive(_ pid: Int32) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }

    // MARK: Main thread

    private func noteEvent(_ date: Date) {
        lastEvent = date
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: DefaultsKey.notchCommandLastEvent)
    }

    // MARK: Shell hook

    static func hookState() -> CommandActivitySupport.HookState {
        let url = zshrcURL.resolvingSymlinksInPath()
        guard let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) else {
            return .missing
        }
        return CommandActivitySupport.hookState(in: text)
    }

    static func installHook() -> CommandActivitySupport.HookEditResult {
        guard let block = hookBlock else { return .failed }
        return CommandActivitySupport.editHook(at: zshrcURL, install: block)
    }

    static func removeHook() -> CommandActivitySupport.HookEditResult {
        CommandActivitySupport.editHook(at: zshrcURL, install: nil)
    }
}
