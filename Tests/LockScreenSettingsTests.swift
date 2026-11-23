// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: Settings → Lock Screen. Its tabs hold one search anchor each,
/// so a search lands on the right tab; the last tab is remembered; the lyric
/// timing reads as a signed figure in each language; and every language words
/// the page with curly apostrophes and its placeholders intact.
enum LockScreenSettingsTests {
    static func run(_ suite: TestSuite) {
        typealias Tab = ZenithLockScreenSettingsTab

        // Each tab owns one anchor of the Lock Screen page, and back again.
        let anchors = Tab.allCases.map(\.anchor)
        suite.expect(Set(anchors).count == Tab.allCases.count, "each tab has its own anchor")
        for tab in Tab.allCases {
            suite.expect(tab.anchor.page == .lockScreen, "\(tab) lands on the Lock Screen page")
            suite.expect(Tab(anchor: tab.anchor) == tab, "\(tab)'s anchor opens \(tab)")
        }
        let lockAnchors = SettingsSectionAnchor.allCases.filter { $0.page == .lockScreen }
        suite.expect(Set(lockAnchors) == Set(anchors), "every Lock Screen anchor sits in a tab: \(lockAnchors)")
        suite.expect(Tab(anchor: nil) == nil && Tab(anchor: .zenithQR) == nil,
                     "no anchor, or one of another page, keeps the tab as it was")

        // The search result of each tab opens that tab.
        let state = SettingsSearchState(defaults: UserDefaults(suiteName: "com.vorssaint.tests.lockscreen-settings")!,
                                        hardware: .init(battery: true, notchedDisplay: true, plainDisplay: false,
                                                        keyboardLight: true, bluetoothSleep: true, brightnessOSD: true))
        let items = ZenithSettingsSearch.items(language: .enUS, state: state)
        for tab in Tab.allCases {
            let item = items.first { $0.id == .setting(tab.anchor) }
            suite.expect(item.flatMap { Tab(anchor: $0.destination.sectionAnchor) } == tab,
                         "Settings search has a result that opens \(tab)")
        }

        // The last tab is remembered; anything else opens the first one.
        suite.expect(Tab.stored(nil) == .wallpaper && Tab.stored("") == .wallpaper && Tab.stored("lyrics") == .wallpaper,
                     "nothing or an unknown tab opens Over the wallpaper")
        suite.expect(Tab.allCases.allSatisfy { Tab.stored($0.rawValue) == $0 }, "a stored tab opens again")

        // The lyric timing: signed, to the tenth, kept in range.
        let english = ZenithStrings.lockScreenPage(.enUS)
        let us = Locale(identifier: "en_US")
        let cases: [(Double, String)] = [
            (0, "0 s"), (0.04, "0 s"), (-0.04, "0 s"), (0.4, "+0.4 s"), (-1.2, "\u{2212}1.2 s"),
            (0.30000000000000004, "+0.3 s"), (3, "+3 s"), (-3, "\u{2212}3 s"), (7, "+3 s"), (-9, "\u{2212}3 s"),
            (.nan, "0 s"), (.infinity, "0 s"),
        ]
        for (value, expected) in cases {
            let shown = english.offset(value, locale: us)
            suite.expect(shown == expected, "\(value) s reads \"\(expected)\": \(shown)")
        }
        let german = ZenithStrings.lockScreenPage(.de).offset(0.4, locale: Locale(identifier: "de_DE"))
        suite.expect(german == "+0,4 s", "the figure follows the region's decimal mark: \(german)")
        suite.expect(english.highlighting("Activity row") == "Highlighted: Activity row",
                     "the outlined part is named in the line")

        // Every language words the page.
        for language in AppLanguage.allCases {
            let page = ZenithStrings.lockScreenPage(language)
            let values = Mirror(reflecting: page).children.compactMap { $0.value as? String }
            suite.expect(values.count >= 30 && values.allSatisfy { !$0.isEmpty },
                         "\(language.rawValue) words every part of the page")
            suite.expect(values.allSatisfy { !$0.contains("'") && !$0.contains("\u{2014}") },
                         "\(language.rawValue) words the page with curly apostrophes and no em dash")
            suite.expect(page.highlighted.contains("{part}") && page.seconds.contains("{value}"),
                         "\(language.rawValue) keeps the placeholders")
            suite.expect(!page.highlighting("X").contains("{") && !page.offset(1, locale: us).contains("{"),
                         "\(language.rawValue) fills the placeholders")
        }
    }
}
