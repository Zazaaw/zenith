// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import CoreServices

/// Zenith fork: renders, recordings and photo exports for the closed island.
///
/// One FSEvents stream with file-level events watches the folders in
/// Settings, subfolders included, and lets through only media outputs. A
/// file it lets through is sized about every second while anything is
/// tracked, and not at all otherwise: no event, no timer. ExportTrackerSupport
/// decides what each size means; this side reads the sizes, asks the kernel
/// who has a file open (ExportWriterProbe) and, when an export ends, shows the
/// capsule notice, plays the sound and, if the island cannot be seen, posts a
/// notification that reveals the file.
///
/// It runs only while the island runs with "Export tracker" on.
final class ExportTrackerService: ObservableObject {
    typealias Support = ExportTrackerSupport

    static let shared = ExportTrackerService()

    /// What the closed island shows, nil when nothing exports.
    @Published private(set) var activity: Support.Activity?
    /// The growing size of what it shows, read by the strip alone.
    @Published private(set) var live: Support.Live?

    private let queue = DispatchQueue(label: "com.vorssaint.zenith.export-tracker", qos: .utility)
    /// Main thread: published values are accepted only while running.
    private var active = false
    private var mountObservers: [NSObjectProtocol] = []

    // Owned by `queue`.
    private var stream: FSEventStreamRef?
    private var roots: [String] = []
    private var timer: DispatchSourceTimer?
    private var timerDeadline: Date?
    private var tracker = Support.Tracker()
    private var configuration = Support.Configuration()
    private let ownPID = getpid()

    private init() {}

    // MARK: Lifecycle

    /// Called with every island preference sync.
    func syncWithPreferences() {
        guard Support.isEnabled(), NotchSupport.isEnabled() else {
            stop()
            return
        }
        let configuration = Support.configuration()
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        // The kernel's spelling, as FSEvents reports paths; a drive that is
        // not mounted is left out until it is.
        let roots = Support.roots(Support.folders(), home: home).filter(Self.isDirectory).map(ExportWriterProbe.canonical)
        active = true
        observeMounts()
        queue.async { [self] in
            self.configuration = configuration
            if stream == nil || self.roots != roots {
                closeStream()
                self.roots = roots
                openStream()
            }
            publish(now: Date())
        }
    }

    /// The island stopped, or the switch went off.
    func stop() {
        let wasActive = active
        active = false
        if activity != nil { activity = nil }
        if live != nil { live = nil }
        mountObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        mountObservers = []
        guard wasActive else { return }
        queue.async { [self] in
            closeStream()
            timer?.cancel()
            timer = nil
            timerDeadline = nil
            tracker = Support.Tracker()
            roots = []
        }
    }

    /// A drive with a watched folder came or went.
    private func observeMounts() {
        guard mountObservers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        mountObservers = [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification].map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                guard self?.active == true else { return }
                self?.syncWithPreferences()
            }
        }
    }

    private static func isDirectory(_ path: String) -> Bool {
        var directory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &directory) && directory.boolValue
    }

    // MARK: Watching (on `queue`)

    private func openStream() {
        guard !roots.isEmpty else { return }
        var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
                                           retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, count, paths, flags, _ in
            guard let info else { return }
            let service = Unmanaged<ExportTrackerService>.fromOpaque(info).takeUnretainedValue()
            let list = (unsafeBitCast(paths, to: NSArray.self) as? [String]) ?? []
            let file = FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsFile)
            let changed = (0..<min(count, list.count)).filter { flags[$0] & file != 0 }.map { list[$0] }
            service.handle(changed)
        }
        // Zenith's own writes never come back as events.
        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes
                                             | kFSEventStreamCreateFlagIgnoreSelf | kFSEventStreamCreateFlagNoDefer)
        guard let created = FSEventStreamCreate(kCFAllocatorDefault, callback, &context, roots as CFArray,
                                                FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.5, flags) else {
            return
        }
        FSEventStreamSetDispatchQueue(created, queue)
        guard FSEventStreamStart(created) else {
            FSEventStreamInvalidate(created)
            FSEventStreamRelease(created)
            return
        }
        stream = created
    }

    private func closeStream() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    /// Files the stream says changed: media outputs start being tracked.
    private func handle(_ paths: [String]) {
        let now = Date()
        var tracked = false
        for path in Set(paths) where Support.isCandidate(path, roots: roots) {
            let info = Self.stat(path)
            if tracker.noteChange(path: path, size: info?.size, created: info?.created, now: now,
                                  configuration: configuration) {
                tracked = true
            }
        }
        guard tracked else { return }
        // A first look a second from now; a tick already due stays as it is.
        schedule(at: now.addingTimeInterval(configuration.sampleInterval))
    }

    /// Reads the tracked sizes, asks who writes, ends what is done and publishes.
    private func tick() {
        let now = Date()
        timer = nil
        timerDeadline = nil
        for path in tracker.sampledPaths {
            tracker.sample(path: path, size: Self.stat(path)?.size, now: now, configuration: configuration)
        }
        for path in tracker.wantsAttribution(now: now, configuration: configuration) {
            // Only a process that writes it says who exports; a reader such
            // as Spotlight or QuickLook says nothing.
            if let writer = ExportWriterProbe.openers(of: path)?.first(where: \.writing) {
                tracker.attribute(path: path, Support.attribution(executablePath: writer.executable, pid: writer.pid,
                                                                  ownPID: ownPID, path: path),
                                  pid: writer.pid, now: now)
            } else {
                tracker.attribute(path: path, .unknown, now: now)
            }
        }
        let folders = tracker.wantsBatchProducer
        if !folders.isEmpty {
            let producer = Support.batchProducer(runningExecutables: ExportWriterProbe.runningExecutables())
            for folder in folders { tracker.setBatchProducer(folder: folder, producer) }
        }
        for check in tracker.writerChecksDue(now: now, configuration: configuration) {
            let (writing, pid) = writer(of: check.path, known: check.pid)
            tracker.writerChecked(path: check.path, writing: writing, writerPID: pid, now: now)
        }
        tracker.advance(now: now, configuration: configuration)
        let finished = tracker.takeFinished()
        publish(now: now)
        if tracker.isSampling {
            schedule(at: now.addingTimeInterval(configuration.sampleInterval))
        } else if let next = tracker.nextChange(after: now, configuration: configuration) {
            schedule(at: next)
        }
        guard !finished.isEmpty else { return }
        DispatchQueue.main.async { [weak self] in self?.announce(finished) }
    }

    /// Whether anyone still writes the file: its known writer alone when
    /// there is one, else every process. Nil when the kernel would not say,
    /// and then the stable size alone ends it.
    private func writer(of path: String, known pid: Int32?) -> (Bool?, Int32?) {
        if let pid, pid != ownPID, let writing = ExportWriterProbe.isWriting(path, pid: pid) {
            return (writing, pid)
        }
        guard let openers = ExportWriterProbe.openers(of: path) else { return (nil, nil) }
        if let writer = openers.first(where: { $0.writing && $0.pid != ownPID }) { return (true, writer.pid) }
        return (false, nil)
    }

    /// Only an earlier moment than the one already due moves the tick.
    private func schedule(at moment: Date) {
        if let timerDeadline, timerDeadline <= moment, timer != nil { return }
        timer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + max(0.05, moment.timeIntervalSinceNow), leeway: .milliseconds(100))
        timer.setEventHandler { [weak self] in self?.tick() }
        self.timer = timer
        timerDeadline = moment
        timer.resume()
    }

    private func publish(now: Date) {
        let next = tracker.activity(now: now, configuration: configuration)
        let size = tracker.live(now: now, configuration: configuration)
        DispatchQueue.main.async { [weak self] in
            guard let self, self.active else { return }
            if self.activity != next { self.activity = next }
            if self.live != size { self.live = size }
        }
    }

    private static func stat(_ path: String) -> (size: Int64, created: Date?)? {
        var info = Darwin.stat()
        guard lstat(path, &info) == 0, info.st_mode & S_IFMT == S_IFREG else { return nil }
        let birth = info.st_birthtimespec
        let created = birth.tv_sec > 0
            ? Date(timeIntervalSince1970: TimeInterval(birth.tv_sec) + TimeInterval(birth.tv_nsec) / 1_000_000_000) : nil
        return (Int64(info.st_size), created)
    }

    // MARK: Main thread

    /// The notice for each export that ended, one sound, and a notification
    /// when the island cannot show it.
    private func announce(_ finished: [Support.Finished]) {
        guard active else { return }
        let language = L10n.shared.language
        let text = ZenithStrings.exportTracker(language)
        let locale = language.formattingLocale()
        let defaults = UserDefaults.standard
        let island = NotchService.shared
        let locked = (CGSessionCopyCurrentDictionary() as? [String: Any])?["CGSSessionScreenIsLocked"] as? Bool ?? false
        let unseen = locked || !island.showsSystemFeedback
        for item in finished {
            RecapService.record(.exported(bytes: item.bytes, at: item.ended)) // Zenith fork: the day's recap
            let url = URL(fileURLWithPath: item.path)
            let title = item.producer?.kind == .recorder ? text.recordingSaved : text.exportFinished
            let name = item.count.map { Support.filling(text.images, count: $0) } ?? item.name
            let size = Support.size(item.bytes, locale: locale)
            let subtitle = [name, size, item.producer?.name].compactMap { $0 }.joined(separator: " · ")
            ZenithNoticeCenter.shared.exportFinished(url, key: item.id, title: title, subtitle: subtitle)
            // The notification center aborts a process without a bundle, such as the bare binary.
            if unseen, defaults.bool(forKey: DefaultsKey.notchExportNotify), Bundle.main.bundleIdentifier != nil {
                let body = [name, Support.finishedDetail(bytes: item.bytes, duration: item.duration, locale: locale),
                            item.producer?.name].compactMap { $0 }.joined(separator: " · ")
                Notifier.post(title: title, body: body, revealing: url)
            }
        }
        if defaults.bool(forKey: DefaultsKey.notchExportSound), let sound = NSSound(named: NSSound.Name("Glass")) {
            sound.volume = 0.5
            sound.play()
        }
    }

    /// Shows the file in Finder, from the strip or the notice.
    static func reveal(_ path: String) {
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            NSWorkspace.shared.open(url.deletingLastPathComponent())
        }
    }
}
