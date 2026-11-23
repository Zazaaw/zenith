// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: Settings → Batteries. The page is found by its English words
/// and the Indonesian ones its owner types; the Mac's alert starts off and
/// stays as set while other devices change; hidden devices can be listed and
/// shown again; each device's caption says where it is read and how it is.
enum BatteriesSettingsTests {
    static func run(_ suite: TestSuite) {
        search(suite)
        alerts(suite)
        hiding(suite)
        captions(suite)
    }

    private static func search(_ suite: TestSuite) {
        let domain = "com.vorssaint.tests.batteries-search"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let state = SettingsSearchState(defaults: defaults, hardware: .init(
            battery: true, notchedDisplay: true, plainDisplay: false,
            keyboardLight: true, bluetoothSleep: true, brightnessOSD: true))
        let all: (AppFeature) -> Bool = { _ in true }
        func routes(_ query: String) -> [FeatureSettingsDestination] {
            let items = SettingsDirectory.searchItems(Strings.localized(.enUS), language: .enUS, state: state)
            return SettingsSearchSupport.groupedMatchingItems(query: query, items: items, isAvailable: all)
                .flatMap { ($0.parentMatches ? [$0.parentSuggestion] : []) + $0.suggestions }
                .prefix(ForkSettingsSearchTests.top)
                .map { SettingsSearchSupport.route(for: $0, isAvailable: all).destination }
        }
        let page = FeatureSettingsDestination(.batteries)
        let anchored = { (anchor: SettingsSectionAnchor) in FeatureSettingsDestination(.batteries, sectionAnchor: anchor) }
        let batteries: Set<FeatureSettingsDestination> = [
            page, anchored(.zenithBatteries), anchored(.zenithBatteriesAlerts), anchored(.zenithBatteriesIPhone),
        ]
        for query in ["batteries", "battery", "airpods", "baterai", "batre", "daya", "sisa baterai", "jam tangan",
                      "baterai lemah", "baterai iphone", "apple watch", "libimobiledevice", "warn me at",
                      "airpods scanning"] {
            let found = routes(query)
            suite.expect(found.contains(where: batteries.contains),
                         "searching \"\(query)\" offers Batteries among the first \(ForkSettingsSearchTests.top): \(found)")
        }
        suite.expect(routes("baterai lemah").contains(anchored(.zenithBatteriesAlerts)),
                     "\"baterai lemah\" opens the low battery alert")
        suite.expect(routes("jam tangan").contains(anchored(.zenithBatteriesIPhone)),
                     "\"jam tangan\" opens iPhone & Apple Watch")
        let aliases = ZenithSettingsSearch.pageAliases[.page(.batteries)] ?? []
        suite.expect(["baterai", "batre", "daya", "airpods", "jam", "iphone"].allSatisfy(aliases.contains),
                     "the page's Indonesian and English aliases")
        suite.expect(FeatureVisibilitySupport.features(for: .batteries).isEmpty,
                     "Batteries is a page of the app's own, which no hub feature hides")
        let text = ZenithStrings.batteries(.de)
        suite.expect(text.all.count > 50 && text.all.allSatisfy { !$0.isEmpty }, "every Batteries string has text")
    }

    private static func alerts(_ suite: TestSuite) {
        typealias Prefs = BatteriesDevicePreferences
        let domain = "com.vorssaint.tests.batteries-alerts"
        let defaults = UserDefaults(suiteName: domain)!
        defaults.removePersistentDomain(forName: domain)
        defer { defaults.removePersistentDomain(forName: domain) }
        suite.expect(Prefs.isMuted("mac", in: defaults) && !Prefs.isMuted("keyboard", in: defaults),
                     "the Mac's alert starts off, every other device's on")
        Prefs.setAlert(false, for: "keyboard", in: defaults)
        suite.expect(Prefs.isMuted("mac", in: defaults) && Prefs.isMuted("keyboard", in: defaults),
                     "muting a device keeps the Mac muted")
        Prefs.setAlert(true, for: "mac", in: defaults)
        suite.expect(!Prefs.isMuted("mac", in: defaults) && Prefs.isMuted("keyboard", in: defaults)
                     && defaults.stringArray(forKey: BatteriesDefaults.mutedDeviceIDs) == ["keyboard"],
                     "turning the Mac on is the muted list without it")
        Prefs.setAlert(true, for: "keyboard", in: defaults)
        suite.expect(!Prefs.isMuted("mac", in: defaults) && defaults.stringArray(forKey: BatteriesDefaults.mutedDeviceIDs) == [],
                     "the Mac stays on once turned on, with nothing muted")
    }

    private static func hiding(_ suite: TestSuite) {
        typealias Prefs = BatteriesDevicePreferences
        let domain = "com.vorssaint.tests.batteries-hidden"
        let defaults = UserDefaults(suiteName: domain)!
        defaults.removePersistentDomain(forName: domain)
        defer { defaults.removePersistentDomain(forName: domain) }
        let devices = BatteriesStore.sample
        Prefs.setHidden(true, id: "sample-gamepad", name: "Xbox Wireless Controller", in: defaults)
        Prefs.setHidden(true, id: "sample-watch", name: "Apple Watch", in: defaults)
        let hidden = Prefs.hidden(in: defaults)
        let groups = Prefs.split(devices, hidden: hidden)
        suite.expect(groups.accessories.map(\.id) == ["mac", "sample-headphones", "sample-keyboard"],
                     "Devices lists the Mac and accessories, hidden ones left out: \(groups.accessories.map(\.id))")
        suite.expect(groups.mobile.map(\.id) == ["sample-iphone"], "iPhone & Apple Watch lists the rest")
        // Gone from the store (the monitor leaves hidden devices out), still listed by name.
        let rows = Prefs.hiddenRows([], hidden: hidden, names: Prefs.hiddenNames(in: defaults))
        suite.expect(rows.map(\.name) == ["Xbox Wireless Controller", "Apple Watch"],
                     "hidden devices are listed by the name they had: \(rows.map(\.name))")
        Prefs.setHidden(false, id: "sample-gamepad", name: nil, in: defaults)
        suite.expect(Prefs.hidden(in: defaults) == ["sample-watch"]
                     && Prefs.hiddenNames(in: defaults) == ["sample-watch": "Apple Watch"],
                     "showing a device again forgets its name")
        Prefs.setHidden(false, id: "sample-watch", name: nil, in: defaults)
        suite.expect(defaults.object(forKey: Prefs.hiddenNamesKey) == nil, "nothing is kept once nothing is hidden")
    }

    private static func captions(_ suite: TestSuite) {
        let text = ZenithStrings.batteries(.enUS)
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        func caption(_ id: String) -> String {
            var device = BatteriesStore.sample.first { $0.id == id }!
            if let since = device.unreachableSince {
                device.unreachableSince = now.addingTimeInterval(since.timeIntervalSinceNow.rounded())
            }
            return BatteriesDevicePreferences.caption(device, text: text, now: now)
        }
        suite.expect(caption("mac") == "BUILT-IN · 100%, charging", caption("mac"))
        suite.expect(caption("sample-headphones") == "BLUETOOTH · 70%", caption("sample-headphones"))
        suite.expect(caption("sample-keyboard") == "BLUETOOTH · 45%, last seen 2 h ago", caption("sample-keyboard"))
        suite.expect(caption("sample-watch") == "VIA IPHONE · 64% · while the iPhone is reachable", caption("sample-watch"))
        var airPods = BatteryDevice(id: "pods", name: "AirPods Pro", kind: .headphones, source: .bluetooth, percent: nil)
        airPods.components = [.init(label: "L", percent: 80), .init(label: "R", percent: 75)]
        suite.expect(BatteriesDevicePreferences.caption(airPods, text: text, now: now) == "BLUETOOTH · L 80% R 75%",
                     "earbuds without one level show each cell")
        let silent = BatteryDevice(id: "x", name: "X", kind: .other, source: .usb, percent: nil)
        suite.expect(BatteriesDevicePreferences.caption(silent, text: text, now: now) == "USB · —", "no level reads as a dash")
        suite.expect(text.ago(20) == "just now" && text.ago(5 * 60) == "5 min ago" && text.ago(3 * 86_400) == "3 d ago",
                     "how long ago, in short")
    }
}
