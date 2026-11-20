// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
//
// The solar position follows the low-precision formulas of Jean Meeus,
// Astronomical Algorithms (2nd ed., chapters 25 and 28), as NOAA's solar
// calculator states them: the sun's apparent longitude, the obliquity of the
// ecliptic, the declination and the equation of time. Written here from the
// published formulas; no code is taken from either.

import Foundation

/// Zenith fork: where the sun is, for prayer times (PrayerTimesSupport) and
/// for a photographer's golden and blue hours. Pure: Foundation only, offline,
/// compiled into the tests.
///
/// Elevations are geometric (the sun's centre, no refraction), as twilight
/// is defined. Sunrise and sunset take the usual −0.833°: the upper limb on a
/// level horizon through average refraction. Every function returns nil or a
/// finite value; none returns NaN, even at the poles.
enum SolarSupport {
    struct Coordinate: Equatable, Hashable {
        var latitude: Double
        var longitude: Double

        var isValid: Bool {
            latitude.isFinite && longitude.isFinite && abs(latitude) <= 90 && abs(longitude) <= 180
        }
    }

    /// The sun's declination (degrees) and the equation of time (minutes) at one instant.
    struct Position: Equatable {
        var declination: Double
        var equationOfTime: Double
    }

    /// The altitude of sunrise and sunset: half the sun's disc (16′) below a
    /// level horizon, lifted by average refraction (34′).
    static let horizon = -0.8333

    private static let radians = Double.pi / 180

    static func julianDay(_ date: Date) -> Double {
        date.timeIntervalSince1970 / 86_400 + 2_440_587.5
    }

    static func position(at date: Date) -> Position {
        let t = (julianDay(date) - 2_451_545) / 36_525
        let meanLongitude = normalized(280.46646 + t * (36_000.76983 + 0.0003032 * t))
        let anomaly = 357.52911 + t * (35_999.05029 - 0.0001537 * t)
        let eccentricity = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)
        let m = anomaly * radians
        let centre = sin(m) * (1.914602 - t * (0.004817 + 0.000014 * t))
            + sin(2 * m) * (0.019993 - 0.000101 * t) + sin(3 * m) * 0.000289
        let omega = (125.04 - 1934.136 * t) * radians
        let apparentLongitude = (meanLongitude + centre - 0.00569 - 0.00478 * sin(omega)) * radians
        let meanObliquity = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60
        let obliquity = (meanObliquity + 0.00256 * cos(omega)) * radians
        let declination = asin(sin(obliquity) * sin(apparentLongitude)) / radians
        let y = pow(tan(obliquity / 2), 2)
        let l0 = meanLongitude * radians
        let equation = y * sin(2 * l0) - 2 * eccentricity * sin(m) + 4 * eccentricity * y * sin(m) * cos(2 * l0)
            - 0.5 * y * y * sin(4 * l0) - 1.25 * eccentricity * eccentricity * sin(2 * m)
        return Position(declination: declination, equationOfTime: 4 * equation / radians)
    }

    /// The sun's hour angle in degrees, −180 to 180: negative before local
    /// solar noon, positive after.
    static func hourAngle(at date: Date, longitude: Double) -> Double {
        let seconds = date.timeIntervalSince1970.truncatingRemainder(dividingBy: 86_400)
        let utcMinutes = (seconds < 0 ? seconds + 86_400 : seconds) / 60
        let solarMinutes = utcMinutes + position(at: date).equationOfTime + 4 * longitude
        return signed(solarMinutes / 4 - 180)
    }

    /// The sun's geometric elevation above the horizon, in degrees.
    static func elevation(at date: Date, coordinate: Coordinate) -> Double {
        let position = position(at: date)
        let latitude = coordinate.latitude * radians
        let declination = position.declination * radians
        let hour = hourAngle(at: date, longitude: coordinate.longitude) * radians
        let value = sin(latitude) * sin(declination) + cos(latitude) * cos(declination) * cos(hour)
        return asin(min(1, max(-1, value))) / radians
    }

    /// Local solar noon nearest `date`: the sun on the meridian.
    static func transit(near date: Date, longitude: Double) -> Date {
        var time = date
        for _ in 0..<4 {
            time = time.addingTimeInterval(-hourAngle(at: time, longitude: longitude) / 15 * 3600)
        }
        return time
    }

    /// When the sun's centre stands at `altitude` on the day around `noon`
    /// (any instant near local noon), rising before the transit or setting
    /// after it. Nil when the sun never reaches that altitude that day.
    static func time(at altitude: Double, rising: Bool, noon: Date, coordinate: Coordinate) -> Date? {
        guard coordinate.isValid, altitude.isFinite else { return nil }
        let transit = transit(near: noon, longitude: coordinate.longitude)
        var time = transit
        for _ in 0..<6 {
            guard let target = hourAngle(for: altitude, latitude: coordinate.latitude,
                                         declination: position(at: time).declination) else { return nil }
            let wanted = rising ? -target : target
            let step = signed(wanted - hourAngle(at: time, longitude: coordinate.longitude))
            time = time.addingTimeInterval(step / 15 * 3600)
        }
        // Stays on its own side of the transit, so a rising time is never after noon.
        let offset = time.timeIntervalSince(transit)
        guard offset.isFinite, rising ? offset <= 0 : offset >= 0 else { return nil }
        return time
    }

    /// The hour angle (degrees, 0 to 180) at which the sun stands at
    /// `altitude`; nil when it stays above or below it all day.
    static func hourAngle(for altitude: Double, latitude: Double, declination: Double) -> Double? {
        let phi = latitude * radians, delta = declination * radians
        let denominator = cos(phi) * cos(delta)
        guard abs(denominator) > 1e-9 else { return nil }
        let value = (sin(altitude * radians) - sin(phi) * sin(delta)) / denominator
        guard value.isFinite, value >= -1, value <= 1 else { return nil }
        return acos(value) / radians
    }

    /// The sun's highest elevation on the day around `noon`.
    static func noonElevation(noon: Date, coordinate: Coordinate) -> Double {
        elevation(at: transit(near: noon, longitude: coordinate.longitude), coordinate: coordinate)
    }

    // MARK: Golden and blue hours

    /// Golden hour: the sun between −4° and +6°, its light low and warm.
    /// Blue hour: between −6° and −4°, the sky deep blue after sunset or
    /// before sunrise.
    enum Band: String, Equatable {
        case golden, blue

        var lower: Double { self == .golden ? -4 : -6 }
        var upper: Double { self == .golden ? 6 : -4 }
    }

    struct Window: Equatable, Identifiable {
        let band: Band
        let morning: Bool
        let start: Date
        let end: Date

        var id: String { "\(band.rawValue)-\(morning ? "am" : "pm")-\(Int(start.timeIntervalSince1970))" }
        var duration: TimeInterval { end.timeIntervalSince(start) }
        func contains(_ date: Date) -> Bool { date >= start && date < end }
    }

    /// The day's golden and blue windows in time order: morning blue, morning
    /// golden, evening golden, evening blue. A band whose edge the sun never
    /// crosses that day (a polar summer or winter) is left out; when the sun
    /// stays under +6° all day, one golden window runs from its rising
    /// through −4° to its setting through it.
    static func windows(noon: Date, coordinate: Coordinate) -> [Window] {
        guard coordinate.isValid else { return [] }
        func at(_ altitude: Double, _ rising: Bool) -> Date? {
            time(at: altitude, rising: rising, noon: noon, coordinate: coordinate)
        }
        var windows: [Window] = []
        let riseBlue = at(Band.blue.lower, true), riseGolden = at(Band.golden.lower, true), riseHigh = at(Band.golden.upper, true)
        let setHigh = at(Band.golden.upper, false), setGolden = at(Band.golden.lower, false), setBlue = at(Band.blue.lower, false)
        if let start = riseBlue, let end = riseGolden, end > start {
            windows.append(Window(band: .blue, morning: true, start: start, end: end))
        }
        if let start = riseGolden {
            if let end = riseHigh, end > start {
                windows.append(Window(band: .golden, morning: true, start: start, end: end))
            } else if riseHigh == nil, let end = setGolden, end > start {
                windows.append(Window(band: .golden, morning: true, start: start, end: end))
            }
        }
        if let start = setHigh, let end = setGolden, end > start {
            windows.append(Window(band: .golden, morning: false, start: start, end: end))
        }
        if let start = setGolden, let end = setBlue, end > start {
            windows.append(Window(band: .blue, morning: false, start: start, end: end))
        }
        return windows
    }

    /// The sun's elevation through the day, from local midnight to midnight
    /// in `count` even steps, for the path the page draws.
    static func path(midnight: Date, coordinate: Coordinate, count: Int = 49) -> [Double] {
        guard coordinate.isValid, count > 1 else { return [] }
        return (0..<count).map { index in
            elevation(at: midnight.addingTimeInterval(86_400 * Double(index) / Double(count - 1)), coordinate: coordinate)
        }
    }

    // MARK: Angles

    static func normalized(_ degrees: Double) -> Double {
        let value = degrees.truncatingRemainder(dividingBy: 360)
        return value < 0 ? value + 360 : value
    }

    /// An angle in −180 to 180.
    static func signed(_ degrees: Double) -> Double {
        let value = normalized(degrees + 180) - 180
        return value
    }
}
