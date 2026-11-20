// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: every fork feature is found by Settings search, by its English
/// name and by the Indonesian words its owner types, and opens its page at its
/// section or island module. The labels the fork's settings show are indexed,
/// as SettingsSearchCoverageTests checks for upstream's.
enum ForkSettingsSearchTests {
    /// How far down the sidebar's result list an expected result may sit.
    static let top = 3

    /// Titles another result on the same page already has in a language, so
    /// the page lists that one: Russian and Ukrainian call the island's notices
    /// and its Notifications by one word. Their labels and English aliases
    /// still find them.
    static let sharedTitles: [(language: AppLanguage, anchor: SettingsSectionAnchor)] = [
        (.ru, .zenithNotices), (.uk, .zenithNotices),
    ]

    static func run(_ suite: TestSuite) {
        let domain = "com.vorssaint.tests.fork-settings-search"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        func state(claude: Bool = true) -> SettingsSearchState {
            defaults.setPersistentDomain([DefaultsKey.notchAgentsClaude: claude], forName: domain)
            return SettingsSearchState(defaults: defaults, hardware: .init(
                battery: true, notchedDisplay: true, plainDisplay: false,
                keyboardLight: true, bluetoothSleep: true, brightnessOSD: true))
        }
        let everything = state()
        let all: (AppFeature) -> Bool = { _ in true }

        func suggestions(_ query: String, language: AppLanguage = .enUS, state: SettingsSearchState = everything,
                         available: (AppFeature) -> Bool = all) -> [SettingsSearchSuggestion] {
            let items = SettingsDirectory.searchItems(Strings.localized(language), language: language, state: state)
            // In the order the sidebar lists them.
            return SettingsSearchSupport.groupedMatchingItems(query: query, items: items, isAvailable: available)
                .flatMap { ($0.parentMatches ? [$0.parentSuggestion] : []) + $0.suggestions }
        }
        func routes(_ query: String, language: AppLanguage = .enUS, state: SettingsSearchState = everything,
                    available: @escaping (AppFeature) -> Bool = all) -> [FeatureSettingsDestination] {
            suggestions(query, language: language, state: state, available: available).prefix(top)
                .map { SettingsSearchSupport.route(for: $0, isAvailable: available).destination }
        }

        let module = { (module: NotchModule) -> FeatureSettingsDestination in
            let anchors: [NotchModule: SettingsSectionAnchor] = [
                .wakatime: .zenithWakaTime, .vercel: .zenithVercel, .github: .zenithGitHub, .cardImport: .zenithCardImport,
                .devServers: .zenithDevServers, .git: .zenithGit, .sky: .zenithSky, .recap: .zenithRecap,
                .prompter: .zenithPrompter,
            ]
            guard let anchor = anchors[module] else { return FeatureSettingsDestination(notch: .module(module)) }
            return FeatureSettingsDestination(notch: .module(module), sectionAnchor: anchor)
        }
        let prayer = FeatureSettingsDestination(notch: .module(.sky), sectionAnchor: .zenithPrayerTimes)
        let golden = FeatureSettingsDestination(notch: .module(.sky), sectionAnchor: .zenithGoldenHour)
        let backup = FeatureSettingsDestination(notch: .module(.cardImport), sectionAnchor: .zenithCardBackup)
        let lockScreen = FeatureSettingsDestination(notch: .activity, sectionAnchor: .zenithLockScreen)
        let commands = FeatureSettingsDestination(notch: .activity, sectionAnchor: .zenithCommandActivity)
        let exports = FeatureSettingsDestination(notch: .activity, sectionAnchor: .zenithExportTracker)
        let notices = FeatureSettingsDestination(notch: .activity, sectionAnchor: .zenithNotices)
        let tabBar = FeatureSettingsDestination(notch: .layout, sectionAnchor: .zenithTabBar)
        let hooks = FeatureSettingsDestination(notch: .module(.agents), sectionAnchor: .zenithClaudeHooks)
        let reply = FeatureSettingsDestination(notch: .module(.notifications), sectionAnchor: .zenithReply)
        let camera = FeatureSettingsDestination(notch: .module(.camera), sectionAnchor: .zenithCameraAutoStart)
        let anchored = { (anchor: SettingsSectionAnchor) in FeatureSettingsDestination(anchor.page, sectionAnchor: anchor) }
        let menuBar = FeatureSettingsDestination(.general, sectionAnchor: .panelConfiguration)

        let english: [(String, FeatureSettingsDestination)] = [
            ("prayer", prayer), ("prayer times", prayer), ("golden hour", golden), ("sky", module(.sky)),
            ("git", module(.git)), ("QR", anchored(.zenithQR)), ("QR code", anchored(.zenithQR)),
            ("teleprompter", module(.prompter)), ("prompter", module(.prompter)),
            ("watermark", anchored(.zenithWatermark)), ("vercel", module(.vercel)), ("wakatime", module(.wakatime)),
            ("github", module(.github)), ("workspace", FeatureSettingsDestination(.workspaces)),
            ("drop zones", anchored(.zenithDropZones)), ("beautify", anchored(.zenithBeautify)),
            ("design overlay", anchored(.zenithDesignOverlay)), ("backup", backup), ("dev server", module(.devServers)),
            ("recap", module(.recap)), ("today", module(.recap)), ("card import", module(.cardImport)),
            ("lock screen", lockScreen), ("weather", lockScreen), ("terminal readout", lockScreen),
            ("terminal commands", commands), ("exports", exports), ("notices", notices), ("tab bar", tabBar),
            ("claude code", hooks), ("whatsapp", reply), ("start the mirror", camera),
            ("menu bar hiding", menuBar), ("about", FeatureSettingsDestination(.about)),
        ]
        let indonesian: [(String, FeatureSettingsDestination)] = [
            ("sholat", prayer), ("jadwal sholat", prayer), ("waktu sholat", prayer), ("adzan", prayer),
            ("imsak", prayer), ("maghrib", prayer), ("senja", golden), ("cadangan", backup),
            ("tanda air", anchored(.zenithWatermark)), ("pindai", anchored(.zenithQR)), ("kode QR", anchored(.zenithQR)),
            ("teleprompter", module(.prompter)), ("naskah", module(.prompter)), ("kartu SD", module(.cardImport)),
            ("rekap", module(.recap)), ("hari ini", module(.recap)), ("menu bar", menuBar),
            ("sembunyikan ikon", menuBar), ("ruang kerja", FeatureSettingsDestination(.workspaces)),
            ("layar kunci", lockScreen), ("cuaca", lockScreen), ("zona drop", anchored(.zenithDropZones)),
            ("percantik", anchored(.zenithBeautify)), ("perintah terminal", commands), ("ekspor", exports),
            ("balas", reply), ("tentang", FeatureSettingsDestination(.about)),
        ]
        for (query, destination) in english + indonesian {
            let found = routes(query)
            suite.expect(found.contains(destination),
                         "searching \"\(query)\" offers \(destination) among the first \(top): \(found)")
        }

        // An alias shows its result's title, in the app's language, not itself.
        for language in [AppLanguage.enUS, .de, .ja] {
            let sky = ZenithStrings.sky(language)
            let first = suggestions("sholat", language: language).first
            let opens = first.map { SettingsSearchSupport.route(for: $0, isAvailable: all).destination }
            suite.expect(first?.title == sky.prayerTab && opens == prayer,
                         "\"sholat\" shows \(sky.prayerTab) first in \(language.rawValue): \(first?.title ?? "")")
        }
        let hider = ZenithStrings.menuBarHider(.enUS)
        suite.expect(suggestions("sembunyikan ikon").first?.title == hider.title,
                     "\"sembunyikan ikon\" shows the menu bar hider")

        // Every fork result is found by its own title, in every language, and opens its destination.
        for language in AppLanguage.allCases {
            for item in ZenithSettingsSearch.items(language: language, state: everything)
                where !sharedTitles.contains(where: { $0.language == language && item.id == .setting($0.anchor) }) {
                let found = suggestions(item.title, language: language).filter { $0.title == item.title }
                    .map { SettingsSearchSupport.route(for: $0, isAvailable: all).destination }
                suite.expect(found.contains(item.destination),
                             "\(language.rawValue): \"\(item.title)\" opens \(item.destination): \(found)")
            }
        }

        // Where results land: on their own page, at an anchor of that page,
        // which the page places once; the island opens the tab and module.
        let items = ZenithSettingsSearch.items(language: .enUS, state: everything)
        suite.expect(Set(items.map(\.id)).count == items.count, "each fork result has its own identity")
        let anchors = SettingsSectionAnchor.allCases.filter { $0.rawValue.hasPrefix("zenith") }
        suite.expect(Set(anchors) == Set(items.compactMap { item -> SettingsSectionAnchor? in
            if case .setting(let anchor) = item.id { return anchor }
            return nil
        }), "every fork anchor names a search result")
        let sources = uiSources()
        for anchor in anchors {
            let pattern = try! NSRegularExpression(pattern: #"Anchor\(\."# + anchor.rawValue + #"\b"#)
            let placed = sources.reduce(0) { $0 + pattern.numberOfMatches(in: $1, range: NSRange($1.startIndex..., in: $1)) }
            let expected = ZenithSettingsSearch.unplacedAnchors.contains(anchor) ? 0 : 1
            suite.expect(placed == expected, "\(anchor.rawValue) is placed \(expected) time(s) in the UI (\(placed))")
        }
        let router = SettingsRouter()
        for item in items {
            let destination = item.destination
            suite.expect(destination.hasValidSectionAnchor, "\(item.title) lands on an anchor of its own page")
            if case .setting(let anchor) = item.id, !ZenithSettingsSearch.unplacedAnchors.contains(anchor) {
                suite.expect(destination.sectionAnchor == anchor, "\(item.title) lands on its own section")
            }
            guard let location = destination.notchLocation else { continue }
            router.request(destination)
            let island = SettingsFeatureTests.IslandSettings(router: router)
            island.revealDestination()
            suite.expect(island.tab == location.tab, "\(item.title) opens the island's \(location.id) tab")
            if case .module(let module) = location {
                suite.expect(island.selectedModule == module, "\(item.title) opens the \(module) options")
            }
        }

        // A section that is not there is not offered.
        suite.expect(!routes("claude code", state: state(claude: false)).contains(hooks),
                     "Claude Code's hooks are not offered while Claude is off")
        suite.expect(!routes("beautify", available: { $0 != .screenshot }).contains(anchored(.zenithBeautify)),
                     "Beautify is not offered without screenshots")
        suite.expect(!routes("balas", available: { $0 != .notchNotifications }).contains(reply),
                     "the island's replies are not offered without island notifications")

        // Upstream's results stay as they were.
        suite.expect(routes("music").contains(module(.music)), "\"music\" still opens the island's Music")
        suite.expect(routes("menu bar").first == menuBar, "\"menu bar\" still opens the Menu bar first")
        suite.expect(routes("clipboard history").contains(AppFeature.clipboardHistory.settingsDestination),
                     "\"clipboard history\" still opens Clipboard history")

        // The command bar finds the same results, by alias too.
        let strings = Strings.enUS
        var actions: [CommandBarEntry] = []
        let entries = SettingsFeatureTests.SearchCommands.settingsEntries(
            SettingsDirectory.searchItems(strings, language: .enUS, state: everything), language: .enUS,
            settingsTitle: strings.settingsTitle, actions: &actions, isAvailable: all)
        let ids = entries.map(\.id)
        suite.expect(Set(ids).count == ids.count, "each settings command keeps one stable id: "
                        + "\(Dictionary(grouping: ids, by: { $0 }).filter { $0.value.count > 1 }.keys.sorted())")
        for (query, id) in [("sholat", "settings.setting.zenithPrayerTimes"), ("teleprompter", "settings.setting.zenithPrompter"),
                            ("tanda air", "settings.setting.zenithWatermark"), ("git", "settings.setting.zenithGit")] {
            suite.expect(entries.contains { $0.id == id && CommandBarSearch.matches(title: $0.title, keywords: $0.keywords, query: query) },
                         "the command bar finds \(id) for \"\(query)\"")
        }

        coverage(suite)
    }

    private static func uiSources() -> [String] {
        let root = "Sources/Vorssaint/UI"
        let paths = FileManager.default.enumerator(atPath: root)?.compactMap { $0 as? String } ?? []
        return paths.filter { $0.hasSuffix(".swift") }.compactMap {
            try? String(contentsOfFile: root + "/" + $0, encoding: .utf8)
        }
    }

    /// The fork's settings label their switches with `ZenithSwitchRow`, which
    /// upstream's coverage scan does not read. Each such label is a word
    /// Settings search knows.
    static let forkSettings = [
        "Sources/Vorssaint/UI/Notch/CardImportSettings.swift", "Sources/Vorssaint/UI/Notch/BackupSettings.swift",
        "Sources/Vorssaint/UI/Notch/DevServersSettings.swift", "Sources/Vorssaint/UI/Notch/ExportTrackerSettings.swift",
        "Sources/Vorssaint/UI/Notch/GitSettings.swift", "Sources/Vorssaint/UI/Notch/PrompterSettings.swift",
        "Sources/Vorssaint/UI/Notch/RecapSettings.swift", "Sources/Vorssaint/UI/Notch/SkySettingsView.swift",
        "Sources/Vorssaint/UI/Command/CommandActivityViews.swift",
        "Sources/Vorssaint/UI/DesignOverlay/DesignOverlaySettings.swift", "Sources/Vorssaint/UI/QR/QRSettingsSection.swift",
        "Sources/Vorssaint/UI/Screenshot/ScreenshotBeautifySettings.swift", "Sources/Vorssaint/UI/Vercel/VercelViews.swift",
        "Sources/Vorssaint/UI/Settings/MenuBarHiderSettings.swift",
        "Sources/Vorssaint/UI/Settings/NotchAgentsClaudeHooksSettings.swift",
        "Sources/Vorssaint/UI/Settings/NotchLockScreenTerminalSettings.swift",
        "Sources/Vorssaint/UI/Settings/NotchWatermarkSettings.swift", "Sources/Vorssaint/UI/Settings/ZenithNoticeSettings.swift",
        "Sources/Vorssaint/UI/Settings/ZenithReplySettings.swift", "Sources/Vorssaint/UI/Settings/ZenithTabBarSettings.swift",
    ]

    /// Switches whose label is a value of their own, named where they are shown.
    static let dynamicLabels: Set<String> = [
        "title(source)", // RecapSettings: each source's name, listed under Include
        "name", // SkySettingsView: each prayer's name, listed under Reminders
        "title(entry.source, text: text)", // NotchLockScreenTerminalSettings: each line of the readout
    ]

    private static func coverage(_ suite: TestSuite) {
        typealias Coverage = SettingsSearchCoverageTests
        let resolver = Coverage.Resolver(sourceRoot: "Sources/Vorssaint")
        var indexed = Set<String>()
        for (path, declaration) in [
            ("Sources/Vorssaint/UI/Settings/SettingsDirectory.swift", "    static func searchItems("),
            ("Sources/Vorssaint/UI/Settings/SettingsDirectory.swift", "    static func sections("),
            ("Sources/Vorssaint/UI/Settings/ZenithSettingsSearch.swift", "    static func items("),
        ] {
            let words = (try? String(contentsOfFile: path, encoding: .utf8)).flatMap {
                resolver.searchWords(in: Coverage.SwiftSource(path: path, text: $0), declaration: declaration, selfType: nil)
            }
            suite.expect(words?.isEmpty == false, "\(path) gives Settings search its words")
            indexed.formUnion(words ?? [])
        }
        var count = 0
        for path in forkSettings {
            guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
                suite.expect(false, "\(path) is still there")
                continue
            }
            let source = Coverage.SwiftSource(path: path, text: text)
            for match in source.matches(#"\bZenithSwitchRow\s*\("#) {
                guard let title = source.arguments(at: match.range.location + match.range.length - 1)?.arguments.first,
                      title.label == nil else { continue }
                if dynamicLabels.contains(source.text(title.range)) { continue }
                do {
                    for label in try resolver.labels(title.range, in: source) {
                        count += 1
                        suite.expect(indexed.contains(label.reference),
                                     "\(path):\(source.line(at: label.offset)): \(label.reference) "
                                        + "is shown in Settings but Settings search cannot find it")
                    }
                } catch {
                    suite.expect(false, "\(path):\(source.line(at: title.range.lowerBound)): cannot follow "
                                    + "the switch title `\(source.text(title.range))` to a localized string (\(error))")
                }
            }
        }
        suite.expect(count > 40, "the fork coverage scan finds the fork's switch labels (\(count))")
    }
}
