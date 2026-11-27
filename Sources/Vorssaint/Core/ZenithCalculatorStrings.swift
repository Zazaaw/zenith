// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: the Calculator's text, for its island page, its Settings page
// and its Command Bar rows. English in every language, by the owner's
// decision, as Mechakey's. Settings search still finds the page by
// Indonesian aliases (CalculatorSearch).

struct ZenithCalculatorStrings {
    // Page.
    let title = "Calculator"
    let subtitle = "Sums, percentages and functions, in the island and the Command Bar, answered as you type."
    let enable = "Enable Calculator"
    let enableHint = "Off, nothing shows in the island or the Command Bar."

    // Where.
    let placesSection = "Where it shows"
    let showInIsland = "Show in the island"
    let showInIslandCaption = "A Calculator page in the island, ⌥⌘= while the island is open."
    let showInCommandBar = "Answer in the Command Bar"
    let showInCommandBarCaption = "Type a sum in the Command Bar and its answer leads the list; Return copies it. The Command Bar answers sums with units itself."

    // Answers.
    let answersSection = "Answers"
    let decimalPlaces = "Decimal places"
    let decimalPlacesCaption = "Automatic shows up to ten and drops trailing zeros."
    let automatic = "Automatic"
    let clearHistory = "Clear History"
    let clearHistoryCaption = "The last \(CalculatorHistory.limit) answers, kept on this Mac only."
    let syntaxFootnote = "+ − × ÷ ^ %, brackets, sqrt sin cos tan log ln abs round, pi and e. Angles are radians; add ° for degrees."

    // Island.
    let placeholder = "Type a sum"
    let history = "History"
    let noHistory = "Answers you keep show here."
    let copy = "Copy"
    let copied = "Copied"
    let clear = "Clear"
    let openCalculator = "Calculator"
    let openCalculatorSubtitle = "Open the island’s Calculator"

    // Stage.
    let stageCaption = "The answer appears as you type"
    let stageIsland = "Island"
    let stageCommandBar = "Command Bar"
    let summary = "Sums and functions, answered as you type"

    func places(_ value: Int) -> String {
        value == CalculatorFormat.automatic ? automatic : "\(value)"
    }

    /// Why there is no answer, in a few words.
    func error(_ error: CalculatorError) -> String {
        switch error {
        case .empty: return ""
        case .tooLong: return "Too long"
        case .unexpected(let word): return word.isEmpty ? "Can’t read that" : "Can’t read “\(word)”"
        case .unbalanced: return "A bracket is closed twice"
        case .incomplete: return "…"
        case .divisionByZero: return "Can’t divide by zero"
        case .domain(let name): return "Outside \(name)’s range"
        case .notFinite: return "Too large"
        }
    }

    /// Every string, for the coverage tests.
    var all: [String] {
        Mirror(reflecting: self).children.compactMap { $0.value as? String }
    }
}

extension ZenithStrings {
    /// English in every language (see the file's note).
    static func calculator(_ language: AppLanguage) -> ZenithCalculatorStrings {
        ZenithCalculatorStrings()
    }
}

enum CalculatorSearch {
    static let aliases = ["calculator", "calc", "math", "maths", "sum", "arithmetic", "percent", "percentage",
                          "sqrt", "square root", "sine", "logarithm",
                          "kalkulator", "hitung", "menghitung", "hitungan", "matematika", "persen", "akar"]

    static func keywords(_ language: AppLanguage) -> [String] {
        let text = ZenithStrings.calculator(language)
        return [text.enable, text.showInIsland, text.showInCommandBar, text.decimalPlaces]
    }
}
