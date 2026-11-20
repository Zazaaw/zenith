// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: the About page's words, where its feature tiles lead, its
// bento grid and the logic behind its motion.
enum ZenithAboutTests {
    static func run(_ suite: TestSuite) {
        strings(suite)
        figures(suite)
        routes(suite)
        bento(suite)
        revealQueue(suite)
        decrypt(suite)
        maker(suite)
    }

    private static func strings(_ suite: TestSuite) {
        let english = ZenithStrings.about(.enUS)
        for language in AppLanguage.allCases {
            let page = ZenithStrings.about(language)
            let tiles = ZenithFeatureArea.ID.allCases.map(page.area)
            let values = Mirror(reflecting: page).children.compactMap { $0.value as? String }
                + tiles.flatMap { [$0.title, $0.caption] + $0.chips }
            suite.expect(values.count == 12 + tiles.reduce(0) { $0 + 2 + $1.chips.count }
                            && values.allSatisfy { !$0.isEmpty && !$0.contains("'") },
                         "\(language.rawValue) words the whole About page, with curly apostrophes")
            suite.expect(values.allSatisfy { !$0.contains("\u{2014}") },
                         "\(language.rawValue) keeps em dashes out of the About page's own strings")
            suite.expect(Set(page.areas.keys) == Set(ZenithFeatureArea.ID.allCases),
                         "\(language.rawValue) words every feature tile")
            suite.expect(ZenithFeatureArea.ID.allCases.allSatisfy {
                page.area($0).chips.count == english.area($0).chips.count
            }, "\(language.rawValue) names as many things on every tile as English does")
            for area in ZenithAbout.areas {
                suite.expect(area.products.allSatisfy { page.area(area.id).chips.contains($0) },
                             "\(language.rawValue): \(area.id.rawValue) keeps \(area.products) as they are")
            }
        }
        suite.expect(english.featuresTitle == "Features" && english.madeBy == "Made by"
                        && english.role == "Fullstack developer & designer",
                     "the section titles and the maker's line read as before")
    }

    private static func figures(_ suite: TestSuite) {
        suite.expect(ZenithAbout.featureCount == AppFeature.allCases.count && ZenithAbout.featureCount > 50,
                     "the feature figure counts what the Features page lists")
        suite.expect(ZenithAbout.languageCount == 15, "Zenith speaks fifteen languages")
        suite.expect(ZenithAbout.accountCount == 0, "Zenith asks for no account")
        suite.expect(ZenithAbout.rotatingWords == ["peak", "notch", "music", "agents", "builds", "files"],
                     "the headline turns through what Zenith brings to the notch")
    }

    private static func routes(_ suite: TestSuite) {
        let areas = Dictionary(uniqueKeysWithValues: ZenithAbout.areas.map { ($0.id, $0) })
        suite.expect(ZenithAbout.areas.map(\.id) == ZenithFeatureArea.ID.allCases,
                     "the bento shows every tile once, in reading order")
        suite.expect(ZenithAbout.areas.allSatisfy { !$0.features.isEmpty && !$0.symbol.isEmpty },
                     "every tile stands for features and has a symbol")

        // Everything installed: each tile opens its own part of Settings.
        let expected: [ZenithFeatureArea.ID: FeatureSettingsDestination] = [
            .island: FeatureSettingsDestination(.notch),
            .agents: FeatureSettingsDestination(notch: .module(.agents)),
            .developers: FeatureSettingsDestination(notch: .module(.vercel)),
            .files: FeatureSettingsDestination(.shelf),
            .capture: FeatureSettingsDestination(.screenshot, sectionAnchor: .screenshot),
            .system: FeatureSettingsDestination(.monitor),
            .windows: FeatureSettingsDestination(.switcher, sectionAnchor: .switcher),
            .input: FeatureSettingsDestination(.mouse, sectionAnchor: .smoothScroll),
            .sound: FeatureSettingsDestination(.general, sectionAnchor: .mixer),
            .utilities: FeatureSettingsDestination(.quickTools, sectionAnchor: .quickLauncher),
        ]
        for area in ZenithAbout.areas {
            let route = area.route(isAvailable: { _ in true })
            suite.expect(route.destination == expected[area.id] && route.targetFeature == nil,
                         "\(area.id.rawValue) opens its settings")
            suite.expect(route.destination.hasValidSectionAnchor,
                         "\(area.id.rawValue) leads to an anchor on its own page")
            suite.expect(route.destination.page != .about && route.destination.page != .features,
                         "\(area.id.rawValue) leaves About for a real settings page")
        }
        let island = areas[.island]!.route(isAvailable: { _ in true })
        suite.expect(island.sidebarFeature == .notch, "the island tile selects the island's sidebar row")

        // The first feature gone: the next one still installed.
        let developers = areas[.developers]!.route(isAvailable: { $0 != .notch })
        suite.expect(developers.destination == FeatureSettingsDestination(.commandBar)
                        && developers.sidebarFeature == .commandBar,
                     "without the island, the developer tile opens the Command Bar")
        let capture = areas[.capture]!.route(isAvailable: { $0 != .screenshot })
        suite.expect(capture.destination == AppFeature.screenRecorder.settingsDestination,
                     "without screenshots, the capture tile opens the recorder")

        // Nothing installed: the Features page, at the tile's first feature.
        for area in ZenithAbout.areas {
            let route = area.route(isAvailable: { _ in false })
            suite.expect(route.destination == FeatureSettingsDestination(.features)
                            && route.targetFeature == area.features.first && route.sidebarFeature == nil,
                         "\(area.id.rawValue) leads to Features when none of it is installed")
        }
        let empty = ZenithFeatureArea(id: .sound, symbol: "x", span: 1, features: [])
        suite.expect(empty.route(isAvailable: { _ in true }).destination == FeatureSettingsDestination(.features),
                     "a tile without features falls back to the Features page")
    }

    private static func bento(_ suite: TestSuite) {
        suite.expect(ZenithBento.columns(for: 640) == 2 && ZenithBento.columns(for: ZenithBento.twoColumnWidth) == 2
                        && ZenithBento.columns(for: 424) == 1,
                     "two columns at normal widths, one when narrow")
        let spans = ZenithAbout.areas.map(\.span)
        suite.expect(ZenithBento.rows(spans: spans, columns: 2) == [[0], [1, 2], [3, 4], [5], [6, 7], [8, 9]],
                     "the bento runs wide, two pairs, wide, two pairs")
        suite.expect(ZenithBento.rows(spans: spans, columns: 1) == spans.indices.map { [$0] },
                     "one column stacks every tile")
        suite.expect(ZenithBento.rows(spans: [1, 2, 1], columns: 2) == [[0], [1], [2]],
                     "a tile before a wide one gets a row to itself")
        suite.expect(ZenithBento.rows(spans: [], columns: 2).isEmpty && ZenithBento.rows(spans: [3], columns: 2) == [[0]],
                     "no tiles make no rows, and a span wider than the grid is clamped")
        suite.expect(ZenithBento.shares(spans: [1], columns: 2) == [1] && ZenithBento.shares(spans: [1, 1], columns: 2) == [0.5, 0.5],
                     "a tile alone on a row stretches across it; a pair splits it")
    }

    private static func revealQueue(_ suite: TestSuite) {
        var queue = ZenithRevealQueue(step: 0.05)
        let first = queue.schedule([3, 1, 2, 1], now: 10)
        suite.expect(first.map(\.index) == [1, 2, 3] && zip(first.map(\.delay), [0, 0.05, 0.1]).allSatisfy { abs($0 - $1) < 1e-9 },
                     "tiles that come into view together arrive in reading order, a step apart")
        let next = queue.schedule([4, 2], now: 10.02)
        suite.expect(next.count == 1 && next[0].index == 4 && abs(next[0].delay - 0.13) < 1e-9,
                     "a later tile waits for the ones already on their way, and none arrives twice")
        let later = queue.schedule([5], now: 20)
        suite.expect(later == [ZenithRevealQueue.Slot(index: 5, delay: 0)],
                     "a tile reached long after the others comes in at once")
    }

    private static func decrypt(_ suite: TestSuite) {
        for word in ZenithAbout.rotatingWords + ["Über mich", "关于", "A"] {
            let steps = ZenithDecrypt.stepCount(for: word)
            var settled = 0
            var keepsLength = true
            var growsLeftToRight = true
            for step in 0..<steps {
                let frame = ZenithDecrypt.frame(of: word, step: step, random: { _ in 0 })
                keepsLength = keepsLength
                    && frame.settled.count + (frame.cursor ? 1 : 0) + frame.noise.count == word.count
                growsLeftToRight = growsLeftToRight && word.hasPrefix(frame.settled)
                    && frame.settled.count >= settled
                settled = frame.settled.count
            }
            suite.expect(keepsLength, "\(word): every decrypt frame is as long as the word")
            suite.expect(growsLeftToRight, "\(word): letters settle left to right and never unsettle")
            suite.expect(ZenithDecrypt.frame(of: word, step: steps) == .clean(word),
                         "\(word): the effect ends on the clean word")
        }
        let first = ZenithDecrypt.frame(of: "agents", step: 0, random: { _ in 0 })
        suite.expect(first.settled.isEmpty && first.cursor && first.noise == "_____",
                     "the first frame is the block leading pure noise")
        let spaced = ZenithDecrypt.frame(of: "Über mich", step: 0, random: { _ in 1 })
        suite.expect(spaced.noise == "<<< <<<<", "spaces survive the noise, so the title keeps its shape")
        suite.expect(ZenithDecrypt.frame(of: "", step: 0) == .clean(""), "an empty title has nothing to decrypt")
        let longest = ZenithAbout.rotatingWords.map { ZenithDecrypt.stepCount(for: $0) }.max() ?? 0
        suite.expect(longest * ZenithDecrypt.stepMilliseconds < 800,
                     "every word settles well inside its three-second turn")
    }

    private static func maker(_ suite: TestSuite) {
        suite.expect(ZenithMaker.socials.allSatisfy { $0.url.scheme == "https" },
                     "the social buttons only open the web, never mail or a phone")
        suite.expect(ZenithMaker.socials.count == 4 && ZenithMaker.socials.first?.title == nil,
                     "the maker's site comes first, then GitHub, LinkedIn and Instagram")
    }
}
