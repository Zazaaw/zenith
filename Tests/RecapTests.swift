// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: the end-of-day recap. Aggregation with sources missing,
/// the day's tally across midnight, formatting and plurals, the shareable
/// text, the schedule (time, weekends, once a day across midnight and time
/// zone changes), the commit search's arguments, and the strings. Everything
/// runs on pure values with fixed calendars; no network, no `gh`.
enum RecapTests {
    static func run(_ suite: TestSuite) {
        aggregation(suite)
        missingSources(suite)
        tally(suite)
        formatting(suite)
        plurals(suite)
        headline(suite)
        summary(suite)
        schedule(suite)
        weekends(suite)
        acrossMidnight(suite)
        timeZones(suite)
        settings(suite)
        commitSearch(suite)
        island(suite)
        strings(suite)
    }

    private static let suiteName = "com.vorssaint.tests.recap"
    private static let english = Locale(identifier: "en_US")

    private static func calendar(_ zone: String = "Asia/Jakarta") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    private static func date(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 11, year: Int = 2026,
                             in calendar: Calendar = calendar()) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    /// Friday 20 November 2026, 17:30 in Jakarta.
    private static var friday: Date { date(20, 17, 30) }

    private static func today(_ seconds: Double, date: String = "2026-11-20") -> WakaTimeSupport.Today {
        WakaTimeSupport.Today(date: date, totalSeconds: seconds,
                              projects: [.init(name: "zenith", seconds: seconds * 0.7)],
                              languages: [.init(name: "Swift", seconds: seconds * 0.8)])
    }

    private static func deployment(_ uid: String, _ state: VercelSupport.State, at created: Date) -> VercelSupport.Deployment {
        VercelSupport.Deployment(uid: uid, project: "site", host: nil, state: state, created: created,
                                 isProduction: true, branch: nil, commitMessage: nil, inspectorURL: nil, scope: nil)
    }

    private static func pull(_ number: Int, created: Date?, checks: GitHubSupport.Checks = .success) -> GitHubSupport.PullRequest {
        GitHubSupport.PullRequest(number: number, title: "t", url: URL(string: "https://github.com/x/y/pull/\(number)")!,
                                  repository: "satuvisual/zenith", author: "me", isDraft: false, updated: friday,
                                  checks: checks, created: created)
    }

    private static func inbox(_ mine: [GitHubSupport.PullRequest], reviews: Int = 0) -> GitHubSupport.Inbox {
        GitHubSupport.Inbox(login: "me", reviewRequested: [], reviewCount: reviews, mine: mine, mineCount: mine.count)
    }

    /// A full day: 6h 11m of Swift, four deploys (one failed), twelve
    /// commits, three long commands, 1,248 photos and twelve videos, three
    /// exports and fourteen Claude Code turns in three sessions.
    private static func fullDay(_ calendar: Calendar = calendar()) -> RecapInputs {
        var tally = RecapTally(day: "2026-11-20")
        tally.commands = 3
        tally.commandSeconds = 41 * 60
        tally.photos = 1248
        tally.videos = 12
        tally.importBytes = 52_000_000_000
        tally.exports = 3
        tally.exportBytes = 8_400_000_000
        tally.turns = 14
        tally.sessions = ["a", "b", "c"]
        return RecapInputs(coding: today(6 * 3600 + 11 * 60),
                           deployments: [deployment("1", .ready, at: date(20, 9)), deployment("2", .ready, at: date(20, 11)),
                                         deployment("3", .error, at: date(20, 14)), deployment("4", .ready, at: date(20, 16)),
                                         deployment("old", .error, at: date(19, 22))],
                           inbox: inbox([pull(1, created: date(20, 10)), pull(2, created: date(18, 10), checks: .failure)],
                                        reviews: 2),
                           commits: 12, tally: tally)
    }

    // MARK: Aggregation

    private static func aggregation(_ suite: TestSuite) {
        let recap = RecapSupport.aggregate(fullDay(), now: friday, calendar: calendar())
        suite.expect(recap.day == "2026-11-20" && recap.sources == RecapSource.allCases,
                     "a full day has every source, in the recap's order")
        suite.expect(recap.coding == .init(seconds: 22260, project: "zenith", language: "Swift"),
                     "coding keeps the day's total, top project and top language")
        suite.expect(recap.deploys == .init(total: 4, ready: 3, failed: 1, building: 0),
                     "only deploys created today count, with how they ended")
        suite.expect(recap.github == .init(commits: 12, pullsOpened: 1, reviewsWaiting: 2, failingChecks: 1),
                     "GitHub counts today's commits, the pull requests opened today, and what waits")
        suite.expect(recap.terminal == .init(count: 3, seconds: 2460) && recap.photos == .init(photos: 1248, videos: 12, bytes: 52_000_000_000)
                     && recap.exports == .init(count: 3, bytes: 8_400_000_000) && recap.agents == .init(turns: 14, sessions: 3),
                     "the day's tally fills the local sources")
        let some = RecapSupport.aggregate(fullDay(), sources: [.coding, .photos], now: friday, calendar: calendar())
        suite.expect(some.sources == [.coding, .photos], "a source left out in settings never shows")
    }

    private static func missingSources(_ suite: TestSuite) {
        let none = RecapSupport.aggregate(RecapInputs(), now: friday, calendar: calendar())
        suite.expect(none.isEmpty && none.sources.isEmpty, "nothing known is an empty recap")

        var inputs = RecapInputs()
        inputs.coding = today(3600, date: "2026-11-19")
        suite.expect(RecapSupport.aggregate(inputs, now: friday, calendar: calendar()).coding == nil,
                     "yesterday’s WakaTime total is not today’s")
        inputs.coding = today(45)
        suite.expect(RecapSupport.aggregate(inputs, now: friday, calendar: calendar()).coding == nil,
                     "under a minute of coding is not worth a card")
        inputs.coding = today(3600, date: "")
        suite.expect(RecapSupport.aggregate(inputs, now: friday, calendar: calendar()).coding?.seconds == 3600,
                     "a total without a date is taken as today’s")

        inputs = RecapInputs(deployments: [deployment("y", .ready, at: date(19, 23, 59))])
        suite.expect(RecapSupport.aggregate(inputs, now: friday, calendar: calendar()).deploys == nil,
                     "a deploy from last night is not today’s")
        inputs = RecapInputs(deployments: [])
        suite.expect(RecapSupport.aggregate(inputs, now: friday, calendar: calendar()).isEmpty,
                     "Vercel with nothing today adds no card")

        inputs = RecapInputs(inbox: inbox([pull(1, created: nil), pull(2, created: date(19, 9))], reviews: 3), commits: 0)
        suite.expect(RecapSupport.aggregate(inputs, now: friday, calendar: calendar()).github == nil,
                     "no commits and no pull request opened today is no GitHub card, whatever waits")
        inputs = RecapInputs(inbox: nil, commits: 5)
        suite.expect(RecapSupport.aggregate(inputs, now: friday, calendar: calendar()).github
                        == .init(commits: 5, pullsOpened: 0, reviewsWaiting: 0, failingChecks: 0),
                     "the commit count stands without the inbox")
        inputs = RecapInputs(inbox: inbox([pull(1, created: date(20, 8))]), commits: nil)
        suite.expect(RecapSupport.aggregate(inputs, now: friday, calendar: calendar()).github?.commits == nil
                        && RecapSupport.aggregate(inputs, now: friday, calendar: calendar()).github?.pullsOpened == 1,
                     "without the commit search, a pull request opened today still shows")

        var stale = RecapTally(day: "2026-11-19")
        stale.commands = 4
        stale.photos = 200
        stale.turns = 9
        inputs = RecapInputs(tally: stale)
        suite.expect(RecapSupport.aggregate(inputs, now: friday, calendar: calendar()).isEmpty,
                     "yesterday’s tally is not today’s")
        var videos = RecapTally(day: "2026-11-20")
        videos.videos = 4
        inputs = RecapInputs(tally: videos)
        suite.expect(RecapSupport.aggregate(inputs, now: friday, calendar: calendar()).photos == .init(photos: 0, videos: 4, bytes: 0),
                     "a card of only videos still counts as an import")
    }

    // MARK: Tally

    private static func tally(_ suite: TestSuite) {
        let jakarta = calendar()
        var tally = RecapTally()
        tally = tally.recording(.command(duration: 90, ended: date(19, 23, 59)), calendar: jakarta)
        tally = tally.recording(.command(duration: 30, ended: date(19, 23, 59)), calendar: jakarta)
        suite.expect(tally.day == "2026-11-19" && tally.commands == 2 && tally.commandSeconds == 120,
                     "commands add up within their day")
        tally = tally.recording(.command(duration: 600, ended: date(20, 0, 1)), calendar: jakarta)
        suite.expect(tally.day == "2026-11-20" && tally.commands == 1 && tally.commandSeconds == 600,
                     "the first event after midnight starts a new day")
        let late = tally.recording(.exported(bytes: 9, at: date(19, 22)), calendar: jakarta)
        suite.expect(late == tally, "a late event from an earlier day changes nothing")
        tally = tally.recording(.imported(photos: 10, videos: 2, bytes: 5_000, at: date(20, 9)), calendar: jakarta)
            .recording(.imported(photos: 5, videos: 0, bytes: 1_000, at: date(20, 10)), calendar: jakarta)
            .recording(.exported(bytes: 4_000, at: date(20, 11)), calendar: jakarta)
            .recording(.command(duration: -5, ended: date(20, 12)), calendar: jakarta)
        suite.expect(tally.photos == 15 && tally.videos == 2 && tally.importBytes == 6_000 && tally.exports == 1
                     && tally.exportBytes == 4_000 && tally.commands == 2 && tally.commandSeconds == 600,
                     "imports and exports add up, and a negative duration counts as none")
        for index in 0..<(RecapTally.sessionMemory + 10) {
            tally = tally.recording(.agent(session: "s\(index % (RecapTally.sessionMemory + 5))", prompt: true, at: date(20, 13)),
                                    calendar: jakarta)
        }
        tally = tally.recording(.agent(session: "s1", prompt: false, at: date(20, 14)), calendar: jakarta)
        suite.expect(tally.turns == RecapTally.sessionMemory + 10 && tally.sessions.count == RecapTally.sessionMemory
                     && Set(tally.sessions).count == tally.sessions.count,
                     "every prompt is a turn; sessions are counted once, up to the memory")
        suite.expect(RecapTally.decode(tally.encoded) == tally && RecapTally.decode(Data("nope".utf8)) == RecapTally()
                     && RecapTally.decode(nil) == RecapTally(),
                     "the tally survives a round trip, and garbage reads as an empty day")
        suite.expect(tally.on("2026-11-21") == RecapTally(day: "2026-11-21") && tally.on(tally.day) == tally,
                     "read on another day, the tally is empty")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.notchRecapTally] == nil
                        && Defaults.registeredDefaults[DefaultsKey.notchRecapLastShown] == nil
                        && !SettingsBackupSupport.exportKeys().contains(DefaultsKey.notchRecapTally)
                        && !SettingsBackupSupport.exportKeys().contains(DefaultsKey.notchRecapLastShown),
                     "the day’s tally and the last shown day stay on this Mac, out of backups")
    }

    // MARK: Formatting

    private static func formatting(_ suite: TestSuite) {
        let text = ZenithStrings.recap(.enUS)
        let recap = RecapSupport.aggregate(fullDay(), now: friday, calendar: calendar())
        let cards = RecapFormat.cards(recap, text: text, language: .enUS, locale: english)
        func card(_ source: RecapSource) -> RecapCard? { cards.first { $0.source == source } }
        suite.expect(cards.map(\.source) == RecapSource.allCases, "one card per source, in order")
        suite.expect(card(.coding).map { RecapFormat.figure($0.value, $0.figure, locale: english) } == "6h 11m"
                     && card(.coding)?.detail == "zenith · Swift" && card(.coding)?.label == "Coding",
                     "coding reads 6h 11m with its project and language")
        suite.expect(card(.deploys)?.value == 4 && card(.deploys)?.detail == "3 ready · 1 failed" && card(.deploys)?.warns == true,
                     "deploys say how many ended well and how many failed, failures in the error colour")
        suite.expect(card(.github)?.label == "Commits" && card(.github)?.value == 12
                     && card(.github)?.detail == "1 PR opened · 2 reviews waiting · 1 check failing",
                     "GitHub leads with commits and adds what was opened and what waits")
        suite.expect(card(.terminal)?.detail == "41m" && card(.terminal)?.label == "Long commands",
                     "long commands add up their time")
        suite.expect(card(.photos).map { RecapFormat.figure($0.value, $0.figure, locale: english) } == "1,248"
                     && card(.photos)?.detail == "52.0 GB · 12 videos",
                     "photos group their count and give the size and the videos beside them")
        suite.expect(card(.exports)?.detail == "8.4 GB" && card(.agents)?.detail == "3 sessions"
                     && card(.agents)?.label == "Agent turns",
                     "exports give their size, agents their sessions")
        suite.expect(RecapFormat.figure(1248.4, .count, locale: Locale(identifier: "de_DE")) == "1.248"
                     && RecapFormat.figure(-3, .count, locale: english) == "0"
                     && RecapFormat.figure(45 * 60, .duration, locale: english) == "45m",
                     "counts round and group by the locale; a count never reads below zero")
        suite.expect(RecapFormat.figure(600, .count, locale: english) != RecapFormat.figure(300, .count, locale: english)
                     && RecapFormat.figure(0, .duration, locale: english) == "0m",
                     "the count-up reads every value on its way")

        var pullsOnly = RecapInputs(inbox: inbox([pull(1, created: date(20, 9)), pull(2, created: date(20, 10))]))
        pullsOnly.commits = nil
        let pulls = RecapFormat.cards(RecapSupport.aggregate(pullsOnly, now: friday, calendar: calendar()), text: text,
                                      language: .enUS, locale: english)
        suite.expect(pulls.first?.label == "Pull requests" && pulls.first?.value == 2 && pulls.first?.detail == "",
                     "without commits, the GitHub card counts the pull requests opened today")
        suite.expect(RecapFormat.imageName(app: "Zenith", title: "Today", day: "2026-11-20") == "Zenith Today 2026-11-20.png"
                     && RecapFormat.imageName(app: "Zenith", title: "Today", day: "2026-11-20", copy: 3) == "Zenith Today 2026-11-20 3.png"
                     && RecapFormat.imageName(app: "Zenith", title: "A/B:C", day: "2026-11-20") == "Zenith A-B-C 2026-11-20.png",
                     "the saved image is named for the day, numbered beside an older one, without slashes or colons")
    }

    private static func plurals(_ suite: TestSuite) {
        let en = ZenithStrings.recap(.enUS)
        suite.expect(RecapFormat.counted(1, en.deploysCount, language: .enUS, locale: english) == "1 deploy"
                     && RecapFormat.counted(4, en.deploysCount, language: .enUS, locale: english) == "4 deploys"
                     && RecapFormat.counted(0, en.commitsCount, language: .enUS, locale: english) == "0 commits"
                     && RecapFormat.counted(1248, en.photos, language: .enUS, locale: english) == "1,248 photos"
                     && RecapFormat.counted(1, en.pullsOpened, language: .enUS, locale: english) == "1 PR opened",
                     "English has one and many")
        let ru = ZenithStrings.recap(.ru)
        let russian = Locale(identifier: "ru_RU")
        suite.expect([1, 3, 5, 11, 21, 22, 25].map { RecapFormat.counted($0, ru.commitsCount, language: .ru, locale: russian) }
                        == ["1 коммит", "3 коммита", "5 коммитов", "11 коммитов", "21 коммит", "22 коммита", "25 коммитов"],
                     "Russian agrees by the last digits")
        let sk = ZenithStrings.recap(.sk)
        let slovak = Locale(identifier: "sk_SK")
        suite.expect([1, 2, 4, 5, 21].map { RecapFormat.counted($0, sk.sessions, language: .sk, locale: slovak) }
                        == ["1 relácia", "2 relácie", "4 relácie", "5 relácií", "21 relácií"],
                     "Slovak agrees by the whole number")
        let uk = ZenithStrings.recap(.uk)
        suite.expect(RecapFormat.counted(2, uk.deploysCount, language: .uk, locale: Locale(identifier: "uk_UA")) == "2 деплої"
                     && RecapFormat.counted(12, uk.deploysCount, language: .uk, locale: Locale(identifier: "uk_UA")) == "12 деплоїв",
                     "Ukrainian agrees by the last digits too")
        let ja = ZenithStrings.recap(.ja)
        suite.expect(RecapFormat.counted(1, ja.photos, language: .ja, locale: Locale(identifier: "ja_JP"))
                        .replacingOccurrences(of: "1", with: "N")
                        == RecapFormat.counted(7, ja.photos, language: .ja, locale: Locale(identifier: "ja_JP"))
                        .replacingOccurrences(of: "7", with: "N"),
                     "Japanese counts without plural forms")
    }

    private static func headline(_ suite: TestSuite) {
        let text = ZenithStrings.recap(.enUS)
        let recap = RecapSupport.aggregate(fullDay(), now: friday, calendar: calendar())
        suite.expect(RecapFormat.headline(recap, text: text, language: .enUS, locale: english).joined(separator: " · ")
                        == "6h 11m coding · 4 deploys · 1,248 photos",
                     "the notice leads with coding, deploys and photos")
        suite.expect(RecapFormat.headline(recap, text: text, language: .enUS, locale: english, limit: 5)
                        == ["6h 11m coding", "4 deploys", "1,248 photos", "12 commits", "3 exports"],
                     "then commits and exports")
        var quiet = RecapTally(day: "2026-11-20")
        quiet.commands = 1
        quiet.turns = 2
        let small = RecapSupport.aggregate(RecapInputs(tally: quiet), now: friday, calendar: calendar())
        suite.expect(RecapFormat.headline(small, text: text, language: .enUS, locale: english) == ["2 agent turns", "1 long command"],
                     "a quiet day says what it has, nothing more")
        suite.expect(RecapFormat.headline(RecapSupport.aggregate(RecapInputs(), now: friday, calendar: calendar()), text: text,
                                          language: .enUS, locale: english).isEmpty,
                     "an empty day has no headline")
    }

    private static func summary(_ suite: TestSuite) {
        let text = ZenithStrings.recap(.enUS)
        let jakarta = calendar()
        let recap = RecapSupport.aggregate(fullDay(), now: friday, calendar: jakarta)
        let summary = RecapFormat.summary(recap, text: text, language: .enUS, locale: english, date: friday, calendar: jakarta)
        let expected = """
            My day · Fri, Nov 20
            Coding 6h 11m · Swift
            Deploys 4 · 1 failed
            Commits 12 · 1 PR opened
            Long commands 3 · 41m
            Photos 1,248 · 52.0 GB · 12 videos
            Exports 3 · 8.4 GB
            Agent turns 14 · 3 sessions
            """
        suite.expect(summary == expected, "the shareable text is a dated heading and one short line per source")
        suite.expect(!summary.contains("zenith") && !summary.contains("review") && !summary.contains("check"),
                     "the shared text leaves out project names and what only waits on the person")
        for language in AppLanguage.allCases {
            let text = ZenithStrings.recap(language)
            let shared = RecapFormat.summary(recap, text: text, language: language, locale: Locale(identifier: language.rawValue),
                                             date: friday, calendar: jakarta)
            suite.expect(!shared.contains("\u{2014}") && !shared.contains("'") && !shared.contains("%@")
                         && shared.split(separator: "\n").count == 8,
                         "\(language.rawValue) shares a full summary without em dashes, straight apostrophes or placeholders")
        }
        let empty = RecapFormat.summary(Recap(day: "2026-11-20"), text: text, language: .enUS, locale: english, date: friday,
                                        calendar: jakarta)
        suite.expect(empty == "My day · Fri, Nov 20", "an empty day shares only its heading")
    }

    // MARK: Schedule

    private static func schedule(_ suite: TestSuite) {
        let jakarta = calendar()
        let settings = RecapSettings()
        suite.expect(settings.minutes == 17 * 60 && settings.enabled && !settings.weekdaysOnly && settings.sources.count == 7,
                     "by default the recap shows at 17:00, every day, with every source")
        suite.expect(!RecapSchedule.isDue(now: date(20, 16, 59), settings: settings, lastShown: nil, calendar: jakarta)
                     && RecapSchedule.isDue(now: date(20, 17), settings: settings, lastShown: nil, calendar: jakarta)
                     && RecapSchedule.isDue(now: date(20, 23, 30), settings: settings, lastShown: "2026-11-19", calendar: jakarta),
                     "it is due from its time until midnight")
        suite.expect(!RecapSchedule.isDue(now: date(20, 18), settings: settings, lastShown: "2026-11-20", calendar: jakarta)
                     && !RecapSchedule.isDue(now: date(20, 18), settings: settings, lastShown: "2026-11-21", calendar: jakarta),
                     "once shown today, or on a later day before a clock went back, it waits")
        suite.expect(RecapSchedule.nextCheck(after: date(20, 9), settings: settings, lastShown: nil, calendar: jakarta) == date(20, 17)
                     && RecapSchedule.nextCheck(after: date(20, 18), settings: settings, lastShown: nil, calendar: jakarta) == date(20, 18)
                     && RecapSchedule.nextCheck(after: date(20, 18), settings: settings, lastShown: "2026-11-20", calendar: jakarta)
                        == date(21, 17),
                     "the next look is today’s time, now when due, or tomorrow’s time once shown")
        var off = settings
        off.enabled = false
        suite.expect(!RecapSchedule.isDue(now: date(20, 18), settings: off, lastShown: nil, calendar: jakarta)
                     && RecapSchedule.nextCheck(after: date(20, 9), settings: off, lastShown: nil, calendar: jakarta) == nil,
                     "turned off, nothing is due and nothing waits")
        var early = settings
        early.minutes = 6 * 60 + 45
        suite.expect(RecapSchedule.nextCheck(after: date(20, 6), settings: early, lastShown: nil, calendar: jakarta) == date(20, 6, 45)
                     && RecapSchedule.minutes(of: date(20, 6, 45), calendar: jakarta) == 405,
                     "any time of day can be chosen, to the minute")
        let newYork = calendar("America/New_York")
        var night = settings
        night.minutes = 2 * 60 + 30
        let springForward = newYork.date(from: DateComponents(year: 2027, month: 3, day: 14))!
        let moment = RecapSchedule.moment(on: springForward, settings: night, calendar: newYork)
        suite.expect(moment.map { $0 > springForward && newYork.isDate($0, inSameDayAs: springForward) } == true,
                     "a time the clock skips moves on to the next valid moment that day")
    }

    private static func weekends(_ suite: TestSuite) {
        let jakarta = calendar()
        var weekdays = RecapSettings()
        weekdays.weekdaysOnly = true
        let saturday = date(21, 18)
        suite.expect(!RecapSchedule.isDue(now: saturday, settings: weekdays, lastShown: "2026-11-20", calendar: jakarta)
                     && RecapSchedule.isDue(now: saturday, settings: RecapSettings(), lastShown: "2026-11-20", calendar: jakarta),
                     "weekdays only skips Saturday; otherwise Saturday has its recap")
        suite.expect(RecapSchedule.nextCheck(after: date(20, 18), settings: weekdays, lastShown: "2026-11-20", calendar: jakarta)
                        == date(23, 17)
                     && RecapSchedule.nextCheck(after: date(20, 18), settings: RecapSettings(), lastShown: "2026-11-20",
                                                calendar: jakarta) == date(21, 17),
                     "after Friday’s, weekdays only waits for Monday")
        suite.expect(RecapSchedule.isOffDay(date(22, 12), settings: weekdays, calendar: jakarta)
                     && !RecapSchedule.isOffDay(date(23, 12), settings: weekdays, calendar: jakarta),
                     "Sunday is off, Monday is not")
    }

    private static func acrossMidnight(_ suite: TestSuite) {
        let jakarta = calendar()
        let settings = RecapSettings()
        suite.expect(!RecapSchedule.isDue(now: date(21, 0, 30), settings: settings, lastShown: "2026-11-20", calendar: jakarta)
                     && RecapSchedule.nextCheck(after: date(21, 0, 30), settings: settings, lastShown: "2026-11-20",
                                                calendar: jakarta) == date(21, 17),
                     "after midnight the new day waits for its own time")
        suite.expect(!RecapSchedule.isDue(now: date(21, 0, 30), settings: settings, lastShown: nil, calendar: jakarta),
                     "a missed evening is not shown after midnight")
        suite.expect(RecapSchedule.wasShown(on: date(20, 23, 59), lastShown: "2026-11-20", calendar: jakarta)
                     && !RecapSchedule.wasShown(on: date(21, 0, 0), lastShown: "2026-11-20", calendar: jakarta)
                     && !RecapSchedule.wasShown(on: date(21, 0, 0), lastShown: "", calendar: jakarta),
                     "a day ends at local midnight")
    }

    private static func timeZones(_ suite: TestSuite) {
        let jakarta = calendar()
        let newYork = calendar("America/New_York")
        let settings = RecapSettings()
        // Shown at 17:00 in Jakarta (10:00 UTC), then flown west: it is 05:00 the same date in New York.
        let shownInJakarta = date(20, 17)
        let shown = RecapSchedule.dayKey(shownInJakarta, calendar: jakarta)
        let newYorkEvening = date(20, 18, in: newYork)
        suite.expect(!RecapSchedule.isDue(now: newYorkEvening, settings: settings, lastShown: shown, calendar: newYork)
                     && RecapSchedule.nextCheck(after: shownInJakarta, settings: settings, lastShown: shown, calendar: newYork)
                        == date(21, 17, in: newYork),
                     "flying west onto the same date never shows the day twice")
        // Shown at 17:00 in New York (22:00 UTC), then flown east: it is already 05:00 the next day in Jakarta.
        let shownInNewYork = date(20, 17, in: newYork)
        let shownWest = RecapSchedule.dayKey(shownInNewYork, calendar: newYork)
        suite.expect(!RecapSchedule.isDue(now: shownInNewYork, settings: settings, lastShown: shownWest, calendar: jakarta)
                     && RecapSchedule.nextCheck(after: shownInNewYork, settings: settings, lastShown: shownWest, calendar: jakarta)
                        == date(21, 17, in: jakarta)
                     && RecapSchedule.isDue(now: date(21, 17, in: jakarta), settings: settings, lastShown: shownWest, calendar: jakarta),
                     "flying east onto the next date waits for that day’s time")
        var tally = RecapTally().recording(.command(duration: 60, ended: shownInNewYork), calendar: newYork)
        tally = tally.recording(.command(duration: 60, ended: shownInNewYork.addingTimeInterval(60)), calendar: jakarta)
        suite.expect(tally.day == "2026-11-21" && tally.commands == 1,
                     "the tally follows the local date, wherever the Mac is")
    }

    private static func settings(_ suite: TestSuite) {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        suite.expect(RecapSettings.current(in: defaults) == RecapSettings(),
                     "unset preferences read as the defaults")
        defaults.set(false, forKey: DefaultsKey.notchRecapEnabled)
        defaults.set(5000, forKey: DefaultsKey.notchRecapMinutes)
        defaults.set(true, forKey: DefaultsKey.notchRecapWeekdaysOnly)
        defaults.set("github, photos,unknown,github", forKey: DefaultsKey.notchRecapHiddenSources)
        let stored = RecapSettings.current(in: defaults)
        suite.expect(!stored.enabled && stored.minutes == 24 * 60 - 1 && stored.weekdaysOnly && stored.hidden == [.github, .photos]
                     && !stored.sources.contains(.github) && stored.sources.contains(.coding),
                     "stored preferences are read, a time out of range is clamped, unknown sources dropped")
        suite.expect(RecapSettings.encodeHidden([.photos, .coding]) == "coding,photos"
                     && RecapSettings.decodeHidden(RecapSettings.encodeHidden(Set(RecapSource.allCases))) == Set(RecapSource.allCases)
                     && RecapSettings.clamped(-20) == 0,
                     "hidden sources round-trip in a stable order")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.notchRecapEnabled] as? Bool == true
                     && Defaults.registeredDefaults[DefaultsKey.notchRecapMinutes] as? Int == 17 * 60
                     && Defaults.registeredDefaults[DefaultsKey.notchRecapWeekdaysOnly] as? Bool == false
                     && Defaults.registeredDefaults[DefaultsKey.notchRecapHiddenSources] as? String == ""
                     && SettingsBackupSupport.exportKeys().contains(DefaultsKey.notchRecapMinutes),
                     "the recap’s preferences are registered and travel with settings backups")
        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: Today's commits

    private static func commitSearch(_ suite: TestSuite) {
        let jakarta = calendar()
        // 01:00 in Jakarta is still the 19th in UTC.
        suite.expect(RecapCommits.since(date(20, 17), calendar: jakarta) == "2026-11-20T00:00:00+07:00"
                     && RecapCommits.since(date(20, 1), calendar: calendar("UTC")) == "2026-11-19T00:00:00+00:00",
                     "today starts at local midnight, written with its offset")
        suite.expect(RecapCommits.since(date(20, 9, in: calendar("America/New_York")), calendar: calendar("America/New_York"))
                        == "2026-11-20T00:00:00-05:00",
                     "a zone behind UTC keeps its own midnight")
        suite.expect(RecapCommits.query(login: nil, now: date(20, 17), calendar: jakarta)
                        == "author:@me committer-date:>=2026-11-20T00:00:00+07:00"
                     && RecapCommits.query(login: "Zazaaw", now: date(20, 17), calendar: jakarta)
                        == "author:Zazaaw committer-date:>=2026-11-20T00:00:00+07:00",
                     "the search asks for today’s commits by the signed-in person")
        suite.expect(["", "-x", "a b", "a:b", "x&q=1", "é", String(repeating: "a", count: 40)].allSatisfy { RecapCommits.author($0) == "@me" }
                     && RecapCommits.author("my-login-1") == "my-login-1",
                     "anything that is not a GitHub login falls back to @me")
        let arguments = RecapCommits.arguments(login: "me", now: date(20, 17), calendar: jakarta)
        suite.expect(arguments == ["api", "-X", "GET", "search/commits", "-H", "Accept: application/vnd.github+json",
                                   "-f", "q=author:me committer-date:>=2026-11-20T00:00:00+07:00", "-f", "per_page=1"],
                     "one GET of one result: the count is all it reads")
        suite.expect(!arguments.contains("graphql") && arguments.filter { $0 == "-f" }.count == 2,
                     "it never posts or asks for more than the count")
        suite.expect(RecapCommits.count(from: Data(#"{"total_count": 12, "incomplete_results": false, "items": []}"#.utf8)) == 12
                     && RecapCommits.count(from: Data("note\n{\"total_count\":0}\n".utf8)) == 0
                     && RecapCommits.count(from: Data(#"{"message":"Validation Failed"}"#.utf8)) == nil
                     && RecapCommits.count(from: Data(#"{"total_count": -1}"#.utf8)) == nil
                     && RecapCommits.count(from: Data()) == nil,
                     "the count is read from the answer, also with a line around it; anything else is no count")
        let node: [String: Any] = ["number": 7, "url": "https://github.com/a/b/pull/7", "repository": ["nameWithOwner": "a/b"],
                                   "createdAt": "2026-11-20T03:00:00Z", "updatedAt": "2026-11-20T04:00:00Z"]
        suite.expect(GitHubSupport.pullRequest(from: node)?.created == GitHubSupport.date(from: "2026-11-20T03:00:00Z")
                     && GitHubSupport.graphQL.contains("createdAt"),
                     "the inbox’s pull requests carry when they were opened")
    }

    // MARK: Island

    private static func island(_ suite: TestSuite) {
        suite.expect(NotchModule.recap.isAvailable() && NotchModule.recap.shortcutKey == "y"
                     && Set(NotchModule.allCases.map(\.shortcutKey)).count == NotchModule.allCases.count,
                     "the Today page is always listed, with a direct key of its own")
        suite.expect(Set(NotchModule.allCases.map(ZenithIslandPalette.hex)).count == NotchModule.allCases.count
                     && ZenithHomeWidget.today.module == .recap && ZenithHomeWidget.today.hex == ZenithIslandPalette.hex(.recap),
                     "Today has its own colour, and its home widget wears it")
        let notice = ZenithNotice(kind: .recap, key: ZenithNoticeKey.recap("2026-11-20"), title: "Your day",
                                  subtitle: "6h 11m coding", accessory: .action("Open"), action: .openRecap)
        var queue = ZenithNoticeQueue()
        _ = queue.enqueue(notice, now: 0)
        suite.expect(queue.enqueue(notice, now: 1) == .coalesced && queue.pending.count == 1,
                     "the same day’s recap never queues twice")
        suite.expect(notice.priority == 1 && notice.duration == 8 && ZenithNoticeQueue.lifetime(.recap) == 600,
                     "the recap is no emergency: low priority, a little longer on screen, and it waits for the island")
        suite.expect(Set(RecapSource.allCases.map(\.hex)).count == RecapSource.allCases.count,
                     "every source has its own soft colour")
    }

    // MARK: Strings

    private static func strings(_ suite: TestSuite) {
        for language in AppLanguage.allCases {
            let text = ZenithStrings.recap(language)
            let values = Mirror(reflecting: text).children.flatMap { child -> [String] in
                if let value = child.value as? String { return [value] }
                return child.value as? [String] ?? []
            }
            suite.expect(values.count == 76 && values.allSatisfy { !$0.isEmpty && !$0.contains("'") && !$0.contains("\u{2014}") },
                         "\(language.rawValue) words every recap string, with curly apostrophes and no em dash")
            let forms = Mirror(reflecting: text).children.compactMap { $0.value as? [String] }
            suite.expect(forms.count == 14 && forms.allSatisfy { $0.count == 3 && $0.allSatisfy { $0.components(separatedBy: "%@").count == 2 } },
                         "\(language.rawValue) gives one, few and many forms, each with its count once")
            suite.expect(text.codingHeadline.components(separatedBy: "%@").count == 2
                         && text.shareHeading.components(separatedBy: "%@").count == 2,
                         "\(language.rawValue) places the duration and the date once")
        }
    }
}
