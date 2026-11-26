// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import Foundation

/// Zenith fork: Translate's decisions. Which language a text goes into (the
/// "already in the target, use the second" rule included) and what the
/// preferences say when unset; language codes; how a selection is tidied;
/// keeping and putting back the clipboard on a private pasteboard; and the
/// page's strings and search words. No Translation framework, no window, no
/// real clipboard.
enum TranslateTests {
    static func run(_ suite: TestSuite) {
        codes(suite)
        targetChoice(suite)
        preferences(suite)
        detection(suite)
        routes(suite)
        speech(suite)
        normalisation(suite)
        preparing(suite)
        clipboard(suite)
        strings(suite)
    }

    // MARK: Languages

    private static func codes(_ suite: TestSuite) {
        typealias Code = TranslateLanguageCode
        let cases: [(String, String?)] = [
            ("en", "en"), ("en-US", "en"), ("en_GB", "en"), (" id-ID ", "id"), ("in", "id"), ("iw", "he"),
            ("zh-Hans", "zh-Hans"), ("zh-CN", "zh-Hans"), ("zh-Hans-CN", "zh-Hans"), ("zh", "zh-Hans"),
            ("zh-TW", "zh-Hant"), ("zh-Hant", "zh-Hant"), ("zh-HK", "zh-Hant"), ("zh_Hant_TW", "zh-Hant"),
            ("pt-BR", "pt"), ("PT", "pt"), ("und", nil), ("", nil), ("x", nil), ("12", nil), ("english", nil),
        ]
        for (raw, expected) in cases {
            suite.expect(Code.canonical(raw) == expected, "\"\(raw)\" reads as \(expected ?? "nothing"): \(Code.canonical(raw) ?? "nil")")
        }
        suite.expect(Code.same("en-US", "en-GB"), "British and American English are one language")
        suite.expect(!Code.same("zh-CN", "zh-TW"), "Simplified and Traditional Chinese are two")
        suite.expect(!Code.same(nil, "en") && !Code.same("und", "und"), "an unknown language matches nothing")
        suite.expect(Code.displayName("id") == "Indonesian" && Code.displayName("en") == "English",
                     "languages are named in English")
        let menu = Code.menu(["id-ID", "en-US", "en-GB", "in", "fr"])
        suite.expect(menu == ["en", "fr", "id"], "a menu lists each language once, by name: \(menu)")
        suite.expect(Code.fallbackLanguages.allSatisfy { Code.canonical($0) == $0 },
                     "the built-in list is in the canonical form")
    }

    private static func targetChoice(_ suite: TestSuite) {
        let choose = TranslateTargetChoice.choose
        suite.expect(choose("ja", "id", "en") == TranslateTargetChoice(target: "id", usedSecond: false),
                     "a text in another language goes into the first language")
        suite.expect(choose("en-US", "id", "en") == TranslateTargetChoice(target: "id", usedSecond: false),
                     "English into Indonesian")
        suite.expect(choose("id", "id", "en") == TranslateTargetChoice(target: "en", usedSecond: true),
                     "already in Indonesian: into the second language, English")
        suite.expect(choose("in", "id-ID", "en_US") == TranslateTargetChoice(target: "en", usedSecond: true),
                     "the rule holds whatever form the codes come in")
        suite.expect(choose("en", "en", "id") == TranslateTargetChoice(target: "id", usedSecond: true),
                     "and the other way round, English into Indonesian")
        suite.expect(choose("id", "id", nil) == TranslateTargetChoice(target: nil, usedSecond: false),
                     "already in the only language there is: nothing to translate into")
        suite.expect(choose("id", "id", "id-ID") == TranslateTargetChoice(target: nil, usedSecond: false),
                     "a second language equal to the first counts as none")
        suite.expect(choose(nil, "id", "en") == TranslateTargetChoice(target: "id", usedSecond: false),
                     "an unknown language goes into the first language")
        suite.expect(choose("zh-TW", "zh-Hans", "en") == TranslateTargetChoice(target: "zh-Hans", usedSecond: false),
                     "Traditional Chinese goes into Simplified, not to the second language")
        suite.expect(choose("de", "", "en").target == "en", "no first language reads as English")
    }

    private static func preferences(_ suite: TestSuite) {
        let domain = "com.vorssaint.tests.translate-preferences"
        let defaults = UserDefaults(suiteName: domain)!
        defaults.removePersistentDomain(forName: domain)
        defer { defaults.removePersistentDomain(forName: domain) }
        let read = { (preferred: [String]) in TranslatePreferences.read(defaults, preferredLanguages: preferred) }

        suite.expect(defaults.object(forKey: TranslateDefaults.enabled) == nil
                     && !defaults.bool(forKey: TranslateDefaults.enabled), "Translate starts off")
        suite.expect(read(["id-ID", "en-US"]) == TranslatePreferences(primary: "id", second: "en", showDetection: true),
                     "unset: the system's language, then its next one, detection shown")
        suite.expect(read(["id-ID"]).second == "en", "a single system language that isn't English pairs with English")
        suite.expect(read(["en-US"]).second == nil, "English alone has no second language")
        suite.expect(read(["en-GB", "en-US", "id"]).second == "id", "the next language that differs, not another English")
        suite.expect(read([]).primary == "en", "no system list reads as English")

        defaults.set("ja", forKey: TranslateDefaults.target)
        suite.expect(read(["id-ID", "en-US"]) == TranslatePreferences(primary: "ja", second: "id", showDetection: true),
                     "a chosen language comes first; the second is the system's first that differs")
        defaults.set("", forKey: TranslateDefaults.target)
        suite.expect(read(["id-ID", "en-US"]).primary == "id", "an empty choice means the system's language")
        defaults.set("fr", forKey: TranslateDefaults.secondTarget)
        suite.expect(read(["id-ID", "en-US"]).second == "fr", "a chosen second language")
        defaults.set("id", forKey: TranslateDefaults.secondTarget)
        suite.expect(read(["id-ID", "en-US"]).second == nil, "a second language equal to the first is none")
        defaults.set(TranslateDefaults.noneValue, forKey: TranslateDefaults.secondTarget)
        suite.expect(read(["id-ID", "en-US"]).second == nil, "None turns the second language off")
        defaults.set(false, forKey: TranslateDefaults.showDetection)
        suite.expect(!read(["id-ID"]).showDetection, "detection can be hidden")
        suite.expect(TranslateDefaults.backupKeys.count == 5 && TranslateDefaults.backupKeys.allSatisfy { $0.hasPrefix("zenithTranslate") },
                     "every preference joins the backup, under the feature's own prefix")
        suite.expect(SettingsBackupSupport.exportKeys().isSuperset(of: TranslateDefaults.backupKeys),
                     "the settings backup carries Translate's preferences")
    }

    private static func detection(_ suite: TestSuite) {
        suite.expect(TranslateDetection.pick(["id": 0.82, "ms": 0.15]) == TranslateDetection(code: "id", confidence: 0.82),
                     "the likeliest language wins")
        suite.expect(TranslateDetection.pick(["en": 0.2, "nl": 0.18]) == nil, "too unsure to name a language")
        suite.expect(TranslateDetection.pick([:]) == nil, "nothing found")
        suite.expect(TranslateDetection.pick(["zh-Hant": 0.6, "zh-Hans": 0.3])?.code == "zh-Hant",
                     "Chinese keeps its script")
        suite.expect(TranslateDetection.pick(["und": 0.9, "en": 0.5])?.code == "en", "undetermined is skipped")
        suite.expect(TranslateDetection.pick(["fr": 0.5, "de": 0.5])?.code == "de", "a tie is settled the same way every time")
    }

    private static func routes(_ suite: TestSuite) {
        let choose = TranslateRoute.choose
        suite.expect(choose(.installed, true, true) == .direct, "installed on macOS 26: a direct session")
        suite.expect(choose(.installed, false, true) == .hosted, "installed on macOS 15: the card hosts the session")
        suite.expect(choose(.installed, true, false) == .hosted, "no known source: the hosted session identifies it")
        suite.expect(choose(.notDownloaded, true, true) == .download, "not downloaded: offer the download")
        suite.expect(choose(.unsupported, true, true) == .unsupported, "unsupported stays unsupported")
    }

    private static func speech(_ suite: TestSuite) {
        let voices = ["en-US", "en-GB", "en-AU", "id-ID", "zh-CN", "zh-TW", "zh-HK", "ja-JP"]
        let speak = TranslateLanguageCode.speechLanguage
        suite.expect(speak("en", voices, "GB") == "en-GB", "English in the person's region")
        suite.expect(speak("en", voices, "ID") == "en-AU", "else the first English voice, in a stable order")
        suite.expect(speak("id", voices, nil) == "id-ID", "Indonesian")
        suite.expect(speak("zh-Hans", voices, "TW") == "zh-CN" && speak("zh-Hant", voices, "CN") == "zh-TW",
                     "Chinese by its script, whatever the region")
        suite.expect(speak("ko", voices, "KR") == nil, "no voice, nothing to speak with")
    }

    // MARK: Text

    private static func normalisation(_ suite: TestSuite) {
        let normalize = TranslateText.normalize
        suite.expect(normalize("  Hello   world \t again  ") == "Hello world again", "spaces collapse and trim")
        suite.expect(normalize("One\r\nTwo\rThree") == "One\nTwo\nThree", "line endings become one kind")
        suite.expect(normalize("soft\u{00AD}ware\u{200B} and\u{00A0}more\u{FEFF}") == "software and more",
                     "invisible characters go, a no-break space is a space")
        suite.expect(normalize("This sentence was wrapped\nby the PDF it came from.") ==
                     "This sentence was wrapped by the PDF it came from.", "a wrapped sentence is joined")
        suite.expect(normalize("A word is transla-\ntion here.") == "A word is translation here.",
                     "a word hyphenated across the break is mended")
        suite.expect(normalize("First line.\nSecond line.") == "First line.\nSecond line.",
                     "a break after a full stop stays")
        suite.expect(normalize("Shopping list\nApples") == "Shopping list\nApples", "a capitalised line stays its own")
        suite.expect(normalize("Para one.\n\n\n\nPara two.") == "Para one.\n\nPara two.",
                     "paragraphs keep one blank line between them")
        suite.expect(normalize("Steps\n1. open it\n2. close it") == "Steps\n1. open it\n2. close it",
                     "numbered steps are not joined")
        suite.expect(normalize("Items:\n• one\n• two") == "Items:\n• one\n• two", "bullets are not joined")
        suite.expect(normalize("Things to do\na) first\nb) second") == "Things to do\na) first\nb) second",
                     "lettered steps are not joined")
        suite.expect(normalize("日本語の文章\nです。") == "日本語の文章\nです。", "scripts without case are left as they are")
        suite.expect(normalize("\n\n  \n") == "", "only whitespace is nothing")
    }

    private static func preparing(_ suite: TestSuite) {
        suite.expect(TranslateText.prepare("  Selamat pagi  ") == .init(text: "Selamat pagi", truncated: false),
                     "a selection is prepared tidy")
        suite.expect(TranslateText.prepare("  \n ") == nil, "nothing selected")
        suite.expect(TranslateText.prepare("12 345 — 6.7%") == nil, "figures alone have nothing to translate")
        let long = Array(repeating: "word", count: 2_000).joined(separator: " ")
        let prepared = TranslateText.prepare(long)
        suite.expect(prepared?.truncated == true && (prepared?.text.count ?? .max) <= TranslateText.maximumLength,
                     "a long text is cut under the limit")
        suite.expect(prepared?.text.hasSuffix("word") == true, "and cut between words")
        let unbroken = String(repeating: "a", count: 6_000)
        suite.expect(TranslateText.prepare(unbroken)?.text.count == TranslateText.maximumLength,
                     "a text with no space near the limit is cut at the limit")
    }

    // MARK: Clipboard

    private static func clipboard(_ suite: TestSuite) {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("ZenithTranslateTests-" + UUID().uuidString))
        defer { pasteboard.releaseGlobally() }

        // The person's clipboard: rich text with a plain fallback, and a second item.
        pasteboard.clearContents()
        let first = NSPasteboardItem()
        first.setString("Bold words", forType: .string)
        first.setData(Data("{\\rtf1 Bold words}".utf8), forType: .rtf)
        let second = NSPasteboardItem()
        second.setString("https://example.com", forType: .URL)
        pasteboard.writeObjects([first, second])

        guard let snapshot = TranslateClipboardSnapshot.take(from: pasteboard) else {
            suite.expect(false, "the clipboard can be kept")
            return
        }
        suite.expect(snapshot.items.count == 2 && snapshot.items[0].count >= 2, "every item and flavour is kept")
        suite.expect(snapshot.byteCount > 0, "and counted")
        suite.expect(TranslateClipboardSnapshot.take(from: pasteboard, maximumBytes: 4) == nil,
                     "too large to keep: the copy is not made")

        // The simulated copy.
        let before = pasteboard.changeCount
        pasteboard.clearContents()
        pasteboard.setString("Teks yang dipilih", forType: .string)
        let afterCopy = pasteboard.changeCount
        suite.expect(TranslateClipboard.copiedText(changeCountBefore: before, changeCountAfter: afterCopy,
                                                   string: pasteboard.string(forType: .string)) == "Teks yang dipilih",
                     "a copy that changed the clipboard gives the selection")
        suite.expect(TranslateClipboard.copiedText(changeCountBefore: before, changeCountAfter: before,
                                                   string: "Bold words") == nil,
                     "an unchanged clipboard means nothing was selected, not its old text")
        suite.expect(TranslateClipboard.copiedText(changeCountBefore: before, changeCountAfter: afterCopy,
                                                   string: "  \n") == nil, "a copy of only whitespace is nothing")
        suite.expect(TranslateClipboard.copiedText(changeCountBefore: before, changeCountAfter: afterCopy,
                                                   string: nil) == nil, "a copy of an image is nothing to translate")

        // Put back.
        let restored = TranslateClipboard.restore(snapshot, to: pasteboard, ifUnchangedSince: afterCopy)
        suite.expect(restored != nil && restored != afterCopy, "the clipboard is put back")
        let items = pasteboard.pasteboardItems ?? []
        suite.expect(items.count == 2
                     && items[0].string(forType: .string) == "Bold words"
                     && items[0].data(forType: .rtf) == Data("{\\rtf1 Bold words}".utf8)
                     && items[1].string(forType: .URL) == "https://example.com",
                     "exactly as it was, rich text and all")

        // A copy the person makes in between is theirs.
        pasteboard.clearContents()
        pasteboard.setString("selection", forType: .string)
        let ours = pasteboard.changeCount
        pasteboard.clearContents()
        pasteboard.setString("the person's own copy", forType: .string)
        suite.expect(TranslateClipboard.restore(snapshot, to: pasteboard, ifUnchangedSince: ours) == nil,
                     "a newer copy is not overwritten")
        suite.expect(pasteboard.string(forType: .string) == "the person's own copy", "and stays on the clipboard")
        suite.expect(TranslateClipboard.shouldRestore(changeCountAfterCopy: 7, current: 7)
                     && !TranslateClipboard.shouldRestore(changeCountAfterCopy: 7, current: 8),
                     "restoring follows the change count alone")

        // An empty clipboard stays empty.
        pasteboard.clearContents()
        let empty = TranslateClipboardSnapshot.take(from: pasteboard)
        suite.expect(empty == TranslateClipboardSnapshot(items: []), "an empty clipboard is kept as empty")
        pasteboard.setString("copied", forType: .string)
        if let empty { TranslateClipboard.restore(empty, to: pasteboard, ifUnchangedSince: pasteboard.changeCount) }
        suite.expect((pasteboard.pasteboardItems ?? []).isEmpty, "and put back empty")
    }

    // MARK: Strings

    private static func strings(_ suite: TestSuite) {
        let text = ZenithStrings.translate(.de)
        suite.expect(text.all.count > 50 && text.all.allSatisfy { !$0.isEmpty }, "every Translate string has text")
        suite.expect(text.title == ZenithStrings.translate(.enUS).title, "English in every language")
        suite.expect(text.name(text.alreadyIn, "English") == "This is already in English.", "the name fills in")
        suite.expect(text.pair(text.pairNotDownloaded, from: "English", to: "Indonesian")
                     == "English → Indonesian isn’t downloaded yet.", "the pair fills in")
        suite.expect(["terjemah", "terjemahan", "bahasa", "translate"].allSatisfy(TranslateSearch.aliases.contains),
                     "the page's Indonesian and English aliases")
    }
}
