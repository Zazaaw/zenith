// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: the island side of Batteries on sample readings: the
/// preferences it reads, the devices it shows and their names, the weakest
/// one for the Home widget, the List captions, the Battery Low card's advice
/// and island, and how long the compact form stands.
enum BatteriesIslandTests {
    static func run(_ suite: TestSuite) {
        suite.run("batteries island preferences") { preferences(suite) }
        suite.run("batteries island devices") { devices(suite) }
        suite.run("batteries island words") { words(suite) }
        suite.run("batteries island rings") { rings(suite) }
        suite.run("batteries island card") { card(suite) }
        suite.run("batteries island compact form") { compact(suite) }
        suite.run("batteries island registration") { registration(suite) }
    }

    private static let text = ZenithStrings.batteriesIsland(.enUS)
    private static let now = Date(timeIntervalSince1970: 1_795_000_000)

    private static func device(_ id: String, _ percent: Int?, charging: Bool = false, unreachableFor: TimeInterval? = nil,
                               name: String? = nil, source: BatterySource = .bluetooth) -> BatteryDevice {
        BatteryDevice(id: id, name: name ?? id, kind: .keyboard, source: source, percent: percent, isCharging: charging,
                      unreachableSince: unreachableFor.map { now.addingTimeInterval(-$0) })
    }

    /// A fresh suite in the namespace build.sh sweeps; `tag` keeps each one apart.
    private static func defaults(_ tag: String) -> UserDefaults {
        let name = "com.vorssaint.tests.batteries-island.\(tag)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private static func preferences(_ suite: TestSuite) {
        let empty = defaults("empty")
        suite.expect(BatteriesIslandSupport.isEnabled(in: empty), "Batteries is on until turned off")
        suite.expect(BatteriesIslandSupport.layout(in: empty) == .rings, "Rings is the default layout")
        suite.expect(BatteriesIslandSupport.threshold(in: empty) == 20, "the alert level defaults to 20")

        let set = defaults("set")
        set.set(false, forKey: BatteriesDefaults.enabled)
        set.set("list", forKey: BatteriesDefaults.layout)
        set.set(15, forKey: BatteriesDefaults.threshold)
        set.set(["a", "b"], forKey: BatteriesDefaults.hiddenDeviceIDs)
        suite.expect(!BatteriesIslandSupport.isEnabled(in: set), "turned off in Settings")
        suite.expect(BatteriesIslandSupport.layout(in: set) == .list, "List when chosen")
        suite.expect(BatteriesIslandSupport.threshold(in: set) == 15, "a chosen step is kept")
        suite.expect(BatteriesIslandSupport.hiddenDeviceIDs(in: set) == ["a", "b"], "hidden devices are read")

        set.set(17, forKey: BatteriesDefaults.threshold)
        set.set("grid", forKey: BatteriesDefaults.layout)
        suite.expect(BatteriesIslandSupport.threshold(in: set) == 20, "a level that is not a step falls back to 20")
        suite.expect(BatteriesIslandSupport.layout(in: set) == .rings, "an unknown layout falls back to Rings")

        // The page leaves the island with its switch, and stays listed for Settings.
        let island = defaults("island")
        island.set(true, forKey: DefaultsKey.notchEnabled)
        suite.expect(NotchModule.batteries.isAvailable(in: island), "the page is always listed")
        island.set(false, forKey: BatteriesDefaults.enabled)
        suite.expect(!NotchSupport.modules(in: island).contains(.batteries), "turned off, the page leaves the island")
        island.set(true, forKey: BatteriesDefaults.enabled)
        if NotchSupport.modules(in: island).contains(.controls) {
            suite.expect(NotchSupport.modules(in: island).contains(.batteries), "turned on, the page is in the island")
        }
        for tag in ["empty", "set", "island"] {
            UserDefaults.standard.removePersistentDomain(forName: "com.vorssaint.tests.batteries-island.\(tag)")
        }
    }

    private static func devices(_ suite: TestSuite) {
        let list = [device("mac", 100, charging: true), device("phone", 57), device("pad", 9, unreachableFor: 600),
                    device("mouse", 30), device("unknown", nil), device("keys", 30)]
        suite.expect(BatteriesIslandSupport.shown(list, hidden: ["phone"]).map(\.id) == ["mac", "pad", "mouse", "unknown", "keys"],
                     "hidden devices leave, the order stays")
        suite.expect(BatteriesIslandSupport.weakest(list)?.id == "mouse",
                     "the weakest is reachable with a known level, the first of equals")
        suite.expect(BatteriesIslandSupport.weakest([device("pad", 9, unreachableFor: 60), device("x", nil)]) == nil,
                     "no reachable level, no weakest")

        let names = BatteriesIslandSupport.displayNames(for: [
            device("a", 50, name: "Faiz’s AirPods Pro"), device("b", 50, name: "Faiz's Magic Mouse"),
            device("c", 50, name: "Raka’s AirPods"), device("d", 50, name: "AirPods"), device("e", 50, name: "’s Odd"),
        ])
        suite.expect(names["a"] == "AirPods Pro", "the owner's name goes when the rest is unique")
        suite.expect(names["b"] == "Magic Mouse", "a straight apostrophe too")
        suite.expect(names["c"] == "Raka’s AirPods" && names["d"] == "AirPods", "two that would read alike keep their names")
        suite.expect(names["e"] == "’s Odd", "a name that starts with the marker is kept")

    }

    private static func words(_ suite: TestSuite) {
        suite.expect(BatteriesIslandSupport.caption(device("a", 50, source: .viaIPhone), now: now, text: text) == "Via iPhone",
                     "a live reading names where it came from")
        suite.expect(BatteriesIslandSupport.caption(device("a", 45, unreachableFor: 7_200), now: now, text: text)
                     == "Last seen 2 h ago", "a last-known level says when it was seen")
        suite.expect(BatteriesIslandSupport.elapsed(since: now.addingTimeInterval(-30), now: now, text: text) == "<1 min",
                     "under a minute")
        suite.expect(BatteriesIslandSupport.elapsed(since: now.addingTimeInterval(-750), now: now, text: text) == "12 min",
                     "minutes")
        suite.expect(BatteriesIslandSupport.elapsed(since: now.addingTimeInterval(-3 * 86_400 - 5), now: now, text: text) == "3 d",
                     "days")
        suite.expect(BatteriesIslandSupport.elapsed(since: now.addingTimeInterval(60), now: now, text: text) == "<1 min",
                     "a clock that moved back is not negative")
        suite.expect(BatteriesIslandSupport.percentText(nil, text: text) == "—", "an unknown level is a dash")
        suite.expect(BatteriesIslandSupport.percentText(104, text: text) == "100%", "levels are clamped")
        let value = BatteriesIslandSupport.accessibilityValue(device("a", 45, charging: true, unreachableFor: 7_200),
                                                              now: now, text: text)
        suite.expect(value == "45 percent, charging, not reachable, last seen 2 h ago", "VoiceOver reads it all: \(value)")
        let sources: [BatterySource] = [.builtIn, .bluetooth, .usb, .wifi, .viaIPhone, .pocket]
        suite.expect(Set(sources.map(text.source)).count == sources.count, "every source has its own word")
        suite.expect(text.all.allSatisfy { !$0.isEmpty }, "no empty string")
        suite.expect(AppLanguage.allCases.allSatisfy { ZenithStrings.batteriesIsland($0).title == "Batteries" },
                     "English in every language")
    }

    private static func rings(_ suite: TestSuite) {
        let metrics = BatteriesRingMetrics.solo
        suite.expect(metrics.diameter == 62 && metrics.lineWidth == 6 && metrics.symbolSize == 22, "the droplet's solo ring")
        suite.expect(metrics.cellWidth == 74, "a column is the ring and twelve points for the name")
        suite.expect(metrics.rowWidth(count: 5) == 5 * 74 + 4 * 8, "five columns and four gaps")
        suite.expect(metrics.rowWidth(count: 0) == 0, "no rings, no row")
        suite.expect(!metrics.scrolls(count: 5, available: 600), "five rings sit whole")
        suite.expect(metrics.visibleWidth(count: 3, available: 600) == metrics.rowWidth(count: 3), "a short row keeps its width")
        suite.expect(metrics.scrolls(count: 6, available: 600), "a sixth scrolls")
        let peek = metrics.visibleWidth(count: 6, available: 600)
        suite.expect(peek > metrics.rowWidth(count: 5) && peek < metrics.rowWidth(count: 6),
                     "past five, five and part of the next show")
        suite.expect(metrics.scrolls(count: 4, available: 200) && metrics.visibleWidth(count: 4, available: 200) == 200,
                     "a narrow page scrolls in what it has")
        suite.expect(BatteriesListMetrics.rows([1, 2, 3, 4, 5]) == [[1, 2], [3, 4], [5]], "two columns, left to right then down")
        suite.expect(BatteriesListMetrics.rows([Int]()).isEmpty, "no devices, no rows")
    }

    private static func card(_ suite: TestSuite) {
        suite.expect(BatteriesIslandSupport.lowDetail(others: [], text: text)
                     == "Its battery is running low. It is recommended to charge it.", "alone")
        suite.expect(BatteriesIslandSupport.lowDetail(others: ["iPhone"], text: text)
                     == "iPhone is low too. It is recommended to charge them.", "with one other")
        suite.expect(BatteriesIslandSupport.lowDetail(others: ["iPhone", "Mouse", "Pad"], text: text)
                     == "3 more devices are low too. It is recommended to charge them.", "with more")

        var gamepad = device("pad", 15, name: "Xbox Wireless Controller")
        gamepad.kind = .gamepad
        let alert = BatteriesLowAlert(id: UUID(), device: gamepad, percent: 15, others: [])
        let low = BatteriesIslandSupport.lowBurst(alert, text: text)
        suite.expect(low.symbol == "gamecontroller" && low.name == "Xbox Wireless Controller" && low.percent == 15,
                     "the card names the device and its level")

        let burst = ZenithIslandBurst(.batteryLow(low), start: now)
        suite.expect(burst.duration == 5, "the card stays five seconds")
        suite.expect(burst.module == .batteries, "a click opens the Batteries page")
        suite.expect(burst.event == .battery, "it rides the battery's notice")
        suite.expect(ZenithIslandBurstTiming.patience(.batteryLow(low)) > 0, "it waits a while for an open island")
        let prayer = ZenithIslandBurst(.prayer(ZenithPrayerBurst(symbol: "sun.max", title: "Asr", subtitle: "15.04",
                                                                 nextLabel: "Next", next: nil)), start: now)
        suite.expect(!ZenithIslandBurstTiming.replaces(prayer, with: burst, at: now), "a prayer's time is not cut short")

        var geometry = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32,
                                     cameraWidth: 185, layout: .spacious, menuBarHeight: 32)
        geometry.compactSideRoom = 280
        let fit = ZenithIslandBurstLayout.fit(burst, geometry: geometry)
        suite.expect(fit.size.width == BatteriesCardMetrics.width, "the card keeps one width: \(fit.size.width)")
        suite.expect(fit.lines == 2, "its advice takes two lines")
        suite.expect(fit.size.height >= geometry.stripHeight + BatteriesCardMetrics.rowHeight + ZenithIslandInset.padding,
                     "the row sits below the camera with the island's padding under it")
        suite.expect(fit.size.width >= 205 && fit.size.height >= 37, "never smaller than the physical notch")
    }

    private static func compact(_ suite: TestSuite) {
        let indicator = BatteriesLowIndicator(deviceID: "pad", name: "Xbox", symbol: "gamecontroller", percent: 15,
                                              since: now)
        func stands(_ device: BatteryDevice?, after: TimeInterval = 10) -> Bool {
            BatteriesIslandSupport.indicatorStands(indicator, device: device, threshold: 20,
                                                   now: now.addingTimeInterval(after))
        }
        suite.expect(stands(device("pad", 14)), "still low, it stands")
        suite.expect(!stands(device("pad", 14, charging: true)), "charging answers it")
        suite.expect(!stands(device("pad", 40)), "recovered, it goes")
        suite.expect(stands(nil), "a device missing from one scan keeps it")
        suite.expect(!stands(device("pad", 14), after: BatteriesIslandSupport.compactLinger), "it goes after a few minutes")
        suite.expect(BatteriesIslandSupport.updated(indicator, device: device("pad", 12)).percent == 12, "the level follows")
        suite.expect(BatteriesIslandSupport.updated(indicator, device: device("pad", nil)).percent == 15,
                     "an unknown level keeps the last")
        suite.expect(BatteriesIslandSupport.batterySymbol(percent: 15) == "battery.25percent", "a quarter battery at 15")
        suite.expect(BatteriesIslandSupport.batterySymbol(percent: 5) == "battery.0percent", "empty under 13")
        suite.expect(BatteriesIslandSupport.batterySymbol(percent: 100) == "battery.100percent", "full")

        let activities = NotchSupport.compactActivities(timer: false, downloads: true, agents: false, calendar: false,
                                                        music: true, batteries: true)
        suite.expect(activities.first == .batteries, "a low battery comes before downloads and music")
        suite.expect(NotchCompactActivity.batteries.module == .batteries, "its strip opens the page")
        suite.expect(NotchSupport.compactActivities(timer: true, downloads: false, agents: false, calendar: false,
                                                    music: false, batteries: true).first == .timer,
                     "a running timer keeps its place")
    }

    private static func registration(_ suite: TestSuite) {
        suite.expect(ZenithHomeWidget.batteries.module == .batteries, "the widget is a view of the page")
        suite.expect(ZenithHomeWidget.batteries.isAvailable(modules: [.batteries]), "pickable while the page is on")
        suite.expect(!ZenithHomeWidget.batteries.isAvailable(modules: [.controls]), "not offered while the page is off")
        suite.expect(ZenithHomeLayout.decode("batteries,timer")?.widgets == [.batteries, .timer], "it saves and reads back")
        let keys = NotchModule.allCases.map(\.shortcutKey)
        suite.expect(Set(keys).count == keys.count, "every page keeps its own shortcut key")
        suite.expect(NotchModule(rawValue: "batteries") == .batteries, "the page's stored name")
    }
}
