// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Mechakey plays the keyboard sound packs of Mechvibes by Hải Nguyễn (MIT),
// https://github.com/hainguyents13/mechvibes — see the notice in About.

import Foundation

// Zenith fork: Mechakey's decisions, without audio or event taps, so the
// tests reach every one: the preferences, the bundled packs, Mechvibes' V2
// config, the macOS key code to Mechvibes key name map, a slice's frames and
// which slice a key event plays.

/// Mechakey's preferences. Kept here, not in `DefaultsKey`, so the feature's
/// files never edit a shared registry.
enum MechakeyDefaults {
    static let enabled = "zenithMechakeyEnabled"           // Bool, default false
    static let pack = "zenithMechakeyPack"                 // MechakeyPack.id, default MechakeyPack.defaultID
    static let volume = "zenithMechakeyVolume"             // Double 0...1, default 0.5
    static let keyUpSounds = "zenithMechakeyKeyUpSounds"   // Bool, default true (Mechvibes plays the release)
    static let ignoreRepeat = "zenithMechakeyIgnoreRepeat" // Bool, default true
    static let shortcut = "zenithMechakeyShortcut"         // GlobalShortcut.storageValue, "" for none

    /// Every key, for the settings backup.
    static let all: Set<String> = [enabled, pack, volume, keyUpSounds, ignoreRepeat, shortcut]
    static let defaultVolume = 0.5
}

/// A bundled pack: its folder under `Resources/Mechakey` and the name
/// Settings shows. The folders are written by Tools/zenith-mechakey-packs.py.
struct MechakeyPack: Identifiable, Equatable {
    let id: String
    let title: String
    /// The pack's folder in Mechvibes' `soundpacks/keyboard`.
    let source: String

    static let all: [MechakeyPack] = [
        MechakeyPack(id: "cherry-mx-blue", title: "Cherry MX Blue", source: "cherrymx-blue-abs"),
        MechakeyPack(id: "cherry-mx-brown", title: "Cherry MX Brown", source: "cherrymx-brown-abs"),
        MechakeyPack(id: "cherry-mx-red", title: "Cherry MX Red", source: "cherrymx-red-abs"),
        MechakeyPack(id: "cherry-mx-black", title: "Cherry MX Black", source: "cherrymx-black-abs"),
        MechakeyPack(id: "topre-purple", title: "Topre Purple Hybrid", source: "topre-purple-hybrid-pbt"),
        MechakeyPack(id: "eg-oreo", title: "EG Oreo", source: "eg-oreo"),
        MechakeyPack(id: "eg-crystal-purple", title: "EG Crystal Purple", source: "eg-crystal-purple"),
    ]
    static let defaultID = "cherry-mx-blue"
    /// The folder every pack sits in, inside the app's Resources.
    static let resourceFolder = "Mechakey"

    /// The pack for a stored id, or the default for anything else.
    static func named(_ id: String?) -> MechakeyPack {
        all.first { $0.id == id } ?? all.first { $0.id == defaultID }!
    }
}

/// What the player runs with while Mechakey is on.
struct MechakeyPlayback: Equatable {
    var packID: String
    var volume: Float
    var keyUpSounds: Bool
    var ignoreRepeat: Bool
}

/// Mechakey's preferences, read in one place.
struct MechakeyPreferences: Equatable {
    var enabled: Bool
    var pack: MechakeyPack
    var volume: Double
    var keyUpSounds: Bool
    var ignoreRepeat: Bool
    var shortcut: String

    init(defaults: UserDefaults) {
        enabled = defaults.object(forKey: MechakeyDefaults.enabled) as? Bool ?? false
        pack = MechakeyPack.named(defaults.string(forKey: MechakeyDefaults.pack))
        let volume = defaults.object(forKey: MechakeyDefaults.volume) as? Double ?? MechakeyDefaults.defaultVolume
        self.volume = volume.isFinite ? min(1, max(0, volume)) : MechakeyDefaults.defaultVolume
        keyUpSounds = defaults.object(forKey: MechakeyDefaults.keyUpSounds) as? Bool ?? true
        ignoreRepeat = defaults.object(forKey: MechakeyDefaults.ignoreRepeat) as? Bool ?? true
        shortcut = defaults.string(forKey: MechakeyDefaults.shortcut) ?? ""
    }

    var playback: MechakeyPlayback {
        MechakeyPlayback(packID: pack.id, volume: Float(volume), keyUpSounds: keyUpSounds, ignoreRepeat: ignoreRepeat)
    }
}

// MARK: - Config

/// One `[start_ms, end_ms]` pair of a pack's audio file.
struct MechakeySlice: Equatable {
    let start: Double
    let end: Double

    /// The frames it covers in a file of `totalFrames` at `sampleRate`,
    /// clamped to the file (Mechvibes cuts a slice at the end of the file);
    /// nil when nothing of it is left.
    func frames(sampleRate: Double, totalFrames: Int) -> Range<Int>? {
        guard sampleRate > 0, totalFrames > 0, start.isFinite, end.isFinite else { return nil }
        func frame(_ ms: Double) -> Int { Int(min(Double(totalFrames), max(0, (ms * sampleRate / 1000).rounded()))) }
        let lower = frame(start), upper = frame(end)
        return upper > lower ? lower..<upper : nil
    }
}

/// A key's sounds: the press, and the release when the pack has one.
struct MechakeyKeySound: Equatable {
    let press: MechakeySlice
    let release: MechakeySlice?
}

/// A Mechvibes V2 `config.json` (docs/soundpack-config-v2.md in Mechvibes):
/// `name`, `author` (or `m_author`) and `definitions` (or `defs`) are
/// required; every key maps to `{"timing": [[start, end]]}` with one pair
/// (the press) or two (press, then release). A key with any other count
/// plays nothing, as in Mechvibes. Only `single` packs, every key a slice
/// of one `audio_file`, are read.
struct MechakeyPackConfig: Equatable {
    enum Problem: Error, Equatable {
        case notJSON, missing(String), newerVersion, multiFile, noKeys
    }

    let name: String
    let author: String
    let audioFile: String
    let recommendedVolume: Double
    let keys: [String: MechakeyKeySound]

    init(data: Data) throws {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { throw Problem.notJSON }
        guard let name = root["name"] as? String, !name.isEmpty else { throw Problem.missing("name") }
        guard let author = (root["author"] ?? root["m_author"]) as? String, !author.isEmpty else {
            throw Problem.missing("author")
        }
        let version = root["config_version"].flatMap { value -> Double? in
            if let text = value as? String { return Double(text) }
            return (value as? NSNumber)?.doubleValue
        }
        if let version, version > 2 { throw Problem.newerVersion }
        if let method = root["definition_method"] as? String, method != "single" { throw Problem.multiFile }
        guard let audioFile = root["audio_file"] as? String, !audioFile.isEmpty else { throw Problem.missing("audio_file") }
        guard let definitions = (root["definitions"] ?? root["defs"]) as? [String: Any] else {
            throw Problem.missing("definitions")
        }
        var keys: [String: MechakeyKeySound] = [:]
        for (key, value) in definitions {
            guard let timing = (value as? [String: Any])?["timing"] as? [Any] else { continue }
            let pairs = timing.compactMap { pair -> MechakeySlice? in
                guard let numbers = pair as? [Any], numbers.count == 2,
                      let start = (numbers[0] as? NSNumber)?.doubleValue,
                      let end = (numbers[1] as? NSNumber)?.doubleValue, end > start else { return nil }
                return MechakeySlice(start: start, end: end)
            }
            guard pairs.count == timing.count, (1...2).contains(pairs.count) else { continue }
            keys[key] = MechakeyKeySound(press: pairs[0], release: pairs.count == 2 ? pairs[1] : nil)
        }
        guard !keys.isEmpty else { throw Problem.noKeys }
        self.name = name
        self.author = author
        self.audioFile = audioFile
        let options = root["options"] as? [String: Any]
        let recommended = (options?["recommended_volume"] as? NSNumber)?.doubleValue ?? 1
        recommendedVolume = recommended.isFinite ? min(2, max(0, recommended)) : 1
        self.keys = keys
    }
}

// MARK: - Keys

/// macOS virtual key codes (Carbon's `kVK_*`, US ANSI positions) to the
/// W3C `KeyboardEvent.code` names Mechvibes packs use. A key a pack does not
/// define plays the pack's fallback slice instead.
enum MechakeyKeyMap {
    static let codes: [UInt16: String] = {
        var map: [UInt16: String] = [
            0: "KeyA", 1: "KeyS", 2: "KeyD", 3: "KeyF", 4: "KeyH", 5: "KeyG", 6: "KeyZ", 7: "KeyX",
            8: "KeyC", 9: "KeyV", 11: "KeyB", 12: "KeyQ", 13: "KeyW", 14: "KeyE", 15: "KeyR",
            16: "KeyY", 17: "KeyT", 31: "KeyO", 32: "KeyU", 34: "KeyI", 35: "KeyP", 37: "KeyL",
            38: "KeyJ", 40: "KeyK", 45: "KeyN", 46: "KeyM",
            18: "Digit1", 19: "Digit2", 20: "Digit3", 21: "Digit4", 22: "Digit6", 23: "Digit5",
            25: "Digit9", 26: "Digit7", 28: "Digit8", 29: "Digit0",
            24: "Equal", 27: "Minus", 30: "BracketRight", 33: "BracketLeft", 39: "Quote",
            41: "Semicolon", 42: "Backslash", 43: "Comma", 44: "Slash", 47: "Period", 50: "Backquote",
            // ISO's extra key beside the left Shift sits where ANSI's Backquote is played.
            10: "Backquote",
            36: "Enter", 48: "Tab", 49: "Space", 51: "Backspace", 53: "Escape", 117: "Delete",
            55: "MetaLeft", 54: "MetaRight", 56: "ShiftLeft", 60: "ShiftRight", 57: "CapsLock",
            58: "AltLeft", 61: "AltRight", 59: "ControlLeft", 62: "ControlRight",
            110: "ContextMenu",
            123: "ArrowLeft", 124: "ArrowRight", 125: "ArrowDown", 126: "ArrowUp",
            115: "Home", 119: "End", 116: "PageUp", 121: "PageDown",
            // Apple's extended keyboard: Help where Insert is, F13-F15 where
            // Print Screen, Scroll Lock and Pause are, Clear where Num Lock is.
            114: "Insert", 105: "PrintScreen", 107: "ScrollLock", 113: "Pause", 71: "NumLock",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
            101: "F9", 109: "F10", 103: "F11", 111: "F12",
            65: "NumpadDecimal", 67: "NumpadMultiply", 69: "NumpadAdd", 75: "NumpadDivide",
            76: "NumpadEnter", 78: "NumpadSubtract",
        ]
        for (index, code) in [82, 83, 84, 85, 86, 87, 88, 89, 91, 92].enumerated() {
            map[UInt16(code)] = "Numpad\(index)"
        }
        return map
    }()

    /// The key whose sound plays for keys a pack does not define.
    static let fallback = "KeyA"

    static func name(for keyCode: UInt16) -> String? { codes[keyCode] }
}

/// The modifier keys arrive as flag changes, not key downs and ups: the
/// event's flags say whether the key went down. Each side has its own
/// device bit (IOKit's `NX_DEVICE*KEYMASK`); an event without any of them,
/// such as a synthetic one, falls back to the side-less flag.
enum MechakeyModifiers {
    private static let deviceBits: UInt64 = 0x207F
    /// Key code to (its side's device bit, the side-less flag).
    private static let masks: [UInt16: (device: UInt64, flag: UInt64)] = [
        56: (0x0002, 0x0002_0000), 60: (0x0004, 0x0002_0000), // Shift
        59: (0x0001, 0x0004_0000), 62: (0x2000, 0x0004_0000), // Control
        58: (0x0020, 0x0008_0000), 61: (0x0040, 0x0008_0000), // Option
        55: (0x0008, 0x0010_0000), 54: (0x0010, 0x0010_0000), // Command
        63: (0, 0x0080_0000),                                   // fn
    ]
    private static let capsLock: UInt16 = 57

    /// Whether a flag change went down (true) or up (false); nil for a key
    /// that is no modifier. Caps Lock reports a change only as it toggles,
    /// so each one counts as a press.
    static func isDown(keyCode: UInt16, flags: UInt64) -> Bool? {
        if keyCode == capsLock { return true }
        guard let mask = masks[keyCode] else { return nil }
        if mask.device != 0, flags & deviceBits != 0 { return flags & mask.device != 0 }
        return flags & mask.flag != 0
    }
}

// MARK: - Sound table

/// A pack ready to play: every distinct slice as frames of its audio file,
/// and for each key code the slice its press and release play, in two flat
/// tables indexed by key code, so a key event reads two arrays and nothing
/// else.
struct MechakeySoundTable: Equatable {
    static let keyCodeCount = 128

    /// Frames of the pack's audio, one entry per distinct slice.
    let slices: [Range<Int>]
    private let presses: [Int16]
    private let releases: [Int16]
    private let fallbackPress: Int16
    private let fallbackRelease: Int16

    init(config: MechakeyPackConfig, sampleRate: Double, totalFrames: Int) {
        var slices: [Range<Int>] = []
        var indices: [Range<Int>: Int16] = [:]
        func index(_ slice: MechakeySlice?) -> Int16 {
            guard let slice, let frames = slice.frames(sampleRate: sampleRate, totalFrames: totalFrames) else { return -1 }
            if let known = indices[frames] { return known }
            let new = Int16(slices.count)
            slices.append(frames)
            indices[frames] = new
            return new
        }
        let fallbackName = config.keys[MechakeyKeyMap.fallback] != nil
            ? MechakeyKeyMap.fallback : config.keys.keys.sorted().first
        let fallback = fallbackName.flatMap { config.keys[$0] }
        let fallbackPress = index(fallback?.press), fallbackRelease = index(fallback?.release)
        var presses = [Int16](repeating: fallbackPress, count: Self.keyCodeCount)
        var releases = [Int16](repeating: fallbackRelease, count: Self.keyCodeCount)
        for code in 0..<Self.keyCodeCount {
            guard let name = MechakeyKeyMap.name(for: UInt16(code)), let sound = config.keys[name] else { continue }
            presses[code] = index(sound.press)
            releases[code] = index(sound.release)
        }
        self.slices = slices
        self.presses = presses
        self.releases = releases
        self.fallbackPress = fallbackPress
        self.fallbackRelease = fallbackRelease
    }

    /// The slice a key's press plays; key codes past the table play the fallback's.
    func press(_ keyCode: UInt16) -> Int? { lookup(presses, keyCode, fallbackPress) }
    /// The slice a key's release plays, nil when the pack has none for it.
    func release(_ keyCode: UInt16) -> Int? { lookup(releases, keyCode, fallbackRelease) }

    private func lookup(_ table: [Int16], _ keyCode: UInt16, _ fallback: Int16) -> Int? {
        let value = Int(keyCode) < table.count ? table[Int(keyCode)] : fallback
        return value >= 0 ? Int(value) : nil
    }
}

// MARK: - Events

/// The key events the tap listens to.
enum MechakeyKeyEvent {
    case down(isRepeat: Bool), up, flagsChanged(flags: UInt64)
}

enum MechakeyEventDecision {
    /// The slice a key event plays, or nil for silence: a held key's repeats
    /// when they are ignored, releases when key-up sounds are off, and keys
    /// the pack has no sound for.
    static func slice(for event: MechakeyKeyEvent, keyCode: UInt16, keyUpSounds: Bool, ignoreRepeat: Bool,
                      table: MechakeySoundTable) -> Int? {
        let down: Bool
        switch event {
        case .down(let isRepeat):
            if isRepeat, ignoreRepeat { return nil }
            down = true
        case .up:
            down = false
        case .flagsChanged(let flags):
            guard let isDown = MechakeyModifiers.isDown(keyCode: keyCode, flags: flags) else { return nil }
            down = isDown
        }
        if down { return table.press(keyCode) }
        return keyUpSounds ? table.release(keyCode) : nil
    }
}

// MARK: - Preview

/// What a pack's preview plays: "hello" and a space at a relaxed typing
/// pace, each key down then up, as offsets from the start.
enum MechakeyPreview {
    struct Hit: Equatable {
        let keyCode: UInt16
        let down: Bool
        let offset: Double // seconds
    }

    /// H, E, L, L, O, Space.
    static let keyCodes: [UInt16] = [4, 14, 37, 37, 31, 49]
    static let stride = 0.14
    static let hold = 0.07

    static func hits(keyUpSounds: Bool) -> [Hit] {
        keyCodes.enumerated().flatMap { index, code -> [Hit] in
            let start = Double(index) * stride
            let down = Hit(keyCode: code, down: true, offset: start)
            return keyUpSounds ? [down, Hit(keyCode: code, down: false, offset: start + hold)] : [down]
        }
    }

    /// How many frames of audio hold every hit and the longest slice after the last.
    static func length(of hits: [Hit], sampleRate: Double, longestSlice: Int) -> Int {
        let last = hits.map(\.offset).max() ?? 0
        return Int((last * sampleRate).rounded(.up)) + longestSlice
    }
}
