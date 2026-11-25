// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CryptoKit
import Foundation

/// Zenith fork: Zenith Pocket's decisions on plain values, so they can be
/// tested without the relay, the screen or the services they read: what the
/// Mac's state says and what the share switches leave out, when it travels
/// live and when it goes in the box, what a phone's command does, how the
/// phone's batteries join Batteries, and where the pairing stands.

// MARK: - Preferences

extension PocketDefaults {
    /// When the phone was last heard from (seconds since 1970). This Mac's
    /// own state, kept out of settings backups like the pairing it belongs
    /// to; absent while a fresh pairing waits for the phone's first message.
    static let lastSeen = "zenithPocketLastSeen"

    /// The contract's defaults, registered at launch so the service and
    /// Settings (AppStorage included) read the same values.
    static func register(in defaults: UserDefaults = .standard) {
        defaults.register(defaults: [enabled: false, shareWallpaper: true, shareAgents: true,
                                     shareNowPlaying: true, allowAnswers: false])
    }
}

// MARK: - The Mac's state

/// What the share switches let through. Battery, lock, keep-awake, coding,
/// prayer and accessories always travel; these three are the person's call.
struct PocketSharing: Equatable {
    var wallpaper = true
    var agents = true
    var nowPlaying = true

    static func current(in defaults: UserDefaults = .standard) -> PocketSharing {
        PocketSharing(wallpaper: defaults.object(forKey: PocketDefaults.shareWallpaper) as? Bool ?? true,
                      agents: defaults.object(forKey: PocketDefaults.shareAgents) as? Bool ?? true,
                      nowPlaying: defaults.object(forKey: PocketDefaults.shareNowPlaying) as? Bool ?? true)
    }
}

/// Everything the Mac's state is made from, as read from Zenith's services.
/// Compared as is to tell whether anything changed, so it holds the readings
/// themselves (a song's position as sampled, not as it moves on).
struct PocketMacInputs: Equatable {
    struct Playback: Equatable {
        var title: String
        var artist: String
        var playing: Bool
        /// The position when the player was read, and when that was.
        var elapsed: TimeInterval?
        var sampledAt: Date
        var rate: Double
        var duration: TimeInterval?
    }

    var macName: String
    var battery: PocketMacState.Battery?
    var locked = false
    var awakeActive = false
    /// nil while awake means until turned off.
    var awakeEnd: Date?
    var coding: PocketMacState.Coding?
    var nextPrayer: PocketMacState.Prayer?
    var sessions: [ClaudeHooksSupport.Session] = []
    var playback: Playback?
    var accessories: [PocketMacState.Accessory] = []
    var wallpaperHash: String?
}

enum PocketStateBuilder {
    /// The most sessions, and the longest detail, the phone is sent.
    static let maximumSessions = 8
    static let maximumDetail = 80

    static func state(_ inputs: PocketMacInputs, sharing: PocketSharing, now: Date) -> PocketMacState {
        var state = PocketMacState(macName: inputs.macName)
        state.battery = inputs.battery
        state.locked = inputs.locked
        state.awakeUntil = awakeUntil(active: inputs.awakeActive, end: inputs.awakeEnd)
        state.coding = inputs.coding
        state.nextPrayer = inputs.nextPrayer
        state.accessories = inputs.accessories
        if sharing.agents {
            let sessions = Array(inputs.sessions.prefix(maximumSessions))
            state.sessions = sessions.map(session)
            state.questions = sessions.compactMap(question)
        }
        if sharing.nowPlaying, let playback = inputs.playback {
            state.nowPlaying = nowPlaying(playback, now: now)
        }
        if sharing.wallpaper { state.wallpaperHash = inputs.wallpaperHash }
        return state
    }

    /// `.distantFuture` for "until turned off", as the contract says.
    static func awakeUntil(active: Bool, end: Date?) -> Date? {
        guard active else { return nil }
        return end ?? .distantFuture
    }

    /// The Mac's own battery. Minutes count to full while it fills and to
    /// empty on battery; plugged in and held (a charge limit, Optimized
    /// Battery Charging) it is neither charging nor counting.
    static func battery(percent: Int?, charging: Bool, minutesToFull: Int?,
                        secondsToEmpty: TimeInterval?) -> PocketMacState.Battery? {
        guard let percent, (0...100).contains(percent) else { return nil }
        let minutes = charging ? minutesToFull : secondsToEmpty.map { Int(($0 / 60).rounded()) }
        return PocketMacState.Battery(percent: percent, charging: charging,
                                      minutesRemaining: minutes.flatMap { $0 > 0 ? $0 : nil })
    }

    /// Today's coding time, the daily goal when one is set, and the language
    /// with the most time today.
    static func coding(seconds: Double?, goalMinutes: Int,
                       languages: [WakaTimeSupport.Entry]) -> PocketMacState.Coding? {
        guard let seconds, seconds.isFinite, seconds >= 0 else { return nil }
        let total = Int(seconds.rounded())
        var coding = PocketMacState.Coding(seconds: total, goalSeconds: goalMinutes > 0 ? goalMinutes * 60 : nil)
        if let top = languages.max(by: { $0.seconds < $1.seconds }), top.seconds > 0, seconds > 0 {
            coding.topLanguage = top.name
            coding.topLanguagePercent = min(100, Int((top.seconds / seconds * 100).rounded()))
        }
        return coding
    }

    static func playback(_ playback: NotchPlayback) -> PocketMacInputs.Playback? {
        let title = playback.track.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let artist = playback.track.artist?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !title.isEmpty || !artist.isEmpty else { return nil }
        let timed = playback.hasPosition && playback.duration > 0
        return PocketMacInputs.Playback(title: title, artist: artist, playing: playback.isPlaying,
                                        elapsed: timed ? playback.elapsed : nil, sampledAt: playback.sampledAt,
                                        rate: playback.rate, duration: timed ? playback.duration : nil)
    }

    /// The position as of `now`, so the phone can count on from `sentAt`.
    static func nowPlaying(_ playback: PocketMacInputs.Playback, now: Date) -> PocketMacState.NowPlaying {
        var elapsed = playback.elapsed
        if let start = elapsed, playback.playing {
            elapsed = start + max(0, now.timeIntervalSince(playback.sampledAt)) * playback.rate
        }
        if let value = elapsed, let duration = playback.duration { elapsed = min(duration, max(0, value)) }
        return PocketMacState.NowPlaying(title: playback.title, artist: playback.artist, playing: playback.playing,
                                         elapsed: elapsed, duration: playback.duration)
    }

    static func session(_ session: ClaudeHooksSupport.Session) -> PocketMacState.AgentSession {
        let status: PocketMacState.AgentSession.Status
        let since: Date
        switch session.state {
        case .working: status = .running; since = session.turnStarted
        case .waiting: status = .waiting; since = session.waitingSince ?? session.lastEvent
        case .done: status = .done; since = session.finished ?? session.lastEvent
        }
        return PocketMacState.AgentSession(id: session.id, project: project(session), status: status, since: since)
    }

    /// A session waiting for permission, shown as the question it asks: the
    /// tool still running and what it touches (a file's or program's name,
    /// all the hook ever keeps). Read only: see `PocketCommands`.
    static func question(_ session: ClaudeHooksSupport.Session) -> PocketMacState.AgentQuestion? {
        guard case .waiting(.permission) = session.state else { return nil }
        let asked = session.waitingSince ?? session.lastEvent
        let step = session.steps.last { $0.phase == .running } ?? session.steps.last
        let detail = step?.target.map { String($0.prefix(maximumDetail)) } ?? ""
        return PocketMacState.AgentQuestion(id: session.id + "@" + String(Int(asked.timeIntervalSince1970 * 1000)),
                                            project: project(session), tool: step?.toolName ?? "Claude Code",
                                            detail: detail, askedAt: asked)
    }

    private static func project(_ session: ClaudeHooksSupport.Session) -> String {
        session.folder.isEmpty ? "Claude Code" : session.folder
    }

    /// Batteries' devices for the phone, without the Mac itself (it has its
    /// own line) and without the phone and Watch the phone reports itself.
    static func accessories(_ devices: [BatteryDevice],
                            report: [PocketDeviceReport.Device]) -> [PocketMacState.Accessory] {
        devices.filter { device in
            device.kind != .mac && device.source != .pocket
                && !report.contains { PocketBatteries.matches(device, $0, among: devices) }
        }.map { device in
            PocketMacState.Accessory(id: device.id, name: device.name, kind: device.kind.rawValue,
                                     percent: device.percent, charging: device.isCharging,
                                     seenAt: device.unreachableSince)
        }
    }
}

// MARK: - Cadence

/// When the state travels. Live: a change waits `debounce` for others to
/// join it, and two sends are at least `minimumLiveInterval` apart. The box
/// (for a phone whose app is closed): at once for a change worth waking up
/// to, otherwise at most once a `boxInterval`. Nothing changes, nothing goes.
enum PocketCadence {
    static let debounce: TimeInterval = 2
    static let minimumLiveInterval: TimeInterval = 5
    static let boxInterval: TimeInterval = 60

    static func liveDelay(now: Date, lastSent: Date?) -> TimeInterval {
        guard let lastSent else { return debounce }
        return max(debounce, minimumLiveInterval - now.timeIntervalSince(lastSent))
    }

    enum BoxDecision: Equatable {
        case now
        case after(TimeInterval)
        case none
    }

    static func box(_ inputs: PocketMacInputs, sharing: PocketSharing, written: PocketMacInputs?,
                    sharingWritten: PocketSharing?, writtenAt: Date?, now: Date) -> BoxDecision {
        guard let written, let writtenAt, sharingWritten == sharing else { return .now }
        if inputs == written { return .none }
        if signature(inputs, sharing: sharing) != signature(written, sharing: sharing) { return .now }
        let wait = boxInterval - now.timeIntervalSince(writtenAt)
        return wait <= 0 ? .now : .after(wait)
    }

    /// What is worth writing the box for at once: the lock, keep-awake, a
    /// plug, every fifth percent, a session or question coming or going, a
    /// new song or a pause, the next prayer, an accessory appearing, a new
    /// wallpaper. Coding seconds, a song's position and small battery steps
    /// wait for the minute.
    static func signature(_ inputs: PocketMacInputs, sharing: PocketSharing) -> [String] {
        var parts = [inputs.macName, String(inputs.locked), String(inputs.awakeActive),
                     inputs.awakeEnd.map { String($0.timeIntervalSince1970) } ?? "-"]
        if let battery = inputs.battery {
            parts.append("battery \(battery.charging) \(battery.percent / 5)")
        }
        if let prayer = inputs.nextPrayer { parts.append("prayer \(prayer.name) \(prayer.at.timeIntervalSince1970)") }
        if sharing.agents {
            parts += inputs.sessions.prefix(PocketStateBuilder.maximumSessions).map { session in
                let state: String
                switch session.state {
                case .working: state = "working"
                case .waiting(let attention): state = "waiting " + attention.rawValue
                case .done: state = "done"
                }
                return "session \(session.id) \(state)"
            }
        }
        if sharing.nowPlaying, let playback = inputs.playback {
            parts.append("song \(playback.title) \(playback.artist) \(playback.playing)")
        }
        parts += inputs.accessories.map { "accessory \($0.id) \($0.charging) \($0.seenAt == nil)" }
        if sharing.wallpaper { parts.append("wallpaper " + (inputs.wallpaperHash ?? "-")) }
        return parts
    }
}

// MARK: - Commands

/// What a phone's command does on this Mac. Nothing beyond these exists.
enum PocketCommandPlan: Equatable {
    case lock
    case keepAwakeOff
    /// Until turned off.
    case keepAwakeIndefinitely
    /// One of Keep Awake's own durations, so it is remembered as the last pick.
    case keepAwakePreset(minutes: Int)
    /// Any other length, as an end time.
    case keepAwakeFor(minutes: Int)
    case media(NotchPlaybackCommand)
    /// Only once a path to answer Claude Code exists (see `answersUnavailable`).
    case answer(questionID: String, allow: Bool)
    case refresh
    case refuse(String)
}

enum PocketCommands {
    /// The longest keep-awake a phone may ask for.
    static let maximumAwakeMinutes = 24 * 60

    static let answersOff = "Answering Claude Code from the phone is off on this Mac."
    /// Claude Code's hook only reports to Zenith; nothing waits for an
    /// answer. Answering needs a blocking PreToolUse (or PermissionRequest)
    /// hook that holds the tool until Zenith writes allow or deny back.
    static let answersUnavailable = "This Mac can't answer Claude Code from the phone yet."
    static let badAwakeLength = "That keep-awake length isn't supported."
    static let keepAwakeOff = "Keep Awake is turned off in Zenith."

    /// `canAnswer` is whether a path to answer Claude Code exists (none yet).
    static func plan(_ command: PocketCommand, allowAnswers: Bool, canAnswer: Bool = false,
                     presets: [Int] = Defaults.allowedDurations) -> PocketCommandPlan {
        switch command {
        case .lock:
            return .lock
        case .keepAwake(let minutes):
            guard let minutes else { return .keepAwakeOff }
            if minutes == 0 { return .keepAwakeIndefinitely }
            guard (1...maximumAwakeMinutes).contains(minutes) else { return .refuse(badAwakeLength) }
            return presets.contains(minutes) ? .keepAwakePreset(minutes: minutes) : .keepAwakeFor(minutes: minutes)
        case .media(let action):
            switch action {
            case .playPause: return .media(.toggle)
            case .next: return .media(.next)
            case .previous: return .media(.previous)
            }
        case .answer(let questionID, let allow):
            guard allowAnswers else { return .refuse(answersOff) }
            guard canAnswer else { return .refuse(answersUnavailable) }
            return .answer(questionID: questionID, allow: allow)
        case .refresh:
            return .refresh
        }
    }

    /// The media key a player that Zenith's adapter cannot reach still hears
    /// (NX_KEYTYPE_PLAY / FAST / REWIND, as RadialMenuMediaKey has them).
    static func mediaKey(_ command: NotchPlaybackCommand) -> RadialMenuMediaKey? {
        switch command {
        case .toggle: return .playPause
        case .next: return .nextTrack
        case .previous: return .previousTrack
        default: return nil
        }
    }
}

// MARK: - Batteries

/// The phone's report as Batteries devices, and how they meet the same
/// iPhone or Watch read over USB, Wi-Fi or Bluetooth.
enum PocketBatteries {
    static let idPrefix = "pocket-"
    /// A reading older than this shows dimmed, as a last-known level.
    static let freshFor: TimeInterval = 30 * 60
    /// Older than this it is dropped.
    static let keptFor: TimeInterval = BatteriesDefaults.lastKnownLifetime

    static func isPocketID(_ id: String) -> Bool { id.hasPrefix(idPrefix) }

    /// One device per kind, levels in range, names trimmed and short, none
    /// from the future (a phone's clock may run ahead).
    static func sanitized(_ report: PocketDeviceReport, now: Date) -> [PocketDeviceReport.Device] {
        var seen = Set<PocketDeviceReport.Device.Kind>()
        return report.devices.compactMap { device in
            guard (0...100).contains(device.percent), seen.insert(device.kind).inserted else { return nil }
            var clean = device
            let name = device.name.trimmingCharacters(in: .whitespacesAndNewlines)
            clean.name = name.isEmpty ? fallbackName(device.kind) : String(name.prefix(64))
            clean.readAt = min(device.readAt, now)
            return now.timeIntervalSince(clean.readAt) <= keptFor ? clean : nil
        }
    }

    /// The latest reading in a report, to keep the newer of two.
    static func readAt(_ devices: [PocketDeviceReport.Device]) -> Date? {
        devices.map(\.readAt).max()
    }

    static func device(_ reading: PocketDeviceReport.Device, now: Date) -> BatteryDevice {
        BatteryDevice(id: idPrefix + reading.kind.rawValue, name: reading.name, kind: kind(reading.kind),
                      source: .pocket, percent: reading.percent, isCharging: reading.charging,
                      fullyCharged: reading.charging && reading.percent >= 100,
                      unreachableSince: now.timeIntervalSince(reading.readAt) > freshFor ? reading.readAt : nil)
    }

    /// Whether a device Batteries read is the phone (or Watch) the report is
    /// about: the same kind and name, or, when the phone gives only its model
    /// ("iPhone 13 Pro", as iOS tells apps without the name entitlement), the
    /// only one of that kind.
    static func matches(_ device: BatteryDevice, _ reading: PocketDeviceReport.Device,
                        among devices: [BatteryDevice]) -> Bool {
        guard device.source != .pocket, device.kind == kind(reading.kind) else { return false }
        if BatteriesNames.key(device.name) == BatteriesNames.key(reading.name) { return true }
        guard isGeneric(reading) else { return false }
        return devices.filter { $0.source != .pocket && $0.kind == device.kind }.count == 1
    }

    /// The scan's devices with the phone's report in: a device read both
    /// ways is one entry, under Batteries' id (so hiding and muting keep
    /// working), with the fresher reading; anything else from the report
    /// joins as its own entry.
    static func merged(scan: [BatteryDevice], scanDate: Date, report: [PocketDeviceReport.Device],
                       now: Date) -> [BatteryDevice] {
        var result = scan
        for reading in report {
            let own = device(reading, now: now)
            guard let index = result.firstIndex(where: { matches($0, reading, among: scan) }) else {
                result.append(own)
                continue
            }
            let scanned = result[index]
            let scannedAt = scanned.percent == nil ? .distantPast : (scanned.unreachableSince ?? scanDate)
            guard reading.readAt > scannedAt else { continue }
            var joined = scanned
            joined.percent = own.percent
            joined.isCharging = own.isCharging
            joined.fullyCharged = own.fullyCharged
            joined.unreachableSince = own.unreachableSince
            joined.source = .pocket
            result[index] = joined
        }
        return result
    }

    private static func kind(_ kind: PocketDeviceReport.Device.Kind) -> BatteryDeviceKind {
        kind == .iphone ? .iphone : .watch
    }

    private static func fallbackName(_ kind: PocketDeviceReport.Device.Kind) -> String {
        kind == .iphone ? "iPhone" : "Apple Watch"
    }

    private static func isGeneric(_ reading: PocketDeviceReport.Device) -> Bool {
        BatteriesNames.key(reading.name).hasPrefix(BatteriesNames.key(fallbackName(reading.kind)))
    }
}

// MARK: - Wallpaper

enum PocketWallpaperSupport {
    /// The thumbnail's longest side and JPEG quality: a phone background, not a print.
    static let maximumPixels = 480
    static let quality = 0.6

    /// What `PocketMacState.wallpaperHash` carries: the thumbnail's SHA-256, in hex.
    static func hash(_ jpeg: Data) -> String {
        SHA256.hash(data: jpeg).map { String(format: "%02x", $0) }.joined()
    }

    /// The picture is read again only when its file or its date changed.
    static func key(path: String, modified: Date?) -> String {
        path + "|" + (modified.map { String($0.timeIntervalSince1970) } ?? "-")
    }
}

// MARK: - Pairing

enum PocketPhaseRules {
    /// A phone message moves `lastSeen` on in the store only this far apart,
    /// so Settings is not redrawn for every report.
    static let seenGranularity: TimeInterval = 30

    /// `lastSeen` is the phone's last message ever (kept in preferences); a
    /// saved pairing the phone never answered still shows its QR code.
    static func phase(enabled: Bool, relay: PocketRelayConfig?, pairing: PocketPairing?,
                      lastSeen: Date?) -> PocketPhase {
        guard enabled, relay != nil else { return .off }
        guard let pairing else { return .unpaired }
        guard let lastSeen else { return .pairing(pairing) }
        return .paired(lastSeen: lastSeen)
    }

    /// Whether a new message's time is worth publishing.
    static func publishesSeen(_ next: Date, after previous: Date?) -> Bool {
        guard let previous else { return true }
        return next.timeIntervalSince(previous) >= seenGranularity
    }

    /// Saving a relay forgets the pairing unless it is the same relay: the
    /// pairing (and the phone) lives on the old one.
    static func forgetsPairing(saving relay: PocketRelayConfig?, over current: PocketRelayConfig?) -> Bool {
        relay != current
    }

    static let invalidRelay = "That relay URL or key doesn't look right. Use the project's https URL and its anon key."
    static let turnOnFirst = "Turn on Zenith Pocket and save a relay first."
    static let couldNotSave = "Zenith couldn't save the pairing on this Mac."

    /// A box write that failed: the relay's HTTP status, or 0 without an answer.
    static func relayProblem(status: Int) -> String {
        status > 0 ? "The relay refused Zenith's update (HTTP \(status)). Check its URL, key and functions."
            : "Zenith couldn't reach the relay."
    }
}
