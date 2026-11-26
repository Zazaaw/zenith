// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import Foundation

// Zenith fork: Translate's decisions, kept away from the Translation
// framework and the windows so the harness can test them: the preferences,
// the language codes and which one to translate into, how a selection is
// tidied before it is translated, and how the clipboard is kept and put back
// when the selection has to be copied to be read.

// MARK: - Preferences

/// Translate's preferences. Kept here, not in `DefaultsKey`, so the feature
/// never edits the shared registry; `backupKeys` joins the settings backup.
enum TranslateDefaults {
    static let enabled = "zenithTranslateEnabled"             // Bool, default false
    static let shortcut = "zenithTranslateShortcut"           // GlobalShortcut storage; absent = default, "" = none
    static let target = "zenithTranslateTarget"               // language code; absent or "" = the system's
    static let secondTarget = "zenithTranslateSecondTarget"   // language code; absent = the system's next, "none" = none
    static let showDetection = "zenithTranslateShowDetection" // Bool, default true

    static let noneValue = "none"

    static let backupKeys: Set<String> = [enabled, shortcut, target, secondTarget, showDetection]
}

/// What the card needs from the preferences, read once per translation.
struct TranslatePreferences: Equatable {
    /// The language to read in.
    let primary: String
    /// The one to use when the text already is in `primary`; nil for none.
    let second: String?
    let showDetection: Bool

    static func read(_ defaults: UserDefaults = .standard,
                     preferredLanguages: [String] = Locale.preferredLanguages) -> TranslatePreferences {
        let system = TranslateLanguageCode.systemTargets(preferredLanguages)
        let storedPrimary = defaults.string(forKey: TranslateDefaults.target) ?? ""
        let primary = TranslateLanguageCode.canonical(storedPrimary) ?? system.primary
        let second: String?
        switch defaults.string(forKey: TranslateDefaults.secondTarget) {
        case nil, "":
            // Unset: the system's next language, or English, whichever differs
            // from the language chosen above.
            second = TranslateLanguageCode.systemTargets(preferredLanguages, primary: primary).second
        case TranslateDefaults.noneValue?:
            second = nil
        case let stored?:
            second = TranslateLanguageCode.canonical(stored)
        }
        let showDetection = defaults.object(forKey: TranslateDefaults.showDetection) as? Bool ?? true
        return TranslatePreferences(primary: primary,
                                    second: second.flatMap { $0 == primary ? nil : $0 },
                                    showDetection: showDetection)
    }
}

// MARK: - Languages

/// Language codes as Translate keeps them: the bare language ("en", "id",
/// "pt"), except Chinese, which keeps its script ("zh-Hans", "zh-Hant")
/// because the two are translated as different languages. Regions are
/// dropped: Translation answers "en" for both British and American English.
enum TranslateLanguageCode {
    /// Codes the system replaced long ago but some apps still report.
    private static let legacy = ["in": "id", "iw": "he", "ji": "yi", "jw": "jv", "mo": "ro"]

    /// Apple's list for macOS 15, used until the framework's own list loads
    /// and wherever it cannot be read.
    static let fallbackLanguages = ["ar", "zh-Hans", "zh-Hant", "nl", "en", "fr", "de", "hi", "id", "it", "ja",
                                    "ko", "pl", "pt", "ru", "es", "th", "tr", "uk", "vi"]

    /// "en-US", "en_GB", "id-ID", "in", "zh-TW" and "zh-Hans-CN" become "en",
    /// "en", "id", "id", "zh-Hant" and "zh-Hans". Nil for nothing, "und" and
    /// what isn't a language subtag at all.
    static func canonical(_ raw: String) -> String? {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "_", with: "-")
        let parts = cleaned.split(separator: "-").map { String($0) }
        guard var language = parts.first?.lowercased(),
              (2...3).contains(language.count),
              language.unicodeScalars.allSatisfy({ $0.isASCII && CharacterSet.letters.contains($0) }),
              language != "und"
        else { return nil }
        language = legacy[language] ?? language
        guard language == "zh" else { return language }
        let rest = parts.dropFirst().map { $0.lowercased() }
        let traditional = rest.contains("hant") || rest.contains { ["tw", "hk", "mo"].contains($0) }
        return traditional ? "zh-Hant" : "zh-Hans"
    }

    static func same(_ lhs: String?, _ rhs: String?) -> Bool {
        guard let lhs = lhs.flatMap(canonical), let rhs = rhs.flatMap(canonical) else { return false }
        return lhs == rhs
    }

    /// The language to read in, from the system's list, and the one to use
    /// when the text is already in it: the system's next language, else
    /// English (nil when the first one is English and there is no other).
    static func systemTargets(_ preferred: [String], primary chosen: String? = nil)
        -> (primary: String, second: String?) {
        let codes = preferred.compactMap(canonical)
        let primary = chosen.flatMap(canonical) ?? codes.first ?? "en"
        let second = codes.first { $0 != primary } ?? (primary == "en" ? nil : "en")
        return (primary, second)
    }

    /// The language's English name: "Indonesian", "Chinese, Simplified".
    static func displayName(_ code: String) -> String {
        let english = Locale(identifier: "en")
        return english.localizedString(forIdentifier: code)
            ?? english.localizedString(forLanguageCode: code)
            ?? code
    }

    /// Codes for a menu, once each, by name.
    static func menu(_ codes: [String]) -> [String] {
        var seen = Set<String>()
        return codes.compactMap(canonical)
            .filter { seen.insert($0).inserted }
            .sorted { displayName($0).localizedStandardCompare(displayName($1)) == .orderedAscending }
    }

    /// The language a voice is asked for, among the voices installed: Chinese
    /// by its script's region, any other language in the person's region
    /// when there is a voice for it, else its first voice.
    static func speechLanguage(_ code: String, available: [String], region: String? = Locale.current.region?.identifier)
        -> String? {
        guard let code = canonical(code) else { return nil }
        let voices = available.map { $0.replacingOccurrences(of: "_", with: "-") }
        if code == "zh-Hans" { return ["zh-CN", "zh-SG"].first(where: voices.contains) }
        if code == "zh-Hant" { return ["zh-TW", "zh-HK", "zh-MO"].first(where: voices.contains) }
        let matching = voices.filter { canonical($0) == code }.sorted()
        if let region, let local = matching.first(where: { $0.hasSuffix("-" + region) }) { return local }
        return matching.first
    }
}

/// Which language a text is translated into.
struct TranslateTargetChoice: Equatable {
    /// Nil when the text is already in the only language there is to read.
    let target: String?
    /// True when the text was already in the first language and the second is used.
    let usedSecond: Bool

    /// Into the first language, unless the text already is in it: then into
    /// the second (Indonesian ↔ English), or nowhere when there is none.
    static func choose(detected: String?, primary: String, second: String?) -> TranslateTargetChoice {
        let primary = TranslateLanguageCode.canonical(primary) ?? "en"
        let second = second.flatMap(TranslateLanguageCode.canonical).flatMap { $0 == primary ? nil : $0 }
        guard TranslateLanguageCode.same(detected, primary) else {
            return TranslateTargetChoice(target: primary, usedSecond: false)
        }
        return TranslateTargetChoice(target: second, usedSecond: second != nil)
    }
}

/// What detection found: the language and how sure it is (0…1).
struct TranslateDetection: Equatable {
    let code: String
    let confidence: Double

    /// Below this, the card asks the framework to identify the language itself.
    static let minimumConfidence = 0.3

    /// The likeliest language among `hypotheses` (raw codes to confidence), when sure enough.
    static func pick(_ hypotheses: [String: Double], minimum: Double = minimumConfidence) -> TranslateDetection? {
        var best: [String: Double] = [:]
        for (raw, confidence) in hypotheses {
            guard let code = TranslateLanguageCode.canonical(raw) else { continue }
            best[code] = max(best[code] ?? 0, confidence)
        }
        guard let top = best.sorted(by: { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }).first,
              top.value >= minimum else { return nil }
        return TranslateDetection(code: top.key, confidence: min(1, top.value))
    }
}

/// How a pair is translated, from what the framework says of it.
enum TranslatePairStatus: Equatable {
    case installed, notDownloaded, unsupported
}

enum TranslateRoute: Equatable {
    /// A session made directly from the installed languages (macOS 26).
    case direct
    /// A session the card's SwiftUI host opens (macOS 15, or no known source).
    case hosted
    /// The languages need downloading first, through the system's prompt.
    case download
    case unsupported

    static func choose(status: TranslatePairStatus, directAvailable: Bool, sourceKnown: Bool) -> TranslateRoute {
        switch status {
        case .installed: return directAvailable && sourceKnown ? .direct : .hosted
        case .notDownloaded: return .download
        case .unsupported: return .unsupported
        }
    }
}

// MARK: - Text

/// How a selection is tidied before it is translated: line endings and
/// invisible characters, runs of spaces, and lines that only break because a
/// PDF or a terminal wrapped them. Paragraphs and lists stay as they were.
enum TranslateText {
    /// A selection longer than this is cut at a word near the limit.
    static let maximumLength = 5_000

    struct Prepared: Equatable {
        let text: String
        let truncated: Bool
    }

    /// The text to translate, or nil when there are no letters in it.
    static func prepare(_ raw: String, limit: Int = maximumLength) -> Prepared? {
        let text = normalize(raw)
        guard text.unicodeScalars.contains(where: { CharacterSet.letters.contains($0) }) else { return nil }
        guard text.count > limit else { return Prepared(text: text, truncated: false) }
        var cut = String(text.prefix(limit))
        if let space = cut.lastIndex(where: { $0.isWhitespace }),
           cut.distance(from: space, to: cut.endIndex) < 200 {
            cut = String(cut[..<space])
        }
        return Prepared(text: cut.trimmingCharacters(in: .whitespacesAndNewlines), truncated: true)
    }

    static func normalize(_ raw: String) -> String {
        var text = raw.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{2028}", with: "\n")
            .replacingOccurrences(of: "\u{2029}", with: "\n\n")
        // A soft hyphen, zero-width space, word joiner and byte order mark
        // only split the words they sit in.
        for invisible in ["\u{00AD}", "\u{200B}", "\u{2060}", "\u{FEFF}"] {
            text = text.replacingOccurrences(of: invisible, with: "")
        }
        text = text.replacingOccurrences(of: "\u{00A0}", with: " ").replacingOccurrences(of: "\t", with: " ")
        var paragraphs: [[String]] = []
        var current: [String] = []
        for line in text.components(separatedBy: "\n") {
            let tidy = line.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
            if tidy.isEmpty {
                if !current.isEmpty { paragraphs.append(current) }
                current = []
            } else {
                current.append(tidy)
            }
        }
        if !current.isEmpty { paragraphs.append(current) }
        return paragraphs.map(joinWrapped).joined(separator: "\n\n")
    }

    /// Joins the lines of one paragraph where the break only wrapped a
    /// sentence: the line before does not end one and the next starts in
    /// lowercase. A word hyphenated across the break is mended.
    private static func joinWrapped(_ lines: [String]) -> String {
        guard var result = lines.first else { return "" }
        for next in lines.dropFirst() {
            guard wraps(after: result, into: next) else {
                result += "\n" + next
                continue
            }
            if result.hasSuffix("-"), result.dropLast().last?.isLetter == true {
                result = String(result.dropLast()) + next
            } else {
                result += " " + next
            }
        }
        return result
    }

    private static let sentenceEnds: Set<Character> = [".", "!", "?", ":", ";", "。", "！", "？", "…"]

    private static func wraps(after previous: String, into next: String) -> Bool {
        guard let last = previous.last, !sentenceEnds.contains(last),
              let first = next.first, first.isLetter, first.isLowercase else { return false }
        return !isListItem(next)
    }

    private static func isListItem(_ line: String) -> Bool {
        if let first = line.first, ["•", "◦", "▪", "–", "—"].contains(first) { return true }
        let marker = line.prefix { $0 != " " }
        guard marker.count >= 2, marker.count <= 4, let end = marker.last, [".", ")"].contains(end) else { return false }
        let body = marker.dropLast()
        return body.allSatisfy(\.isNumber) || (body.count == 1 && body.allSatisfy(\.isLetter))
    }
}

// MARK: - Clipboard

/// Every item and flavour on a pasteboard, kept to be written back after a
/// copy that was only made to read the selection.
struct TranslateClipboardSnapshot: Equatable {
    struct Flavor: Equatable {
        let type: String
        let data: Data
    }

    let items: [[Flavor]]

    var byteCount: Int { items.reduce(0) { $0 + $1.reduce(0) { $0 + $1.data.count } } }

    /// More than this is not held in memory to be put back: the copy is not
    /// made, so nothing is lost.
    static let maximumBytes = 64 * 1024 * 1024

    /// Nil when a flavour cannot be read (promised data that never comes) or
    /// the whole is too large: then the clipboard is left alone.
    static func take(from pasteboard: NSPasteboard, maximumBytes: Int = maximumBytes) -> TranslateClipboardSnapshot? {
        guard let items = pasteboard.pasteboardItems else {
            return pasteboard.types?.isEmpty == false ? nil : TranslateClipboardSnapshot(items: [])
        }
        var kept: [[Flavor]] = []
        var total = 0
        for item in items {
            var flavors: [Flavor] = []
            for type in item.types {
                guard let data = item.data(forType: type) else { return nil }
                total += data.count
                guard total <= maximumBytes else { return nil }
                flavors.append(Flavor(type: type.rawValue, data: data))
            }
            kept.append(flavors)
        }
        return TranslateClipboardSnapshot(items: kept)
    }

    /// Puts the items back as they were; an empty snapshot leaves it empty.
    func write(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        let restored: [NSPasteboardItem] = items.map { flavors in
            let item = NSPasteboardItem()
            for flavor in flavors { item.setData(flavor.data, forType: NSPasteboard.PasteboardType(flavor.type)) }
            return item
        }
        if !restored.isEmpty { pasteboard.writeObjects(restored) }
    }
}

enum TranslateClipboard {
    /// The text a simulated ⌘C put on the clipboard: only when the clipboard
    /// changed since `before`, and only text with something in it.
    static func copiedText(changeCountBefore before: Int, changeCountAfter after: Int, string: String?) -> String? {
        guard after != before, let string,
              !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return string
    }

    /// The clipboard goes back to what it held only while it still holds
    /// what the copy put there: a copy the person made in between is theirs.
    static func shouldRestore(changeCountAfterCopy: Int, current: Int) -> Bool {
        current == changeCountAfterCopy
    }

    /// Writes `snapshot` back when the clipboard is unchanged since the copy;
    /// the new change count, or nil when it was left alone.
    @discardableResult
    static func restore(_ snapshot: TranslateClipboardSnapshot, to pasteboard: NSPasteboard,
                        ifUnchangedSince changeCount: Int) -> Int? {
        guard shouldRestore(changeCountAfterCopy: changeCount, current: pasteboard.changeCount) else { return nil }
        snapshot.write(to: pasteboard)
        return pasteboard.changeCount
    }
}
