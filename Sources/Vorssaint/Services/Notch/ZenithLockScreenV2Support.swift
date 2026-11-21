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
    var full = false
    var fullDisc = false
    var fullAccount = false
    var fullDevice = false
    var fullClock = false
    var fullJobs = false
    var fullCoverColor = false
    var fullLoginHint = false

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
        gates.full = gates.lyrics && on(.full)
        gates.fullDisc = gates.full && on(.fullDisc)
        gates.fullAccount = gates.full && on(.fullAccount)
        gates.fullDevice = gates.full && on(.fullDevice)
        gates.fullClock = gates.full && on(.fullClock)
        gates.fullJobs = gates.full && on(.fullJobs)
        gates.fullCoverColor = gates.full && on(.fullCoverColor)
        gates.fullLoginHint = gates.full && on(.fullLoginHint)
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

/// The full layer's colours: one calm background from the cover and an ink
/// that always reads on it.
enum ZenithLockScreenPalette {
    struct Scheme: Equatable {
        let background: ZenithLockScreenRGB
        let ink: ZenithLockScreenRGB
        var inkIsDark: Bool { ink == .darkInk }
        static let neutral = Scheme(background: .neutral, ink: .white)
    }

    /// Covers are softened to at most this saturation and between these
    /// brightnesses, so the screen stays calm whatever the artwork.
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

    /// The background and ink for a cover's dominant colour, or the neutral
    /// pair without one. A background too close to its ink is nudged away
    /// from it, lighter under dark ink and darker under white, until the pair
    /// reaches 4.5:1.
    static func scheme(cover: ZenithLockScreenRGB?) -> Scheme {
        guard let cover else { return .neutral }
        var background = softened(cover)
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

    /// The most common colour of an RGBA8 bitmap (premultiplied or not),
    /// counted in coarse bins, colourful pixels counting a little more.
    /// Mostly transparent pixels are skipped; nothing readable gives nil.
    static func dominant(rgba pixels: [UInt8], count: Int) -> ZenithLockScreenRGB? {
        guard count > 0, pixels.count >= count * 4 else { return nil }
        var weights = [Double](repeating: 0, count: 512)
        var sums = [(Double, Double, Double)](repeating: (0, 0, 0), count: 512)
        for index in 0..<count {
            let offset = index * 4
            let alpha = Double(pixels[offset + 3]) / 255
            guard alpha >= 0.5 else { continue }
            // Undo premultiplication; an opaque pixel is unchanged.
            let red = min(1, Double(pixels[offset]) / 255 / alpha)
            let green = min(1, Double(pixels[offset + 1]) / 255 / alpha)
            let blue = min(1, Double(pixels[offset + 2]) / 255 / alpha)
            let bin = min(7, Int(red * 8)) << 6 | min(7, Int(green * 8)) << 3 | min(7, Int(blue * 8))
            let weight = 1 + ZenithLockScreenRGB(red: red, green: green, blue: blue).hsb.saturation
            weights[bin] += weight
            sums[bin].0 += red * weight
            sums[bin].1 += green * weight
            sums[bin].2 += blue * weight
        }
        guard let best = weights.indices.max(by: { weights[$0] < weights[$1] }), weights[best] > 0 else { return nil }
        let weight = weights[best]
        return ZenithLockScreenRGB(red: sums[best].0 / weight, green: sums[best].1 / weight, blue: sums[best].2 / weight)
    }
}

// MARK: - Lyrics

/// lrclib.net times lines, not words, so the sung part of a line is worked
/// out from the time spent in it, one character after another.
enum ZenithLockScreenKaraoke {
    /// A line held over a long instrumental gap finishes at a singing pace
    /// rather than crawling until the next line.
    static let secondsPerCharacter = 0.18
    static let minimumSpan = 1.5

    /// How long the singing of a line of `characters` takes.
    static func span(start: Double, next: Double?, characters: Int) -> Double {
        let paced = max(minimumSpan, Double(max(0, characters)) * secondsPerCharacter)
        guard let next, next.isFinite else { return paced }
        return min(max(0, next - start), paced)
    }

    /// How far through its line the singing is, 0...1.
    static func progress(start: Double, next: Double?, characters: Int, position: Double) -> Double {
        guard start.isFinite, position.isFinite, characters > 0 else { return 0 }
        let span = span(start: start, next: next, characters: characters)
        guard span > 0 else { return position >= start ? 1 : 0 }
        return min(1, max(0, (position - start) / span))
    }

    /// The characters sung through, and how far into the next one.
    static func sung(characters: Int, progress: Double) -> (whole: Int, partial: Double) {
        guard characters > 0, progress.isFinite else { return (0, 0) }
        let exact = min(1, max(0, progress)) * Double(characters)
        let whole = min(characters, Int(exact))
        return (whole, whole >= characters ? 0 : exact - Double(whole))
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
}

// MARK: - Small rules

/// "Click for full lyrics" shows on hovering the lyric during the first
/// three lock screens that show it, and never after.
enum ZenithLockScreenHint {
    static let limit = 3
    static func shows(count: Int) -> Bool { count < limit }
}

/// The full layer leaves for the login controls once the pointer moves.
enum ZenithLockScreenFullExit {
    static let pointerTravel: CGFloat = 8
    static let pollInterval: TimeInterval = 0.25
    /// Music that stays paused or stopped this long closes the full layer;
    /// a player moving on to its next song pauses for less.
    static let pauseGrace: TimeInterval = 1.2

    static func moved(from origin: CGPoint, to point: CGPoint) -> Bool {
        guard [origin.x, origin.y, point.x, point.y].allSatisfy(\.isFinite) else { return false }
        return hypot(point.x - origin.x, point.y - origin.y) > pointerTravel
    }
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

/// The minimal layer under the activity row: the now-playing line 38 points
/// under the row's frame, the lyric under it, as wide as the row.
enum ZenithLockScreenMinimalLayout {
    static let titleGap: CGFloat = 38
    static let lyricGap: CGFloat = 33
    static let lyricWidth: CGFloat = 640
    /// The title controls' glass card, as wide as the old player's pane.
    static let cardWidth: CGFloat = 404

    /// The panel over the player's room, widened to the row so a long lyric
    /// line has the room the row has. Clear pixels pass clicks through.
    static func frame(row: CGRect, player: CGRect) -> CGRect {
        CGRect(x: row.minX, y: player.minY, width: row.width, height: player.height)
    }

    /// The title line's top, from the panel's top.
    static func titleTop(row: CGRect, panel: CGRect) -> CGFloat {
        max(0, panel.maxY - (row.minY - titleGap))
    }

    /// `.low` lifts the terminal readout's bottom 10 points over the login line.
    static func terminalLift(_ placement: ZenithLockScreenTerminalPlacement) -> CGFloat {
        placement == .low ? 10 : 0
    }
}

/// The full layer, measured on an 1800 × 1169 point display and scaled to
/// others by the shorter of their two ratios.
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

    var margin: CGFloat { s(110) }
    var clockTop: CGFloat { s(85) }
    var dateSize: CGFloat { s(17) }
    var timeSize: CGFloat { s(60) }
    /// Where the time's middle sits, which the jobs line up with.
    var timeMiddle: CGFloat { clockTop + s(22) + s(36) }

    var columnLeft: CGFloat { s(210) }
    var columnTop: CGFloat { s(300) }
    var discSize: CGFloat { s(350) }
    var titleSize: CGFloat { s(27) }
    var artistSize: CGFloat { s(21) }
    var barHeight: CGFloat { max(3, s(4)) }
    var timesSize: CGFloat { max(10, s(12)) }
    var sideControlSize: CGFloat { s(23) }
    var mainControlSize: CGFloat { s(30) }

    var lyricsLeft: CGFloat { s(710) }
    var lyricsWidth: CGFloat { max(200, size.width - lyricsLeft - margin) }
    /// The sung line's top: about level with the record's middle.
    var activeTop: CGFloat { (size.height * 0.4).rounded() }
    var activeSize: CGFloat { s(64) }
    var lineSize: CGFloat { s(48) }
    var lineGap: CGFloat { s(20) }
    static let previousOpacity = 0.30
    static let previousBlur: CGFloat = 1.25
    static let upcomingOpacities = [0.42, 0.30, 0.20, 0.12, 0.06]
    static let upcomingBlurs: [CGFloat] = [1.25, 2.5, 3.75, 5.25, 7]

    var identityBottom: CGFloat { s(75) }
    var photoSize: CGFloat { s(48) }
    var nameSize: CGFloat { s(17) }
    var deviceSize: CGFloat { s(13) }
    var hintSize: CGFloat { s(15) }
}
