// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: the Calculator's parser and evaluator (operators, precedence,
/// percentages, functions, constants, the person's decimal separator, the
/// errors), its formatting, its preferences and its history. No island, no
/// Command Bar, no clipboard.
enum CalculatorTests {
    static func run(_ suite: TestSuite) {
        arithmetic(suite)
        percentages(suite)
        functions(suite)
        separators(suite)
        errors(suite)
        calculationIntent(suite)
        formatting(suite)
        preferences(suite)
        history(suite)
    }

    private static func close(_ a: Double?, _ b: Double, tolerance: Double = 1e-9) -> Bool {
        guard let a else { return false }
        return abs(a - b) <= tolerance * max(1, abs(b))
    }

    private static func expectValue(_ suite: TestSuite, _ input: String, _ expected: Double,
                                    separator: String = ".") {
        let value = CalculatorEngine.value(input, decimalSeparator: separator)
        suite.expect(close(value, expected), "\"\(input)\" is \(expected): \(value.map { "\($0)" } ?? "no answer")")
    }

    private static func expectError(_ suite: TestSuite, _ input: String, _ expected: CalculatorError,
                                    separator: String = ".") {
        let result = CalculatorEngine.evaluate(input, decimalSeparator: separator)
        switch result {
        case .success(let answer):
            suite.expect(false, "\"\(input)\" should fail with \(expected), got \(answer.value)")
        case .failure(let error):
            suite.expect(error == expected, "\"\(input)\" fails with \(expected): \(error)")
        }
    }

    // MARK: Arithmetic

    private static func arithmetic(_ suite: TestSuite) {
        let cases: [(String, Double)] = [
            ("1+2", 3), ("2+3*4", 14), ("(2+3)*4", 20), ("10-4-3", 3), ("100/10/2", 5),
            ("2^3", 8), ("2^3^2", 512), ("-2^2", -4), ("(-2)^2", 4), ("2^-1", 0.5),
            ("2*-3", -6), ("--5", 5), ("+7", 7), ("7 − 2", 5), ("6 × 7", 42), ("84 ÷ 2", 42),
            ("3 x 4", 12), ("3x4", 12), ("10 : 4", 2.5), ("1.5 + 1.25", 2.75), (".5 + .5", 1),
            ("2(3+4)", 14), ("(1+2)(3+4)", 21), ("(2)3", 6), ("2pi", 2 * .pi), ("pi", .pi), ("π/2", .pi / 2),
            ("e", M_E), ("2e", 2 * M_E), ("1e3", 1000), ("1.5E-3", 0.0015), ("2e+2", 200),
            ("1,234 + 1", 1235), ("1,000,000 / 1,000", 1000), ("1_000 * 2", 2000),
            ("3!", 6), ("0!", 1), ("5! / 3!", 20), ("2²", 4), ("2³", 8), ("[1+2]*3", 9),
            ("2 + 3 =", 5), ("  42  ", 42), ("0.1 + 0.2", 0.3), ("10 - 20", -10),
            ("((((1))))", 1), ("1/3*3", 1), ("12 * (3 + 4) - 5 ^ 2", 59),
        ]
        for (input, expected) in cases { expectValue(suite, input, expected) }
    }

    private static func percentages(_ suite: TestSuite) {
        let cases: [(String, Double)] = [
            ("10%", 0.1), ("50% * 8", 4), ("200 + 10%", 220), ("200 - 10%", 180), ("80 * 25%", 20),
            ("200 + 10% + 10%", 242), ("50%+50%", 0.75), ("(200 + 10%) * 2", 440), ("1000 / 50%", 2000),
        ]
        for (input, expected) in cases { expectValue(suite, input, expected) }
    }

    private static func functions(_ suite: TestSuite) {
        let cases: [(String, Double)] = [
            ("sqrt(16)", 4), ("sqrt 16", 4), ("√16", 4), ("√(9+16)", 5), ("sqrt 9 + 1", 4), ("sqrt(9 + 7)", 4),
            ("2 sqrt 9", 6), ("sqrt 2^2", 2), ("sin(0)", 0), ("sin(pi/2)", 1), ("sin(pi)", 0),
            ("sin 30°", 0.5), ("cos(0)", 1), ("cos(60°)", 0.5), ("cos pi", -1), ("tan(45°)", 1), ("tan(0)", 0),
            ("log(1000)", 3), ("lg 100", 2), ("ln(e)", 1), ("ln(1)", 0), ("abs(-3.5)", 3.5), ("abs -2", 2),
            ("round(2.5)", 3), ("round(-2.5)", -3), ("round(2.49)", 2), ("SQRT(4)", 2), ("Sin(0)", 0),
            ("log(10)*ln(e)", 1), ("sqrt(sqrt(16))", 2), ("-sqrt(4)", -2), ("2^sqrt(4)", 4),
        ]
        for (input, expected) in cases { expectValue(suite, input, expected) }
        // Brackets left open at the end close themselves, and say how many.
        let open = try? CalculatorEngine.evaluate("sqrt(9", decimalSeparator: ".").get()
        suite.expect(open?.value == 3 && open?.closedBrackets == 1, "\"sqrt(9\" closes itself: \(String(describing: open))")
        let two = try? CalculatorEngine.evaluate("2*(3+(4", decimalSeparator: ".").get()
        suite.expect(two?.value == 14 && two?.closedBrackets == 2, "two open brackets close: \(String(describing: two))")
    }

    private static func separators(_ suite: TestSuite) {
        // A comma locale (Indonesian, German): the comma is the decimal point.
        expectValue(suite, "1,5 + 1,5", 3, separator: ",")
        expectValue(suite, "2,5 * 2", 5, separator: ",")
        expectValue(suite, ",5 * 4", 2, separator: ",")
        // A keypad's dot is a decimal point there too.
        expectValue(suite, "1.5 + 1,5", 3, separator: ",")
        // In a dot locale a comma only groups thousands.
        expectError(suite, "1,5 + 1", .unexpected(","))
        expectError(suite, "1,23", .unexpected(","))
        expectValue(suite, "12,345.5", 12345.5)
        // Full-width digits and operators, as an IME types them.
        expectValue(suite, "１２＋３", 15)
    }

    private static func errors(_ suite: TestSuite) {
        expectError(suite, "", .empty)
        expectError(suite, "   ", .empty)
        expectError(suite, "=", .empty)
        expectError(suite, String(repeating: "1+", count: 130) + "1", .tooLong)
        expectError(suite, "1/0", .divisionByZero)
        expectError(suite, "5 / (2 - 2)", .divisionByZero)
        expectError(suite, "sqrt(-1)", .domain("sqrt"))
        expectError(suite, "log(0)", .domain("log"))
        expectError(suite, "ln(-1)", .domain("ln"))
        expectError(suite, "tan(90°)", .domain("tan"))
        expectError(suite, "(-8)^(1/3)", .domain("^"))
        expectError(suite, "2.5!", .domain("!"))
        expectError(suite, "171!", .notFinite)
        expectError(suite, "10^400", .notFinite)
        expectError(suite, "2 +", .incomplete)
        expectError(suite, "2 *", .incomplete)
        expectError(suite, "sqrt", .incomplete)
        expectError(suite, "(", .incomplete)
        expectError(suite, "-", .incomplete)
        expectError(suite, "1 + 2)", .unbalanced)
        expectError(suite, ")", .unbalanced)
        expectError(suite, "2 3", .unexpected("3.0"))
        expectError(suite, "hello", .unexpected("hello"))
        expectError(suite, "2 + apples", .unexpected("apples"))
        expectError(suite, "max(1)", .unexpected("max"))
        expectError(suite, "1 $ 2", .unexpected("$"))
        expectError(suite, "2 ** 3", .incomplete)
    }

    private static func calculationIntent(_ suite: TestSuite) {
        func intent(_ input: String) -> Bool? {
            try? CalculatorEngine.evaluate(input, decimalSeparator: ".").get().isCalculation
        }
        for input in ["42", "pi", "e", "(5)", "1,000", "-3"] {
            suite.expect(intent(input) == false, "\"\(input)\" is a value, not a calculation")
        }
        for input in ["1+1", "2pi", "sqrt 4", "10%", "sin 30°", "3!", "2^2", "2(3)"] {
            suite.expect(intent(input) == true, "\"\(input)\" asks for a calculation")
        }
    }

    // MARK: Formatting

    private static func formatting(_ suite: TestSuite) {
        typealias F = CalculatorFormat
        let cases: [(Double, Int, String, String?, String)] = [
            (3, F.automatic, ".", nil, "3"), (0.1 + 0.2, F.automatic, ".", nil, "0.3"),
            (1.0 / 3, F.automatic, ".", nil, "0.3333333333"), (2.5, F.automatic, ",", nil, "2,5"),
            (1234567.891, F.automatic, ".", ",", "1,234,567.891"), (1234567.891, F.automatic, ",", ".", "1.234.567,891"),
            (-1234.5, F.automatic, ".", ",", "-1,234.5"), (999, F.automatic, ".", ",", "999"),
            (2.0 / 3, 2, ".", nil, "0.67"), (2, 2, ".", nil, "2.00"), (2.5, 0, ".", nil, "3"),
            (-0.0001, 2, ".", nil, "0.00"), (1e20, F.automatic, ".", nil, "1e20"), (1.5e-12, F.automatic, ".", nil, "1.5e-12"),
            (-2.5e16, F.automatic, ",", nil, "-2,5e16"), (0, F.automatic, ".", nil, "0"), (-0.0, F.automatic, ".", nil, "0"),
            (1e-10, 4, ".", nil, "0.0000"), (.infinity, F.automatic, ".", nil, "—"),
        ]
        for (value, places, separator, grouping, expected) in cases {
            let text = F.string(value, places: places, decimalSeparator: separator, grouping: grouping)
            suite.expect(text == expected, "\(value) at \(places) places is \"\(expected)\": \"\(text)\"")
        }
        let indonesian = Locale(identifier: "id_ID")
        suite.expect(CalculatorText.display(12345.5, places: F.automatic, locale: indonesian) == "12.345,5",
                     "Indonesian groups with dots and decimals with a comma")
        suite.expect(CalculatorText.copied(12345.5, places: F.automatic, locale: indonesian) == "12345,5",
                     "a copied answer has no grouping, so it pastes back into a sum")
        suite.expect(CalculatorEngine.value(CalculatorText.copied(12345.5, places: F.automatic, locale: indonesian),
                                            decimalSeparator: ",") == 12345.5,
                     "a copied answer reads back as the same number")
    }

    // MARK: Preferences and history

    private static func preferences(_ suite: TestSuite) {
        let domain = "com.vorssaint.tests.calculator"
        guard let defaults = UserDefaults(suiteName: domain) else { return suite.expect(false, "test defaults") }
        defaults.removePersistentDomain(forName: domain)
        defer { defaults.removePersistentDomain(forName: domain) }
        let fresh = CalculatorPreferences(defaults: defaults)
        suite.expect(!fresh.enabled && fresh.showInIsland && fresh.showInCommandBar
                        && fresh.decimalPlaces == CalculatorFormat.automatic,
                     "off by default; once on it shows in the island and the Command Bar, automatic decimals")
        suite.expect(!CalculatorPreferences.showsInIsland(defaults) && !CalculatorPreferences.showsInCommandBar(defaults),
                     "off, it shows nowhere")
        defaults.set(true, forKey: CalculatorDefaults.enabled)
        suite.expect(CalculatorPreferences.showsInIsland(defaults) && CalculatorPreferences.showsInCommandBar(defaults),
                     "on, it shows in both")
        defaults.set(false, forKey: CalculatorDefaults.showInIsland)
        suite.expect(!CalculatorPreferences.showsInIsland(defaults) && CalculatorPreferences.showsInCommandBar(defaults),
                     "each place has its own switch")
        defaults.set(7, forKey: CalculatorDefaults.decimalPlaces)
        suite.expect(CalculatorPreferences(defaults: defaults).decimalPlaces == CalculatorFormat.automatic,
                     "a stored value Settings does not offer reads as automatic")
        defaults.set(2, forKey: CalculatorDefaults.decimalPlaces)
        suite.expect(CalculatorPreferences(defaults: defaults).decimalPlaces == 2, "two decimal places")
        suite.expect(!CalculatorDefaults.backupKeys.contains(CalculatorDefaults.history)
                        && CalculatorDefaults.backupKeys.count == 4
                        && CalculatorDefaults.backupKeys.allSatisfy { $0.hasPrefix("zenithCalculator") },
                     "the backup carries the preferences, never the history")
    }

    private static func history(_ suite: TestSuite) {
        var history = CalculatorHistory()
        history.add("1+1", value: 2)
        history.add("2*3", value: 6)
        suite.expect(history.entries.map(\.expression) == ["2*3", "1+1"], "newest first")
        history.add(" 1+1 ", value: 2)
        suite.expect(history.entries.map(\.expression) == ["1+1", "2*3"], "the same sum moves to the top, once")
        history.add("", value: 3)
        history.add("1/0", value: .infinity)
        suite.expect(history.entries.count == 2, "an empty sum or an endless answer is not kept")
        for index in 0..<30 { history.add("\(index)+0", value: Double(index)) }
        suite.expect(history.entries.count == CalculatorHistory.limit && history.entries.first?.expression == "29+0",
                     "the oldest fall off past \(CalculatorHistory.limit)")
        let restored = CalculatorHistory(data: history.data)
        suite.expect(restored == history, "the history survives being stored")
        suite.expect(CalculatorHistory(data: Data("nonsense".utf8)).entries.isEmpty
                        && CalculatorHistory(data: nil).entries.isEmpty,
                     "unreadable storage starts an empty history")
        history.clear()
        suite.expect(history.entries.isEmpty, "Clear empties it")
    }
}
