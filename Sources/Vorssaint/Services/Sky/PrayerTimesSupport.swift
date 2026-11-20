// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
//
// The prayer times follow the method published with PrayTimes.org (Hamid
// Zarrabi-Zadeh): Fajr and Isha at a depression angle of the sun, Asr when
// an object's shadow reaches its length times a factor plus its noon shadow,
// and the angle-based rule for high latitudes. Written here from that
// description and the solar formulas in SolarSupport; no code is taken.

import CoreGraphics
import Foundation

// Zenith fork: prayer times, offline. Everything here is pure (Foundation
// only) and compiled into the tests: the methods and their parameters, the
// day's times, the person's adjustments, which prayer is next and which
// period is under way, the closed island's moments, the formats, the cities
// and the settings. SkyService keeps time; the Sky views draw.

/// The times a day holds, in order. Sunrise only ends Fajr's time and is
/// never a prayer; Imsak is the start of a fast's abstinence, ten minutes
/// before Fajr.
enum Prayer: String, CaseIterable, Identifiable {
    case imsak, fajr, sunrise, dhuhr, asr, maghrib, isha

    var id: String { rawValue }

    /// The five daily prayers.
    static let obligatory: [Prayer] = [.fajr, .dhuhr, .asr, .maghrib, .isha]
    /// What the island can remind of: the five and Imsak, never sunrise.
    static let remindable: [Prayer] = [.imsak, .fajr, .dhuhr, .asr, .maghrib, .isha]
    /// Reminded by default: the five prayers. Imsak matters in Ramadan and starts off.
    static let remindedByDefault: [Prayer] = obligatory

    var index: Int { Prayer.allCases.firstIndex(of: self) ?? 0 }

    /// A sun by day, a moon by night: the glyph of the island's activity.
    var symbol: String {
        switch self {
        case .imsak: return "moon.stars.fill"
        case .fajr: return "sun.haze.fill"
        case .sunrise: return "sunrise.fill"
        case .dhuhr: return "sun.max.fill"
        case .asr: return "sun.min.fill"
        case .maghrib: return "sunset.fill"
        case .isha: return "moon.stars.fill"
        }
    }

    /// Indonesian names, as Kemenag's schedules print them.
    var indonesianName: String {
        switch self {
        case .imsak: return "Imsak"
        case .fajr: return "Subuh"
        case .sunrise: return "Terbit"
        case .dhuhr: return "Dzuhur"
        case .asr: return "Ashar"
        case .maghrib: return "Maghrib"
        case .isha: return "Isya"
        }
    }

    /// The readout's lowercase word: `ashar 15:04`.
    func terminalName(indonesian: Bool) -> String {
        if indonesian { return indonesianName.lowercased() }
        switch self {
        case .imsak: return "imsak"
        case .fajr: return "fajr"
        case .sunrise: return "sunrise"
        case .dhuhr: return "dhuhr"
        case .asr: return "asr"
        case .maghrib: return "maghrib"
        case .isha: return "isha"
        }
    }
}

/// A published calculation method.
enum PrayerMethod: String, CaseIterable, Identifiable {
    /// Kementerian Agama Republik Indonesia: Fajr 20°, Isha 18°, and its
    /// ihtiyat of two minutes on every time (Dhuhr two after the transit,
    /// sunrise two earlier).
    case kemenag
    /// Muslim World League: Fajr 18°, Isha 17°.
    case mwl
    /// Umm al-Qura, Makkah: Fajr 18.5°, Isha 90 minutes after Maghrib.
    case ummAlQura
    /// Egyptian General Authority of Survey: Fajr 19.5°, Isha 17.5°.
    case egyptian
    /// Islamic Society of North America: Fajr 15°, Isha 15°.
    case isna
    /// MUIS Singapore and JAKIM Malaysia: Fajr 20°, Isha 18°.
    case singapore

    var id: String { rawValue }

    enum Isha: Equatable {
        case angle(Double)
        case afterMaghrib(minutes: Double)
    }

    var fajrAngle: Double {
        switch self {
        case .kemenag, .singapore: return 20
        case .mwl: return 18
        case .ummAlQura: return 18.5
        case .egyptian: return 19.5
        case .isna: return 15
        }
    }

    var isha: Isha {
        switch self {
        case .kemenag, .singapore: return .angle(18)
        case .mwl: return .angle(17)
        case .ummAlQura: return .afterMaghrib(minutes: 90)
        case .egyptian: return .angle(17.5)
        case .isna: return .angle(15)
        }
    }

    /// The safety margin, in minutes, added to each time (taken from sunrise).
    var ihtiyat: Double { self == .kemenag ? 2 : 0 }

    /// Dhuhr after the sun's transit, in minutes.
    var dhuhrDelay: Double { self == .kemenag ? 2 : 0 }

    /// Imsak before Fajr, in minutes.
    var imsakLead: Double { 10 }

    /// The method's own name, the same in every language.
    var title: String {
        switch self {
        case .kemenag: return "Kemenag RI"
        case .mwl: return "Muslim World League"
        case .ummAlQura: return "Umm al-Qura"
        case .egyptian: return "Egyptian General Authority"
        case .isna: return "ISNA"
        case .singapore: return "MUIS / JAKIM"
        }
    }

    /// The angles, for the Settings caption: `20° · 18°`, `18.5° · 90 min`.
    var parameters: String {
        let fajr = Self.degrees(fajrAngle)
        switch isha {
        case .angle(let angle): return fajr + " · " + Self.degrees(angle)
        case .afterMaghrib(let minutes): return fajr + " · \(Int(minutes)) min"
        }
    }

    private static func degrees(_ value: Double) -> String {
        value.rounded() == value ? "\(Int(value))°" : String(format: "%.1f°", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}

/// Which school's shadow sets Asr.
enum PrayerAsrSchool: String, CaseIterable, Identifiable {
    /// Shafi'i, Maliki and Hanbali: the shadow as long as the object (plus its noon shadow).
    case shafii
    /// Hanafi: twice as long.
    case hanafi

    var id: String { rawValue }
    var shadowFactor: Double { self == .shafii ? 1 : 2 }
}

/// The person's own minutes on each time, −10 to +10.
struct PrayerAdjustments: Equatable {
    static let range = -10...10
    private(set) var minutes: [Int] = Array(repeating: 0, count: Prayer.allCases.count)

    init() {}

    subscript(prayer: Prayer) -> Int {
        get { minutes[prayer.index] }
        set { minutes[prayer.index] = min(Self.range.upperBound, max(Self.range.lowerBound, newValue)) }
    }

    /// Seven whole numbers in Prayer order, comma-separated.
    var encoded: String { minutes.map(String.init).joined(separator: ",") }

    /// A stored list; missing, unreadable or out-of-range values become 0 or
    /// the nearest bound.
    static func decode(_ stored: String?) -> PrayerAdjustments {
        var adjustments = PrayerAdjustments()
        let values = (stored ?? "").split(separator: ",", omittingEmptySubsequences: false)
        for prayer in Prayer.allCases where prayer.index < values.count {
            adjustments[prayer] = Int(values[prayer.index].trimmingCharacters(in: .whitespaces)) ?? 0
        }
        return adjustments
    }

    var isZero: Bool { minutes.allSatisfy { $0 == 0 } }
}

struct PrayerConfiguration: Equatable {
    var method: PrayerMethod = .kemenag
    var asr: PrayerAsrSchool = .shafii
    var adjustments = PrayerAdjustments()
}

/// One prayer at its time.
struct PrayerMoment: Equatable, Hashable {
    let prayer: Prayer
    let time: Date
}

/// One day's times.
struct PrayerSchedule: Equatable {
    let times: [Prayer: Date]
    /// A high-latitude rule or a nearer latitude stood in for a time the sun
    /// does not give that day.
    let approximated: Bool

    func time(_ prayer: Prayer) -> Date? { times[prayer] }

    /// Every time it has, in order.
    var moments: [PrayerMoment] {
        Prayer.allCases.compactMap { prayer in times[prayer].map { PrayerMoment(prayer: prayer, time: $0) } }
    }
}

enum PrayerTimesSupport {
    /// The farthest latitude computed as it is. Beyond it (polar days and
    /// nights, when the sun neither rises nor sets) the times are those of
    /// this latitude on the same meridian, marked as approximated.
    static let nearestLatitude = 64.0

    /// The day's times around `noon` (any instant near that day's local noon).
    static func schedule(noon: Date, coordinate: SolarSupport.Coordinate,
                         configuration: PrayerConfiguration = PrayerConfiguration()) -> PrayerSchedule? {
        guard coordinate.isValid else { return nil }
        let method = configuration.method
        var place = coordinate
        var approximated = false
        var sunrise = SolarSupport.time(at: SolarSupport.horizon, rising: true, noon: noon, coordinate: place)
        var sunset = SolarSupport.time(at: SolarSupport.horizon, rising: false, noon: noon, coordinate: place)
        if sunrise == nil || sunset == nil {
            // The sun stays up or down all day: take the nearest latitude where it rises and sets.
            place.latitude = (coordinate.latitude < 0 ? -1 : 1) * min(abs(coordinate.latitude), nearestLatitude)
            approximated = true
            sunrise = SolarSupport.time(at: SolarSupport.horizon, rising: true, noon: noon, coordinate: place)
            sunset = SolarSupport.time(at: SolarSupport.horizon, rising: false, noon: noon, coordinate: place)
        }
        guard let sunrise, let sunset else { return nil }
        let transit = SolarSupport.transit(near: noon, longitude: place.longitude)
        // The night, for the high-latitude rule: sunset to the next sunrise.
        let night = sunrise.addingTimeInterval(86_400).timeIntervalSince(sunset)

        var fajr = sunrise.addingTimeInterval(-night * method.fajrAngle / 60)
        if let byAngle = SolarSupport.time(at: -method.fajrAngle, rising: true, noon: noon, coordinate: place),
           byAngle >= fajr {
            fajr = byAngle
        } else {
            // Angle-based rule: never further from sunrise than angle/60 of the night.
            approximated = true
        }

        var isha: Date?
        switch method.isha {
        case .angle(let angle):
            isha = SolarSupport.time(at: -angle, rising: false, noon: noon, coordinate: place)
            let portion = night * angle / 60
            if isha.map({ $0.timeIntervalSince(sunset) > portion }) ?? true {
                isha = sunset.addingTimeInterval(portion)
                approximated = true
            }
        case .afterMaghrib(let minutes):
            isha = sunset.addingTimeInterval(minutes * 60)
        }

        let asr = asrTime(factor: configuration.asr.shadowFactor, transit: transit, coordinate: place)
            // Never missing where the sun rises and sets; halfway to sunset if it were.
            ?? transit.addingTimeInterval(sunset.timeIntervalSince(transit) / 2)

        let margin = method.ihtiyat * 60
        var times: [Prayer: Date] = [:]
        times[.fajr] = rounded(fajr.addingTimeInterval(margin))
        times[.sunrise] = rounded(sunrise.addingTimeInterval(-margin))
        times[.dhuhr] = rounded(transit.addingTimeInterval(method.dhuhrDelay * 60))
        times[.asr] = rounded(asr.addingTimeInterval(margin))
        times[.maghrib] = rounded(sunset.addingTimeInterval(margin))
        times[.isha] = isha.map { rounded($0.addingTimeInterval(margin)) }

        let adjustments = configuration.adjustments
        for prayer in Prayer.allCases where prayer != .imsak {
            times[prayer] = times[prayer]?.addingTimeInterval(Double(adjustments[prayer]) * 60)
        }
        // Imsak follows Fajr as the person set it, then takes its own minutes.
        times[.imsak] = times[.fajr]?.addingTimeInterval((-method.imsakLead + Double(adjustments[.imsak])) * 60)
        return PrayerSchedule(times: times, approximated: approximated)
    }

    /// When an object's shadow is `factor` times its length plus its noon
    /// shadow: the sun's altitude is acot(factor + tan|φ − δ|), δ taken at
    /// that afternoon time.
    static func asrTime(factor: Double, transit: Date, coordinate: SolarSupport.Coordinate) -> Date? {
        let radians = Double.pi / 180
        var time = transit.addingTimeInterval(3 * 3600)
        for _ in 0..<5 {
            let declination = SolarSupport.position(at: time).declination
            let altitude = atan(1 / (factor + tan(abs(coordinate.latitude - declination) * radians))) / radians
            guard let angle = SolarSupport.hourAngle(for: altitude, latitude: coordinate.latitude,
                                                     declination: declination) else { return nil }
            let step = SolarSupport.signed(angle - SolarSupport.hourAngle(at: time, longitude: coordinate.longitude))
            time = time.addingTimeInterval(step / 15 * 3600)
        }
        return time.timeIntervalSince(transit) >= 0 ? time : nil
    }

    /// To the nearest whole minute, as schedules print them.
    static func rounded(_ date: Date) -> Date {
        Date(timeIntervalSince1970: (date.timeIntervalSince1970 / 60).rounded() * 60)
    }

    // MARK: Next and current

    /// Every time of the days given, in order.
    static func moments(_ schedules: [PrayerSchedule?]) -> [PrayerMoment] {
        schedules.compactMap { $0 }.flatMap(\.moments).sorted { $0.time < $1.time }
    }

    /// The first of `among` after `now`, across the days given (today and
    /// tomorrow, so the evening finds tomorrow's Fajr).
    static func next(after now: Date, in moments: [PrayerMoment],
                     among prayers: [Prayer] = Prayer.obligatory) -> PrayerMoment? {
        moments.first { $0.time > now && prayers.contains($0.prayer) }
    }

    /// The prayer whose time is under way: the last of the five at or before
    /// `now`. Sunrise ends Fajr's time, so between sunrise and Dhuhr there is none.
    static func current(at now: Date, in moments: [PrayerMoment]) -> PrayerMoment? {
        guard let last = moments.last(where: { $0.time <= now && ($0.prayer == .sunrise || Prayer.obligatory.contains($0.prayer)) })
        else { return nil }
        return last.prayer == .sunrise ? nil : last
    }

    // MARK: The closed island

    /// "Waktunya Dzuhur" stays this long after the time.
    static let arrivalDuration: TimeInterval = 120
    static let leadChoices = [10, 15, 30]
    static let defaultLead = 10

    enum Activity: Equatable {
        /// Counting down to the time, within the lead.
        case upcoming(PrayerMoment)
        /// The time has come.
        case arrived(PrayerMoment)

        var moment: PrayerMoment {
            switch self {
            case .upcoming(let moment), .arrived(let moment): return moment
            }
        }
    }

    /// What the closed island shows at `now` for the prayers reminded of: the
    /// arrival while it lasts, otherwise the next one once it is within
    /// `leadMinutes`.
    static func activity(at now: Date, moments: [PrayerMoment], reminded: Set<Prayer>,
                         leadMinutes: Int) -> Activity? {
        let shown = moments.filter { reminded.contains($0.prayer) }
        if let arrived = shown.last(where: { $0.time <= now && now.timeIntervalSince($0.time) < arrivalDuration }) {
            return .arrived(arrived)
        }
        let lead = TimeInterval(max(0, leadMinutes)) * 60
        if let next = shown.first(where: { $0.time > now }), next.time.timeIntervalSince(now) <= lead {
            return .upcoming(next)
        }
        return nil
    }

    /// The next instant the island's activity may change: a lead starting, a
    /// time arriving, an arrival ending. Nil when nothing is ahead.
    static func nextChange(after now: Date, moments: [PrayerMoment], reminded: Set<Prayer>,
                           leadMinutes: Int) -> Date? {
        let lead = TimeInterval(max(0, leadMinutes)) * 60
        return moments.filter { reminded.contains($0.prayer) }
            .flatMap { [$0.time.addingTimeInterval(-lead), $0.time, $0.time.addingTimeInterval(arrivalDuration)] }
            .filter { $0 > now }
            .min()
    }

    // MARK: Formats

    /// A countdown for the island: `-12:04`, `-1:12:04`; whole seconds up, so
    /// it reaches `-0:00`'s place only at the time itself.
    static func countdown(_ interval: TimeInterval) -> String {
        let seconds = interval.isFinite ? Int(max(0, min(interval, 86_400 * 2)).rounded(.up)) : 0
        if seconds >= 3600 {
            return String(format: "-%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
        }
        return String(format: "-%d:%02d", seconds / 60, seconds % 60)
    }

    /// The widest the countdown gets in its range: under an hour or over it.
    static func countdownTemplate(long: Bool) -> String { long ? "-00:00:00" : "-00:00" }

    /// Whole minutes left, rounded up: 32 for 31 minutes and a few seconds.
    static func minutesLeft(_ interval: TimeInterval) -> Int {
        guard interval.isFinite, interval > 0 else { return 0 }
        return Int((interval / 60).rounded(.up))
    }

    /// `1h 04m` or `32m`, for the page's quieter readings.
    static func shortDuration(_ interval: TimeInterval) -> String {
        let minutes = minutesLeft(interval)
        return minutes >= 60 ? String(format: "%dh %02dm", minutes / 60, minutes % 60) : "\(minutes)m"
    }

    /// A time of day as the schedule shows it, in the person's time zone and locale.
    static func clock(_ date: Date, timeZone: TimeZone = .current, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("jmm")
        return formatter.string(from: date)
    }

    /// The readout line: `ashar 15:04 · in 1h 04m`, or `isya now` at the time.
    static func terminalValue(_ moment: PrayerMoment, now: Date, indonesian: Bool,
                              timeZone: TimeZone = .current) -> String {
        let name = moment.prayer.terminalName(indonesian: indonesian)
        let interval = moment.time.timeIntervalSince(now)
        if interval <= 0 { return name + " now" }
        return name + " " + terminalClock(moment.time, timeZone: timeZone) + " · in " + shortDuration(interval)
    }

    /// 24-hour `HH:mm`, as a command line's output would print it.
    static func terminalClock(_ date: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    // MARK: Names

    enum NameStyle: String, CaseIterable, Identifiable {
        /// Indonesian names on a Mac set to Indonesian, or in Indonesia.
        case automatic
        case indonesian
        /// The app language's names.
        case app

        var id: String { rawValue }
    }

    /// Whether the names are Indonesian: chosen, or by the Mac's own
    /// preferred languages and region.
    static func usesIndonesian(_ style: NameStyle, preferredLanguages: [String] = Locale.preferredLanguages,
                               region: String? = Locale.current.region?.identifier) -> Bool {
        switch style {
        case .indonesian: return true
        case .app: return false
        case .automatic:
            return region == "ID" || preferredLanguages.contains { $0 == "id" || $0.hasPrefix("id-") }
        }
    }
}

// MARK: - Places

/// A major Indonesian city, for those who keep Location Services off.
struct SkyCity: Equatable, Identifiable {
    let id: String
    let name: String
    let coordinate: SolarSupport.Coordinate

    static let all: [SkyCity] = [
        SkyCity(id: "jakarta", name: "Jakarta", coordinate: .init(latitude: -6.21, longitude: 106.85)),
        SkyCity(id: "bogor", name: "Bogor", coordinate: .init(latitude: -6.60, longitude: 106.80)),
        SkyCity(id: "bandung", name: "Bandung", coordinate: .init(latitude: -6.92, longitude: 107.62)),
        SkyCity(id: "semarang", name: "Semarang", coordinate: .init(latitude: -6.97, longitude: 110.42)),
        SkyCity(id: "yogyakarta", name: "Yogyakarta", coordinate: .init(latitude: -7.80, longitude: 110.37)),
        SkyCity(id: "surabaya", name: "Surabaya", coordinate: .init(latitude: -7.26, longitude: 112.75)),
        SkyCity(id: "denpasar", name: "Denpasar", coordinate: .init(latitude: -8.67, longitude: 115.21)),
        SkyCity(id: "mataram", name: "Mataram", coordinate: .init(latitude: -8.58, longitude: 116.12)),
        SkyCity(id: "kupang", name: "Kupang", coordinate: .init(latitude: -10.18, longitude: 123.61)),
        SkyCity(id: "banda-aceh", name: "Banda Aceh", coordinate: .init(latitude: 5.55, longitude: 95.32)),
        SkyCity(id: "medan", name: "Medan", coordinate: .init(latitude: 3.59, longitude: 98.67)),
        SkyCity(id: "pematangsiantar", name: "Pematangsiantar", coordinate: .init(latitude: 2.96, longitude: 99.07)),
        SkyCity(id: "padang", name: "Padang", coordinate: .init(latitude: -0.95, longitude: 100.42)),
        SkyCity(id: "pekanbaru", name: "Pekanbaru", coordinate: .init(latitude: 0.51, longitude: 101.45)),
        SkyCity(id: "batam", name: "Batam", coordinate: .init(latitude: 1.13, longitude: 104.05)),
        SkyCity(id: "palembang", name: "Palembang", coordinate: .init(latitude: -2.98, longitude: 104.78)),
        SkyCity(id: "bandar-lampung", name: "Bandar Lampung", coordinate: .init(latitude: -5.40, longitude: 105.27)),
        SkyCity(id: "pontianak", name: "Pontianak", coordinate: .init(latitude: -0.03, longitude: 109.34)),
        SkyCity(id: "banjarmasin", name: "Banjarmasin", coordinate: .init(latitude: -3.32, longitude: 114.59)),
        SkyCity(id: "balikpapan", name: "Balikpapan", coordinate: .init(latitude: -1.24, longitude: 116.85)),
        SkyCity(id: "makassar", name: "Makassar", coordinate: .init(latitude: -5.15, longitude: 119.43)),
        SkyCity(id: "manado", name: "Manado", coordinate: .init(latitude: 1.47, longitude: 124.84)),
        SkyCity(id: "ambon", name: "Ambon", coordinate: .init(latitude: -3.70, longitude: 128.18)),
        SkyCity(id: "jayapura", name: "Jayapura", coordinate: .init(latitude: -2.53, longitude: 140.72)),
    ]

    static let defaultID = "jakarta"

    static func named(_ id: String?) -> SkyCity? { all.first { $0.id == id } }
}

/// Where the times are for.
enum SkyLocationSource: String, CaseIterable, Identifiable {
    /// The weather's approximate location (WeatherService), rounded to about a kilometre.
    case automatic
    case city
    /// A latitude and longitude typed in.
    case custom

    var id: String { rawValue }
}

struct SkyPlace: Equatable {
    let coordinate: SolarSupport.Coordinate
    /// A chosen city's name; nil for an approximate or typed position,
    /// whose place is never named.
    let name: String?
}

// MARK: - Settings

/// Every Sky preference, read once from the defaults.
struct SkySettings: Equatable {
    var configuration = PrayerConfiguration()
    var source: SkyLocationSource = .automatic
    var cityID = SkyCity.defaultID
    var customLatitude = -6.2
    var customLongitude = 106.8
    var names: PrayerTimesSupport.NameStyle = .automatic
    var reminded: Set<Prayer> = Set(Prayer.remindedByDefault)
    var prayerActivity = true
    var leadMinutes = PrayerTimesSupport.defaultLead
    var sound = false
    var goldenActivity = true

    static let defaultReminded = Prayer.remindedByDefault.map(\.rawValue).joined(separator: ",")
    static let defaultAdjustments = PrayerAdjustments().encoded

    static func current(in defaults: UserDefaults = .standard) -> SkySettings {
        var settings = SkySettings()
        settings.configuration.method = PrayerMethod(rawValue: defaults.string(forKey: DefaultsKey.notchSkyMethod) ?? "") ?? .kemenag
        settings.configuration.asr = PrayerAsrSchool(rawValue: defaults.string(forKey: DefaultsKey.notchSkyAsr) ?? "") ?? .shafii
        settings.configuration.adjustments = PrayerAdjustments.decode(defaults.string(forKey: DefaultsKey.notchSkyAdjustments))
        settings.source = SkyLocationSource(rawValue: defaults.string(forKey: DefaultsKey.notchSkyLocationSource) ?? "") ?? .automatic
        settings.cityID = SkyCity.named(defaults.string(forKey: DefaultsKey.notchSkyCity))?.id ?? SkyCity.defaultID
        if let latitude = defaults.object(forKey: DefaultsKey.notchSkyLatitude) as? Double { settings.customLatitude = latitude }
        if let longitude = defaults.object(forKey: DefaultsKey.notchSkyLongitude) as? Double { settings.customLongitude = longitude }
        settings.names = PrayerTimesSupport.NameStyle(rawValue: defaults.string(forKey: DefaultsKey.notchSkyNames) ?? "") ?? .automatic
        settings.reminded = decodeReminded(defaults.string(forKey: DefaultsKey.notchSkyReminded))
        settings.prayerActivity = defaults.object(forKey: DefaultsKey.notchSkyPrayerActivity) as? Bool ?? true
        let lead = defaults.integer(forKey: DefaultsKey.notchSkyPrayerLead)
        settings.leadMinutes = PrayerTimesSupport.leadChoices.contains(lead) ? lead : PrayerTimesSupport.defaultLead
        settings.sound = defaults.bool(forKey: DefaultsKey.notchSkyPrayerSound)
        settings.goldenActivity = defaults.object(forKey: DefaultsKey.notchSkyGoldenActivity) as? Bool ?? true
        return settings
    }

    /// The prayers reminded of; sunrise and unknown names are skipped. Nil
    /// (never stored) is the default; an empty string is none.
    static func decodeReminded(_ stored: String?) -> Set<Prayer> {
        guard let stored else { return Set(Prayer.remindedByDefault) }
        return Set(stored.split(separator: ",").compactMap {
            Prayer(rawValue: $0.trimmingCharacters(in: .whitespaces))
        }.filter { Prayer.remindable.contains($0) })
    }

    static func encodeReminded(_ prayers: Set<Prayer>) -> String {
        Prayer.remindable.filter(prayers.contains).map(\.rawValue).joined(separator: ",")
    }

    /// The place the times are for: the chosen city, the typed position, or
    /// the weather's approximate one when there is one.
    func place(automatic: SolarSupport.Coordinate?) -> SkyPlace? {
        switch source {
        case .automatic:
            return automatic.flatMap { $0.isValid ? SkyPlace(coordinate: $0, name: nil) : nil }
        case .city:
            return SkyCity.named(cityID).map { SkyPlace(coordinate: $0.coordinate, name: $0.name) }
        case .custom:
            let coordinate = SolarSupport.Coordinate(latitude: customLatitude, longitude: customLongitude)
            return coordinate.isValid ? SkyPlace(coordinate: coordinate, name: nil) : nil
        }
    }
}

// MARK: - The day

/// Everything the Sky views and the island read for one day and place:
/// yesterday's, today's and tomorrow's times, and today's and tomorrow's
/// golden and blue windows. Worked out once per day, place and method.
struct SkyDay: Equatable {
    let place: SkyPlace
    let configuration: PrayerConfiguration
    /// Local midnight that starts the day.
    let start: Date
    let today: PrayerSchedule?
    let moments: [PrayerMoment]
    let windows: [SolarSupport.Window]
    let tomorrowWindows: [SolarSupport.Window]

    static func make(containing date: Date, place: SkyPlace, configuration: PrayerConfiguration,
                     calendar: Calendar = .current) -> SkyDay {
        let start = calendar.startOfDay(for: date)
        func noon(_ offset: Int) -> Date {
            let day = calendar.date(byAdding: .day, value: offset, to: start) ?? start.addingTimeInterval(Double(offset) * 86_400)
            return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day.addingTimeInterval(12 * 3600)
        }
        let coordinate = place.coordinate
        let yesterday = PrayerTimesSupport.schedule(noon: noon(-1), coordinate: coordinate, configuration: configuration)
        let today = PrayerTimesSupport.schedule(noon: noon(0), coordinate: coordinate, configuration: configuration)
        let tomorrow = PrayerTimesSupport.schedule(noon: noon(1), coordinate: coordinate, configuration: configuration)
        return SkyDay(place: place, configuration: configuration, start: start, today: today,
                      moments: PrayerTimesSupport.moments([yesterday, today, tomorrow]),
                      windows: SolarSupport.windows(noon: noon(0), coordinate: coordinate),
                      tomorrowWindows: SolarSupport.windows(noon: noon(1), coordinate: coordinate))
    }

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(date, inSameDayAs: start)
    }

    /// The next golden or blue windows not yet over: the rest of today's,
    /// then tomorrow morning's.
    func upcomingWindows(after now: Date) -> [SolarSupport.Window] {
        (windows + tomorrowWindows.filter(\.morning)).filter { $0.end > now }
    }
}

// MARK: - Golden hour in the closed island

enum SkyGoldenSupport {
    /// The evening's golden hour shows this long before it starts.
    static let lead: TimeInterval = 30 * 60

    enum Activity: Equatable {
        case upcoming(SolarSupport.Window)
        case during(SolarSupport.Window)

        var window: SolarSupport.Window {
            switch self {
            case .upcoming(let window), .during(let window): return window
            }
        }
    }

    /// The evening golden hour at `now`: coming within the lead, or under way.
    static func activity(at now: Date, windows: [SolarSupport.Window]) -> Activity? {
        for window in windows where window.band == .golden && !window.morning {
            if window.contains(now) { return .during(window) }
            let wait = window.start.timeIntervalSince(now)
            if wait > 0, wait <= lead { return .upcoming(window) }
        }
        return nil
    }

    static func nextChange(after now: Date, windows: [SolarSupport.Window]) -> Date? {
        windows.filter { $0.band == .golden && !$0.morning }
            .flatMap { [$0.start.addingTimeInterval(-lead), $0.start, $0.end] }
            .filter { $0 > now }
            .min()
    }

    /// The readout line: `golden 17:23–17:55 · in 32m`, `golden now · 18m left`.
    static func terminalValue(_ windows: [SolarSupport.Window], now: Date, timeZone: TimeZone = .current) -> String? {
        guard let window = windows.first(where: { $0.band == .golden && $0.end > now }) else { return nil }
        if window.contains(now) { return "now · " + PrayerTimesSupport.shortDuration(window.end.timeIntervalSince(now)) + " left" }
        return PrayerTimesSupport.terminalClock(window.start, timeZone: timeZone) + "–"
            + PrayerTimesSupport.terminalClock(window.end, timeZone: timeZone)
            + " · in " + PrayerTimesSupport.shortDuration(window.start.timeIntervalSince(now))
    }

    /// The sun's elevation for the page: `12.4°`, `−3.1°`, with the locale's decimal mark.
    static func elevationText(_ degrees: Double, locale: Locale = Locale(identifier: "en_US_POSIX")) -> String {
        guard degrees.isFinite else { return "–°" }
        let value = (degrees * 10).rounded() / 10
        let text = String(format: "%.1f°", locale: locale, abs(value))
        return value < 0 ? "−" + text : text
    }
}

/// The Sky page's least height in the island (the page is in SkyPage).
enum SkyPageMetrics {
    static let minimumHeight: CGFloat = 196
}
