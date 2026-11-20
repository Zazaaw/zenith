// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit

// Zenith fork: what the About page says about Zenith and its maker, where its
// feature tiles lead, and the plain logic behind its motion and its bento
// grid, kept apart from the views so tests can reach it.

/// Zenith itself: the hero’s line, the figures and the feature tiles.
enum ZenithAbout {
    /// “Your Mac, at its ⟨word⟩”, split where it may wrap. English in every
    /// language on purpose: it is Zenith’s signature line.
    static let headlineLead = "Your Mac,"
    static let headlineJoin = "at its"
    /// What Zenith brings to the notch, one turn of the rotating word each.
    static let rotatingWords = ["peak", "notch", "music", "agents", "builds", "files"]

    /// Everything the Features page lists, each of which can be switched off.
    static var featureCount: Int { AppFeature.allCases.count }
    static var languageCount: Int { AppLanguage.allCases.count }
    /// Zenith asks for no account and sends nothing about its use anywhere.
    static let accountCount = 0

    /// The bento, in reading order. Spans follow a wide tile, two rows of
    /// pairs, a wide tile, two rows of pairs.
    static let areas: [ZenithFeatureArea] = [
        ZenithFeatureArea(id: .island, symbol: "macbook", span: 2, features: [.notch]),
        ZenithFeatureArea(id: .agents, symbol: "sparkles", span: 1, features: [.notchAgents],
                          products: ["Claude", "Codex"]),
        // Vercel, GitHub and WakaTime are sections of the island; Vercel is
        // the one always listed there, so its options are where the tile lands.
        ZenithFeatureArea(id: .developers, symbol: "chevron.left.forwardslash.chevron.right", span: 1,
                          features: [.notch, .commandBar],
                          leadDestination: FeatureSettingsDestination(notch: .module(.vercel)),
                          products: ["Vercel", "GitHub", "WakaTime"]),
        ZenithFeatureArea(id: .files, symbol: "tray.full", span: 1, features: [.shelf, .clipboardHistory],
                          products: ["AirDrop"]),
        ZenithFeatureArea(id: .capture, symbol: "camera.viewfinder", span: 1,
                          features: [.screenshot, .screenRecorder, .screenOCR, .colorPicker]),
        ZenithFeatureArea(id: .system, symbol: "gauge.with.dots.needle.50percent", span: 2,
                          features: FeatureVisibilitySupport.monitorFeatures + [.keepAwake]),
        ZenithFeatureArea(id: .windows, symbol: "rectangle.on.rectangle", span: 1,
                          features: [.switcher, .windowLayout, .dockPreview, .autoQuit]),
        ZenithFeatureArea(id: .input, symbol: "computermouse", span: 1,
                          features: [.smoothScroll, .scrollInverter, .mouseButtonShortcuts, .textSnippets, .superKey]),
        ZenithFeatureArea(id: .sound, symbol: "speaker.wave.2", span: 1,
                          features: [.mixer, .soundOutputSwitcher, .micMute]),
        ZenithFeatureArea(id: .utilities, symbol: "wand.and.rays", span: 1,
                          features: [.quickLauncher, .scratchpad, .cleaner, .uninstaller, .homebrew],
                          products: ["Homebrew"]),
    ]
}

/// One tile of the Features bento: a part of Zenith and where it is set up.
struct ZenithFeatureArea {
    enum ID: String, CaseIterable {
        case island, agents, developers, files, capture, system, windows, input, sound, utilities
    }

    let id: ID
    let symbol: String
    /// Columns the tile spans when the grid has two.
    let span: Int
    /// The features the tile stands for, in the order it tries to open them.
    let features: [AppFeature]
    /// A particular spot for the first feature, instead of its usual page.
    let leadDestination: FeatureSettingsDestination?
    /// Names on the tile’s chips that stay the same in every language.
    let products: [String]

    init(id: ID, symbol: String, span: Int, features: [AppFeature],
         leadDestination: FeatureSettingsDestination? = nil, products: [String] = []) {
        self.id = id
        self.symbol = symbol
        self.span = span
        self.features = features
        self.leadDestination = leadDestination
        self.products = products
    }

    /// Where a click goes: the settings of the first feature still installed,
    /// or, when none is, the Features page at the first one, where it can be
    /// installed again. A page whose features are all off is not in Settings.
    func route(isAvailable: (AppFeature) -> Bool) -> ZenithFeatureRoute {
        guard let lead = features.first else {
            return ZenithFeatureRoute(destination: FeatureSettingsDestination(.features),
                                      targetFeature: nil, sidebarFeature: nil)
        }
        guard let feature = features.first(where: isAvailable) else {
            return ZenithFeatureRoute(destination: FeatureSettingsDestination(.features),
                                      targetFeature: lead, sidebarFeature: nil)
        }
        let destination = feature == lead ? leadDestination ?? feature.settingsDestination
                                          : feature.settingsDestination
        return ZenithFeatureRoute(destination: destination, targetFeature: nil, sidebarFeature: feature)
    }
}

struct ZenithFeatureRoute: Equatable {
    let destination: FeatureSettingsDestination
    /// The Features page row to reveal, when the tile leads there.
    let targetFeature: AppFeature?
    /// The sidebar row to select, when it is the feature’s own.
    let sidebarFeature: AppFeature?
}

/// The bento’s arithmetic: how many columns a width allows, and which tiles
/// share a row.
enum ZenithBento {
    /// Below this the tiles stack in one column.
    static let twoColumnWidth: CGFloat = 460

    static func columns(for width: CGFloat) -> Int { width >= twoColumnWidth ? 2 : 1 }

    /// Tile indices row by row. A tile that does not fit in what is left of
    /// a row starts the next one; the tiles of a row that is not full share
    /// its width, so a tile left on its own stretches across.
    static func rows(spans: [Int], columns: Int) -> [[Int]] {
        let columns = max(columns, 1)
        var rows: [[Int]] = []
        var row: [Int] = []
        var used = 0
        for (index, span) in spans.enumerated() {
            let span = min(max(span, 1), columns)
            if used + span > columns, !row.isEmpty {
                rows.append(row)
                row = []
                used = 0
            }
            row.append(index)
            used += span
        }
        if !row.isEmpty { rows.append(row) }
        return rows
    }

    /// Each tile’s share of its row, for the spans given: the row’s width
    /// split in proportion to them.
    static func shares(spans: [Int], columns: Int) -> [Double] {
        let clamped = spans.map { Double(min(max($0, 1), max(columns, 1))) }
        let total = clamped.reduce(0, +)
        return clamped.map { total > 0 ? $0 / total : 0 }
    }
}

/// Hands out entrance times, so tiles that come into view together still
/// arrive one after another, in reading order, `step` apart, and a tile that
/// comes into view later waits for the ones already on their way.
struct ZenithRevealQueue {
    struct Slot: Equatable {
        let index: Int
        /// Seconds from now.
        let delay: TimeInterval
    }

    let step: TimeInterval
    private var nextSlot = -TimeInterval.greatestFiniteMagnitude
    private var scheduled: Set<Int> = []

    init(step: TimeInterval) { self.step = step }

    /// Slots for the indices not scheduled before, lowest index first. `now`
    /// is any steadily rising clock, in seconds.
    mutating func schedule(_ indices: [Int], now: TimeInterval) -> [Slot] {
        var slot = max(now, nextSlot)
        var slots: [Slot] = []
        for index in Set(indices).sorted() where !scheduled.contains(index) {
            scheduled.insert(index)
            slots.append(Slot(index: index, delay: slot - now))
            slot += step
        }
        if !slots.isEmpty { nextSlot = slot }
        return slots
    }
}

/// Who makes Zenith. Public facts only, as on p441z.my.id.
enum ZenithMaker {
    static let name = "Faiz Hazim Hawari"
    static let handle = "p441z"
    static let portfolioURL = URL(string: "https://p441z.my.id")!

    /// The round buttons on the maker’s card, left to right. No email or phone.
    static let socials: [ZenithSocialLink] = [
        ZenithSocialLink(title: nil, url: portfolioURL, icon: .symbol("globe")),
        ZenithSocialLink(title: "GitHub", url: URL(string: "https://github.com/Zazaaw")!, icon: .bundled("si-github")),
        ZenithSocialLink(title: "LinkedIn", url: URL(string: "https://www.linkedin.com/in/zazaaw/")!,
                         icon: .bundled("si-linkedin")),
        ZenithSocialLink(title: "Instagram", url: URL(string: "https://www.instagram.com/faizhazimhawarii")!,
                         icon: .bundled("si-instagram")),
    ]

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
