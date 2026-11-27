// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import Combine

/// Zenith fork: prayer times and the golden hour, kept on time.
///
/// Everything is worked out on this Mac (PrayerTimesSupport, SolarSupport);
/// nothing is fetched. The place is a chosen city, a typed position, or the
/// weather's approximate location (WeatherService), whose permission flow it
/// shares: it never asks for access itself, and only asks Location Services
/// for a new fix when access is already granted.
///
/// While the island runs with the Sky section on, one timer waits for the
/// next moment the closed island's activity changes (a reminder's lead, a
/// prayer's time, the end of its arrival, the golden hour's lead, start and
/// end, midnight) and nothing else runs. At a prayer's time it shows a
/// capsule notice and, when asked for, plays a soft sound. The lock screen,
/// the home page and Settings read the same day without starting anything.
/// Used on the main thread, as the island's other services are.
final class SkyService: ObservableObject {
    static let shared = SkyService()

    /// The day the views show; nil without a place.
    @Published private(set) var day: SkyDay?
    @Published private(set) var settings = SkySettings.current()
    /// What the closed island shows; each changes only at a phase boundary,
    /// never with the countdown, so the island lays itself out once.
    @Published private(set) var prayerActivity: PrayerTimesSupport.Activity?
    @Published private(set) var goldenActivity: SkyGoldenSupport.Activity?

    private var running = false
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    /// The last prayer time announced, so a time is announced once.
    private var announced: PrayerMoment?
    private var sound: NSSound?

    /// How old the approximate position may be before a new fix is asked for:
    /// in the background, and when a view of the times appears.
    static let backgroundLocationAge: TimeInterval = 6 * 3600
    static let viewLocationAge: TimeInterval = 3600
    /// A time found later than this after it came (the Mac was asleep) is not announced.
    static let announcementGrace: TimeInterval = 90

    private init() {}

    /// WeatherService fixed a new approximate position or forgot it.
    func locationChanged() {
        DispatchQueue.main.async { [weak self] in self?.refresh() }
    }

    /// WeatherService's access changed: once granted, the first fix is asked for.
    func locationAccessChanged(granted: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if granted, self.settings.source == .automatic { self.locate(maximumAge: Self.viewLocationAge) }
            self.refresh()
        }
    }

    // MARK: Reading

    /// The day containing `now`, worked out again when the date, the place
    /// or a preference changed. Cheap when nothing did.
    func currentDay(now: Date = Date()) -> SkyDay? {
        guard let place = place() else { return nil }
        if let day, day.contains(now), day.place == place, day.configuration == settings.configuration { return day }
        // Views ask from inside their body: the published day catches up just after.
        DispatchQueue.main.async { [weak self] in self?.refresh() }
        return SkyDay.make(containing: now, place: place, configuration: settings.configuration)
    }

    private func place() -> SkyPlace? {
        let automatic = MainActor.assumeIsolated { WeatherService.shared.place }
        return settings.place(automatic: automatic.map {
            SolarSupport.Coordinate(latitude: $0.latitude, longitude: $0.longitude)
        })
    }

    /// Whether the names are Indonesian, by the setting and the Mac's language and region.
    var usesIndonesianNames: Bool { PrayerTimesSupport.usesIndonesian(settings.names) }

    func name(_ prayer: Prayer, language: AppLanguage) -> String {
        ZenithStrings.sky(language).name(prayer, indonesian: usesIndonesianNames)
    }

    // MARK: Lifecycle

    /// Called with every island preference sync.
    func syncWithPreferences() {
        settings = SkySettings.current()
        let wanted = NotchSupport.isEnabled() && NotchSupport.modules().contains(.sky)
        if wanted != running {
            running = wanted
            wanted ? observe() : unobserve()
        }
        if running, settings.source == .automatic { locate(maximumAge: Self.backgroundLocationAge) }
        refresh()
    }

    /// The island stopped.
    func stop() {
        running = false
        unobserve()
        timer?.invalidate()
        timer = nil
        if prayerActivity != nil { prayerActivity = nil }
        if goldenActivity != nil { goldenActivity = nil }
    }

    /// Settings changed one of the Sky preferences.
    func preferencesChanged() {
        settings = SkySettings.current()
        refresh()
    }

    /// A view of the times appeared (the page, a home widget, the lock screen,
    /// Settings): with the approximate location, an old fix is renewed.
    func viewShown() {
        if settings.source == .automatic { locate(maximumAge: Self.viewLocationAge) }
    }

    private func locate(maximumAge: TimeInterval) {
        MainActor.assumeIsolated { WeatherService.shared.locateForSky(maximumAge: maximumAge) }
    }

    private func observe() {
        unobserve()
        let center = NotificationCenter.default
        for name in [Notification.Name.NSCalendarDayChanged, .NSSystemTimeZoneDidChange, .NSSystemClockDidChange] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.refresh()
            })
        }
        // A Mac that slept through a boundary catches up as it wakes.
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                self?.refresh()
            })
    }

    private func unobserve() {
        observers.forEach {
            NotificationCenter.default.removeObserver($0)
            NSWorkspace.shared.notificationCenter.removeObserver($0)
        }
        observers.removeAll()
    }

    // MARK: Time

    private func refresh(now: Date = Date()) {
        if let place = place() {
            let configuration = settings.configuration
            if day == nil || day?.contains(now) != true || day?.place != place || day?.configuration != configuration {
                day = SkyDay.make(containing: now, place: place, configuration: configuration)
            }
        } else if day != nil {
            day = nil
        }
        update(now: now)
    }

    private func update(now: Date) {
        timer?.invalidate()
        timer = nil
        guard running, let day else {
            if prayerActivity != nil { prayerActivity = nil }
            if goldenActivity != nil { goldenActivity = nil }
            return
        }
        let reminded = settings.reminded
        let prayer = PrayerTimesSupport.activity(at: now, moments: day.moments, reminded: reminded,
                                                 leadMinutes: settings.leadMinutes)
        let golden = SkyGoldenSupport.activity(at: now, windows: day.windows)
        let shownPrayer = settings.prayerActivity ? prayer : nil
        let shownGolden = settings.goldenActivity ? golden : nil
        if prayerActivity != shownPrayer { prayerActivity = shownPrayer }
        if goldenActivity != shownGolden { goldenActivity = shownGolden }
        if case .arrived(let moment) = prayer { announce(moment, now: now) }

        let midnight = Calendar.current.date(byAdding: .day, value: 1, to: day.start) ?? now.addingTimeInterval(3600)
        let changes = [PrayerTimesSupport.nextChange(after: now, moments: day.moments, reminded: reminded,
                                                     leadMinutes: settings.leadMinutes),
                       SkyGoldenSupport.nextChange(after: now, windows: day.windows),
                       midnight.addingTimeInterval(1)].compactMap { $0 }
        guard let next = changes.min() else { return }
        let timer = Timer(fire: next.addingTimeInterval(0.05), interval: 0, repeats: false) { [weak self] _ in
            self?.refresh()
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    // MARK: The prayer's time

    private func announce(_ moment: PrayerMoment, now: Date) {
        guard announced != moment else { return }
        announced = moment
        guard now.timeIntervalSince(moment.time) < Self.announcementGrace else { return }
        // The pill beside the camera grows into the bigger island and shrinks
        // back (ZenithIslandBurst): one surface, never a capsule over the pill.
        NotchService.shared.showZenithBurst(.prayer(prayerBurst(moment)))
        if settings.sound { playSound() }
    }

    /// “Waktunya Ashar”, its time and the method, and the prayer after it.
    func prayerBurst(_ moment: PrayerMoment) -> ZenithPrayerBurst {
        let language = L10n.shared.language
        let locale = language.formattingLocale()
        let text = ZenithStrings.sky(language)
        let subtitle = PrayerTimesSupport.clock(moment.time, locale: locale) + " · " + settings.configuration.method.title
        let next = (day?.moments).flatMap { PrayerTimesSupport.next(after: moment.time, in: $0) }
        return ZenithPrayerBurst(symbol: moment.prayer.symbol,
                                 title: text.arrival(moment.prayer, indonesian: usesIndonesianNames),
                                 subtitle: subtitle, nextLabel: ZenithStrings.island(language).next,
                                 next: next.map { name($0.prayer, language: language) + " "
                                     + PrayerTimesSupport.clock($0.time, locale: locale) })
    }

    // MARK: Sound

    static let systemSoundName = "Purr"
    static let soundFolder = "Sky"

    /// The person's own file in the container, when there is one.
    static var customSoundURL: URL? {
        guard let name = UserDefaults.standard.string(forKey: DefaultsKey.notchSkyPrayerSoundFile), !name.isEmpty,
              let folder = PrivateFileStore.containerURL?.appendingPathComponent(soundFolder, isDirectory: true)
        else { return nil }
        let url = folder.appendingPathComponent(name, isDirectory: false)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func playSound() {
        guard !ZenithQuiet.isOn else { return } // Zenith fork: tests stay silent
        sound?.stop()
        let chosen = Self.customSoundURL.flatMap { NSSound(contentsOf: $0, byReference: false) }
        guard let sound = chosen ?? NSSound(named: NSSound.Name(Self.systemSoundName)) else { return }
        sound.volume = chosen == nil ? 0.6 : 0.8
        sound.play()
        self.sound = sound
    }

    /// Copies an audio file the person chose into the container, so it keeps
    /// playing when the original moves. Returns its name, or nil on failure.
    @discardableResult
    func installSound(from source: URL) -> String? {
        guard let container = PrivateFileStore.containerURL else { return nil }
        let folder = container.appendingPathComponent(Self.soundFolder, isDirectory: true)
        guard PrivateFileStore.createDirectory(at: folder, container: container),
              let data = try? Data(contentsOf: source), !data.isEmpty, data.count <= 50 * 1024 * 1024 else { return nil }
        let ext = source.pathExtension.isEmpty ? "m4a" : source.pathExtension.lowercased()
        let name = "prayer-sound." + ext
        // Earlier choices go, whatever their extension.
        let old = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        for file in old where file.hasPrefix("prayer-sound.") {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(file))
        }
        guard PrivateFileStore.write(data, to: folder.appendingPathComponent(name, isDirectory: false)) else { return nil }
        UserDefaults.standard.set(name, forKey: DefaultsKey.notchSkyPrayerSoundFile)
        return name
    }

    /// Back to the system sound; the copied file goes.
    func removeSound() {
        if let url = Self.customSoundURL { try? FileManager.default.removeItem(at: url) }
        UserDefaults.standard.removeObject(forKey: DefaultsKey.notchSkyPrayerSoundFile)
    }
}

#if VORSSAINT_DEVELOPMENT
// Zenith fork: sample state for the island catalog (IslandCatalog,
// `--render-island-catalog`), which draws the island offscreen. Nothing else
// calls this, and the release build does not have it.
extension SkyService {
    func catalogPose(day: SkyDay?, prayer: PrayerTimesSupport.Activity?, golden: SkyGoldenSupport.Activity?) {
        self.day = day
        settings = SkySettings.current()
        prayerActivity = prayer
        goldenActivity = golden
    }
}
#endif
