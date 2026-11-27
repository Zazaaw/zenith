// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: the Calculator's parser and evaluator, pure Foundation so the
// tests reach every rule. Unit-less on purpose: the Command Bar keeps its own
// calculator for units and conversions, and this one answers the arithmetic
// and the functions that one leaves alone.
//
// Grammar, loosest first:
//
//     sum      = product (("+" | "-") product)*
//     product  = unary (("×" | "÷") unary | implicit unary)*
//     unary    = ("+" | "-") unary | power
//     power    = postfix ("^" unary)?             right-associative, -2^2 = -4
//     postfix  = primary ("%" | "°" | "!")*
//     primary  = number | constant | function primary-or-group | "(" sum ")"
//
// A percentage after + or - is a share of what comes before it, as on a
// pocket calculator (200 + 10% = 220); anywhere else it is a hundredth.
// Angles are radians; a degree sign converts (sin 30° = 0.5). Brackets still
// open at the end close themselves, so a live answer shows while typing.

/// Why an expression has no answer.
enum CalculatorError: Error, Equatable {
    case empty
    case tooLong
    /// A character or a word the calculator does not read.
    case unexpected(String)
    /// A closing bracket without an opening one.
    case unbalanced
    /// An operator with nothing after it, such as "2 +".
    case incomplete
    case divisionByZero
    /// A function asked outside its domain: the square root of a negative
    /// number, the logarithm of zero.
    case domain(String)
    /// The answer overflowed or is not a number.
    case notFinite
}

/// What an expression came to.
struct CalculatorAnswer: Equatable {
    let value: Double
    /// Brackets the calculator closed for the person: "sqrt(9" → ")".
    let closedBrackets: Int
    /// True when the input asks for a calculation (an operator, a function,
    /// a percentage or a degree), not a lone number or constant. The Command
    /// Bar answers only these, so a search for "e" or "2026" stays a search.
    let isCalculation: Bool
}

enum CalculatorEngine {
    /// Longer input is refused, as no one types a sum that long by hand.
    static let maximumLength = 240

    /// The functions the calculator knows, by every name it accepts.
    static let functions: [String: CalculatorFunction] = [
        "sqrt": .sqrt, "√": .sqrt, "sin": .sin, "cos": .cos, "tan": .tan,
        "log": .log, "lg": .log, "ln": .ln, "abs": .abs, "round": .round,
    ]

    static let constants: [String: Double] = ["pi": .pi, "π": .pi, "e": M_E]

    /// Evaluates `input`. `decimalSeparator` is the person's ("," in much of
    /// Europe and in Indonesia); a "." is read as a decimal point too, as a
    /// keypad types it. With "." as the separator, "," groups thousands
    /// ("1,234.5") and is refused anywhere else.
    static func evaluate(_ input: String, decimalSeparator: String = ".") -> Result<CalculatorAnswer, CalculatorError> {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.empty) }
        guard trimmed.count <= maximumLength else { return .failure(.tooLong) }
        var expression = trimmed
        // "2+3=" is the same sum.
        while expression.hasSuffix("=") { expression.removeLast() }
        guard !expression.trimmingCharacters(in: .whitespaces).isEmpty else { return .failure(.empty) }
        do {
            let tokens = try CalculatorTokenizer.tokens(expression, decimalSeparator: decimalSeparator)
            var parser = CalculatorParser(tokens: tokens)
            let value = try parser.parse()
            guard value.isFinite else { throw CalculatorError.notFinite }
            return .success(CalculatorAnswer(value: value == 0 ? 0 : value, closedBrackets: parser.closedBrackets,
                                             isCalculation: parser.isCalculation))
        } catch let error as CalculatorError {
            return .failure(error)
        } catch {
            return .failure(.unexpected(""))
        }
    }

    /// The answer's value, or nil.
    static func value(_ input: String, decimalSeparator: String = ".") -> Double? {
        try? evaluate(input, decimalSeparator: decimalSeparator).get().value
    }
}

enum CalculatorFunction: Equatable {
    case sqrt, sin, cos, tan, log, ln, abs, round

    func apply(_ x: Double) throws -> Double {
        switch self {
        case .sqrt:
            guard x >= 0 else { throw CalculatorError.domain("sqrt") }
            return x.squareRoot()
        case .sin: return CalculatorFunction.tidy(Foundation.sin(x))
        case .cos: return CalculatorFunction.tidy(Foundation.cos(x))
        case .tan:
            // At an odd multiple of π/2 the tangent has no value; the double
            // closest to it gives a huge one instead.
            let cosine = CalculatorFunction.tidy(Foundation.cos(x))
            guard cosine != 0 else { throw CalculatorError.domain("tan") }
            return CalculatorFunction.tidy(Foundation.tan(x))
        case .log:
            guard x > 0 else { throw CalculatorError.domain("log") }
            return Foundation.log10(x)
        case .ln:
            guard x > 0 else { throw CalculatorError.domain("ln") }
            return Foundation.log(x)
        case .abs: return Swift.abs(x)
        case .round: return x.rounded(.toNearestOrAwayFromZero)
        }
    }

    /// sin π is 1.2e-16 in doubles; a calculator says 0. Values that close to
    /// a whole number or a half are snapped to it.
    static func tidy(_ value: Double) -> Double {
        for target in [0, 0.5, -0.5, 1, -1] where Swift.abs(value - target) < 1e-12 { return target }
        return value
    }
}

// MARK: - Tokens

enum CalculatorToken: Equatable {
    case number(Double)
    case constant(Double)
    case function(CalculatorFunction)
    case plus, minus, times, divide, power, percent, degree, factorial
    case open, close
}

enum CalculatorTokenizer {
    static func tokens(_ input: String, decimalSeparator: String) throws -> [CalculatorToken] {
        let separator: Character = decimalSeparator.first ?? "."
        let chars = Array(input.folding(options: .widthInsensitive, locale: nil))
        var tokens: [CalculatorToken] = []
        var index = 0

        func isDigit(_ c: Character) -> Bool { c.isASCII && c.isNumber }

        while index < chars.count {
            let c = chars[index]
            if c.isWhitespace || c == "\u{00A0}" || c == "\u{202F}" {
                index += 1
                continue
            }
            if isDigit(c) || ((c == separator || c == ".") && index + 1 < chars.count && isDigit(chars[index + 1])) {
                let (value, next) = try number(chars, from: index, separator: separator)
                tokens.append(.number(value))
                index = next
                continue
            }
            switch c {
            case "+": tokens.append(.plus)
            case "-", "\u{2212}", "\u{2013}": tokens.append(.minus)
            case "*", "×", "\u{00B7}", "\u{22C5}": tokens.append(.times)
            case "x" where follows(tokens) && nextIsOperand(chars, after: index): tokens.append(.times)
            case "/", "÷": tokens.append(.divide)
            case ":" where follows(tokens): tokens.append(.divide)
            case "^": tokens.append(.power)
            case "%": tokens.append(.percent)
            case "°": tokens.append(.degree)
            case "!": tokens.append(.factorial)
            case "(", "[": tokens.append(.open)
            case ")", "]": tokens.append(.close)
            case "²": tokens += [.power, .number(2)]
            case "³": tokens += [.power, .number(3)]
            case "√": tokens.append(.function(.sqrt))
            case "π": tokens.append(.constant(.pi))
            default:
                guard c.isLetter else { throw CalculatorError.unexpected(String(c)) }
                var end = index
                while end < chars.count, chars[end].isLetter { end += 1 }
                let word = String(chars[index..<end]).lowercased()
                if let function = CalculatorEngine.functions[word] {
                    tokens.append(.function(function))
                } else if let constant = CalculatorEngine.constants[word] {
                    tokens.append(.constant(constant))
                } else if let split = splitConstants(word) {
                    // "pie", "epi": constants side by side multiply.
                    tokens += split
                } else {
                    throw CalculatorError.unexpected(word)
                }
                index = end
                continue
            }
            index += 1
        }
        return tokens
    }

    /// "x" is a times sign only between two operands ("2x3", "2 x pi"), so
    /// a stray word starting with x is not read as one.
    private static func follows(_ tokens: [CalculatorToken]) -> Bool {
        switch tokens.last {
        case .number?, .constant?, .close?, .percent?, .degree?, .factorial?: return true
        default: return false
        }
    }

    private static func nextIsOperand(_ chars: [Character], after index: Int) -> Bool {
        var next = index + 1
        while next < chars.count, chars[next].isWhitespace { next += 1 }
        guard next < chars.count else { return true }
        let c = chars[next]
        return c.isNumber || c == "(" || c == "." || c == "-" || c == "π" || c == "√" || c.isLetter
    }

    private static func splitConstants(_ word: String) -> [CalculatorToken]? {
        var rest = Substring(word)
        var tokens: [CalculatorToken] = []
        while !rest.isEmpty {
            if rest.hasPrefix("pi") {
                tokens.append(.constant(.pi))
                rest = rest.dropFirst(2)
            } else if rest.hasPrefix("e") {
                tokens.append(.constant(M_E))
                rest = rest.dropFirst()
            } else {
                return nil
            }
        }
        return tokens.count > 1 ? tokens : nil
    }

    /// Digits, one decimal point, thousands groups when "." is the decimal
    /// separator, and an exponent ("1.5e3", "2E-4").
    private static func number(_ chars: [Character], from start: Int,
                               separator: Character) throws -> (Double, Int) {
        var index = start
        var text = ""
        var seenPoint = false
        func isDigit(_ c: Character) -> Bool { c.isASCII && c.isNumber }
        while index < chars.count {
            let c = chars[index]
            if isDigit(c) {
                text.append(c)
            } else if (c == separator || c == ".") && !seenPoint {
                seenPoint = true
                text.append(".")
            } else if c == ",", separator == ".", !seenPoint, !text.isEmpty {
                // A thousands group: exactly three digits after the comma.
                let group = chars[(index + 1)...].prefix { isDigit($0) }
                guard group.count == 3 else { throw CalculatorError.unexpected(",") }
            } else if c == "_" || c == "'", !text.isEmpty, index + 1 < chars.count, isDigit(chars[index + 1]) {
                // 1_000 and 1'000 group digits too.
            } else {
                break
            }
            index += 1
        }
        // A scientific exponent: e or E, an optional sign, then digits.
        if index < chars.count, chars[index] == "e" || chars[index] == "E" {
            var probe = index + 1
            var exponent = "e"
            if probe < chars.count, chars[probe] == "+" || chars[probe] == "-" || chars[probe] == "\u{2212}" {
                exponent.append(chars[probe] == "+" ? "+" : "-")
                probe += 1
            }
            if probe < chars.count, isDigit(chars[probe]) {
                while probe < chars.count, isDigit(chars[probe]) {
                    exponent.append(chars[probe])
                    probe += 1
                }
                text += exponent
                index = probe
            }
        }
        if text.hasSuffix(".") { text.removeLast() }
        if text.hasPrefix(".") { text = "0" + text }
        guard let value = Double(text) else { throw CalculatorError.unexpected(text) }
        return (value, index)
    }
}

// MARK: - Parser

struct CalculatorParser {
    private let tokens: [CalculatorToken]
    private var position = 0
    private var depth = 0
    private(set) var closedBrackets = 0
    private(set) var isCalculation = false

    init(tokens: [CalculatorToken]) {
        self.tokens = tokens
    }

    private var current: CalculatorToken? { position < tokens.count ? tokens[position] : nil }

    private mutating func advance() { position += 1 }

    mutating func parse() throws -> Double {
        guard !tokens.isEmpty else { throw CalculatorError.empty }
        let value = try sum()
        if current == .close { throw CalculatorError.unbalanced }
        if let current { throw CalculatorError.unexpected(Self.describe(current)) }
        closedBrackets = depth
        return value
    }

    /// A value and whether it ended in a bare percentage, which + and - read
    /// as a share of the left side.
    private struct Term {
        var value: Double
        var percent: Bool
    }

    private mutating func sum() throws -> Double {
        var left = try product()
        var total = left.value
        while let token = current, token == .plus || token == .minus {
            isCalculation = true
            advance()
            guard current != nil else { throw CalculatorError.incomplete }
            let right = try product()
            let amount = right.percent ? total * right.value : right.value
            total = token == .plus ? total + amount : total - amount
            left = Term(value: total, percent: false)
        }
        return left.percent ? left.value : total
    }

    private mutating func product() throws -> Term {
        var term = try unary()
        while let token = current {
            switch token {
            case .times, .divide:
                isCalculation = true
                advance()
                guard current != nil else { throw CalculatorError.incomplete }
                let right = try unary()
                if token == .divide {
                    guard right.value != 0 else { throw CalculatorError.divisionByZero }
                    term = Term(value: term.value / right.value, percent: false)
                } else {
                    term = Term(value: term.value * right.value, percent: false)
                }
            case .constant, .function, .open, .number:
                // Side by side: 2π, 3(4+1), (1+2)(3+4), 2 sqrt 9, (2)3. Two
                // bare numbers in a row ("2 3") are a typo, not a product.
                if case .number = token, !Self.endsOperand(tokens[position - 1]) {
                    throw CalculatorError.unexpected(Self.describe(token))
                }
                isCalculation = true
                let right = try unary()
                term = Term(value: term.value * right.value, percent: false)
            default:
                return term
            }
        }
        return term
    }

    private mutating func unary() throws -> Term {
        if current == .minus || current == .plus {
            let negative = current == .minus
            advance()
            guard current != nil else { throw CalculatorError.incomplete }
            let inner = try unary()
            return Term(value: negative ? -inner.value : inner.value, percent: inner.percent)
        }
        return try power()
    }

    private mutating func power() throws -> Term {
        let base = try postfix()
        guard current == .power else { return base }
        isCalculation = true
        advance()
        guard current != nil else { throw CalculatorError.incomplete }
        let exponent = try unary()
        let value = Foundation.pow(base.value, exponent.value)
        guard !value.isNaN else { throw CalculatorError.domain("^") }
        return Term(value: value, percent: false)
    }

    private mutating func postfix() throws -> Term {
        var term = Term(value: try primary(), percent: false)
        while let token = current {
            switch token {
            case .percent:
                isCalculation = true
                advance()
                term = Term(value: term.value / 100, percent: true)
            case .degree:
                isCalculation = true
                advance()
                term = Term(value: term.value * .pi / 180, percent: false)
            case .factorial:
                isCalculation = true
                advance()
                term = Term(value: try Self.factorial(term.value), percent: false)
            default:
                return term
            }
        }
        return term
    }

    private mutating func primary() throws -> Double {
        guard let token = current else { throw CalculatorError.incomplete }
        switch token {
        case .number(let value):
            advance()
            return value
        case .constant(let value):
            advance()
            return value
        case .function(let function):
            isCalculation = true
            advance()
            guard current != nil else { throw CalculatorError.incomplete }
            // The argument binds tight: sqrt 9 + 1 is 4, sqrt(9 + 1) is √10.
            // A sign, a power and a postfix belong to it: abs -2, sin 30°,
            // sqrt 2^2.
            let argument = try unary().value
            return try function.apply(argument)
        case .open:
            advance()
            depth += 1
            if current == nil { throw CalculatorError.incomplete }
            let value = try sum()
            if current == .close {
                advance()
                depth -= 1
            } else if current != nil {
                throw CalculatorError.unexpected(Self.describe(current!))
            }
            return value
        case .close:
            throw CalculatorError.unbalanced
        default:
            throw CalculatorError.incomplete
        }
    }

    /// Whether a number may follow this token without an operator: after a
    /// closing bracket, a constant, a percentage or a degree, never after a
    /// number.
    private static func endsOperand(_ token: CalculatorToken) -> Bool {
        switch token {
        case .close, .constant, .percent, .degree, .factorial: return true
        default: return false
        }
    }

    /// n! for whole numbers up to 170, the largest a double holds.
    private static func factorial(_ value: Double) throws -> Double {
        guard value >= 0, value == value.rounded() else { throw CalculatorError.domain("!") }
        guard value <= 170 else { throw CalculatorError.notFinite }
        var result = 1.0
        var n = 2.0
        while n <= value {
            result *= n
            n += 1
        }
        return result
    }

    private static func describe(_ token: CalculatorToken) -> String {
        switch token {
        case .number(let value): return "\(value)"
        case .constant: return "constant"
        case .function: return "function"
        case .plus: return "+"
        case .minus: return "-"
        case .times: return "×"
        case .divide: return "÷"
        case .power: return "^"
        case .percent: return "%"
        case .degree: return "°"
        case .factorial: return "!"
        case .open: return "("
        case .close: return ")"
        }
    }
}

// MARK: - Formatting

enum CalculatorFormat {
    /// Automatic: up to ten decimals, trailing zeros dropped.
    static let automatic = -1
    static let maximumAutomaticDecimals = 10

    /// The value as the person reads it: `places` decimals (or automatic),
    /// their decimal separator, thousands grouped when `grouping` is given.
    /// Very large and very small values switch to an exponent ("1.5e20").
    static func string(_ value: Double, places: Int = automatic, decimalSeparator: String = ".",
                       grouping: String? = nil) -> String {
        guard value.isFinite else { return "—" }
        let magnitude = Swift.abs(value)
        if magnitude >= 1e15 || (magnitude > 0 && magnitude < 1e-9 && places == automatic) {
            return scientific(value, decimalSeparator: decimalSeparator)
        }
        // Automatic keeps to the 15 digits a double holds, so 1234567.891
        // does not come out as 1234567.8910000001.
        let integerDigits = magnitude < 1 ? 1 : Int(Foundation.log10(magnitude)) + 1
        let decimals = places == automatic ? max(0, min(maximumAutomaticDecimals, 15 - integerDigits))
            : max(0, min(places, 12))
        // Halves round away from zero, as people do (2.5 → 3), not to even.
        let scale = Foundation.pow(10, Double(decimals))
        let rounded = (value * scale).rounded(.toNearestOrAwayFromZero) / scale
        var text = String(format: "%.\(decimals)f", locale: Locale(identifier: "en_US_POSIX"), rounded.isFinite ? rounded : value)
        if places == automatic, text.contains(".") {
            while text.hasSuffix("0") { text.removeLast() }
            if text.hasSuffix(".") { text.removeLast() }
        }
        if text == "-0" || (Double(text) == 0 && text.hasPrefix("-")) { text.removeFirst() }
        var integer = text
        var fraction = ""
        if let point = text.firstIndex(of: ".") {
            integer = String(text[..<point])
            fraction = String(text[text.index(after: point)...])
        }
        if let grouping, !grouping.isEmpty { integer = group(integer, with: grouping) }
        return fraction.isEmpty ? integer : integer + decimalSeparator + fraction
    }

    private static func group(_ integer: String, with separator: String) -> String {
        let negative = integer.hasPrefix("-")
        let digits = Array(negative ? integer.dropFirst() : Substring(integer))
        guard digits.count > 3 else { return integer }
        var out = ""
        for (offset, digit) in digits.enumerated() {
            if offset > 0, (digits.count - offset) % 3 == 0 { out += separator }
            out.append(digit)
        }
        return (negative ? "-" : "") + out
    }

    private static func scientific(_ value: Double, decimalSeparator: String) -> String {
        var text = String(format: "%.6e", locale: Locale(identifier: "en_US_POSIX"), value)
        // 1.500000e+20 → 1.5e20
        guard let e = text.firstIndex(where: { $0 == "e" || $0 == "E" }) else { return text }
        var mantissa = String(text[..<e])
        var exponent = String(text[text.index(after: e)...])
        if mantissa.contains(".") {
            while mantissa.hasSuffix("0") { mantissa.removeLast() }
            if mantissa.hasSuffix(".") { mantissa.removeLast() }
        }
        if exponent.hasPrefix("+") { exponent.removeFirst() }
        let negativeExponent = exponent.hasPrefix("-")
        if negativeExponent { exponent.removeFirst() }
        while exponent.count > 1, exponent.hasPrefix("0") { exponent.removeFirst() }
        text = mantissa.replacingOccurrences(of: ".", with: decimalSeparator) + "e" + (negativeExponent ? "-" : "") + exponent
        return text
    }
}
