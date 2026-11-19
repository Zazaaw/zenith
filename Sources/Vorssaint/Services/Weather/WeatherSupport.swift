// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
//
// The weather-code symbols start from Atoll's Open-Meteo mapping
// (Ebullioscopic/Atoll, DynamicIsland/managers/LockScreenWeatherManager.swift,
// GPL-3.0-or-later), with day and night variants for clear and showery skies.

import Foundation

/// Zenith fork: the lock screen's weather, everything that needs neither the
/// network nor a location. `WeatherService` does the fetching.
enum WeatherSupport {
    /// How often the lock screen reads the weather while it shows.
    static let refreshInterval: TimeInterval = 30 * 60
    /// After a failed read, the next try comes sooner.
    static let retryInterval: TimeInterval = 5 * 60
    /// A reading older than this is no longer shown: stale weather misleads.
    static let maximumAge: TimeInterval = 3 * 60 * 60
    /// A cached position is reused this long before Location Services is asked again.
    static let locationMaximumAge: TimeInterval = 60 * 60
    static let forecastEndpoint = "https://api.open-meteo.com/v1/forecast"

    struct Coordinate: Equatable {
        var latitude: Double
        var longitude: Double

        var isValid: Bool {
            latitude.isFinite && longitude.isFinite && abs(latitude) <= 90 && abs(longitude) <= 180
        }
    }

    /// Two decimals, about a kilometre: enough for a forecast, never a street.
    /// Only this rounded position is kept or sent.
    static func coarse(_ coordinate: Coordinate) -> Coordinate {
        func round(_ value: Double) -> Double { (value * 100).rounded() / 100 }
        return Coordinate(latitude: round(coordinate.latitude), longitude: round(coordinate.longitude))
    }

    /// Open-Meteo's forecast for one place, in Celsius (converted on display, so
    /// a unit change needs no new read), today only.
    static func forecastURL(for coordinate: Coordinate) -> URL? {
        guard coordinate.isValid else { return nil }
        let place = coarse(coordinate)
        var components = URLComponents(string: forecastEndpoint)
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(place.latitude)),
            URLQueryItem(name: "longitude", value: String(place.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day"),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "1"),
        ]
        return components?.url
    }

    struct Snapshot: Equatable {
        /// Celsius, as Open-Meteo sends it by default.
        var temperature: Double
        var code: Int
        var isDay: Bool
        var high: Double?
        var low: Double?
        var fetched: Date
    }

    private struct Response: Decodable {
        struct Current: Decodable {
            let temperature: Double
            let code: Int
            let isDay: Int?

            enum CodingKeys: String, CodingKey {
                case temperature = "temperature_2m", code = "weather_code", isDay = "is_day"
            }
        }

        struct Daily: Decodable {
            let high: [Double?]?
            let low: [Double?]?

            enum CodingKeys: String, CodingKey {
                case high = "temperature_2m_max", low = "temperature_2m_min"
            }
        }

        let current: Current
        let daily: Daily?
    }

    static func snapshot(from data: Data, fetched: Date) -> Snapshot? {
        guard let response = try? JSONDecoder().decode(Response.self, from: data),
              response.current.temperature.isFinite else { return nil }
        let high = response.daily?.high?.first ?? nil
        let low = response.daily?.low?.first ?? nil
        return Snapshot(temperature: response.current.temperature, code: response.current.code,
                        isDay: response.current.isDay != 0,
                        high: high.flatMap { $0.isFinite ? $0 : nil }, low: low.flatMap { $0.isFinite ? $0 : nil },
                        fetched: fetched)
    }

    /// The SF Symbol for a WMO weather code, as Open-Meteo reports it.
    static func symbol(code: Int, isDay: Bool) -> String {
        switch code {
        case 0: return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1, 2: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 56, 57, 66, 67: return "cloud.sleet.fill"
        case 61, 63: return "cloud.rain.fill"
        case 65, 82: return "cloud.heavyrain.fill"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
        case 80, 81: return isDay ? "cloud.sun.rain.fill" : "cloud.moon.rain.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    static func convert(_ celsius: Double, to unit: TemperatureUnit) -> Double {
        switch unit {
        case .celsius: return celsius
        case .fahrenheit: return celsius * 9 / 5 + 32
        }
    }

    /// "31°": whole degrees in the person's unit, never "-0°".
    static func degrees(_ celsius: Double, unit: TemperatureUnit) -> String {
        let value = convert(celsius, to: unit)
        guard value.isFinite else { return "–°" }
        let whole = Int(value.rounded())
        return "\(whole == 0 ? 0 : whole)°"
    }

    /// Fresh enough that showing the lock screen again reads nothing.
    static func isFresh(_ snapshot: Snapshot?, now: Date) -> Bool {
        guard let snapshot else { return false }
        let age = now.timeIntervalSince(snapshot.fetched)
        return age >= 0 && age < refreshInterval
    }

    /// Recent enough to show at all.
    static func isShowable(_ snapshot: Snapshot?, now: Date) -> Bool {
        guard let snapshot else { return false }
        let age = now.timeIntervalSince(snapshot.fetched)
        return age >= -60 && age < maximumAge
    }

    static func isLocationFresh(fixed: Date, now: Date) -> Bool {
        let age = now.timeIntervalSince(fixed)
        return age >= 0 && age < locationMaximumAge
    }
}
