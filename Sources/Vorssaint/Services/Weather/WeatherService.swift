// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
//
// The one-shot, coarse location request follows Atoll's
// LockScreenWeatherLocationProvider (Ebullioscopic/Atoll,
// DynamicIsland/managers/LockScreenWeatherManager.swift, GPL-3.0-or-later).

import AppKit
import CoreLocation

/// Zenith fork: the weather on the lock screen.
///
/// Location permission is asked for only when the lock screen's Weather switch
/// is turned on. Nothing runs in the background: the lock screen asks for a
/// read when it shows (if the last one is older than 30 minutes) and every 30
/// minutes while it stays. Each read asks Location Services for a coarse
/// position (or reuses one under an hour old), rounds it to about a kilometre
/// and sends only that to Open-Meteo. The rounded position is kept on this Mac
/// (not in settings backups) so a read can go ahead when no fix comes.
@MainActor
final class WeatherService: NSObject, ObservableObject {
    static let shared = WeatherService()

    @Published private(set) var snapshot: WeatherSupport.Snapshot?
    @Published private(set) var access: LockScreenWidgetAccess = .notDetermined

    /// The last rounded position and when it was fixed, on this Mac only.
    static let locationKey = "zenithWeatherLocation"

    /// Created on first need, so a Mac that never turns Weather on never makes one.
    private var manager: CLLocationManager?
    private var cachedLocation: (coordinate: WeatherSupport.Coordinate, fixed: Date)?
    private var request: Task<Void, Never>?
    private var timer: Timer?
    private var locateTimeout: Timer?
    private var locating = false
    /// The lock screen shows the weather, or the home page's widget does.
    private var lockShowing = false
    private var homeShowing = false
    private var showing: Bool { lockShowing || homeShowing }

    private override init() {
        super.init()
        if let stored = UserDefaults.standard.dictionary(forKey: Self.locationKey),
           let latitude = stored["latitude"] as? Double, let longitude = stored["longitude"] as? Double,
           let fixed = stored["fixed"] as? Double {
            let coordinate = WeatherSupport.Coordinate(latitude: latitude, longitude: longitude)
            if coordinate.isValid { cachedLocation = (coordinate, Date(timeIntervalSince1970: fixed)) }
        }
    }

    private func locationManager() -> CLLocationManager {
        if let manager { return manager }
        let manager = CLLocationManager()
        // City level is plenty for a forecast and spares the radios.
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        manager.delegate = self
        self.manager = manager
        return manager
    }

    // MARK: Permission

    /// Reads the current status; never prompts.
    @discardableResult
    func refreshAccess() -> LockScreenWidgetAccess {
        let current = LockScreenWidgetAccess(location: locationManager().authorizationStatus)
        if access != current { access = current }
        return current
    }

    /// Asks macOS once, when the person turns Weather on. Afterwards only
    /// System Settings can change the answer.
    func requestAccess() {
        guard refreshAccess() == .notDetermined else { return }
        locationManager().requestWhenInUseAuthorization()
    }

    func openLocationSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")!
        NSWorkspace.shared.open(url)
    }

    // MARK: Lock screen

    func lockScreenShown() {
        lockShowing = true
        resume()
    }

    func lockScreenHidden() {
        lockShowing = false
        pauseIfHidden()
    }

    // MARK: Home page

    /// The home page's weather widget came into view: the same reads as the
    /// lock screen's, for as long as it shows. Never asks for access.
    func homeShown() {
        homeShowing = true
        resume()
    }

    func homeHidden() {
        homeShowing = false
        pauseIfHidden()
    }

    private func resume() {
        guard refreshAccess() == .granted else { return }
        if WeatherSupport.isFresh(snapshot, now: Date()) {
            schedule(after: WeatherSupport.refreshInterval - Date().timeIntervalSince(snapshot?.fetched ?? Date()))
        } else {
            refresh()
        }
    }

    private func pauseIfHidden() {
        guard !showing else { return }
        timer?.invalidate()
        timer = nil
        finishLocating(with: nil, fetches: false)
    }

    private func schedule(after interval: TimeInterval) {
        timer?.invalidate()
        guard showing else { timer = nil; return }
        let timer = Timer(timeInterval: max(60, interval), repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        timer.tolerance = 60
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func refresh() {
        guard showing, request == nil, !locating else { return }
        guard access == .granted else { return }
        if let cachedLocation, WeatherSupport.isLocationFresh(fixed: cachedLocation.fixed, now: Date()) {
            fetch(cachedLocation.coordinate)
            return
        }
        locating = true
        locationManager().requestLocation()
        // No fix in time (no Wi-Fi nearby, Location Services busy): use the last position.
        let timeout = Timer(timeInterval: 20, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.finishLocating(with: nil, fetches: true) }
        }
        RunLoop.main.add(timeout, forMode: .common)
        locateTimeout = timeout
    }

    private func finishLocating(with coordinate: WeatherSupport.Coordinate?, fetches: Bool) {
        guard locating else { return }
        locating = false
        locateTimeout?.invalidate()
        locateTimeout = nil
        if let coordinate, coordinate.isValid {
            let place = WeatherSupport.coarse(coordinate)
            let now = Date()
            cachedLocation = (place, now)
            UserDefaults.standard.set(["latitude": place.latitude, "longitude": place.longitude,
                                       "fixed": now.timeIntervalSince1970], forKey: Self.locationKey)
        }
        guard fetches else { return }
        if let place = cachedLocation?.coordinate {
            fetch(place)
        } else {
            schedule(after: WeatherSupport.retryInterval)
        }
    }

    private func fetch(_ coordinate: WeatherSupport.Coordinate) {
        guard let url = WeatherSupport.forecastURL(for: coordinate) else { return }
        var urlRequest = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        urlRequest.setValue("\(AppInfo.name)/\(AppInfo.version)", forHTTPHeaderField: "User-Agent")
        let sent = urlRequest
        request = Task { [weak self] in
            let snapshot = await Self.read(sent)
            guard let self, !Task.isCancelled else { return }
            self.request = nil
            // A failed read keeps the last one, which hides itself once too old.
            if let snapshot { self.snapshot = snapshot }
            self.schedule(after: snapshot == nil ? WeatherSupport.retryInterval : WeatherSupport.refreshInterval)
        }
    }

    private nonisolated static func read(_ request: URLRequest) async -> WeatherSupport.Snapshot? {
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let status = (response as? HTTPURLResponse)?.statusCode, (200..<300).contains(status) else { return nil }
        return WeatherSupport.snapshot(from: data, fetched: Date())
    }

    private func forgetLocation() {
        cachedLocation = nil
        snapshot = nil
        UserDefaults.standard.removeObject(forKey: Self.locationKey)
    }
}

extension WeatherService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            guard let self else { return }
            let current = LockScreenWidgetAccess(location: status)
            if self.access != current { self.access = current }
            // Permission taken back: nothing about where the Mac was stays behind.
            if current == .denied { self.forgetLocation() }
            if current == .granted, self.showing, self.snapshot == nil { self.refresh() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coordinate = locations.last.map {
            WeatherSupport.Coordinate(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
        }
        Task { @MainActor [weak self] in self?.finishLocating(with: coordinate, fetches: true) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in self?.finishLocating(with: nil, fetches: true) }
    }
}
