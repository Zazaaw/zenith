// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: coding time from WakaTime.
///
/// With a personal token (Keychain) it reads ranges, daily summaries and whether
/// someone is coding right now. With only the plugin key in `~/.wakatime.cfg` it
/// reads today and keeps its own seven-day history.
///
/// Nothing runs in the background. A visible WakaTime view asks for a refresh
/// when it appears, and refreshes every `WakaTimeSupport.refreshInterval` while
/// shown. Credentials only travel to WakaTime (or the `api_url` the config names).
@MainActor
final class WakaTimeService: ObservableObject {
    static let shared = WakaTimeService()

    enum State: Equatable {
        case idle, loading, ready, missingKey, failed
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var today: WakaTimeSupport.Today?
    @Published private(set) var history: [String: Double]
    @Published private(set) var hasToken: Bool
    @Published private(set) var range: WakaTimeSupport.Range
    @Published private(set) var presence: WakaTimeSupport.Presence?
    @Published private(set) var stats: WakaTimeSupport.StatsResult?
    @Published private(set) var summaryDays: [WakaTimeSupport.Day] = []

    /// One total per day seen, kept on this Mac only (not part of settings backups).
    static let historyKey = "zenithWakaTimeHistory"
    static let rangeKey = "zenithWakaTimeRange"
    /// The day the goal notification last went out, so it comes once a day.
    static let goalNotifiedKey = "zenithWakaTimeGoalNotifiedDay"

    private var lastFetch: Date?
    private var request: Task<Void, Never>?
    private var timer: Timer?
    private var viewers = 0
    private var token: String?
    private var goalTimer: Timer?

    var goalMinutes: Int { UserDefaults.standard.integer(forKey: DefaultsKey.wakaTimeDailyGoalMinutes) }

    private init() {
        let stored = UserDefaults.standard.dictionary(forKey: Self.historyKey) ?? [:]
        history = stored.compactMapValues { ($0 as? Double) ?? ($0 as? NSNumber)?.doubleValue }
        token = WakaTimeTokenStore.read()
        hasToken = token != nil
        range = (UserDefaults.standard.string(forKey: Self.rangeKey)).flatMap(WakaTimeSupport.Range.init) ?? .today
    }

    /// Bars for the chart, oldest first: WakaTime's own days with a token,
    /// otherwise the days Zenith has seen.
    var days: [WakaTimeSupport.Day] {
        if hasToken, !summaryDays.isEmpty { return summaryDays }
        return WakaTimeSupport.lastDays(history, today: Date())
    }

    /// The range's stats once WakaTime has them.
    var readyStats: WakaTimeSupport.Stats? {
        if case .ready(let stats) = stats { return stats }
        return nil
    }

    // MARK: Token

    @discardableResult
    func saveToken(_ value: String) -> Bool {
        guard WakaTimeTokenStore.save(value) else { return false }
        token = WakaTimeTokenStore.read()
        hasToken = token != nil
        refresh(force: true)
        return hasToken
    }

    func removeToken() {
        WakaTimeTokenStore.delete()
        token = nil
        hasToken = false
        presence = nil
        stats = nil
        summaryDays = []
        if range != .today { select(.today) } else { refresh(force: true) }
    }

    func select(_ range: WakaTimeSupport.Range) {
        guard range != self.range else { return }
        self.range = range
        UserDefaults.standard.set(range.rawValue, forKey: Self.rangeKey)
        stats = nil
        summaryDays = []
        refresh(force: true)
    }

    // MARK: Daily goal

    /// With a goal set, checks every ten minutes so the goal notification is on
    /// time even with no WakaTime view open. Without one, nothing runs.
    func syncGoalMonitoring() {
        goalTimer?.invalidate()
        goalTimer = nil
        guard goalMinutes > 0, hasToken || WakaTimeSupport.hasConfiguration() else { return }
        refreshIfStale()
        let timer = Timer(timeInterval: 10 * 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        timer.tolerance = 60
        RunLoop.main.add(timer, forMode: .common)
        goalTimer = timer
    }

    private func notifyGoalIfReached(_ today: WakaTimeSupport.Today) {
        let day = WakaTimeSupport.dayKey(Date())
        guard WakaTimeSupport.goalReached(totalSeconds: today.totalSeconds, goalMinutes: goalMinutes),
              UserDefaults.standard.string(forKey: Self.goalNotifiedKey) != day else { return }
        UserDefaults.standard.set(day, forKey: Self.goalNotifiedKey)
        let language = L10n.shared.language
        let text = ZenithStrings.wakaTimeGoal(language)
        let total = WakaTimeSupport.duration(today.totalSeconds, locale: Locale(identifier: language.rawValue))
        Notifier.post(title: text.goalReachedTitle, body: text.reachedBody(total))
    }

    // MARK: Refresh

    func viewAppeared() {
#if VORSSAINT_DEVELOPMENT
        // Zenith fork: the island catalog draws sample data only.
        if IslandCatalog.isRendering { return }
#endif
        viewers += 1
        refreshIfStale()
        guard timer == nil else { return }
        let timer = Timer(timeInterval: WakaTimeSupport.refreshInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        timer.tolerance = 30
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func viewDisappeared() {
        viewers = max(0, viewers - 1)
        guard viewers == 0 else { return }
        timer?.invalidate()
        timer = nil
    }

    func refreshIfStale() {
#if VORSSAINT_DEVELOPMENT
        // Zenith fork: the island catalog draws sample data only.
        if IslandCatalog.isRendering { return }
#endif
        if state == .ready, let lastFetch,
           Date().timeIntervalSince(lastFetch) < WakaTimeSupport.refreshInterval { return }
        refresh()
    }

    func refresh(force: Bool = false) {
        if force { request?.cancel(); request = nil }
        guard request == nil else { return }
        let configuration = WakaTimeSupport.loadConfiguration()
        guard let authorization = WakaTimeSupport.authorization(token: token, configuration: configuration) else {
            state = .missingKey
            return
        }
        if today == nil { state = .loading }
        let base = token != nil ? WakaTimeSupport.tokenAPIURL : (configuration?.apiURL ?? WakaTimeSupport.defaultAPIURL)
        let agent = "\(AppInfo.name)/\(AppInfo.version)"
        func make(_ path: String) -> URLRequest {
            WakaTimeSupport.request(path, base: base, authorization: authorization, userAgent: agent)
        }
        let withToken = token != nil
        let todayKey = WakaTimeSupport.dayKey(Date())
        let todayRequest = make("users/current/status_bar/today")
        let userRequest = withToken ? make("users/current") : nil
        let statsRequest = withToken && range != .today ? make("users/current/stats/\(range.rawValue)") : nil
        let daysRequest = withToken ? range.summaryRange.map { make("users/current/summaries?range=\($0)") } : nil
        request = Task { [weak self] in
            async let todayData = Self.fetch(todayRequest)
            async let userData = Self.fetch(userRequest)
            async let statsData = Self.fetch(statsRequest)
            async let daysData = Self.fetch(daysRequest)
            let (todayBody, userBody, statsBody, daysBody) = await (todayData, userData, statsData, daysData)
            guard let self, !Task.isCancelled else { return }
            self.request = nil
            self.lastFetch = Date()
            if let userBody { self.presence = WakaTimeSupport.presence(from: userBody) }
            if let statsBody { self.stats = WakaTimeSupport.stats(from: statsBody) }
            if let daysBody, let days = WakaTimeSupport.summaryDays(from: daysBody, today: todayKey) {
                self.summaryDays = days
            }
            guard let todayBody, let today = WakaTimeSupport.today(from: todayBody) else {
                // Keep showing the last good summary; say so only when there is none.
                if self.today == nil { self.state = .failed }
                return
            }
            self.today = today
            self.notifyGoalIfReached(today)
            self.history = WakaTimeSupport.recording(today.totalSeconds, for: Date(), in: self.history)
            UserDefaults.standard.set(self.history, forKey: Self.historyKey)
            self.state = .ready
        }
    }

    /// The body of a 2xx answer (WakaTime answers 202 while it builds a range).
    private nonisolated static func fetch(_ request: URLRequest?) async -> Data? {
        guard let request, let (data, response) = try? await URLSession.shared.data(for: request),
              let status = (response as? HTTPURLResponse)?.statusCode, (200..<300).contains(status) else { return nil }
        return data
    }
}

#if VORSSAINT_DEVELOPMENT
// Zenith fork: sample state for the island catalog (IslandCatalog,
// `--render-island-catalog`), which draws the island offscreen. Nothing else
// calls this, and the release build does not have it.
extension WakaTimeService {
    func catalogPose(today: WakaTimeSupport.Today?, history: [String: Double]) {
        state = today == nil ? .missingKey : .ready
        self.today = today
        self.history = history
        hasToken = today != nil
        range = .today
        summaryDays = []
        stats = nil
    }
}
#endif
