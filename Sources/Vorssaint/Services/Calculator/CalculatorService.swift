// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import Combine

// Zenith fork: the Calculator's state on the main thread: the history, read
// the first time the island's page or the Command Bar asks for it, and the
// copy. No hotkey, no observer, no timer: the page and the bar call in.

final class CalculatorService: ObservableObject {
    static let shared = CalculatorService()

    @Published private(set) var history = CalculatorHistory()
    private var loaded = false

    private init() {}

    static func isEnabled(_ defaults: UserDefaults = .standard) -> Bool {
        CalculatorPreferences(defaults: defaults).enabled
    }

    var preferences: CalculatorPreferences { CalculatorPreferences() }

    /// The answer to what is typed, in the person's separators.
    func answer(_ expression: String) -> Result<CalculatorAnswer, CalculatorError> {
        CalculatorEngine.evaluate(expression, decimalSeparator: Locale.current.decimalSeparator ?? ".")
    }

    func display(_ value: Double) -> String {
        CalculatorText.display(value, places: preferences.decimalPlaces)
    }

    func loadHistory() {
        guard !loaded else { return }
        loaded = true
        history = CalculatorHistory(data: UserDefaults.standard.data(forKey: CalculatorDefaults.history))
    }

    /// Keeps an answer: Return in the island or in the Command Bar.
    func keep(_ expression: String, value: Double) {
        loadHistory()
        history.add(expression, value: value)
        UserDefaults.standard.set(history.data, forKey: CalculatorDefaults.history)
    }

    func clearHistory() {
        history.clear()
        loaded = true
        UserDefaults.standard.removeObject(forKey: CalculatorDefaults.history)
    }

    /// Copies the answer without grouping, so it pastes back into a sum.
    func copy(_ value: Double, completion: ((Bool) -> Void)? = nil) {
        let text = CalculatorText.copied(value, places: preferences.decimalPlaces)
        GeneralPasteboardAccess.shared.async({ () -> Bool in
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.declareVorssaintSource()
            return pasteboard.setString(text, forType: .string)
        }, then: { ok in completion?(ok) })
    }

    func openSettings() {
        SettingsRouter.shared.request(FeatureSettingsDestination(.calculator, sectionAnchor: .zenithCalculator))
        appDelegate()?.openSettingsWindow()
    }
}
