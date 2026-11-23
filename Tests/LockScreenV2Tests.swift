// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation

/// Zenith fork: the lock screen v2's pure parts: its switches, the full
/// layer's colours, the cover's colour and the record's edge, karaoke by
/// word, lyric timing, the lyric window, the jobs, the top right and the
/// layout. Nothing here draws a window or reads the account.
enum LockScreenV2Tests {
    static func run(_ suite: TestSuite) {
        gates(suite)
        luminance(suite)
        scheme(suite)
        backgrounds(suite)
        coverColour(suite)
        edgeRing(suite)
        karaoke(suite)
        words(suite)
        timing(suite)
        lyricWindow(suite)
        jobs(suite)
        topRight(suite)
        smallRules(suite)
        minimalLayout(suite)
        terminalCard(suite)
        fullLayout(suite)
        lyricPlacement(suite)
    }

    /// Fake jobs, as the job feed would publish them, for these tests.
    static let sampleJobs = [
        ZenithLockScreenJob(id: "export", source: .export, label: "DaVinci", fraction: 0.62, finished: false),
        ZenithLockScreenJob(id: "backup", source: .backup, label: "Backup", fraction: nil, finished: false),
        ZenithLockScreenJob(id: "deploy", source: .vercel, label: "zenith", fraction: 1, finished: true),
        ZenithLockScreenJob(id: "build", source: .command, label: "npm", fraction: 0.2, finished: false),
    ]

    private static func gates(_ suite: TestSuite) {
        let name = "com.vorssaint.tests.lockscreen-v2"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defer { defaults.removePersistentDomain(forName: name) }

        let all = ZenithLockScreenV2Gates.resolve(music: true, lyricsAvailable: true, in: defaults)
        suite.expect(all.jobs && all.nowPlaying && all.lyrics && all.karaoke && all.titleControls && all.full
                     && all.fullDisc && all.fullAccount && all.fullDevice && all.fullClock && all.fullJobs
                     && all.fullCoverColor && all.fullLoginHint && all.minimalTakesClicks,
                     "every part starts on")
        let silent = ZenithLockScreenV2Gates.resolve(music: false, lyricsAvailable: true, in: defaults)
        suite.expect(silent.jobs && !silent.nowPlaying && !silent.lyrics && !silent.titleControls && !silent.full
                     && !silent.fullClock && !silent.minimalTakesClicks,
                     "without the lock screen's music only the jobs remain")
        let noLyrics = ZenithLockScreenV2Gates.resolve(music: true, lyricsAvailable: false, in: defaults)
        suite.expect(noLyrics.nowPlaying && noLyrics.titleControls && !noLyrics.lyrics && !noLyrics.karaoke
                     && !noLyrics.full && !noLyrics.fullDisc,
                     "with the island's lyrics off there is no lyric and no full layer")

        defaults.set(false, forKey: ZenithLockScreenOption.nowPlaying.defaultsKey)
        let noLine = ZenithLockScreenV2Gates.resolve(music: true, lyricsAvailable: true, in: defaults)
        suite.expect(!noLine.nowPlaying && !noLine.lyrics && !noLine.titleControls && !noLine.full,
                     "the old player keeps the screen when the now-playing line is off")
        defaults.removeObject(forKey: ZenithLockScreenOption.nowPlaying.defaultsKey)

        defaults.set(false, forKey: ZenithLockScreenOption.full.defaultsKey)
        let noFull = ZenithLockScreenV2Gates.resolve(music: true, lyricsAvailable: true, in: defaults)
        suite.expect(noFull.lyrics && !noFull.full && !noFull.fullClock && !noFull.fullAccount && !noFull.fullLoginHint,
                     "the full layer's corners go with it")
        defaults.set(false, forKey: ZenithLockScreenOption.titleControls.defaultsKey)
        suite.expect(!ZenithLockScreenV2Gates.resolve(music: true, lyricsAvailable: true, in: defaults).minimalTakesClicks,
                     "with neither title controls nor the full layer the minimal layer takes no clicks")
        defaults.removePersistentDomain(forName: name)

        for option in [ZenithLockScreenOption.fullDisc, .fullAccount, .fullDevice, .fullClock, .fullJobs,
                       .fullCoverColor, .fullLoginHint, .karaoke] {
            defaults.set(false, forKey: option.defaultsKey)
        }
        let bare = ZenithLockScreenV2Gates.resolve(music: true, lyricsAvailable: true, in: defaults)
        suite.expect(bare.full && bare.lyrics && !bare.karaoke && !bare.fullDisc && !bare.fullAccount && !bare.fullDevice
                     && !bare.fullClock && !bare.fullJobs && !bare.fullCoverColor && !bare.fullLoginHint,
                     "each part of the full layer has its own switch")
        defaults.removePersistentDomain(forName: name)

        let fresh = ZenithLockScreenV2Gates.resolve(music: true, lyricsAvailable: true, in: defaults)
        suite.expect(fresh.lyricShade && !fresh.fullDiscSpin && fresh.fullTopPrayer && fresh.fullTopWeather
                     && !fresh.fullTopTimer && !fresh.fullTopCalendar && !fresh.fullTopWakaTime
                     && fresh.fullTone == .vivid && fresh.lyricOffset == 0,
                     "the shade, prayer and weather start on; the spin, timer, calendar and WakaTime off; vivid, no offset")
        defaults.set(true, forKey: ZenithLockScreenOption.fullDiscSpin.defaultsKey)
        defaults.set(false, forKey: ZenithLockScreenOption.fullDisc.defaultsKey)
        defaults.set("muted", forKey: DefaultsKey.zenithLockFullTone)
        defaults.set(0.43, forKey: DefaultsKey.zenithLockLyricOffset)
        let spun = ZenithLockScreenV2Gates.resolve(music: true, lyricsAvailable: true, in: defaults)
        suite.expect(!spun.fullDiscSpin && spun.fullTone == .muted && abs(spun.lyricOffset - 0.4) < 1e-9,
                     "the spin needs the record; the tone and the offset (in tenths) are read at lock")
        defaults.set(9.0, forKey: DefaultsKey.zenithLockLyricOffset)
        suite.expect(abs(ZenithLockScreenV2Gates.resolve(music: true, lyricsAvailable: true, in: defaults).lyricOffset - 3) < 1e-9
                     && ZenithLockScreenV2Gates.resolve(music: true, lyricsAvailable: false, in: defaults).lyricOffset == 0,
                     "the offset stays within 3 seconds and only matters with the lyric")
        let silentShade = ZenithLockScreenV2Gates.resolve(music: false, lyricsAvailable: true, in: defaults)
        suite.expect(!silentShade.lyricShade && !silentShade.fullTopPrayer, "no song, no shade and no top row")
    }

    private static func luminance(_ suite: TestSuite) {
        suite.expectClose(ZenithLockScreenRGB.white.relativeLuminance, 1, "white's luminance")
        suite.expectClose(ZenithLockScreenRGB(hex: 0x000000).relativeLuminance, 0, "black's luminance")
        suite.expectClose(ZenithLockScreenRGB.white.contrast(with: ZenithLockScreenRGB(hex: 0x000000)), 21, "black on white")
        suite.expectClose(ZenithLockScreenRGB(hex: 0x777777).contrast(with: .white), 4.48, "#777 on white", tol: 0.01)
        suite.expect(ZenithLockScreenRGB(hex: 0xC4B5FD) == ZenithLockScreenRGB(red: 196 / 255, green: 181 / 255, blue: 253 / 255),
                     "hex reads as sRGB channels")
        let teal = ZenithLockScreenRGB(red: 0.2, green: 0.6, blue: 0.5)
        let hsb = teal.hsb
        let back = ZenithLockScreenRGB(hue: hsb.hue, saturation: hsb.saturation, brightness: hsb.brightness)
        suite.expect(abs(back.red - teal.red) < 1e-9 && abs(back.green - teal.green) < 1e-9 && abs(back.blue - teal.blue) < 1e-9,
                     "hue, saturation and brightness round-trip")
        suite.expect(ZenithLockScreenRGB(red: .nan, green: 2, blue: -1) == ZenithLockScreenRGB(red: 0, green: 1, blue: 0),
                     "broken channels are clamped")
    }

    private static func scheme(_ suite: TestSuite) {
        suite.expect(ZenithLockScreenPalette.scheme(cover: nil) == .neutral
                     && ZenithLockScreenPalette.Scheme.neutral.background == ZenithLockScreenRGB(hex: 0x1C1C1E)
                     && ZenithLockScreenPalette.Scheme.neutral.ink == .white,
                     "with no cover colour the layer is #1C1C1E with white ink")
        let vivid = ZenithLockScreenPalette.softened(ZenithLockScreenRGB(red: 1, green: 0, blue: 0.1))
        suite.expect(vivid.hsb.saturation <= ZenithLockScreenPalette.maximumSaturation + 1e-9
                     && vivid.hsb.brightness <= ZenithLockScreenPalette.brightnessRange.upperBound + 1e-9,
                     "a vivid cover is calmed")
        let dark = ZenithLockScreenPalette.softened(ZenithLockScreenRGB(hex: 0x020202))
        suite.expect(dark.hsb.brightness >= ZenithLockScreenPalette.brightnessRange.lowerBound - 1e-9,
                     "a black cover is lifted a little")
        suite.expect(ZenithLockScreenPalette.ink(on: ZenithLockScreenRGB(hex: 0xEEEEEE)) == .darkInk
                     && ZenithLockScreenPalette.ink(on: ZenithLockScreenRGB(hex: 0x333333)) == .white,
                     "light backgrounds take #1C1917, dark ones white")
        let pale = ZenithLockScreenPalette.scheme(cover: ZenithLockScreenRGB(hex: 0xFFF3C4))
        suite.expect(pale.inkIsDark && pale.background.relativeLuminance > ZenithLockScreenPalette.darkInkLuminance,
                     "a pale cover keeps a light background with dark ink")
        // Every colour of a coarse grid ends with ink that reads at 4.5:1.
        var failing: [String] = []
        for red in stride(from: 0.0, through: 1.0, by: 0.125) {
            for green in stride(from: 0.0, through: 1.0, by: 0.125) {
                for blue in stride(from: 0.0, through: 1.0, by: 0.125) {
                    let scheme = ZenithLockScreenPalette.scheme(cover: ZenithLockScreenRGB(red: red, green: green, blue: blue))
                    let expected = ZenithLockScreenPalette.ink(on: ZenithLockScreenPalette.softened(
                        ZenithLockScreenRGB(red: red, green: green, blue: blue)))
                    if scheme.background.contrast(with: scheme.ink) < ZenithLockScreenPalette.minimumContrast - 1e-9
                        || scheme.ink != expected { failing.append("\(red),\(green),\(blue)") }
                }
            }
        }
        suite.expect(failing.isEmpty, "every cover colour reaches 4.5:1 with its ink: \(failing.prefix(5))")
        let mid = ZenithLockScreenPalette.scheme(cover: ZenithLockScreenRGB(red: 0.45, green: 0.62, blue: 0.75))
        let softened = ZenithLockScreenPalette.softened(ZenithLockScreenRGB(red: 0.45, green: 0.62, blue: 0.75))
        suite.expect(mid.ink == .white && softened.contrast(with: .white) < 4.5
                     && mid.background.hsb.brightness < softened.hsb.brightness
                     && abs(mid.background.hsb.hue - softened.hsb.hue) < 0.01,
                     "a mid blue too light for white ink is darkened, keeping its hue")
    }

    private static func backgrounds(_ suite: TestSuite) {
        let name = "com.vorssaint.tests.lockscreen-v2-background"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defer { defaults.removePersistentDomain(forName: name) }
        let standard = ZenithLockScreenV2Gates.resolve(music: true, lyricsAvailable: true, in: defaults)
        suite.expect(standard.fullBackground == .solid && standard.fullBlurRadius == 40 && standard.fullCustomColor == 0x1C1C1E,
                     "the full layer starts on a solid colour, a 40 point blur and #1C1C1E")
        defaults.set("blurredCover", forKey: DefaultsKey.zenithLockFullBackground)
        defaults.set(200.0, forKey: DefaultsKey.zenithLockFullBlurRadius)
        defaults.set("#F5F5F4", forKey: DefaultsKey.zenithLockFullCustomColor)
        let chosen = ZenithLockScreenV2Gates.resolve(music: true, lyricsAvailable: true, in: defaults)
        suite.expect(chosen.fullBackground == .blurredCover && chosen.fullBlurRadius == 80 && chosen.fullCustomColor == 0xF5F5F4,
                     "the background, the blur (kept within 10...80) and the picked colour are read at lock")

        var gates = standard
        let cover = ZenithLockScreenRGB(hex: 0xFFF3C4)
        // Solid, cover colour on: the cover's colour as it is (vivid) or calmed (muted).
        let fromCover = ZenithLockScreenPalette.scheme(for: gates, cover: cover, blurredAverage: nil)
        suite.expect(fromCover.background == cover && fromCover.inkIsDark && fromCover.dim == 0,
                     "vivid takes the cover's colour as it is, with dark ink on a pale one")
        let red = ZenithLockScreenRGB(hex: 0xE0102A)
        let vivid = ZenithLockScreenPalette.scheme(for: gates, cover: red, blurredAverage: nil)
        gates.fullTone = .muted
        let muted = ZenithLockScreenPalette.scheme(for: gates, cover: red, blurredAverage: nil)
        suite.expect(vivid.background.hsb.saturation > 0.85 && vivid.ink == .white
                     && vivid.background.contrast(with: .white) >= 4.5
                     && muted == ZenithLockScreenPalette.scheme(cover: red)
                     && muted.background.hsb.saturation <= ZenithLockScreenPalette.maximumSaturation + 1e-9
                     && abs(muted.background.hsb.hue - vivid.background.hsb.hue) < 0.02,
                     "muted calms the same red to round one's look, keeping its hue")
        var toneFailures = 0
        for value in stride(from: 0.0, through: 1.0, by: 0.1) {
            let colour = ZenithLockScreenRGB(red: value, green: 1 - value, blue: value * 0.5)
            let scheme = ZenithLockScreenPalette.scheme(cover: colour, tone: .vivid)
            if scheme.background.contrast(with: scheme.ink) < 4.5 - 1e-9 { toneFailures += 1 }
        }
        suite.expect(toneFailures == 0, "vivid colours still reach 4.5:1 with their ink")
        gates.fullTone = .vivid
        suite.expect(ZenithLockScreenPalette.scheme(for: gates, cover: nil, blurredAverage: nil)
                     == ZenithLockScreenPalette.Scheme(background: .neutral, ink: .white),
                     "with no cover the picked colour stands in")
        // Solid, cover colour off: the picked colour as it is.
        gates.fullCoverColor = false
        gates.fullCustomColor = 0xF5F5F4
        let light = ZenithLockScreenPalette.scheme(for: gates, cover: cover, blurredAverage: nil)
        suite.expect(light.background == ZenithLockScreenRGB(hex: 0xF5F5F4) && light.inkIsDark,
                     "solid with the cover colour off keeps the picked light colour, with dark ink")
        gates.fullCustomColor = 0x1C1C1E
        suite.expect(ZenithLockScreenPalette.scheme(for: gates, cover: cover, blurredAverage: nil) == .neutral,
                     "the default picked colour is #1C1C1E with white ink")
        gates.fullCustomColor = 0x7A8FA0
        let middling = ZenithLockScreenPalette.scheme(for: gates, cover: cover, blurredAverage: nil)
        suite.expect(middling.ink == .white && middling.background.contrast(with: .white) >= 4.5
                     && middling.background.relativeLuminance < ZenithLockScreenRGB(hex: 0x7A8FA0).relativeLuminance,
                     "a picked colour too light for white ink is darkened just enough")
        // Blurred cover: the ink comes from the dimmed average; the dim deepens for white ink.
        gates.fullBackground = .blurredCover
        let bright = ZenithLockScreenPalette.scheme(for: gates, cover: nil, blurredAverage: ZenithLockScreenRGB(red: 1, green: 1, blue: 0.98))
        suite.expect(bright.inkIsDark && bright.dim == ZenithLockScreenPalette.baseDim
                     && bright.background.contrast(with: bright.ink) >= 4.5,
                     "a bright blurred cover keeps its light dim and takes dark ink")
        let mid = ZenithLockScreenPalette.scheme(for: gates, cover: nil, blurredAverage: ZenithLockScreenRGB(red: 0.62, green: 0.74, blue: 0.82))
        suite.expect(mid.ink == .white && mid.dim > ZenithLockScreenPalette.baseDim && mid.dim <= ZenithLockScreenPalette.maximumDim
                     && mid.background.contrast(with: .white) >= 4.5,
                     "a middling blurred cover is dimmed further until white ink reads at 4.5:1")
        let dark = ZenithLockScreenPalette.scheme(for: gates, cover: nil, blurredAverage: ZenithLockScreenRGB(hex: 0x202830))
        suite.expect(dark.ink == .white && dark.dim == ZenithLockScreenPalette.baseDim,
                     "a dark blurred cover needs no more than the light dim")
        var failing = 0
        for value in stride(from: 0.0, through: 1.0, by: 0.05) {
            let scheme = ZenithLockScreenPalette.blurred(average: ZenithLockScreenRGB(red: value, green: value * 0.9, blue: 1 - value))
            if scheme.background.contrast(with: scheme.ink) < 4.5 - 1e-9 { failing += 1 }
        }
        suite.expect(failing == 0, "every blurred average reaches 4.5:1 with its ink")
        suite.expect(ZenithLockScreenPalette.scheme(for: gates, cover: cover, blurredAverage: nil)
                     == ZenithLockScreenPalette.solid(ZenithLockScreenRGB(hex: 0x7A8FA0)),
                     "a blurred cover with no artwork falls back to the picked colour")

        suite.expectClose(ZenithLockScreenBackdrop.imageRadius(points: 40, image: CGSize(width: 160, height: 160),
                                                               screen: CGSize(width: 1800, height: 1169)), 40 * 160 / 1800.0,
                          "the blur is sized for the copy that fills the screen")
        suite.expectClose(ZenithLockScreenBackdrop.imageRadius(points: 40, image: CGSize(width: 160, height: 160), screen: .zero), 0,
                          "no screen, no blur")
        let average = ZenithLockScreenPalette.average(rgba: [255, 0, 0, 255, 0, 0, 255, 255, 9, 9, 9, 0], count: 3)
        suite.expect(average.map { abs($0.red - 0.5) < 1e-9 && abs($0.blue - 0.5) < 1e-9 && $0.green == 0 } == true
                     && ZenithLockScreenPalette.average(rgba: [], count: 0) == nil,
                     "the average skips clear pixels")
    }

    private static func pixels(_ colours: [(UInt8, UInt8, UInt8, UInt8, Int)]) -> [UInt8] {
        colours.flatMap { colour in Array(repeating: [colour.0, colour.1, colour.2, colour.3], count: colour.4).flatMap { $0 } }
    }

    private static func coverColour(_ suite: TestSuite) {
        // A red cover with a white hand: the average is a dusty pink, the cover's colour is red.
        let hand = pixels([(222, 12, 40, 255, 55), (244, 238, 236, 255, 30), (200, 190, 188, 255, 5), (24, 18, 18, 255, 10)])
        let picked = ZenithLockScreenPalette.coverColor(rgba: hand, count: 100)
        let average = ZenithLockScreenPalette.average(rgba: hand, count: 100)
        suite.expect(picked.map { $0.red > 0.8 && $0.green < 0.1 && $0.blue < 0.2 && $0.hsb.saturation > 0.85 } == true
                     && average.map { $0.hsb.saturation < 0.6 } == true,
                     "a red cover with a white hand gives red, not the pink average")
        let grey = pixels([(120, 120, 122, 255, 60), (230, 230, 230, 255, 30), (20, 20, 20, 255, 10)])
        suite.expect(ZenithLockScreenPalette.saturatedCluster(rgba: grey, count: 100) == nil
                     && ZenithLockScreenPalette.coverColor(rgba: grey, count: 100) == ZenithLockScreenPalette.average(rgba: grey, count: 100),
                     "a grey cover has no colour of its own and falls back to its average")
        let logo = pixels([(120, 120, 122, 255, 97), (230, 20, 30, 255, 3)])
        suite.expect(ZenithLockScreenPalette.saturatedCluster(rgba: logo, count: 100) == nil,
                     "a small red logo on grey is not the cover's colour")
        let split = pixels([(30, 90, 220, 255, 40), (230, 200, 20, 255, 25), (250, 250, 250, 255, 35)])
        suite.expect(ZenithLockScreenPalette.coverColor(rgba: split, count: 100).map { $0.blue > 0.75 && $0.red < 0.2 } == true,
                     "the commonest hue wins, however much white there is")
        let reds = pixels([(250, 20, 60, 255, 20), (240, 40, 10, 255, 20), (40, 200, 60, 255, 30)])
        suite.expect(ZenithLockScreenPalette.coverColor(rgba: reds, count: 70).map { $0.red > 0.85 && $0.green < 0.2 } == true,
                     "reds either side of 0 degrees count together")
        let hidden = pixels([(10, 200, 10, 0, 90), (20, 40, 230, 255, 10)])
        suite.expect(ZenithLockScreenPalette.coverColor(rgba: hidden, count: 100).map { $0.blue > 0.85 } == true,
                     "transparent pixels do not count")
        suite.expect(ZenithLockScreenPalette.coverColor(rgba: [], count: 0) == nil
                     && ZenithLockScreenPalette.coverColor(rgba: [1, 2, 3], count: 1) == nil
                     && ZenithLockScreenPalette.coverColor(rgba: pixels([(1, 2, 3, 0, 4)]), count: 4) == nil,
                     "nothing readable gives no colour")
        let premultiplied = pixels([(100, 0, 0, 200, 4)])
        suite.expect(ZenithLockScreenPalette.coverColor(rgba: premultiplied, count: 4).map { abs($0.red - 0.5) < 0.01 } == true,
                     "premultiplied pixels are read at their own colour")
    }

    private static func edgeRing(_ suite: TestSuite) {
        let red = ZenithLockScreenRGB(hex: 0xE0102A)
        suite.expect(ZenithLockScreenRecordEdge.needsRing(edge: [ZenithLockScreenRGB(hex: 0xDA1430), .white], background: red),
                     "a rim the colour of the background gets the ring")
        suite.expect(!ZenithLockScreenRecordEdge.needsRing(edge: [ZenithLockScreenRGB(hex: 0x101010), .white], background: red)
                     && !ZenithLockScreenRecordEdge.needsRing(edge: [], background: red),
                     "a rim that stands apart, or none, gets no ring")
        suite.expectClose(red.distance(to: red), 0, "a colour's distance to itself")
        suite.expectClose(ZenithLockScreenRGB.white.distance(to: ZenithLockScreenRGB(hex: 0x000000)), 1, "black to white", tol: 1e-9)
        // A 10 px cover, yellow on top, cream below: the top arcs read yellow.
        let side = 10
        var cover = [UInt8]()
        for y in 0..<side {
            for _ in 0..<side { cover += y < side / 2 ? [245, 211, 106, 255] : [239, 229, 200, 255] }
        }
        let samples = ZenithLockScreenRecordEdge.samples(rgba: cover, side: side)
        let yellow = ZenithLockScreenRGB(hex: 0xF5D36A)
        suite.expect(samples.count == ZenithLockScreenRecordEdge.arcs
                     && ZenithLockScreenRecordEdge.needsRing(edge: samples, background: yellow)
                     && !ZenithLockScreenRecordEdge.needsRing(edge: samples, background: ZenithLockScreenRGB(hex: 0x1C1C1E)),
                     "the rim is read in arcs; one arc matching the background is enough")
        suite.expect(ZenithLockScreenRecordEdge.samples(rgba: [], side: 10).isEmpty, "no pixels, no rim")
    }

    private static func karaoke(_ suite: TestSuite) {
        suite.expectClose(ZenithLockScreenKaraoke.progress(start: 10, next: 14, characters: 20, position: 10), 0, "the line's start")
        suite.expectClose(ZenithLockScreenKaraoke.span(start: 10, next: 14, characters: 20), 1.7,
                          "a line of 20 characters is sung at about 12 a second")
        suite.expectClose(ZenithLockScreenKaraoke.progress(start: 10, next: 14, characters: 20, position: 10.85), 0.5,
                          "halfway through it")
        suite.expectClose(ZenithLockScreenKaraoke.span(start: 10, next: 13, characters: 60), 3 * 0.92,
                          "a long line ends a little before the next one starts")
        suite.expectClose(ZenithLockScreenKaraoke.span(start: 10, next: 40, characters: 2), ZenithLockScreenKaraoke.minimumSpan,
                          "a short line still takes a moment")
        suite.expectClose(ZenithLockScreenKaraoke.span(start: 10, next: nil, characters: 20), 1.7, "the last line")
        suite.expectClose(ZenithLockScreenKaraoke.progress(start: 10, next: 14, characters: 20, position: 30), 1, "past the line")
        suite.expectClose(ZenithLockScreenKaraoke.progress(start: 10, next: 14, characters: 20, position: 5), 0, "before the line")
        suite.expectClose(ZenithLockScreenKaraoke.progress(start: 10, next: 10, characters: 20, position: 10), 1,
                          "two lines at one time")
        suite.expectClose(ZenithLockScreenKaraoke.progress(start: 10, next: 14, characters: 0, position: 12), 0, "an empty line")
        suite.expectClose(ZenithLockScreenKaraoke.progress(start: 10, next: 14, characters: 5, position: .nan), 0, "a broken position")
    }

    private static func words(_ suite: TestSuite) {
        suite.expect(ZenithLockScreenKaraoke.words("what the  fucking hell") == [0..<4, 5..<8, 10..<17, 18..<22],
                     "words run between spaces")
        suite.expect(ZenithLockScreenKaraoke.words("  ") == [] && ZenithLockScreenKaraoke.words("") == [],
                     "spaces alone have no words")
        suite.expect(ZenithLockScreenKaraoke.words("君の名は") == [0..<1, 1..<2, 2..<3, 3..<4]
                     && ZenithLockScreenKaraoke.words("사랑해 you") == [0..<1, 1..<2, 2..<3, 4..<7],
                     "every CJK character is its own word")
        // Never split: at any moment the words before the one being sung are
        // lit, those after it unlit, and the one being sung fades from its start.
        let line = "what the hell is fucking wrong with me"
        let words = ZenithLockScreenKaraoke.words(line)
        var broken: [String] = []
        for step in 0...200 {
            let progress = Double(step) / 200
            let levels = ZenithLockScreenKaraoke.levels(line, progress: progress)
            guard levels.count == line.count, levels.allSatisfy({ $0 >= 0 && $0 <= 1 }) else { broken.append("\(step) range"); continue }
            let states = words.map { word -> Int in
                let values = word.map { levels[$0] }
                if values.allSatisfy({ $0 >= 1 }) { return 2 }
                if values.allSatisfy({ $0 <= 0 }) { return 0 }
                return 1
            }
            if states.filter({ $0 == 1 }).count > 1 { broken.append("\(step) two words partly lit") }
            if zip(states, states.dropFirst()).contains(where: { $0 < $1 }) { broken.append("\(step) out of order") }
            for word in words {
                let values = word.map { levels[$0] }
                if zip(values, values.dropFirst()).contains(where: { $0 < $1 - 1e-12 }) { broken.append("\(step) edge backwards") }
            }
        }
        suite.expect(broken.isEmpty, "a word is never left split and lights from its first letter: \(broken.prefix(3))")
        let start = ZenithLockScreenKaraoke.levels(line, progress: 0)
        let end = ZenithLockScreenKaraoke.levels(line, progress: 1)
        suite.expect(start.allSatisfy { $0 == 0 } && end.allSatisfy { $0 == 1 }, "nothing lit at the start, all of it at the end")
        let fucking = words[4]
        var reachedWhole = false
        for step in 0...400 {
            let levels = ZenithLockScreenKaraoke.levels(line, progress: Double(step) / 400)
            let values = fucking.map { levels[$0] }
            if values.allSatisfy({ $0 >= 1 }) { reachedWhole = true; break }
            // While "fucking" is lit at its start, its end is on the way too, never a hard cut.
            if values.first == 1, values.last == 0 { break }
        }
        suite.expect(reachedWhole, "the word being sung lights up whole, with a soft edge rather than a cut")
        suite.expect(ZenithLockScreenKaraoke.levels("", progress: 0.5).isEmpty
                     && ZenithLockScreenKaraoke.levels("♪", progress: .nan) == [0],
                     "an empty line, a pause, a broken progress")
    }

    private static func timing(_ suite: TestSuite) {
        suite.expectClose(ZenithLockScreenLyricTiming.offset(island: 0.25, lockScreen: -0.5), -0.25,
                          "the island's adjustment and the lock screen's timing add up")
        suite.expectClose(ZenithLockScreenLyricTiming.offset(island: .nan, lockScreen: 0.3), 0.3, "a broken offset counts as none")
        // A positive offset shows each line later; a negative one earlier.
        let lyrics = NotchLyrics(lines: [NotchLyricLine(time: 10, text: "a"), NotchLyricLine(time: 12, text: "b")],
                                 plain: "", instrumental: false)
        suite.expect(lyrics.activeIndex(at: 11.9, offset: 0) == 0
                     && lyrics.activeIndex(at: 11.9, offset: ZenithLockScreenLyricTiming.offset(island: 0, lockScreen: -0.2)) == 1
                     && lyrics.activeIndex(at: 12.1, offset: ZenithLockScreenLyricTiming.offset(island: 0, lockScreen: 0.3)) == 0,
                     "the lock screen's timing moves the line being sung")
        suite.expectClose(ZenithLockScreenKaraoke.progress(start: 10 + 0.5, next: 12 + 0.5, characters: 10, position: 10.5), 0,
                          "and the karaoke with it")
    }

    private static func lyricWindow(_ suite: TestSuite) {
        suite.expect(ZenithLockScreenLyricWindow.make(lineCount: 10, active: 4, upcoming: 5)
                     == ZenithLockScreenLyricWindow(previous: 3, active: 4, upcoming: [5, 6, 7, 8, 9]),
                     "the line before, the sung one and five after")
        suite.expect(ZenithLockScreenLyricWindow.make(lineCount: 10, active: 8, upcoming: 5)
                     == ZenithLockScreenLyricWindow(previous: 7, active: 8, upcoming: [9]),
                     "near the end fewer lines follow")
        suite.expect(ZenithLockScreenLyricWindow.make(lineCount: 10, active: 0, upcoming: 1)
                     == ZenithLockScreenLyricWindow(previous: nil, active: 0, upcoming: [1]),
                     "the first line has none before it")
        suite.expect(ZenithLockScreenLyricWindow.make(lineCount: 10, active: nil, upcoming: 2)
                     == ZenithLockScreenLyricWindow(previous: nil, active: nil, upcoming: [0, 1]),
                     "before the singing starts the first lines wait")
        suite.expect(ZenithLockScreenLyricWindow.make(lineCount: 0, active: 2, upcoming: 2).upcoming.isEmpty
                     && ZenithLockScreenLyricWindow.make(lineCount: 3, active: 7, upcoming: 2).active == nil,
                     "no lines or a stale index show nothing out of range")
    }

    private static func jobs(_ suite: TestSuite) {
        let none = ZenithLockScreenJobLine.arrange([])
        suite.expect(none.isEmpty && none.overflow == 0, "no jobs, nothing beside the row")
        let one = ZenithLockScreenJobLine.arrange(Array(sampleJobs.prefix(1)))
        suite.expect(one.leading?.id == "export" && one.trailing == nil && one.overflow == 0, "one job goes left of the row")
        let two = ZenithLockScreenJobLine.arrange(Array(sampleJobs.prefix(2)))
        suite.expect(two.leading?.id == "export" && two.trailing?.id == "backup" && two.overflow == 0,
                     "the second job goes right of the row")
        let four = ZenithLockScreenJobLine.arrange(sampleJobs)
        suite.expect(four.shown.map(\.id) == ["export", "backup"] && four.overflow == 2,
                     "at most two show; the rest count as +N")
        suite.expect(ZenithLockScreenJobLine.arrange(sampleJobs, limit: 9).shown.count == 2
                     && ZenithLockScreenJobs.visibleLimit == 2,
                     "the row never holds more than two")
        suite.expect(ZenithLockScreenJobLine.percent(0.629) == 62 && ZenithLockScreenJobLine.percent(0.999) == 99
                     && ZenithLockScreenJobLine.percent(1) == 100 && ZenithLockScreenJobLine.percent(-3) == 0
                     && ZenithLockScreenJobLine.percent(nil) == nil && ZenithLockScreenJobLine.percent(.nan) == nil,
                     "figures are whole percentages, rounded down")
        suite.expect(ZenithLockScreenJobLine.ringHex(.export) == 0xC4B5FD && ZenithLockScreenJobLine.ringHex(.cardImport) == 0xFDBA74
                     && ZenithLockScreenJobLine.ringHex(.backup) == 0xFDBA74 && ZenithLockScreenJobLine.ringHex(.command) == 0x86EFAC
                     && ZenithLockScreenJobLine.ringHex(.vercel) == nil,
                     "each source has its ring colour; Vercel's is the ink")
    }

    private static func topRight(_ suite: TestSuite) {
        var gates = ZenithLockScreenV2Gates()
        gates.full = true
        gates.fullJobs = true
        gates.fullTopPrayer = true
        gates.fullTopWeather = true
        let everything = Set(ZenithLockScreenTopItem.allCases)
        suite.expect(ZenithLockScreenTopRight.items(gates, showing: everything) == [.jobs, .prayer, .weather],
                     "from the close button outward: jobs, the next prayer, the weather")
        gates.fullTopTimer = true
        gates.fullTopCalendar = true
        gates.fullTopWakaTime = true
        suite.expect(ZenithLockScreenTopRight.items(gates, showing: everything) == [.jobs, .prayer, .weather, .timer, .calendar, .wakatime],
                     "then the timer, the calendar and WakaTime")
        suite.expect(ZenithLockScreenTopRight.items(gates, showing: [.weather, .wakatime]) == [.weather, .wakatime],
                     "items with nothing to show are left out")
        gates.fullJobs = false
        gates.fullTopWeather = false
        suite.expect(ZenithLockScreenTopRight.items(gates, showing: everything) == [.prayer, .timer, .calendar, .wakatime],
                     "and so are items switched off")
        suite.expect(ZenithLockScreenJobLine.sampleJobs.count >= 2 && Set(ZenithLockScreenJobLine.sampleJobs.map(\.id)).count
                     == ZenithLockScreenJobLine.sampleJobs.count,
                     "the preview's sample jobs are distinct")
    }

    private static func smallRules(_ suite: TestSuite) {
        suite.expect(ZenithLockScreenHint.shows(count: 0) && ZenithLockScreenHint.shows(count: 2)
                     && !ZenithLockScreenHint.shows(count: 3) && !ZenithLockScreenHint.shows(count: 40),
                     "the lyric's hint shows its first three times only")
        suite.expect(ZenithLockScreenFullExit.closes(keyCode: 53) && !ZenithLockScreenFullExit.closes(keyCode: 0)
                     && !ZenithLockScreenFullExit.closes(keyCode: 36) && ZenithLockScreenFullExit.pauseGrace == 1.2,
                     "only Esc closes the full layer from the keyboard; music gets 1.2 s of grace")
        let start = Date(timeIntervalSinceReferenceDate: 0)
        suite.expectClose(ZenithLockScreenDiscSpin.angle(from: 0, startedAt: start, at: start.addingTimeInterval(8)), 0,
                          "the record turns once every eight seconds", tol: 1e-9)
        suite.expectClose(ZenithLockScreenDiscSpin.angle(from: 10, startedAt: start, at: start.addingTimeInterval(2)), 100,
                          "from where it stopped")
        suite.expectClose(ZenithLockScreenDiscSpin.angle(from: 10, startedAt: start, at: start.addingTimeInterval(-3)), 10,
                          "a clock that went back holds it still")
        suite.expectClose(ZenithLockScreenDiscSpin.coast, 27, "and it coasts 27 degrees to a stop")
        suite.expect(ZenithLockScreenInitials.of("Faiz Andhilmi") == "FA" && ZenithLockScreenInitials.of("faiz") == "F"
                     && ZenithLockScreenInitials.of("Anna Maria de la Cruz") == "AC" && ZenithLockScreenInitials.of("  ") == ""
                     && ZenithLockScreenInitials.of("J. R. Tolkien") == "JT",
                     "initials stand in for the account picture")
    }

    private static func minimalLayout(_ suite: TestSuite) {
        let screen = CGRect(x: 0, y: 0, width: 1800, height: 1169)
        guard let row = NotchLockScreenLayout.rowFrame(in: screen),
              let player = NotchLockScreenLayout.playerFrame(in: screen) else {
            suite.expect(false, "the reference display has a row and a player")
            return
        }
        let panel = ZenithLockScreenMinimalLayout.frame(row: row, player: player)
        suite.expect(panel.minX == row.minX && panel.width == row.width && panel.minY == player.minY
                     && panel.maxY == row.maxY,
                     "the minimal layer takes the player's room and reaches up behind the row, as wide as it")
        let titleTop = ZenithLockScreenMinimalLayout.titleTop(row: row, panel: panel)
        // The title's text sits under the row by the clock's gap to the row's text.
        let textTop = panel.maxY - titleTop - ZenithLockScreenMinimalLayout.titlePadding
        suite.expectClose(Double(titleTop), Double(row.height + ZenithLockScreenMinimalLayout.titleGap),
                          "the title line starts a row gap under the row")
        suite.expectClose(Double(row.minY - textTop), Double(NotchLockScreenLayout.rowGap + 6),
                          "its text as far under the row's frame as the row's text is under the clock")
        suite.expect(ZenithLockScreenMinimalLayout.lyricGap + ZenithLockScreenMinimalLayout.titlePadding >= 6
                     && ZenithLockScreenMinimalLayout.lyricGap + ZenithLockScreenMinimalLayout.titlePadding <= 8,
                     "the sung line starts 6 to 8 points under the title")
        suite.expect(titleTop - ZenithLockScreenMinimalLayout.shadeReach.height >= 0,
                     "the shade fades out inside the panel, not against its edge")
        suite.expect(ZenithLockScreenMinimalLayout.terminalLift(.low) == 10 && ZenithLockScreenMinimalLayout.terminalLift(.normal) == 0,
                     "only the low placement lifts the readout")
        let normal = NotchLockScreenTerminalLayout.arrange(row: row, player: player, screen: screen, lines: 4, music: true)
        let low = NotchLockScreenTerminalLayout.arrange(row: row, player: player, screen: screen, lines: 4, music: true,
                                                         lift: ZenithLockScreenMinimalLayout.terminalLift(.low))
        suite.expect(normal.terminal?.minY == NotchLockScreenLayout.loginClearance
                     && low.terminal?.minY == NotchLockScreenLayout.loginClearance + 10
                     && low.terminal?.height == normal.terminal?.height
                     && low.player.map { $0.minY == (low.terminal?.maxY ?? 0) + NotchLockScreenTerminalLayout.gap } == true,
                     "the low readout's frame is 10 points over the login line, the player above it")
        suite.expect(NotchLockScreenTerminalLayout.arrange(row: row, player: player, screen: screen, lines: 4, music: true,
                                                           lift: .nan).terminal == normal.terminal,
                     "a broken lift leaves the readout where it was")
    }

    private static func terminalCard(_ suite: TestSuite) {
        let screen = CGRect(x: 0, y: 0, width: 1800, height: 1169)
        guard let row = NotchLockScreenLayout.rowFrame(in: screen),
              let frame = NotchLockScreenTerminalLayout.arrange(
                row: row, player: NotchLockScreenLayout.playerFrame(in: screen), screen: screen, lines: 7, music: true,
                lift: ZenithLockScreenMinimalLayout.terminalLift(.low)).terminal else {
            suite.expect(false, "the reference display has room for seven lines")
            return
        }
        // Seven lines may show, four have something to say.
        let shown = NotchLockScreenTerminalLayout.height(lines: 4)
        let low = ZenithLockScreenMinimalLayout.terminalCard(in: frame, cardHeight: shown, placement: .low)
        suite.expect(low.minY == screen.minY + NotchLockScreenLayout.loginClearance + 10 && low.height == shown,
                     "low, the card's bottom is 10 points over the login line however few lines show")
        let full = ZenithLockScreenMinimalLayout.terminalCard(in: frame, cardHeight: frame.height, placement: .low)
        suite.expect(full == frame, "with every line showing the card fills its frame")
        let normal = ZenithLockScreenMinimalLayout.terminalCard(in: frame, cardHeight: shown, placement: .normal)
        suite.expect(normal.maxY == frame.maxY && normal.height == shown,
                     "normal, the card still hangs from its frame's top")
        suite.expect(ZenithLockScreenMinimalLayout.terminalAnchorsBottom(.low) && !ZenithLockScreenMinimalLayout.terminalAnchorsBottom(.normal)
                     && ZenithLockScreenMinimalLayout.terminalCard(in: frame, cardHeight: 9999, placement: .low).height == frame.height
                     && ZenithLockScreenMinimalLayout.terminalCard(in: frame, cardHeight: -4, placement: .low).height == 0,
                     "the card stays within its frame")
    }

    private static func fullLayout(_ suite: TestSuite) {
        let reference = ZenithLockScreenFullLayout(size: ZenithLockScreenFullLayout.reference)
        suite.expect(reference.scale == 1 && reference.margin == 110 && reference.clockTop == 85
                     && reference.discSize == 320 && reference.groupLeft == 350 && reference.lyricsLeft == 760
                     && reference.lyricsLeft - (reference.groupLeft + reference.discSize) == 90
                     && reference.identityBottom == 75 && reference.activeSize == 54 && reference.lineSize == 40
                     && reference.closeSize == 42 && reference.hubSize == 26,
                     "the reference display keeps the design's measures")
        suite.expectClose(Double(reference.groupLeft * 2 + reference.groupWidth), 1800,
                          "the record and the lyrics are one group, centred across the screen", tol: 1)
        let middle = (reference.topRowBottom + reference.bottomRowTop) / 2
        suite.expectClose(Double(reference.columnTop + reference.columnHeight / 2), Double(middle),
                          "the record's column sits midway between the top and bottom rows", tol: 1)
        suite.expectClose(Double(reference.discMiddle), 508, "the record's middle, which the sung line shares", tol: 2)
        suite.expect(reference.columnTop > reference.topRowBottom && reference.columnTop + reference.columnHeight < reference.bottomRowTop
                     && reference.lyricsBottom < reference.bottomRowTop && reference.lyricsTop > reference.topRowBottom,
                     "the group and the lyrics stay clear of the corners")
        for size in [CGSize(width: 1512, height: 982), CGSize(width: 3440, height: 1440), CGSize(width: 2560, height: 1440)] {
            let layout = ZenithLockScreenFullLayout(size: size)
            let centred = abs(layout.groupLeft * 2 + layout.groupWidth - size.width) <= 1
            suite.expect(centred && layout.groupLeft >= layout.margin
                         && layout.columnTop + layout.columnHeight < layout.bottomRowTop
                         && layout.lyricsLeft + layout.lyricsWidth <= size.width - layout.margin,
                         "a \(Int(size.width)) × \(Int(size.height)) display keeps the group centred and inside the corners")
        }
        suite.expect(ZenithLockScreenFullLayout(size: .zero).scale == 1
                     && ZenithLockScreenFullLayout(size: CGSize(width: 400, height: 300)).scale == 0.55,
                     "a broken or tiny display keeps a usable scale")
        suite.expect(ZenithLockScreenFullLyrics.upcoming == 3 && ZenithLockScreenFullLyrics.previousOpacity == 0.35
                     && ZenithLockScreenFullLyrics.upcomingOpacities == [0.45, 0.28, 0.14]
                     && ZenithLockScreenFullLyrics.upcomingBlurs.count == ZenithLockScreenFullLyrics.upcomingOpacities.count
                     && zip(ZenithLockScreenFullLyrics.upcomingBlurs, ZenithLockScreenFullLyrics.upcomingBlurs.dropFirst()).allSatisfy { $0 < $1 },
                     "one line before at 35%, three after at 45, 28 and 14%, softer the further they are")
        suite.expect(ZenithLockScreenFullLyrics.upcomingOpacity(0, darkInk: true) > ZenithLockScreenFullLyrics.upcomingOpacity(0, darkInk: false)
                     && ZenithLockScreenFullLyrics.opacity(0.9, darkInk: true) == 1
                     && ZenithLockScreenFullLyrics.upcomingOpacity(7, darkInk: false) == 0.14
                     && ZenithLockScreenFullLyrics.upcomingBlur(-2) == ZenithLockScreenFullLyrics.upcomingBlurs[0],
                     "dark ink lifts the faded lines a little; distances stay in range")
        let window = ZenithLockScreenLyricWindow.make(lineCount: 20, active: 6, upcoming: ZenithLockScreenFullLyrics.upcoming)
        suite.expect(window == ZenithLockScreenLyricWindow(previous: 5, active: 6, upcoming: [7, 8, 9]),
                     "the full layer shows the line before, the sung one and three after")
    }

    private static func lyricPlacement(_ suite: TestSuite) {
        let tops = ZenithLockScreenLyricPlacement.tops(heights: [48, 65, 48, 48, 48], spacing: 22, active: 1, middle: 508)
        suite.expect(tops.count == 5 && abs(tops[1] + 32.5 - 508) <= 0.5 && tops[0] + 48 + 22 == tops[1]
                     && tops[2] == tops[1] + 65 + 22,
                     "the sung line's middle is the record's, the others stacked around it")
        let wrapped = ZenithLockScreenLyricPlacement.tops(heights: [48, 130, 48], spacing: 22, active: 1, middle: 508)
        suite.expect(abs(wrapped[1] + 65 - 508) <= 0.5, "a sung line on two lines is centred too")
        let waiting = ZenithLockScreenLyricPlacement.tops(heights: [48, 48], spacing: 22, active: nil, middle: 508)
        suite.expect(waiting.first == 484 && ZenithLockScreenLyricPlacement.tops(heights: [], spacing: 22, active: 0, middle: 0).isEmpty
                     && ZenithLockScreenLyricPlacement.tops(heights: [48], spacing: 22, active: 9, middle: 100) == [76],
                     "before the singing the first line waits in the middle; a stale index falls back")
    }
}
