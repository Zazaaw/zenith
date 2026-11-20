// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation

// Zenith fork: a teleprompter that hangs from the camera. Everything here is
// pure (Foundation only) and compiled into the tests: the settings, the
// script's paragraphs and word count, the layout estimate and the scroll
// speed it gives, paragraph jumps, the time left, the scroll clock, the
// voice-paced state machine, the keys, and the scripts kept as files in the
// app's container with their list in one registered default.
// PrompterService keeps time and talks to the island; the Prompter views draw.

// MARK: - Settings

enum PrompterAlignment: String, CaseIterable, Identifiable {
    case center, leading
    var id: String { rawValue }
}

/// What the person chose in Settings, read once when a session starts.
/// Speed and size can still change while prompting; those changes are saved
/// back, so the next session starts where the last one ended.
struct PrompterSettings: Equatable {
    static let speedRange = 60...260
    static let speedStep = 10
    static let defaultSpeed = 140
    static let textSizeRange = 18...48
    static let textSizeStep = 2
    static let defaultTextSize = 32
    static let lineSpacingRange = 1.0...2.0
    static let defaultLineSpacing = 1.3
    static let widthRange = 360...520
    static let defaultWidth = 420
    static let heightRange = 200...640
    static let defaultHeight = 340

    var speed = defaultSpeed
    var textSize = defaultTextSize
    var lineSpacing = defaultLineSpacing
    var alignment: PrompterAlignment = .center
    var mirror = false
    var guide = true
    var voicePaced = false
    var width = defaultWidth
    var height = defaultHeight

    static func current(in defaults: UserDefaults = .standard) -> PrompterSettings {
        var settings = PrompterSettings()
        settings.speed = clampedSpeed(defaults.object(forKey: DefaultsKey.notchPrompterSpeed) as? Int ?? defaultSpeed)
        settings.textSize = clampedTextSize(defaults.object(forKey: DefaultsKey.notchPrompterTextSize) as? Int ?? defaultTextSize)
        settings.lineSpacing = clampedLineSpacing(defaults.object(forKey: DefaultsKey.notchPrompterLineSpacing) as? Double
                                                  ?? defaultLineSpacing)
        settings.alignment = PrompterAlignment(rawValue: defaults.string(forKey: DefaultsKey.notchPrompterAlignment) ?? "") ?? .center
        settings.mirror = defaults.bool(forKey: DefaultsKey.notchPrompterMirror)
        settings.guide = defaults.object(forKey: DefaultsKey.notchPrompterGuide) as? Bool ?? true
        settings.voicePaced = defaults.bool(forKey: DefaultsKey.notchPrompterVoicePaced)
        settings.width = clamped(defaults.object(forKey: DefaultsKey.notchPrompterWidth) as? Int ?? defaultWidth, to: widthRange)
        settings.height = clamped(defaults.object(forKey: DefaultsKey.notchPrompterHeight) as? Int ?? defaultHeight, to: heightRange)
        return settings
    }

    static func clampedSpeed(_ value: Int) -> Int {
        // Whole steps, so ↑ and ↓ land on the same numbers Settings shows.
        let stepped = Int((Double(value) / Double(speedStep)).rounded()) * speedStep
        return clamped(stepped, to: speedRange)
    }

    static func clampedTextSize(_ value: Int) -> Int { clamped(value, to: textSizeRange) }

    static func clampedLineSpacing(_ value: Double) -> Double {
        guard value.isFinite else { return defaultLineSpacing }
        return (min(lineSpacingRange.upperBound, max(lineSpacingRange.lowerBound, value)) * 20).rounded() / 20
    }

    static func clamped(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(range.upperBound, max(range.lowerBound, value))
    }
}

// MARK: - Text

/// One block of the script between blank lines. A Markdown heading reads
/// as a heading; its marks and the emphasis marks are not read aloud.
struct PrompterParagraph: Equatable {
    var text: String
    var heading = false
    var words: Int
}

enum PrompterText {
    /// The script as paragraphs: blocks between blank lines, with their
    /// single line breaks kept. Empty blocks are dropped.
    static func paragraphs(_ text: String) -> [PrompterParagraph] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        var blocks: [[Substring]] = [[]]
        for line in normalized.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                if !(blocks.last?.isEmpty ?? true) { blocks.append([]) }
            } else {
                blocks[blocks.count - 1].append(line)
            }
        }
        return blocks.compactMap { lines -> PrompterParagraph? in
            guard let first = lines.first else { return nil }
            var heading = false
            var cleaned = lines.map { cleanLine(String($0)) }
            let trimmed = first.drop(while: { $0 == " " })
            if trimmed.hasPrefix("#") {
                let marks = trimmed.prefix(while: { $0 == "#" })
                if marks.count <= 6, trimmed.dropFirst(marks.count).first.map({ $0 == " " }) ?? true {
                    heading = true
                    cleaned[0] = cleanLine(String(trimmed.dropFirst(marks.count)))
                }
            }
            let joined = cleaned.map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: "\n")
            guard !joined.isEmpty else { return nil }
            return PrompterParagraph(text: joined, heading: heading, words: wordCount(joined))
        }
    }

    /// Bold and code marks go; the words stay.
    private static func cleanLine(_ line: String) -> String {
        line.replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: "`", with: "")
    }

    /// Words as a reader says them: runs between spaces that hold a letter
    /// or a digit, and every Chinese or Japanese character on its own, since
    /// those scripts read without spaces.
    static func wordCount(_ text: String) -> Int {
        var count = 0
        for token in text.split(whereSeparator: { $0.isWhitespace }) {
            var wide = 0
            var rest = false
            for scalar in token.unicodeScalars {
                if isWide(scalar) { wide += 1 }
                else if CharacterSet.alphanumerics.contains(scalar) { rest = true }
            }
            count += wide + (rest ? 1 : 0)
        }
        return count
    }

    /// Ideographs, kana and full-width forms: about one em across, read one at a time.
    static func isWide(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3040...0x30FF, 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF, 0xFF00...0xFF60, 0x20000...0x2FA1F:
            return true
        default:
            return false
        }
    }
}

// MARK: - Layout

/// Where each paragraph sits in the reading column, measured by the reader
/// or estimated before it has drawn. Offset 0 has the first line on the
/// guide; the script ends when its last line reaches it.
struct PrompterTimeline: Equatable {
    var tops: [Double]
    var heights: [Double]
    var words: [Int]
    var lineHeight: Double

    static let empty = PrompterTimeline(tops: [], heights: [], words: [], lineHeight: 0)

    var totalHeight: Double { zip(tops, heights).map { $0 + $1 }.max() ?? 0 }
    var totalWords: Int { words.reduce(0, +) }
    /// The last line on the guide.
    var limit: Double { max(0, totalHeight - lineHeight) }

    /// Points per second that carry the whole script past the guide in the
    /// time `wpm` takes to say it.
    func pointsPerSecond(wpm: Int) -> Double {
        let words = totalWords
        guard words > 0, wpm > 0, limit > 0 else { return 0 }
        return limit * Double(wpm) / (60 * Double(words))
    }

    /// Seconds until the last line reaches the guide.
    func timeLeft(offset: Double, wpm: Int) -> TimeInterval {
        let speed = pointsPerSecond(wpm: wpm)
        guard speed > 0 else { return 0 }
        return max(0, limit - min(max(0, offset), limit)) / speed
    }

    /// Seconds the whole script takes at `wpm`.
    func duration(wpm: Int) -> TimeInterval {
        guard wpm > 0 else { return 0 }
        return Double(totalWords) * 60 / Double(wpm)
    }

    func progress(offset: Double) -> Double {
        guard limit > 0 else { return 0 }
        return min(1, max(0, offset / limit))
    }

    /// ← and →: back to the start of this paragraph, or the one before when
    /// already at its start; forward to the next one, or the end.
    func jumpTarget(from offset: Double, forward: Bool) -> Double {
        guard !tops.isEmpty else { return 0 }
        let slack = max(1, lineHeight * 0.6)
        if forward {
            let next = tops.first { $0 > offset + 1 }
            return min(limit, next ?? limit)
        }
        guard let index = tops.lastIndex(where: { $0 <= offset + 1 }) else { return 0 }
        if offset - tops[index] > slack { return min(limit, tops[index]) }
        return min(limit, tops[max(0, index - 1)])
    }

    /// The paragraph the guide is in, and how far through it.
    func position(of offset: Double) -> (index: Int, fraction: Double)? {
        guard !tops.isEmpty else { return nil }
        let index = tops.lastIndex(where: { $0 <= offset }) ?? 0
        let height = max(1, heights[index])
        return (index, min(1, max(0, (offset - tops[index]) / height)))
    }

    /// The same place in a new layout, after the text size or the width
    /// changed: the same paragraph, the same way through it.
    func translate(_ offset: Double, to next: PrompterTimeline) -> Double {
        guard next.tops.count == tops.count, let place = position(of: offset) else {
            return progress(offset: offset) * next.limit
        }
        return min(next.limit, max(0, next.tops[place.index] + place.fraction * next.heights[place.index]))
    }
}

enum PrompterLayout {
    /// A line of the reading face, as SwiftUI's system font sets it, times
    /// the chosen spacing.
    static func lineHeight(textSize: Int, lineSpacing: Double) -> Double {
        Double(textSize) * 1.2 * lineSpacing
    }

    /// The extra room between lines SwiftUI's `lineSpacing` takes.
    static func extraLineSpacing(textSize: Int, lineSpacing: Double) -> Double {
        Double(textSize) * 1.2 * max(0, lineSpacing - 1)
    }

    /// Air between paragraphs: a little under a line.
    static func paragraphSpacing(textSize: Int) -> Double { Double(textSize) * 0.8 }

    /// Average advances of the semibold system face: about half an em for
    /// Latin text, a full em for Chinese and Japanese.
    static let narrowAdvance = 0.55
    static let wideAdvance = 1.0

    /// Lines a paragraph wraps to in `width`, filling each line word by word.
    static func estimatedLines(_ text: String, textSize: Int, width: Double) -> Int {
        guard width > 0 else { return 1 }
        let size = Double(textSize)
        let space = size * narrowAdvance
        var lines = 0
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            var used = 0.0
            var count = 1
            for word in line.split(separator: " ") {
                let advance = word.unicodeScalars.reduce(0.0) { $0 + size * (PrompterText.isWide($1) ? wideAdvance : narrowAdvance) }
                let needed = used == 0 ? advance : used + space + advance
                if needed <= width || used == 0 {
                    used = needed
                    // A word wider than the line breaks across lines.
                    while used > width { count += 1; used -= width }
                } else {
                    count += 1
                    used = advance
                    while used > width { count += 1; used -= width }
                }
            }
            lines += count
        }
        return max(1, lines)
    }

    /// The column before the reader has measured it.
    static func estimate(_ paragraphs: [PrompterParagraph], textSize: Int, lineSpacing: Double,
                         width: Double) -> PrompterTimeline {
        let line = lineHeight(textSize: textSize, lineSpacing: lineSpacing)
        let base = Double(textSize) * 1.2
        let gap = paragraphSpacing(textSize: textSize)
        var tops: [Double] = []
        var heights: [Double] = []
        var y = 0.0
        for paragraph in paragraphs {
            let lines = estimatedLines(paragraph.text, textSize: textSize, width: width)
            // The spacing sits between lines, not after the last one.
            let height = base + Double(lines - 1) * line
            tops.append(y)
            heights.append(height)
            y += height + gap
        }
        return PrompterTimeline(tops: tops, heights: heights, words: paragraphs.map(\.words), lineHeight: base)
    }
}

// MARK: - Clock

/// The scroll position as a function of time: an anchor, a speed and
/// whether it runs, plus the short glide a jump eases through. The reader
/// asks it for the offset on every display frame, so the motion is
/// continuous at the display's rate and never steps.
struct PrompterClock: Equatable {
    static let glideDuration: TimeInterval = 0.38

    private(set) var anchorOffset = 0.0
    private(set) var anchorTime: TimeInterval = 0
    private(set) var speed = 0.0
    private(set) var running = false
    private(set) var limit = 0.0
    /// The glide's remaining distance at its start, and when it started.
    private(set) var glideDelta = 0.0
    private(set) var glideStart: TimeInterval = 0

    init(limit: Double = 0, speed: Double = 0, now: TimeInterval = 0) {
        self.limit = max(0, limit)
        self.speed = max(0, speed)
        anchorTime = now
    }

    /// Where the column is without the glide.
    func baseOffset(at time: TimeInterval) -> Double {
        let moved = running ? max(0, time - anchorTime) * speed : 0
        return min(limit, max(0, anchorOffset + moved))
    }

    func offset(at time: TimeInterval) -> Double {
        let base = baseOffset(at: time)
        guard glideDelta != 0 else { return base }
        let progress = min(1, max(0, (time - glideStart) / Self.glideDuration))
        guard progress < 1 else { return base }
        // Ease out: quick away from where it was, settling on the target.
        let remaining = pow(1 - progress, 3)
        return min(limit, max(0, base + glideDelta * remaining))
    }

    func isGliding(at time: TimeInterval) -> Bool {
        glideDelta != 0 && time - glideStart < Self.glideDuration
    }

    func isFinished(at time: TimeInterval) -> Bool { limit > 0 && baseOffset(at: time) >= limit }

    /// When the base reaches the end at the current speed, if it is running.
    func finishTime() -> TimeInterval? {
        guard running, speed > 0 else { return nil }
        return anchorTime + max(0, limit - anchorOffset) / speed
    }

    private mutating func rebase(at time: TimeInterval) {
        anchorOffset = baseOffset(at: time)
        anchorTime = time
    }

    mutating func setRunning(_ value: Bool, at time: TimeInterval) {
        rebase(at: time)
        running = value
    }

    mutating func setSpeed(_ value: Double, at time: TimeInterval) {
        rebase(at: time)
        speed = max(0, value.isFinite ? value : 0)
    }

    /// Moves to `target`; animated, the column eases there from where it is.
    mutating func jump(to target: Double, at time: TimeInterval, animated: Bool) {
        let shown = offset(at: time)
        rebase(at: time)
        anchorOffset = min(limit, max(0, target))
        glideDelta = animated ? shown - anchorOffset : 0
        glideStart = time
    }

    /// A new layout: the same place in it, a new end and a new speed.
    mutating func relayout(offset: Double, limit: Double, speed: Double, at time: TimeInterval) {
        anchorTime = time
        self.limit = max(0, limit)
        anchorOffset = min(self.limit, max(0, offset))
        self.speed = max(0, speed)
        glideDelta = 0
    }
}

// MARK: - Voice pace

/// Voice-paced scrolling from the microphone's level alone. A level well
/// above the room's quiet counts as speech; 1.5 seconds without it holds the
/// script, and the next word lets it go. The quiet starts at the first
/// reading (the countdown's), falls with any quieter one, and rises slowly
/// with the readings that are not speech, so a fan or a room tone does not
/// count as talking, and talking never raises it. Nothing is recognised and
/// nothing is recorded.
struct PrompterVoicePace: Equatable {
    static let silence: TimeInterval = 1.5
    /// Speech stands this far above the quiet, in dB.
    static let margin: Float = 12
    /// Never quieter than this counts as speech, however still the room.
    static let quietest: Float = -55
    /// The quiet never sits above this, so a voice heard first stays a voice.
    static let loudestFloor: Float = -45
    /// How much of the gap the quiet closes per quiet reading, rising.
    static let floorRise: Float = 0.002

    /// Nil until the first reading.
    private(set) var floor: Float?
    private(set) var lastVoice: TimeInterval
    private(set) var holding = false

    init(now: TimeInterval) { lastVoice = now }

    /// A new start: the person gets the full silence before it holds.
    mutating func reset(at time: TimeInterval) {
        lastVoice = time
        holding = false
    }

    var threshold: Float { max((floor ?? Self.quietest - Self.margin) + Self.margin, Self.quietest) }

    /// One level reading in dBFS; returns whether the script holds.
    @discardableResult
    mutating func update(level: Float, at time: TimeInterval) -> Bool {
        let level = level.isFinite ? max(-120, min(0, level)) : -120
        let quiet = min(floor ?? Self.loudestFloor, Self.loudestFloor)
        floor = level < quiet ? max(level, -90) : quiet
        if level >= threshold {
            lastVoice = time
            holding = false
        } else {
            if let floor, level > floor { self.floor = min(Self.loudestFloor, floor + (level - floor) * Self.floorRise) }
            if time - lastVoice >= Self.silence { holding = true }
        }
        return holding
    }

    /// dBFS of a buffer's root mean square.
    static func level(rms: Float) -> Float {
        guard rms.isFinite, rms > 0 else { return -120 }
        return max(-120, 20 * log10(rms))
    }
}

// MARK: - Keys

enum PrompterKeyAction: Equatable {
    case toggle, faster, slower, previous, next, larger, smaller, exit
}

enum PrompterKeys {
    /// What a key does while prompting. Keys with Command, Control or Option
    /// stay the island's and the system's, so ⌘K and the module keys still work.
    static func action(keyCode: UInt16, characters: String?, command: Bool, control: Bool, option: Bool) -> PrompterKeyAction? {
        guard !command, !control, !option else { return nil }
        switch keyCode {
        case 49: return .toggle
        case 126: return .faster
        case 125: return .slower
        case 123: return .previous
        case 124: return .next
        case 53: return .exit
        case 69: return .larger   // keypad +
        case 78: return .smaller  // keypad −
        default: break
        }
        switch characters {
        case "+", "=": return .larger
        case "-", "_": return .smaller
        default: return nil
        }
    }
}

// MARK: - Formats

enum PrompterFormat {
    /// `1:05`, `12:40`, `1:02:03`.
    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.isFinite ? seconds.rounded(.up) : 0))
        let hours = total / 3600, minutes = (total % 3600) / 60, rest = total % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, rest) : String(format: "%d:%02d", minutes, rest)
    }
}

// MARK: - Island

/// Zenith fork: the island's size while prompting, read by `NotchGeometry`:
/// the body's width (the shoulders flare outside it) and the reading
/// panel's height below the camera.
struct ZenithPrompterIslandGeometry: Equatable {
    var width: CGFloat
    var contentHeight: CGFloat

    init(settings: PrompterSettings) {
        width = CGFloat(settings.width)
        contentHeight = CGFloat(settings.height)
    }
}

/// Zenith fork: what the island asks the teleprompter. The island's code is
/// compiled into the tests as well, so it reads this rather than
/// PrompterService, which keeps it current.
enum ZenithPrompterIsland {
    /// The reading panel while a session prompts; nil otherwise.
    static var geometry: ZenithPrompterIslandGeometry?
    /// Prompting, or a dialog of the prompter's is up: the island stays open.
    static var holdsIsland = false
    /// The session's controls; returns whether it took the key.
    static var perform: ((PrompterKeyAction) -> Bool)?

    static var prompting: Bool { geometry != nil }

    /// A key pressed in the island: the prompter's while it prompts.
    static func handleKey(keyCode: UInt16, characters: String?, command: Bool, control: Bool, option: Bool) -> Bool {
        guard prompting, let perform,
              let action = PrompterKeys.action(keyCode: keyCode, characters: characters,
                                               command: command, control: control, option: option) else { return false }
        return perform(action)
    }
}

// MARK: - Scripts

enum PrompterScriptFormat: String, Codable {
    case markdown = "md", text = "txt"

    static func from(pathExtension: String) -> PrompterScriptFormat? {
        switch pathExtension.lowercased() {
        case "md", "markdown", "mdown": return .markdown
        case "txt", "text", "": return .text
        default: return nil
        }
    }
}

struct PrompterScript: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var format: PrompterScriptFormat
    var modified: Date

    init(id: UUID = UUID(), name: String, format: PrompterScriptFormat = .markdown, modified: Date = Date()) {
        self.id = id
        self.name = name
        self.format = format
        self.modified = modified
    }

    var fileName: String { "\(id.uuidString).\(format.rawValue)" }
}

/// The scripts' list as it is stored: `{"version":1,"scripts":[…]}` in one
/// registered default, so a backup carries the list. The texts live as
/// files beside it in the container, which a backup does not carry.
enum PrompterLibrary {
    static let version = 1
    static let maximumNameLength = 80

    private struct Stored: Codable {
        var version: Int
        var scripts: [PrompterScript]
    }

    static func decode(_ raw: String?) -> [PrompterScript] {
        guard let raw, let data = raw.data(using: .utf8),
              let stored = try? JSONDecoder().decode(Stored.self, from: data) else { return [] }
        var seen = Set<UUID>()
        return stored.scripts.filter { seen.insert($0.id).inserted }
    }

    static func encode(_ scripts: [PrompterScript]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(Stored(version: version, scripts: scripts)),
              let raw = String(data: data, encoding: .utf8) else { return "" }
        return raw
    }

    /// A name to show and store: one line, trimmed, not too long, never empty.
    static func cleanName(_ name: String, fallback: String) -> String {
        let line = name.components(separatedBy: .newlines).joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        let short = String(line.prefix(maximumNameLength))
        return short.isEmpty ? fallback : short
    }
}

/// The scripts on disk: `<container>/Prompter/<id>.md` (or `.txt`), written
/// owner-only through `PrivateFileStore`, with the list in UserDefaults.
/// Tests point it at a temporary container and their own defaults suite.
struct PrompterStore {
    /// A larger file is not a script.
    static let maximumImportBytes = 4 * 1024 * 1024
    static let importExtensions = ["txt", "md", "markdown", "text"]

    let container: URL
    let defaults: UserDefaults

    var directory: URL { container.appendingPathComponent("Prompter", isDirectory: true) }

    static var standard: PrompterStore? {
        PrivateFileStore.containerURL.map { PrompterStore(container: $0, defaults: .standard) }
    }

    func list() -> [PrompterScript] {
        PrompterLibrary.decode(defaults.string(forKey: DefaultsKey.notchPrompterScripts))
    }

    private func saveList(_ scripts: [PrompterScript]) {
        defaults.set(PrompterLibrary.encode(scripts), forKey: DefaultsKey.notchPrompterScripts)
    }

    func url(for script: PrompterScript) -> URL { directory.appendingPathComponent(script.fileName) }

    /// The script's text; empty when its file is missing, as after a
    /// backup restored on another Mac.
    func text(of script: PrompterScript) -> String {
        guard let data = try? Data(contentsOf: url(for: script)) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    @discardableResult
    func write(_ text: String, for script: PrompterScript) -> Bool {
        guard PrivateFileStore.createDirectory(at: directory, container: container) else { return false }
        return PrivateFileStore.write(Data(text.utf8), to: url(for: script))
    }

    /// A new script at the end of the list, with its file.
    @discardableResult
    func create(name: String, text: String, format: PrompterScriptFormat = .markdown, fallbackName: String,
                now: Date = Date()) -> PrompterScript? {
        let script = PrompterScript(name: PrompterLibrary.cleanName(name, fallback: fallbackName), format: format, modified: now)
        guard write(text, for: script) else { return nil }
        saveList(list() + [script])
        return script
    }

    /// Saves new text; the list keeps when it was changed.
    @discardableResult
    func save(_ text: String, for id: UUID, now: Date = Date()) -> Bool {
        var scripts = list()
        guard let index = scripts.firstIndex(where: { $0.id == id }), write(text, for: scripts[index]) else { return false }
        scripts[index].modified = now
        saveList(scripts)
        return true
    }

    @discardableResult
    func rename(_ id: UUID, to name: String, fallbackName: String) -> PrompterScript? {
        var scripts = list()
        guard let index = scripts.firstIndex(where: { $0.id == id }) else { return nil }
        scripts[index].name = PrompterLibrary.cleanName(name, fallback: fallbackName)
        saveList(scripts)
        return scripts[index]
    }

    func delete(_ id: UUID) {
        var scripts = list()
        guard let index = scripts.firstIndex(where: { $0.id == id }) else { return }
        try? FileManager.default.removeItem(at: url(for: scripts[index]))
        scripts.remove(at: index)
        saveList(scripts)
    }

    /// Reads a `.txt` or `.md` file as a new script named after the file.
    /// Nil for another kind of file, one too large, or one that is not text.
    func importFile(at source: URL, fallbackName: String, now: Date = Date()) -> PrompterScript? {
        guard let format = PrompterScriptFormat.from(pathExtension: source.pathExtension),
              let values = try? source.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
              values.isRegularFile == true, (values.fileSize ?? 0) <= Self.maximumImportBytes,
              let data = try? Data(contentsOf: source),
              let text = Self.decodeText(data) else { return nil }
        let name = source.deletingPathExtension().lastPathComponent
        return create(name: name, text: text, format: format, fallbackName: fallbackName, now: now)
    }

    /// UTF-8 (with or without a mark), or UTF-16 with its mark. Anything
    /// with a NUL byte otherwise is taken for binary.
    static func decodeText(_ data: Data) -> String? {
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) {
            return String(data: data, encoding: .utf16)
        }
        guard !data.contains(0), var text = String(data: data, encoding: .utf8) else { return nil }
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        return text
    }
}
