// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// The emoji list comes from Unicode's emoji-test.txt and CLDR annotations
// (Unicode License v3), built by Tools/zenith-emoji-data.py — see
// Resources/Emoji/NOTICE.txt.

import Foundation

// Zenith fork: the Emoji Picker's decisions, without a window, so the tests
// reach them: the preferences, reading the bundled list, which emoji this
// Mac's font can draw, the search and its ranking, the skin tone, and the
// recent and frequently used lists.

/// Kept here, not in `DefaultsKey`, so the feature's files never edit a
/// shared registry.
enum EmojiPickerDefaults {
    static let enabled = "zenithEmojiPickerEnabled"                 // Bool, default false
    static let shortcut = "zenithEmojiPickerShortcut"               // GlobalShortcut storage; absent = default, "" = none
    static let skinTone = "zenithEmojiPickerSkinTone"               // CommandBarEmoji.SkinTone.rawValue, "" = yellow
    static let recentCount = "zenithEmojiPickerRecentCount"         // Int, default 16
    static let showInCommandBar = "zenithEmojiPickerShowInCommandBar" // Bool, default true
    /// What was picked, how often and when. Private: never in a backup.
    static let usage = "zenithEmojiPickerUsage"                     // JSON EmojiUsage

    static let backupKeys: Set<String> = [enabled, shortcut, skinTone, recentCount, showInCommandBar]

    static let defaultRecentCount = 16
    static let recentCountRange = 0...40
}

struct EmojiPickerPreferences: Equatable {
    var enabled: Bool
    var skinTone: CommandBarEmoji.SkinTone
    var recentCount: Int
    var showInCommandBar: Bool

    init(defaults: UserDefaults = .standard) {
        enabled = defaults.object(forKey: EmojiPickerDefaults.enabled) as? Bool ?? false
        skinTone = CommandBarEmoji.SkinTone(rawValue: defaults.string(forKey: EmojiPickerDefaults.skinTone) ?? "") ?? .none
        let count = defaults.object(forKey: EmojiPickerDefaults.recentCount) as? Int ?? EmojiPickerDefaults.defaultRecentCount
        let range = EmojiPickerDefaults.recentCountRange
        recentCount = min(range.upperBound, max(range.lowerBound, count))
        showInCommandBar = defaults.object(forKey: EmojiPickerDefaults.showInCommandBar) as? Bool ?? true
    }
}

// MARK: - The list

/// The picker's groups, in Unicode's order.
enum EmojiCategory: String, CaseIterable, Identifiable {
    case smileys, people, animals, food, travel, activities, objects, symbols, flags

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smileys: return "Smileys & Emotion"
        case .people: return "People & Body"
        case .animals: return "Animals & Nature"
        case .food: return "Food & Drink"
        case .travel: return "Travel & Places"
        case .activities: return "Activities"
        case .objects: return "Objects"
        case .symbols: return "Symbols"
        case .flags: return "Flags"
        }
    }

    var symbol: String {
        switch self {
        case .smileys: return "face.smiling"
        case .people: return "hand.wave"
        case .animals: return "pawprint"
        case .food: return "fork.knife"
        case .travel: return "car"
        case .activities: return "soccerball"
        case .objects: return "lightbulb"
        case .symbols: return "heart"
        case .flags: return "flag"
        }
    }
}

/// One emoji of the bundled list.
struct EmojiRecord: Equatable, Identifiable {
    let category: EmojiCategory
    /// The fully-qualified sequence, untoned.
    let emoji: String
    let name: String
    let keywords: [String]
    /// The Emoji version it arrived in (15.1 for 15.1).
    let version: Double
    /// The light-tone sequence when it takes a skin tone; every U+1F3FB in it
    /// stands for the chosen tone.
    let toneTemplate: String?

    var id: String { emoji }

    /// The emoji in `tone`, or as it is when it takes none.
    func character(_ tone: CommandBarEmoji.SkinTone) -> String {
        guard let toneTemplate, let modifier = tone.modifier else { return emoji }
        let light = Unicode.Scalar(0x1F3FB)!
        return String(String.UnicodeScalarView(toneTemplate.unicodeScalars.map { $0 == light ? modifier : $0 }))
    }
}

enum EmojiCatalog {
    static let resourceFolder = "Emoji"
    static let resourceName = "emoji"

    /// Reads emoji.tsv: `group, emoji, name, keyword|keyword, version,
    /// tone-template` per line, `#` lines skipped. Lines it cannot read and
    /// emoji newer than `maximumVersion` are left out.
    static func parse(_ text: String, maximumVersion: Double = .infinity) -> [EmojiRecord] {
        var records: [EmojiRecord] = []
        records.reserveCapacity(2000)
        text.enumerateLines { line, _ in
            guard !line.isEmpty, !line.hasPrefix("#") else { return }
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard fields.count >= 5, let category = EmojiCategory(rawValue: String(fields[0])),
                  !fields[1].isEmpty, let version = Double(fields[4]), version <= maximumVersion else { return }
            let template = fields.count > 5 && !fields[5].isEmpty ? String(fields[5]) : nil
            records.append(EmojiRecord(category: category, emoji: String(fields[1]), name: String(fields[2]),
                                       keywords: fields[3].split(separator: "|").map(String.init),
                                       version: version, toneTemplate: template))
        }
        return records
    }

    /// The newest Emoji version this macOS draws. Apple ships each Unicode
    /// emoji release in the spring update after it: 15.1 in macOS 14.4, 16.0
    /// in 15.4, 17.0 in 26.4, 18.0 in 27.4.
    static func maximumVersion(for os: OperatingSystemVersion) -> Double {
        func atLeast(_ major: Int, _ minor: Int) -> Bool {
            os.majorVersion > major || (os.majorVersion == major && os.minorVersion >= minor)
        }
        if atLeast(27, 4) { return 18.0 }
        if atLeast(26, 4) { return 17.0 }
        if atLeast(15, 4) { return 16.0 }
        if atLeast(14, 4) { return 15.1 }
        return 15.0
    }

    /// The bundled list for this Mac, read once.
    static let shared: [EmojiRecord] = {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "tsv", subdirectory: resourceFolder),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return parse(text, maximumVersion: maximumVersion(for: ProcessInfo.processInfo.operatingSystemVersion))
    }()
}

// MARK: - Search

enum EmojiSearch {
    /// Lowercased, without accents or width, so "Cafe" finds "café".
    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }

    /// Every word of the query must find a word of the emoji's name or
    /// keywords that starts with it. Better matches first: the whole name,
    /// then whole words before the start of one, the name before the
    /// keywords; a shorter name, and a more often picked emoji, among
    /// equals; then Unicode's order.
    /// An emoji typed into the field finds itself.
    static func rank(_ records: [EmojiRecord], query: String, usage: EmojiUsage = EmojiUsage(),
                     limit: Int = 400) -> [EmojiRecord] {
        let folded = fold(query).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !folded.isEmpty else { return Array(records.prefix(limit)) }
        let tokens = folded.split(whereSeparator: { $0.isWhitespace || $0 == ":" || $0 == "_" || $0 == "-" })
            .map(String.init)
        var scored: [(score: Double, index: Int)] = []
        for (index, record) in records.enumerated() {
            if record.emoji == query.trimmingCharacters(in: .whitespaces)
                || record.emoji.replacingOccurrences(of: "\u{FE0F}", with: "") == folded {
                scored.append((10_000, index))
                continue
            }
            guard !tokens.isEmpty, let score = self.score(record, folded: folded, tokens: tokens) else { continue }
            scored.append((score + usage.boost(record.emoji), index))
        }
        scored.sort { $0.score != $1.score ? $0.score > $1.score : $0.index < $1.index }
        return scored.prefix(limit).map { records[$0.index] }
    }

    static func score(_ record: EmojiRecord, folded: String, tokens: [String]) -> Double? {
        let name = fold(record.name).replacingOccurrences(of: ":", with: "")
        let nameWords = name.split(whereSeparator: { $0.isWhitespace || $0 == "-" }).map(String.init)
        let keywords = record.keywords.map(fold)
        let keywordWords = keywords.flatMap { $0.split(separator: " ").map(String.init) }
        var total = 0.0
        if name == folded { total += 1000 }
        if keywords.contains(folded) { total += 20 }
        if name.hasPrefix(folded) { total += 10 }
        for token in tokens {
            // A whole word beats the start of one, and a keyword said in full
            // beats a name that only starts the same: "lol" is 😂, not 🍭.
            if nameWords.contains(token) { total += 100 }
            else if keywordWords.contains(token) { total += 80 }
            else if nameWords.contains(where: { $0.hasPrefix(token) }) { total += 60 }
            else if keywordWords.contains(where: { $0.hasPrefix(token) }) { total += 30 }
            else { return nil }
        }
        // A shorter name says more about the word that found it: "cat" before
        // "cat with tears of joy".
        return total - Double(nameWords.count)
    }
}

// MARK: - Recent and frequently used

/// What the person picked, keyed by the untoned emoji, so a tone change
/// keeps the history.
struct EmojiUsage: Codable, Equatable {
    struct Entry: Codable, Equatable {
        var count: Int
        var last: Date
    }

    /// The most emoji remembered; the least used and oldest go first.
    static let capacity = 120
    private(set) var entries: [String: Entry] = [:]

    init() {}

    mutating func record(_ emoji: String, at date: Date = Date()) {
        guard !emoji.isEmpty else { return }
        var entry = entries[emoji] ?? Entry(count: 0, last: date)
        entry.count += 1
        entry.last = date
        entries[emoji] = entry
        guard entries.count > Self.capacity else { return }
        let drop = entries.sorted { ($0.value.count, $0.value.last) < ($1.value.count, $1.value.last) }
            .prefix(entries.count - Self.capacity).map(\.key)
        drop.forEach { entries[$0] = nil }
    }

    /// Newest first.
    func recent(_ limit: Int) -> [String] {
        guard limit > 0 else { return [] }
        return entries.sorted { $0.value.last != $1.value.last ? $0.value.last > $1.value.last : $0.key < $1.key }
            .prefix(limit).map(\.key)
    }

    /// Most picked first; a tie goes to the newer one. Only emoji picked
    /// more than once, so the list is not the recent one again.
    func frequent(_ limit: Int) -> [String] {
        guard limit > 0 else { return [] }
        return entries.filter { $0.value.count > 1 }
            .sorted { ($0.value.count, $0.value.last) > ($1.value.count, $1.value.last) }
            .prefix(limit).map(\.key)
    }

    /// Lifts often picked emoji in a search a little, never past a better match.
    func boost(_ emoji: String) -> Double {
        guard let count = entries[emoji]?.count, count > 0 else { return 0 }
        return min(25, 6 * log2(Double(count) + 1))
    }

    mutating func clear() { entries = [:] }

    init(data: Data?) {
        guard let data, let decoded = try? JSONDecoder().decode(EmojiUsage.self, from: data) else { return }
        self = decoded
    }

    var data: Data? { try? JSONEncoder().encode(self) }
}

/// What the picker shows with nothing typed: the recent and frequently used
/// rows, then every category.
struct EmojiPickerSections: Equatable {
    struct Section: Equatable, Identifiable {
        let id: String
        let title: String
        let symbol: String
        let records: [EmojiRecord]
    }

    let sections: [Section]

    init(records: [EmojiRecord], usage: EmojiUsage, recentCount: Int) {
        let byEmoji = Dictionary(records.map { ($0.emoji, $0) }, uniquingKeysWith: { first, _ in first })
        var sections: [Section] = []
        let recent = usage.recent(recentCount).compactMap { byEmoji[$0] }
        if !recent.isEmpty {
            sections.append(Section(id: "recent", title: "Recent", symbol: "clock", records: recent))
        }
        let frequent = usage.frequent(recentCount).compactMap { byEmoji[$0] }
        if !frequent.isEmpty {
            sections.append(Section(id: "frequent", title: "Frequently Used", symbol: "star", records: frequent))
        }
        let grouped = Dictionary(grouping: records, by: \.category)
        for category in EmojiCategory.allCases {
            guard let list = grouped[category], !list.isEmpty else { continue }
            sections.append(Section(id: category.rawValue, title: category.title, symbol: category.symbol, records: list))
        }
        self.sections = sections
    }

    /// Every emoji in reading order, for the arrow keys.
    var flat: [EmojiRecord] { sections.flatMap(\.records) }
}

/// Moving the selection through the picker's grid with the arrow keys. The
/// grid is sections of emoji, each starting a new row, so up and down keep
/// the column across a section's short last row.
enum EmojiGridNavigation {
    enum Move { case left, right, up, down }

    /// The visual rows, as ranges of the flat index, for sections of these
    /// sizes laid out `columns` wide.
    static func rows(sectionCounts: [Int], columns: Int) -> [Range<Int>] {
        let columns = max(1, columns)
        var rows: [Range<Int>] = []
        var start = 0
        for count in sectionCounts where count > 0 {
            var offset = 0
            while offset < count {
                let length = min(columns, count - offset)
                rows.append((start + offset)..<(start + offset + length))
                offset += length
            }
            start += count
        }
        return rows
    }

    static func move(_ move: Move, from index: Int, rows: [Range<Int>]) -> Int {
        guard let last = rows.last?.upperBound, last > 0 else { return 0 }
        let current = min(max(0, index), last - 1)
        switch move {
        case .left: return max(0, current - 1)
        case .right: return min(last - 1, current + 1)
        case .up, .down:
            guard let row = rows.firstIndex(where: { $0.contains(current) }) else { return current }
            let target = move == .up ? row - 1 : row + 1
            guard rows.indices.contains(target) else { return current }
            let column = current - rows[row].lowerBound
            return min(rows[target].lowerBound + column, rows[target].upperBound - 1)
        }
    }
}
