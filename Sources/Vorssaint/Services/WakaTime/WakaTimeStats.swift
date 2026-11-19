// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: what a personal WakaTime token unlocks beyond today's status bar.
///
/// A personal OAuth token (`waka_tok_…`, scope `read_stats`) is sent as a Bearer
/// token and can read ranges, daily summaries and the last heartbeat. The plugin
/// API key in `~/.wakatime.cfg` can only read today.
extension WakaTimeSupport {
    /// Ranges WakaTime computes stats for, plus today from the status bar.
    enum Range: String, CaseIterable, Identifiable {
        case today
        case week = "last_7_days"
        case month = "last_30_days"
        case year = "last_year"
        case allTime = "all_time"

        var id: String { rawValue }

        /// Ranges with one bar per day in the chart.
        var summaryRange: String? {
            switch self {
            case .today, .week: return Range.week.rawValue
            case .month: return Range.month.rawValue
            case .year, .allTime: return nil
            }
        }
    }

    static let tokenAPIURL = URL(string: "https://wakatime.com/api/v1")!
    /// A heartbeat this recent means someone is coding right now.
    static let activeWindow: TimeInterval = 15 * 60

    static func isPersonalToken(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("waka_tok_")
    }

    /// Bearer for a personal token, otherwise Basic with the plugin API key.
    static func authorization(token: String?, configuration: Configuration?) -> String? {
        if let token = token?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty {
            return "Bearer \(token)"
        }
        guard let configuration else { return nil }
        return "Basic \(Data(configuration.apiKey.utf8).base64EncodedString())"
    }

    static func request(_ path: String, base: URL, authorization: String, userAgent: String) -> URLRequest {
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)!
        let parts = path.split(separator: "?", maxSplits: 1).map(String.init)
        components.path += (components.path.hasSuffix("/") ? "" : "/") + parts[0]
        if parts.count > 1 { components.percentEncodedQuery = parts[1] }
        var request = URLRequest(url: components.url!)
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        return request
    }

    // MARK: Presence

    struct Presence: Equatable {
        let lastHeartbeat: Date?
        let project: String?
        let language: String?
        let editor: String?

        func isCoding(at now: Date) -> Bool {
            guard let lastHeartbeat else { return false }
            return now.timeIntervalSince(lastHeartbeat) < WakaTimeSupport.activeWindow
        }
    }

    /// The last heartbeat from `/users/current`.
    static func presence(from data: Data) -> Presence? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let user = root["data"] as? [String: Any] else { return nil }
        return Presence(lastHeartbeat: (user["last_heartbeat_at"] as? String).flatMap(date(from:)),
                        project: nonEmpty(user["last_project"]),
                        language: nonEmpty(user["last_language"]),
                        editor: editor(plugin: user["last_plugin"] as? String,
                                       name: user["last_plugin_name"] as? String))
    }

    /// A readable editor from WakaTime's plugin string, as the portfolio reads it.
    static func editor(plugin: String?, name: String?) -> String? {
        let plugin = (plugin ?? "").lowercased()
        let known: [(String, String)] = [("claude-code/", "Claude Code"), ("cursor/", "Cursor"), ("codex", "Codex"),
                                         ("zed/", "Zed"), ("xcode/", "Xcode"), ("vscode/", "VS Code")]
        if let match = known.first(where: { plugin.contains($0.0) }) { return match.1 }
        guard let name, !name.isEmpty else { return nil }
        return name == "vscode" ? "VS Code" : name.prefix(1).uppercased() + name.dropFirst()
    }

    // MARK: Stats

    struct Share: Equatable, Identifiable {
        let name: String
        let percent: Double
        let seconds: Double
        var id: String { name }
    }

    struct Stats: Equatable {
        let totalSeconds: Double
        let dailyAverageSeconds: Double
        let bestDay: String?
        let bestDaySeconds: Double
        let projects: [Share]
        let languages: [Share]
    }

    enum StatsResult: Equatable {
        case ready(Stats)
        /// WakaTime is still computing a range it has not built before.
        case pending
    }

    static func stats(from data: Data) -> StatsResult? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let body = root["data"] as? [String: Any] else { return nil }
        if body["is_up_to_date"] as? Bool == false { return .pending }
        func shares(_ key: String) -> [Share] {
            ((body[key] as? [[String: Any]]) ?? []).compactMap { item in
                guard let name = item["name"] as? String else { return nil }
                return Share(name: name, percent: number(item["percent"]) ?? 0,
                             seconds: number(item["total_seconds"]) ?? 0)
            }
            .filter { $0.seconds > 0 || $0.percent > 0 }
        }
        let best = body["best_day"] as? [String: Any]
        return .ready(Stats(totalSeconds: number(body["total_seconds"]) ?? 0,
                            dailyAverageSeconds: number(body["daily_average"]) ?? 0,
                            bestDay: best?["date"] as? String,
                            bestDaySeconds: number(best?["total_seconds"]) ?? 0,
                            projects: shares("projects"), languages: shares("languages")))
    }

    /// One total per day from `/users/current/summaries`, oldest first.
    static func summaryDays(from data: Data, today: String) -> [Day]? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let days = root["data"] as? [[String: Any]] else { return nil }
        return days.compactMap { day in
            guard let date = (day["range"] as? [String: Any])?["date"] as? String else { return nil }
            let seconds = number((day["grand_total"] as? [String: Any])?["total_seconds"]) ?? 0
            return Day(date: date, seconds: seconds, isToday: date == today)
        }
    }

    /// Languages for the stacked bar: the leaders, then the rest folded into one.
    static func stackedLanguages(_ languages: [Share], limit: Int = 5) -> [Share] {
        let visible = languages.filter { $0.percent >= 0.5 }
        let leaders = Array(visible.prefix(limit))
        let rest = visible.dropFirst(limit).reduce(0) { $0 + $1.percent }
        return rest > 0 ? leaders + [Share(name: "", percent: rest, seconds: 0)] : leaders
    }

    // MARK: Daily goal

    /// Goals offered in Settings, in minutes; 0 is off.
    static let goalChoices = [0, 60, 120, 180, 240, 300, 360, 480]

    /// Share of the goal done today, capped at 1; nil without a goal.
    static func goalProgress(totalSeconds: Double, goalMinutes: Int) -> Double? {
        guard goalMinutes > 0 else { return nil }
        return min(1, max(0, totalSeconds) / Double(goalMinutes * 60))
    }

    static func goalReached(totalSeconds: Double, goalMinutes: Int) -> Bool {
        goalMinutes > 0 && totalSeconds >= Double(goalMinutes * 60)
    }

    // MARK: Helpers

    private static func number(_ value: Any?) -> Double? {
        (value as? Double) ?? (value as? Int).map(Double.init) ?? (value as? NSNumber)?.doubleValue
    }

    private static func nonEmpty(_ value: Any?) -> String? {
        guard let text = value as? String, !text.isEmpty else { return nil }
        return text
    }

    static func date(from text: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }
}
