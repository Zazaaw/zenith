// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

/// Zenith fork: the Calculator's page in the island. A field to type in, the
/// answer under it as it is typed, a keypad for the mouse, and the history
/// beside it: a click on a past answer puts it back in the field. Return
/// keeps the answer in the history; Copy (⌘C with nothing selected) copies it.
struct CalculatorPage: View {
    let size: CGSize
    var preview = false
    @ObservedObject private var service = CalculatorService.shared
    @State private var expression = ""
    @State private var copied = false
    @FocusState private var fieldFocused: Bool

    private let text = ZenithStrings.calculator(.enUS)
    private static let keys: [[String]] = [
        ["(", ")", "%", "÷"],
        ["7", "8", "9", "×"],
        ["4", "5", "6", "−"],
        ["1", "2", "3", "+"],
        ["0", Locale.current.decimalSeparator ?? ".", "⌫", "="],
    ]

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 8) {
                display
                keypad
            }
            .frame(maxWidth: .infinity)
            historyColumn
                .frame(width: min(170, size.width * 0.36))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            service.loadHistory()
            if !preview { DispatchQueue.main.async { fieldFocused = true } }
        }
        .task(id: copied) {
            guard copied else { return }
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled else { return }
            copied = false
        }
    }

    private var result: Result<CalculatorAnswer, CalculatorError> { service.answer(expression) }

    private var answer: CalculatorAnswer? { try? result.get() }

    // MARK: Display

    private var display: some View {
        VStack(alignment: .trailing, spacing: 2) {
            TextField(text.placeholder, text: $expression)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .multilineTextAlignment(.trailing)
                .foregroundStyle(ZenithIsland.secondary)
                .focused($fieldFocused)
                .onSubmit(keep)
            HStack(spacing: 8) {
                if answer != nil {
                    Button(copied ? text.copied : text.copy, action: copy)
                        .buttonStyle(ZenithIslandOutlineButtonStyle(height: 22))
                        .keyboardShortcut("c", modifiers: [.command, .shift])
                }
                Spacer(minLength: 4)
                Text(verbatim: resultLine)
                    .font(.system(size: answer == nil ? 13 : 26, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(answer == nil ? ZenithIsland.tertiary : ZenithIsland.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .textSelection(.enabled)
                    .contentTransition(.numericText())
            }
            .frame(height: 32)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .zenithIslandSoftCard(cornerRadius: 12)
    }

    private var resultLine: String {
        switch result {
        case .success(let answer): return "= " + service.display(answer.value)
        case .failure(let error): return expression.isEmpty ? "0" : text.error(error)
        }
    }

    // MARK: Keypad

    private var keypad: some View {
        VStack(spacing: 5) {
            ForEach(Self.keys, id: \.self) { row in
                HStack(spacing: 5) {
                    ForEach(row, id: \.self) { key in
                        CalculatorKey(label: key, role: role(of: key)) { press(key) }
                    }
                }
            }
        }
    }

    private func role(of key: String) -> CalculatorKey.Role {
        if key == "=" { return .equals }
        if ["÷", "×", "−", "+", "%", "(", ")"].contains(key) { return .operator }
        if key == "⌫" { return .function }
        return .digit
    }

    private func press(_ key: String) {
        switch key {
        case "=": keep()
        case "⌫": if !expression.isEmpty { expression.removeLast() }
        default: expression += key
        }
        if !preview { fieldFocused = true }
    }

    private func keep() {
        guard let answer else { return ZenithQuiet.beep() }
        let closed = expression + String(repeating: ")", count: answer.closedBrackets)
        service.keep(closed, value: answer.value)
        expression = CalculatorText.copied(answer.value, places: service.preferences.decimalPlaces)
    }

    private func copy() {
        guard let answer else { return }
        service.copy(answer.value) { ok in if ok { copied = true } else { ZenithQuiet.beep() } }
    }

    // MARK: History

    private var historyColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(text.history.uppercased())
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(ZenithIsland.tertiary)
                Spacer()
                if !service.history.entries.isEmpty {
                    Button(text.clear) { service.clearHistory() }
                        .buttonStyle(.plain)
                        .font(.system(size: 10.5))
                        .foregroundStyle(ZenithIsland.secondary)
                }
            }
            if service.history.entries.isEmpty {
                Text(text.noHistory)
                    .font(.system(size: 11))
                    .foregroundStyle(ZenithIsland.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(service.history.entries) { entry in
                            CalculatorHistoryRow(expression: entry.expression, answer: service.display(entry.value)) {
                                expression = CalculatorText.copied(entry.value, places: service.preferences.decimalPlaces)
                                if !preview { fieldFocused = true }
                            }
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// One key of the keypad.
struct CalculatorKey: View {
    enum Role { case digit, `operator`, function, equals }

    let label: String
    let role: Role
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(verbatim: label)
                .font(.system(size: role == .digit ? 15 : 14, weight: role == .digit ? .medium : .semibold, design: .rounded))
                .foregroundStyle(role == .equals ? Color.white : role == .operator ? ZenithIsland.accent : ZenithIsland.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(fill))
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(accessibilityName)
    }

    private var fill: Color {
        switch role {
        case .equals: return ZenithIsland.accent.opacity(hovering ? 0.95 : 0.8)
        default: return Color.white.opacity(hovering ? 0.12 : 0.06)
        }
    }

    private var accessibilityName: String {
        switch label {
        case "⌫": return "Delete"
        case "÷": return "Divide"
        case "×": return "Multiply"
        case "−": return "Minus"
        case "+": return "Plus"
        case "=": return "Equals"
        case "%": return "Percent"
        default: return label
        }
    }
}

struct CalculatorHistoryRow: View {
    let expression: String
    let answer: String
    let use: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: use) {
            VStack(alignment: .trailing, spacing: 0) {
                Text(verbatim: expression)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(ZenithIsland.tertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
                Text(verbatim: answer)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(ZenithIsland.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 6).fill(hovering ? ZenithIsland.hoverFill : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
