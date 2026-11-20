// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation

/// Zenith fork: the lock screen's terminal readout. Pure logic only: nothing
/// here reads a service, a token, `gh` or the network.
enum LockScreenTerminalTests {
    private typealias Support = NotchLockScreenTerminalSupport
    private typealias Selection = NotchLockScreenTerminalSelection

    static func run(_ suite: TestSuite) {
        selection(suite)
        ordering(suite)
        visibility(suite)
        privacy(suite)
        agents(suite)
        wakaTime(suite)
        vercel(suite)
        checks(suite)
        system(suite)
        downloads(suite)
        timer(suite)
        formatting(suite)
        layout(suite)
        configuration(suite)
        title(suite)
    }

    // MARK: Fixtures

    private static let now = Date(timeIntervalSince1970: 2_000_000)
    private static let secret = "secret-project"

    private static func session(_ provider: AgentProvider, project: String = secret,
                                startedAgo: TimeInterval = 60) -> AgentLiveSession {
        AgentLiveSession(id: provider.rawValue + project + "\(startedAgo)", provider: provider,
                         started: now.addingTimeInterval(-startedAgo), lastActivity: now, model: "m",
                         project: project, tokens: AgentTokens(), cost: 0)
    }

    private static func deployment(_ state: VercelSupport.State, ago: TimeInterval,
                                   project: String = secret) -> VercelSupport.Deployment {
        VercelSupport.Deployment(uid: "\(state)\(ago)", project: project, host: nil, state: state,
                                 created: now.addingTimeInterval(-ago), isProduction: true, branch: nil,
                                 commitMessage: nil, inspectorURL: nil, scope: nil)
    }

    private static func pullRequest(_ checks: GitHubSupport.Checks, repository: String = "satuvisual/" + secret,
                                    number: Int = 1) -> GitHubSupport.PullRequest {
        GitHubSupport.PullRequest(number: number, title: "t", url: URL(string: "https://github.com/x/y/pull/\(number)")!,
                                  repository: repository, author: nil, isDraft: false, updated: now, checks: checks)
    }

    private static func inbox(mine: [GitHubSupport.PullRequest], reviews: Int = 0) -> GitHubSupport.Inbox {
        GitHubSupport.Inbox(login: "me", reviewRequested: [], reviewCount: reviews, mine: mine, mineCount: mine.count)
    }

    private static func download(_ name: String = secret + ".zip", fraction: Double?, active: Bool = true,
                                 completed: Bool = false) -> NotchDownloadItem {
        NotchDownloadItem(id: name, url: URL(fileURLWithPath: "/tmp/" + name), name: name, receivedBytes: 1,
                          fraction: fraction, completed: completed, active: active)
    }

    /// Every source with something to say, project names included.
    private static func fullReadings() -> NotchLockScreenTerminalReadings {
        var timer = NotchTimerSession()
        timer.start(mode: .timer, minutes: 15, now: 100)
        return NotchLockScreenTerminalReadings(
            agents: [session(.claude), session(.codex, project: "other")],
            wakaSeconds: 3 * 3600 + 12 * 60, wakaGoalMinutes: 256, wakaTopProject: secret,
            deployments: [deployment(.building, ago: 30)], inbox: inbox(mine: [pullRequest(.pending)]),
            batteryPercent: 84, charging: false, cpu: 0.23, downloads: [download(fraction: 0.42)],
            timer: timer, timerNow: 100 + 3 * 60 - 4,
            prayer: "ashar 15:04 · in 1h 04m", golden: "17:21–18:04 · in 3h 21m", now: now) // Zenith fork
    }

    // MARK: Selection

    private static func selection(_ suite: TestSuite) {
        // Zenith fork: the Sky lines (prayer, golden) join at the end, off.
        suite.expect(Selection.defaultValue == "agents,waka,-vercel,-ci,sys,dl,timer,-prayer,-golden",
                     "the default order is the readout's own, with Vercel, GitHub checks and the Sky lines off")
        suite.expect(Selection(stored: nil) == Selection(stored: Selection.defaultValue)
                     && Selection(stored: "  ") == Selection(stored: Selection.defaultValue),
                     "nothing stored reads as the default")
        let parsed = Selection(stored: "timer, -sys,bogus,timer,ci")
        suite.expect(parsed.entries.map(\.source) == [.timer, .sys, .ci, .agents, .waka, .vercel, .dl, .prayer, .golden]
                     && parsed.shown == [.timer, .ci],
                     "unknown and repeated names are skipped; missing lines join at the end, off")
        suite.expect(Selection(stored: parsed.stored) == parsed && parsed.stored == "timer,-sys,ci,-agents,-waka,-vercel,-dl,-prayer,-golden",
                     "a selection survives being stored and read back")
        var toggled = Selection(stored: nil)
        toggled.set(.vercel, isOn: true)
        toggled.set(.timer, isOn: false)
        suite.expect(toggled.shown == [.agents, .waka, .vercel, .sys, .dl] && toggled.isOn(.vercel) && !toggled.isOn(.timer),
                     "a line turns on and off in its place")
    }

    private static func ordering(_ suite: TestSuite) {
        var selection = Selection(stored: nil)
        selection.move(.sys, by: -4)
        suite.expect(selection.entries.map(\.source) == [.sys, .agents, .waka, .vercel, .ci, .dl, .timer, .prayer, .golden],
                     "a line moves up past the others")
        selection.move(.sys, by: -1)
        selection.move(.golden, by: 1)
        suite.expect(selection.entries.first?.source == .sys && selection.entries.last?.source == .golden,
                     "moving past either end stops there")
        suite.expect(!selection.canMove(.sys, by: -1) && selection.canMove(.sys, by: 1)
                     && !selection.canMove(.golden, by: 1) && !selection.canMove(.waka, by: 0),
                     "the first line cannot go up, the last cannot go down")
        selection.move(.agents, by: 99)
        suite.expect(selection.entries.map(\.source) == [.sys, .waka, .vercel, .ci, .dl, .timer, .prayer, .golden, .agents],
                     "a large move lands at the end")
        let lines = Support.lines([.timer, .sys, .agents], readings: fullReadings(), showsProjects: false)
        suite.expect(lines.map(\.source) == [.timer, .sys, .agents], "the readout follows the chosen order")
        suite.expect(Support.lines([.sys, .sys], readings: fullReadings(), showsProjects: false).count == 1,
                     "a line shows once")
    }

    // MARK: Visibility

    private static func visibility(_ suite: TestSuite) {
        let all = NotchLockScreenTerminalSource.allCases
        let empty = NotchLockScreenTerminalReadings(now: now)
        suite.expect(Support.lines(all, readings: empty, showsProjects: false).map(\.source) == [.sys],
                     "with nothing to read, only sys shows")
        suite.expect(Support.lines(all, readings: empty, showsProjects: false).first?.value == "cpu --",
                     "sys shows before its first reading")
        var quiet = empty
        quiet.agents = []
        quiet.wakaSeconds = 0
        quiet.deployments = []
        quiet.inbox = inbox(mine: [])
        quiet.downloads = [download(fraction: 1, completed: true), download(fraction: 0.3, active: false)]
        quiet.timer = NotchTimerSession()
        suite.expect(Support.lines(all.filter { $0 != .sys }, readings: quiet, showsProjects: true).isEmpty,
                     "a source with nothing to show hides its line")
        suite.expect(Support.lines(all, readings: fullReadings(), showsProjects: false).count == all.count,
                     "every source with something to say shows")
        suite.expect(Support.lines([], readings: fullReadings(), showsProjects: true).isEmpty,
                     "no chosen lines, no readout")
    }

    private static func privacy(_ suite: TestSuite) {
        let all = NotchLockScreenTerminalSource.allCases
        var readings = fullReadings()
        readings.inbox = inbox(mine: [pullRequest(.failure)])
        let hidden = Support.lines(all, readings: readings, showsProjects: false)
        suite.expect(!hidden.contains { $0.value.contains(secret) || $0.value.contains("other") || $0.value.contains("satuvisual") },
                     "no project, repository or file name shows while names are off")
        let shown = Support.lines(all, readings: readings, showsProjects: true)
        let named: Set<NotchLockScreenTerminalSource> = [.agents, .waka, .vercel, .ci, .dl]
        suite.expect(shown.filter { named.contains($0.source) }.allSatisfy { $0.value.contains(secret) },
                     "with names on, every line that has one shows it")
        suite.expect(shown.first { $0.source == .sys }?.value == hidden.first { $0.source == .sys }?.value
                     && shown.first { $0.source == .timer }?.value == hidden.first { $0.source == .timer }?.value,
                     "lines without names read the same either way")
    }

    // MARK: Lines

    private static func agents(_ suite: TestSuite) {
        let live = [session(.codex, startedAgo: 10), session(.claude, startedAgo: 30)]
        suite.expect(Support.agents(live, showsProjects: false)?.value == "2 running · claude, codex",
                     "agents read as a count and their names, in a fixed order")
        suite.expect(Support.agents([session(.claude), session(.claude, startedAgo: 5)], showsProjects: false)?.value
                        == "2 running · claude",
                     "two sessions of one agent name it once")
        suite.expect(Support.agents([session(.claude, project: "web"), session(.codex, project: " ")], showsProjects: true)?.value
                        == "2 running · claude@web, codex",
                     "with names on, each agent shows its project, or nothing when it has none")
        suite.expect(Support.agents([], showsProjects: true) == nil, "no agent working, no line")
    }

    private static func wakaTime(_ suite: TestSuite) {
        suite.expect(Support.wakaTime(seconds: 3 * 3600 + 12 * 60, goalMinutes: 256, topProject: nil,
                                      showsProjects: false)?.value == "3h 12m · goal 75%",
                     "coding time reads with the share of the goal")
        suite.expect(Support.wakaTime(seconds: 45 * 60, goalMinutes: 0, topProject: "web", showsProjects: false)?.value == "45m",
                     "without a goal, the time alone")
        suite.expect(Support.wakaTime(seconds: 5 * 3600, goalMinutes: 240, topProject: "web", showsProjects: true)?.value
                        == "5h 0m · goal 125% · web",
                     "a goal passed reads over 100%, and the top project shows with names on")
        suite.expect(Support.wakaTime(seconds: 0, goalMinutes: 60, topProject: nil, showsProjects: false) == nil
                     && Support.wakaTime(seconds: nil, goalMinutes: 60, topProject: nil, showsProjects: false) == nil
                     && Support.wakaTime(seconds: .nan, goalMinutes: 60, topProject: nil, showsProjects: false) == nil,
                     "no coding time today, no line")
    }

    private static func vercel(_ suite: TestSuite) {
        suite.expect(Support.vercel([deployment(.ready, ago: 7200), deployment(.building, ago: 20)],
                                    showsProjects: false, now: now)?.value == "building",
                     "a build on its way comes first")
        suite.expect(Support.vercel([deployment(.building, ago: 20, project: "a"), deployment(.initializing, ago: 10, project: "b")],
                                    showsProjects: true, now: now)?.value == "2 building · b",
                     "several builds read as a count, with the newest one's project")
        suite.expect(Support.vercel([deployment(.queued, ago: 5)], showsProjects: false, now: now)?.value == "queued",
                     "a build still waiting reads as queued")
        let ready = Support.vercel([deployment(.ready, ago: 7200), deployment(.error, ago: 90_000)], showsProjects: false, now: now)
        suite.expect(ready?.value == "ready · 2h ago" && ready?.tone == .plain,
                     "otherwise the newest deployment's state and age")
        let failed = Support.vercel([deployment(.error, ago: 300)], showsProjects: true, now: now)
        suite.expect(failed?.value == "failed · 5m ago · " + secret && failed?.tone == .failure,
                     "a failed build takes the failure dot")
        suite.expect(Support.vercel([], showsProjects: false, now: now) == nil, "no deployments, no line")
    }

    private static func checks(_ suite: TestSuite) {
        suite.expect(Support.checks(inbox(mine: [pullRequest(.pending), pullRequest(.pending, number: 2)]),
                                    showsProjects: false)?.value == "2 checks pending",
                     "pending checks read as the readout's example")
        let failing = Support.checks(inbox(mine: [pullRequest(.failure), pullRequest(.pending, number: 2),
                                                  pullRequest(.success, number: 3)], reviews: 1), showsProjects: true)
        suite.expect(failing?.value == "1 check failing · 1 pending · 1 review · satuvisual/" + secret
                     && failing?.tone == .failure,
                     "failing checks come first with their dot; reviews follow, then the repository with names on")
        suite.expect(Support.checks(inbox(mine: [pullRequest(.success), pullRequest(.success, number: 2)]),
                                    showsProjects: false)?.value == "2 checks passing",
                     "all green reads as passing")
        suite.expect(Support.checks(inbox(mine: [pullRequest(.none)]), showsProjects: false)?.value == "1 open",
                     "pull requests without checks are counted")
        suite.expect(Support.checks(inbox(mine: [], reviews: 3), showsProjects: false)?.value == "3 reviews",
                     "reviews waiting show alone")
        suite.expect(Support.checks(inbox(mine: []), showsProjects: true) == nil, "nothing open, no line")
    }

    private static func system(_ suite: TestSuite) {
        suite.expect(Support.system(batteryPercent: 84, charging: false, cpu: 0.23).value == "bat 84% · cpu 23%",
                     "battery and CPU read as the readout's example")
        suite.expect(Support.system(batteryPercent: 50, charging: true, cpu: 0.5).value == "bat 50% charging · cpu 50%",
                     "charging says so")
        suite.expect(Support.system(batteryPercent: nil, charging: false, cpu: 0.071).value == "cpu 7%",
                     "a Mac without a battery reads its CPU alone")
        suite.expect(Support.system(batteryPercent: 15, charging: false, cpu: nil).tone == .warning
                     && Support.system(batteryPercent: 15, charging: true, cpu: nil).tone == .plain
                     && Support.system(batteryPercent: 21, charging: false, cpu: nil).tone == .plain,
                     "a low battery, unplugged, takes the warning dot")
        suite.expect(Support.system(batteryPercent: 140, charging: false, cpu: 1.7).value == "bat 100% · cpu 100%"
                     && Support.system(batteryPercent: nil, charging: false, cpu: .infinity).value == "cpu --",
                     "readings stay in range")
    }

    private static func downloads(_ suite: TestSuite) {
        suite.expect(Support.downloads([download(fraction: 0.42)], showsProjects: false)?.value == "1 file 42%",
                     "one download reads as the readout's example")
        suite.expect(Support.downloads([download("a", fraction: 0.2), download("b", fraction: 0.6), download("c", fraction: nil)],
                                       showsProjects: true)?.value == "3 files 40% · a",
                     "several downloads read their average progress, and the first name with names on")
        suite.expect(Support.downloads([download(fraction: nil)], showsProjects: false)?.value == "1 file",
                     "unknown progress reads the count alone")
        suite.expect(Support.downloads([download(fraction: 1, completed: true)], showsProjects: false) == nil,
                     "finished downloads hide the line")
    }

    private static func timer(_ suite: TestSuite) {
        var countdown = NotchTimerSession()
        countdown.start(mode: .timer, minutes: 15, now: 100)
        suite.expect(Support.timer(countdown, at: 100 + 3 * 60 - 4)?.value == "12:04 left",
                     "a countdown reads as the readout's example")
        suite.expect(Support.timer(countdown, at: 100 + 15 * 60 + 1)?.value == "done",
                     "a countdown past its end is done")
        var paused = countdown
        paused.pause(at: 100 + 60)
        suite.expect(Support.timer(paused, at: 5000)?.value == "14:00 paused", "a paused timer says so")
        var stopwatch = NotchTimerSession()
        stopwatch.start(mode: .stopwatch, minutes: 0, now: 0)
        suite.expect(Support.timer(stopwatch, at: 190)?.value == "03:10 elapsed", "a stopwatch counts up")
        var focus = NotchTimerSession()
        focus.start(mode: .pomodoro, minutes: 25, now: 0)
        suite.expect(Support.timer(focus, at: 60)?.value == "focus 24:00 left", "a focus session names its phase")
        suite.expect(Support.timer(NotchTimerSession(), at: 0) == nil, "no timer, no line")
    }

    private static func formatting(_ suite: TestSuite) {
        suite.expect(Support.duration(30) == "<1m" && Support.duration(60) == "1m" && Support.duration(3600) == "1h 0m"
                     && Support.duration(.nan) == "<1m",
                     "durations read in hours and minutes")
        suite.expect(Support.age(10) == "just now" && Support.age(-5) == "just now" && Support.age(59 * 60) == "59m ago"
                     && Support.age(3 * 3600) == "3h ago" && Support.age(50 * 3600) == "2d ago",
                     "ages read in the largest whole unit")
        suite.expect(Support.percent(0.004) == "0%" && Support.percent(0.995) == "100%" && Support.percent(-1) == "0%"
                     && Support.percent(.nan) == "--",
                     "percentages are whole and in range")
        suite.expect(NotchLockScreenTerminalSource.allCases.allSatisfy { Support.paddedLabel($0).count == Support.labelWidth }
                     && Support.paddedLabel(.ci) == "ci    " && Support.labelWidth == 6,
                     "labels pad to one column")
    }

    // MARK: Layout

    private static func layout(_ suite: TestSuite) {
        typealias Layout = NotchLockScreenTerminalLayout
        let screen = CGRect(x: 0, y: 0, width: 1470, height: 956)
        let row = NotchLockScreenLayout.rowFrame(in: screen)
        let player = NotchLockScreenLayout.playerFrame(in: screen)
        let arranged = Layout.arrange(row: row, player: player, screen: screen, lines: 7, music: true)
        suite.expect(arranged.terminal.map { terminal in
            terminal.minY == screen.minY + NotchLockScreenLayout.loginClearance
                && terminal.width == NotchLockScreenLayout.paneWidth
                && terminal.height == Layout.height(lines: 7) && terminal.midX == screen.midX
        } == true, "the readout sits at the bottom, just over the login controls, as wide as the player's pane")
        suite.expect(arranged.player.map { adjusted in
            arranged.terminal.map { adjusted.minY == $0.maxY + Layout.gap } == true
                && adjusted.maxY == player?.maxY && adjusted.height >= NotchLockScreenLayout.minimumPlayerHeight
        } == true, "the player keeps the room over the readout")
        suite.expect(Layout.height(lines: 2) == Layout.headerHeight + 2 * Layout.lineHeight + 2 * Layout.verticalPadding,
                     "the card holds its title bar and its lines, the cursor ending the last")
        let short = CGRect(x: 0, y: 0, width: 1280, height: 800)
        let shortArranged = Layout.arrange(row: NotchLockScreenLayout.rowFrame(in: short),
                                           player: NotchLockScreenLayout.playerFrame(in: short), screen: short,
                                           lines: 7, music: true)
        suite.expect(shortArranged.terminal == nil && shortArranged.player == NotchLockScreenLayout.playerFrame(in: short),
                     "on a short display the readout gives way to the player")
        let silent = Layout.arrange(row: NotchLockScreenLayout.rowFrame(in: short),
                                    player: NotchLockScreenLayout.playerFrame(in: short), screen: short, lines: 7, music: false)
        suite.expect(silent.terminal != nil, "without music the readout takes the room")
        let none = Layout.arrange(row: row, player: player, screen: screen, lines: 0, music: true)
        suite.expect(none.terminal == nil && none.player == player, "no lines, no readout, and the player as it was")
        suite.expect(Layout.arrange(row: nil, player: player, screen: screen, lines: 3, music: true).terminal == nil,
                     "no line of activities to stay under, no readout")
    }

    private static func configuration(_ suite: TestSuite) {
        suite.expect(Defaults.registeredDefaults[DefaultsKey.notchLockScreenTerminal] as? Bool == false,
                     "the readout starts off")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.notchLockScreenTerminalProjects] as? Bool == false,
                     "project names start hidden")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.notchLockScreenTerminalLines] as? String == Selection.defaultValue,
                     "the lines start in the default order")
        let defaults = UserDefaults(suiteName: "com.vorssaint.tests.lockscreen-terminal")!
        defaults.removePersistentDomain(forName: "com.vorssaint.tests.lockscreen-terminal")
        defaults.set(true, forKey: DefaultsKey.notchLockScreenTerminal)
        suite.expect(!Support.isEnabled(in: defaults), "the readout needs the lock screen itself on")
        defaults.removePersistentDomain(forName: "com.vorssaint.tests.lockscreen-terminal")
    }

    /// The title bar's name: the default until one is chosen, then the
    /// chosen one on one short line.
    private static func title(_ suite: TestSuite) {
        suite.expect(Defaults.registeredDefaults[DefaultsKey.notchLockScreenTerminalTitle] as? String == "",
                     "the title starts empty, which is the default")
        suite.expect(Support.title(nil) == "zenith — status" && Support.title("") == Support.defaultTitle
                     && Support.title("   \n\t ") == Support.defaultTitle,
                     "an empty or blank title is the default")
        suite.expect(Support.title("  build box  ") == "build box", "a title is trimmed")
        suite.expect(Support.title("dev\nbox\r\nstatus") == "dev box status"
                     && Support.title("a\u{2028}b\tc") == "a b c" && Support.title("a   b") == "a b",
                     "line breaks, tabs and runs of spaces close up into one line")
        let long = String(repeating: "x", count: 50)
        suite.expect(Support.title(long).count == Support.maximumTitleLength && Support.maximumTitleLength == 32,
                     "a title is capped at 32 characters")
        suite.expect(Support.title("👩‍💻 macbook — status") == "👩‍💻 macbook — status",
                     "an emoji sequence and the em dash survive the clean-up")
        suite.expect(Support.title(" " + String(repeating: "y", count: 40)).count == Support.maximumTitleLength,
                     "a leading space does not count against the cap once trimmed")

        suite.expect(Support.titleInput("one\ntwo") == "one two" && Support.titleInput("tab\there") == "tab here",
                     "typing keeps the title on one line")
        suite.expect(Support.titleInput("trailing ") == "trailing ",
                     "a space being typed at the end stays in the field")
        suite.expect(Support.titleInput(long).count == Support.maximumTitleLength
                     && Support.titleInput(long) == String(repeating: "x", count: 32),
                     "the field stops at the cap")
        suite.expect(Support.titleInput("e\u{301}t\u{E9}") == "e\u{301}t\u{E9}",
                     "combining marks are kept")

        suite.expect(Support.computerTitle("Faiz’s MacBook Air") == "Faiz’s MacBook Air — status",
                     "this Mac's name takes the shape <name> — status")
        suite.expect(Support.computerTitle(nil) == nil && Support.computerTitle("  \n ") == nil,
                     "no name, no suggestion")
        suite.expect(Support.computerTitle("  Studio\n Mac ") == "Studio Mac — status",
                     "the name is put on one line first")
        let named = Support.computerTitle("A Very Long Computer Name For A Mac Studio")
        suite.expect(named.map { $0.count == Support.maximumTitleLength && $0.hasSuffix("… — status") } == true,
                     "a long name is shortened so the whole stays within the cap and still ends in — status")
        suite.expect(named.map { Support.title($0) == $0 } == true,
                     "a suggested title survives the readout's own clean-up")
        let exact = String(repeating: "m", count: Support.maximumTitleLength - Support.titleSuffix.count)
        suite.expect(Support.computerTitle(exact) == exact + " — status",
                     "a name that just fits is kept whole")

        let defaults = UserDefaults(suiteName: "com.vorssaint.tests.lockscreen-terminal-title")!
        defaults.removePersistentDomain(forName: "com.vorssaint.tests.lockscreen-terminal-title")
        suite.expect(Support.title(in: defaults) == Support.defaultTitle, "nothing stored, the default")
        defaults.set(" ci\nbox ", forKey: DefaultsKey.notchLockScreenTerminalTitle)
        suite.expect(Support.title(in: defaults) == "ci box", "a stored title is read cleaned up")
        defaults.removePersistentDomain(forName: "com.vorssaint.tests.lockscreen-terminal-title")
        suite.expect(NotchLockScreenTerminalConfiguration(sources: [.sys], showsProjects: false).title == Support.defaultTitle,
                     "a configuration without a title reads as the default")

        suite.expect(AppLanguage.allCases.allSatisfy { language in
            let text = ZenithStrings.lockScreenTerminalTitle(language)
            return [text.windowTitle, text.caption, text.useComputerName]
                .allSatisfy { !$0.isEmpty && !$0.contains("'") && !$0.contains("\u{2014}") }
        }, "every language names the title field and its button, with curly apostrophes")
    }
}
