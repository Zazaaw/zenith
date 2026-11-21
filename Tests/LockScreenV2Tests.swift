// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation

/// Zenith fork: the lock screen v2's pure parts: its switches, the full
/// layer's colours, karaoke timing, the lyric window, the jobs in the row and
/// the layout. Nothing here draws a window or reads the account.
enum LockScreenV2Tests {
    static func run(_ suite: TestSuite) {
        gates(suite)
        luminance(suite)
        scheme(suite)
        dominant(suite)
        karaoke(suite)
        lyricWindow(suite)
        jobs(suite)
        smallRules(suite)
        minimalLayout(suite)
        fullLayout(suite)
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

    private static func dominant(_ suite: TestSuite) {
        func pixels(_ colours: [(UInt8, UInt8, UInt8, UInt8, Int)]) -> [UInt8] {
            colours.flatMap { colour in Array(repeating: [colour.0, colour.1, colour.2, colour.3], count: colour.4).flatMap { $0 } }
        }
        let mostlyRed = pixels([(220, 30, 40, 255, 70), (20, 40, 200, 255, 30)])
        let red = ZenithLockScreenPalette.dominant(rgba: mostlyRed, count: 100)
        suite.expect(red.map { $0.red > 0.8 && $0.blue < 0.3 } == true, "the commonest colour wins")
        let hidden = pixels([(10, 200, 10, 0, 90), (240, 240, 240, 255, 10)])
        suite.expect(ZenithLockScreenPalette.dominant(rgba: hidden, count: 100).map { $0.green > 0.9 && $0.red > 0.9 } == true,
                     "transparent pixels do not count")
        suite.expect(ZenithLockScreenPalette.dominant(rgba: [], count: 0) == nil
                     && ZenithLockScreenPalette.dominant(rgba: [1, 2, 3], count: 1) == nil
                     && ZenithLockScreenPalette.dominant(rgba: pixels([(1, 2, 3, 0, 4)]), count: 4) == nil,
                     "nothing readable gives no colour")
        let premultiplied = pixels([(100, 0, 0, 200, 4)])
        suite.expect(ZenithLockScreenPalette.dominant(rgba: premultiplied, count: 4).map { abs($0.red - 0.5) < 0.01 } == true,
                     "premultiplied pixels are read at their own colour")
    }

    private static func karaoke(_ suite: TestSuite) {
        suite.expectClose(ZenithLockScreenKaraoke.progress(start: 10, next: 14, characters: 20, position: 10), 0, "the line's start")
        suite.expectClose(ZenithLockScreenKaraoke.progress(start: 10, next: 14, characters: 20, position: 11.8), 0.5,
                          "halfway through a 3.6 s line of 20 characters")
        suite.expectClose(ZenithLockScreenKaraoke.progress(start: 10, next: 14, characters: 40, position: 12), 0.5,
                          "a long line spreads over the time to the next")
        suite.expectClose(ZenithLockScreenKaraoke.span(start: 10, next: 40, characters: 10), 1.8,
                          "a line before a long gap is sung at a singing pace")
        suite.expectClose(ZenithLockScreenKaraoke.span(start: 10, next: 40, characters: 2), ZenithLockScreenKaraoke.minimumSpan,
                          "a short line still takes a moment")
        suite.expectClose(ZenithLockScreenKaraoke.span(start: 10, next: nil, characters: 10), 1.8, "the last line")
        suite.expectClose(ZenithLockScreenKaraoke.progress(start: 10, next: 14, characters: 20, position: 30), 1, "past the line")
        suite.expectClose(ZenithLockScreenKaraoke.progress(start: 10, next: 14, characters: 20, position: 5), 0, "before the line")
        suite.expectClose(ZenithLockScreenKaraoke.progress(start: 10, next: 10, characters: 20, position: 10), 1,
                          "two lines at one time")
        suite.expectClose(ZenithLockScreenKaraoke.progress(start: 10, next: 14, characters: 0, position: 12), 0, "an empty line")
        suite.expectClose(ZenithLockScreenKaraoke.progress(start: 10, next: 14, characters: 5, position: .nan), 0, "a broken position")
        let sung = ZenithLockScreenKaraoke.sung(characters: 20, progress: 0.525)
        suite.expect(sung.whole == 10 && abs(sung.partial - 0.5) < 1e-9, "ten and a half characters sung")
        let done = ZenithLockScreenKaraoke.sung(characters: 20, progress: 1)
        suite.expect(done.whole == 20 && done.partial == 0, "the whole line sung")
        suite.expect(ZenithLockScreenKaraoke.sung(characters: 0, progress: 0.5).whole == 0
                     && ZenithLockScreenKaraoke.sung(characters: 4, progress: 3).whole == 4,
                     "sung characters stay within the line")
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

    private static func smallRules(_ suite: TestSuite) {
        suite.expect(ZenithLockScreenHint.shows(count: 0) && ZenithLockScreenHint.shows(count: 2)
                     && !ZenithLockScreenHint.shows(count: 3) && !ZenithLockScreenHint.shows(count: 40),
                     "the lyric's hint shows its first three times only")
        suite.expect(!ZenithLockScreenFullExit.moved(from: .zero, to: CGPoint(x: 5, y: 6))
                     && ZenithLockScreenFullExit.moved(from: .zero, to: CGPoint(x: 6, y: 6))
                     && ZenithLockScreenFullExit.moved(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 100, y: 91))
                     && !ZenithLockScreenFullExit.moved(from: .zero, to: CGPoint(x: CGFloat.nan, y: 40)),
                     "the full layer leaves once the pointer travels more than 8 points")
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
                     && panel.height == player.height,
                     "the minimal layer takes the player's room, as wide as the row")
        suite.expectClose(Double(ZenithLockScreenMinimalLayout.titleTop(row: row, panel: panel)), 28,
                          "the title line's top sits 38 points under the row's frame")
        suite.expect(ZenithLockScreenMinimalLayout.terminalLift(.low) == 10 && ZenithLockScreenMinimalLayout.terminalLift(.normal) == 0,
                     "only the low placement lifts the readout")
        let normal = NotchLockScreenTerminalLayout.arrange(row: row, player: player, screen: screen, lines: 4, music: true)
        let low = NotchLockScreenTerminalLayout.arrange(row: row, player: player, screen: screen, lines: 4, music: true,
                                                         lift: ZenithLockScreenMinimalLayout.terminalLift(.low))
        suite.expect(normal.terminal?.minY == NotchLockScreenLayout.loginClearance
                     && low.terminal?.minY == NotchLockScreenLayout.loginClearance + 10
                     && low.terminal?.height == normal.terminal?.height
                     && low.player.map { $0.minY == (low.terminal?.maxY ?? 0) + NotchLockScreenTerminalLayout.gap } == true,
                     "the low readout's bottom is 10 points over the login line, hugging its lines, the player above it")
        suite.expect(NotchLockScreenTerminalLayout.arrange(row: row, player: player, screen: screen, lines: 4, music: true,
                                                           lift: .nan).terminal == normal.terminal,
                     "a broken lift leaves the readout where it was")
    }

    private static func fullLayout(_ suite: TestSuite) {
        let reference = ZenithLockScreenFullLayout(size: ZenithLockScreenFullLayout.reference)
        suite.expect(reference.scale == 1 && reference.margin == 110 && reference.clockTop == 85
                     && reference.columnLeft == 210 && reference.columnTop == 300 && reference.discSize == 350
                     && reference.lyricsLeft == 710 && reference.lyricsWidth == 1800 - 710 - 110
                     && reference.identityBottom == 75 && reference.activeSize == 64 && reference.lineSize == 48,
                     "the reference display keeps the design's measures")
        let laptop = ZenithLockScreenFullLayout(size: CGSize(width: 1512, height: 982))
        suite.expect(laptop.scale < 1 && laptop.discSize < 350 && laptop.columnLeft + laptop.discSize < laptop.lyricsLeft
                     && laptop.lyricsLeft + laptop.lyricsWidth <= 1512 - laptop.margin + 1,
                     "a smaller display scales down and the lyrics stay right of the record")
        let wide = ZenithLockScreenFullLayout(size: CGSize(width: 3440, height: 1440))
        suite.expect(wide.scale <= 1.6 && wide.columnLeft + wide.discSize < wide.lyricsLeft
                     && wide.activeTop + wide.activeSize < 1440 - wide.identityBottom - wide.photoSize,
                     "an ultrawide display scales by its height")
        suite.expect(ZenithLockScreenFullLayout(size: .zero).scale == 1
                     && ZenithLockScreenFullLayout(size: CGSize(width: 400, height: 300)).scale == 0.55,
                     "a broken or tiny display keeps a usable scale")
        suite.expect(ZenithLockScreenFullLayout.upcomingOpacities == [0.42, 0.30, 0.20, 0.12, 0.06]
                     && ZenithLockScreenFullLayout.upcomingBlurs.count == ZenithLockScreenFullLayout.upcomingOpacities.count
                     && zip(ZenithLockScreenFullLayout.upcomingBlurs, ZenithLockScreenFullLayout.upcomingBlurs.dropFirst()).allSatisfy { $0 < $1 }
                     && ZenithLockScreenFullLayout.upcomingBlurs.first == 1.25 && ZenithLockScreenFullLayout.upcomingBlurs.last == 7,
                     "upcoming lines fade from 42% to 6% and blur from 1.25 to 7 points")
    }
}
