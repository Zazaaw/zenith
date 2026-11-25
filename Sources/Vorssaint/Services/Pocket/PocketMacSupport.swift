// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: the Mac tab's decisions, on plain values so they can be tested
// without a phone, a relay or the services they drive: what each command
// asks for and why one is refused, which process may be quit, how a dropped
// file is named, how the health readings are rounded, and when sampling runs.

extension PocketDefaults {
    /// The latest text clips travel to the phone. Off by default: a clipboard
    /// holds what people copy without thinking about it.
    static let shareClipboard = "zenithPocketShareClipboard"   // Bool, default false
    /// The phone may quit one of the busiest apps. Off by default.
    static let allowQuit = "zenithPocketAllowQuit"             // Bool, default false
}

// MARK: - Commands

/// What one of the Mac tab's commands asks for, once checked.
enum PocketMacPlan: Equatable {
    case volume(Double)
    case output(String)
    case muteMic(Bool)
    case seek(TimeInterval)
    case workspace(UUID)
    case startTimer(minutes: Int)
    case stopTimer
    case pauseTimer(Bool)
    case stopDevServer(port: Int)
    case quit(pid: Int32)
    case clipboard(String)
    case open(URL)
    case collect(slot: Int)
    case refuse(String)
}

enum PocketMacCommands {
    static let maximumText = 20_000
    static let maximumTimerMinutes = 180

    static let badVolume = "That volume isn't supported."
    static let badOutput = "That sound output isn't on this Mac."
    static let badPosition = "That position isn't in the song."
    static let badWorkspace = "That workspace isn't on this Mac."
    static let badTimer = "Timers run from 1 minute to 3 hours."
    static let badPort = "That port isn't a dev server."
    static let badProcess = "That app isn't one Pocket can quit."
    static let emptyText = "There's no text to send."
    static let longText = "That text is too long for the clipboard (20,000 characters at most)."
    static let badLink = "Pocket opens http and https links only."
    static let badSlot = "That drop isn't one Pocket made."

    /// The plan for a command of the Mac tab; nil for any other command.
    static func plan(_ command: PocketCommand) -> PocketMacPlan? {
        switch command {
        case .setVolume(let value):
            guard (0...100).contains(value) else { return .refuse(badVolume) }
            return .volume(Double(value) / 100)
        case .setOutput(let id):
            guard !id.isEmpty, id.count <= 512 else { return .refuse(badOutput) }
            return .output(id)
        case .muteMic(let muted):
            return .muteMic(muted)
        case .seek(let seconds):
            guard seconds.isFinite, seconds >= 0 else { return .refuse(badPosition) }
            return .seek(seconds)
        case .openWorkspace(let id):
            guard let uuid = UUID(uuidString: id) else { return .refuse(badWorkspace) }
            return .workspace(uuid)
        case .timer(let minutes, _):
            guard let minutes else { return .stopTimer }
            guard (1...maximumTimerMinutes).contains(minutes) else { return .refuse(badTimer) }
            return .startTimer(minutes: minutes)
        case .pauseTimer(let paused):
            return .pauseTimer(paused)
        case .stopDevServer(let port):
            guard (1...65_535).contains(port) else { return .refuse(badPort) }
            return .stopDevServer(port: port)
        case .quitProcess(let pid):
            guard pid > 1 else { return .refuse(badProcess) }
            return .quit(pid: pid)
        case .sendText(let text):
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .refuse(emptyText) }
            guard text.count <= maximumText else { return .refuse(longText) }
            return .clipboard(text)
        case .openURL(let text):
            guard let url = PocketLinkRules.url(text) else { return .refuse(badLink) }
            return .open(url)
        case .collectDrop(let slot):
            guard (0..<PocketPairing.dropSlots).contains(slot) else { return .refuse(badSlot) }
            return .collect(slot: slot)
        default:
            return nil
        }
    }
}

enum PocketLinkRules {
    /// An http or https link with a host, nothing else: no file, no custom
    /// scheme that would start an app.
    static func url(_ text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 4_096,
              let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }
}

// MARK: - Sampling

/// Health and sound are read only while a phone has Pocket open, at a pace
/// far under the monitor's own panel.
enum PocketMacCadence {
    static let health: TimeInterval = 4
    /// The busiest processes every this many health ticks (8 s).
    static let topEvery = 2
    /// The startup disk's free space every this many health ticks (32 s).
    static let diskEvery = 8
    static let sound: TimeInterval = 3
}

/// Whether a sampling part runs: the link is up and a phone watches.
struct PocketSampling: Equatable {
    enum Change: Equatable { case start, stop, none }
    private(set) var linkUp = false
    private(set) var watching = false
    var running: Bool { linkUp && watching }

    mutating func setLink(_ up: Bool) -> Change {
        let before = running
        linkUp = up
        // A new link waits for the phone to say it watches again.
        if !up { watching = false }
        return change(from: before)
    }

    mutating func setWatching(_ open: Bool) -> Change {
        let before = running
        watching = open
        return change(from: before)
    }

    private func change(from before: Bool) -> Change {
        running == before ? .none : (running ? .start : .stop)
    }
}

// MARK: - Health

enum PocketHealthRules {
    struct Reading {
        var cpu: Double?
        var temperature: Double?
        var memoryUsed: UInt64?
        var memoryTotal: UInt64?
        var diskFree: Int64?
        var diskTotal: Int64?
        var down: Double?
        var up: Double?
    }

    /// The state's health, nil until the CPU has been read once.
    static func health(_ reading: Reading, top: [PocketHealth.Process]) -> PocketHealth? {
        guard let cpu = reading.cpu, cpu.isFinite else { return nil }
        let memory: Int? = {
            guard let used = reading.memoryUsed, let total = reading.memoryTotal, total > 0 else { return nil }
            return min(100, max(0, Int((Double(used) / Double(total) * 100).rounded())))
        }()
        let disk = reading.diskTotal.flatMap { $0 > 0 ? $0 : nil }
        return PocketHealth(cpuPercent: min(100, max(0, Int((cpu * 100).rounded()))),
                            temperature: reading.temperature.flatMap(temperature),
                            memoryPercent: memory,
                            diskFree: disk.flatMap { total in reading.diskFree.map { min(max(0, $0), total) } },
                            diskTotal: disk,
                            networkDown: reading.down.flatMap(rate),
                            networkUp: reading.up.flatMap(rate),
                            top: busiest(top))
    }

    /// Whole degrees; a sensor reading out of any chip's range is no reading.
    static func temperature(_ celsius: Double) -> Double? {
        guard celsius.isFinite, celsius > 0, celsius < 130 else { return nil }
        return celsius.rounded()
    }

    /// Two significant figures: enough for "1.2 MB/s", and the state doesn't
    /// change with every byte.
    static func rate(_ bytesPerSecond: Double) -> Int64? {
        guard bytesPerSecond.isFinite else { return nil }
        let value = max(0, bytesPerSecond)
        guard value >= 100 else { return Int64(value.rounded()) }
        let scale = pow(10, floor(log10(value)) - 1)
        return Int64((value / scale).rounded() * scale)
    }

    /// The five busiest, named shortly, a tenth of a percent at most precise.
    static func busiest(_ rows: [PocketHealth.Process]) -> [PocketHealth.Process] {
        rows.filter { $0.cpu.isFinite && $0.cpu >= 0.1 && $0.pid > 0 }
            .sorted { $0.cpu > $1.cpu }
            .prefix(5)
            .map { row in
                let name = row.name.trimmingCharacters(in: .whitespacesAndNewlines)
                return PocketHealth.Process(pid: row.pid, name: String((name.isEmpty ? "pid \(row.pid)" : name).prefix(40)),
                                            cpu: (row.cpu * 10).rounded() / 10)
            }
    }
}

// MARK: - Quitting

enum PocketQuitRules {
    /// A process the phone was shown among the busiest.
    struct Shared: Equatable {
        var name: String
        var startedAt: UInt64?
    }

    /// What is known about the process now.
    struct Facts {
        var ownPID: Int32
        /// The kernel's start time now; nil when it is gone.
        var startedAt: UInt64?
        var isApp: Bool
        var bundleID: String?
        var path: String?
        /// `KillProcessSupport.isProtected` (kernel, launchd, WindowServer …).
        var protectedProcess: Bool
    }

    enum Verdict: Equatable {
        case quit(name: String)
        case refuse(String)
    }

    static let off = "Quitting apps from the phone is off on this Mac."
    static let itself = "Zenith can't quit itself from the phone."
    static let notListed = "That app isn't among the busiest anymore."
    static let gone = "That app has already quit."
    static let system = "That's part of macOS, so it keeps running."
    static let notApp = "Only apps can be quit from the phone."

    /// macOS's own apps that keep the desktop working.
    static let protectedBundles: Set<String> = [
        "com.apple.finder", "com.apple.dock", "com.apple.systemuiserver", "com.apple.controlcenter",
        "com.apple.loginwindow", "com.apple.windowmanager", "com.apple.notificationcenterui",
        "com.apple.spotlight", "com.apple.securityagent", "com.apple.coreservices.uiagent",
        "com.apple.wallpaper.agent", "com.apple.dock.extra",
    ]
    static let ownBundlePrefixes = ["id.satuvisual.zenith", "com.vorssaint"]
    static let systemPaths = ["/System/", "/usr/", "/sbin/", "/bin/", "/Library/Apple/"]

    static func verdict(pid: Int32, allowed: Bool, shared: [Int32: Shared], facts: Facts) -> Verdict {
        guard allowed else { return .refuse(off) }
        let bundle = facts.bundleID?.lowercased() ?? ""
        if pid == facts.ownPID || ownBundlePrefixes.contains(where: { bundle.hasPrefix($0) }) { return .refuse(itself) }
        guard let row = shared[pid] else { return .refuse(notListed) }
        guard let now = facts.startedAt else { return .refuse(gone) }
        // The same pid on a process started since is a different process.
        if let then = row.startedAt, then != now { return .refuse(gone) }
        if facts.protectedProcess || protectedBundles.contains(bundle) { return .refuse(system) }
        if let path = facts.path, isSystemPath(path) { return .refuse(system) }
        guard facts.isApp else { return .refuse(notApp) }
        return .quit(name: row.name)
    }

    /// macOS's own code, except the apps it ships for people (Music, Notes …).
    static func isSystemPath(_ path: String) -> Bool {
        if path.hasPrefix("/System/Applications/") || path.contains("/Cryptexes/App/System/Applications/") { return false }
        return systemPaths.contains { path.hasPrefix($0) }
    }

    static func asked(_ name: String) -> String { "Asked \(name) to quit." }
}

// MARK: - Drops

enum PocketDropRules {
    static let folderName = "Pocket"
    /// A drop older than this isn't collected: the phone gave up on it.
    static let freshFor: TimeInterval = 15 * 60
    static let maximumNameLength = 120

    static let empty = "That drop is empty."
    static let tooBig = "That file is too big for Pocket."
    static let stale = "That file waited too long. Send it again."
    static let missing = "Pocket couldn't find that file. Send it again."
    static let couldNotSave = "Pocket couldn't save that file in Downloads."

    static func refusal(_ drop: PocketDrop, sentAt: Date, now: Date) -> String? {
        if drop.data.isEmpty { return empty }
        if drop.data.count > PocketDrop.maxBytes { return tooBig }
        if now.timeIntervalSince(sentAt) > freshFor || sentAt.timeIntervalSince(now) > 120 { return stale }
        return nil
    }

    /// A plain file name: no folders, no hidden file, no control characters,
    /// the extension kept when it is shortened. A photo without one is a JPEG.
    static func sanitizedName(_ raw: String, kind: PocketDrop.Kind, now: Date) -> String {
        var name = String(raw.unicodeScalars.map { scalar -> Character in
            if CharacterSet.controlCharacters.contains(scalar) || "/\\:".unicodeScalars.contains(scalar) { return "-" }
            return Character(scalar)
        })
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        while name.hasPrefix(".") || name.hasPrefix("-") { name.removeFirst() }
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var ext = (name as NSString).pathExtension
        var stem = (name as NSString).deletingPathExtension
        if ext.count > 10 || ext.contains(" ") { stem = name; ext = "" }
        if stem.isEmpty {
            stem = "Pocket \(kind == .photo ? "photo" : "file") " + stamp(now)
        }
        if ext.isEmpty, kind == .photo { ext = "jpg" }
        let room = maximumNameLength - (ext.isEmpty ? 0 : ext.count + 1)
        if stem.count > room { stem = String(stem.prefix(room)).trimmingCharacters(in: .whitespaces) }
        return ext.isEmpty ? stem : stem + "." + ext
    }

    /// "photo.jpg", then "photo 2.jpg", "photo 3.jpg" …: never over a file.
    static func available(_ name: String, exists: (String) -> Bool) -> String? {
        guard exists(name) else { return name }
        let ext = (name as NSString).pathExtension
        let stem = (name as NSString).deletingPathExtension
        for number in 2...999 {
            let next = ext.isEmpty ? "\(stem) \(number)" : "\(stem) \(number).\(ext)"
            if !exists(next) { return next }
        }
        return nil
    }

    static func saved(_ name: String) -> String { "Saved \(name) to Downloads/Pocket." }

    private static func stamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return formatter.string(from: date)
    }
}

// MARK: - Sound

enum PocketSoundRules {
    enum Transport { case builtIn, bluetooth, usb, display, airPlay, other }

    /// The phone's glyph for an output.
    static func kind(_ transport: Transport, name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("airpods") { return "airpods" }
        let headphones = ["headphone", "headset", "earbuds", "buds"].contains { lower.contains($0) }
        switch transport {
        case .builtIn: return headphones ? "headphones" : "speakers"
        case .bluetooth: return headphones ? "headphones" : "bluetooth"
        case .display: return "display"
        case .usb: return headphones ? "headphones" : "other"
        case .airPlay, .other: return "other"
        }
    }

    static func percent(_ scalar: Float) -> Int {
        guard scalar.isFinite else { return 0 }
        return min(100, max(0, Int((scalar * 100).rounded())))
    }
}

// MARK: - Tools

enum PocketToolsRules {
    struct Event {
        var title: String
        var start: Date
        var end: Date
        var allDay: Bool
    }

    /// The next timed event that hasn't ended, within the coming day.
    static func nextEvent(_ events: [Event], now: Date) -> PocketTools.Event? {
        events.filter { !$0.allDay && $0.end > now && $0.start < now.addingTimeInterval(24 * 3600) }
            .min { $0.start < $1.start }
            .map { PocketTools.Event(title: String($0.title.prefix(80)), start: $0.start, end: $0.end) }
    }

    /// When the next event stops being the same one: it starts, then ends.
    static func nextChange(_ events: [Event], now: Date) -> Date? {
        events.flatMap { [$0.start, $0.end] }.filter { $0 > now }.min()
    }

    /// The newest text clips, shortened (≤ 10, ≤ 300 characters each).
    static func clips(_ texts: [String]) -> [String] {
        texts.compactMap { text -> String? in
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return trimmed.count > 300 ? String(trimmed.prefix(299)) + "…" : trimmed
        }
        .prefix(10).map { $0 }
    }

    static let timerOff = "The island timer is turned off in Zenith."
    static let noTimer = "No timer is running."
    static let workspaceBusy = "Another workspace is still opening."
    static let devServerGone = "That dev server isn't running anymore."
    static let devServerKeep = "Zenith doesn't stop that kind of server."
}

/// A part handed to a Task without the Task owning it: the part may be gone
/// (the link stopped) by the time the relay answers.
final class PocketWeak<Value: AnyObject>: @unchecked Sendable {
    weak var value: Value?
    init(_ value: Value) { self.value = value }
}
