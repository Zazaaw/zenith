// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: recent Vercel deployments and the build on its way.
///
/// It polls only while a token is saved and the island runs with the Vercel
/// section on, or the lock screen's terminal readout shows its line: every
/// `VercelSupport.buildingInterval` while something builds, every
/// `VercelSupport.idleInterval` otherwise. With failure alerts on and nothing
/// else asking, the same loop reads on in the background at a gentler pace
/// (`VercelSupport.backgroundBuildingInterval`, `backgroundIdleInterval`);
/// every read, whoever asked for it, is checked for failed builds, so alerts
/// never cost a request of their own. The token lives in an owner-only file
/// (`ZenithSecretStore`, never preferences or backups), is read only once the
/// section or the alerts are on (or its page or settings show), and only ever
/// travels to api.vercel.com. Like the island's own services it lives on the
/// main thread; only the requests run elsewhere.
final class VercelService: ObservableObject {
    static let shared = VercelService()

    enum State: Equatable {
        case idle, loading, ready, missingToken, unauthorized, failed
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var deployments: [VercelSupport.Deployment] = []
    /// What the closed island shows, nil when nothing builds or just ended.
    @Published private(set) var activity: VercelSupport.Activity?
    @Published private(set) var hasToken = false

    private var token: String?
    private var tokenLoaded = false
    private var polling = false
    private var request: Task<Void, Never>?
    private var timer: Timer?
    private var resultTimer: Timer?
    private var lastFetch: Date?
    private var lastFailed = false
    private var result: VercelSupport.Deployment?
    private var resultSince: Date?
    /// The lock screen's terminal readout, while it shows the Vercel line.
    private var lockScreenViewers = 0
    /// The island has synced since it last stopped.
    private var islandRunning = false
    /// Polling only for failure alerts, at their gentler pace.
    private var pollsInBackground = false
    /// Failure alerts: the last list read while they are on (nil until the
    /// first, which announces nothing), and the deployments announced so far.
    private var failureBaseline: VercelSupport.FailureBaseline?
    private var notifiedFailures: [String] = []

    /// The token's file in Zenith's private secrets folder (ZenithSecretStore).
    static let secretName = "vercel-token"

    private init() {}

    /// The island runs and shows the Vercel section.
    static func isModuleOn(in defaults: UserDefaults = .standard) -> Bool {
        NotchSupport.isEnabled(in: defaults) && NotchSupport.modules(in: defaults).contains(.vercel)
    }

    static func showsLiveActivity(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: DefaultsKey.notchVercelActivity) as? Bool ?? true
    }

    // MARK: Token

    /// Reads the stored token once, when something first needs it.
    func loadTokenIfNeeded() {
        guard !tokenLoaded else { return }
        tokenLoaded = true
        token = ZenithSecretStore.read(Self.secretName)
        hasToken = token != nil
        if token == nil { state = .missingToken }
    }

    /// Saving a token also turns the section on: pasting one is asking for it.
    @discardableResult
    func saveToken(_ value: String) -> Bool {
        guard ZenithSecretStore.save(value, as: Self.secretName) else { return false }
        tokenLoaded = true
        token = ZenithSecretStore.read(Self.secretName)
        hasToken = token != nil
        guard hasToken else { return false }
        deployments = []
        state = .loading
        // Another token may see other deployments: its first read only sets the baseline.
        failureBaseline = nil
        UserDefaults.standard.set(true, forKey: DefaultsKey.notchVercelEnabled)
        refresh(force: true)
        sync()
        return true
    }

    func removeToken() {
        ZenithSecretStore.delete(Self.secretName)
        tokenLoaded = true
        token = nil
        hasToken = false
        stopPolling()
        polling = false
        pollsInBackground = false
        deployments = []
        result = nil
        resultSince = nil
        failureBaseline = nil
        state = .missingToken
        publishActivity()
    }

    // MARK: Lifecycle

    /// Called with every island preference sync: starts or stops polling.
    func syncWithPreferences() {
        islandRunning = true
        sync()
    }

    /// At launch, and whenever the alerts switch changes: starts or stops
    /// the background reads failure alerts need.
    func syncFailureAlerts() {
        sync()
    }

    /// Polls while the island shows the section or the lock screen shows its
    /// line, at the usual pace; otherwise, with failure alerts on, at theirs.
    private func sync() {
        let shown = (islandRunning && Self.isModuleOn()) || lockScreenViewers > 0
        let alerts = VercelSupport.sendsFailureAlerts()
        // Turned off, the alerts forget their baseline, so turning them on
        // again never announces what failed in between.
        if !alerts { failureBaseline = nil }
        if shown || alerts { loadTokenIfNeeded() }
        let wanted = (shown || alerts) && token != nil
        let background = wanted && !shown
        if wanted != polling || background != pollsInBackground {
            polling = wanted
            pollsInBackground = background
            if !wanted {
                stopPolling()
            } else if isFresh(background: background) {
                // A list read moments ago, as on locking right after a look
                // at the island, waits for its next turn.
                if request == nil { scheduleNext() }
            } else {
                refresh()
            }
        }
        publishActivity()
    }

    /// The lock screen's terminal readout appeared with a Vercel line.
    func lockScreenShown() {
        lockScreenViewers += 1
        sync()
    }

    func lockScreenHidden() {
        guard lockScreenViewers > 0 else { return }
        lockScreenViewers -= 1
        sync()
    }

    /// Read within the last minute, or, in the background, within its own turn.
    private func isFresh(background: Bool = false) -> Bool {
        guard state == .ready, let lastFetch else { return false }
        let limit = background ? VercelSupport.pollInterval(deployments: deployments, failed: false, background: true)
            : VercelSupport.staleAfter
        return Date().timeIntervalSince(lastFetch) < limit
    }

    /// The island stopped. Failure alerts, when on, carry on in the background.
    func stop() {
        islandRunning = false
        sync()
    }

    private func stopPolling() {
        timer?.invalidate()
        timer = nil
        request?.cancel()
        request = nil
    }

    /// The page asks when it appears: a list older than a minute is read
    /// again, even while the section is off (the Settings preview).
    func viewAppeared() {
        loadTokenIfNeeded()
        guard token != nil else { return }
        if isFresh() { return }
        refresh()
    }

    // MARK: Refresh

    func refresh(force: Bool = false) {
        loadTokenIfNeeded()
        if force { request?.cancel(); request = nil }
        guard request == nil else { return }
        guard let token else {
            state = .missingToken
            deployments = []
            publishActivity()
            return
        }
        if deployments.isEmpty { state = .loading }
        timer?.invalidate()
        timer = nil
        let agent = "\(AppInfo.name)/\(AppInfo.version)"
        let started = Date()
        request = Task { @MainActor [weak self] in
            let outcome = await Self.fetch(token: token, userAgent: agent)
            guard let self, !Task.isCancelled else { return }
            self.request = nil
            self.apply(outcome, polledAt: started)
        }
    }

    private func apply(_ outcome: VercelSupport.Outcome, polledAt: Date) {
        lastFetch = Date()
        switch outcome {
        case .ready(let list):
            noteFailures(in: list, polledAt: polledAt)
            // A build seen on its way last time and finished now gets its
            // moment in the closed island.
            let ended = VercelSupport.finished(previous: deployments, current: list)
            if let newest = ended.max(by: { $0.created < $1.created }) {
                result = newest
                resultSince = Date()
                scheduleResultEnd()
            }
            deployments = list
            state = .ready
            lastFailed = false
        case .unauthorized:
            deployments = []
            state = .unauthorized
            lastFailed = true
        case .failed:
            // Keep showing the last good list; say so only when there is none.
            if deployments.isEmpty { state = .failed }
            lastFailed = true
        }
        publishActivity()
        scheduleNext()
    }

    /// A refused token is not asked again until a new one is saved.
    private func scheduleNext() {
        timer?.invalidate()
        timer = nil
        guard polling, state != .unauthorized else { return }
        let interval = VercelSupport.pollInterval(deployments: deployments, failed: lastFailed,
                                                  background: pollsInBackground)
        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            self?.refresh()
        }
        timer.tolerance = interval * 0.1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func scheduleResultEnd() {
        resultTimer?.invalidate()
        let timer = Timer(timeInterval: VercelSupport.resultDuration, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.result = nil
            self.resultSince = nil
            self.publishActivity()
        }
        RunLoop.main.add(timer, forMode: .common)
        resultTimer = timer
    }

    private func publishActivity() {
        // Polling for the lock screen or the alerts alone never feeds the closed island.
        let live = polling && islandRunning && Self.isModuleOn() && Self.showsLiveActivity()
        let next = live ? VercelSupport.activity(deployments: deployments, result: result,
                                                 resultSince: resultSince, now: Date()) : nil
        if next != activity { activity = next }
    }

    // MARK: Failure alerts

    /// Announces the builds that failed since the last read, then keeps this
    /// read as the baseline. With the alerts off nothing is kept.
    private func noteFailures(in list: [VercelSupport.Deployment], polledAt: Date) {
        guard VercelSupport.sendsFailureAlerts() else {
            failureBaseline = nil
            return
        }
        if let baseline = failureBaseline {
            let failed = VercelSupport.failureAlerts(since: baseline, current: list, polledAt: polledAt,
                                                     notified: Set(notifiedFailures))
            notifiedFailures = VercelSupport.remembering(failed.map(\.uid), in: notifiedFailures)
            failed.forEach(postFailure)
        }
        failureBaseline = VercelSupport.failureBaseline(previous: failureBaseline, current: list, polledAt: polledAt)
    }

    /// The project and branch, never the commit message; a click opens the
    /// build log on the dashboard.
    private func postFailure(_ deployment: VercelSupport.Deployment) {
        // The notification center aborts a process without a bundle, such as the bare binary.
        guard Bundle.main.bundleIdentifier != nil else { return }
        let text = ZenithStrings.vercelAlerts(L10n.shared.language)
        Notifier.post(title: text.buildFailed, body: VercelSupport.failureBody(deployment), opening: deployment.openURL)
    }

    // MARK: Network

    /// The teams the token sees, then each scope's latest deployments at once.
    private static func fetch(token: String, userAgent: String) async -> VercelSupport.Outcome {
        let teamsAnswer = await load(VercelSupport.teamsRequest(token: token, userAgent: userAgent))
        let teams = teamsAnswer.data.flatMap(VercelSupport.teams(from:)) ?? []
        let scopes: [VercelSupport.Team?] = [nil] + teams.prefix(VercelSupport.maximumTeams).map { Optional($0) }
        let results = await withTaskGroup(of: (Int, VercelSupport.ScopeResult).self) { group in
            for (index, scope) in scopes.enumerated() {
                group.addTask {
                    let answer = await load(VercelSupport.deploymentsRequest(teamID: scope?.id, token: token,
                                                                             userAgent: userAgent))
                    let list = answer.data.flatMap { VercelSupport.deployments(from: $0, scope: scope?.name) }
                    return (index, VercelSupport.ScopeResult(status: answer.status, deployments: list))
                }
            }
            var collected: [(Int, VercelSupport.ScopeResult)] = []
            for await item in group { collected.append(item) }
            return collected.sorted { $0.0 < $1.0 }.map(\.1)
        }
        // A refused teams list counts too, so a bad token reads as refused.
        return VercelSupport.outcome(results + [VercelSupport.ScopeResult(status: teamsAnswer.status, deployments: nil)])
    }

    /// The status, and the body of a 2xx answer.
    private static func load(_ request: URLRequest) async -> (status: Int?, data: Data?) {
        guard let (data, response) = try? await URLSession.shared.data(for: request) else { return (nil, nil) }
        let status = (response as? HTTPURLResponse)?.statusCode
        let ok = status.map { (200..<300).contains($0) } ?? false
        return (status, ok ? data : nil)
    }
}
