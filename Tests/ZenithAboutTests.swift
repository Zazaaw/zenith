// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: the About page's words and the logic behind its motion.
enum ZenithAboutTests {
    static func run(_ suite: TestSuite) {
        strings(suite)
        decrypt(suite)
        wordReveal(suite)
        content(suite)
    }

    private static func strings(_ suite: TestSuite) {
        for language in AppLanguage.allCases {
            let values = Mirror(reflecting: ZenithStrings.maker(language)).children.compactMap { $0.value as? String }
            suite.expect(values.count == 15 && values.allSatisfy { !$0.isEmpty && !$0.contains("'") },
                         "\(language.rawValue) words the whole About page, with curly apostrophes")
            suite.expect(values.allSatisfy { !$0.contains("\u{2014}") },
                         "\(language.rawValue) keeps em dashes out of the About page's own strings")
        }
        let english = ZenithStrings.maker(.enUS)
        suite.expect(english.aboutTitle == "About" && english.nowTitle == "Now" && english.stackTitle == "Stack",
                     "the section titles read as on the portfolio")
    }

    private static func decrypt(_ suite: TestSuite) {
        for word in ZenithMaker.rotatingWords + ["Über mich", "关于", "A"] {
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
        let first = ZenithDecrypt.frame(of: "design", step: 0, random: { _ in 0 })
        suite.expect(first.settled.isEmpty && first.cursor && first.noise == "_____",
                     "the first frame is the block leading pure noise")
        let spaced = ZenithDecrypt.frame(of: "Über mich", step: 0, random: { _ in 1 })
        suite.expect(spaced.noise == "<<< <<<<", "spaces survive the noise, so the title keeps its shape")
        suite.expect(ZenithDecrypt.frame(of: "", step: 0) == .clean(""), "an empty title has nothing to decrypt")
        let duration = ZenithDecrypt.stepCount(for: "design") * ZenithDecrypt.stepMilliseconds
        suite.expect(duration < 800, "the word settles well inside its three-second turn")
    }

    private static func wordReveal(_ suite: TestSuite) {
        for language in AppLanguage.allCases {
            let bio = ZenithStrings.maker(language).bio
            let units = ZenithWordReveal.units(bio)
            suite.expect(units.joined() == bio && units.count > 20,
                         "\(language.rawValue): the bio rises in by pieces that join back into it")
        }
        suite.expect(ZenithWordReveal.units("one two  three") == ["one ", "two  ", "three"],
                     "words keep the spaces after them")
        suite.expect(ZenithWordReveal.units("我是设计师") == ["我", "是", "设", "计", "师"],
                     "writing without spaces rises in character by character")
    }

    private static func content(_ suite: TestSuite) {
        suite.expect(ZenithMaker.socials.allSatisfy { $0.url.scheme == "https" },
                     "the social buttons only open the web, never mail or a phone")
        suite.expect(ZenithMaker.timeline.map(\.organisation) == ["Satu Visual", "Jamaah.net", "Zenith"],
                     "the timeline lists the studio, Jamaah.net and Zenith only")
        let english = ZenithStrings.maker(.enUS)
        suite.expect(ZenithMaker.timeline[0].period(english) == "2025 – Present"
                        && ZenithTimelineEntry(role: .custom("Intern"), organisation: "X", location: nil,
                                               start: 2023, end: 2024, tile: .app).period(english) == "2023 – 2024",
                     "periods read as a span, ongoing ones ending in Present")
        let rows = ZenithMaker.stackRows(3)
        suite.expect(rows.count == 3 && rows.allSatisfy { Set($0.map(\.name)) == Set(ZenithMaker.stack.map(\.name)) }
                        && Set(rows.map { $0.first?.name ?? "" }).count == 3,
                     "every marquee row carries the whole stack, each starting elsewhere")
    }
}
