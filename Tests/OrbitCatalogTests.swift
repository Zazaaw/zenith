// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: Orbit, the store-like Features page. Every hub feature and
/// every Zenith page is listed exactly once with real art and a shelf; Get,
/// Open and Turn Off go through the hub's own availability and the pages'
/// own switches; and search finds items by name, by what Settings search
/// knows them as, and by their Indonesian aliases.
enum OrbitCatalogTests {
    static func run(_ suite: TestSuite) {
        catalog(suite)
        state(suite)
        routing(suite)
        search(suite)
    }

    // MARK: Catalog

    private static func catalog(_ suite: TestSuite) {
        let items = OrbitCatalog.items
        let ids = items.map(\.id)
        suite.expect(Set(ids).count == ids.count, "no item is listed twice")
        for feature in AppFeature.allCases {
            suite.expect(ids.filter { $0 == .feature(feature) }.count == 1,
                         "\(feature.rawValue) appears in Orbit exactly once")
        }
        let pages = items.compactMap(\.page)
        suite.expect(Set(pages) == [.lockScreen, .meetings, .translate, .mechakey, .workspaces, .pocket, .remote,
                                    .batteries, .faceUnlock,
                                    .removeBackground, .emojiPicker, .calculator, // Orbit wave 2
                                    .appLock, // App Lock
                                    .privacyBlur] && pages.count == 14, // Privacy
                     "every Zenith page appears exactly once: \(pages)")
        suite.expect(items.count == AppFeature.allCases.count + pages.count,
                     "Orbit lists the hub's features and Zenith's pages, nothing else")
        // A Zenith page is one no hub feature gates; Lock Screen rides on the island.
        for page in pages where page != .lockScreen {
            suite.expect(FeatureVisibilitySupport.features(for: page).isEmpty,
                         "\(page) is a page of the app's own, not a hub feature's")
        }

        let text = ZenithStrings.orbit
        var names = Set<String>()
        for item in items {
            let name = text.name(item.id)
            suite.expect(OrbitIcons.named(item.iconName) != nil,
                         "\(name) draws a real Orbit icon (\(item.iconName))")
            suite.expect(OrbitCategory.shelves.contains(item.category),
                         "\(name) sits on a shelf, not on All or Installed")
            suite.expect(!name.isEmpty && !text.summary(item.id).isEmpty,
                         "\(item.id) has a name and a one-line summary")
            suite.expect(text.summary(item.id).count <= 60, "\(name)'s summary fits one line")
            suite.expect(names.insert(name).inserted, "\(name) is the only item with its name")
        }
        let iconNames = OrbitIcons.all.map(\.name)
        suite.expect(Set(iconNames).count == iconNames.count, "every icon name is unique")
        // The pages Settings is split into each draw an icon of their own name.
        let settingsPages = [
            "Scrolling", "Pointer", "Mouse Buttons", "Sleep", "Brightness", "Spaces", "Finder Tools", "Sound Output",
            "Music Blocker", "Volume Mixer", "Mic Mute", "Quick Launcher", "Quick Toggles", "Quit Apps", "Cleaning Mode",
            "Camera Preview", "Wallpaper", "Scratchpad", "Screenshot", "Screen Recording", "Text Capture", "Color Picker",
            "Dock", "Window Layout", "Clipboard", "System Monitor", "Fan Control", "Dynamic Island", "Calendar",
            "Notifications", "Music", "Timer", "Agents", "Downloads", "Watch", "Lock Screen", "Remove Background",
            "Emoji Picker", "Calculator", "App Lock", "Privacy Blur",
        ]
        let unresolved = settingsPages.filter { OrbitIcons.named($0)?.name != $0 }
        suite.expect(unresolved.isEmpty, "every Settings page has an Orbit icon under its name (missing: \(unresolved))")
        suite.expect(OrbitIcons.named("Mechakey") != nil && OrbitIcons.named("Mechey") == nil,
                     "the keyboard sounds icon goes by Mechakey")

        for shelf in OrbitCategory.shelves {
            suite.expect(items.contains { $0.category == shelf }, "the \(shelf.rawValue) shelf is not empty")
            suite.expect(!text.category(shelf).isEmpty, "the \(shelf.rawValue) chip has a title")
        }
        suite.expect(OrbitCategory.allCases.map(\.rawValue) == [
            "all", "island", "ai", "productivity", "media", "files", "capture", "windows", "input", "sound",
            "system", "devices", "privacy", "installed",
        ], "the chips run All, the shelves, then Installed")

        let picks = OrbitCatalog.picks.compactMap(OrbitCatalog.item)
        suite.expect(picks.count == OrbitCatalog.picks.count, "every pick is a catalog item")
        suite.expect(Set(OrbitCatalog.picks).isSuperset(of: [
            .page(.meetings), .page(.translate), .page(.mechakey), .feature(.shelf), .feature(.clipboardHistory),
            .page(.pocket), .page(.batteries), .page(.faceUnlock), .feature(.commandBar),
            .page(.removeBackground), .page(.emojiPicker), .page(.calculator), // Orbit wave 2
        ]), "Our Picks holds the curated list")
        suite.expect(OrbitCatalog.item(OrbitCatalog.featured) != nil, "the banner features a catalog item")
        let privacyBlur = OrbitCatalog.item(.page(.privacyBlur))
        suite.expect(privacyBlur?.category == .privacy && privacyBlur?.switchKey == PrivacyBlurDefaults.enabled
                        && privacyBlur?.switchDefault == false && privacyBlur?.permissions == [.accessibility],
                     "Privacy Blur sits on the Privacy shelf, off until its page turns it on, asking for Accessibility")

        suite.expect(AppFeature.dynamicIslandExtensions.allSatisfy { OrbitCatalog.item(.feature($0))?.requires == .notch }
                        && OrbitCatalog.item(.feature(.notch))?.requires == nil
                        && OrbitCatalog.item(.page(.lockScreen))?.requires == .notch,
                     "the island's extensions and its lock screen need the island")
    }

    // MARK: State

    private static func state(_ suite: TestSuite) {
        func state(_ id: OrbitItemID, available: Set<AppFeature> = [], switches: [String: Bool] = [:],
                   missing: Set<AppPermission> = [], using: Bool = true, blocked: String? = nil) -> OrbitItemState {
            OrbitCatalog.state(of: OrbitCatalog.item(id)!,
                               isAvailable: available.contains,
                               switchValue: { switches[$0] },
                               missing: missing.contains,
                               using: { _, _ in using },
                               blockedReason: { _ in blocked })
        }
        suite.expect(state(.feature(.mixer), available: [.mixer]) == .on, "an installed feature is on")
        suite.expect(state(.feature(.mixer)) == .off, "an uninstalled feature is off")
        suite.expect(state(.feature(.fanControl), blocked: "No fans") == .unsupported("No fans"),
                     "a feature this Mac cannot run is unsupported while off")
        suite.expect(state(.feature(.fanControl), available: [.fanControl], blocked: "No fans") == .on,
                     "an install that predates the hardware check stays on")
        suite.expect(state(.feature(.switcher), available: [.switcher], missing: [.screenRecording])
                        == .needsPermission([.screenRecording]),
                     "an installed feature using a refused permission needs it")
        suite.expect(state(.feature(.switcher), available: [.switcher], missing: [.screenRecording], using: false) == .on,
                     "a refused permission the feature is not using right now is not asked for")
        suite.expect(state(.page(.batteries)) == .on
                        && state(.page(.batteries), switches: [BatteriesDefaults.enabled: false]) == .off,
                     "Batteries reads its own switch, on by default")
        suite.expect(state(.page(.meetings)) == .off
                        && state(.page(.meetings), switches: [DefaultsKey.zenithMeetingsEnabled: true]) == .on,
                     "Meetings reads its own switch, off by default")
        suite.expect(state(.page(.meetings), switches: [DefaultsKey.zenithMeetingsEnabled: true], missing: [.calendar])
                        == .needsPermission([.calendar]),
                     "Meetings on without the calendar needs it")
        suite.expect(state(.page(.lockScreen), switches: [DefaultsKey.notchLockScreen: true]) == .off
                        && state(.page(.lockScreen), available: [.notch], switches: [DefaultsKey.notchLockScreen: true]) == .on,
                     "the lock screen is only on while the island is installed")
        suite.expect(state(.page(.workspaces)) == .on, "Workspaces is part of the app and always on")

        suite.expect(OrbitCatalog.button(for: .off) == .get && OrbitCatalog.button(for: .on) == .open
                        && OrbitCatalog.button(for: .needsPermission([.accessibility])) == .open
                        && OrbitCatalog.button(for: .unsupported("x")) == .unavailable,
                     "off shows Get, on shows Open, unsupported greys Get")
    }

    // MARK: Get, Open, Turn Off

    private static func routing(_ suite: TestSuite) {
        let none: (AppFeature) -> Bool = { _ in false }
        func item(_ id: OrbitItemID) -> OrbitItem { OrbitCatalog.item(id)! }

        suite.expect(OrbitCatalog.getPlan(for: item(.feature(.mixer)), isAvailable: none)
                        == OrbitGetPlan(install: [.mixer], opens: nil),
                     "Get installs the feature and stays on Orbit")
        suite.expect(OrbitCatalog.getPlan(for: item(.feature(.notchLyrics)), isAvailable: none)
                        == OrbitGetPlan(install: [.notch, .notchLyrics], opens: nil),
                     "Get on an island extension brings the island first")
        suite.expect(OrbitCatalog.getPlan(for: item(.feature(.notchLyrics)), isAvailable: { $0 == .notch })
                        == OrbitGetPlan(install: [.notchLyrics], opens: nil),
                     "an island already installed is not installed again")
        suite.expect(OrbitCatalog.getPlan(for: item(.page(.meetings)), isAvailable: none)
                        == OrbitGetPlan(install: [], opens: FeatureSettingsDestination(.meetings)),
                     "Get on a Zenith page opens it, where it is switched on and set up")
        suite.expect(OrbitCatalog.getPlan(for: item(.page(.lockScreen)), isAvailable: none)
                        == OrbitGetPlan(install: [.notch], opens: FeatureSettingsDestination(.lockScreen)),
                     "Get on the lock screen installs the island, then opens its page")

        for entry in OrbitCatalog.items {
            if let feature = entry.feature {
                let destination = OrbitCatalog.openDestination(for: entry)
                suite.expect(destination == (feature.hasNavigableSettingsDestination ? feature.settingsDestination : nil),
                             "Open on \(feature.rawValue) goes to its own Settings destination")
                suite.expect(OrbitCatalog.turnOffFeatures(for: entry) == [feature],
                             "Turn Off uninstalls \(feature.rawValue) through the hub")
            } else if let page = entry.page {
                suite.expect(OrbitCatalog.openDestination(for: entry) == FeatureSettingsDestination(page),
                             "Open on \(page) opens its page")
                suite.expect(OrbitCatalog.turnOffFeatures(for: entry) == nil,
                             "\(page) is switched off on its own page")
            }
        }
        suite.expect(OrbitCatalog.openDestination(for: item(.feature(.diskImageInstaller)))
                        == FeatureSettingsDestination(.finderTools, sectionAnchor: .diskImageInstaller),
                     "the disk image installer opens its section on Finder Tools")
        suite.expect(OrbitCatalog.openDestination(for: item(.feature(.notchLyrics)))
                        == FeatureSettingsDestination(notch: .module(.music)),
                     "Open lands on the island module that holds the feature")
    }

    // MARK: Browsing and search

    private static func search(_ suite: TestSuite) {
        let allOff: (OrbitItemID) -> Bool = { _ in false }
        func found(_ query: String, in category: OrbitCategory = .all,
                   words: [OrbitItemID: [String]] = [:]) -> [OrbitItemID] {
            OrbitCatalog.visible(in: category, query: query, isOn: allOff, words: words).map(\.id)
        }
        suite.expect(found("").count == OrbitCatalog.items.count, "All with no query lists everything")
        suite.expect(found("volume").contains(.feature(.mixer)), "a name finds its item")
        suite.expect(found("VOLUME MIX").first == .feature(.mixer), "search ignores case")
        suite.expect(found("whisper").isEmpty, "an unknown word finds nothing")
        suite.expect(found("tracking").contains(.feature(.urlCleaner)), "a summary word finds its item")
        suite.expect(found("layar kunci").contains(.page(.lockScreen)),
                     "a Zenith page's Indonesian alias finds it")
        suite.expect(found("baterai").contains(.page(.batteries)) || found("batre").contains(.page(.batteries)),
                     "Batteries is found by its Indonesian aliases")
        suite.expect(found("volume", in: .capture).isEmpty && found("", in: .sound).contains(.feature(.mixer)),
                     "a chip limits the catalog to its shelf")
        suite.expect(found("", in: .installed).isEmpty
                        && OrbitCatalog.visible(in: .installed, query: "", isOn: { $0 == .feature(.shelf) })
                            .map(\.id) == [.feature(.shelf)],
                     "Installed shows only what is on")

        // Settings search's own words reach Orbit: a feature's localized
        // result and its aliases, and a Zenith page's sections.
        let results = [
            SettingsSearchItem(id: .feature(.mixer), destination: AppFeature.mixer.settingsDestination,
                               title: "Mixer aplikasi", icon: "speaker", keywords: ["suara per aplikasi"],
                               feature: .mixer),
            SettingsSearchItem(id: .setting(.zenithMeetingsProviders),
                               destination: FeatureSettingsDestination(.meetings,
                                                                       sectionAnchor: .zenithMeetingsProviders),
                               title: "Zoom and Google Meet", icon: "video"),
            SettingsSearchItem(id: .page(.general), destination: FeatureSettingsDestination(.general),
                               title: "General", icon: "gear", keywords: ["umum"]),
        ]
        let words = OrbitCatalog.searchWords(from: results)
        suite.expect(words[.feature(.mixer)]?.contains("suara per aplikasi") == true
                        && words[.page(.meetings)]?.contains("Zoom and Google Meet") == true
                        && words.count == 2,
                     "Settings search's words map to the feature or Zenith page they belong to")
        suite.expect(found("suara per", words: words) == [.feature(.mixer)],
                     "a word only Settings search knows finds the item")
        suite.expect(found("google meet", words: words).contains(.page(.meetings)),
                     "a section of a Zenith page finds the page")
    }
}
