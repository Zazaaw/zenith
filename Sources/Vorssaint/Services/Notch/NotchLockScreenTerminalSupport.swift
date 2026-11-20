// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation

/// Zenith fork: a line of the terminal readout under the lock screen clock.
///
/// The readout is not a terminal. It is a monospaced status board that reads
/// like one: a dim prompt, a short label, then a value. Labels stay English in
/// every language, as a command line's output would.
enum NotchLockScreenTerminalSource: String, CaseIterable, Identifiable {
    case agents, waka, vercel, ci, sys, dl, timer
    // Zenith fork: the next prayer, and the golden hour (SkyService).
    case prayer, golden

    var id: String { rawValue }

    /// The readout's own label; the prayer's is `sholat` with Indonesian names.
    var label: String { self == .prayer ? prayerLabel(indonesian: NotchLockScreenTerminalSupport.prayerNamesIndonesian()) : rawValue }

    func prayerLabel(indonesian: Bool) -> String { indonesian ? "sholat" : "prayer" }

    /// Lines that reach a network service or run a command line start off;
    /// the person turns them on knowing what they ask for. The Sky lines
    /// start off too, so the readout stays as it was.
    var isOnByDefault: Bool { self != .vercel && self != .ci && self != .prayer && self != .golden }

    /// `sys` shows whenever it is chosen; every other line only with something to say.
    var alwaysShows: Bool { self == .sys }
}

/// Which lines the readout shows, and in what order. Stored as one string:
/// every line in its place, a line that is off led by "-".
struct NotchLockScreenTerminalSelection: Equatable {
    struct Entry: Equatable, Identifiable {
        let source: NotchLockScreenTerminalSource
        var isOn: Bool
        var id: String { source.rawValue }
    }

    private(set) var entries: [Entry]

    static let defaultEntries = NotchLockScreenTerminalSource.allCases.map { Entry(source: $0, isOn: $0.isOnByDefault) }
    static let defaultValue = encode(defaultEntries)

    /// Unknown or repeated names are skipped; a line missing from the stored
    /// order, such as one a later version adds, joins at the end, off.
    init(stored: String?) {
        guard let stored, !stored.trimmingCharacters(in: .whitespaces).isEmpty else {
            entries = Self.defaultEntries
            return
        }
        var seen = Set<NotchLockScreenTerminalSource>()
        var entries: [Entry] = []
        for token in stored.split(separator: ",") {
            let name = token.trimmingCharacters(in: .whitespaces)
            let isOn = !name.hasPrefix("-")
            guard let source = NotchLockScreenTerminalSource(rawValue: isOn ? name : String(name.dropFirst())),
                  seen.insert(source).inserted else { continue }
            entries.append(Entry(source: source, isOn: isOn))
        }
        for source in NotchLockScreenTerminalSource.allCases where !seen.contains(source) {
            entries.append(Entry(source: source, isOn: false))
        }
        self.entries = entries
    }

    var stored: String { Self.encode(entries) }

    /// The lines that are on, in order.
    var shown: [NotchLockScreenTerminalSource] { entries.filter(\.isOn).map(\.source) }

    func isOn(_ source: NotchLockScreenTerminalSource) -> Bool {
        entries.first { $0.source == source }?.isOn ?? false
    }

    mutating func set(_ source: NotchLockScreenTerminalSource, isOn: Bool) {
        guard let index = entries.firstIndex(where: { $0.source == source }) else { return }
        entries[index].isOn = isOn
    }

    func canMove(_ source: NotchLockScreenTerminalSource, by offset: Int) -> Bool {
        guard let index = entries.firstIndex(where: { $0.source == source }) else { return false }
        return entries.indices.contains(index + offset) && offset != 0
    }

    /// Moves a line up (negative) or down (positive), stopping at either end.
    mutating func move(_ source: NotchLockScreenTerminalSource, by offset: Int) {
        guard let index = entries.firstIndex(where: { $0.source == source }) else { return }
        let target = min(entries.count - 1, max(0, index + offset))
        guard target != index else { return }
        let entry = entries.remove(at: index)
        entries.insert(entry, at: target)
    }

    private static func encode(_ entries: [Entry]) -> String {
        entries.map { ($0.isOn ? "" : "-") + $0.source.rawValue }.joined(separator: ",")
    }
}

/// What the readout shows as it appears, settled then: preferences cannot
/// change while the Mac is locked.
struct NotchLockScreenTerminalConfiguration: Equatable {
    /// The chosen lines this Mac can fill, in order.
    var sources: [NotchLockScreenTerminalSource]
    var showsProjects: Bool
    /// The title bar's name, already cleaned up (`NotchLockScreenTerminalSupport.title`).
    var title = NotchLockScreenTerminalSupport.defaultTitle
}

/// A tiny dot after a line's value, in a status color: used sparingly, so the
/// readout stays white like everything else on the lock screen.
enum NotchLockScreenTerminalTone: Equatable {
    case plain, warning, failure
}

struct NotchLockScreenTerminalLine: Equatable, Identifiable {
    let source: NotchLockScreenTerminalSource
    let value: String
    var tone: NotchLockScreenTerminalTone = .plain

    var id: NotchLockScreenTerminalSource { source }
}

/// What each source has right now. Nil where a source has nothing, or is not
/// read on this Mac.
struct NotchLockScreenTerminalReadings {
    var agents: [AgentLiveSession]?
    var wakaSeconds: Double?
    var wakaGoalMinutes = 0
    var wakaTopProject: String?
    var deployments: [VercelSupport.Deployment]?
    var inbox: GitHubSupport.Inbox?
    var batteryPercent: Int?
    var charging = false
    var cpu: Double?
    var downloads: [NotchDownloadItem]?
    var timer: NotchTimerSession?
    var timerNow: TimeInterval = 0
    // Zenith fork: already worded (PrayerTimesSupport.terminalValue, SkyGoldenSupport.terminalValue).
    var prayer: String?
    var golden: String?
    var now = Date()
}

enum NotchLockScreenTerminalSupport {
    static let prompt = "›"
    /// Wide enough for the longest label, so values line up in a column.
    static let labelWidth = NotchLockScreenTerminalSource.allCases.map(\.label.count).max() ?? 6
    /// Under this charge, unplugged, the `sys` line takes a warning dot.
    static let lowBattery = 20

    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        NotchLockScreenSupport.isEnabled(in: defaults) && defaults.bool(forKey: DefaultsKey.notchLockScreenTerminal)
    }

    static func selection(in defaults: UserDefaults = .standard) -> NotchLockScreenTerminalSelection {
        NotchLockScreenTerminalSelection(stored: defaults.string(forKey: DefaultsKey.notchLockScreenTerminalLines))
    }

    static func showsProjects(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: DefaultsKey.notchLockScreenTerminalProjects)
    }

    /// Zenith fork: whether the prayer's label and names are Indonesian.
    static func prayerNamesIndonesian(in defaults: UserDefaults = .standard) -> Bool {
        PrayerTimesSupport.usesIndonesian(
            PrayerTimesSupport.NameStyle(rawValue: defaults.string(forKey: DefaultsKey.notchSkyNames) ?? "") ?? .automatic)
    }

    static func paddedLabel(_ source: NotchLockScreenTerminalSource) -> String {
        source.label.padding(toLength: labelWidth, withPad: " ", startingAt: 0)
    }

    // MARK: Title

    /// The title bar's name when the person has not chosen one.
    static let defaultTitle = "zenith — status"
    /// What follows a computer's name in `<computer name> — status`.
    static let titleSuffix = " — status"
    /// A title stays one short line in the title bar.
    static let maximumTitleLength = 32

    static func title(in defaults: UserDefaults = .standard) -> String {
        title(defaults.string(forKey: DefaultsKey.notchLockScreenTerminalTitle))
    }

    /// A title as it is typed and kept: on one line (line breaks, tabs and
    /// other control characters become spaces) and at most
    /// `maximumTitleLength` characters. Spaces at its ends stay, since the
    /// person may still be typing.
    static func titleInput(_ raw: String) -> String {
        String(oneLine(raw).prefix(maximumTitleLength))
    }

    /// The name the title bar shows: the chosen title on one line, its runs
    /// of spaces closed up and its ends trimmed, within the length limit; the
    /// default when nothing is left.
    static func title(_ stored: String?) -> String {
        let words = oneLine(stored ?? "").split(whereSeparator: \.isWhitespace)
        let title = String(words.joined(separator: " ").prefix(maximumTitleLength)).trimmingCharacters(in: .whitespaces)
        return title.isEmpty ? defaultTitle : title
    }

    /// `<computer name> — status`, the name shortened with an ellipsis when
    /// the whole would pass the length limit. Nil without a name.
    static func computerTitle(_ computerName: String?) -> String? {
        let name = oneLine(computerName ?? "").split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !name.isEmpty else { return nil }
        let room = maximumTitleLength - titleSuffix.count
        guard name.count > room else { return name + titleSuffix }
        let shortened = String(name.prefix(room - 1)).trimmingCharacters(in: .whitespaces)
        return shortened + "…" + titleSuffix
    }

    /// Line breaks, tabs and other control characters as spaces.
    private static func oneLine(_ text: String) -> String {
        let scalars = text.unicodeScalars.map { scalar -> Unicode.Scalar in
            scalar.properties.generalCategory == .control || CharacterSet.newlines.contains(scalar) ? " " : scalar
        }
        return String(String.UnicodeScalarView(scalars))
    }

    // MARK: Lines

    /// The lines to show, in the chosen order. A source with nothing to say
    /// is left out, except `sys`.
    static func lines(_ sources: [NotchLockScreenTerminalSource], readings: NotchLockScreenTerminalReadings,
                      showsProjects: Bool) -> [NotchLockScreenTerminalLine] {
        var seen = Set<NotchLockScreenTerminalSource>()
        return sources.compactMap { source in
            guard seen.insert(source).inserted else { return nil }
            switch source {
            case .agents:
                return readings.agents.flatMap { agents($0, showsProjects: showsProjects) }
            case .waka:
                return wakaTime(seconds: readings.wakaSeconds, goalMinutes: readings.wakaGoalMinutes,
                                topProject: readings.wakaTopProject, showsProjects: showsProjects)
            case .vercel:
                return readings.deployments.flatMap { vercel($0, showsProjects: showsProjects, now: readings.now) }
            case .ci:
                return readings.inbox.flatMap { checks($0, showsProjects: showsProjects) }
            case .sys:
                return system(batteryPercent: readings.batteryPercent, charging: readings.charging, cpu: readings.cpu)
            case .dl:
                return readings.downloads.flatMap { downloads($0, showsProjects: showsProjects) }
            case .timer:
                return readings.timer.flatMap { timer($0, at: readings.timerNow) }
            case .prayer: // Zenith fork
                return readings.prayer.map { NotchLockScreenTerminalLine(source: .prayer, value: $0) }
            case .golden: // Zenith fork
                return readings.golden.map { NotchLockScreenTerminalLine(source: .golden, value: $0) }
            }
        }
    }

    /// `2 running · claude, codex`; with project names, `claude@zenith`.
    static func agents(_ live: [AgentLiveSession], showsProjects: Bool) -> NotchLockScreenTerminalLine? {
        guard !live.isEmpty else { return nil }
        let order = AgentProvider.allCases
        let sorted = live.sorted {
            let left = order.firstIndex(of: $0.provider) ?? 0, right = order.firstIndex(of: $1.provider) ?? 0
            return left != right ? left < right : $0.started < $1.started
        }
        var names: [String] = []
        for session in sorted {
            let provider = session.provider.rawValue
            let project = session.project.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = showsProjects && !project.isEmpty ? provider + "@" + project : provider
            if !names.contains(name) { names.append(name) }
        }
        return NotchLockScreenTerminalLine(source: .agents, value: "\(live.count) running · " + names.joined(separator: ", "))
    }

    /// `3h 12m · goal 75%`, and the day's top project when names show.
    static func wakaTime(seconds: Double?, goalMinutes: Int, topProject: String?,
                         showsProjects: Bool) -> NotchLockScreenTerminalLine? {
        guard let seconds, seconds.isFinite, seconds > 0 else { return nil }
        var parts = [duration(seconds)]
        if goalMinutes > 0 {
            parts.append("goal \(Int((seconds / 60 / Double(goalMinutes) * 100).rounded(.down)))%")
        }
        if showsProjects, let project = topProject?.trimmingCharacters(in: .whitespacesAndNewlines), !project.isEmpty {
            parts.append(project)
        }
        return NotchLockScreenTerminalLine(source: .waka, value: parts.joined(separator: " · "))
    }

    /// A build on its way (`building`, `2 building`, `queued`), or how the
    /// newest deployment ended and when (`ready · 2h ago`).
    static func vercel(_ deployments: [VercelSupport.Deployment], showsProjects: Bool,
                       now: Date) -> NotchLockScreenTerminalLine? {
        guard let newest = deployments.max(by: { $0.created < $1.created }) else { return nil }
        let building = deployments.filter(\.state.inProgress)
        var parts: [String]
        var tone = NotchLockScreenTerminalTone.plain
        let shown: VercelSupport.Deployment
        if let latest = building.max(by: { $0.created < $1.created }) {
            shown = latest
            let word = building.allSatisfy { $0.state == .queued } ? "queued" : "building"
            parts = [building.count == 1 ? word : "\(building.count) \(word)"]
        } else {
            shown = newest
            parts = [stateWord(newest.state), age(now.timeIntervalSince(newest.created))]
            if newest.state == .error { tone = .failure }
        }
        let project = shown.project.trimmingCharacters(in: .whitespacesAndNewlines)
        if showsProjects, !project.isEmpty { parts.append(project) }
        return NotchLockScreenTerminalLine(source: .vercel, value: parts.joined(separator: " · "), tone: tone)
    }

    /// The checks on the person's own pull requests, and reviews waiting:
    /// `1 check failing · 2 pending · 1 review`.
    static func checks(_ inbox: GitHubSupport.Inbox, showsProjects: Bool) -> NotchLockScreenTerminalLine? {
        let failing = inbox.mine.filter { $0.checks == .failure }
        let pending = inbox.mine.filter { $0.checks == .pending }
        let passing = inbox.mine.filter { $0.checks == .success }.count
        func checks(_ count: Int) -> String { count == 1 ? "check" : "checks" }
        var parts: [String] = []
        if !failing.isEmpty { parts.append("\(failing.count) \(checks(failing.count)) failing") }
        if !pending.isEmpty {
            parts.append(parts.isEmpty ? "\(pending.count) \(checks(pending.count)) pending" : "\(pending.count) pending")
        }
        if parts.isEmpty, passing > 0 { parts.append("\(passing) \(checks(passing)) passing") }
        if parts.isEmpty, !inbox.mine.isEmpty { parts.append("\(max(inbox.mineCount, inbox.mine.count)) open") }
        if inbox.reviewCount > 0 { parts.append("\(inbox.reviewCount) \(inbox.reviewCount == 1 ? "review" : "reviews")") }
        guard !parts.isEmpty else { return nil }
        if showsProjects, let repository = (failing.first ?? pending.first)?.repository, !repository.isEmpty {
            parts.append(repository)
        }
        return NotchLockScreenTerminalLine(source: .ci, value: parts.joined(separator: " · "),
                                           tone: failing.isEmpty ? .plain : .failure)
    }

    /// `bat 84% · cpu 23%`. A Mac without a battery reads its CPU alone, and
    /// a reading not in yet shows as `--`.
    static func system(batteryPercent: Int?, charging: Bool, cpu: Double?) -> NotchLockScreenTerminalLine {
        var parts: [String] = []
        var tone = NotchLockScreenTerminalTone.plain
        if let batteryPercent {
            let level = min(100, max(0, batteryPercent))
            parts.append("bat \(level)%" + (charging ? " charging" : ""))
            if level <= lowBattery, !charging { tone = .warning }
        }
        parts.append("cpu " + (cpu.flatMap { $0.isFinite ? percent($0) : nil } ?? "--"))
        return NotchLockScreenTerminalLine(source: .sys, value: parts.joined(separator: " · "), tone: tone)
    }

    /// `1 file 42%`, `2 files 37%`; the first file's name when names show.
    static func downloads(_ items: [NotchDownloadItem], showsProjects: Bool) -> NotchLockScreenTerminalLine? {
        let active = items.filter { $0.active && !$0.completed }
        guard let first = active.first else { return nil }
        var value = "\(active.count) \(active.count == 1 ? "file" : "files")"
        let fractions = active.compactMap(\.fraction).filter(\.isFinite)
        if !fractions.isEmpty { value += " " + percent(fractions.reduce(0, +) / Double(fractions.count)) }
        let name = first.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if showsProjects, !name.isEmpty { value += " · " + name }
        return NotchLockScreenTerminalLine(source: .dl, value: value)
    }

    /// `12:04 left`, `focus 12:04 left`, `03:10 elapsed`, `12:04 paused`, `done`.
    static func timer(_ session: NotchTimerSession, at now: TimeInterval) -> NotchLockScreenTerminalLine? {
        guard session.hasSession else { return nil }
        if NotchLockScreenSupport.timerFinished(session, at: now) {
            return NotchLockScreenTerminalLine(source: .timer, value: "done")
        }
        let clock = NotchTimerSupport.clockText(for: session, at: now)
        var value = clock + (session.isPaused ? " paused" : session.countsUp ? " elapsed" : " left")
        switch session.phase {
        case .focus: value = "focus " + value
        case .shortBreak, .longBreak: value = "break " + value
        case .timer, .stopwatch: break
        }
        return NotchLockScreenTerminalLine(source: .timer, value: value)
    }

    // MARK: Formatting

    /// `3h 12m`, `12m`, `<1m`.
    static func duration(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 60 else { return "<1m" }
        let minutes = Int(min(seconds, 100 * 24 * 3600) / 60)
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    /// `just now`, `5m ago`, `2h ago`, `3d ago`.
    static func age(_ interval: TimeInterval) -> String {
        guard interval.isFinite, interval >= 60 else { return "just now" }
        let minutes = Int(min(interval, 3650 * 24 * 3600) / 60)
        if minutes < 60 { return "\(minutes)m ago" }
        if minutes < 24 * 60 { return "\(minutes / 60)h ago" }
        return "\(minutes / (24 * 60))d ago"
    }

    /// A fraction as a whole percentage, kept between 0 and 100.
    static func percent(_ fraction: Double) -> String {
        guard fraction.isFinite else { return "--" }
        return "\(Int((min(1, max(0, fraction)) * 100).rounded()))%"
    }

    static func stateWord(_ state: VercelSupport.State) -> String {
        switch state {
        case .queued: return "queued"
        case .initializing, .building: return "building"
        case .ready: return "ready"
        case .error: return "failed"
        case .canceled: return "canceled"
        case .unknown: return "unknown"
        }
    }
}

/// Where the readout sits: at the bottom, just over the login controls, in a
/// panel as wide as the music player's pane. The card inside hugs its longest
/// line between `minimumWidth` and that width. The player keeps the room
/// between the line of activities and the readout, and when that is too
/// little, the readout gives way.
enum NotchLockScreenTerminalLayout {
    static let fontSize: CGFloat = 12.5
    static let lineHeight: CGFloat = 18
    static let verticalPadding: CGFloat = 9
    static let horizontalPadding: CGFloat = 13
    /// The title bar: three grey dots and the window's name.
    static let headerHeight: CGFloat = 24
    static let minimumWidth: CGFloat = 260
    /// Between the line of activities and the readout, and the readout and the player.
    static let gap: CGFloat = 10
    static var width: CGFloat { NotchLockScreenLayout.paneWidth }

    /// The card for `lines` lines under its title bar; the cursor ends the last line.
    static func height(lines: Int) -> CGFloat {
        headerHeight + CGFloat(max(0, lines)) * lineHeight + verticalPadding * 2
    }

    /// The readout's frame and the player's, given the line of activities and
    /// the player's own frame. `music` says whether the player may show.
    static func arrange(row: CGRect?, player: CGRect?, screen: CGRect, lines: Int,
                        music: Bool) -> (terminal: CGRect?, player: CGRect?) {
        guard lines > 0, let row, [screen.minX, screen.minY, screen.width, screen.height].allSatisfy(\.isFinite),
              screen.width >= width + 32 else { return (nil, player) }
        let height = height(lines: lines)
        let bottom = screen.minY + NotchLockScreenLayout.loginClearance
        guard bottom + height <= row.minY - gap else { return (nil, player) }
        let terminal = CGRect(x: (screen.midX - width / 2).rounded(), y: bottom, width: width, height: height)
        guard music, let player else { return (terminal, player) }
        let floor = terminal.maxY + gap
        let room = player.maxY - floor
        guard room >= NotchLockScreenLayout.minimumPlayerHeight else { return (nil, player) }
        return (terminal, CGRect(x: player.minX, y: floor, width: player.width, height: room))
    }
}
