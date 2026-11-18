// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: today's coding time from WakaTime, plus the days Zenith has seen.
///
/// Nothing runs in the background. A view that shows WakaTime asks for a
/// refresh when it appears, and while one is visible the summary refreshes every
/// `WakaTimeSupport.refreshInterval`. The API key never leaves the request to
/// WakaTime's own server (or the `api_url` in `~/.wakatime.cfg`).
@MainActor
final class WakaTimeService: ObservableObject {
    static let shared = WakaTimeService()

    enum State: Equatable {
        case idle, loading, ready, missingKey, failed
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var today: WakaTimeSupport.Today?
    @Published private(set) var history: [String: Double]

    /// One total per day seen, kept on this Mac only (not part of settings backups).
    static let historyKey = "zenithWakaTimeHistory"

    private var lastFetch: Date?
    private var request: Task<Void, Never>?
    private var timer: Timer?
    private var viewers = 0

    private init() {
        let stored = UserDefaults.standard.dictionary(forKey: Self.historyKey) ?? [:]
        history = stored.compactMapValues { ($0 as? Double) ?? ($0 as? NSNumber)?.doubleValue }
    }

    /// The last seven days, today last.
    var days: [WakaTimeSupport.Day] {
        WakaTimeSupport.lastDays(history, today: Date())
    }

    func viewAppeared() {
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
        if state == .ready, let lastFetch,
           Date().timeIntervalSince(lastFetch) < WakaTimeSupport.refreshInterval { return }
        refresh()
    }

    func refresh() {
        guard request == nil else { return }
        guard let configuration = WakaTimeSupport.loadConfiguration() else {
            state = .missingKey
            return
        }
        if today == nil { state = .loading }
        let urlRequest = WakaTimeSupport.todayRequest(configuration,
                                                      userAgent: "\(AppInfo.name)/\(AppInfo.version)")
        request = Task { [weak self] in
            let result = try? await URLSession.shared.data(for: urlRequest)
            guard let self else { return }
            self.request = nil
            self.lastFetch = Date()
            guard let (data, response) = result,
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let today = WakaTimeSupport.today(from: data) else {
                // Keep showing the last good summary; say so only when there is none.
                if self.today == nil { self.state = .failed }
                return
            }
            self.today = today
            self.history = WakaTimeSupport.recording(today.totalSeconds, for: Date(), in: self.history)
            UserDefaults.standard.set(self.history, forKey: Self.historyKey)
            self.state = .ready
        }
    }
}
