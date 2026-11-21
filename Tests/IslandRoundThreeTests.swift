// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import Foundation

/// Zenith fork: the island's third round: the room rule every grown island
/// keeps, the collapsed capture row and the strings they read.
enum IslandRoundThreeTests {
    static func run(_ suite: TestSuite) {
        room(suite)
        captureStrip(suite)
        batteryNotice(suite)
        calendarGrid(suite)
        prayerBurst(suite)
        strings(suite)
    }

    // MARK: Bursts

    static let geometry = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32,
                                        cameraWidth: 185, layout: .spacious, menuBarHeight: 32)

    static let asr = ZenithPrayerBurst(symbol: "sun.max", title: "Waktunya Ashar", subtitle: "15.04 · Kemenag RI",
                                       nextLabel: "Next", next: "Maghrib 18.02")

    private static func prayerBurst(_ suite: TestSuite) {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let burst = ZenithIslandBurst(.prayer(asr), start: start)
        suite.expect(burst.duration == ZenithIslandBurstTiming.prayer && burst.event == .timer && burst.module == .sky,
                     "a prayer's time grows the island through its own notice and opens the Sky page")
        suite.expect(burst.remaining(at: start) == 1 && burst.remaining(at: start.addingTimeInterval(burst.duration / 2)) == 0.5
                        && burst.remaining(at: start.addingTimeInterval(burst.duration + 5)) == 0
                        && burst.remaining(at: start.addingTimeInterval(-3)) == 1,
                     "its line empties from full to nothing over its stay")
        suite.expect(ZenithIslandBurstTiming.phase(burst, at: start.addingTimeInterval(2)) == .shown(remaining: 0.75)
                        && ZenithIslandBurstTiming.phase(burst, at: start.addingTimeInterval(burst.duration)) == .settled,
                     "grown for its stay, then settled back into the pill")
        let charge = ZenithIslandBurst(.charge(.make(.charging, percent: 50, minutes: nil, island: ZenithStrings.island(.enUS),
                                                     notices: ZenithStrings.notices(.enUS), locale: Locale(identifier: "en_US"))),
                                       start: start)
        suite.expect(!ZenithIslandBurstTiming.replaces(burst, with: charge, at: start.addingTimeInterval(1))
                        && ZenithIslandBurstTiming.replaces(burst, with: charge, at: start.addingTimeInterval(burst.duration + 1))
                        && ZenithIslandBurstTiming.replaces(charge, with: burst, at: start.addingTimeInterval(1))
                        && ZenithIslandBurstTiming.replaces(nil, with: charge, at: start),
                     "a charger never cuts a prayer's time short; a prayer takes the island from a charger")
        suite.expect(burst.accessibilityText == "Waktunya Ashar, 15.04 · Kemenag RI, Next Maghrib 18.02",
                     "VoiceOver reads the time, the method and the next prayer")

        let size = ZenithIslandBurstLayout.size(burst, geometry: geometry)
        let shoulder = NotchLayout.shoulder(height: size.height)
        suite.expect(ZenithIslandRoom.contentWidth(width: size.width, shoulder: shoulder) >= ZenithIslandBurstLayout.contentWidth(burst)
                        && size.width >= ZenithIslandRoom.minimumWidth,
                     "the prayer's row fits inside the room rule")
        suite.expect(size.height == geometry.stripHeight - ZenithIslandBurstLayout.rowOverlap
                        + ZenithIslandBurstLayout.contentHeight(burst) && size.height > geometry.stripHeight + 60,
                     "the row and its line sit below the camera, the island taller than the pill")
        let alone = ZenithIslandBurst(.prayer(ZenithPrayerBurst(symbol: "moon", title: "Waktunya Isya", subtitle: "19.07 · Kemenag RI",
                                                                nextLabel: "Next", next: nil)), start: start)
        suite.expect(ZenithIslandBurstLayout.contentWidth(alone) < ZenithIslandBurstLayout.contentWidth(burst),
                     "without a next prayer the end column is left out")
    }

    // MARK: Calendar

    private static func calendar(_ identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: identifier)
        calendar.timeZone = TimeZone(identifier: "Asia/Jakarta")!
        return calendar
    }

    private static func calendarGrid(_ suite: TestSuite) {
        let us = calendar("en_US"), de = calendar("de_DE"), gb = calendar("en_GB")
        let november = us.date(from: DateComponents(year: 2026, month: 11, day: 21))!
        let cells = ZenithCalendarGrid.cells(month: november, calendar: us)
        // 1 November 2026 is a Sunday: no lead with Sunday first, six with Monday first.
        suite.expect(us.firstWeekday == 1 && cells.count == 35 && cells.first??.timeIntervalSince(us.date(from: DateComponents(year: 2026, month: 11, day: 1))!) == 0,
                     "with Sunday first, November 2026 starts in the first cell and fills five weeks")
        suite.expect(cells.compactMap { $0 }.count == 30 && cells.suffix(5).allSatisfy { $0 == nil },
                     "the grid holds only the month's 30 days, the rest of the last row empty")
        let monday = ZenithCalendarGrid.cells(month: november, calendar: de)
        suite.expect(de.firstWeekday == 2 && monday.prefix(6).allSatisfy { $0 == nil } && monday[6] != nil
                        && monday.count == 42 && monday.count % 7 == 0,
                     "with Monday first (Germany) the 1st sits under Sunday and the month takes six rows")
        suite.expect(ZenithCalendarGrid.weekdaySymbols(calendar: us) == ["S", "M", "T", "W", "T", "F", "S"]
                        && ZenithCalendarGrid.weekdaySymbols(calendar: gb) == ["M", "T", "W", "T", "F", "S", "S"],
                     "the weekday line starts on the locale's first weekday")
        let february = us.date(from: DateComponents(year: 2026, month: 2, day: 10))!
        suite.expect(ZenithCalendarGrid.cells(month: february, calendar: us).count == 28,
                     "a February starting on Sunday fills exactly four rows")
        let leap = ZenithCalendarGrid.cells(month: us.date(from: DateComponents(year: 2028, month: 2, day: 1))!, calendar: us)
        suite.expect(leap.compactMap { $0 }.count == 29, "a leap February has 29 days")

        let now = us.date(from: DateComponents(year: 2026, month: 11, day: 21, hour: 15))!
        suite.expect(ZenithCalendarGrid.tone(us.date(from: DateComponents(year: 2026, month: 11, day: 21))!, now: now, calendar: us) == .today
                        && ZenithCalendarGrid.tone(us.date(from: DateComponents(year: 2026, month: 11, day: 20))!, now: now, calendar: us) == .past
                        && ZenithCalendarGrid.tone(us.date(from: DateComponents(year: 2026, month: 11, day: 22))!, now: now, calendar: us) == .future,
                     "today is filled, days gone by dimmed, the rest plain")
        suite.expect(ZenithCalendarGrid.dots([1, 1, 2, 3, 2, 4]) == [1, 2, 3] && ZenithCalendarGrid.dots([Int]()).isEmpty,
                     "a day shows at most three dots, one per calendar")
        suite.expect(ZenithCalendarMode.stored(nil) == .week && ZenithCalendarMode.stored("month") == .month
                        && ZenithCalendarMode.stored("year") == .week,
                     "the page opens on the last choice, Week by default")
        suite.expect(ZenithCalendarGrid.fitsBesideAgenda(CGSize(width: 500, height: 250))
                        && !ZenithCalendarGrid.fitsBesideAgenda(CGSize(width: 380, height: 250))
                        && ZenithCalendarGrid.gridWidth(500) + 18 + 1 < 500 - 150,
                     "a page wide enough holds the grid beside the day's events, with room for them")
        suite.expect(ZenithCalendarGrid.rowHeight(height: 250, rows: 6) * 6 + ZenithCalendarGrid.weekdayHeight <= 250
                        && ZenithCalendarGrid.rowHeight(height: 1000, rows: 5) == 40,
                     "six rows fit the page's height, and rows stop growing in a tall one")
    }

    // MARK: Battery notices

    private static func batteryNotice(_ suite: TestSuite) {
        let island = ZenithStrings.island(.enUS), notices = ZenithStrings.notices(.enUS)
        let en = Locale(identifier: "en_US")
        let off = ZenithBatteryNoticeLook.content(lowPowerOn: false, minutesLeft: 25, island: island, notices: notices, locale: en)
        suite.expect(off == .init(title: "Battery low", subtitle: "Turn on Low Power Mode to last longer", tone: .red),
                     "with Low Power Mode off the notice is red and offers it")
        let on = ZenithBatteryNoticeLook.content(lowPowerOn: true, minutesLeft: 25, island: island, notices: notices, locale: en)
        suite.expect(on == .init(title: "Low Power Mode is on", subtitle: "Plug in soon · about 25 min left", tone: .amber),
                     "with Low Power Mode on it turns amber and reads the time left")
        let unknown = ZenithBatteryNoticeLook.content(lowPowerOn: true, minutesLeft: nil, island: island, notices: notices, locale: en)
        suite.expect(unknown.subtitle == "Plug in soon", "without an estimate it only asks to plug in")

        let notice = ZenithNotice(kind: .batteryLow, key: ZenithNoticeKey.batteryLow, title: "", subtitle: "",
                                  glyph: .battery(percent: 20, tone: .red), accessory: .lowPower(on: false),
                                  action: .batterySettings, minutesLeft: 70)
        let turnedOn = ZenithBatteryNoticeLook.refreshed(notice, lowPowerOn: true, island: island, notices: notices, locale: en)
        suite.expect(turnedOn.accessory == .lowPower(on: true) && turnedOn.glyph == .battery(percent: 20, tone: .amber)
                        && turnedOn.title == notices.lowPowerOn && turnedOn.subtitle == "Plug in soon · about 1h 10m left"
                        && turnedOn.action == .batterySettings,
                     "Low Power Mode turned on while it shows recolours the glyph and swaps the pill for the chip")
        suite.expect(turnedOn.accessibilityText == "20%, Low Power Mode is on, Plug in soon · about 1h 10m left",
                     "VoiceOver reads the percentage first")

        suite.expect(ZenithPowerFormat.duration(minutes: 25, locale: en) == "25 min"
                        && ZenithPowerFormat.duration(minutes: 70, locale: en) == "1h 10m"
                        && ZenithPowerFormat.duration(minutes: 260, locale: en) == "4h 20m"
                        && ZenithPowerFormat.duration(minutes: 0, locale: en) == "1 min",
                     "durations read as minutes under an hour, hours and minutes from there")
        suite.expect(ZenithPowerFormat.minutes(nil) == nil && ZenithPowerFormat.minutes(-1) == nil
                        && ZenithPowerFormat.minutes(30) == nil && ZenithPowerFormat.minutes(.infinity) == nil
                        && ZenithPowerFormat.minutes(3 * 86_400) == nil && ZenithPowerFormat.minutes(1500) == 25,
                     "only a plausible estimate becomes minutes")
    }

    // MARK: Room

    private static func room(_ suite: TestSuite) {
        let edge = ZenithIslandRoom.edge
        suite.expect(edge >= 30, "content keeps at least 30 points from the island's sides")
        suite.expect(ZenithIslandRoom.width(content: 100, shoulder: 14, screenWidth: 1512) == ZenithIslandRoom.minimumWidth,
                     "short content keeps the island at its narrowest grown width")
        suite.expect(ZenithIslandRoom.width(content: 400, shoulder: 14, screenWidth: 1512) == 400 + (edge + 14) * 2,
                     "longer content widens the island by exactly its edges and shoulders")
        suite.expect(ZenithIslandRoom.contentWidth(width: ZenithIslandRoom.width(content: 400, shoulder: 14, screenWidth: 1512),
                                                   shoulder: 14) == 400,
                     "the content gets back what it asked for")
        suite.expect(ZenithIslandRoom.width(content: 2000, shoulder: 14, screenWidth: 1512) == ZenithIslandRoom.maximumWidth,
                     "the island stops growing at its widest")
        suite.expect(ZenithIslandRoom.width(content: 100, shoulder: 14, covering: 620, screenWidth: 1512) == 620,
                     "the island is never narrower than the one it grows from, even past its widest")
        suite.expect(ZenithIslandRoom.width(content: 2000, shoulder: 14, screenWidth: 500) == 500 - ZenithIslandRoom.screenMargin * 2
                        && ZenithIslandRoom.width(content: 100, shoulder: 14, covering: 900, screenWidth: 500) == 476,
                     "a narrow display keeps it inside its margins")
        suite.expect(ZenithIslandRoom.width(content: .infinity, shoulder: 14, screenWidth: 1512) == ZenithIslandRoom.minimumWidth
                        && ZenithIslandRoom.width(content: -50, shoulder: 14, screenWidth: 1512) == ZenithIslandRoom.minimumWidth,
                     "a measure that is not a width reads as none")
        let widest = ZenithIslandRoom.maximumWidth
        suite.expect(ZenithIslandRoom.lines(text: 200, fixed: 100, width: widest, shoulder: 14) == 1
                        && ZenithIslandRoom.lines(text: widest, fixed: 100, width: widest, shoulder: 14) == 2,
                     "text that fits keeps one line; text that does not takes two")
        suite.expect(ZenithIslandRoom.measure("", font: .systemFont(ofSize: 13)) == 0
                        && ZenithIslandRoom.measure("Battery low", font: .systemFont(ofSize: 13)) > 40,
                     "text measures as AppKit lays it out")
    }

    // MARK: Capture

    private static func captureStrip(_ suite: TestSuite) {
        let geometry = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32,
                                     cameraWidth: 185, layout: .spacious, menuBarHeight: 32)
        for language in AppLanguage.allCases {
            let size = ZenithCaptureStripLayout.size(language: language, geometry: geometry)
            let shoulder = NotchLayout.shoulder(height: size.height)
            let room = ZenithIslandRoom.contentWidth(width: size.width, shoulder: shoulder)
            let fits = ScreenCaptureTool.allCases.allSatisfy {
                ZenithCaptureStripLayout.contentWidth($0, language: language) <= room + 0.5
                    || size.width == ZenithIslandRoom.maximumWidth
            }
            suite.expect(fits && size.width >= geometry.cameraWidth + 56,
                         "\(language.rawValue): every tool's row fits the collapsed island, clear of its shoulders")
            suite.expect(size.height == geometry.stripHeight - ZenithCaptureStripLayout.rowOverlap
                            + ZenithCaptureStripLayout.rowHeight,
                         "\(language.rawValue): the row sits below the camera")
        }
        let en = ZenithCaptureStripLayout.self
        suite.expect(en.hint(.screenshot, language: .enUS) == "Drag to choose an area"
                        && en.title(.screenshot, language: .enUS) == "Screenshot",
                     "the screenshot row reads Screenshot and its hint")
        suite.expect(Set(ScreenCaptureTool.allCases.map { en.hint($0, language: .enUS) }).count == ScreenCaptureTool.allCases.count,
                     "each tool has its own hint")
    }

    // MARK: Strings

    private static func strings(_ suite: TestSuite) {
        for language in AppLanguage.allCases {
            let text = ZenithStrings.island(language)
            let all = [text.batteryLow, text.batteryLowHint, text.plugInSoon, text.aboutLeft, text.lowPowerPill, text.on,
                       text.fullIn, text.onHold, text.optimizedCharging, text.charged, text.left, text.next,
                       text.dragArea, text.dragRecording, text.dragText, text.clickColor, text.dragScrolling,
                       text.week, text.month, text.pickDay]
            suite.expect(all.allSatisfy { !$0.isEmpty && !$0.contains("'") && !$0.contains("\u{2014}") },
                         "\(language.rawValue): island strings are filled, with curly apostrophes and no em dash")
            suite.expect([text.aboutLeft, text.fullIn, text.left].allSatisfy { $0.components(separatedBy: "%@").count == 2 },
                         "\(language.rawValue): each duration template places its duration once")
        }
    }
}
