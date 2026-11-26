// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation
import NaturalLanguage
import Translation

// Zenith fork: Translate's reach into the system. NaturalLanguage names the
// text's language; LanguageAvailability says whether a pair is downloaded,
// can be downloaded, or can't be translated at all; and on macOS 26 a
// session is made straight from installed languages. Everything else (macOS
// 15, an unknown source, a download) goes through the SwiftUI host that the
// card and the Settings page carry (`translationTask`). All of it on this
// Mac: Translation never sends the text anywhere.

@available(macOS 15.0, *)
enum TranslateEngine {
    /// How much of a long text detection reads: enough to be sure, cheap
    /// enough to run on every press.
    private static let detectionSample = 1_000

    static func detect(_ text: String) -> TranslateDetection? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(String(text.prefix(detectionSample)))
        let hypotheses = recognizer.languageHypotheses(withMaximum: 3)
        return TranslateDetection.pick(Dictionary(hypotheses.map { ($0.key.rawValue, $0.value) },
                                                  uniquingKeysWith: { max($0, $1) }))
    }

    /// Whether `from` → `to` is installed. With no known source, the
    /// framework identifies the text's language itself.
    static func status(from: String?, to: String, text: String) async -> TranslatePairStatus {
        let availability = LanguageAvailability()
        let target = Locale.Language(identifier: to)
        let status: LanguageAvailability.Status
        if let from {
            status = await availability.status(from: Locale.Language(identifier: from), to: target)
        } else {
            status = (try? await availability.status(for: text, to: target)) ?? .unsupported
        }
        switch status {
        case .installed: return .installed
        case .supported: return .notDownloaded
        case .unsupported: return .unsupported
        @unknown default: return .unsupported
        }
    }

    /// A session can be made directly from installed languages.
    static var directAvailable: Bool {
        if #available(macOS 26.0, *) { return true }
        return false
    }

    /// Translates with a session made from the installed languages (macOS
    /// 26). Callers check the pair is installed first.
    static func translateDirect(_ text: String, from: String, to: String) async throws -> String {
        guard #available(macOS 26.0, *) else { throw CancellationError() }
        let session = TranslationSession(installedSource: Locale.Language(identifier: from),
                                         target: Locale.Language(identifier: to))
        return try await session.translate(text).targetText
    }

    /// The languages Translation knows, as Translate's codes, by name.
    static func supportedLanguages() async -> [String] {
        let languages = await LanguageAvailability().supportedLanguages
        let codes = languages.compactMap { TranslateLanguageCode.canonical($0.maximalIdentifier) }
        return TranslateLanguageCode.menu(codes.isEmpty ? TranslateLanguageCode.fallbackLanguages : codes)
    }

    static func configuration(from: String?, to: String) -> TranslationSession.Configuration {
        TranslationSession.Configuration(source: from.map { Locale.Language(identifier: $0) },
                                         target: Locale.Language(identifier: to))
    }
}
