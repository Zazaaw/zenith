// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: coding time from WakaTime, in the notch and the menu panel.
///
/// WakaTime only lets an API key (the one editor plugins keep in
/// `~/.wakatime.cfg`) read today's status bar summary; summaries, stats and
/// durations need an OAuth token. Zenith therefore reads today from WakaTime and
/// keeps the last seven days itself, one total per day it saw.
enum WakaTimeSupport {
    static let defaultAPIURL = URL(string: "https://api.wakatime.com/api/v1")!
    static let historyDays = 7
    /// How long a fetched summary stays fresh before a visible view asks again.
    static let refreshInterval: TimeInterval = 5 * 60

    struct Configuration: Equatable {
        let apiKey: String
        let apiURL: URL
    }

    struct Entry: Equatable, Identifiable {
        let name: String
        let seconds: Double
        var id: String { name }
    }

    struct Today: Equatable {
        let date: String
        let totalSeconds: Double
        let projects: [Entry]
        let languages: [Entry]
    }

    struct Day: Equatable, Identifiable {
        let date: String
        let seconds: Double
        let isToday: Bool
        var id: String { date }
    }

    // MARK: Configuration

    static func configURL(home: URL = FileManager.default.homeDirectoryForCurrentUser,
                          environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        if let custom = environment["WAKATIME_HOME"], custom.hasPrefix("/") {
            return URL(fileURLWithPath: custom, isDirectory: true).appendingPathComponent(".wakatime.cfg")
        }
        return home.appendingPathComponent(".wakatime.cfg")
    }

    /// `api_key` and `api_url` from the `[settings]` section of the INI file
    /// WakaTime's plugins share. nil without a key.
    static func configuration(from text: String) -> Configuration? {
        var section = ""
        var values: [String: String] = [:]
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") || line.hasPrefix(";") { continue }
            if line.hasPrefix("["), line.hasSuffix("]") {
                section = line.dropFirst().dropLast().trimmingCharacters(in: .whitespaces).lowercased()
                continue
            }
            guard section == "settings", let equals = line.firstIndex(of: "=") else { continue }
            let key = line[..<equals].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: equals)...].trimmingCharacters(in: .whitespaces)
            values[key] = value
        }
        guard let key = values["api_key"], !key.isEmpty else { return nil }
        let url = values["api_url"].flatMap { URL(string: $0) }.flatMap { $0.scheme == "https" ? $0 : nil }
        return Configuration(apiKey: key, apiURL: url ?? defaultAPIURL)
    }

    static func loadConfiguration(at url: URL = configURL()) -> Configuration? {
        (try? String(contentsOf: url, encoding: .utf8)).flatMap(configuration(from:))
    }

    /// Whether this Mac has a WakaTime key to read with. Cheap enough for the
    /// island's section list: a file check, not a read.
    static func hasConfiguration(at url: URL = configURL()) -> Bool {
        FileManager.default.isReadableFile(atPath: url.path)
    }

    // MARK: Requests

    static func todayRequest(_ configuration: Configuration, userAgent: String) -> URLRequest {
        var request = URLRequest(url: configuration.apiURL.appendingPathComponent("users/current/status_bar/today"))
        let token = Data(configuration.apiKey.utf8).base64EncodedString()
        request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        return request
    }

    /// Today's summary from a `status_bar/today` response, biggest first.
    static func today(from data: Data) -> Today? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let body = root["data"] as? [String: Any],
              let total = body["grand_total"] as? [String: Any] else { return nil }
        let date = (body["range"] as? [String: Any])?["date"] as? String ?? ""
        func entries(_ key: String) -> [Entry] {
            ((body[key] as? [[String: Any]]) ?? [])
                .compactMap { item in
                    guard let name = item["name"] as? String, let seconds = number(item["total_seconds"]),
                          seconds > 0 else { return nil }
                    return Entry(name: name, seconds: seconds)
                }
                .sorted { $0.seconds > $1.seconds }
        }
        return Today(date: date, totalSeconds: number(total["total_seconds"]) ?? 0,
                     projects: entries("projects"), languages: entries("languages"))
    }

    private static func number(_ value: Any?) -> Double? {
        (value as? Double) ?? (value as? Int).map(Double.init) ?? (value as? NSNumber)?.doubleValue
    }

    // MARK: History

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Records a day's total and forgets anything older than the window.
    static func recording(_ seconds: Double, for date: Date, in history: [String: Double],
                          calendar: Calendar = .current) -> [String: Double] {
        var history = history
        let key = dayKey(date, calendar: calendar)
        history[key] = max(0, seconds)
        // Days after the one recorded stay: an older date (a clock set back)
        // must not wipe out today. Keys sort as dates.
        let keep = Set(window(ending: date, calendar: calendar))
        return history.filter { keep.contains($0.key) || $0.key > key }
    }

    /// The last seven days, oldest first, today last. Days without a total read 0.
    static func lastDays(_ history: [String: Double], today: Date, calendar: Calendar = .current) -> [Day] {
        let keys = window(ending: today, calendar: calendar)
        return keys.map { Day(date: $0, seconds: history[$0] ?? 0, isToday: $0 == keys.last) }
    }

    private static func window(ending date: Date, calendar: Calendar) -> [String] {
        (0..<historyDays).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: date).map { dayKey($0, calendar: calendar) }
        }
    }

    // MARK: Formatting

    /// "3h 12m", "45m" or "0m", in the app language's own units.
    static func duration(_ seconds: Double, locale: Locale) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds >= 3600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropLeading
        var calendar = Calendar.current
        calendar.locale = locale
        formatter.calendar = calendar
        return formatter.string(from: max(0, seconds)) ?? "0m"
    }

    /// A one-letter weekday for a `yyyy-MM-dd` key, in the app language.
    static func weekdayInitial(_ key: String, locale: Locale) -> String {
        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .gregorian)
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: key) else { return "" }
        let out = DateFormatter()
        out.locale = locale
        out.setLocalizedDateFormatFromTemplate("EEEEE")
        return out.string(from: date)
    }
}
