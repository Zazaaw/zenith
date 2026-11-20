// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import Foundation

/// Zenith fork: the end-of-day recap.
///
/// It reads what the island's other services already hold (WakaTime's day,
/// Vercel's last deployments, the GitHub inbox) and the day's tally the local
/// services add to (long commands, card imports, exports, Claude Code turns).
/// The only thing it may ask for itself is one GitHub search for today's
/// commits, through the signed-in `gh`, off the main thread. Vercel is read
/// once more only when nothing read it today and its token exists.
///
/// While the island runs, a single timer waits for the chosen time; at it,
/// once a day, a capsule notice sums the day up with an Open for the Today
/// page. Waking, a clock or time zone change and a new day look again.
/// Like the island's own services it lives on the main thread.
final class RecapService: ObservableObject {
    static let shared = RecapService()

    /// What the local services saw today.
    @Published private(set) var tally: RecapTally
    /// Today's commits from the GitHub search, for `commitsDay` only.
    @Published private(set) var commits: Int?

    private var commitsDay: String?
    /// The last search, answered or not, so a failing `gh` is not run again
    /// on every look at the page.
    private var commitsAsked: (day: String, at: Date)?
    private var commitsTask: Task<Void, Never>?
    private var running = false
    private var timer: Timer?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var viewers = 0
    private var watchesWakaTime = false

    private init() {
        tally = RecapTally.decode(UserDefaults.standard.data(forKey: DefaultsKey.notchRecapTally))
    }

    // MARK: The day's tally (any thread)

    /// A local service saw something the recap counts. Safe from any queue.
    static func record(_ event: RecapEvent) {
        DispatchQueue.main.async { RecapService.shared.apply(event) }
    }

    private func apply(_ event: RecapEvent) {
        let next = tally.recording(event)
        guard next != tally else { return }
        tally = next
        UserDefaults.standard.set(next.encoded, forKey: DefaultsKey.notchRecapTally)
    }

    // MARK: The recap

    /// Today's recap from what every service holds right now.
    func recap(now: Date = Date()) -> Recap {
        let settings = RecapSettings.current()
        let today = RecapSchedule.dayKey(now)
        let inputs = RecapInputs(coding: MainActor.assumeIsolated { WakaTimeService.shared.today },
                                 deployments: VercelService.shared.deployments,
                                 inbox: GitHubService.shared.inbox,
                                 commits: commitsDay == today ? commits : nil,
                                 tally: tally)
        return RecapSupport.aggregate(inputs, sources: settings.sources, now: now)
    }

    /// The shareable text, in the app's language.
    func summaryText(now: Date = Date()) -> String {
        let language = L10n.shared.language
        return RecapFormat.summary(recap(now: now), text: ZenithStrings.recap(language), language: language,
                                   locale: language.formattingLocale(), date: now)
    }

    /// Brings the sources up to date: WakaTime when stale, Vercel once when
    /// nothing read it today, the GitHub inbox by its own page's rule while
    /// its section is on, and today's commits when that count is older than
    /// ten minutes.
    func prepare(now: Date = Date()) {
        let sources = RecapSettings.current().sources
        if sources.contains(.coding) {
            MainActor.assumeIsolated {
                let wakaTime = WakaTimeService.shared
                if wakaTime.hasToken || WakaTimeSupport.hasConfiguration() { wakaTime.refreshIfStale() }
            }
        }
        if sources.contains(.deploys) { readVercelIfUnread(now: now) }
        if sources.contains(.github) { readGitHub(now: now) }
    }

    private func readVercelIfUnread(now: Date) {
        let vercel = VercelService.shared
        if let last = vercel.lastFetch, Calendar.current.isDate(last, inSameDayAs: now) { return }
        vercel.loadTokenIfNeeded()
        guard vercel.hasToken else { return }
        vercel.refresh()
    }

    private func readGitHub(now: Date) {
        guard let executable = GitHubCLI.installed() else { return }
        let github = GitHubService.shared
        // The inbox is read only where its own section already reads it, so
        // the commit search stays the one `gh` run the recap adds.
        if GitHubService.isModuleOn() { github.viewAppeared() }
        let day = RecapSchedule.dayKey(now)
        if let asked = commitsAsked, asked.day == day, now.timeIntervalSince(asked.at) < RecapCommits.staleAfter { return }
        guard commitsTask == nil else { return }
        commitsAsked = (day, now)
        let arguments = RecapCommits.arguments(login: github.inbox?.login, now: now)
        commitsTask = Task { @MainActor [weak self] in
            let count = await Self.readCommits(executable, arguments: arguments)
            guard let self else { return }
            self.commitsTask = nil
            guard let count else { return }
            self.commitsDay = day
            if self.commits != count { self.commits = count }
        }
    }

    private static func readCommits(_ executable: URL, arguments: [String]) async -> Int? {
        await Task.detached(priority: .utility) {
            let result = BoundedProcessRunner.run(executable.path, arguments, timeout: RecapCommits.timeout,
                                                  maxOutputBytes: 1024 * 1024,
                                                  environment: GitHubSupport.environment(for: executable))
            guard result.status == 0, !result.timedOut else { return nil }
            return RecapCommits.count(from: result.output)
        }.value
    }

    // MARK: The Today page and widget

    /// The page or the home widget appeared: WakaTime refreshes while it
    /// shows, and the rest is read as for a recap.
    func viewAppeared() {
        viewers += 1
        if !watchesWakaTime, RecapSettings.current().sources.contains(.coding) {
            watchesWakaTime = MainActor.assumeIsolated {
                let wakaTime = WakaTimeService.shared
                guard wakaTime.hasToken || WakaTimeSupport.hasConfiguration() else { return false }
                wakaTime.viewAppeared()
                return true
            }
        }
        prepare()
    }

    func viewDisappeared() {
        viewers = max(0, viewers - 1)
        guard viewers == 0, watchesWakaTime else { return }
        watchesWakaTime = false
        MainActor.assumeIsolated { WakaTimeService.shared.viewDisappeared() }
    }

    /// Copies the shareable text; the answer says whether it went.
    func copySummary(_ done: @escaping (Bool) -> Void) {
        let text = summaryText()
        GeneralPasteboardAccess.shared.async({
            NSPasteboard.general.clearContents()
            NSPasteboard.general.declareVorssaintSource()
            return NSPasteboard.general.setString(text, forType: .string)
        }, then: done)
    }

    // MARK: Schedule

    /// Called with every island preference sync.
    func syncWithPreferences() {
        running = true
        if observers.isEmpty { observe() }
        schedule()
    }

    /// The recap's settings changed: the timer looks again, if it runs at all.
    func settingsChanged() {
        guard running else { return }
        schedule()
    }

    /// The island stopped.
    func stop() {
        running = false
        timer?.invalidate()
        timer = nil
        observers.forEach { center, token in center.removeObserver(token) }
        observers = []
    }

    private func observe() {
        let workspace = NSWorkspace.shared.notificationCenter
        let local = NotificationCenter.default
        let changes: [(NotificationCenter, Notification.Name)] = [
            (workspace, NSWorkspace.didWakeNotification),
            (local, .NSSystemTimeZoneDidChange),
            (local, .NSSystemClockDidChange),
            (local, .NSCalendarDayChanged),
        ]
        observers = changes.map { center, name in
            (center, center.addObserver(forName: name, object: nil, queue: .main) { _ in
                RecapService.shared.schedule()
            })
        }
    }

    private var lastShown: String? { UserDefaults.standard.string(forKey: DefaultsKey.notchRecapLastShown) }

    private func schedule(now: Date = Date()) {
        timer?.invalidate()
        timer = nil
        guard running,
              let next = RecapSchedule.nextCheck(after: now, settings: .current(), lastShown: lastShown) else { return }
        if next <= now {
            deliver(now: now)
            return
        }
        let timer = Timer(fire: next, interval: 0, repeats: false) { _ in
            RecapService.shared.schedule()
        }
        timer.tolerance = 20
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Marks the day first, so nothing shows it twice, then gives the
    /// sources a few seconds to answer and posts what the day holds. An empty
    /// day posts nothing.
    private func deliver(now: Date) {
        let day = RecapSchedule.dayKey(now)
        UserDefaults.standard.set(day, forKey: DefaultsKey.notchRecapLastShown)
        prepare(now: now)
        schedule(now: now)
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            var waits = 0
            while self?.commitsTask != nil, waits < 30 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                waits += 1
            }
            self?.post(day: day)
        }
    }

    private func post(day: String) {
        guard running else { return }
        let now = Date()
        let recap = recap(now: now)
        guard recap.day == day, !recap.isEmpty else { return }
        let language = L10n.shared.language
        let text = ZenithStrings.recap(language)
        let headline = RecapFormat.headline(recap, text: text, language: language, locale: language.formattingLocale())
        ZenithNoticeCenter.shared.recapReady(day: day, title: text.yourDay, subtitle: headline.joined(separator: " · "))
    }
}
