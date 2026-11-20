// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: prayer times and the golden hour, worked out offline.
///
/// The references are published schedules and calculators, not this code's
/// own output: Kemenag-method schedules for Jakarta Pusat and Medan
/// (jadwalsholat.org, Fajr 20°, Isha 18°, Shafi'i, ihtiyat 2 minutes) and
/// Kemenag's own Ramadan 1447 schedule for Jakarta; Aladhan's timings for
/// the other methods and for the angle-based rule at high latitudes;
/// sunrise-sunset.org for sunrise, sunset and civil twilight; Meeus's worked
/// example for the declination and the equation of time; NREL's SPA paper
/// for an elevation.
enum SkyTests {
    static func run(_ suite: TestSuite) {
        solarPosition(suite)
        sunEvents(suite)
        goldenWindows(suite)
        kemenagJakarta(suite)
        kemenagMedan(suite)
        otherMethods(suite)
        highLatitudes(suite)
        adjustments(suite)
        nextAndCurrent(suite)
        islandActivity(suite)
        goldenActivity(suite)
        formatting(suite)
        settings(suite)
        names(suite)
        island(suite)
        strings(suite)
    }

    private static let jakartaZone = TimeZone(identifier: "Asia/Jakarta")!
    private static let suiteName = "com.vorssaint.tests.sky"

    private static func calendar(_ zone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar
    }

    private static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ mi: Int = 0, _ s: Int = 0,
                             zone: TimeZone = jakartaZone) -> Date {
        calendar(zone).date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: mi, second: s))!
    }

    private static func minutes(_ clock: String) -> Int {
        let parts = clock.split(separator: ":").compactMap { Int($0) }
        return parts[0] * 60 + parts[1]
    }

    /// Minutes past local midnight of the day `day` starts, so a time just
    /// after midnight the next day reads as more than 24 hours.
    private static func minutes(_ date: Date?, from day: Date, zone: TimeZone) -> Int? {
        guard let date else { return nil }
        let midnight = calendar(zone).startOfDay(for: day)
        return Int((date.timeIntervalSince(midnight) / 60).rounded())
    }

    private static func schedule(_ y: Int, _ m: Int, _ d: Int, _ coordinate: SolarSupport.Coordinate,
                                 method: PrayerMethod = .kemenag, asr: PrayerAsrSchool = .shafii,
                                 adjustments: PrayerAdjustments = PrayerAdjustments(),
                                 zone: TimeZone = jakartaZone) -> PrayerSchedule? {
        PrayerTimesSupport.schedule(noon: date(y, m, d, zone: zone), coordinate: coordinate,
                                    configuration: PrayerConfiguration(method: method, asr: asr, adjustments: adjustments))
    }

    /// Every time within `tolerance` minutes of a published row, in Prayer
    /// order (Imsak, Fajr, sunrise, Dhuhr, Asr, Maghrib, Isha); "" skips one.
    private static func matches(_ schedule: PrayerSchedule?, _ row: [String], day: Date, zone: TimeZone = jakartaZone,
                                tolerance: Int) -> Bool {
        guard let schedule else { return false }
        return zip(Prayer.allCases, row).allSatisfy { prayer, reference in
            guard !reference.isEmpty else { return true }
            guard let got = minutes(schedule.time(prayer), from: day, zone: zone) else { return false }
            var wanted = minutes(reference)
            if wanted < 6 * 60, prayer == .isha { wanted += 24 * 60 }
            return abs(got - wanted) <= tolerance
        }
    }

    // MARK: Solar position

    private static func solarPosition(_ suite: TestSuite) {
        // Meeus, Astronomical Algorithms, examples 25.a and 28.a: 1992 October 13, 0h.
        let meeus = Date(timeIntervalSince1970: 718_934_400)
        let position = SolarSupport.position(at: meeus)
        suite.expect(abs(position.declination - (-7.78500)) < 0.005,
                     "the declination matches Meeus’s example (−7°47′06″)")
        suite.expect(abs(position.equationOfTime - 13.711) < 0.05,
                     "the equation of time matches Meeus’s example (13m42.7s)")
        // NREL SPA (Reda and Andreas 2004): 2003-10-17 12:30:30 −7h at Golden,
        // Colorado, topocentric zenith 50.11162° with refraction; geometric about 39.872°.
        let spa = Date(timeIntervalSince1970: 1_066_419_030)
        let elevation = SolarSupport.elevation(at: spa, coordinate: .init(latitude: 39.742476, longitude: -105.1786))
        suite.expect(abs(elevation - 39.872) < 0.05, "the elevation matches NREL’s SPA example")
        suite.expect(SolarSupport.signed(190) == -170 && SolarSupport.signed(-190) == 170 && SolarSupport.normalized(-10) == 350,
                     "angles wrap into their ranges")
    }

    // MARK: Sunrise, sunset, twilight

    private static func sunEvents(_ suite: TestSuite) {
        // sunrise-sunset.org, to the second, in Asia/Jakarta.
        let references: [(Int, Int, Int, SolarSupport.Coordinate, [String])] = [
            (2026, 11, 20, .init(latitude: -6.2, longitude: 106.8), ["05:03:42", "05:25:46", "11:38:20", "17:50:54", "18:12:58"]),
            (2026, 6, 21, .init(latitude: -6.2, longitude: 106.8), ["05:39:04", "06:01:38", "11:54:33", "17:47:28", "18:10:02"]),
            (2026, 11, 20, .init(latitude: 3.59, longitude: 98.67), ["05:50:29", "06:12:22", "12:10:52", "18:09:21", "18:31:14"]),
            (2026, 3, 20, .init(latitude: 3.59, longitude: 98.67), ["06:08:50", "06:29:28", "12:32:51", "18:36:13", "18:56:51"]),
        ]
        var worst: TimeInterval = 0
        for (y, m, d, place, row) in references {
            let noon = date(y, m, d)
            let events: [Date?] = [
                SolarSupport.time(at: -6, rising: true, noon: noon, coordinate: place),
                SolarSupport.time(at: SolarSupport.horizon, rising: true, noon: noon, coordinate: place),
                SolarSupport.transit(near: noon, longitude: place.longitude),
                SolarSupport.time(at: SolarSupport.horizon, rising: false, noon: noon, coordinate: place),
                SolarSupport.time(at: -6, rising: false, noon: noon, coordinate: place),
            ]
            for (event, reference) in zip(events, row) {
                let parts = reference.split(separator: ":").compactMap { Int($0) }
                let wanted = date(y, m, d, parts[0], parts[1], parts[2])
                worst = max(worst, event.map { abs($0.timeIntervalSince(wanted)) } ?? .infinity)
            }
        }
        suite.expect(worst <= 60, "civil twilight, sunrise, noon and sunset are within a minute of the reference")
        let place = SolarSupport.Coordinate(latitude: -6.2, longitude: 106.8)
        let noon = date(2026, 11, 20)
        let edges = [(-6.0, true), (-4.0, true), (6.0, true), (6.0, false), (-4.0, false), (-6.0, false)]
        suite.expect(edges.allSatisfy { altitude, rising in
            SolarSupport.time(at: altitude, rising: rising, noon: noon, coordinate: place)
                .map { abs(SolarSupport.elevation(at: $0, coordinate: place) - altitude) < 0.05 } ?? false
        }, "the sun stands at the asked altitude at the time found for it")
        suite.expect(SolarSupport.time(at: 80, rising: true, noon: date(2026, 6, 21), coordinate: place) == nil,
                     "an altitude the sun never reaches has no time")
    }

    // MARK: Golden and blue hours

    private static func goldenWindows(_ suite: TestSuite) {
        let place = SolarSupport.Coordinate(latitude: -6.2, longitude: 106.8)
        let windows = SolarSupport.windows(noon: date(2026, 11, 20), coordinate: place)
        suite.expect(windows.map(\.band) == [.blue, .golden, .golden, .blue] && windows.map(\.morning) == [true, true, false, false],
                     "a tropical day has a morning blue and golden hour, then an evening golden and blue hour")
        suite.expect(zip(windows, windows.dropFirst()).allSatisfy { $0.end == $1.start || $0.end <= $1.start }
                     && windows.allSatisfy { $0.end > $0.start },
                     "the windows run in order without overlapping")
        let sunset = SolarSupport.time(at: SolarSupport.horizon, rising: false, noon: date(2026, 11, 20), coordinate: place)!
        suite.expect(windows[2].contains(sunset), "the evening golden hour holds sunset")
        // Civil twilight ends at 18:12:58 (sunrise-sunset.org): the blue hour's end.
        suite.expect(abs(windows[3].end.timeIntervalSince(date(2026, 11, 20, 18, 12, 58))) < 60,
                     "the evening blue hour ends with civil twilight")
        suite.expect((windows[2].duration / 60).rounded() >= 35 && (windows[2].duration / 60).rounded() <= 50,
                     "near the equator the golden hour lasts about 40 minutes")
        let path = SolarSupport.path(midnight: date(2026, 11, 20, 0), coordinate: place)
        suite.expect(path.count == 49 && path.allSatisfy(\.isFinite) && (path.max() ?? 0) > 70 && (path.min() ?? 0) < -60,
                     "the day’s path climbs high at noon and sinks at midnight")
        // Tromsø at the winter solstice: the sun stays under +6°, one golden window.
        let tromso = SolarSupport.windows(noon: date(2026, 12, 21, 12, zone: TimeZone(identifier: "Europe/Oslo")!),
                                          coordinate: .init(latitude: 69.65, longitude: 18.96))
        suite.expect(tromso.filter { $0.band == .golden }.count == 1 && tromso.allSatisfy { $0.end > $0.start },
                     "a sun that never climbs past +6° gives one golden window")
        let polar = SolarSupport.windows(noon: date(2026, 6, 21, 12, zone: TimeZone(identifier: "UTC")!),
                                         coordinate: .init(latitude: 78.22, longitude: 15.65))
        suite.expect(polar.isEmpty, "under the midnight sun there is no golden or blue hour to name")
        suite.expect(SkyGoldenSupport.elevationText(12.44) == "12.4°" && SkyGoldenSupport.elevationText(-3.06) == "−3.1°"
                     && SkyGoldenSupport.elevationText(-0.01) == "0.0°" && SkyGoldenSupport.elevationText(.nan) == "–°",
                     "the elevation reads with one decimal and a real minus sign")
    }

    // MARK: Kemenag

    private static func kemenagJakarta(_ suite: TestSuite) {
        let pusat = SolarSupport.Coordinate(latitude: -(6 + 10.0 / 60), longitude: 106 + 49.0 / 60)
        let brief = SolarSupport.Coordinate(latitude: -6.2, longitude: 106.8)
        // jadwalsholat.org, Jakarta Pusat: Imsak, Subuh, Terbit, Dzuhur, Ashar, Maghrib, Isya.
        let rows: [(Int, Int, Int, [String])] = [
            (2026, 1, 1, ["04:08", "04:18", "05:39", "11:58", "15:25", "18:12", "19:28"]),
            (2026, 1, 21, ["04:20", "04:30", "05:49", "12:06", "15:30", "18:18", "19:33"]),
            (2026, 6, 15, ["04:28", "04:38", "05:58", "11:55", "15:17", "17:48", "19:03"]),
            (2026, 11, 1, ["03:59", "04:09", "05:25", "11:38", "14:54", "17:48", "19:00"]),
            (2026, 11, 20, ["03:55", "04:05", "05:24", "11:40", "15:03", "17:52", "19:07"]),
        ]
        for (y, m, d, row) in rows {
            suite.expect(matches(schedule(y, m, d, pusat), row, day: date(y, m, d), tolerance: 1),
                         "Kemenag Jakarta \(y)-\(m)-\(d) within a minute of the published schedule")
            suite.expect(matches(schedule(y, m, d, brief), row, day: date(y, m, d), tolerance: 2),
                         "Kemenag at −6.2, 106.8 on \(y)-\(m)-\(d) within two minutes")
        }
        // Kemenag's own Ramadan 1447 schedule, DKI Jakarta, 19 February 2026.
        suite.expect(matches(schedule(2026, 2, 19, pusat), ["04:31", "04:41", "", "", "", "18:18", "19:28"],
                             day: date(2026, 2, 19), tolerance: 1),
                     "Kemenag’s own Ramadan schedule for Jakarta matches within a minute")
        let times = schedule(2026, 11, 20, pusat)!
        suite.expect(times.time(.fajr)!.timeIntervalSince(times.time(.imsak)!) == 600 && !times.approximated,
                     "Imsak is ten minutes before Subuh, and Jakarta needs no approximation")
        let transit = SolarSupport.transit(near: date(2026, 11, 20), longitude: pusat.longitude)
        let delay = times.time(.dhuhr)!.timeIntervalSince(transit)
        suite.expect(delay > 60 && delay < 180, "Dzuhur comes two minutes after the sun’s transit")
    }

    private static func kemenagMedan(_ suite: TestSuite) {
        let medan = SolarSupport.Coordinate(latitude: 3 + 35.0 / 60, longitude: 98 + 39.0 / 60)
        let brief = SolarSupport.Coordinate(latitude: 3.59, longitude: 98.67)
        let rows: [(Int, Int, Int, [String])] = [
            (2026, 3, 1, ["05:11", "05:21", "06:35", "12:40", "15:56", "18:41", "19:51"]),
            (2026, 3, 21, ["05:05", "05:15", "06:28", "12:35", "15:42", "18:38", "19:47"]),
            (2026, 7, 15, ["04:51", "05:01", "06:20", "12:33", "15:59", "18:43", "19:57"]),
            (2026, 11, 21, ["04:43", "04:53", "06:11", "12:13", "15:36", "18:11", "19:24"]),
        ]
        for (y, m, d, row) in rows {
            suite.expect(matches(schedule(y, m, d, medan), row, day: date(y, m, d), tolerance: 1),
                         "Kemenag Medan \(y)-\(m)-\(d) within a minute of the published schedule")
            suite.expect(matches(schedule(y, m, d, brief), row, day: date(y, m, d), tolerance: 2),
                         "Kemenag at 3.59, 98.67 on \(y)-\(m)-\(d) within two minutes")
        }
    }

    // MARK: Other methods

    private static func otherMethods(_ suite: TestSuite) {
        let jakarta = SolarSupport.Coordinate(latitude: -6.2, longitude: 106.8)
        let day = date(2026, 11, 20)
        // Aladhan, 2026-11-20 at −6.2, 106.8: Imsak, Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha.
        let references: [(PrayerMethod, [String])] = [
            (.mwl, ["04:02", "04:12", "05:26", "11:38", "15:02", "17:51", "19:01"]),
            (.isna, ["04:15", "04:25", "05:26", "11:38", "15:02", "17:51", "18:52"]),
            (.egyptian, ["03:55", "04:05", "05:26", "11:38", "15:02", "17:51", "19:03"]),
            (.ummAlQura, ["04:00", "04:10", "05:26", "11:38", "15:02", "17:51", "19:21"]),
            (.singapore, ["03:53", "04:03", "05:26", "11:38", "15:02", "17:51", "19:05"]),
        ]
        for (method, row) in references {
            suite.expect(matches(schedule(2026, 11, 20, jakarta, method: method), row, day: day, tolerance: 1),
                         "\(method.title) matches Aladhan within a minute")
        }
        suite.expect(matches(schedule(2026, 11, 20, jakarta, method: .mwl, asr: .hanafi),
                             ["", "", "", "", "16:05", "", ""], day: day, tolerance: 1),
                     "the Hanafi Asr comes about an hour later (Aladhan 16:05)")
        let riyadh = TimeZone(identifier: "Asia/Riyadh")!
        suite.expect(matches(schedule(2026, 6, 21, .init(latitude: 21.4225, longitude: 39.8262), method: .ummAlQura, zone: riyadh),
                             ["04:01", "04:11", "05:39", "12:22", "15:42", "19:06", "20:36"],
                             day: date(2026, 6, 21, zone: riyadh), zone: riyadh, tolerance: 1),
                     "Umm al-Qura in Makkah matches Aladhan, Isha 90 minutes after Maghrib")
        suite.expect(PrayerMethod.kemenag.parameters == "20° · 18°" && PrayerMethod.ummAlQura.parameters == "18.5° · 90 min",
                     "a method describes its angles")
    }

    // MARK: High latitudes

    private static func highLatitudes(_ suite: TestSuite) {
        // Aladhan, MWL, angle-based: Fajr and Isha never further from the sun
        // than angle/60 of the night.
        let london = TimeZone(identifier: "Europe/London")!
        suite.expect(matches(schedule(2026, 6, 21, .init(latitude: 51.5074, longitude: -0.1278), method: .mwl, zone: london),
                             ["02:21", "02:31", "04:43", "13:02", "17:25", "21:22", "23:27"],
                             day: date(2026, 6, 21, zone: london), zone: london, tolerance: 1),
                     "London at midsummer takes the angle-based rule, as Aladhan does")
        let oslo = TimeZone(identifier: "Europe/Oslo")!
        let osloTimes = schedule(2026, 6, 21, .init(latitude: 59.9139, longitude: 10.7522), method: .mwl, zone: oslo)
        suite.expect(matches(osloTimes, ["02:11", "02:21", "03:54", "13:19", "18:00", "22:44", "00:12"],
                             day: date(2026, 6, 21, zone: oslo), zone: oslo, tolerance: 1)
                     && osloTimes?.approximated == true,
                     "Oslo’s Isha falls after midnight, marked as approximated")
        let svalbard = SolarSupport.Coordinate(latitude: 78.22, longitude: 15.65)
        let utc = TimeZone(identifier: "UTC")!
        for (month, day) in [(6, 21), (12, 21), (3, 20)] {
            let times = PrayerTimesSupport.schedule(noon: date(2026, month, day, zone: utc), coordinate: svalbard,
                                                    configuration: PrayerConfiguration(method: .mwl))
            let ordered = times.map { schedule in
                let list = Prayer.allCases.compactMap { schedule.time($0) }
                return list.count == Prayer.allCases.count && zip(list, list.dropFirst()).allSatisfy { $0 < $1 }
                    && list.allSatisfy { $0.timeIntervalSince1970.isFinite }
            } ?? false
            suite.expect(ordered, "Svalbard on \(month)-\(day) still has every time, in order, without NaN")
        }
        suite.expect(PrayerTimesSupport.schedule(noon: date(2026, 6, 21, zone: utc), coordinate: svalbard)?.approximated == true,
                     "a polar day falls back to the nearest latitude and says so")
        for latitude in [89.99, -89.99, 66.56, -66.56] {
            let place = SolarSupport.Coordinate(latitude: latitude, longitude: 0)
            let times = PrayerTimesSupport.schedule(noon: date(2026, 12, 21, zone: utc), coordinate: place)
            let windows = SolarSupport.windows(noon: date(2026, 12, 21, zone: utc), coordinate: place)
            suite.expect(times.map { $0.times.values.allSatisfy { $0.timeIntervalSince1970.isFinite } } == true
                         && windows.allSatisfy { $0.start.timeIntervalSince1970.isFinite && $0.end > $0.start }
                         && SolarSupport.elevation(at: date(2026, 12, 21, zone: utc), coordinate: place).isFinite,
                         "latitude \(latitude) gives finite times and windows")
        }
        suite.expect(PrayerTimesSupport.schedule(noon: date(2026, 1, 1), coordinate: .init(latitude: .nan, longitude: 0)) == nil
                     && PrayerTimesSupport.schedule(noon: date(2026, 1, 1), coordinate: .init(latitude: 91, longitude: 0)) == nil
                     && SolarSupport.windows(noon: date(2026, 1, 1), coordinate: .init(latitude: 0, longitude: .infinity)).isEmpty,
                     "an impossible position has no times")
    }

    // MARK: Adjustments

    private static func adjustments(_ suite: TestSuite) {
        let jakarta = SolarSupport.Coordinate(latitude: -6.2, longitude: 106.8)
        let plain = schedule(2026, 11, 20, jakarta)!
        var minutes = PrayerAdjustments()
        minutes[.dhuhr] = 3
        minutes[.fajr] = -2
        minutes[.isha] = 15
        minutes[.imsak] = 1
        let adjusted = schedule(2026, 11, 20, jakarta, adjustments: minutes)!
        func shift(_ prayer: Prayer) -> TimeInterval { adjusted.time(prayer)!.timeIntervalSince(plain.time(prayer)!) / 60 }
        suite.expect(shift(.dhuhr) == 3 && shift(.fajr) == -2 && shift(.asr) == 0 && shift(.sunrise) == 0,
                     "each time takes its own minutes")
        suite.expect(minutes[.isha] == 10 && shift(.isha) == 10, "an adjustment stays within ten minutes")
        suite.expect(shift(.imsak) == -1, "Imsak follows Subuh as adjusted, then takes its own minutes")
        suite.expect(PrayerAdjustments.decode(minutes.encoded) == minutes && minutes.encoded == "1,-2,0,3,0,0,10",
                     "adjustments are stored as seven numbers")
        let messy = PrayerAdjustments.decode("x, 4,,-40")
        suite.expect(messy[.imsak] == 0 && messy[.fajr] == 4 && messy[.sunrise] == 0 && messy[.dhuhr] == -10
                     && messy[.isha] == 0 && PrayerAdjustments.decode(nil).isZero,
                     "unreadable or missing values become 0, the rest are clamped")
    }

    // MARK: Next and current

    private static func nextAndCurrent(_ suite: TestSuite) {
        let place = SkyPlace(coordinate: .init(latitude: -6.2, longitude: 106.8), name: nil)
        let day = SkyDay.make(containing: date(2026, 11, 20, 23, 30), place: place, configuration: PrayerConfiguration(),
                              calendar: calendar(jakartaZone))
        let lateEvening = date(2026, 11, 20, 23, 30)
        let next = PrayerTimesSupport.next(after: lateEvening, in: day.moments)
        suite.expect(next?.prayer == .fajr && calendar(jakartaZone).component(.day, from: next!.time) == 21,
                     "after Isha the next prayer is tomorrow’s Subuh")
        suite.expect(PrayerTimesSupport.current(at: lateEvening, in: day.moments)?.prayer == .isha,
                     "late in the evening, Isha’s time is under way")
        let afterMidnight = date(2026, 11, 20, 0, 30)
        let early = SkyDay.make(containing: afterMidnight, place: place, configuration: PrayerConfiguration(),
                                calendar: calendar(jakartaZone))
        suite.expect(PrayerTimesSupport.current(at: afterMidnight, in: early.moments)?.prayer == .isha
                     && PrayerTimesSupport.next(after: afterMidnight, in: early.moments)?.prayer == .fajr,
                     "just after midnight, yesterday’s Isha runs until today’s Subuh")
        suite.expect(PrayerTimesSupport.current(at: date(2026, 11, 20, 8), in: day.moments) == nil,
                     "between sunrise and Dzuhur no prayer’s time is under way")
        suite.expect(PrayerTimesSupport.next(after: date(2026, 11, 20, 8), in: day.moments)?.prayer == .dhuhr
                     && PrayerTimesSupport.next(after: date(2026, 11, 20, 3), in: day.moments, among: Prayer.remindable)?.prayer == .imsak,
                     "sunrise is never next; Imsak is when asked for")
        let dhuhr = day.today!.time(.dhuhr)!
        suite.expect(PrayerTimesSupport.next(after: dhuhr, in: day.moments)?.prayer == .asr
                     && PrayerTimesSupport.current(at: dhuhr, in: day.moments)?.prayer == .dhuhr,
                     "at Dzuhur’s minute it is under way and Ashar is next")
        let windows = day.upcomingWindows(after: date(2026, 11, 20, 19))
        suite.expect(windows.count == 2 && windows.allSatisfy(\.morning) && windows.first?.band == .blue,
                     "after dusk the next windows are tomorrow morning’s")
        suite.expect(day.contains(date(2026, 11, 20, 0, 0, 1), calendar: calendar(jakartaZone))
                     && !day.contains(date(2026, 11, 21, 0, 0, 1), calendar: calendar(jakartaZone)),
                     "a day holds its own date only")
    }

    // MARK: The closed island

    private static func islandActivity(_ suite: TestSuite) {
        let place = SkyPlace(coordinate: .init(latitude: -6.2, longitude: 106.8), name: nil)
        let day = SkyDay.make(containing: date(2026, 11, 20), place: place, configuration: PrayerConfiguration(),
                              calendar: calendar(jakartaZone))
        let asr = day.today!.time(.asr)!
        let five = Set(Prayer.obligatory)
        func activity(_ offset: TimeInterval, lead: Int = 10, reminded: Set<Prayer> = five) -> PrayerTimesSupport.Activity? {
            PrayerTimesSupport.activity(at: asr.addingTimeInterval(offset), moments: day.moments, reminded: reminded, leadMinutes: lead)
        }
        let moment = PrayerMoment(prayer: .asr, time: asr)
        suite.expect(activity(-11 * 60) == nil && activity(-9 * 60) == .upcoming(moment) && activity(-25 * 60, lead: 30) == .upcoming(moment),
                     "the countdown starts within the chosen lead")
        suite.expect(activity(0) == .arrived(moment) && activity(119) == .arrived(moment) && activity(121) == nil,
                     "at the time the island says so for two minutes")
        suite.expect(activity(-5 * 60, reminded: five.subtracting([.asr])) == nil,
                     "a prayer switched off is not counted down")
        suite.expect(PrayerTimesSupport.nextChange(after: asr.addingTimeInterval(-30 * 60), moments: day.moments,
                                                   reminded: five, leadMinutes: 10) == asr.addingTimeInterval(-10 * 60)
                     && PrayerTimesSupport.nextChange(after: asr.addingTimeInterval(-60), moments: day.moments,
                                                      reminded: five, leadMinutes: 10) == asr
                     && PrayerTimesSupport.nextChange(after: asr.addingTimeInterval(1), moments: day.moments,
                                                      reminded: five, leadMinutes: 10) == asr.addingTimeInterval(120),
                     "the service wakes only where the activity changes")
        suite.expect(NotchSupport.compactActivities(timer: false, downloads: false, agents: false, calendar: true, music: true,
                                                    export: true, prayer: true, golden: true)
                        == [.export, .prayer, .golden, .calendar, .music],
                     "a prayer and the golden hour come before an event, after work under way")
        suite.expect(NotchCompactActivity.prayer.module == .sky && NotchCompactActivity.golden.module == .sky,
                     "a click opens the Sky page")
    }

    private static func goldenActivity(_ suite: TestSuite) {
        let place = SolarSupport.Coordinate(latitude: -6.2, longitude: 106.8)
        let windows = SolarSupport.windows(noon: date(2026, 11, 20), coordinate: place)
        let evening = windows.first { $0.band == .golden && !$0.morning }!
        let morning = windows.first { $0.band == .golden && $0.morning }!
        suite.expect(SkyGoldenSupport.activity(at: evening.start.addingTimeInterval(-31 * 60), windows: windows) == nil
                     && SkyGoldenSupport.activity(at: evening.start.addingTimeInterval(-29 * 60), windows: windows) == .upcoming(evening)
                     && SkyGoldenSupport.activity(at: evening.start.addingTimeInterval(60), windows: windows) == .during(evening)
                     && SkyGoldenSupport.activity(at: evening.end.addingTimeInterval(1), windows: windows) == nil,
                     "the evening golden hour shows 30 minutes ahead and while it lasts")
        suite.expect(SkyGoldenSupport.activity(at: morning.start.addingTimeInterval(60), windows: windows) == nil,
                     "the morning golden hour stays on the page, not in the closed island")
        suite.expect(SkyGoldenSupport.nextChange(after: evening.start.addingTimeInterval(-60), windows: windows) == evening.start,
                     "the golden hour’s start wakes the service")
    }

    // MARK: Formats

    private static func formatting(_ suite: TestSuite) {
        suite.expect(PrayerTimesSupport.countdown(724) == "-12:04" && PrayerTimesSupport.countdown(723.2) == "-12:04"
                     && PrayerTimesSupport.countdown(4324) == "-1:12:04" && PrayerTimesSupport.countdown(0) == "-0:00"
                     && PrayerTimesSupport.countdown(-5) == "-0:00" && PrayerTimesSupport.countdown(.nan) == "-0:00",
                     "the countdown reads minutes and seconds, hours once past one, and never goes below zero")
        suite.expect(PrayerTimesSupport.countdownTemplate(long: false).count >= PrayerTimesSupport.countdown(59 * 60 + 59).count
                     && PrayerTimesSupport.countdownTemplate(long: true).count >= PrayerTimesSupport.countdown(9 * 3600).count,
                     "the slot is as wide as the widest reading")
        suite.expect(PrayerTimesSupport.minutesLeft(31 * 60 + 5) == 32 && PrayerTimesSupport.minutesLeft(0) == 0
                     && PrayerTimesSupport.shortDuration(64 * 60) == "1h 04m" && PrayerTimesSupport.shortDuration(90) == "2m",
                     "minutes round up")
        let utc = TimeZone(identifier: "UTC")!
        let time = Date(timeIntervalSince1970: 15 * 3600 + 4 * 60)
        suite.expect(PrayerTimesSupport.terminalValue(PrayerMoment(prayer: .asr, time: time), now: time.addingTimeInterval(-64 * 60),
                                                      indonesian: true, timeZone: utc) == "ashar 15:04 · in 1h 04m"
                     && PrayerTimesSupport.terminalValue(PrayerMoment(prayer: .isha, time: time), now: time,
                                                         indonesian: false, timeZone: utc) == "isha now",
                     "the readout line names the prayer, its time and how long")
        let window = SolarSupport.Window(band: .golden, morning: false, start: time, end: time.addingTimeInterval(40 * 60))
        suite.expect(SkyGoldenSupport.terminalValue([window], now: time.addingTimeInterval(-32 * 60), timeZone: utc)
                        == "15:04–15:44 · in 32m"
                     && SkyGoldenSupport.terminalValue([window], now: time.addingTimeInterval(22 * 60), timeZone: utc) == "now · 18m left"
                     && SkyGoldenSupport.terminalValue([window], now: time.addingTimeInterval(41 * 60), timeZone: utc) == nil,
                     "the golden line reads its window, then the minutes left")
        suite.expect(NotchLockScreenTerminalSupport.paddedLabel(.golden).count == NotchLockScreenTerminalSupport.labelWidth
                     && NotchLockScreenTerminalSource.prayer.prayerLabel(indonesian: true) == "sholat"
                     && NotchLockScreenTerminalSource.prayer.prayerLabel(indonesian: false) == "prayer"
                     && !NotchLockScreenTerminalSource.prayer.isOnByDefault && !NotchLockScreenTerminalSource.golden.isOnByDefault,
                     "the readout lines fit the label column and start off")
        var readings = NotchLockScreenTerminalReadings(now: time)
        readings.prayer = "ashar 15:04 · in 1h 04m"
        suite.expect(NotchLockScreenTerminalSupport.lines([.prayer, .golden], readings: readings, showsProjects: false)
                        .map(\.source) == [.prayer],
                     "a Sky line without a reading stays hidden")
    }

    // MARK: Settings

    private static func settings(_ suite: TestSuite) {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let fresh = SkySettings.current(in: defaults)
        suite.expect(fresh.configuration.method == .kemenag && fresh.configuration.asr == .shafii && fresh.source == .automatic
                     && fresh.reminded == Set(Prayer.obligatory) && fresh.leadMinutes == 10 && !fresh.sound
                     && fresh.prayerActivity && fresh.goldenActivity,
                     "the defaults are Kemenag, Shafi’i, the five prayers, ten minutes, no sound")
        defaults.set("mwl", forKey: DefaultsKey.notchSkyMethod)
        defaults.set("hanafi", forKey: DefaultsKey.notchSkyAsr)
        defaults.set("city", forKey: DefaultsKey.notchSkyLocationSource)
        defaults.set("medan", forKey: DefaultsKey.notchSkyCity)
        defaults.set(25, forKey: DefaultsKey.notchSkyPrayerLead)
        defaults.set("imsak, sunrise,isha,bogus", forKey: DefaultsKey.notchSkyReminded)
        let chosen = SkySettings.current(in: defaults)
        suite.expect(chosen.configuration.method == .mwl && chosen.configuration.asr == .hanafi
                     && chosen.place(automatic: nil) == SkyPlace(coordinate: .init(latitude: 3.59, longitude: 98.67), name: "Medan"),
                     "a chosen method, school and city are read back")
        suite.expect(chosen.leadMinutes == 10 && chosen.reminded == [.imsak, .isha],
                     "an unknown lead falls back; sunrise and unknown names are never reminded")
        defaults.set("", forKey: DefaultsKey.notchSkyReminded)
        suite.expect(SkySettings.current(in: defaults).reminded.isEmpty, "an empty list reminds of nothing")
        suite.expect(SkySettings.encodeReminded([.isha, .fajr, .sunrise]) == "fajr,isha", "reminders are stored in prayer order")
        var automatic = SkySettings()
        suite.expect(automatic.place(automatic: nil) == nil
                     && automatic.place(automatic: .init(latitude: -6.2, longitude: 106.8))?.name == nil,
                     "the approximate location needs a fix and is never named")
        automatic.source = .custom
        automatic.customLatitude = 95
        suite.expect(automatic.place(automatic: nil) == nil, "a typed position off the globe has no times")
        suite.expect(SkyCity.all.count >= 20 && Set(SkyCity.all.map(\.id)).count == SkyCity.all.count
                     && SkyCity.all.allSatisfy { $0.coordinate.isValid && abs($0.coordinate.latitude) < 12 }
                     && SkyCity.named("medan") != nil && SkyCity.named(SkyCity.defaultID)?.name == "Jakarta",
                     "the built-in cities are Indonesian and unique")
        let registered = Defaults.registeredDefaults
        let keys = [DefaultsKey.notchSkyMethod, DefaultsKey.notchSkyAsr, DefaultsKey.notchSkyAdjustments,
                    DefaultsKey.notchSkyLocationSource, DefaultsKey.notchSkyCity, DefaultsKey.notchSkyLatitude,
                    DefaultsKey.notchSkyLongitude, DefaultsKey.notchSkyNames, DefaultsKey.notchSkyReminded,
                    DefaultsKey.notchSkyPrayerActivity, DefaultsKey.notchSkyPrayerLead, DefaultsKey.notchSkyPrayerSound,
                    DefaultsKey.notchSkyGoldenActivity, DefaultsKey.notchLockScreenPrayer, DefaultsKey.notchLockScreenGolden]
        suite.expect(keys.allSatisfy { registered[$0] != nil }
                     && registered[DefaultsKey.notchSkyPrayerSoundFile] == nil && registered[DefaultsKey.notchSkyPage] == nil
                     && registered[DefaultsKey.notchLockScreenPrayer] as? Bool == false
                     && registered[DefaultsKey.notchSkyPrayerSound] as? Bool == false,
                     "the preferences join the backup; the copied sound file and the page’s tab stay on this Mac")
    }

    private static func names(_ suite: TestSuite) {
        suite.expect(PrayerTimesSupport.usesIndonesian(.automatic, preferredLanguages: ["id-ID", "en-US"], region: "US")
                     && PrayerTimesSupport.usesIndonesian(.automatic, preferredLanguages: ["en-US"], region: "ID")
                     && !PrayerTimesSupport.usesIndonesian(.automatic, preferredLanguages: ["en-GB"], region: "GB")
                     && PrayerTimesSupport.usesIndonesian(.indonesian, preferredLanguages: [], region: nil)
                     && !PrayerTimesSupport.usesIndonesian(.app, preferredLanguages: ["id"], region: "ID"),
                     "Indonesian names on a Mac in Indonesian or in Indonesia, unless chosen otherwise")
        let english = ZenithStrings.sky(.enUS)
        suite.expect(english.name(.fajr, indonesian: true) == "Subuh" && english.name(.dhuhr, indonesian: true) == "Dzuhur"
                     && english.name(.asr, indonesian: true) == "Ashar" && english.name(.isha, indonesian: true) == "Isya"
                     && english.name(.fajr, indonesian: false) == "Fajr" && english.name(.isha, indonesian: false) == "Isha",
                     "Kemenag’s Indonesian names, or the language’s own")
        suite.expect(english.arrival(.dhuhr, indonesian: true) == "Waktunya Dzuhur"
                     && english.arrival(.dhuhr, indonesian: false) == "Time for Dhuhr",
                     "the time’s arrival reads Waktunya Dzuhur with Indonesian names")
        suite.expect(ZenithStrings.sky(.tr).name(.dhuhr, indonesian: false) == "Öğle"
                     && ZenithStrings.sky(.zhHans).name(.maghrib, indonesian: false) == "昏礼",
                     "Turkish and Chinese keep their own names for the prayers")
    }

    private static func island(_ suite: TestSuite) {
        suite.expect(NotchModule.sky.isAvailable() && NotchModule.sky.shortcutKey == "y"
                     && Set(NotchModule.allCases.map(\.shortcutKey)).count == NotchModule.allCases.count,
                     "the Sky section is always available and has a key of its own")
        suite.expect(ZenithHomeWidget.prayer.module == .sky && ZenithHomeWidget.golden.module == .sky
                     && ZenithHomeWidget.prayer.isAvailable(modules: [.sky]) && !ZenithHomeWidget.golden.isAvailable(modules: [.controls]),
                     "the home widgets follow the Sky page")
        suite.expect(ZenithNotice.Kind.prayer.priority == 3 && ZenithNoticeQueue.lifetime(.prayer) == 120
                     && ZenithNoticeTiming.duration(.prayer) == 6 && ZenithNoticeKey.prayer("dhuhr") == "prayer.dhuhr",
                     "a prayer’s notice outranks chargers and downloads, and waits up to two minutes")
        suite.expect(NotchLockScreenSupport.activities(timer: false, calendar: false, agents: false, downloads: false,
                                                       weather: true, prayer: true, golden: true) == [.weather, .prayer, .golden],
                     "the lock screen line gives up the Sky items first")
    }

    private static func strings(_ suite: TestSuite) {
        for language in AppLanguage.allCases {
            let text = ZenithStrings.sky(language)
            let visible = [text.title, text.summary, text.prayerTab, text.goldenTab, text.timeFor, text.next, text.blueHour,
                           text.morning, text.evening, text.tomorrow, text.goldenIn, text.goldenLeft, text.minutes, text.sun,
                           text.noWindows, text.needsLocation, text.locationDenied, text.chooseCity, text.approximated,
                           text.calculation, text.method, text.asr, text.shafii, text.hanafi, text.adjustments,
                           text.adjustmentsCaption, text.names, text.namesAutomatic, text.namesIndonesian, text.namesApp,
                           text.location, text.sourceAutomatic, text.sourceCity, text.sourceCustom, text.latitude,
                           text.longitude, text.automaticCaption, text.manualCaption, text.reminders, text.remindersCaption,
                           text.prayerActivity, text.prayerActivityCaption, text.lead, text.sound, text.soundCaption,
                           text.chooseSound, text.systemSound, text.goldenActivity, text.goldenActivityCaption,
                           text.lockPrayer, text.lockGolden] + text.prayerNames
            suite.expect(text.prayerNames.count == Prayer.allCases.count && visible.allSatisfy { !$0.isEmpty },
                         "\(language.rawValue): every Sky text and all seven names are there")
            suite.expect(visible.allSatisfy { !$0.contains("'") && !$0.contains("—") },
                         "\(language.rawValue): curly apostrophes and no em dashes")
            suite.expect(text.timeFor.contains("%@") && text.goldenIn.contains("%@") && text.goldenLeft.contains("%@")
                         && text.minutes.contains("%d"),
                         "\(language.rawValue): the formats keep their placeholders")
        }
    }
}
