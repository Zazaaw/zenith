// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: the Settings kit's decisions (docs/SETTINGS-KIT.md): one tint
/// per sidebar group, which caption stays inline and which becomes an ⓘ,
/// when "More options" is open, and when kit art may move.
enum SettingsKitTests {
    static func run(_ suite: TestSuite) {
        tints(suite)
        captions(suite)
        moreOptions(suite)
        motion(suite)
    }

    private static func tints(_ suite: TestSuite) {
        let all = SettingsSidebarGroup.allCases.map(ZenithCategoryTint.of)
        suite.expect(all.allSatisfy { $0.stage.count == 3 && $0.colors.count == 2 },
                     "every group has a tint pair and a three-stop stage")
        suite.expect(ZenithCategoryTint.of(.tiles) == ZenithCategoryTint.zenith
                        && ZenithCategoryTint.of(.zenith) == ZenithCategoryTint.zenith,
                     "Zenith's own pages share the indigo-to-coral stage of the General mockup")
        let feature = SettingsSidebarGroup.allCases.filter { $0 != .tiles && $0 != .zenith }
        let stages = feature.map { group in ZenithCategoryTint.of(group).stage.map { "\($0.red),\($0.green),\($0.blue)" } }
        suite.expect(Set(stages).count == feature.count, "each feature group's stage is its own")
        suite.expect(ZenithCategoryTint.of(.fromOrbit).light == ZenithRGB(1, 0.72, 0.25),
                     "From Orbit takes the hero mockup's amber")
        suite.expect(ZenithCategoryTint.of(.page(.mechakey)) == ZenithCategoryTint.of(.fromOrbit)
                        && ZenithCategoryTint.of(.page(.general)) == ZenithCategoryTint.zenith,
                     "a page's tint is its sidebar group's")
        suite.expect(SettingsSidebarGroup.of(page: .lockScreen) == .island
                        && SettingsSidebarGroup.island.tint.count == 2
                        && SettingsSidebarGroup.zenith.tint.count == 2,
                     "the sidebar's fallback icons read the same table, grey for Zenith's own")
        // A dark stage keeps white content readable; a light one stays pale.
        suite.expect(all.allSatisfy { tint in tint.stageStops(dark: true).prefix(2).allSatisfy { $0.luminance < 0.2 } },
                     "the dark stage's first two stops stay dark enough for white content")
        suite.expect(all.allSatisfy { tint in tint.stageStops(dark: false).allSatisfy { $0.luminance > 0.45 } },
                     "the light stage is a soft tint, never a strong colour")
        // The label in Light Mode is the deep end pulled towards black.
        suite.expect(all.allSatisfy { $0.label(dark: false).luminance < $0.deep.luminance + 0.0001 },
                     "the category label darkens on light backgrounds")
        let mid = ZenithRGB(0, 0, 0).mixed(with: .white, 0.5)
        let past = ZenithRGB.white.mixed(with: .night, 2)
        suite.expect(mid == ZenithRGB(0.5, 0.5, 0.5)
                        && abs(past.red - ZenithRGB.night.red) < 1e-9 && abs(past.blue - ZenithRGB.night.blue) < 1e-9,
                     "mixing is linear and clamped")
        suite.expect(SettingsSidebarGroup.zenith.categoryLabel == "Zenith"
                        && SettingsSidebarGroup.fromOrbit.categoryLabel == "From Orbit",
                     "the hero's label is the group's title, Zenith for its own pages")
    }

    private static func captions(_ suite: TestSuite) {
        typealias P = ZenithCaptionRule.Presentation
        suite.expect(ZenithCaptionRule.presentation(caption: "Opens at login.", essential: false)
                        == P(inline: nil, info: "Opens at login."),
                     "a row's caption becomes its ⓘ")
        suite.expect(ZenithCaptionRule.presentation(caption: "Allow Input Monitoring first.", essential: true)
                        == P(inline: "Allow Input Monitoring first.", info: nil),
                     "an essential caption stays under the title")
        suite.expect(ZenithCaptionRule.presentation(caption: nil, essential: false) == P(inline: nil, info: nil)
                        && ZenithCaptionRule.presentation(caption: "  ", essential: true) == P(inline: nil, info: nil),
                     "no caption, or a blank one, shows nothing")
        suite.expect(ZenithCaptionRule.presentation(info: "Why.", essential: "Must read.")
                        == P(inline: "Must read.", info: "Why."),
                     "a row can carry both an ⓘ and an essential line")
    }

    private static func moreOptions(_ suite: TestSuite) {
        let inside: Set<SettingsSectionAnchor> = [.zenithMechakeyRepeat]
        suite.expect(ZenithMoreOptionsRule.key("mechakey") == "zenithMoreOptions.mechakey"
                        && ZenithMoreOptionsRule.key("mechakey") != ZenithMoreOptionsRule.key("general"),
                     "each page remembers its own fold")
        suite.expect(!ZenithMoreOptionsRule.isOpen(remembered: false, openedForSearch: false),
                     "More options starts folded")
        suite.expect(ZenithMoreOptionsRule.isOpen(remembered: true, openedForSearch: false),
                     "a fold left open stays open")
        suite.expect(ZenithMoreOptionsRule.opensForSearch(target: .zenithMechakeyRepeat, inside: inside)
                        && ZenithMoreOptionsRule.isOpen(remembered: false, openedForSearch: true),
                     "a search landing inside opens the fold")
        suite.expect(!ZenithMoreOptionsRule.opensForSearch(target: .zenithMechakey, inside: inside)
                        && !ZenithMoreOptionsRule.opensForSearch(target: nil, inside: inside)
                        && !ZenithMoreOptionsRule.opensForSearch(target: .zenithMechakeyRepeat, inside: []),
                     "a landing elsewhere, or none, leaves it folded")
        suite.expect(SettingsSectionAnchor.zenithMechakeyRepeat.page == .mechakey,
                     "Mechakey's folded anchor lands on Mechakey")
    }

    private static func motion(_ suite: TestSuite) {
        func moves(_ shown: Bool, _ visible: Bool, _ reduce: Bool, _ saving: Bool) -> Bool {
            ZenithKitMotionRule.animates(pageShown: shown, windowVisible: visible, reduceMotion: reduce,
                                         savingBattery: saving)
        }
        suite.expect(moves(true, true, false, false), "the hero moves while its page is on screen")
        suite.expect(!moves(false, true, false, false) && !moves(true, false, false, false),
                     "it stops when the page goes or the window is hidden or covered")
        suite.expect(!moves(true, true, true, false), "it stands still under Reduce Motion")
        suite.expect(!moves(true, true, false, true), "it stands still while the battery saver saves")
        suite.expect(ZenithKitMotionRule.stillTime > 0 && ZenithKitMotionRule.stillTime < 4,
                     "the still frame is a moment inside every loop")
    }
}
