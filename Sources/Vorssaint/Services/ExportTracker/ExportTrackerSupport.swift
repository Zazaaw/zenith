// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: a render, recording or photo export in the closed island.
///
/// DaVinci Resolve's free version has no scripting to ask, so nothing here
/// talks to an app: the watched folders tell when a media file appears or
/// changes (ExportTrackerService, FSEvents), and everything decided from
/// there lives in this file, pure and compiled into the tests: which files
/// count, the growth and stability state machine, which app wrote a file,
/// what the island shows and how sizes read.
///
/// A file counts as exporting once it keeps growing past the minimum size.
/// Its size is read about every second only while something is tracked. It
/// is done when its size held still for `stableWindow` and no process still
/// has it open for writing; when that cannot be told, the size alone decides.
/// Images that land whole, one after another, while a photo or video app runs,
/// are one batch export.
enum ExportTrackerSupport {
    static let symbol = "film"

    /// Media outputs. `braw` covers Blackmagic RAW proxies rendered out, and
    /// `mkv` OBS's long-time recording format.
    static let mediaExtensions: Set<String> = [
        "mov", "mp4", "mxf", "m4v", "mkv", "braw",
        "wav", "aac", "mp3",
        "jpg", "jpeg", "png", "tif", "tiff", "heic", "psd",
        "pdf",
    ]
    static let videoExtensions: Set<String> = ["mov", "mp4", "mxf", "m4v", "mkv", "braw"]
    static let audioExtensions: Set<String> = ["wav", "aac", "mp3"]
    /// Only these join a batch: a PDF or a video landing whole is a copy, not an export.
    static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "tif", "tiff", "heic", "psd"]
    /// Names a download or a writer gives a file until it is complete.
    static let temporaryExtensions: Set<String> = ["part", "partial", "tmp", "temp", "crdownload", "download"]
    /// Resolve's render cache, gallery stills, proxies and optimized media.
    static let ignoredFolders: Set<String> = ["cacheclip", ".gallery", "proxymedia", "optimizedmedia"]
    /// Libraries and bundles whose insides are an app's own working files,
    /// such as Final Cut's render files inside a library in ~/Movies.
    static let ignoredPackages: Set<String> = [
        "fcpbundle", "imovielibrary", "photoslibrary", "tvlibrary", "musiclibrary", "lrdata", "lrlibrary",
        "cocatalog", "cosessiondb", "app", "bundle", "fcpxml", "motn", "drp",
    ]

    /// The size a file needs before it shows, in megabytes.
    static let minimumChoices = [1, 10, 50, 200]
    static let defaultMinimum = 1
    static let megabyte: Int64 = 1_000_000
    static let defaultFolders = ["~/Movies", "~/Desktop", "~/Downloads"]
    static let defaultFoldersOff = ["~/Downloads"]
    /// More are left untracked: a burst of copies must not turn into work.
    static let maximumTracked = 200

    // MARK: Preferences

    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: DefaultsKey.notchExportTracker)
    }

    static func minimum(in defaults: UserDefaults = .standard) -> Int {
        let stored = defaults.integer(forKey: DefaultsKey.notchExportMinimum)
        return minimumChoices.contains(stored) ? stored : defaultMinimum
    }

    static func configuration(in defaults: UserDefaults = .standard) -> Configuration {
        Configuration(minimumBytes: Int64(minimum(in: defaults)) * megabyte)
    }

    /// One watched folder as stored: `~/Movies` for a folder under the home
    /// folder, so a backup reads on another Mac, or an absolute path.
    struct Folder: Equatable, Sendable, Identifiable {
        let entry: String
        var on: Bool
        var id: String { entry }
    }

    static func folders(in defaults: UserDefaults = .standard) -> [Folder] {
        let list = defaults.stringArray(forKey: DefaultsKey.notchExportFolders) ?? defaultFolders
        let off = Set(defaults.stringArray(forKey: DefaultsKey.notchExportFoldersOff) ?? defaultFoldersOff)
        var seen = Set<String>()
        return list.compactMap { entry in
            let entry = entry.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !entry.isEmpty, seen.insert(entry).inserted else { return nil }
            return Folder(entry: entry, on: !off.contains(entry))
        }
    }

    /// `~/Movies` for a path under `home`, the path itself elsewhere.
    static func entry(forPath path: String, home: String) -> String {
        let home = trimmedSlash(home), path = trimmedSlash(path)
        if path == home { return "~" }
        if path.hasPrefix(home + "/") { return "~" + path.dropFirst(home.count) }
        return path
    }

    static func expanded(_ entry: String, home: String) -> String {
        let home = trimmedSlash(home)
        if entry == "~" { return home }
        if entry.hasPrefix("~/") { return home + entry.dropFirst(1) }
        return trimmedSlash(entry)
    }

    /// The folders to watch, expanded, without one inside another (its
    /// events already come with the outer one's).
    static func roots(_ folders: [Folder], home: String) -> [String] {
        let paths = folders.filter(\.on).map { expanded($0.entry, home: home) }.filter { $0.hasPrefix("/") && $0 != "/" }
        let sorted = Array(Set(paths)).sorted { $0.count != $1.count ? $0.count < $1.count : $0 < $1 }
        var kept: [String] = []
        for path in sorted where !kept.contains(where: { path.hasPrefix($0 + "/") }) { kept.append(path) }
        return kept.sorted()
    }

    private static func trimmedSlash(_ path: String) -> String {
        var path = path
        while path.count > 1, path.hasSuffix("/") { path.removeLast() }
        return path
    }

    // MARK: Which files count

    static func fileExtension(_ path: String) -> String {
        let name = (path as NSString).lastPathComponent
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return "" }
        return name[name.index(after: dot)...].lowercased()
    }

    /// A media output under one of the roots that is not hidden, temporary,
    /// a cache or inside an app's library.
    static func isCandidate(_ path: String, roots: [String]) -> Bool {
        guard mediaExtensions.contains(fileExtension(path)),
              let root = roots.first(where: { path.hasPrefix($0 + "/") }) else { return false }
        return !isIgnored(relative: String(path.dropFirst(root.count + 1)))
    }

    /// `relative` is the path below its watched root.
    static func isIgnored(relative: String) -> Bool {
        let components = relative.split(separator: "/").map(String.init)
        guard let name = components.last, !name.isEmpty else { return true }
        if name.hasPrefix(".") || name.hasPrefix("~$") { return true }
        // "clip.mov.part", "clip.tmp.mov": any temporary suffix in the name.
        let parts = name.lowercased().split(separator: ".").dropFirst().map(String.init)
        if parts.contains(where: temporaryExtensions.contains) { return true }
        for folder in components.dropLast() {
            let lowered = folder.lowercased()
            if folder.hasPrefix(".") || ignoredFolders.contains(lowered) { return true }
            if let dot = lowered.lastIndex(of: "."),
               ignoredPackages.contains(String(lowered[lowered.index(after: dot)...]))
                || temporaryExtensions.contains(String(lowered[lowered.index(after: dot)...])) {
                return true
            }
        }
        return false
    }

    // MARK: Producer

    /// The app that writes a file, by the executable behind the process.
    struct Producer: Equatable, Sendable {
        enum Kind: String, Sendable { case video, recorder, photo, encoder, audio, other }
        let name: String
        let kind: Kind
        /// sRGB 0xRRGGBB from the island's palette, for its glyph.
        let tint: UInt32
        /// The app bundle, whose icon the island shows when there is one.
        var bundlePath: String? = nil

        var symbol: String {
            switch kind {
            case .video: return "film.stack"
            case .recorder: return "record.circle"
            case .photo: return "photo.stack"
            case .encoder: return "rectangle.stack.badge.play"
            case .audio: return "waveform"
            case .other: return "film"
            }
        }
    }

    enum Attribution: Equatable, Sendable {
        case producer(Producer)
        /// A copy, a sync, a download or Zenith itself: never an export.
        case ignored
        /// Nobody has it open, or it could not be told.
        case unknown
    }

    private struct Known {
        let names: [String]
        let display: String
        let kind: Producer.Kind
        let tint: UInt32
        var prefix = false
    }

    /// Matched by the app's name (or the program's, outside an app), lowercased.
    private static let known: [Known] = [
        Known(names: ["davinci resolve", "resolve", "davinci resolve studio"], display: "DaVinci Resolve",
              kind: .video, tint: 0xFB923C),
        Known(names: ["obs", "obs studio"], display: "OBS", kind: .recorder, tint: 0x818CF8),
        Known(names: ["final cut pro", "final cut pro trial"], display: "Final Cut Pro", kind: .video, tint: 0xC084FC),
        Known(names: ["compressor"], display: "Compressor", kind: .encoder, tint: 0xA78BFA),
        Known(names: ["imovie"], display: "iMovie", kind: .video, tint: 0x818CF8),
        Known(names: ["adobe premiere pro"], display: "Premiere Pro", kind: .video, tint: 0xA78BFA, prefix: true),
        Known(names: ["adobe after effects", "aerender", "aerendercore"], display: "After Effects", kind: .video,
              tint: 0xC084FC, prefix: true),
        Known(names: ["adobe media encoder"], display: "Media Encoder", kind: .encoder, tint: 0xA78BFA, prefix: true),
        Known(names: ["adobe lightroom classic"], display: "Lightroom Classic", kind: .photo, tint: 0x38BDF8,
              prefix: true),
        Known(names: ["adobe lightroom", "lightroom"], display: "Lightroom", kind: .photo, tint: 0x38BDF8, prefix: true),
        Known(names: ["adobe photoshop"], display: "Photoshop", kind: .photo, tint: 0x60A5FA, prefix: true),
        Known(names: ["photos", "photolibraryd"], display: "Photos", kind: .photo, tint: 0xFACC15),
        Known(names: ["capture one"], display: "Capture One", kind: .photo, tint: 0xE5E7EB, prefix: true),
        Known(names: ["affinity photo"], display: "Affinity Photo", kind: .photo, tint: 0xE879F9, prefix: true),
        Known(names: ["pixelmator pro"], display: "Pixelmator Pro", kind: .photo, tint: 0x2DD4BF),
        Known(names: ["capcut"], display: "CapCut", kind: .video, tint: 0x22D3EE),
        Known(names: ["ffmpeg", "ffmpeg-bin"], display: "ffmpeg", kind: .encoder, tint: 0x4ADE80),
        Known(names: ["handbrake", "handbrakecli"], display: "HandBrake", kind: .encoder, tint: 0xFB7185),
        Known(names: ["screencaptureui", "screencapture", "screenshot"], display: "Screenshot", kind: .recorder,
              tint: 0xF87171),
        Known(names: ["quicktime player"], display: "QuickTime Player", kind: .recorder, tint: 0x60A5FA),
        Known(names: ["logic pro", "logic pro x"], display: "Logic Pro", kind: .audio, tint: 0xF472B6),
        Known(names: ["garageband"], display: "GarageBand", kind: .audio, tint: 0xF472B6),
        Known(names: ["audacity"], display: "Audacity", kind: .audio, tint: 0xF472B6),
    ]

    /// Copies, syncs, downloads and stores: a file they write is not an export.
    static let ignoredWriters: Set<String> = [
        "finder", "desktopserviceshelper", "cp", "ditto", "rsync", "mv", "tar", "bsdtar", "unzip", "archive utility",
        "bomarch", "bird", "cloudd", "fileproviderd", "dropbox", "google drive", "onedrive", "box", "sharingd",
        "safari", "google chrome", "firefox", "arc", "microsoft edge", "brave browser", "curl", "wget", "tv", "music",
        "mdworker", "mdworker_shared", "quicklookd", "image capture",
    ]

    /// The app's name from its executable: the outermost `.app` in the
    /// path, or the program's own name outside an app.
    static func appName(executablePath: String) -> (name: String, bundle: String?) {
        let components = executablePath.split(separator: "/").map(String.init)
        if let index = components.firstIndex(where: { $0.lowercased().hasSuffix(".app") }) {
            let bundle = "/" + components[...index].joined(separator: "/")
            return (String(components[index].dropLast(4)), bundle)
        }
        return (components.last ?? "", nil)
    }

    static func attribution(executablePath: String, pid: Int32, ownPID: Int32, path: String) -> Attribution {
        guard pid != ownPID, !executablePath.isEmpty else { return pid == ownPID ? .ignored : .unknown }
        let (name, bundle) = appName(executablePath: executablePath)
        let lowered = name.lowercased()
        let program = (executablePath as NSString).lastPathComponent.lowercased()
        if lowered.hasPrefix("zenith") || ignoredWriters.contains(lowered) || ignoredWriters.contains(program) {
            return .ignored
        }
        if var producer = producer(named: lowered) ?? producer(named: program) {
            producer.bundlePath = bundle
            return .producer(producer)
        }
        guard !name.isEmpty else { return .unknown }
        return .producer(Producer(name: name, kind: kind(ofPath: path), tint: 0x2DD4BF, bundlePath: bundle))
    }

    static func producer(named lowered: String) -> Producer? {
        for entry in known where entry.names.contains(where: { entry.prefix ? lowered.hasPrefix($0) : lowered == $0 }) {
            return Producer(name: entry.display, kind: entry.kind, tint: entry.tint)
        }
        return nil
    }

    /// What a file is when nobody is known to have written it.
    static func kind(ofPath path: String) -> Producer.Kind {
        let ext = fileExtension(path)
        if videoExtensions.contains(ext) { return .video }
        if audioExtensions.contains(ext) { return .audio }
        if imageExtensions.contains(ext) { return .photo }
        return .other
    }

    static func fallbackSymbol(path: String) -> String {
        switch kind(ofPath: path) {
        case .video: return "film"
        case .audio: return "waveform"
        case .photo: return "photo"
        default: return fileExtension(path) == "pdf" ? "doc.richtext" : "film"
        }
    }

    /// A batch of images landing whole has no writer left to see. It is
    /// credited to an app that can export them and is running, photo apps
    /// first; with none running it is a copy and stays out.
    static func batchProducer(runningExecutables: [String]) -> Producer? {
        let producers = runningExecutables.compactMap { path -> Producer? in
            let (name, bundle) = appName(executablePath: path)
            // Apps only: a daemon such as photolibraryd always runs.
            guard bundle != nil, var producer = producer(named: name.lowercased()),
                  producer.kind == .photo || producer.kind == .video || producer.kind == .encoder else { return nil }
            producer.bundlePath = bundle
            return producer
        }
        let rank: (Producer) -> Int = { $0.kind == .photo ? 0 : 1 }
        return producers.min { rank($0) != rank($1) ? rank($0) < rank($1) : $0.name < $1.name }
    }

    /// The kernel keeps a file's open mode with FREAD (1) and FWRITE (2).
    static func isWriteMode(openFlags: UInt32) -> Bool { openFlags & 0x2 != 0 }

    // MARK: Tracking

    struct Configuration: Equatable, Sendable {
        var minimumBytes: Int64 = ExportTrackerSupport.megabyte
        /// How long a size holds still before the writer is asked.
        var stableWindow: TimeInterval = 4
        /// About how often a tracked size is read.
        var sampleInterval: TimeInterval = 1
        /// How long the ✓ stays.
        var resultDuration: TimeInterval = 8
        /// A batch ends once no image has landed for this long.
        var batchGap: TimeInterval = 4
        var batchMinimum = 3
        /// Who writes an active file is asked this many times before giving up.
        var attributionTries = 5
        /// A finished or left-out file is not tracked again for this long unless its size changes.
        var settledMemory: TimeInterval = 600
    }

    struct Job: Equatable, Sendable {
        let path: String
        var size: Int64
        let firstSeen: Date
        /// When the file came to be, if the file system says and it is recent.
        let created: Date?
        /// Set once it grew past the minimum: it shows from here.
        var started: Date?
        var lastGrowth: Date
        var lastSample: Date
        var grew = false
        var producer: Producer?
        var writerPID: Int32?
        var attributionTries = 0
        /// Asking walks every process, so a writer not found waits longer each time.
        var nextAttribution: Date?
        var lastCheck: Date?
        /// Bytes per second, smoothed.
        var rate: Double?
    }

    struct Batch: Equatable, Sendable {
        let folder: String
        var paths: [String]
        var bytes: Int64
        let first: Date
        var last: Date
        var producer: Producer?
        var producerAsked = false
    }

    /// An export that ended, for the ✓, the notice and the notification.
    struct Finished: Equatable, Sendable {
        let id: String
        /// The file, or the last image of a batch, to reveal.
        let path: String
        let name: String
        /// A batch's images.
        let count: Int?
        let bytes: Int64
        let duration: TimeInterval
        let producer: Producer?
        let ended: Date
        let started: Date
    }

    /// What the island shows. Its size while running is in `Live`, read by
    /// the strip alone, so the island lays out only when this changes.
    struct Activity: Equatable, Sendable {
        enum Phase: Equatable, Sendable { case running, finished }
        let id: String
        let phase: Phase
        let path: String
        let name: String
        let count: Int?
        let producer: Producer?
        let started: Date
        /// Finished only: the final size and how long it took.
        let bytes: Int64?
        let duration: TimeInterval
        /// More exports running beside this one.
        let others: Int

        var isRecording: Bool { producer?.kind == .recorder }
        var symbol: String { producer?.symbol ?? ExportTrackerSupport.fallbackSymbol(path: path) }
    }

    struct Live: Equatable, Sendable {
        let id: String
        let bytes: Int64
        let rate: Double?
    }

    private struct Settled: Equatable, Sendable {
        let bytes: Int64
        let at: Date
    }

    struct Tracker: Equatable, Sendable {
        private(set) var jobs: [String: Job] = [:]
        private(set) var batches: [String: Batch] = [:]
        private(set) var results: [Finished] = []
        private var settled: [String: Settled] = [:]
        private var announcements: [Finished] = []

        init() {}

        /// Something is tracked, so sizes are read every second.
        var isSampling: Bool { !jobs.isEmpty }
        var sampledPaths: [String] { jobs.keys.sorted() }

        /// The folder said `path` changed. Returns whether it is tracked now.
        @discardableResult
        mutating func noteChange(path: String, size: Int64?, created: Date? = nil, now: Date,
                                 configuration: Configuration) -> Bool {
            guard let size else {
                jobs[path] = nil
                return false
            }
            if jobs[path] != nil { return true }
            if let done = settled[path] {
                if now.timeIntervalSince(done.at) >= configuration.settledMemory {
                    settled[path] = nil
                } else if done.bytes == size {
                    // Metadata, a tag or Spotlight: the same file, untouched.
                    return false
                } else {
                    settled[path] = nil
                }
                // A file that finished moments ago and writes again picks up where it left.
                if let index = results.lastIndex(where: { $0.path == path && $0.count == nil }) {
                    let earlier = results.remove(at: index)
                    jobs[path] = Job(path: path, size: size, firstSeen: earlier.started, created: earlier.started,
                                     started: earlier.started, lastGrowth: now, lastSample: now, grew: true,
                                     producer: earlier.producer)
                    return true
                }
            }
            guard jobs.count < ExportTrackerSupport.maximumTracked else { return false }
            let recent = created.flatMap { now.timeIntervalSince($0) < 24 * 3600 && $0 <= now ? $0 : nil }
            jobs[path] = Job(path: path, size: size, firstSeen: now, created: recent, lastGrowth: now, lastSample: now)
            return true
        }

        /// The size read on a tick, nil once the file is gone.
        mutating func sample(path: String, size: Int64?, now: Date, configuration: Configuration) {
            guard var job = jobs[path] else { return }
            guard let size else {
                jobs[path] = nil
                return
            }
            let elapsed = now.timeIntervalSince(job.lastSample)
            if size != job.size {
                if size > job.size, elapsed > 0 {
                    let instant = Double(size - job.size) / elapsed
                    job.rate = job.rate.map { $0 * 0.7 + instant * 0.3 } ?? instant
                }
                job.grew = true
                job.lastGrowth = now
                job.size = size
            }
            job.lastSample = now
            let image = imageExtensions.contains(fileExtension(path))
            // An image must keep growing a moment longer: one of a batch is
            // often caught half written, and that is no export of its own.
            if job.started == nil, job.grew, job.size >= configuration.minimumBytes,
               !image || job.lastGrowth.timeIntervalSince(job.firstSeen) >= 2 * configuration.sampleInterval {
                job.started = min(job.created ?? job.firstSeen, job.firstSeen)
            }
            // An image that landed whole, or in a moment, joins its folder's batch.
            if job.started == nil, image, now.timeIntervalSince(job.lastGrowth) >= configuration.sampleInterval,
               now.timeIntervalSince(job.firstSeen) >= configuration.sampleInterval {
                jobs[path] = nil
                settled[path] = Settled(bytes: size, at: now)
                if size >= configuration.minimumBytes { join(path: path, size: size, seen: job.firstSeen, now: now) }
                return
            }
            jobs[path] = job
        }

        private mutating func join(path: String, size: Int64, seen: Date, now: Date) {
            let folder = (path as NSString).deletingLastPathComponent
            if var batch = batches[folder] {
                batch.paths.append(path)
                batch.bytes += size
                batch.last = max(batch.last, now)
                batches[folder] = batch
            } else {
                batches[folder] = Batch(folder: folder, paths: [path], bytes: size, first: seen, last: now)
            }
        }

        // MARK: Writers

        /// Active files nobody has been credited with yet.
        func wantsAttribution(now: Date, configuration: Configuration) -> [String] {
            jobs.values.filter {
                $0.started != nil && $0.producer == nil && $0.attributionTries < configuration.attributionTries
                    && ($0.nextAttribution.map { now >= $0 } ?? true)
            }
            .map(\.path).sorted()
        }

        mutating func attribute(path: String, _ attribution: Attribution, pid: Int32? = nil, now: Date) {
            guard var job = jobs[path] else { return }
            switch attribution {
            case .ignored:
                jobs[path] = nil
                settled[path] = Settled(bytes: job.size, at: job.lastSample)
                return
            case .producer(let producer):
                job.producer = producer
                job.writerPID = pid
            case .unknown:
                job.attributionTries += 1
                job.nextAttribution = now.addingTimeInterval(pow(2, Double(job.attributionTries)))
            }
            jobs[path] = job
        }

        /// Batches waiting to know whether an app that exports images runs.
        var wantsBatchProducer: [String] {
            batches.values.filter { !$0.producerAsked && $0.paths.count >= 1 }.map(\.folder).sorted()
        }

        mutating func setBatchProducer(folder: String, _ producer: Producer?) {
            guard var batch = batches[folder] else { return }
            batch.producer = producer
            batch.producerAsked = true
            batches[folder] = batch
        }

        /// Active files whose size held still long enough to ask whether
        /// anyone still writes them.
        func writerChecksDue(now: Date, configuration: Configuration) -> [(path: String, pid: Int32?)] {
            jobs.values.filter { job in
                job.started != nil && now.timeIntervalSince(job.lastGrowth) >= configuration.stableWindow
                    && job.lastCheck.map { now.timeIntervalSince($0) >= configuration.sampleInterval * 0.9 } ?? true
            }
            .sorted { $0.path < $1.path }
            .map { ($0.path, $0.writerPID) }
        }

        /// `writing` is nil when it could not be told: the size alone decides.
        mutating func writerChecked(path: String, writing: Bool?, writerPID: Int32? = nil, now: Date) {
            guard var job = jobs[path], let started = job.started else { return }
            if writing == true {
                job.lastCheck = now
                if let writerPID { job.writerPID = writerPID }
                jobs[path] = job
                return
            }
            jobs[path] = nil
            settled[path] = Settled(bytes: job.size, at: now)
            let finished = Finished(id: path, path: path, name: (path as NSString).lastPathComponent, count: nil,
                                    bytes: job.size, duration: max(0, job.lastGrowth.timeIntervalSince(started)),
                                    producer: job.producer, ended: now, started: started)
            results.append(finished)
            announcements.append(finished)
        }

        // MARK: Time

        /// Drops what never became an export, ends quiet batches and
        /// lets old results go.
        mutating func advance(now: Date, configuration: Configuration) {
            for job in jobs.values where job.started == nil
                && now.timeIntervalSince(job.lastGrowth) >= configuration.stableWindow {
                jobs[job.path] = nil
                settled[job.path] = Settled(bytes: job.size, at: now)
            }
            for batch in batches.values where now.timeIntervalSince(batch.last) >= configuration.batchGap {
                batches[batch.folder] = nil
                guard Self.isVisible(batch, configuration: configuration), let last = batch.paths.last else { continue }
                let finished = Finished(id: Self.batchID(batch.folder), path: last,
                                        name: (batch.folder as NSString).lastPathComponent, count: batch.paths.count,
                                        bytes: batch.bytes, duration: max(0, batch.last.timeIntervalSince(batch.first)),
                                        producer: batch.producer, ended: now, started: batch.first)
                results.append(finished)
                announcements.append(finished)
            }
            results.removeAll { now.timeIntervalSince($0.ended) >= configuration.resultDuration }
            settled = settled.filter { now.timeIntervalSince($0.value.at) < configuration.settledMemory }
        }

        /// Exports that ended since the last call, once each.
        mutating func takeFinished() -> [Finished] {
            defer { announcements = [] }
            return announcements
        }

        static func batchID(_ folder: String) -> String { "batch:" + folder }

        static func isVisible(_ batch: Batch, configuration: Configuration) -> Bool {
            batch.paths.count >= configuration.batchMinimum && batch.producer != nil
        }

        private struct Running {
            let id: String
            let path: String
            let name: String
            let count: Int?
            let producer: Producer?
            let started: Date
            let bytes: Int64
            let rate: Double?
        }

        private func running(configuration: Configuration) -> [Running] {
            let files = jobs.values.compactMap { job -> Running? in
                guard let started = job.started, job.size >= configuration.minimumBytes else { return nil }
                return Running(id: job.path, path: job.path, name: (job.path as NSString).lastPathComponent, count: nil,
                               producer: job.producer, started: started, bytes: job.size, rate: job.rate)
            }
            let groups = batches.values.filter { Self.isVisible($0, configuration: configuration) }.map { batch in
                Running(id: Self.batchID(batch.folder), path: batch.paths.last ?? batch.folder,
                        name: (batch.folder as NSString).lastPathComponent, count: batch.paths.count,
                        producer: batch.producer, started: batch.first, bytes: batch.bytes, rate: nil)
            }
            // Newest first; the id keeps two that started together in one order.
            return (files + groups).sorted { $0.started != $1.started ? $0.started > $1.started : $0.id < $1.id }
        }

        /// A result that just came in, else the newest export running, with how many more run.
        func activity(now: Date, configuration: Configuration) -> Activity? {
            let running = running(configuration: configuration)
            if let result = results.last(where: { now.timeIntervalSince($0.ended) < configuration.resultDuration }) {
                return Activity(id: result.id, phase: .finished, path: result.path, name: result.name,
                                count: result.count, producer: result.producer, started: result.started,
                                bytes: result.bytes, duration: result.duration,
                                others: running.filter { $0.id != result.id }.count)
            }
            guard let newest = running.first else { return nil }
            return Activity(id: newest.id, phase: .running, path: newest.path, name: newest.name, count: newest.count,
                            producer: newest.producer, started: newest.started, bytes: nil, duration: 0,
                            others: running.count - 1)
        }

        /// The size of what the island shows while it runs.
        func live(now: Date, configuration: Configuration) -> Live? {
            guard let shown = activity(now: now, configuration: configuration), shown.phase == .running,
                  let item = running(configuration: configuration).first(where: { $0.id == shown.id }) else { return nil }
            return Live(id: item.id, bytes: item.bytes, rate: item.rate)
        }

        /// When the island changes with no new size: a result running out or a batch ending.
        func nextChange(after now: Date, configuration: Configuration) -> Date? {
            let ends = results.map { $0.ended.addingTimeInterval(configuration.resultDuration) }
            let quiet = batches.values.map { $0.last.addingTimeInterval(configuration.batchGap) }
            return (ends + quiet).filter { $0 > now }.min()
        }
    }

    // MARK: Formatting

    /// `2.1 GB`, `512 MB`, `4.2 MB`, `830 KB`, in decimal units like Finder,
    /// with the language's decimal mark.
    static func size(_ bytes: Int64, locale: Locale = Locale(identifier: "en_US")) -> String {
        let value = Double(max(0, bytes))
        let units: [(Double, String)] = [(1e12, "TB"), (1e9, "GB"), (1e6, "MB"), (1e3, "KB")]
        for (scale, unit) in units where value >= scale * 0.9995 || (unit == "KB") {
            let amount = value / scale
            let digits = amount >= 99.95 || unit == "KB" ? 0 : (unit == "MB" && amount >= 9.995 ? 0 : 1)
            return number(amount, digits: digits, locale: locale) + " " + unit
        }
        return "0 KB"
    }

    /// The widest reading `size` gives, for a slot that never changes width.
    static func sizeTemplate(locale: Locale = Locale(identifier: "en_US")) -> String {
        "00" + (locale.decimalSeparator ?? ".") + "0 GB"
    }

    /// `48 MB/s`.
    static func rate(_ bytesPerSecond: Double, locale: Locale = Locale(identifier: "en_US")) -> String {
        guard bytesPerSecond.isFinite, bytesPerSecond > 0 else { return "" }
        return size(Int64(bytesPerSecond), locale: locale) + "/s"
    }

    /// `4.2 GB · 12:31`.
    static func finishedDetail(bytes: Int64, duration: TimeInterval, locale: Locale = Locale(identifier: "en_US")) -> String {
        size(bytes, locale: locale) + " · " + CommandActivitySupport.clock(duration)
    }

    /// A batch's count, `%d` in the language's template.
    static func filling(_ template: String, count: Int) -> String {
        template.replacingOccurrences(of: "%d", with: "\(max(0, count))")
    }

    private static func number(_ value: Double, digits: Int, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        formatter.roundingMode = .halfUp
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(digits)f", locale: locale, value)
    }
}
