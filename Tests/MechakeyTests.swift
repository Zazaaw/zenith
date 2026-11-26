// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AVFoundation
import Foundation

/// Zenith fork: Mechakey. Mechvibes' V2 config reads as Mechvibes reads it;
/// macOS key codes reach their own Mechvibes keys, and keys a pack lacks its
/// fallback; a slice's frames stay inside its file; modifiers, key repeat
/// and key-up sounds decide what plays; the bundled packs load and fit their
/// audio; and the page is found, backed up and credited.
enum MechakeyTests {
    static func run(_ suite: TestSuite) {
        config(suite)
        slices(suite)
        keyMap(suite)
        table(suite)
        modifiers(suite)
        decisions(suite)
        preferences(suite)
        preview(suite)
        bundledPacks(suite)
        settings(suite)
    }

    private static func parse(_ json: String) -> Result<MechakeyPackConfig, MechakeyPackConfig.Problem> {
        do { return .success(try MechakeyPackConfig(data: Data(json.utf8))) } catch let problem as MechakeyPackConfig.Problem {
            return .failure(problem)
        } catch {
            return .failure(.notJSON)
        }
    }

    private static let sample = """
    {"config_version": "2", "name": "Sample", "author": "Someone", "definition_method": "single",
     "audio_file": "sound.ogg", "options": {"recommended_volume": 0.8},
     "definitions": {
       "KeyA": {"timing": [[100, 150], [150, 200]]},
       "Space": {"timing": [[1000.5, 1100.25], [1100.25, 1200]]},
       "Enter": {"timing": [[2000, 2080]]},
       "KeyB": {"timing": [[100, 150], [150, 200]]},
       "Tab": {"timing": [[1, 2], [2, 3], [3, 4]]},
       "Escape": {"timing": [[10, 5]]},
       "Comma": {"timing": [[10]]},
       "Period": [[10, 20]]
     }}
    """

    private static func config(_ suite: TestSuite) {
        guard case .success(let config) = parse(sample) else {
            suite.expect(false, "the sample V2 config parses")
            return
        }
        suite.expect(config.name == "Sample" && config.author == "Someone" && config.audioFile == "sound.ogg",
                     "name, author and audio file")
        suite.expect(config.recommendedVolume == 0.8, "the pack's recommended volume")
        suite.expect(config.keys["KeyA"] == MechakeyKeySound(press: MechakeySlice(start: 100, end: 150),
                                                             release: MechakeySlice(start: 150, end: 200)),
                     "two pairs: the press, then the release")
        suite.expect(config.keys["Space"]?.press == MechakeySlice(start: 1000.5, end: 1100.25),
                     "fractional milliseconds")
        suite.expect(config.keys["Enter"]?.release == nil && config.keys["Enter"]?.press.end == 2080,
                     "one pair: a press and a silent release")
        suite.expect(config.keys["Tab"] == nil, "three pairs play nothing, as in Mechvibes")
        suite.expect(config.keys["Escape"] == nil && config.keys["Comma"] == nil && config.keys["Period"] == nil,
                     "a backwards pair, a pair of one number and a bare array are dropped")
        suite.expect(config.keys.count == 4, "the four valid keys: \(config.keys.keys.sorted())")

        let legacy = parse("""
        {"name": "Old", "m_author": "Someone", "config_version": 2, "audio_file": "a.wav",
         "defs": {"KeyA": {"timing": [[0, 10]]}}}
        """)
        if case .success(let old) = legacy {
            suite.expect(old.author == "Someone" && old.keys.count == 1 && old.recommendedVolume == 1,
                         "`m_author`, `defs`, a numeric version and no options")
        } else {
            suite.expect(false, "`m_author` and `defs` are accepted: \(legacy)")
        }
        let base = #""author": "A", "audio_file": "a.ogg", "definitions": {"KeyA": {"timing": [[0, 10]]}}"#
        let cases: [(String, MechakeyPackConfig.Problem)] = [
            ("not json", .notJSON),
            ("{\(base)}", .missing("name")),
            (#"{"name": "N", "audio_file": "a.ogg", "definitions": {"KeyA": {"timing": [[0, 10]]}}}"#, .missing("author")),
            (#"{"name": "N", "config_version": "3", \#(base)}"#, .newerVersion),
            (#"{"name": "N", "definition_method": "multi", \#(base)}"#, .multiFile),
            (#"{"name": "N", "author": "A", "definitions": {"KeyA": {"timing": [[0, 10]]}}}"#, .missing("audio_file")),
            (#"{"name": "N", "author": "A", "audio_file": "a.ogg"}"#, .missing("definitions")),
            (#"{"name": "N", "author": "A", "audio_file": "a.ogg", "definitions": {"KeyA": {"timing": [[1, 2], [2, 3], [3, 4]]}}}"#,
             .noKeys),
        ]
        for (json, problem) in cases {
            let result = parse(json)
            if case .failure(let found) = result {
                suite.expect(found == problem, "\(json) is refused as \(problem), not \(found)")
            } else {
                suite.expect(false, "\(json) is refused as \(problem)")
            }
        }
    }

    private static func slices(_ suite: TestSuite) {
        let slice = MechakeySlice(start: 100, end: 150)
        suite.expect(slice.frames(sampleRate: 48_000, totalFrames: 100_000) == 4_800..<7_200, "48 kHz")
        suite.expect(slice.frames(sampleRate: 44_100, totalFrames: 100_000) == 4_410..<6_615, "44.1 kHz")
        suite.expect(MechakeySlice(start: 0.01, end: 0.03).frames(sampleRate: 44_100, totalFrames: 10) == 0..<1,
                     "fractions of a millisecond round to the nearest frame")
        suite.expect(slice.frames(sampleRate: 48_000, totalFrames: 6_000) == 4_800..<6_000,
                     "a slice past the end of the file is cut at the end")
        suite.expect(slice.frames(sampleRate: 48_000, totalFrames: 4_000) == nil, "a slice wholly past the end plays nothing")
        suite.expect(MechakeySlice(start: 10, end: 10.001).frames(sampleRate: 48_000, totalFrames: 100_000) == nil,
                     "a slice shorter than a frame plays nothing")
        suite.expect(slice.frames(sampleRate: 0, totalFrames: 100) == nil
                     && MechakeySlice(start: .nan, end: 10).frames(sampleRate: 48_000, totalFrames: 100) == nil,
                     "no rate or a broken number plays nothing")
    }

    private static func keyMap(_ suite: TestSuite) {
        let names = MechakeyKeyMap.codes
        let expected: [UInt16: String] = [0: "KeyA", 12: "KeyQ", 46: "KeyM", 29: "Digit0", 18: "Digit1", 49: "Space",
                                          36: "Enter", 51: "Backspace", 117: "Delete", 48: "Tab", 53: "Escape",
                                          56: "ShiftLeft", 60: "ShiftRight", 59: "ControlLeft", 62: "ControlRight",
                                          58: "AltLeft", 61: "AltRight", 55: "MetaLeft", 54: "MetaRight",
                                          57: "CapsLock", 123: "ArrowLeft", 126: "ArrowUp", 122: "F1", 111: "F12",
                                          82: "Numpad0", 92: "Numpad9", 76: "NumpadEnter", 50: "Backquote",
                                          10: "Backquote", 114: "Insert", 105: "PrintScreen"]
        for (code, name) in expected {
            suite.expect(names[code] == name, "key code \(code) is \(name), not \(names[code] ?? "nothing")")
        }
        let letters = Set(names.values.filter { $0.hasPrefix("Key") })
        suite.expect(letters.count == 26, "all 26 letters: \(letters.count)")
        suite.expect(Set(names.values.filter { $0.hasPrefix("Digit") }).count == 10, "all ten digits")
        suite.expect(Set(names.values.filter { $0.hasPrefix("Numpad") && $0.dropFirst(6).allSatisfy(\.isNumber) }).count == 10,
                     "all ten keypad digits")
        var seen: [String: UInt16] = [:]
        for (code, name) in names.sorted(by: { $0.key < $1.key }) where name != "Backquote" {
            suite.expect(seen[name] == nil, "\(name) has one key code, not \(seen[name] ?? 0) and \(code)")
            seen[name] = code
        }
        suite.expect(names.keys.allSatisfy { Int($0) < MechakeySoundTable.keyCodeCount }, "every code fits the table")
        suite.expect(names[63] == nil && names[90] == nil, "fn and F20 have no Mechvibes key, so they play the fallback")
    }

    private static func table(_ suite: TestSuite) {
        guard case .success(let config) = parse(sample) else { return }
        let table = MechakeySoundTable(config: config, sampleRate: 48_000, totalFrames: 200_000)
        // KeyA and KeyB share their slices; Space has two; Enter one.
        suite.expect(table.slices.count == 5, "identical slices are kept once: \(table.slices)")
        let a = table.press(0), b = table.press(11)
        suite.expect(a != nil && a == b, "KeyA and KeyB play the same press")
        suite.expect(table.press(49) != a && table.release(49) != table.release(0), "Space has a sound of its own")
        suite.expect(table.press(49).map { table.slices[$0] } == 48_024..<52_812, "Space's press frames")
        suite.expect(table.press(36) != nil && table.release(36) == nil, "Enter has a press and a silent release")
        for code: UInt16 in [63, 90, 48, 53, 127, 200, 0xFFFF] {
            suite.expect(table.press(code) == a && table.release(code) == table.release(0),
                         "key code \(code) plays KeyA, the fallback")
        }

        let noA = parse(#"{"name": "N", "author": "A", "audio_file": "a.ogg", "definitions": {"Space": {"timing": [[0, 10]]}, "Enter": {"timing": [[20, 30]]}}}"#)
        if case .success(let config) = noA {
            let table = MechakeySoundTable(config: config, sampleRate: 1_000, totalFrames: 100)
            suite.expect(table.press(0) == table.press(36) && table.press(36) != table.press(49),
                         "without KeyA, the first key by name is the fallback")
        }
        let short = MechakeySoundTable(config: config, sampleRate: 48_000, totalFrames: 60_000)
        suite.expect(short.press(36) == nil && short.press(0) != nil,
                     "a slice wholly past the end of the file plays nothing")
    }

    private static func modifiers(_ suite: TestSuite) {
        let leftShift: UInt64 = 0x0002_0002, rightShift: UInt64 = 0x0002_0004, both: UInt64 = 0x0002_0006
        suite.expect(MechakeyModifiers.isDown(keyCode: 56, flags: leftShift) == true, "left Shift down")
        suite.expect(MechakeyModifiers.isDown(keyCode: 56, flags: 0x100) == false, "left Shift up, nothing else held")
        suite.expect(MechakeyModifiers.isDown(keyCode: 60, flags: both) == true, "right Shift down beside the left")
        suite.expect(MechakeyModifiers.isDown(keyCode: 56, flags: rightShift) == false,
                     "the left Shift comes up while the right is held")
        suite.expect(MechakeyModifiers.isDown(keyCode: 62, flags: 0x0004_2000) == true, "right Control")
        suite.expect(MechakeyModifiers.isDown(keyCode: 54, flags: 0x0010_0010) == true
                     && MechakeyModifiers.isDown(keyCode: 55, flags: 0x0010_0010) == false, "right Command, not left")
        suite.expect(MechakeyModifiers.isDown(keyCode: 58, flags: 0x0008_0000) == true,
                     "an event without device bits falls back to the side-less flag")
        suite.expect(MechakeyModifiers.isDown(keyCode: 63, flags: 0x0080_0000) == true
                     && MechakeyModifiers.isDown(keyCode: 63, flags: 0) == false, "fn")
        suite.expect(MechakeyModifiers.isDown(keyCode: 57, flags: 0) == true
                     && MechakeyModifiers.isDown(keyCode: 57, flags: 0x0001_0000) == true, "every Caps Lock change is a press")
        suite.expect(MechakeyModifiers.isDown(keyCode: 0, flags: leftShift) == nil, "A is no modifier")
    }

    private static func decisions(_ suite: TestSuite) {
        guard case .success(let config) = parse(sample) else { return }
        let table = MechakeySoundTable(config: config, sampleRate: 48_000, totalFrames: 200_000)
        func play(_ event: MechakeyKeyEvent, _ code: UInt16, up: Bool = true, ignore: Bool = true) -> Int? {
            MechakeyEventDecision.slice(for: event, keyCode: code, keyUpSounds: up, ignoreRepeat: ignore, table: table)
        }
        suite.expect(play(.down(isRepeat: false), 49) == table.press(49), "a press plays the press")
        suite.expect(play(.down(isRepeat: true), 49) == nil, "a held key's repeat is silent by default")
        suite.expect(play(.down(isRepeat: true), 49, ignore: false) == table.press(49), "or sounds when asked")
        suite.expect(play(.up, 49) == table.release(49) && play(.up, 49, up: false) == nil,
                     "a release plays the release, unless key-up sounds are off")
        suite.expect(play(.flagsChanged(flags: 0x0002_0002), 56) == table.press(56), "Shift down sounds as a press")
        suite.expect(play(.flagsChanged(flags: 0x100), 56) == table.release(56)
                     && play(.flagsChanged(flags: 0x100), 56, up: false) == nil, "Shift up sounds as a release")
        suite.expect(play(.flagsChanged(flags: 0x0002_0002), 0) == nil, "a flag change of no modifier is silent")
    }

    private static func preferences(_ suite: TestSuite) {
        let domain = "com.vorssaint.tests.mechakey"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.removePersistentDomain(forName: domain)
        var preferences = MechakeyPreferences(defaults: defaults)
        suite.expect(!preferences.enabled, "off by default")
        suite.expect(preferences.pack.id == MechakeyPack.defaultID && preferences.volume == 0.5
                     && preferences.keyUpSounds && preferences.ignoreRepeat && preferences.shortcut.isEmpty,
                     "Cherry MX Blue at half volume, key-up sounds on, repeats ignored, no shortcut")
        defaults.set("gone-pack", forKey: MechakeyDefaults.pack)
        defaults.set(3.0, forKey: MechakeyDefaults.volume)
        preferences = MechakeyPreferences(defaults: defaults)
        suite.expect(preferences.pack.id == MechakeyPack.defaultID, "an unknown pack falls back to the default")
        suite.expect(preferences.volume == 1, "the volume stays within 0...1")
        defaults.set("eg-oreo", forKey: MechakeyDefaults.pack)
        defaults.set(-1.0, forKey: MechakeyDefaults.volume)
        defaults.set(false, forKey: MechakeyDefaults.keyUpSounds)
        preferences = MechakeyPreferences(defaults: defaults)
        suite.expect(preferences.playback == MechakeyPlayback(packID: "eg-oreo", volume: 0, keyUpSounds: false,
                                                              ignoreRepeat: true), "the playback follows: \(preferences.playback)")
        suite.expect(Set(MechakeyPack.all.map(\.id)).count == MechakeyPack.all.count
                     && MechakeyPack.all.contains { $0.id == MechakeyPack.defaultID }, "pack ids are unique, the default among them")
    }

    private static func preview(_ suite: TestSuite) {
        let hits = MechakeyPreview.hits(keyUpSounds: true)
        suite.expect(hits.count == 12 && MechakeyPreview.hits(keyUpSounds: false).count == 6,
                     "six keys, each down and up, or down only")
        suite.expect(zip(hits, hits.dropFirst()).allSatisfy { $0.offset < $1.offset } && hits.first?.offset == 0,
                     "the hits run forward from the start")
        suite.expect(MechakeyPreview.length(of: hits, sampleRate: 1_000, longestSlice: 50) == 820,
                     "the last release at 770 ms and the longest slice after it")
    }

    private static var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func bundledPacks(_ suite: TestSuite) {
        let folder = root.appendingPathComponent("Resources/Mechakey")
        var bytes = 0
        let tool = (try? String(contentsOf: root.appendingPathComponent("Tools/zenith-mechakey-packs.py"), encoding: .utf8)) ?? ""
        let notice = (try? String(contentsOf: folder.appendingPathComponent("NOTICE.txt"), encoding: .utf8)) ?? ""
        suite.expect(notice.contains("MIT License") && notice.contains("Hải Nguyễn"), "the notice carries Mechvibes' licence")
        let reachable = Set(MechakeyKeyMap.codes.values)
        for pack in MechakeyPack.all {
            let dir = folder.appendingPathComponent(pack.id)
            suite.expect(tool.contains("(\"\(pack.source)\", \"\(pack.id)\", \"\(pack.title)\")"),
                         "\(pack.id) is one the tool writes, from \(pack.source)")
            suite.expect(notice.contains(pack.source), "the notice names \(pack.source)")
            guard let data = try? Data(contentsOf: dir.appendingPathComponent("config.json")),
                  let config = try? MechakeyPackConfig(data: data) else {
                suite.expect(false, "\(pack.id)'s config parses")
                continue
            }
            suite.expect(config.author == "Mechvibes" && config.name == pack.title, "\(pack.id)'s name and author")
            suite.expect(config.keys.count == 104 && config.keys.values.allSatisfy { $0.release != nil },
                         "\(pack.id): 104 keys, each with a press and a release")
            let unreachable = Set(config.keys.keys).subtracting(reachable)
            suite.expect(unreachable.isEmpty, "every key of \(pack.id) has a Mac key code: \(unreachable.sorted())")
            let audio = dir.appendingPathComponent(config.audioFile)
            bytes += ((try? FileManager.default.attributesOfItem(atPath: audio.path)[.size]) as? Int) ?? 0
            guard let file = try? AVAudioFile(forReading: audio) else {
                suite.expect(false, "\(pack.id)'s audio opens")
                continue
            }
            let rate = file.processingFormat.sampleRate, total = Int(file.length)
            let duration = Double(total) / rate * 1000
            let latest = config.keys.values.flatMap { [$0.press, $0.release].compactMap { $0 } }.map(\.end).max() ?? 0
            suite.expect(latest <= duration, "\(pack.id)'s slices end by \(latest) ms, inside its \(duration) ms of audio")
            let table = MechakeySoundTable(config: config, sampleRate: rate, totalFrames: total)
            let presses = Set([49, 36, 51, 56, 0].compactMap { table.press($0) })
            suite.expect(presses.count == 5, "\(pack.id): Space, Return, Delete, Shift and A sound different")
        }
        suite.expect(bytes > 0 && bytes < 6_000_000, "the packs' audio stays under 6 MB: \(bytes) bytes")
    }

    private static func settings(_ suite: TestSuite) {
        let text = ZenithStrings.mechakey(.de)
        suite.expect(text.all.count > 25 && text.all.allSatisfy { !$0.isEmpty }, "every Mechakey string has text")
        suite.expect(text.title == "Mechakey", "the page is called Mechakey")
        suite.expect(MechakeyPack.all.filter { $0.id.hasPrefix("cherry") }.allSatisfy { text.caption(for: $0) != nil },
                     "each Cherry switch says how it feels")
        let aliases = ZenithSettingsSearch.pageAliases[.page(.mechakey)] ?? []
        suite.expect(["keyboard sounds", "mechanical", "typing sound", "mechvibes", "suara keyboard"].allSatisfy(aliases.contains),
                     "the page's English and Indonesian aliases")
        suite.expect(FeatureVisibilitySupport.features(for: .mechakey).isEmpty,
                     "Mechakey is a page of the app's own, which no hub feature hides")
        suite.expect(SettingsSectionAnchor.zenithMechakey.page == .mechakey, "its anchor lands on its page")
        suite.expect(MechakeyDefaults.all.isSubset(of: SettingsBackupSupport.exportKeys())
                     && MechakeyDefaults.all.isDisjoint(with: SettingsBackupSupport.machineStateKeys),
                     "every Mechakey preference joins the settings backup")
        suite.expect(MechakeyDefaults.all.count == 6 && MechakeyDefaults.all.allSatisfy { $0.hasPrefix("zenithMechakey") },
                     "six keys in Mechakey's own namespace")

        let domain = "com.vorssaint.tests.mechakey-search"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let state = SettingsSearchState(defaults: defaults, hardware: .init(
            battery: true, notchedDisplay: true, plainDisplay: false,
            keyboardLight: true, bluetoothSleep: true, brightnessOSD: true))
        let all: (AppFeature) -> Bool = { _ in true }
        func routes(_ query: String) -> [FeatureSettingsDestination] {
            let items = SettingsDirectory.searchItems(Strings.localized(.enUS), language: .enUS, state: state)
            return SettingsSearchSupport.groupedMatchingItems(query: query, items: items, isAvailable: all)
                .flatMap { ($0.parentMatches ? [$0.parentSuggestion] : []) + $0.suggestions }
                .prefix(ForkSettingsSearchTests.top)
                .map { SettingsSearchSupport.route(for: $0, isAvailable: all).destination }
        }
        for query in ["mechakey", "keyboard sounds", "mechvibes", "typing sound", "suara keyboard", "suara ketik",
                      "key-up sounds", "ignore key repeat"] {
            let found = routes(query)
            suite.expect(found.contains { $0.page == .mechakey },
                         "searching \"\(query)\" offers Mechakey among the first \(ForkSettingsSearchTests.top): \(found)")
        }
    }
}
