// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: WakaTime config, today's summary and the seven-day window.
enum WakaTimeTests {
    static func run(_ suite: TestSuite) {
        configuration(suite)
        today(suite)
        history(suite)
        formatting(suite)
        token(suite)
    }

    /// What a personal token unlocks: ranges, daily summaries and the last heartbeat.
    private static func token(_ suite: TestSuite) {
        let config = WakaTimeSupport.Configuration(apiKey: "abc", apiURL: WakaTimeSupport.defaultAPIURL)
        suite.expect(WakaTimeSupport.authorization(token: " waka_tok_xyz \n", configuration: config) == "Bearer waka_tok_xyz"
                     && WakaTimeSupport.authorization(token: nil, configuration: config) == "Basic YWJj"
                     && WakaTimeSupport.authorization(token: "", configuration: nil) == nil,
                     "a personal token goes as Bearer, else the plugin key as Basic, else nothing")
        suite.expect(WakaTimeSupport.isPersonalToken("waka_tok_123") && !WakaTimeSupport.isPersonalToken("waka_123"),
                     "only waka_tok_ values are personal tokens")
        let request = WakaTimeSupport.request("users/current/summaries?range=last_7_days", base: WakaTimeSupport.tokenAPIURL,
                                              authorization: "Bearer t", userAgent: "Zenith/1")
        suite.expect(request.url?.absoluteString == "https://wakatime.com/api/v1/users/current/summaries?range=last_7_days",
                     "paths keep their query")

        let user = """
            {"data": {"last_heartbeat_at": "2026-11-19T01:00:00.123Z", "last_project": "zenith",
            "last_language": "Swift", "last_plugin": "wakatime/v2 (darwin) claude-code/2.1 vscode/1.1",
            "last_plugin_name": "vscode"}}
            """
        let presence = WakaTimeSupport.presence(from: Data(user.utf8))
        let heartbeat = WakaTimeSupport.date(from: "2026-11-19T01:00:00.123Z")!
        suite.expect(presence?.project == "zenith" && presence?.language == "Swift" && presence?.editor == "Claude Code"
                     && presence?.lastHeartbeat == heartbeat,
                     "the last heartbeat gives project, language and a readable editor")
        suite.expect(presence?.isCoding(at: heartbeat.addingTimeInterval(14 * 60)) == true
                     && presence?.isCoding(at: heartbeat.addingTimeInterval(16 * 60)) == false,
                     "coding now means a heartbeat in the last fifteen minutes")
        suite.expect(WakaTimeSupport.editor(plugin: nil, name: "vscode") == "VS Code"
                     && WakaTimeSupport.editor(plugin: "", name: "sublime") == "Sublime",
                     "a plugin name alone still reads as an editor")

        suite.expect(WakaTimeSupport.stats(from: Data(#"{"data": {"is_up_to_date": false}}"#.utf8)) == .pending,
                     "a range WakaTime is still building says so instead of zero")
        let statsJSON = """
            {"data": {"is_up_to_date": true, "total_seconds": 72000, "daily_average": 10285,
            "best_day": {"date": "2026-11-15", "total_seconds": 21600},
            "projects": [{"name": "zenith", "total_seconds": 40000, "percent": 55.5}],
            "languages": [{"name": "Swift", "percent": 60, "total_seconds": 43200},
                          {"name": "Go", "percent": 0.2, "total_seconds": 144},
                          {"name": "TS", "percent": 39.8, "total_seconds": 28656}]}}
            """
        guard case .ready(let stats)? = WakaTimeSupport.stats(from: Data(statsJSON.utf8)) else {
            suite.expect(false, "a finished range parses"); return
        }
        suite.expect(stats.totalSeconds == 72000 && stats.dailyAverageSeconds == 10285 && stats.bestDay == "2026-11-15"
                     && stats.bestDaySeconds == 21600 && stats.projects.first?.name == "zenith",
                     "a range gives its total, daily average, best day and projects")
        let stacked = WakaTimeSupport.stackedLanguages(stats.languages)
        suite.expect(stacked.map(\.name) == ["Swift", "TS"],
                     "slivers under half a percent leave the language bar")
        let many = (1...7).map { WakaTimeSupport.Share(name: "L\($0)", percent: 10, seconds: 1) }
        let folded = WakaTimeSupport.stackedLanguages(many)
        suite.expect(folded.count == 6 && folded.last?.name == "" && folded.last?.percent == 20,
                     "beyond five languages the rest fold into one share")

        let summaries = """
            {"data": [{"range": {"date": "2026-11-18"}, "grand_total": {"total_seconds": 3600}},
            {"range": {"date": "2026-11-19"}, "grand_total": {"total_seconds": 60}}]}
            """
        let days = WakaTimeSupport.summaryDays(from: Data(summaries.utf8), today: "2026-11-19")
        suite.expect(days?.map(\.seconds) == [3600, 60] && days?.last?.isToday == true && days?.first?.isToday == false,
                     "daily summaries become the chart's days, today marked")
    }

    private static func configuration(_ suite: TestSuite) {
        let plain = WakaTimeSupport.configuration(from: "[settings]\napi_key = waka_123\n")
        suite.expect(plain == .init(apiKey: "waka_123", apiURL: WakaTimeSupport.defaultAPIURL),
                     "a plugin config gives its key and the default API")
        let custom = WakaTimeSupport.configuration(from: """
            ; comment
            [git]
            api_key = not_this_one
            [settings]
            # comment
            API_KEY=waka_456
            api_url = https://wakapi.example.com/api/compat/wakatime/v1
            """)
        suite.expect(custom?.apiKey == "waka_456"
                     && custom?.apiURL.absoluteString == "https://wakapi.example.com/api/compat/wakatime/v1",
                     "only [settings] counts, keys ignore case, and a custom HTTPS server is kept")
        let insecure = WakaTimeSupport.configuration(from: "[settings]\napi_key=k\napi_url=http://example.com/api\n")
        suite.expect(insecure?.apiURL == WakaTimeSupport.defaultAPIURL,
                     "the key is never sent to a plain HTTP server")
        suite.expect(WakaTimeSupport.configuration(from: "[settings]\ndebug = true\n") == nil
                     && WakaTimeSupport.configuration(from: "[settings]\napi_key =\n") == nil,
                     "no key, no configuration")
        let home = URL(fileURLWithPath: "/Users/someone", isDirectory: true)
        suite.expect(WakaTimeSupport.configURL(home: home, environment: [:]).path == "/Users/someone/.wakatime.cfg"
                     && WakaTimeSupport.configURL(home: home, environment: ["WAKATIME_HOME": "/opt/waka"]).path
                        == "/opt/waka/.wakatime.cfg",
                     "the config sits in the home folder unless WAKATIME_HOME moves it")
        let request = WakaTimeSupport.todayRequest(.init(apiKey: "abc", apiURL: WakaTimeSupport.defaultAPIURL),
                                                   userAgent: "Zenith/1")
        suite.expect(request.url?.absoluteString == "https://api.wakatime.com/api/v1/users/current/status_bar/today"
                     && request.value(forHTTPHeaderField: "Authorization") == "Basic YWJj",
                     "today is read from the status bar endpoint with the key as basic auth")
    }

    private static func today(_ suite: TestSuite) {
        let json = """
            {"data": {"grand_total": {"total_seconds": 11520.5, "text": "3 hrs 12 mins"},
              "range": {"date": "2026-11-18"},
              "projects": [{"name": "zenith", "total_seconds": 3600}, {"name": "site", "total_seconds": 7200},
                           {"name": "idle", "total_seconds": 0}],
              "languages": [{"name": "Swift", "total_seconds": 9000}, {"name": "Markdown", "total_seconds": 600}]}}
            """
        let today = WakaTimeSupport.today(from: Data(json.utf8))
        suite.expect(today?.date == "2026-11-18" && today?.totalSeconds == 11520.5,
                     "today's total and date come from grand_total and range")
        suite.expect(today?.projects.map(\.name) == ["site", "zenith"] && today?.languages.first?.name == "Swift",
                     "projects and languages are biggest first, without empty entries")
        suite.expect(WakaTimeSupport.today(from: Data(#"{"error": "API Keys are only for plugins"}"#.utf8)) == nil
                     && WakaTimeSupport.today(from: Data("not json".utf8)) == nil,
                     "an error body or garbage is no summary")
    }

    private static func history(_ suite: TestSuite) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Jakarta")!
        let day = { (offset: Int) in
            calendar.date(byAdding: .day, value: offset, to: calendar.date(from: DateComponents(year: 2026, month: 11, day: 18))!)!
        }
        var history: [String: Double] = ["2026-11-01": 999]
        history = WakaTimeSupport.recording(100, for: day(-2), in: history, calendar: calendar)
        history = WakaTimeSupport.recording(300, for: day(0), in: history, calendar: calendar)
        history = WakaTimeSupport.recording(-5, for: day(-1), in: history, calendar: calendar)
        suite.expect(history == ["2026-11-16": 100, "2026-11-17": 0, "2026-11-18": 300],
                     "recording keeps seven days, drops older totals and never goes negative")
        let days = WakaTimeSupport.lastDays(history, today: day(0), calendar: calendar)
        suite.expect(days.count == 7 && days.first?.date == "2026-11-12" && days.last?.date == "2026-11-18"
                     && days.last?.isToday == true && days.filter(\.isToday).count == 1,
                     "the week runs oldest first and ends today")
        suite.expect(days.map(\.seconds) == [0, 0, 0, 0, 100, 0, 300],
                     "days Zenith never saw read as zero")
    }

    private static func formatting(_ suite: TestSuite) {
        let english = Locale(identifier: "en-US")
        suite.expect(WakaTimeSupport.duration(11520, locale: english) == "3h 12m"
                     && WakaTimeSupport.duration(2700, locale: english) == "45m"
                     && WakaTimeSupport.duration(0, locale: english) == "0m",
                     "durations read as hours and minutes, or minutes alone")
        suite.expect(WakaTimeSupport.weekdayInitial("2026-11-18", locale: english) == "W"
                     && WakaTimeSupport.weekdayInitial("not a date", locale: english).isEmpty,
                     "each bar is labelled with its weekday's initial")
    }
}
