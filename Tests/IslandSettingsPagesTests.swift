// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: the Island group's pages. The Dynamic Island is one page: its
/// modules with settings of their own are the tiles of its Modules grid, not
/// pages, so the group lists the island and its lock screen alone. Every way
/// into a module (its feature, search, Orbit, the island's own buttons) lands
/// on the island's page with that module's tile, and the page stays while
/// any island feature is installed.
enum IslandSettingsPagesTests {
    static func run(_ suite: TestSuite) {
        sidebar(suite)
        modules(suite)
        destinations(suite)
        visibility(suite)
    }

    private static func sections(available: @escaping (AppFeature) -> Bool) -> [SettingsSidebarSection] {
        let state = SettingsSearchState(defaults: UserDefaults(), hardware: .init(
            battery: true, notchedDisplay: true, plainDisplay: false,
            keyboardLight: true, bluetoothSleep: true, brightnessOSD: true))
        return SettingsDirectory.sidebarSections(.enUS, language: .enUS, superKeySource: .capsLock, state: state,
                                                 keyboardLight: true, isAvailable: available)
    }

    private static func sidebar(_ suite: TestSuite) {
        let island = sections(available: { _ in true }).first { $0.group == .island }?.items.map(\.id) ?? []
        suite.expect(island == [.page(.notch), .page(.lockScreen)],
                     "the Island group lists the Dynamic Island and its lock screen, once each: \(island)")
        suite.expect([SettingsPage.notch, .lockScreen].allSatisfy { SettingsSidebarIcons.orbitIcon(for: .page($0)) != nil },
                     "both Island pages have their Orbit icon")
        let withoutCalendar = sections(available: { $0 != .notchCalendar }).flatMap(\.items).map(\.id)
        suite.expect(withoutCalendar.contains(.page(.notch)) && !withoutCalendar.contains(.feature(.notchCalendar)),
                     "a module out of Orbit leaves no row behind, and the island's page stays")
    }

    private static func modules(_ suite: TestSuite) {
        suite.expect(IslandSettingsModule.allCases == [.calendar, .notifications, .music, .timer, .agents, .downloads,
                                                       .watch, .companion],
                     "the Modules grid lists the modules in the design's order")
        suite.expect(IslandSettingsModule.allCases.allSatisfy { OrbitIcons.named($0.orbitName) != nil },
                     "every module's tile has its Orbit icon")
        suite.expect(IslandSettingsModule.allCases.allSatisfy { !$0.title(.enUS).isEmpty }
                        && IslandSettingsModule.music.title(.enUS) == NotchModule.music.title(.enUS)
                        && IslandSettingsModule.companion.title(.enUS) == FeatureStrings.notchMascot(.enUS).title,
                     "each tile is named as the island names it")
        for module in IslandSettingsModule.allCases {
            suite.expect(module.location.islandModule == module
                            && (module.notchModule.map { IslandSettingsModule($0) == module } ?? (module == .companion)),
                         "\(module.rawValue)'s location selects its own tile")
        }
        let tiles = Set(NotchModule.allCases.compactMap(IslandSettingsModule.init))
        suite.expect(tiles == Set(IslandSettingsModule.allCases.filter { $0 != .companion }),
                     "each module tile belongs to exactly one island section, and the companion to none")
        suite.expect(IslandSettingsModule(remembered: "watch") == .watch
                        && IslandSettingsModule(remembered: "gone") == .calendar
                        && !IslandSettingsModule.rememberedKey.hasPrefix("notch")
                        && !SettingsBackupSupport.exportKeys().contains(IslandSettingsModule.rememberedKey),
                     "the chosen tile is remembered as Settings' own state, outside backups, and an unknown one falls back")
        suite.expect([NotchSettingsLocation.layout, .activity, .behavior, .module(.controls), .module(.clipboard)]
                        .allSatisfy { $0.islandModule == nil },
                     "the island's tabs and the sections without settings of their own stay on the tabs")
    }

    private static func destinations(_ suite: TestSuite) {
        let modules: [(AppFeature, IslandSettingsModule)] = [
            (.notchCalendar, .calendar), (.notchNotifications, .notifications), (.notchTimer, .timer),
            (.notchLyrics, .music), (.notchQueue, .music), (.notchLiveEqualizer, .music),
            (.notchAgents, .agents), (.notchDownloads, .downloads), (.notchWatch, .watch), (.notchMascot, .companion),
        ]
        for (feature, module) in modules {
            let destination = feature.settingsDestination
            suite.expect(destination == FeatureSettingsDestination(notch: module.location)
                            && destination.page == .notch && destination.sectionAnchor == nil
                            && destination.notchLocation?.islandModule == module,
                         "\(feature.rawValue) opens the Dynamic Island page at the \(module.rawValue) tile (Orbit's Open and the hub follow it)")
        }
        for feature in [AppFeature.notchGestures, .notchAccessories, .notch] {
            suite.expect(feature.settingsDestination.page == .notch && feature.settingsDestination.notchLocation?.islandModule == nil,
                         "\(feature.rawValue) opens one of the island's tabs")
        }
        for module in NotchModule.allCases {
            let destination = FeatureSettingsDestination(notch: .module(module))
            suite.expect(destination.page == .notch && destination.notchLocation == .module(module),
                         "the island's \(module.rawValue) link opens the Dynamic Island page")
        }
        suite.expect(SettingsSectionAnchor.zenithReply.page == .notch
                        && SettingsSectionAnchor.zenithClaudeHooks.page == .notch
                        && FeatureSettingsDestination(notch: .module(.agents), sectionAnchor: .zenithClaudeHooks)
                            .hasValidSectionAnchor
                        && FeatureSettingsDestination(notch: .module(.notifications), sectionAnchor: .zenithReply)
                            .hasValidSectionAnchor,
                     "the replies and Claude's hooks land inside their modules on the island's page")

        // The island's own buttons, search results and Orbit all go through the router.
        let router = SettingsRouter()
        for (feature, module) in modules {
            router.request(FeatureSettingsDestination(.about))
            router.request(feature.settingsDestination)
            let island = SettingsFeatureTests.IslandSettings(router: router)
            island.revealDestination()
            suite.expect(router.page == .notch && island.islandModule == module && island.modulesReveal == router.requestID
                            && island.tab == .layout,
                         "\(feature.rawValue) lands on the \(module.rawValue) tile, scrolled to, the tab left as it was")
            if let section = module.notchModule {
                suite.expect(island.selectedModule == section, "\(module.rawValue) is chosen on the Content tab too")
            }
        }
        router.request(FeatureSettingsDestination(notch: .module(.agents), sectionAnchor: .zenithClaudeHooks))
        let hooks = SettingsFeatureTests.IslandSettings(router: router)
        hooks.revealDestination()
        suite.expect(hooks.islandModule == .agents && hooks.modulesReveal == nil,
                     "a section inside a module selects its tile and leaves the scroll to the section's anchor")
        router.request(FeatureSettingsDestination(notch: .behavior))
        let behavior = SettingsFeatureTests.IslandSettings(router: router)
        behavior.revealDestination()
        suite.expect(behavior.tab == .behavior && behavior.modulesReveal == nil,
                     "a tab of the island still opens its tab")
    }

    private static func visibility(_ suite: TestSuite) {
        func visible(_ available: Set<AppFeature>) -> Bool {
            FeatureVisibilitySupport.isPageVisible(.notch, isAvailable: available.contains)
        }
        suite.expect(visible([.notch]) && visible([.notchCalendar]) && visible([.notchMascot]) && visible([.notchAgents])
                        && !visible([]),
                     "the island's page stays while the island or any of its modules is installed")
        suite.expect(IslandSettingsModule.allCases.allSatisfy { FeatureVisibilitySupport.features(for: .notch).contains($0.feature) },
                     "every module's feature keeps the island's page")
    }
}
