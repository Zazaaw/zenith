// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: the Island group's pages. The island's sections with options
/// of their own each have a page, one sidebar row each, in the order the
/// design lists them; their features, search anchors and the island's own
/// links land there; and the island page keeps only what is its own.
enum IslandSettingsPagesTests {
    static let modulePages: [SettingsPage] = [.notchCalendar, .notchNotifications, .notchMusic, .notchTimer,
                                              .notchAgents, .notchDownloads, .notchWatch]

    static func run(_ suite: TestSuite) {
        sidebar(suite)
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
        suite.expect(island == [.page(.notch), .page(.lockScreen)] + modulePages.map { .page($0) } + [.page(.notchMascot)],
                     "the Island group lists the island, its lock screen, each section's page and the companion, once each")
        suite.expect(modulePages.allSatisfy { SettingsSidebarGroup.of(page: $0) == .island && $0.isNotchModulePage }
                        && !SettingsPage.notch.isNotchModulePage && !SettingsPage.notchMascot.isNotchModulePage,
                     "the sections' pages sit in the Island group")
        suite.expect((modulePages + [.notch, .notchMascot, .lockScreen]).allSatisfy {
                         SettingsSidebarIcons.orbitIcon(for: .page($0)) != nil
                     }, "every Island page has its Orbit icon")
        let withoutCalendar = sections(available: { $0 != .notchCalendar }).flatMap(\.items).map(\.id)
        suite.expect(!withoutCalendar.contains(.page(.notchCalendar)) && withoutCalendar.contains(.page(.notch)),
                     "a section's page leaves the sidebar with its feature, the island's stays")
    }

    private static func destinations(_ suite: TestSuite) {
        let pages: [(AppFeature, SettingsPage)] = [
            (.notchCalendar, .notchCalendar), (.notchNotifications, .notchNotifications), (.notchTimer, .notchTimer),
            (.notchLyrics, .notchMusic), (.notchQueue, .notchMusic), (.notchLiveEqualizer, .notchMusic),
            (.notchAgents, .notchAgents), (.notchDownloads, .notchDownloads), (.notchWatch, .notchWatch),
            (.notchMascot, .notchMascot), (.notchGestures, .notch), (.notchAccessories, .notch), (.notch, .notch),
        ]
        for (feature, page) in pages {
            suite.expect(feature.settingsDestination.page == page && feature.settingsDestination.sectionAnchor == nil,
                         "\(feature.rawValue) opens \(page) (Orbit's Open and the hub follow it)")
        }
        for module in NotchModule.allCases {
            let destination = FeatureSettingsDestination(notch: .module(module))
            if let page = module.settingsPage {
                suite.expect(destination == FeatureSettingsDestination(page) && destination.notchLocation == nil,
                             "the island's \(module.rawValue) link opens its own page")
            } else {
                suite.expect(destination.page == .notch && destination.notchLocation == .module(module),
                             "the island's \(module.rawValue) options stay on its Content tab")
            }
        }
        suite.expect(Set(NotchModule.allCases.compactMap(\.settingsPage)) == Set(modulePages),
                     "each section's page belongs to exactly one section")
        suite.expect(SettingsSectionAnchor.zenithReply.page == .notchNotifications
                        && SettingsSectionAnchor.zenithClaudeHooks.page == .notchAgents
                        && FeatureSettingsDestination(notch: .module(.agents), sectionAnchor: .zenithClaudeHooks)
                            .hasValidSectionAnchor,
                     "the replies and Claude's hooks land on their sections' pages")
        let router = SettingsRouter()
        router.request(AppFeature.notchMascot.settingsDestination)
        suite.expect(router.page == .notchMascot, "the companion's settings open its own page, not a tab of the island's")
    }

    private static func visibility(_ suite: TestSuite) {
        func visible(_ page: SettingsPage, _ available: Set<AppFeature>) -> Bool {
            FeatureVisibilitySupport.isPageVisible(page, isAvailable: available.contains)
        }
        suite.expect(visible(.notchMusic, [.notch]) && visible(.notchMusic, [.notchLyrics]) && !visible(.notchMusic, []),
                     "Music shows with the island or any of its extras")
        suite.expect(visible(.notchAgents, [.notchAgents]) && !visible(.notchAgents, [.notch]),
                     "Agents follows its own install")
        suite.expect(visible(.notch, [.notch]) && !visible(.notch, [.notchCalendar, .notchMascot]),
                     "the island page follows the island, not the sections that moved out")
    }
}
