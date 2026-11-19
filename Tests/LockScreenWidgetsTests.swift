// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreLocation
import EventKit
import Foundation

/// Zenith fork: the lock screen's weather and reminders. Nothing here asks for
/// a permission, reads Location Services or Reminders, or touches the network.
enum LockScreenWidgetsTests {
    static func run(_ suite: TestSuite) {
        weatherSymbols(suite)
        temperatures(suite)
        forecastRequest(suite)
        forecastResponse(suite)
        freshness(suite)
        reminderItems(suite)
        reminderSelection(suite)
        access(suite)
        line(suite)
        configuration(suite)
    }

    private static func weatherSymbols(_ suite: TestSuite) {
        suite.expect(WeatherSupport.symbol(code: 0, isDay: true) == "sun.max.fill"
                     && WeatherSupport.symbol(code: 0, isDay: false) == "moon.stars.fill"
                     && WeatherSupport.symbol(code: 2, isDay: true) == "cloud.sun.fill"
                     && WeatherSupport.symbol(code: 2, isDay: false) == "cloud.moon.fill",
                     "clear and partly cloudy skies have day and night symbols")
        let shared: [(Int, String)] = [
            (3, "cloud.fill"), (45, "cloud.fog.fill"), (48, "cloud.fog.fill"), (53, "cloud.drizzle.fill"),
            (57, "cloud.sleet.fill"), (67, "cloud.sleet.fill"), (61, "cloud.rain.fill"), (65, "cloud.heavyrain.fill"),
            (82, "cloud.heavyrain.fill"), (73, "cloud.snow.fill"), (86, "cloud.snow.fill"),
            (95, "cloud.bolt.rain.fill"), (99, "cloud.bolt.rain.fill"),
        ]
        suite.expect(shared.allSatisfy { code, symbol in
            WeatherSupport.symbol(code: code, isDay: true) == symbol && WeatherSupport.symbol(code: code, isDay: false) == symbol
        }, "overcast, fog, drizzle, rain, sleet, snow and storms read the same day and night")
        suite.expect(WeatherSupport.symbol(code: 80, isDay: true) == "cloud.sun.rain.fill"
                     && WeatherSupport.symbol(code: 81, isDay: false) == "cloud.moon.rain.fill",
                     "showers have day and night symbols")
        suite.expect(WeatherSupport.symbol(code: -1, isDay: true) == "cloud.fill"
                     && WeatherSupport.symbol(code: 4, isDay: false) == "cloud.fill",
                     "an unknown code reads as cloud, never as sun")
        suite.expect((0...99).allSatisfy { !WeatherSupport.symbol(code: $0, isDay: false).contains("sun") },
                     "no sun at night")
    }

    private static func temperatures(_ suite: TestSuite) {
        suite.expect(WeatherSupport.convert(0, to: .fahrenheit) == 32 && WeatherSupport.convert(100, to: .fahrenheit) == 212
                     && WeatherSupport.convert(-40, to: .fahrenheit) == -40 && WeatherSupport.convert(21.5, to: .celsius) == 21.5,
                     "Celsius converts to Fahrenheit, and stays as it is otherwise")
        suite.expect(WeatherSupport.degrees(31.4, unit: .celsius) == "31°" && WeatherSupport.degrees(31.5, unit: .celsius) == "32°"
                     && WeatherSupport.degrees(30, unit: .fahrenheit) == "86°" && WeatherSupport.degrees(-7.6, unit: .celsius) == "-8°",
                     "temperatures read in whole degrees in the chosen unit")
        suite.expect(WeatherSupport.degrees(-0.3, unit: .celsius) == "0°" && WeatherSupport.degrees(.nan, unit: .celsius) == "–°",
                     "never minus zero, and a dash for a broken value")
    }

    private static func forecastRequest(_ suite: TestSuite) {
        let jakarta = WeatherSupport.Coordinate(latitude: -6.208_812, longitude: 106.845_599)
        suite.expect(WeatherSupport.coarse(jakarta) == WeatherSupport.Coordinate(latitude: -6.21, longitude: 106.85),
                     "the position is rounded to two decimals, about a kilometre")
        let url = WeatherSupport.forecastURL(for: jakarta)
        let components = url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
        let query = Dictionary(uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        suite.expect(components?.scheme == "https" && components?.host == "api.open-meteo.com"
                     && components?.path == "/v1/forecast",
                     "the forecast comes from Open-Meteo over HTTPS")
        suite.expect(query["latitude"] == "-6.21" && query["longitude"] == "106.85",
                     "only the rounded position is sent")
        suite.expect(query["current"] == "temperature_2m,weather_code,is_day"
                     && query["daily"] == "temperature_2m_max,temperature_2m_min"
                     && query["timezone"] == "auto" && query["forecast_days"] == "1"
                     && query["temperature_unit"] == nil,
                     "it asks for now and today in Celsius, nothing more")
        suite.expect(WeatherSupport.forecastURL(for: .init(latitude: 91, longitude: 0)) == nil
                     && WeatherSupport.forecastURL(for: .init(latitude: .nan, longitude: 10)) == nil
                     && WeatherSupport.forecastURL(for: .init(latitude: 10, longitude: -181)) == nil,
                     "an impossible position is never sent")
    }

    private static func forecastResponse(_ suite: TestSuite) {
        let fetched = Date(timeIntervalSince1970: 1_800_000_000)
        let body = """
            {"latitude":-6.25,"longitude":106.875,"timezone":"Asia/Jakarta",
             "current":{"time":"2026-11-19T10:00","interval":900,"temperature_2m":31.2,"weather_code":2,"is_day":1},
             "daily":{"time":["2026-11-19"],"temperature_2m_max":[33.1],"temperature_2m_min":[24.0]}}
            """
        let snapshot = WeatherSupport.snapshot(from: Data(body.utf8), fetched: fetched)
        suite.expect(snapshot == WeatherSupport.Snapshot(temperature: 31.2, code: 2, isDay: true, high: 33.1, low: 24,
                                                         fetched: fetched),
                     "Open-Meteo's answer gives now, the sky, day or night and today's range")
        let night = """
            {"current":{"temperature_2m":-3.5,"weather_code":71,"is_day":0}}
            """
        let nightSnapshot = WeatherSupport.snapshot(from: Data(night.utf8), fetched: fetched)
        suite.expect(nightSnapshot?.isDay == false && nightSnapshot?.high == nil && nightSnapshot?.low == nil
                     && nightSnapshot?.code == 71,
                     "without today's range, the temperature still shows")
        let missing = """
            {"current":{"temperature_2m":12},"daily":{"temperature_2m_max":[null],"temperature_2m_min":[]}}
            """
        suite.expect(WeatherSupport.snapshot(from: Data(missing.utf8), fetched: fetched) == nil
                     && WeatherSupport.snapshot(from: Data("{\"error\":true,\"reason\":\"x\"}".utf8), fetched: fetched) == nil
                     && WeatherSupport.snapshot(from: Data("not json".utf8), fetched: fetched) == nil,
                     "an incomplete answer or an error shows nothing")
    }

    private static func freshness(_ suite: TestSuite) {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func snapshot(_ age: TimeInterval) -> WeatherSupport.Snapshot {
            .init(temperature: 20, code: 0, isDay: true, high: nil, low: nil, fetched: now.addingTimeInterval(-age))
        }
        suite.expect(!WeatherSupport.isFresh(nil, now: now) && WeatherSupport.isFresh(snapshot(29 * 60), now: now)
                     && !WeatherSupport.isFresh(snapshot(31 * 60), now: now),
                     "showing the lock screen reads again only after 30 minutes")
        suite.expect(WeatherSupport.isShowable(snapshot(2 * 3600), now: now)
                     && !WeatherSupport.isShowable(snapshot(4 * 3600), now: now)
                     && !WeatherSupport.isShowable(snapshot(-3600), now: now) && !WeatherSupport.isShowable(nil, now: now),
                     "weather older than three hours, or from the future, is not shown")
        suite.expect(WeatherSupport.isLocationFresh(fixed: now.addingTimeInterval(-59 * 60), now: now)
                     && !WeatherSupport.isLocationFresh(fixed: now.addingTimeInterval(-61 * 60), now: now),
                     "a position is reused for an hour")
        suite.expect(WeatherSupport.refreshInterval == 30 * 60, "the lock screen reads the weather every 30 minutes")
    }

    private static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private static func date(_ day: Int, _ hour: Int = 0, _ minute: Int = 0, month: Int = 11) -> Date {
        utc.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    private static func reminderItems(_ suite: TestSuite) {
        let calendar = utc
        let dayOnly = DateComponents(year: 2026, month: 11, day: 19)
        let timed = DateComponents(year: 2026, month: 11, day: 19, hour: 15, minute: 30)
        suite.expect(RemindersSupport.item(id: "a", title: "  Buy milk \n", due: dayOnly, completed: false, calendar: calendar)
                        == .init(id: "a", title: "Buy milk", due: date(19), hasTime: false),
                     "a reminder with only a day is due at the start of it, its title trimmed")
        suite.expect(RemindersSupport.item(id: "b", title: "Call", due: timed, completed: false, calendar: calendar)
                        == .init(id: "b", title: "Call", due: date(19, 15, 30), hasTime: true),
                     "a timed reminder keeps its time")
        suite.expect(RemindersSupport.item(id: "c", title: "Done", due: timed, completed: true, calendar: calendar) == nil
                     && RemindersSupport.item(id: "d", title: "Someday", due: nil, completed: false, calendar: calendar) == nil,
                     "completed reminders and ones without a due date never show")
        suite.expect(RemindersSupport.item(id: "e", title: nil, due: dayOnly, completed: false, calendar: calendar)?.title == "",
                     "a reminder without a title is kept, to read as untitled")
    }

    private static func reminderSelection(_ suite: TestSuite) {
        let calendar = utc
        let now = date(19, 10)
        func item(_ id: String, _ due: Date, time: Bool = true, title: String? = nil) -> RemindersSupport.Item {
            .init(id: id, title: title ?? id, due: due, hasTime: time)
        }
        let items = [
            item("later today", date(19, 15)),
            item("tomorrow", date(20), time: false),
            item("midnight", date(20, 0)),
            item("this morning", date(19, 9)),
            item("today", date(19), time: false),
            item("last week", date(10, 8)),
            item("yesterday", date(18), time: false),
        ]
        let top = RemindersSupport.selection(items, now: now, calendar: calendar)
        suite.expect(top.shown.map(\.id) == ["last week", "yesterday", "today"] && top.hidden == 2,
                     "the three earliest due today or overdue show, and the rest are counted")
        suite.expect(top.shown.map(\.overdue) == [true, true, false],
                     "a reminder for today with no time is not overdue until the day ends")
        let all = RemindersSupport.selection(items, now: now, calendar: calendar, limit: 10)
        suite.expect(all.shown.map(\.id) == ["last week", "yesterday", "today", "this morning", "later today"]
                     && all.hidden == 0,
                     "nothing due tomorrow shows, even at midnight")
        suite.expect(all.shown.first { $0.id == "this morning" }?.overdue == true
                     && all.shown.first { $0.id == "later today" }?.overdue == false,
                     "a timed reminder is overdue once its time has passed")
        let laterNow = RemindersSupport.selection(items, now: date(19, 16), calendar: calendar, limit: 10)
        suite.expect(laterNow.shown.first { $0.id == "later today" }?.overdue == true,
                     "a reminder turns overdue as the clock passes it")
        let ties = RemindersSupport.selection([item("2", date(19, 9), title: "Water plants"),
                                               item("1", date(19, 9), title: "Call mum")], now: now, calendar: calendar)
        suite.expect(ties.shown.map(\.id) == ["1", "2"], "reminders due at the same time read in title order")
        suite.expect(RemindersSupport.selection([], now: now, calendar: calendar).isEmpty
                     && RemindersSupport.selection([item("tomorrow", date(20, 9))], now: now, calendar: calendar).isEmpty,
                     "with nothing due, the lock screen shows no reminders")
        suite.expect(RemindersSupport.limit == 3, "at most three reminders")
        suite.expect(RemindersSupport.readEnd(now: now, calendar: calendar) == date(20),
                     "EventKit is asked for everything due before tomorrow")
    }

    private static func access(_ suite: TestSuite) {
        suite.expect(LockScreenWidgetAccess(location: .authorizedAlways) == .granted
                     && CLAuthorizationStatus(rawValue: 4).map(LockScreenWidgetAccess.init(location:)) == .granted
                     && LockScreenWidgetAccess(location: .notDetermined) == .notDetermined
                     && LockScreenWidgetAccess(location: .denied) == .denied
                     && LockScreenWidgetAccess(location: .restricted) == .denied,
                     "location access reads as granted, not asked yet or refused")
        suite.expect(LockScreenWidgetAccess(reminders: .fullAccess) == .granted
                     && LockScreenWidgetAccess(reminders: .writeOnly) == .denied
                     && LockScreenWidgetAccess(reminders: .notDetermined) == .notDetermined
                     && LockScreenWidgetAccess(reminders: .denied) == .denied
                     && LockScreenWidgetAccess(reminders: .restricted) == .denied,
                     "reminders need full access; write-only access cannot read them")
    }

    private static func line(_ suite: TestSuite) {
        suite.expect(NotchLockScreenSupport.activities(timer: false, calendar: false, agents: false, downloads: false,
                                                       weather: true, reminders: true) == [.weather, .reminders],
                     "weather and reminders join the lock screen line after the rest")
        suite.expect(NotchLockScreenSupport.activities(timer: true, calendar: false, agents: false, downloads: false)
                        == [.timer],
                     "weather and reminders stay off unless asked for")
    }

    private static func configuration(_ suite: TestSuite) {
        suite.expect(Defaults.registeredDefaults[DefaultsKey.notchLockScreenWeather] as? Bool == false
                     && Defaults.registeredDefaults[DefaultsKey.notchLockScreenReminders] as? Bool == false,
                     "weather and reminders start off, so nothing asks for a permission unasked")
        let info = NSDictionary(contentsOfFile: "Resources/Info.plist") as? [String: Any]
        let promptKeys = ["NSLocationUsageDescription", "NSLocationWhenInUseUsageDescription",
                          "NSRemindersFullAccessUsageDescription"]
        suite.expect(promptKeys.allSatisfy { !(info?[$0] as? String ?? "").isEmpty },
                     "the location and reminders prompts explain themselves")
        let folders = ((try? FileManager.default.contentsOfDirectory(atPath: "Resources")) ?? [])
            .filter { $0.hasSuffix(".lproj") }
        suite.expect(!folders.isEmpty && folders.allSatisfy { folder in
            let strings = NSDictionary(contentsOfFile: "Resources/\(folder)/InfoPlist.strings") as? [String: String]
            return promptKeys.allSatisfy { key in
                guard let value = strings?[key], !value.isEmpty else { return false }
                return value != info?[key] as? String
            }
        }, "every language translates the location and reminders prompts")
        let entitlements = NSDictionary(contentsOfFile: "Resources/Vorssaint.entitlements") as? [String: Any]
        suite.expect(entitlements?["com.apple.security.personal-information.location"] as? Bool == true,
                     "the hardened runtime may ask for location")
        suite.expect(AppLanguage.allCases.allSatisfy { language in
            let text = ZenithStrings.lockScreenWidgets(language)
            let all = [text.weather, text.reminders, text.weatherCaption, text.remindersCaption, text.locationNeeded,
                       text.locationDenied, text.remindersNeeded, text.remindersDenied, text.high, text.low, text.overdue]
            return all.allSatisfy { !$0.isEmpty && !$0.contains("'") }
        }, "every language names the weather and reminders and explains their permissions")
    }
}
