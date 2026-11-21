// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: the teleprompter. The speed math from the layout estimate,
/// paragraph jumps, the time left, the clock, the voice pace with fake
/// levels on a fake clock, the keys, the scripts kept in a temporary
/// container with their own defaults suite, settings and backups, the
/// island's size and the strings. No microphone, no window, no island.
enum PrompterTests {
    static func run(_ suite: TestSuite) {
        paragraphs(suite)
        wordCount(suite)
        speedMath(suite)
        jumps(suite)
        timeLeft(suite)
        translate(suite)
        clock(suite)
        voicePace(suite)
        keys(suite)
        storage(suite)
        importing(suite)
        settings(suite)
        island(suite)
        strings(suite)
    }

    private static let suiteName = "com.vorssaint.tests.prompter"

    private static func withDefaults(_ body: (UserDefaults) -> Void) {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        body(defaults)
        defaults.removePersistentDomain(forName: suiteName)
    }

    private static func withContainer(_ body: (URL) -> Void) {
        let root = FileManager.default.temporaryDirectory.appending(path: "zenith-prompter-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        body(root)
        try? FileManager.default.removeItem(at: root)
    }

    /// Three paragraphs, 10 words each, each 100 points tall with 20 between.
    private static var even: PrompterTimeline {
        PrompterTimeline(tops: [0, 120, 240], heights: [100, 100, 100], words: [10, 10, 10], lineHeight: 40)
    }

    // MARK: Text

    private static func paragraphs(_ suite: TestSuite) {
        let script = "# Intro\n\nHello there,\nthis is **Zenith**.\n\n\n   \nSecond `block` here.\r\n\r\nLast"
        let parsed = PrompterText.paragraphs(script)
        suite.expect(parsed.count == 4, "blank lines, however many, separate paragraphs; empty blocks are dropped")
        suite.expect(parsed.first?.heading == true && parsed.first?.text == "Intro",
                     "a Markdown heading reads as a heading without its marks")
        suite.expect(parsed.count > 1 && parsed[1].text == "Hello there,\nthis is Zenith." && !parsed[1].heading,
                     "single line breaks stay, emphasis marks go")
        suite.expect(parsed.count > 2 && parsed[2].text == "Second block here.", "code marks go, Windows line ends split too")
        suite.expect(PrompterText.paragraphs("#hashtag at the start").first?.heading == false,
                     "a hash without a space is a word, not a heading")
        suite.expect(PrompterText.paragraphs(" \n\n \n").isEmpty, "only whitespace is no script")
    }

    private static func wordCount(_ suite: TestSuite) {
        suite.expect(PrompterText.wordCount("Hello,  world - it’s 2026!") == 4, "punctuation alone is no word")
        suite.expect(PrompterText.wordCount("今日は晴れ") == 5, "every Japanese character reads as one")
        suite.expect(PrompterText.wordCount("Zenith 提词器") == 4, "mixed scripts count both ways")
        suite.expect(PrompterText.wordCount("") == 0, "nothing is no words")
    }

    // MARK: Speed

    private static func speedMath(_ suite: TestSuite) {
        // 60 words at 120 wpm take 30 s; the column's travel is its height
        // less one line, so the speed is that over 30 s.
        let timeline = PrompterTimeline(tops: [0, 200], heights: [180, 180], words: [30, 30], lineHeight: 40)
        suite.expectClose(timeline.limit, 340, "the end has the last line on the guide")
        suite.expectClose(timeline.pointsPerSecond(wpm: 120), 340.0 / 30.0, "travel over the time the words take")
        suite.expectClose(timeline.pointsPerSecond(wpm: 240), 2 * timeline.pointsPerSecond(wpm: 120),
                          "twice the words per minute, twice the speed")
        suite.expect(PrompterTimeline.empty.pointsPerSecond(wpm: 140) == 0
                     && timeline.pointsPerSecond(wpm: 0) == 0, "no words or no speed never moves")

        // The estimate: a paragraph of 20 four-letter words at 30 pt in a
        // 300-point column. Each word is 4 × 16.5 pt with a 16.5-point space,
        // so 3 words fill a line (3 × 66 + 2 × 16.5 = 231; a fourth needs 313.5).
        let words = Array(repeating: "word", count: 20).joined(separator: " ")
        let lines = PrompterLayout.estimatedLines(words, textSize: 30, width: 300)
        suite.expect(lines == 7, "words wrap whole: 20 words three to a line take 7 lines, got \(lines)")
        let paragraph = PrompterText.paragraphs(words)
        let estimate = PrompterLayout.estimate(paragraph, textSize: 30, lineSpacing: 1.5, width: 300)
        // First line 36 pt (30 × 1.2), then 6 more at 54 (36 × 1.5).
        suite.expectClose(estimate.heights.first ?? 0, 36 + 6 * 54, "line height and spacing")
        suite.expectClose(estimate.limit, 6 * 54, "the last line reaches the guide")
        suite.expectClose(estimate.pointsPerSecond(wpm: 120), 324.0 / 10.0, "20 words at 120 wpm cover 324 pt in 10 s")
        let wide = PrompterLayout.estimate(paragraph, textSize: 30, lineSpacing: 1.5, width: 600)
        let large = PrompterLayout.estimate(paragraph, textSize: 44, lineSpacing: 1.5, width: 300)
        suite.expect(wide.pointsPerSecond(wpm: 120) < estimate.pointsPerSecond(wpm: 120)
                     && large.pointsPerSecond(wpm: 120) > estimate.pointsPerSecond(wpm: 120),
                     "a wider column scrolls slower, a larger face faster, for the same words")
        let two = PrompterLayout.estimate(PrompterText.paragraphs("one\n\ntwo"), textSize: 20, lineSpacing: 1, width: 300)
        suite.expectClose(two.tops.last ?? 0, 24 + PrompterLayout.paragraphSpacing(textSize: 20), "paragraphs stack with their spacing")
        suite.expect(PrompterLayout.estimatedLines("提词器提词器提词器提词器", textSize: 30, width: 100) == 4,
                     "wide characters take a full em and break anywhere")
    }

    // MARK: Jumps

    private static func jumps(_ suite: TestSuite) {
        let timeline = even
        suite.expectClose(timeline.jumpTarget(from: 0, forward: true), 120, "forward from the start: the next paragraph")
        suite.expectClose(timeline.jumpTarget(from: 130, forward: true), 240, "forward from inside one: the one after")
        suite.expectClose(timeline.jumpTarget(from: 250, forward: true), timeline.limit, "forward from the last: the end")
        suite.expectClose(timeline.jumpTarget(from: 180, forward: false), 120,
                          "back from inside a paragraph: its own start")
        suite.expectClose(timeline.jumpTarget(from: 125, forward: false), 0,
                          "back from just past a start: the paragraph before")
        suite.expectClose(timeline.jumpTarget(from: 120, forward: false), 0, "back from a start: the one before")
        suite.expectClose(timeline.jumpTarget(from: 0, forward: false), 0, "back from the first stays at the start")
        suite.expect(PrompterTimeline.empty.jumpTarget(from: 10, forward: true) == 0, "no paragraphs, nowhere to go")
    }

    // MARK: Time left

    private static func timeLeft(_ suite: TestSuite) {
        let timeline = even // 30 words, limit 300
        suite.expectClose(timeline.duration(wpm: 120), 15, "30 words at 120 wpm read in 15 s")
        suite.expectClose(timeline.timeLeft(offset: 0, wpm: 120), 15, "from the start, the whole duration")
        suite.expectClose(timeline.timeLeft(offset: 150, wpm: 120), 7.5, "halfway, half of it")
        suite.expectClose(timeline.timeLeft(offset: 400, wpm: 120), 0, "past the end, none")
        suite.expectClose(timeline.timeLeft(offset: 150, wpm: 60), 15, "half the speed, twice the time")
        suite.expectClose(timeline.progress(offset: 75), 0.25, "progress is the way to the end")
        suite.expect(PrompterFormat.clock(65) == "1:05" && PrompterFormat.clock(0.2) == "0:01"
                     && PrompterFormat.clock(3723) == "1:02:03" && PrompterFormat.clock(.nan) == "0:00",
                     "clock format rounds up and stays sane")
    }

    private static func translate(_ suite: TestSuite) {
        let larger = PrompterTimeline(tops: [0, 220, 440], heights: [200, 200, 200], words: [10, 10, 10], lineHeight: 70)
        suite.expectClose(even.translate(170, to: larger), 320, "half way through the second paragraph stays half way")
        let other = PrompterTimeline(tops: [0], heights: [500], words: [30], lineHeight: 40)
        suite.expectClose(even.translate(150, to: other), 230, "a different paragraph count keeps the progress")
    }

    // MARK: Clock

    private static func clock(_ suite: TestSuite) {
        var clock = PrompterClock(limit: 300, speed: 20, now: 100)
        suite.expect(clock.offset(at: 105) == 0, "a clock not running holds still")
        clock.setRunning(true, at: 100)
        suite.expectClose(clock.offset(at: 105), 100, "running, it moves at its speed")
        suite.expectClose(clock.offset(at: 105.004), 100.08, "continuously, not in steps")
        clock.setSpeed(40, at: 105)
        suite.expectClose(clock.offset(at: 106), 140, "a new speed takes over from where it was")
        clock.setRunning(false, at: 106)
        suite.expectClose(clock.offset(at: 200), 140, "pausing holds the place")
        clock.setRunning(true, at: 200)
        suite.expectClose(clock.finishTime() ?? 0, 204, "it knows when it will reach the end")
        suite.expect(clock.isFinished(at: 205) && clock.offset(at: 205) == 300, "and stops there")
        clock.jump(to: 100, at: 205, animated: true)
        suite.expect(clock.isGliding(at: 205.1), "an animated jump glides")
        suite.expectClose(clock.offset(at: 205), 300, "the glide starts where the column was")
        suite.expectClose(clock.offset(at: 205 + PrompterClock.glideDuration), 100 + 40 * PrompterClock.glideDuration,
                          "and settles on the target while the text keeps moving")
        var still = PrompterClock(limit: 300, speed: 20, now: 0)
        still.jump(to: 50, at: 1, animated: false)
        suite.expect(still.offset(at: 1) == 50 && !still.isGliding(at: 1), "Reduce Motion jumps at once")
        still.relayout(offset: 80, limit: 60, speed: 5, at: 2)
        suite.expect(still.offset(at: 3) == 60, "a new layout clamps the place to its end")
    }

    // MARK: Voice pace

    private static func voicePace(_ suite: TestSuite) {
        var pace = PrompterVoicePace(now: 0)
        var time = 0.0
        // A quiet room at -70 dBFS, then speech at -24 for a second.
        for _ in 0..<20 { time += 0.05; pace.update(level: -70, at: time) }
        suite.expect(pace.holding == false, "under 1.5 s of quiet after the start never holds")
        for _ in 0..<20 { time += 0.05; pace.update(level: -24, at: time) }
        suite.expect(!pace.holding, "speech keeps it going")
        let lastWord = time
        while time - lastWord < 1.4 { time += 0.05; pace.update(level: -68, at: time) }
        suite.expect(!pace.holding, "a pause shorter than 1.5 s does not hold")
        while time - lastWord < 1.55 { time += 0.05; pace.update(level: -68, at: time) }
        suite.expect(pace.holding, "1.5 s of quiet holds the script")
        time += 0.05
        suite.expect(!pace.update(level: -30, at: time), "the next word lets it go at once")
        // A noisy room: its hum rises the floor, so it does not count as talking.
        var noisy = PrompterVoicePace(now: 0)
        time = 0
        for _ in 0..<400 { time += 0.05; noisy.update(level: -50, at: time) }
        suite.expect(noisy.holding, "a steady hum is quiet, not speech")
        suite.expect(noisy.threshold > -50, "the threshold sits above the room")
        time += 0.05
        suite.expect(!noisy.update(level: -25, at: time), "a voice over the hum still counts")
        // Long speech never lifts the floor into it.
        var talker = PrompterVoicePace(now: 0)
        time = 0
        for _ in 0..<4000 { time += 0.05; talker.update(level: -28, at: time) }
        suite.expect(!talker.holding && (talker.floor ?? 0) <= PrompterVoicePace.loudestFloor,
                     "minutes of talking still count as talking")
        pace.reset(at: 1000)
        suite.expect(!pace.update(level: -90, at: 1001), "a reset gives the full silence again")
        suite.expectClose(Double(PrompterVoicePace.level(rms: 0.1)), -20, "RMS to dBFS")
        suite.expect(PrompterVoicePace.level(rms: 0) == -120 && PrompterVoicePace.level(rms: .nan) == -120,
                     "silence and nonsense read as the floor")
    }

    // MARK: Keys

    private static func keys(_ suite: TestSuite) {
        func key(_ code: UInt16, _ chars: String? = nil, command: Bool = false) -> PrompterKeyAction? {
            PrompterKeys.action(keyCode: code, characters: chars, command: command, control: false, option: false)
        }
        suite.expect(key(49, " ") == .toggle && key(126) == .faster && key(125) == .slower
                     && key(123) == .previous && key(124) == .next && key(53) == .exit,
                     "Space, the arrows and Escape")
        suite.expect(key(24, "=") == .larger && key(24, "+") == .larger && key(27, "-") == .smaller
                     && key(69) == .larger && key(78) == .smaller, "+ and − on the row and the keypad")
        suite.expect(key(40, "k", command: true) == nil && key(49, " ", command: true) == nil,
                     "Command keys stay the island’s")
        suite.expect(key(0, "a") == nil, "other keys pass")
    }

    // MARK: Storage

    private static func storage(_ suite: TestSuite) {
        withDefaults { defaults in
            withContainer { container in
                let store = PrompterStore(container: container, defaults: defaults)
                suite.expect(store.list().isEmpty, "a new Mac has no scripts")
                let first = store.create(name: "  Intro\nvideo  ", text: "Hello", fallbackName: "Untitled")
                let second = store.create(name: "", text: "Second", format: .text, fallbackName: "Untitled")
                suite.expect(first?.name == "Intro video" && second?.name == "Untitled",
                             "names are one trimmed line, never empty")
                suite.expect(store.list().map(\.id) == [first?.id, second?.id].compactMap { $0 }, "new scripts join the end")
                if let first, let second {
                    let url = store.url(for: first)
                    suite.expect(url.lastPathComponent == "\(first.id.uuidString).md"
                                 && store.url(for: second).pathExtension == "txt", "files are named by id and format")
                    let mode = (try? FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int) ?? 0
                    suite.expect(mode == 0o600, "files are owner-only")
                    suite.expect(store.text(of: first) == "Hello", "the text reads back")
                    suite.expect(store.save("Hello again", for: first.id, now: Date(timeIntervalSince1970: 5)),
                                 "saving writes the file")
                    suite.expect(store.text(of: first) == "Hello again"
                                 && store.list().first?.modified == Date(timeIntervalSince1970: 5), "and dates the change")
                    let renamed = store.rename(first.id, to: "Take two", fallbackName: "Untitled")
                    suite.expect(renamed?.name == "Take two" && store.list().first?.name == "Take two"
                                 && store.text(of: first) == "Hello again", "renaming keeps the text and the place")
                    store.delete(first.id)
                    suite.expect(store.list().map(\.id) == [second.id] && !FileManager.default.fileExists(atPath: url.path),
                                 "deleting removes the entry and its file")
                    // A list restored on a Mac without the files: the entry stays, empty.
                    try? FileManager.default.removeItem(at: store.url(for: second))
                    suite.expect(store.list().count == 1 && store.text(of: second).isEmpty, "a missing file reads empty")
                }
                defaults.set("{\"version\":1,\"scripts\":[]} junk", forKey: DefaultsKey.notchPrompterScripts)
                suite.expect(store.list().isEmpty, "a damaged list is no scripts, not a crash")
            }
        }
        let id = UUID()
        let doubled = PrompterLibrary.encode([PrompterScript(id: id, name: "A"), PrompterScript(id: id, name: "B")])
        suite.expect(PrompterLibrary.decode(doubled).map(\.name) == ["A"], "an id listed twice reads once")
        suite.expect(PrompterLibrary.cleanName(String(repeating: "x", count: 200), fallback: "U").count
                     == PrompterLibrary.maximumNameLength, "long names are cut")
    }

    private static func importing(_ suite: TestSuite) {
        withDefaults { defaults in
            withContainer { container in
                let store = PrompterStore(container: container, defaults: defaults)
                let source = container.appending(path: "Source")
                try? FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
                let markdown = source.appending(path: "Studio intro.md")
                try? Data("\u{FEFF}# Hi\n\nWelcome".utf8).write(to: markdown)
                let imported = store.importFile(at: markdown, fallbackName: "Untitled")
                suite.expect(imported?.name == "Studio intro" && imported?.format == .markdown,
                             "a Markdown file is named after itself")
                suite.expect(imported.map { store.text(of: $0) } == "# Hi\n\nWelcome", "its text comes in without the mark")
                let utf16 = source.appending(path: "notes.txt")
                try? "Plain words".data(using: .utf16)?.write(to: utf16)
                suite.expect(store.importFile(at: utf16, fallbackName: "Untitled").map { store.text(of: $0) } == "Plain words",
                             "UTF-16 with its mark reads too")
                let binary = source.appending(path: "photo.txt")
                try? Data([0x89, 0x50, 0x00, 0x47]).write(to: binary)
                suite.expect(store.importFile(at: binary, fallbackName: "Untitled") == nil, "binary is refused")
                let other = source.appending(path: "clip.mov")
                try? Data("x".utf8).write(to: other)
                suite.expect(store.importFile(at: other, fallbackName: "Untitled") == nil, "another kind of file is refused")
                suite.expect(store.importFile(at: source, fallbackName: "Untitled") == nil, "a folder is refused")
                suite.expect(store.list().count == 2, "only what was read joins the list")
            }
        }
    }

    // MARK: Settings

    private static func settings(_ suite: TestSuite) {
        let registered = Defaults.registeredDefaults
        let keys = [DefaultsKey.notchPrompterScripts, DefaultsKey.notchPrompterSpeed, DefaultsKey.notchPrompterTextSize,
                    DefaultsKey.notchPrompterLineSpacing, DefaultsKey.notchPrompterAlignment, DefaultsKey.notchPrompterMirror,
                    DefaultsKey.notchPrompterGuide, DefaultsKey.notchPrompterVoicePaced, DefaultsKey.notchPrompterWidth,
                    DefaultsKey.notchPrompterHeight, DefaultsKey.notchPrompterShortcut]
        let exported = SettingsBackupSupport.exportKeys()
        suite.expect(keys.allSatisfy { registered[$0] != nil && exported.contains($0) },
                     "the prompter’s preferences and its scripts’ list are registered and travel with backups")
        suite.expect(registered[DefaultsKey.notchPrompterLastScript] == nil
                     && !exported.contains(DefaultsKey.notchPrompterLastScript), "the last script chosen stays on this Mac")
        suite.expect(registered[DefaultsKey.notchPrompterVoicePaced] as? Bool == false
                     && registered[DefaultsKey.notchPrompterMirror] as? Bool == false
                     && registered[DefaultsKey.notchPrompterGuide] as? Bool == true
                     && registered[DefaultsKey.notchPrompterShortcut] as? String == "",
                     "voice pace and mirror start off, the guide on, no shortcut")
        withDefaults { defaults in
            suite.expect(PrompterSettings.current(in: defaults) == PrompterSettings(), "defaults when nothing is set")
            defaults.set(999, forKey: DefaultsKey.notchPrompterSpeed)
            defaults.set(5, forKey: DefaultsKey.notchPrompterTextSize)
            defaults.set(9.0, forKey: DefaultsKey.notchPrompterLineSpacing)
            defaults.set("diagonal", forKey: DefaultsKey.notchPrompterAlignment)
            defaults.set(100, forKey: DefaultsKey.notchPrompterWidth)
            defaults.set(5000, forKey: DefaultsKey.notchPrompterHeight)
            let read = PrompterSettings.current(in: defaults)
            suite.expect(read.speed == 260 && read.textSize == 18 && read.lineSpacing == 2 && read.alignment == .center
                         && read.width == 360 && read.height == 640, "out-of-range values are clamped, unknown ones default")
        }
        suite.expect(PrompterSettings.clampedSpeed(143) == 140 && PrompterSettings.clampedSpeed(146) == 150,
                     "speeds land on whole steps")
    }

    private static func island(_ suite: TestSuite) {
        suite.expect(NotchModule.prompter.isAvailable() && NotchModule.prompter.shortcutKey == "x"
                     && NotchModule.prompter.symbol == "scroll",
                     "the Prompter module is always there, on ⌥⌘X")
        let keys = NotchModule.allCases.map(\.shortcutKey)
        suite.expect(Set(keys).count == keys.count, "no two modules share a key")
        let hexes = NotchModule.allCases.map(ZenithIslandPalette.hex)
        suite.expect(Set(hexes).count == hexes.count, "no two modules share a colour")
        let symbols = NotchModule.allCases.map(\.symbol)
        suite.expect(Set(symbols).count == symbols.count, "no two modules share a glyph")

        // The reading panel takes its own width and height on every layout.
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        var geometry = NotchGeometry(screen: screen, safeAreaTop: 32, cameraWidth: 185, layout: .custom,
                                     customWidth: 600, customHeight: 200)
        let resting = geometry.expandedSize(module: .prompter)
        var settings = PrompterSettings()
        settings.width = 400
        settings.height = 480
        geometry.zenithPrompter = ZenithPrompterIslandGeometry(settings: settings)
        geometry.pageTop = .none
        let prompting = geometry.expandedSize(module: .prompter)
        suite.expect(prompting.width == 400 + NotchLayout.openGrowth * 2, "the panel is as wide as chosen, past a custom width")
        suite.expect(prompting.height > resting.height && prompting.height > 480
                     && geometry.contentSize(for: prompting).height == 480,
                     "and as tall, past a custom height, its reading area exactly the chosen height")
        settings.height = 5000
        geometry.zenithPrompter = ZenithPrompterIslandGeometry(settings: PrompterSettings())
        geometry.zenithPrompter?.contentHeight = 5000
        suite.expect(geometry.expandedSize(module: .prompter).height <= screen.height - 48,
                     "never taller than the display allows")
    }

    private static func strings(_ suite: TestSuite) {
        for language in AppLanguage.allCases {
            let text = ZenithStrings.prompter(language)
            let all = Mirror(reflecting: text).children.compactMap { $0.value as? String }
            suite.expect(all.count == 47 && all.allSatisfy { !$0.isEmpty }, "\(language.rawValue): every prompter string is there")
            suite.expect(all.allSatisfy { !$0.contains("'") && !$0.contains("\u{2014}") },
                         "\(language.rawValue): curly apostrophes and no em dashes")
            suite.expect(text.leftFormat.contains("%@") && text.deleteTitle.contains("%@"),
                         "\(language.rawValue): formats keep their placeholder")
        }
    }
}
