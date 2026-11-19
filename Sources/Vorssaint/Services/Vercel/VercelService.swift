// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: recent Vercel deployments and the build on its way.
///
/// It polls only while the island runs, the Vercel section is on and a token
/// is saved: every `VercelSupport.buildingInterval` while something builds,
/// every `VercelSupport.idleInterval` otherwise. The token lives in an
/// owner-only file (`ZenithSecretStore`, never preferences or backups), is
/// read only once the section is on (or its page or settings show), and only
/// ever travels to api.vercel.com. Like the island's own services it lives
/// on the main thread; only the requests run elsewhere.
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
        UserDefaults.standard.set(true, forKey: DefaultsKey.notchVercelEnabled)
        refresh(force: true)
        return true
    }

    func removeToken() {
        ZenithSecretStore.delete(Self.secretName)
        tokenLoaded = true
        token = nil
        hasToken = false
        stopPolling()
        polling = false
        deployments = []
        result = nil
        resultSince = nil
        state = .missingToken
        publishActivity()
    }

    // MARK: Lifecycle

    /// Called with every island preference sync: starts or stops polling.
    func syncWithPreferences() {
        let moduleOn = Self.isModuleOn()
        if moduleOn { loadTokenIfNeeded() }
        let wanted = moduleOn && token != nil
        if wanted != polling {
            polling = wanted
            if wanted { refresh() } else { stopPolling() }
        }
        publishActivity()
    }

    func stop() {
        polling = false
        stopPolling()
        publishActivity()
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
        if let lastFetch, state == .ready,
           Date().timeIntervalSince(lastFetch) < VercelSupport.staleAfter { return }
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
        request = Task { @MainActor [weak self] in
            let outcome = await Self.fetch(token: token, userAgent: agent)
            guard let self, !Task.isCancelled else { return }
            self.request = nil
            self.apply(outcome)
        }
    }

    private func apply(_ outcome: VercelSupport.Outcome) {
        lastFetch = Date()
        switch outcome {
        case .ready(let list):
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
        let interval = VercelSupport.pollInterval(deployments: deployments, failed: lastFailed)
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
        let live = polling && Self.showsLiveActivity()
        let next = live ? VercelSupport.activity(deployments: deployments, result: result,
                                                 resultSince: resultSince, now: Date()) : nil
        if next != activity { activity = next }
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
