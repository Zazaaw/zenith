// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation

/// Zenith fork: the lock screen v2's switches as they stand when the lock
/// screen appears. Preferences cannot change while the Mac is locked, so the
/// views read these and never the defaults.
///
/// Each part also needs what it hangs from: the lyric and the title controls
/// need the now-playing line, the full layer needs the lyric, and the full
/// layer's corners need the full layer.
struct ZenithLockScreenV2Gates: Equatable {
    var jobs = false
    var nowPlaying = false
    var lyrics = false
    var karaoke = false
    var titleControls = false
    /// A soft dark glow behind the title and the lyric.
    var lyricShade = false
    var full = false
    var fullDisc = false
    var fullDiscSpin = false
    var fullAccount = false
    var fullDevice = false
    var fullClock = false
    var fullJobs = false
    var fullCoverColor = false
    var fullLoginHint = false
    /// What sits at the top right beside the close button, with `fullJobs`.
    var fullTopPrayer = false
    var fullTopWeather = false
    var fullTopTimer = false
    var fullTopCalendar = false
    var fullTopWakaTime = false
    /// The full layer's background, read with the rest: one colour or the
    /// blurred cover, the blur's strength, and the colour picked in Settings.
    var fullBackground = ZenithLockScreenFullBackground.fallback
    var fullBlurRadius = ZenithLockScreenFullBlur.fallback
    var fullCustomColor = ZenithLockScreenCustomColor.fallback
    var fullTone = ZenithLockScreenFullTone.fallback
    /// Seconds added to the lyric's timing, on top of the island's own adjustment.
    var lyricOffset = 0.0

    /// `music` is the lock screen's own music gate; `lyricsAvailable` is
    /// whether the island's lyrics are on at all (`NotchLyricsSupport.isEnabled`).
    static func resolve(music: Bool, lyricsAvailable: Bool,
                        in defaults: UserDefaults = .standard) -> Self {
        func on(_ option: ZenithLockScreenOption) -> Bool { option.isOn(in: defaults) }
        var gates = Self()
        gates.jobs = on(.jobs)
        gates.nowPlaying = music && on(.nowPlaying)
        gates.lyrics = gates.nowPlaying && lyricsAvailable && on(.lyrics)
        gates.karaoke = gates.lyrics && on(.karaoke)
        gates.titleControls = gates.nowPlaying && on(.titleControls)
        gates.lyricShade = gates.nowPlaying && on(.lyricShade)
        gates.full = gates.lyrics && on(.full)
        gates.fullDisc = gates.full && on(.fullDisc)
        gates.fullDiscSpin = gates.fullDisc && on(.fullDiscSpin)
        gates.fullAccount = gates.full && on(.fullAccount)
        gates.fullDevice = gates.full && on(.fullDevice)
        gates.fullClock = gates.full && on(.fullClock)
        gates.fullJobs = gates.full && on(.fullJobs)
        gates.fullCoverColor = gates.full && on(.fullCoverColor)
        gates.fullLoginHint = gates.full && on(.fullLoginHint)
        gates.fullTopPrayer = gates.full && on(.fullTopPrayer)
        gates.fullTopWeather = gates.full && on(.fullTopWeather)
        gates.fullTopTimer = gates.full && on(.fullTopTimer)
        gates.fullTopCalendar = gates.full && on(.fullTopCalendar)
        gates.fullTopWakaTime = gates.full && on(.fullTopWakaTime)
        if gates.full {
            gates.fullBackground = ZenithLockScreenFullBackground.current(in: defaults)
            gates.fullBlurRadius = ZenithLockScreenFullBlur.radius(in: defaults)
            gates.fullCustomColor = ZenithLockScreenCustomColor.rgb(in: defaults)
            gates.fullTone = ZenithLockScreenFullTone.current(in: defaults)
        }
        if gates.lyrics { gates.lyricOffset = ZenithLockScreenLyricOffset.seconds(in: defaults) }
        return gates
    }

    /// Whether the minimal layer has anything to click: the title controls,
    /// or the lyric that opens the full layer.
    var minimalTakesClicks: Bool { titleControls || full }
}

// MARK: - Colour

/// An sRGB colour, each channel 0...1.
struct ZenithLockScreenRGB: Equatable {
    var red: Double
    var green: Double
    var blue: Double

    init(red: Double, green: Double, blue: Double) {
        func clamp(_ value: Double) -> Double { value.isFinite ? min(1, max(0, value)) : 0 }
        self.red = clamp(red)
        self.green = clamp(green)
        self.blue = clamp(blue)
    }

    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }

    /// #1C1C1E, the full layer's background with the cover colour off.
    static let neutral = Self(hex: 0x1C1C1E)
    /// #1C1917, the ink over a light background.
    static let darkInk = Self(hex: 0x1C1917)
    static let white = Self(red: 1, green: 1, blue: 1)

    /// WCAG 2 relative luminance.
    var relativeLuminance: Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// WCAG 2 contrast ratio, 1...21.
    func contrast(with other: Self) -> Double {
        let (a, b) = (relativeLuminance, other.relativeLuminance)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    /// How far apart two colours look, 0 (the same) to 1 (black and white),
    /// with green weighed most and red and blue by how red the pair is.
    func distance(to other: Self) -> Double {
        let redMean = (red + other.red) / 2
        let dr = red - other.red, dg = green - other.green, db = blue - other.blue
        return ((2 + redMean) * dr * dr + 4 * dg * dg + (3 - redMean) * db * db).squareRoot() / 3
    }

    var hsb: (hue: Double, saturation: Double, brightness: Double) {
        let highest = max(red, green, blue), lowest = min(red, green, blue)
        let range = highest - lowest
        var hue = 0.0
        if range > 0 {
            if highest == red { hue = (green - blue) / range }
            else if highest == green { hue = 2 + (blue - red) / range }
            else { hue = 4 + (red - green) / range }
            hue /= 6
            if hue < 0 { hue += 1 }
        }
        return (hue, highest == 0 ? 0 : range / highest, highest)
    }

    init(hue: Double, saturation: Double, brightness: Double) {
        let h = (hue.isFinite ? hue - hue.rounded(.down) : 0) * 6
        let s = saturation.isFinite ? min(1, max(0, saturation)) : 0
        let v = brightness.isFinite ? min(1, max(0, brightness)) : 0
        let sector = Int(h) % 6
        let f = h - Double(Int(h))
        let p = v * (1 - s), q = v * (1 - s * f), t = v * (1 - s * (1 - f))
        switch sector {
        case 0: self.init(red: v, green: t, blue: p)
        case 1: self.init(red: q, green: v, blue: p)
        case 2: self.init(red: p, green: v, blue: t)
        case 3: self.init(red: p, green: q, blue: v)
        case 4: self.init(red: t, green: p, blue: v)
        default: self.init(red: v, green: p, blue: q)
        }
    }
}

/// The full layer's colours: one background from the cover and an ink that
/// always reads on it.
enum ZenithLockScreenPalette {
    struct Scheme: Equatable {
        /// The colour behind everything; over a blurred cover, its average
        /// once dimmed, which the ink and the record's edge are measured by.
        let background: ZenithLockScreenRGB
        let ink: ZenithLockScreenRGB
        /// How much black dims a blurred cover; 0 for a solid colour.
        var dim: Double = 0
        var inkIsDark: Bool { ink == .darkInk }
        static let neutral = Scheme(background: .neutral, ink: .white)
    }

    /// The muted tone softens a cover to at most this saturation and between
    /// these brightnesses, so the screen stays calm whatever the artwork.
    static let maximumSaturation = 0.42
    static let brightnessRange = 0.16...0.80
    /// Above this luminance the ink turns dark.
    static let darkInkLuminance = 0.4
    static let minimumContrast = 4.5

    static func softened(_ color: ZenithLockScreenRGB) -> ZenithLockScreenRGB {
        let hsb = color.hsb
        return ZenithLockScreenRGB(hue: hsb.hue, saturation: min(hsb.saturation, maximumSaturation),
                                   brightness: min(brightnessRange.upperBound, max(brightnessRange.lowerBound, hsb.brightness)))
    }

    static func ink(on background: ZenithLockScreenRGB) -> ZenithLockScreenRGB {
        background.relativeLuminance > darkInkLuminance ? .darkInk : .white
    }

    /// The background and ink for a cover's colour in the muted tone, or the
    /// neutral pair without one.
    static func scheme(cover: ZenithLockScreenRGB?) -> Scheme {
        guard let cover else { return .neutral }
        return scheme(cover: cover, tone: .muted)
    }

    /// The cover's colour as it is (vivid) or calmed (muted), then moved
    /// only as far as its ink needs to reach 4.5:1.
    static func scheme(cover: ZenithLockScreenRGB, tone: ZenithLockScreenFullTone) -> Scheme {
        solid(tone == .vivid ? cover : softened(cover))
    }

    /// A solid colour as it is, such as the one picked in Settings. A colour
    /// too close to its ink is nudged away from it, lighter under dark ink
    /// and darker under white, until the pair reaches 4.5:1.
    static func solid(_ color: ZenithLockScreenRGB) -> Scheme {
        var background = color
        let ink = ink(on: background)
        var hsb = background.hsb
        var steps = 0
        while background.contrast(with: ink) < minimumContrast, steps < 60 {
            hsb.brightness = min(1, max(0, hsb.brightness + (ink == .darkInk ? 0.02 : -0.02)))
            background = ZenithLockScreenRGB(hue: hsb.hue, saturation: hsb.saturation, brightness: hsb.brightness)
            steps += 1
        }
        return Scheme(background: background, ink: ink)
    }

    /// A blurred cover starts under this much black, which keeps it calm.
    static let baseDim = 0.28
    static let maximumDim = 0.86

    /// The ink over a blurred cover whose average colour is `average`,
    /// judged on that average once dimmed. Where white ink would not reach
    /// 4.5:1 the dim deepens rather than any colour changing.
    static func blurred(average: ZenithLockScreenRGB) -> Scheme {
        func dimmed(_ amount: Double) -> ZenithLockScreenRGB {
            ZenithLockScreenRGB(red: average.red * (1 - amount), green: average.green * (1 - amount),
                                blue: average.blue * (1 - amount))
        }
        var dim = baseDim
        let ink = ink(on: dimmed(dim))
        while dimmed(dim).contrast(with: ink) < minimumContrast, dim < maximumDim {
            dim = min(maximumDim, dim + 0.02)
        }
        return Scheme(background: dimmed(dim), ink: ink, dim: dim)
    }

    /// The mean colour of an RGBA8 bitmap's readable pixels, unpremultiplied.
    static func average(rgba pixels: [UInt8], count: Int) -> ZenithLockScreenRGB? {
        guard count > 0, pixels.count >= count * 4 else { return nil }
        var sum = (0.0, 0.0, 0.0), counted = 0.0
        for index in 0..<count {
            guard let pixel = pixel(pixels, index) else { continue }
            sum.0 += pixel.red
            sum.1 += pixel.green
            sum.2 += pixel.blue
            counted += 1
        }
        guard counted > 0 else { return nil }
        return ZenithLockScreenRGB(red: sum.0 / counted, green: sum.1 / counted, blue: sum.2 / counted)
    }

    /// One pixel of an RGBA8 bitmap (premultiplied or not) at its own colour;
    /// nil when it is mostly transparent.
    static func pixel(_ pixels: [UInt8], _ index: Int) -> ZenithLockScreenRGB? {
        let offset = index * 4
        guard offset >= 0, offset + 3 < pixels.count else { return nil }
        let alpha = Double(pixels[offset + 3]) / 255
        guard alpha >= 0.5 else { return nil }
        // Undo premultiplication; an opaque pixel is unchanged.
        return ZenithLockScreenRGB(red: min(1, Double(pixels[offset]) / 255 / alpha),
                                   green: min(1, Double(pixels[offset + 1]) / 255 / alpha),
                                   blue: min(1, Double(pixels[offset + 2]) / 255 / alpha))
    }

    /// The full layer's scheme for the background chosen. `cover` is the
    /// cover's colour (`coverColor`) and `blurredAverage` the blurred cover's
    /// mean, when there is a cover. With no cover, the picked colour stands in.
    static func scheme(for gates: ZenithLockScreenV2Gates, cover: ZenithLockScreenRGB?,
                       blurredAverage: ZenithLockScreenRGB?) -> Scheme {
        let picked = solid(ZenithLockScreenRGB(hex: gates.fullCustomColor))
        switch gates.fullBackground {
        case .blurredCover: return blurredAverage.map(blurred(average:)) ?? picked
        case .solid:
            guard gates.fullCoverColor, let cover else { return picked }
            return scheme(cover: cover, tone: gates.fullTone)
        }
    }

    // MARK: Cover colour

    /// A pixel counts towards the cover's colour only when it has colour of
    /// its own: saturated enough, and neither near black nor near white.
    static let colourfulSaturation = 0.28
    static let colourfulBrightness = 0.18
    static let colourfulChroma = 0.12
    static let hueBins = 36
    /// The commonest colour must cover at least this share of the cover, or
    /// the cover counts as having none (a grey photo with a small red logo).
    static let minimumShare = 0.06

    static func isColourful(_ color: ZenithLockScreenRGB) -> Bool {
        let hsb = color.hsb
        let chroma = max(color.red, color.green, color.blue) - min(color.red, color.green, color.blue)
        return hsb.saturation >= colourfulSaturation && hsb.brightness >= colourfulBrightness && chroma >= colourfulChroma
    }

    /// The cover's commonest saturated colour: its colourful pixels are
    /// counted by hue in 10° bins, each by its saturation; the 30° window with
    /// the most colour wins, and its pixels are averaged.
    /// Near white, near black and grey pixels never count, so a red cover with
    /// a white hand gives red, not the pink their average would. Nil when no
    /// hue covers `minimumShare` of the readable pixels.
    static func saturatedCluster(rgba pixels: [UInt8], count: Int) -> ZenithLockScreenRGB? {
        guard count > 0, pixels.count >= count * 4 else { return nil }
        var readable = 0
        var colourful: [(color: ZenithLockScreenRGB, bin: Int, weight: Double)] = []
        var histogram = [Double](repeating: 0, count: hueBins)
        for index in 0..<count {
            guard let pixel = pixel(pixels, index) else { continue }
            readable += 1
            guard isColourful(pixel) else { continue }
            let hsb = pixel.hsb
            let bin = min(hueBins - 1, Int(hsb.hue * Double(hueBins)))
            colourful.append((pixel, bin, hsb.saturation))
            histogram[bin] += hsb.saturation
        }
        guard readable > 0, !colourful.isEmpty else { return nil }
        func bin(_ value: Int) -> Int { (value % hueBins + hueBins) % hueBins }
        // Each bin with its two neighbours: the 30° of hue with the most colour.
        let scores = (0..<hueBins).map { histogram[bin($0 - 1)] + histogram[$0] + histogram[bin($0 + 1)] }
        guard let best = scores.indices.max(by: { scores[$0] < scores[$1] }) else { return nil }
        let window = Set([bin(best - 1), best, bin(best + 1)])
        let cluster = colourful.filter { window.contains($0.bin) }
        guard Double(cluster.count) / Double(readable) >= minimumShare else { return nil }
        let total = cluster.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return nil }
        return ZenithLockScreenRGB(red: cluster.reduce(0) { $0 + $1.color.red * $1.weight } / total,
                                   green: cluster.reduce(0) { $0 + $1.color.green * $1.weight } / total,
                                   blue: cluster.reduce(0) { $0 + $1.color.blue * $1.weight } / total)
    }

    /// The colour the full layer takes from a cover: its commonest saturated
    /// colour, or, for a cover with none (black and white, grey), its average.
    static func coverColor(rgba pixels: [UInt8], count: Int) -> ZenithLockScreenRGB? {
        saturatedCluster(rgba: pixels, count: count) ?? average(rgba: pixels, count: count)
    }
}

/// The record's edge: a thin ring in the ink, only where the cover's rim is
/// close to the background, so the record does not dissolve into it.
enum ZenithLockScreenRecordEdge {
    /// Closer than this (`ZenithLockScreenRGB.distance`) reads as the same colour.
    static let threshold = 0.16
    static let arcs = 8

    static func needsRing(edge samples: [ZenithLockScreenRGB], background: ZenithLockScreenRGB) -> Bool {
        samples.contains { $0.distance(to: background) < threshold }
    }

    /// The rim of the circle inscribed in a square RGBA8 bitmap `side` wide
    /// (the outer tenth of its radius), averaged in `arcs` arcs. An arc with
    /// no readable pixel is left out.
    static func samples(rgba pixels: [UInt8], side: Int) -> [ZenithLockScreenRGB] {
        guard side > 1, pixels.count >= side * side * 4 else { return [] }
        let centre = Double(side) / 2, radius = Double(side) / 2
        var sums = [(Double, Double, Double, Double)](repeating: (0, 0, 0, 0), count: arcs)
        for y in 0..<side {
            for x in 0..<side {
                let dx = Double(x) + 0.5 - centre, dy = Double(y) + 0.5 - centre
                let distance = (dx * dx + dy * dy).squareRoot()
                guard distance <= radius, distance >= radius * 0.8,
                      let pixel = ZenithLockScreenPalette.pixel(pixels, y * side + x) else { continue }
                var angle = atan2(dy, dx) / (2 * Double.pi)
                if angle < 0 { angle += 1 }
                let arc = min(arcs - 1, Int(angle * Double(arcs)))
                sums[arc].0 += pixel.red
                sums[arc].1 += pixel.green
                sums[arc].2 += pixel.blue
                sums[arc].3 += 1
            }
        }
        return sums.compactMap { sum in
            sum.3 > 0 ? ZenithLockScreenRGB(red: sum.0 / sum.3, green: sum.1 / sum.3, blue: sum.2 / sum.3) : nil
        }
    }
}

/// The blurred cover behind the full layer is blurred once per song, on a
/// small copy that is then scaled up to fill the screen.
enum ZenithLockScreenBackdrop {
    /// The small copy's side, in pixels.
    static let side = 160
    /// A blur of `points` on screen, in pixels of an `image` sized copy
    /// filling `screen` (aspect fill).
    static func imageRadius(points: Double, image: CGSize, screen: CGSize) -> Double {
        guard points.isFinite, points > 0, image.width > 0, image.height > 0,
              screen.width > 0, screen.height > 0 else { return 0 }
        let fill = max(screen.width / image.width, screen.height / image.height)
        return points / Double(fill)
    }
}

// MARK: - Lyrics

/// Where the lyrics are in the song: the player's position, moved by the
/// island's own adjustment and the lock screen's lyric timing together.
/// Positive offsets show each line later.
enum ZenithLockScreenLyricTiming {
    static func offset(island: Double, lockScreen: Double) -> Double {
        (island.isFinite ? island : 0) + (lockScreen.isFinite ? lockScreen : 0)
    }
}

/// lrclib.net times lines, not words, so the sung part of a line is worked
/// out from the time spent in it, one word after another, each word taking
/// time for its letters. A word lights up whole; the one being sung fades in
/// from its first letter with a soft edge, and no word is ever left split.
enum ZenithLockScreenKaraoke {
    /// About a sung syllable's pace. A line held over a long instrumental gap
    /// finishes at this pace rather than crawling until the next line.
    static let secondsPerCharacter = 0.085
    static let minimumSpan = 1.2
    /// The singing ends a little before the next line starts.
    static let gapShare = 0.92
    /// How far the fade's soft edge reaches back through a word.
    static let softness = 0.8

    /// How long the singing of a line of `characters` takes.
    static func span(start: Double, next: Double?, characters: Int) -> Double {
        let paced = max(minimumSpan, Double(max(0, characters)) * secondsPerCharacter)
        guard let next, next.isFinite else { return paced }
        return min(max(0, next - start) * gapShare, paced)
    }

    /// How far through its line the singing is, 0...1.
    static func progress(start: Double, next: Double?, characters: Int, position: Double) -> Double {
        guard start.isFinite, position.isFinite, characters > 0 else { return 0 }
        let span = span(start: start, next: next, characters: characters)
        guard span > 0 else { return position >= start ? 1 : 0 }
        return min(1, max(0, (position - start) / span))
    }

    /// The words of a line, as ranges of character offsets: runs between
    /// spaces, and every CJK character its own word, as those lines have none.
    static func words(_ text: String) -> [Range<Int>] {
        var words: [Range<Int>] = []
        var start: Int?
        for (offset, character) in text.enumerated() {
            if character.isWhitespace {
                if let begun = start { words.append(begun..<offset) }
                start = nil
            } else if isLogographic(character) {
                if let begun = start { words.append(begun..<offset) }
                words.append(offset..<(offset + 1))
                start = nil
            } else if start == nil {
                start = offset
            }
        }
        if let begun = start { words.append(begun..<text.count) }
        return words
    }

    private static func isLogographic(_ character: Character) -> Bool {
        character.unicodeScalars.contains { scalar in
            scalar.properties.isIdeographic
                || (0x3040...0x30FF).contains(scalar.value) // Hiragana, Katakana
                || (0xAC00...0xD7AF).contains(scalar.value) // Hangul syllables
        }
    }

    /// How lit each character is, 0...1, at `progress` through the line:
    /// words before the one being sung are whole, words after it unlit, and
    /// the one being sung fades in from its first letter.
    static func levels(_ text: String, progress: Double) -> [Double] {
        let count = text.count
        guard count > 0 else { return [] }
        let words = words(text)
        guard !words.isEmpty else { return Array(repeating: progress >= 1 ? 1 : 0, count: count) }
        let p = progress.isFinite ? min(1, max(0, progress)) : 0
        // Each word takes its letters' time and a beat for the gap after it.
        let weights = words.map { Double($0.count) + 1 }
        let total = weights.reduce(0, +)
        var levels = [Double](repeating: 0, count: count)
        var start = 0.0
        for (word, weight) in zip(words, weights) {
            let length = Double(word.count)
            let lit = min(1, max(0, (p * total - start) / length))
            for (index, offset) in word.enumerated() {
                let position = Double(index) / length
                levels[offset] = min(1, max(0, lit * (1 + softness) - softness * position))
            }
            // A space takes the word before it: lit once that word is.
            if word.upperBound < count, lit >= 1 {
                var gap = word.upperBound
                while gap < count, text[text.index(text.startIndex, offsetBy: gap)].isWhitespace {
                    levels[gap] = 1
                    gap += 1
                }
            }
            start += weight
        }
        return levels
    }
}

/// Which lyric lines show around the one being sung.
struct ZenithLockScreenLyricWindow: Equatable {
    var previous: Int?
    var active: Int?
    var upcoming: [Int]

    /// Before the first line nothing is active and the first lines wait below.
    static func make(lineCount: Int, active: Int?, upcoming count: Int) -> Self {
        guard lineCount > 0 else { return Self(previous: nil, active: nil, upcoming: []) }
        guard let active, active >= 0, active < lineCount else {
            return Self(previous: nil, active: nil, upcoming: Array(0..<min(lineCount, max(0, count))))
        }
        let last = min(lineCount, active + 1 + max(0, count))
        return Self(previous: active > 0 ? active - 1 : nil, active: active, upcoming: Array((active + 1)..<last))
    }
}

/// How the full layer's lyric lines fade: the line before, the line being
/// sung, then three after it, fainter and softer the further they are. Dark
/// ink reads weaker than white at the same opacity, so it is raised a little.
enum ZenithLockScreenFullLyrics {
    static let upcoming = 3
    static let previousOpacity = 0.35
    static let upcomingOpacities = [0.45, 0.28, 0.14]
    static let previousBlur: CGFloat = 0.75
    static let upcomingBlurs: [CGFloat] = [0.5, 1.5, 3]
    /// The part of the sung line still to come.
    static let restOpacity = 0.45
    static let darkInkBoost = 1.3

    static func opacity(_ base: Double, darkInk: Bool) -> Double {
        darkInk ? min(1, base * darkInkBoost) : base
    }

    static func upcomingOpacity(_ distance: Int, darkInk: Bool) -> Double {
        opacity(upcomingOpacities[min(max(0, distance), upcomingOpacities.count - 1)], darkInk: darkInk)
    }

    static func upcomingBlur(_ distance: Int) -> CGFloat {
        upcomingBlurs[min(max(0, distance), upcomingBlurs.count - 1)]
    }
}

/// Where the full layer's lyric lines go: one under another, `spacing`
/// apart, moved so the line being sung has its middle on `middle`, however
/// many lines it wraps to. Before the singing starts, the first line waiting
/// takes that place.
enum ZenithLockScreenLyricPlacement {
    static func tops(heights: [CGFloat], spacing: CGFloat, active: Int?, middle: CGFloat) -> [CGFloat] {
        guard !heights.isEmpty else { return [] }
        var tops: [CGFloat] = []
        var y: CGFloat = 0
        for height in heights {
            tops.append(y)
            y += max(0, height) + spacing
        }
        let anchor = active.flatMap { heights.indices.contains($0) ? $0 : nil } ?? 0
        let shift = middle - (tops[anchor] + max(0, heights[anchor]) / 2)
        return tops.map { ($0 + shift).rounded() }
    }
}

// MARK: - Jobs

/// The jobs in the activity row: the first left of the other activities, the
/// second right of them, the rest counted as "+N".
enum ZenithLockScreenJobLine {
    struct Arrangement: Equatable {
        var leading: ZenithLockScreenJob?
        var trailing: ZenithLockScreenJob?
        var overflow = 0
        var isEmpty: Bool { leading == nil && trailing == nil }
        var shown: [ZenithLockScreenJob] { [leading, trailing].compactMap { $0 } }
    }

    static func arrange(_ items: [ZenithLockScreenJob], limit: Int = ZenithLockScreenJobs.visibleLimit) -> Arrangement {
        let limit = max(0, min(2, limit))
        let shown = Array(items.prefix(limit))
        return Arrangement(leading: shown.first, trailing: shown.count > 1 ? shown[1] : nil,
                           overflow: max(0, items.count - shown.count))
    }

    /// A whole percentage, rounded down so a running job never reads 100%.
    static func percent(_ fraction: Double?) -> Int? {
        guard let fraction, fraction.isFinite else { return nil }
        return Int((min(1, max(0, fraction)) * 100).rounded(.down))
    }

    /// The ring's colour; nil draws it in the ink (white over the wallpaper).
    static func ringHex(_ source: ZenithLockScreenJobSource) -> UInt32? {
        switch source {
        case .export: return 0xC4B5FD
        case .cardImport, .backup: return 0xFDBA74
        case .command: return 0x86EFAC
        case .vercel: return nil
        }
    }

    /// Jobs for the Settings preview, as the job feed would publish them.
    static let sampleJobs = [
        ZenithLockScreenJob(id: "export", source: .export, label: "DaVinci", fraction: 0.62, finished: false),
        ZenithLockScreenJob(id: "import", source: .cardImport, label: "Import", fraction: 0.85, finished: false),
        ZenithLockScreenJob(id: "deploy", source: .vercel, label: "zenith", fraction: 1, finished: true),
        ZenithLockScreenJob(id: "build", source: .command, label: "npm", fraction: 0.2, finished: false),
    ]
}

/// What can sit at the full layer's top right, beside the close button.
enum ZenithLockScreenTopItem: String, CaseIterable, Identifiable {
    case jobs, prayer, weather, timer, calendar, wakatime
    var id: String { rawValue }
}

enum ZenithLockScreenTopRight {
    /// The items to show, from the close button outward: the jobs nearest,
    /// then the next prayer, the weather, the timer, the calendar and
    /// WakaTime, each only when its switch is on and it has something to show.
    static func items(_ gates: ZenithLockScreenV2Gates, showing available: Set<ZenithLockScreenTopItem>) -> [ZenithLockScreenTopItem] {
        ZenithLockScreenTopItem.allCases.filter { item in
            guard available.contains(item) else { return false }
            switch item {
            case .jobs: return gates.fullJobs
            case .prayer: return gates.fullTopPrayer
            case .weather: return gates.fullTopWeather
            case .timer: return gates.fullTopTimer
            case .calendar: return gates.fullTopCalendar
            case .wakatime: return gates.fullTopWakaTime
            }
        }
    }
}

// MARK: - Small rules

/// "Click for full lyrics" shows on hovering the lyric during the first
/// three lock screens that show it, and never after.
enum ZenithLockScreenHint {
    static let limit = 3
    static func shows(count: Int) -> Bool { count < limit }
}

/// The full layer closes with its close button, Esc when key events reach
/// the app, the music staying stopped, or the Mac unlocking. The pointer
/// moving never closes it: clicking a line would otherwise close it at once.
enum ZenithLockScreenFullExit {
    /// Music that stays paused or stopped this long closes the full layer;
    /// a player moving on to its next song pauses for less.
    static let pauseGrace: TimeInterval = 1.2
    static let escapeKeyCode: UInt16 = 53

    static func closes(keyCode: UInt16) -> Bool { keyCode == escapeKeyCode }
}

/// The record turns once every eight seconds while the song plays, and
/// coasts to a stop when it pauses.
enum ZenithLockScreenDiscSpin {
    static let degreesPerSecond = 360.0 / 8
    static let stopDuration = 1.2

    static func angle(from base: Double, startedAt start: Date, at date: Date) -> Double {
        let elapsed = max(0, date.timeIntervalSince(start))
        return (base + elapsed * degreesPerSecond).truncatingRemainder(dividingBy: 360)
    }

    /// How far an ease-out stop over `stopDuration` carries the record from
    /// full speed: half the distance full speed would cover.
    static var coast: Double { degreesPerSecond * stopDuration / 2 }
}

/// The account picture's stand-in: the first letter of the first and last
/// words of the name.
enum ZenithLockScreenInitials {
    static func of(_ name: String) -> String {
        let words = name.split(whereSeparator: { $0.isWhitespace || $0 == "." })
        guard let first = words.first?.first else { return "" }
        guard words.count > 1, let last = words.last?.first else { return String(first).uppercased() }
        return (String(first) + String(last)).uppercased()
    }
}

// MARK: - Layout

/// The minimal layer under the activity row: the title line one row gap
/// under the row, the lyric right under the title, as one block.
enum ZenithLockScreenMinimalLayout {
    /// The title's tap target pads its text this much above and below.
    static let titlePadding: CGFloat = 4
    /// From the row's frame to the title's text, the clock's gap to the row's
    /// text: the row gap and the room the row's text leaves in its frame.
    static var titleGap: CGFloat { NotchLockScreenLayout.rowGap + 6 - titlePadding }
    /// From the title's text to the sung line's.
    static let lyricGap: CGFloat = 3
    static let lineSpacing: CGFloat = 2
    static let lyricWidth: CGFloat = 640
    /// The title controls' glass card, as wide as the old player's pane.
    static let cardWidth: CGFloat = 404
    /// The shade reaches this far past the title and lyric on each side.
    static let shadeReach = CGSize(width: 110, height: 44)

    /// The panel over the player's room and up over the activity row, so the
    /// lyric's shade can fade out behind the row; as wide as the row, so a
    /// long lyric line has the room the row has. Clear pixels pass clicks through.
    static func frame(row: CGRect, player: CGRect) -> CGRect {
        CGRect(x: row.minX, y: player.minY, width: row.width, height: max(player.height, row.maxY - player.minY))
    }

    /// The title line's top, from the panel's top.
    static func titleTop(row: CGRect, panel: CGRect) -> CGFloat {
        max(0, panel.maxY - (row.minY - titleGap))
    }

    /// `.low` lifts the terminal readout's bottom 10 points over the login line.
    static func terminalLift(_ placement: ZenithLockScreenTerminalPlacement) -> CGFloat {
        placement == .low ? 10 : 0
    }

    /// The readout's frame has room for every line that may show. Low, the
    /// card sits on the frame's bottom, so its bottom stays 10 points over the
    /// login line however few lines have something to say; normal, it hangs
    /// from the frame's top as it always has.
    static func terminalAnchorsBottom(_ placement: ZenithLockScreenTerminalPlacement) -> Bool { placement == .low }

    /// The card's frame inside the readout's `frame` (AppKit coordinates).
    static func terminalCard(in frame: CGRect, cardHeight: CGFloat, placement: ZenithLockScreenTerminalPlacement) -> CGRect {
        let height = min(frame.height, max(0, cardHeight))
        let y = terminalAnchorsBottom(placement) ? frame.minY : frame.maxY - height
        return CGRect(x: frame.minX, y: y, width: frame.width, height: height)
    }
}

/// The full layer, measured on an 1800 × 1169 point display and scaled to
/// others by the shorter of their two ratios. The record with its column and
/// the lyrics are one group, centred across the screen and between the top
/// and bottom rows; the record and the sung line share a middle.
struct ZenithLockScreenFullLayout: Equatable {
    static let reference = CGSize(width: 1800, height: 1169)
    let size: CGSize
    let scale: CGFloat

    init(size: CGSize) {
        self.size = size
        let ratio = min(size.width / Self.reference.width, size.height / Self.reference.height)
        scale = ratio.isFinite && ratio > 0 ? min(1.6, max(0.55, ratio)) : 1
    }

    private func s(_ value: CGFloat) -> CGFloat { (value * scale).rounded() }

    // Corners.
    var margin: CGFloat { s(110) }
    var clockTop: CGFloat { s(85) }
    var dateSize: CGFloat { s(17) }
    var timeSize: CGFloat { s(60) }
    /// Where the top row's middle sits: the close button and its items.
    var topRowMiddle: CGFloat { s(128) }
    /// Under the clock.
    var topRowBottom: CGFloat { clockTop + s(22) + s(72) }
    var closeSize: CGFloat { s(42) }
    var topItemSize: CGFloat { max(11, s(15)) }
    var topItemGap: CGFloat { s(30) }
    var identityBottom: CGFloat { s(75) }
    var photoSize: CGFloat { s(48) }
    var nameSize: CGFloat { s(17) }
    var deviceSize: CGFloat { s(13) }
    var hintSize: CGFloat { s(15) }
    /// Over the account's picture and its ring.
    var bottomRowTop: CGFloat { size.height - identityBottom - photoSize - s(6) }

    // The group.
    var discSize: CGFloat { s(320) }
    var groupGap: CGFloat { s(90) }
    var lyricsWidth: CGFloat { s(690) }
    var groupWidth: CGFloat { discSize + groupGap + lyricsWidth }
    var groupLeft: CGFloat { max(margin, ((size.width - groupWidth) / 2).rounded()) }
    var lyricsLeft: CGFloat { groupLeft + discSize + groupGap }

    // The record's column.
    var titleGap: CGFloat { s(30) }
    var titleSize: CGFloat { s(27) }
    var titleLine: CGFloat { s(33) }
    var artistSize: CGFloat { s(21) }
    var artistGap: CGFloat { s(4) }
    var artistLine: CGFloat { s(26) }
    var progressGap: CGFloat { s(22) }
    var barHeight: CGFloat { max(3, s(4)) }
    var timesGap: CGFloat { s(8) }
    var timesSize: CGFloat { max(10, s(12)) }
    var timesLine: CGFloat { s(15) }
    var controlsGap: CGFloat { s(12) }
    var controlsHeight: CGFloat { s(50) }
    var sideControlSize: CGFloat { s(23) }
    var mainControlSize: CGFloat { s(30) }
    var hubSize: CGFloat { s(26) }

    /// The record, the title and artist, the progress and the buttons.
    var columnHeight: CGFloat {
        discSize + titleGap + titleLine + artistGap + artistLine + progressGap + barHeight + timesGap + timesLine
            + controlsGap + controlsHeight
    }
    /// Centred between the clock and the account.
    var columnTop: CGFloat { max(topRowBottom, ((topRowBottom + bottomRowTop) / 2 - columnHeight / 2).rounded()) }
    /// The record's middle, which the sung line's middle shares.
    var discMiddle: CGFloat { columnTop + discSize / 2 }

    // The lyrics.
    var activeSize: CGFloat { s(54) }
    var lineSize: CGFloat { s(40) }
    var lineGap: CGFloat { s(22) }
    /// The lyrics fade out above this, clear of the clock.
    var lyricsTop: CGFloat { topRowBottom + s(24) }
    /// And below this, clear of the account and the login hint.
    var lyricsBottom: CGFloat { bottomRowTop - s(30) }
    var lyricsFade: CGFloat { s(60) }
}
