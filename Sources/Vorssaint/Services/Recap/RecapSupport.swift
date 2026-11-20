// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: the end-of-day recap. Everything here is pure (Foundation and
// the other features' support files) and compiled into the tests: the
// sources, the day's tally the local services add to, the aggregation of
// what the island already knows into one recap, its formatting (cards, the
// notice's headline, the shareable text), the schedule that shows it once a
// day, and the one GitHub search it may add. RecapService reads the services
// and presents; RecapPage draws.

/// Where a part of the recap comes from, in the order the recap shows them.
enum RecapSource: String, CaseIterable, Identifiable, Sendable {
    case coding, deploys, github, terminal, photos, exports, agents

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .coding: return "chevron.left.forwardslash.chevron.right"
        case .deploys: return "triangle.fill"
        case .github: return "arrow.triangle.branch"
        case .terminal: return "terminal.fill"
        case .photos: return "camera.fill"
        case .exports: return "film.fill"
        case .agents: return "sparkles"
        }
    }

    /// A soft identity colour per card (the 300 steps, gentler than the
    /// island's module colours). Never a status: failures keep `ZenithStatus`.
    var hex: UInt32 {
        switch self {
        case .coding: return 0xF9A8D4   // pink
        case .deploys: return 0x93C5FD  // blue
        case .github: return 0xC4B5FD   // violet
        case .terminal: return 0x86EFAC // green
        case .photos: return 0xFDBA74   // peach, as Card Import
        case .exports: return 0xFCD34D  // amber
        case .agents: return 0x5EEAD4   // teal
        }
    }
}

// MARK: - Settings

struct RecapSettings: Equatable, Sendable {
    static let defaultMinutes = 17 * 60

    /// The automatic notice. The Today page is there either way.
    var enabled = true
    /// Minutes after local midnight.
    var minutes = RecapSettings.defaultMinutes
    var weekdaysOnly = false
    var hidden: Set<RecapSource> = []

    var sources: Set<RecapSource> { Set(RecapSource.allCases).subtracting(hidden) }

    static func current(in defaults: UserDefaults = .standard) -> RecapSettings {
        RecapSettings(enabled: defaults.object(forKey: DefaultsKey.notchRecapEnabled) as? Bool ?? true,
                      minutes: clamped(defaults.object(forKey: DefaultsKey.notchRecapMinutes) as? Int ?? defaultMinutes),
                      weekdaysOnly: defaults.bool(forKey: DefaultsKey.notchRecapWeekdaysOnly),
                      hidden: decodeHidden(defaults.string(forKey: DefaultsKey.notchRecapHiddenSources) ?? ""))
    }

    static func clamped(_ minutes: Int) -> Int { min(max(0, minutes), 24 * 60 - 1) }

    /// Comma-separated raw values of the sources left out; unknown names are dropped.
    static func decodeHidden(_ stored: String) -> Set<RecapSource> {
        Set(stored.split(separator: ",").compactMap { RecapSource(rawValue: $0.trimmingCharacters(in: .whitespaces)) })
    }

    static func encodeHidden(_ hidden: Set<RecapSource>) -> String {
        RecapSource.allCases.filter(hidden.contains).map(\.rawValue).joined(separator: ",")
    }
}

// MARK: - Schedule

/// Once a day, at the chosen time, never on a weekend when asked. The day is
/// the local calendar's: `lastShown` is that day's `yyyy-MM-dd`, so a time
/// zone change that lands on the same date, or an earlier one, never shows it
/// twice, and one that lands on the next date waits for that day's time.
enum RecapSchedule {
    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        WakaTimeSupport.dayKey(date, calendar: calendar)
    }

    static func isOffDay(_ date: Date, settings: RecapSettings, calendar: Calendar = .current) -> Bool {
        settings.weekdaysOnly && calendar.isDateInWeekend(date)
    }

    /// Already shown on this day or a later one (a clock set back).
    static func wasShown(on date: Date, lastShown: String?, calendar: Calendar = .current) -> Bool {
        guard let lastShown, !lastShown.isEmpty else { return false }
        return lastShown >= dayKey(date, calendar: calendar)
    }

    /// Minutes after the day's midnight, by the clock on the wall.
    static func minutes(of date: Date, calendar: Calendar = .current) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    static func isDue(now: Date, settings: RecapSettings, lastShown: String?, calendar: Calendar = .current) -> Bool {
        settings.enabled && !isOffDay(now, settings: settings, calendar: calendar)
            && !wasShown(on: now, lastShown: lastShown, calendar: calendar)
            && minutes(of: now, calendar: calendar) >= settings.minutes
    }

    /// The chosen time on a date's day. A time a clock change skips moves on
    /// to the next valid moment.
    static func moment(on date: Date, settings: RecapSettings, calendar: Calendar = .current) -> Date? {
        let minutes = RecapSettings.clamped(settings.minutes)
        return calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: date,
                             matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward)
    }

    /// When to look next: now when due, otherwise the next day's time the
    /// recap may show. Nil when it is off.
    static func nextCheck(after now: Date, settings: RecapSettings, lastShown: String?,
                          calendar: Calendar = .current) -> Date? {
        guard settings.enabled else { return nil }
        if isDue(now: now, settings: settings, lastShown: lastShown, calendar: calendar) { return now }
        let start = calendar.startOfDay(for: now)
        for offset in 0...8 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start),
                  let fire = moment(on: day, settings: settings, calendar: calendar), fire > now,
                  !isOffDay(fire, settings: settings, calendar: calendar),
                  !wasShown(on: fire, lastShown: lastShown, calendar: calendar) else { continue }
            return fire
        }
        return nil
    }
}

// MARK: - The day's tally

/// What the local services saw today and keep nowhere else: long terminal
/// commands, card imports, finished exports and Claude Code turns. Counts
/// only, never names or paths. Kept on this Mac (never backed up), and an
/// event from a later day starts it over.
struct RecapTally: Codable, Equatable, Sendable {
    /// Session ids remembered to count sessions, never more.
    static let sessionMemory = 64

    var day = ""
    var commands = 0
    var commandSeconds: Double = 0
    var photos = 0
    var videos = 0
    var importBytes: Int64 = 0
    var exports = 0
    var exportBytes: Int64 = 0
    var turns = 0
    var sessions: [String] = []

    /// This tally if it is the day's, otherwise an empty one for that day.
    func on(_ day: String) -> RecapTally { self.day == day ? self : RecapTally(day: day) }

    func recording(_ event: RecapEvent, calendar: Calendar = .current) -> RecapTally {
        let key = RecapSchedule.dayKey(event.date, calendar: calendar)
        // A late event from an earlier day has nowhere to go.
        guard day.isEmpty || key >= day else { return self }
        var next = on(key)
        switch event {
        case .command(let duration, _):
            next.commands += 1
            next.commandSeconds += max(0, duration.isFinite ? duration : 0)
        case .imported(let photos, let videos, let bytes, _):
            next.photos += max(0, photos)
            next.videos += max(0, videos)
            next.importBytes += max(0, bytes)
        case .exported(let bytes, _):
            next.exports += 1
            next.exportBytes += max(0, bytes)
        case .agent(let session, let prompt, _):
            if prompt { next.turns += 1 }
            let id = String(session.prefix(36))
            if !id.isEmpty, !next.sessions.contains(id), next.sessions.count < Self.sessionMemory {
                next.sessions.append(id)
            }
        }
        return next
    }

    var encoded: Data? { try? JSONEncoder().encode(self) }

    static func decode(_ data: Data?) -> RecapTally {
        data.flatMap { try? JSONDecoder().decode(RecapTally.self, from: $0) } ?? RecapTally()
    }
}

/// One thing a local service saw happen.
enum RecapEvent: Equatable, Sendable {
    /// A command that ran past the island's threshold, by when it ended.
    case command(duration: TimeInterval, ended: Date)
    /// Files off a camera card.
    case imported(photos: Int, videos: Int, bytes: Int64, at: Date)
    case exported(bytes: Int64, at: Date)
    /// A Claude Code hook event: a prompt is a turn.
    case agent(session: String, prompt: Bool, at: Date)

    var date: Date {
        switch self {
        case .command(_, let date), .imported(_, _, _, let date), .exported(_, let date), .agent(_, _, let date):
            return date
        }
    }
}

// MARK: - The recap

/// What the services know right now, each part optional.
struct RecapInputs {
    var coding: WakaTimeSupport.Today?
    var deployments: [VercelSupport.Deployment]?
    var inbox: GitHubSupport.Inbox?
    /// Today's commits from the one GitHub search, nil when it was not made.
    var commits: Int?
    var tally = RecapTally()
}

struct Recap: Equatable {
    struct Coding: Equatable { var seconds: Double; var project: String?; var language: String? }
    struct Deploys: Equatable { var total: Int; var ready: Int; var failed: Int; var building: Int }
    struct GitHub: Equatable { var commits: Int?; var pullsOpened: Int; var reviewsWaiting: Int; var failingChecks: Int }
    struct Terminal: Equatable { var count: Int; var seconds: Double }
    struct Photos: Equatable { var photos: Int; var videos: Int; var bytes: Int64 }
    struct Exports: Equatable { var count: Int; var bytes: Int64 }
    struct Agents: Equatable { var turns: Int; var sessions: Int }

    var day = ""
    var coding: Coding?
    var deploys: Deploys?
    var github: GitHub?
    var terminal: Terminal?
    var photos: Photos?
    var exports: Exports?
    var agents: Agents?

    /// The sources with something to show, in order.
    var sources: [RecapSource] {
        RecapSource.allCases.filter { source in
            switch source {
            case .coding: return coding != nil
            case .deploys: return deploys != nil
            case .github: return github != nil
            case .terminal: return terminal != nil
            case .photos: return photos != nil
            case .exports: return exports != nil
            case .agents: return agents != nil
            }
        }
    }

    var isEmpty: Bool { sources.isEmpty }
}

enum RecapSupport {
    /// Coding time under a minute is not worth a card.
    static let minimumCodingSeconds: Double = 60

    /// Today's recap from what each service holds, only the sources asked for
    /// and only the ones with something from today.
    static func aggregate(_ inputs: RecapInputs, sources: Set<RecapSource> = Set(RecapSource.allCases),
                          now: Date, calendar: Calendar = .current) -> Recap {
        let today = RecapSchedule.dayKey(now, calendar: calendar)
        var recap = Recap(day: today)
        if sources.contains(.coding), let coding = inputs.coding,
           coding.date.isEmpty || coding.date == today, coding.totalSeconds >= minimumCodingSeconds {
            recap.coding = .init(seconds: coding.totalSeconds, project: coding.projects.first?.name,
                                 language: coding.languages.first?.name)
        }
        if sources.contains(.deploys), let deployments = inputs.deployments {
            let todays = deployments.filter { RecapSchedule.dayKey($0.created, calendar: calendar) == today }
            if !todays.isEmpty {
                recap.deploys = .init(total: todays.count, ready: todays.filter { $0.state == .ready }.count,
                                      failed: todays.filter { $0.state == .error }.count,
                                      building: todays.filter(\.state.inProgress).count)
            }
        }
        if sources.contains(.github) {
            let opened = inputs.inbox?.mine.filter { pull in
                pull.created.map { RecapSchedule.dayKey($0, calendar: calendar) == today } ?? false
            }.count ?? 0
            let commits = inputs.commits.map { max(0, $0) }
            if (commits ?? 0) > 0 || opened > 0 {
                recap.github = .init(commits: commits, pullsOpened: opened,
                                     reviewsWaiting: inputs.inbox?.reviewCount ?? 0,
                                     failingChecks: inputs.inbox?.failingCount ?? 0)
            }
        }
        let tally = inputs.tally.on(today)
        if sources.contains(.terminal), tally.commands > 0 {
            recap.terminal = .init(count: tally.commands, seconds: tally.commandSeconds)
        }
        if sources.contains(.photos), tally.photos + tally.videos > 0 {
            recap.photos = .init(photos: tally.photos, videos: tally.videos, bytes: tally.importBytes)
        }
        if sources.contains(.exports), tally.exports > 0 {
            recap.exports = .init(count: tally.exports, bytes: tally.exportBytes)
        }
        if sources.contains(.agents), tally.turns > 0 {
            recap.agents = .init(turns: tally.turns, sessions: tally.sessions.count)
        }
        return recap
    }
}

// MARK: - Formatting

/// One card on the Today page: a big figure that counts up, its label, and
/// one line of detail made of short notes.
struct RecapCard: Equatable, Identifiable {
    enum Figure: Equatable { case duration, count }

    /// One part of the detail; a failure wears the error colour on its own.
    struct Note: Equatable {
        let text: String
        var warns = false
    }

    let source: RecapSource
    let label: String
    let value: Double
    let figure: Figure
    let notes: [Note]

    var id: RecapSource { source }
    var detail: String { notes.map(\.text).joined(separator: " · ") }
    /// Something failed.
    var warns: Bool { notes.contains(where: \.warns) }
}

enum RecapFormat {
    static func duration(_ seconds: Double, locale: Locale) -> String {
        WakaTimeSupport.duration(seconds, locale: locale)
    }

    static func count(_ value: Int, locale: Locale) -> String { CardImportFormat.count(value, locale: locale) }

    static func counted(_ value: Int, _ forms: [String], language: AppLanguage, locale: Locale) -> String {
        CardImportFormat.counted(value, forms: forms, agreement: language.countAgreement, locale: locale)
    }

    static func size(_ bytes: Int64, locale: Locale) -> String { ExportTrackerSupport.size(bytes, locale: locale) }

    static func filling(_ format: String, _ value: String) -> String {
        format.replacingOccurrences(of: "%@", with: value)
    }

    /// The figure as it reads at a value, for the count-up as much as the end.
    static func figure(_ value: Double, _ kind: RecapCard.Figure, locale: Locale) -> String {
        switch kind {
        case .duration: return duration(value, locale: locale)
        case .count: return count(Int(max(0, value).rounded()), locale: locale)
        }
    }

    static func cards(_ recap: Recap, text: ZenithRecapStrings, language: AppLanguage, locale: Locale) -> [RecapCard] {
        recap.sources.compactMap { card($0, recap, text: text, language: language, locale: locale, sharing: false) }
    }

    /// A card's parts. Shared, the detail leaves out what is only for the
    /// person (project names, waiting reviews, checks) and keeps what the day made.
    static func card(_ source: RecapSource, _ recap: Recap, text: ZenithRecapStrings, language: AppLanguage,
                     locale: Locale, sharing: Bool) -> RecapCard? {
        func note(_ text: String?, warns: Bool = false) -> RecapCard.Note? {
            guard let text, !text.isEmpty else { return nil }
            return RecapCard.Note(text: text, warns: warns)
        }
        func counted(_ value: Int, _ forms: [String], when shown: Bool = true, warns: Bool = false) -> RecapCard.Note? {
            guard shown, value > 0 else { return nil }
            return note(self.counted(value, forms, language: language, locale: locale), warns: warns)
        }
        func make(_ label: String, _ value: Double, _ figure: RecapCard.Figure, _ notes: [RecapCard.Note?]) -> RecapCard {
            RecapCard(source: source, label: label, value: value, figure: figure, notes: notes.compactMap { $0 })
        }
        switch source {
        case .coding:
            guard let coding = recap.coding else { return nil }
            return make(text.coding, coding.seconds, .duration,
                        [note(sharing ? nil : coding.project), note(coding.language)])
        case .deploys:
            guard let deploys = recap.deploys else { return nil }
            return make(text.deploys, Double(deploys.total), .count,
                        [counted(deploys.ready, text.ready, when: !sharing),
                         counted(deploys.failed, text.failed, warns: !sharing),
                         counted(deploys.building, text.building, when: !sharing)])
        case .github:
            guard let github = recap.github else { return nil }
            let commits = github.commits ?? 0
            let waiting = [counted(github.reviewsWaiting, text.reviewsWaiting, when: !sharing),
                           counted(github.failingChecks, text.checksFailing, when: !sharing, warns: true)]
            if commits > 0 {
                return make(text.commitsLabel, Double(commits), .count,
                            [counted(github.pullsOpened, text.pullsOpened)] + waiting)
            }
            return make(text.pullRequests, Double(github.pullsOpened), .count, waiting)
        case .terminal:
            guard let terminal = recap.terminal else { return nil }
            return make(text.commandsLabel, Double(terminal.count), .count, [note(duration(terminal.seconds, locale: locale))])
        case .photos:
            guard let photos = recap.photos else { return nil }
            let size = note(photos.bytes > 0 ? self.size(photos.bytes, locale: locale) : nil)
            if photos.photos > 0 {
                return make(text.photosLabel, Double(photos.photos), .count, [size, counted(photos.videos, text.videos)])
            }
            return make(text.videosLabel, Double(photos.videos), .count, [size])
        case .exports:
            guard let exports = recap.exports else { return nil }
            return make(text.exportsLabel, Double(exports.count), .count,
                        [note(exports.bytes > 0 ? size(exports.bytes, locale: locale) : nil)])
        case .agents:
            guard let agents = recap.agents else { return nil }
            return make(text.agentsLabel, Double(agents.turns), .count, [counted(agents.sessions, text.sessions)])
        }
    }

    /// The notice's line: the day's biggest things, short. Coding time first,
    /// then what shipped and what was shot.
    static let headlineOrder: [RecapSource] = [.coding, .deploys, .photos, .github, .exports, .agents, .terminal]

    static func headline(_ recap: Recap, text: ZenithRecapStrings, language: AppLanguage, locale: Locale,
                         limit: Int = 3) -> [String] {
        let parts: [String?] = headlineOrder.map { source in
            switch source {
            case .coding:
                return recap.coding.map { filling(text.codingHeadline, duration($0.seconds, locale: locale)) }
            case .deploys:
                return recap.deploys.map { counted($0.total, text.deploysCount, language: language, locale: locale) }
            case .photos:
                return recap.photos.map { photos in
                    photos.photos > 0 ? counted(photos.photos, text.photos, language: language, locale: locale)
                        : counted(photos.videos, text.videos, language: language, locale: locale)
                }
            case .github:
                return recap.github.map { github in
                    (github.commits ?? 0) > 0 ? counted(github.commits ?? 0, text.commitsCount, language: language, locale: locale)
                        : counted(github.pullsOpened, text.pullsOpened, language: language, locale: locale)
                }
            case .exports:
                return recap.exports.map { counted($0.count, text.exportsCount, language: language, locale: locale) }
            case .agents:
                return recap.agents.map { counted($0.turns, text.turns, language: language, locale: locale) }
            case .terminal:
                return recap.terminal.map { counted($0.count, text.commandsCount, language: language, locale: locale) }
            }
        }
        return Array(parts.compactMap { $0 }.prefix(max(0, limit)))
    }

    /// A short plain-text summary to paste into a status or a standup: a
    /// heading with the date, then one line per source. No project names.
    static func summary(_ recap: Recap, text: ZenithRecapStrings, language: AppLanguage, locale: Locale,
                        date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEEMMMd")
        var lines = [filling(text.shareHeading, formatter.string(from: date))]
        for source in recap.sources {
            guard let card = card(source, recap, text: text, language: language, locale: locale, sharing: true) else { continue }
            let figure = self.figure(card.value, card.figure, locale: locale)
            lines.append(card.detail.isEmpty ? "\(card.label) \(figure)" : "\(card.label) \(figure) · \(card.detail)")
        }
        return lines.joined(separator: "\n")
    }
}

extension RecapFormat {
    /// The saved image's name in Downloads: `Zenith Today 2026-11-20.png`,
    /// then ` 2`, ` 3` beside one already there. Slashes and colons, which
    /// Finder and the file system read differently, become hyphens.
    static func imageName(app: String, title: String, day: String, copy: Int = 1) -> String {
        let base = [app, title, day].filter { !$0.isEmpty }.joined(separator: " ")
            .map { "/:".contains($0) ? "-" : $0 }
        return String(base) + (copy > 1 ? " \(copy)" : "") + ".png"
    }
}

// MARK: - Today's commits

/// The one GitHub search the recap adds, through the `gh` the person signed
/// in with: today's commits by them, counted, nothing else read. It runs off
/// the main thread with a timeout, never when `gh` is missing.
enum RecapCommits {
    static let timeout: TimeInterval = 20
    /// A count read this recently is not asked again.
    static let staleAfter: TimeInterval = 10 * 60

    /// `author:<login>` when the GitHub page knows who is signed in, else
    /// `@me`; anything that is not a GitHub login falls back to `@me`.
    static func author(_ login: String?) -> String {
        guard let login, !login.isEmpty, login.count <= 39,
              login.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }),
              !login.hasPrefix("-") else { return "@me" }
        return login
    }

    /// Local midnight with its offset, so "today" is the person's day and
    /// not GitHub's (UTC): `2026-11-20T00:00:00+07:00`.
    static func since(_ now: Date, calendar: Calendar = .current) -> String {
        let start = calendar.startOfDay(for: now)
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = calendar.timeZone
        formatter.formatOptions = [.withInternetDateTime]
        var text = formatter.string(from: start)
        // ISO8601DateFormatter writes UTC as "Z"; GitHub reads either.
        if text.hasSuffix("Z") { text = String(text.dropLast()) + "+00:00" }
        return text
    }

    static func query(login: String?, now: Date, calendar: Calendar = .current) -> String {
        "author:\(author(login)) committer-date:>=\(since(now, calendar: calendar))"
    }

    /// `gh api -X GET search/commits -f q=… -f per_page=1`: one page of one
    /// commit is enough, the count is in `total_count`.
    static func arguments(login: String?, now: Date, calendar: Calendar = .current) -> [String] {
        ["api", "-X", "GET", "search/commits",
         "-H", "Accept: application/vnd.github+json",
         "-f", "q=\(query(login: login, now: now, calendar: calendar))",
         "-f", "per_page=1"]
    }

    /// `total_count` from the answer, also with a line `gh` wrote around it.
    static func count(from data: Data) -> Int? {
        func object(_ bytes: Data) -> [String: Any]? { try? JSONSerialization.jsonObject(with: bytes) as? [String: Any] }
        var root = object(data)
        if root == nil, let start = data.firstIndex(of: UInt8(ascii: "{")),
           let end = data.lastIndex(of: UInt8(ascii: "}")), start < end {
            root = object(data[start...end])
        }
        guard let root, let total = root["total_count"] as? Int, total >= 0 else { return nil }
        return total
    }
}
