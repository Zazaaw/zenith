// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit

// Zenith fork: what the About page says about its maker, and the plain logic
// behind its motion, kept apart from the views so tests can reach it. Public
// facts only, as on p441z.my.id.

/// Who makes Zenith.
enum ZenithMaker {
    static let name = "Faiz Hazim Hawari"
    static let handle = "p441z"
    static let portfolioURL = URL(string: "https://p441z.my.id")!

    /// The hero’s signature lines. English in every language on purpose: they
    /// are the maker’s own words, exactly as on the portfolio.
    /// The headline is “I build for the web — and I ⟨word⟩”, split where it may wrap.
    static let headlineLead = "I build for the web —"
    static let headlineJoin = "and I"
    static let rotatingWords = ["design", "code", "shoot", "ship"]
    static let subtitle = "Fullstack Developer & Designer — I code, design, and shoot."

    /// Years building, shown as “4+”.
    static let yearsBuilding = 4
    static let disciplines = 3

    /// The round buttons under the hero, left to right. No email or phone.
    static let socials: [ZenithSocialLink] = [
        ZenithSocialLink(title: nil, url: portfolioURL, icon: .symbol("globe")),
        ZenithSocialLink(title: "GitHub", url: URL(string: "https://github.com/Zazaaw")!, icon: .bundled("si-github")),
        ZenithSocialLink(title: "LinkedIn", url: URL(string: "https://www.linkedin.com/in/zazaaw/")!,
                         icon: .bundled("si-linkedin")),
        ZenithSocialLink(title: "Instagram", url: URL(string: "https://www.instagram.com/faizhazimhawarii")!,
                         icon: .bundled("si-instagram")),
    ]

    /// The “Now” timeline, newest role first. Add entries here; leave out the
    /// day job on purpose.
    static let timeline: [ZenithTimelineEntry] = [
        ZenithTimelineEntry(role: .founder, organisation: "Satu Visual",
                            location: "Pematangsiantar, Sumatera Utara", start: 2025, end: nil, tile: .studio),
        ZenithTimelineEntry(role: .fullstackDeveloper, organisation: "Jamaah.net",
                            location: "Medan, Sumatera Utara", start: 2026, end: nil, tile: .symbol("person.3")),
        ZenithTimelineEntry(role: .maker, organisation: "Zenith", location: nil, start: 2026, end: nil, tile: .app),
    ]

    /// The tools in the Stack marquee. Icons are simple-icons (CC0) SVGs in
    /// Resources/Images; a nil icon shows the name alone.
    static let stack: [ZenithStackItem] = [
        ZenithStackItem(name: "Swift", icon: "si-swift"),
        ZenithStackItem(name: "SwiftUI", icon: nil),
        ZenithStackItem(name: "TypeScript", icon: "si-typescript"),
        ZenithStackItem(name: "Next.js", icon: "si-nextdotjs"),
        ZenithStackItem(name: "React", icon: "si-react"),
        ZenithStackItem(name: "Node.js", icon: "si-nodedotjs"),
        ZenithStackItem(name: "Go", icon: "si-go"),
        ZenithStackItem(name: "Laravel", icon: "si-laravel"),
        ZenithStackItem(name: "Supabase", icon: "si-supabase"),
        ZenithStackItem(name: "PostgreSQL", icon: "si-postgresql"),
        ZenithStackItem(name: "Flutter", icon: "si-flutter"),
        ZenithStackItem(name: "Docker", icon: "si-docker"),
        ZenithStackItem(name: "Figma", icon: "si-figma"),
        ZenithStackItem(name: "Lightroom", icon: "si-adobelightroom"),
    ]

    /// The stack split into marquee rows, each starting somewhere else in the
    /// list so the same names never line up from one row to the next.
    static func stackRows(_ count: Int = 3) -> [[ZenithStackItem]] {
        guard count > 0, !stack.isEmpty else { return [] }
        return (0..<count).map { row in
            let shift = (row * stack.count / count + row * 2) % stack.count
            return Array(stack[shift...] + stack[..<shift])
        }
    }

    static let photo: NSImage? = {
        guard let url = Bundle.main.url(forResource: "zenith-maker", withExtension: "jpg",
                                        subdirectory: "Images") else { return nil }
        return NSImage(contentsOf: url)
    }()
}

struct ZenithSocialLink {
    enum Icon {
        case symbol(String)
        /// An SVG in Resources/Images, drawn as a template.
        case bundled(String)
    }

    /// nil for the maker’s own site, which takes its localised name.
    let title: String?
    let url: URL
    let icon: Icon
}

struct ZenithTimelineEntry {
    enum Role {
        case founder, fullstackDeveloper, maker
        /// A role that needs no translation, for entries added later.
        case custom(String)
    }

    enum Tile {
        /// The Satu Visual badge.
        case studio
        /// Zenith’s own icon.
        case app
        case symbol(String)
    }

    let role: Role
    let organisation: String
    let location: String?
    let start: Int
    /// nil while the role is ongoing.
    let end: Int?
    let tile: Tile

    var isCurrent: Bool { end == nil }

    func roleTitle(_ strings: ZenithMakerStrings) -> String {
        switch role {
        case .founder: return strings.founder
        case .fullstackDeveloper: return strings.fullstackDeveloper
        case .maker: return strings.maker
        case let .custom(title): return title
        }
    }

    /// “2025 – Present”, or “2023 – 2024”, or one year when it began and ended in it.
    func period(_ strings: ZenithMakerStrings) -> String {
        guard let end else { return "\(start) – \(strings.present)" }
        return end == start ? "\(start)" : "\(start) – \(end)"
    }
}

struct ZenithStackItem: Equatable {
    let name: String
    let icon: String?
}

// MARK: - Decrypt

/// One frame of a word decrypting: the letters already settled, then the
/// block that leads the noise for the first half, then the noise itself.
struct ZenithDecryptFrame: Equatable {
    var settled: String
    var cursor: Bool
    var noise: String

    static func clean(_ text: String) -> ZenithDecryptFrame {
        ZenithDecryptFrame(settled: text, cursor: false, noise: "")
    }

    var isClean: Bool { !cursor && noise.isEmpty }
}

/// Noise glyphs resolving left to right into a word, as on p441z.my.id. The
/// steps are discrete by design (the page swaps one string per step), so they
/// run on a short sleep rather than the display clock.
enum ZenithDecrypt {
    static let glyphs: [Character] = Array("_<>*/#")
    /// Time between frames.
    static let stepMilliseconds = 34
    /// All-noise frames before the first letter settles.
    static let leadSteps = 3

    /// Frames for a word: a short lead of noise, then one letter every two steps.
    static func stepCount(for text: String) -> Int { leadSteps + 2 * text.count }

    /// The frame `step` of `stepCount(for:)` frames. `random(n)` picks a glyph
    /// index below `n`; tests pass a fixed one.
    static func frame(of text: String, step: Int,
                      random: (Int) -> Int = { Int.random(in: 0..<$0) }) -> ZenithDecryptFrame {
        let letters = Array(text)
        let count = letters.count
        guard step < stepCount(for: text), count > 0 else { return .clean(text) }
        let settledCount = min(count, max(0, (step - leadSteps + 1) / 2))
        guard settledCount < count else { return .clean(text) }
        let cursor = step < leadSteps + count && count > 1
        let noiseStart = settledCount + (cursor ? 1 : 0)
        let noise = letters[min(noiseStart, count)...].map { letter -> Character in
            letter.isWhitespace ? letter : glyphs[random(glyphs.count) % glyphs.count]
        }
        return ZenithDecryptFrame(settled: String(letters[..<settledCount]), cursor: cursor, noise: String(noise))
    }
}

// MARK: - Word reveal

enum ZenithWordReveal {
    /// The pieces a paragraph rises in by: words with their trailing space,
    /// or single characters for writing that does not put spaces between
    /// words (Chinese, Japanese). Joined, they give back the paragraph.
    static func units(_ text: String) -> [String] {
        let spaces = text.filter(\.isWhitespace).count
        guard spaces * 12 >= text.count else { return text.map(String.init) }
        var units: [String] = []
        var current = ""
        for character in text {
            if !character.isWhitespace, let last = current.last, last.isWhitespace {
                units.append(current)
                current = ""
            }
            current.append(character)
        }
        if !current.isEmpty { units.append(current) }
        return units
    }
}
