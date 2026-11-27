// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: the Calculator's preferences and its history, without views,
// so the tests reach them and the island's module list can ask whether the
// page shows.

/// Kept here, not in `DefaultsKey`, so the feature's files never edit a
/// shared registry.
enum CalculatorDefaults {
    static let enabled = "zenithCalculatorEnabled"                 // Bool, default false
    static let showInIsland = "zenithCalculatorShowInIsland"       // Bool, default true
    static let showInCommandBar = "zenithCalculatorShowInCommandBar" // Bool, default true
    static let decimalPlaces = "zenithCalculatorDecimalPlaces"     // Int, CalculatorFormat.automatic (-1) or 0...10
    /// The last answers. Private content: never in a backup.
    static let history = "zenithCalculatorHistory"                 // JSON [CalculatorHistoryEntry]

    /// The preferences a backup carries.
    static let backupKeys: Set<String> = [enabled, showInIsland, showInCommandBar, decimalPlaces]

    /// The choices Settings offers for decimal places.
    static let placeChoices = [CalculatorFormat.automatic, 0, 1, 2, 3, 4, 6, 8, 10]
}

struct CalculatorPreferences: Equatable {
    var enabled: Bool
    var showInIsland: Bool
    var showInCommandBar: Bool
    var decimalPlaces: Int

    init(defaults: UserDefaults = .standard) {
        enabled = defaults.object(forKey: CalculatorDefaults.enabled) as? Bool ?? false
        showInIsland = defaults.object(forKey: CalculatorDefaults.showInIsland) as? Bool ?? true
        showInCommandBar = defaults.object(forKey: CalculatorDefaults.showInCommandBar) as? Bool ?? true
        let places = defaults.object(forKey: CalculatorDefaults.decimalPlaces) as? Int ?? CalculatorFormat.automatic
        decimalPlaces = CalculatorDefaults.placeChoices.contains(places) ? places : CalculatorFormat.automatic
    }

    /// The island lists the page only while the Calculator is on and asked to show there.
    static func showsInIsland(_ defaults: UserDefaults = .standard) -> Bool {
        let preferences = CalculatorPreferences(defaults: defaults)
        return preferences.enabled && preferences.showInIsland
    }

    static func showsInCommandBar(_ defaults: UserDefaults = .standard) -> Bool {
        let preferences = CalculatorPreferences(defaults: defaults)
        return preferences.enabled && preferences.showInCommandBar
    }
}

/// One line of the history: what was typed and what it came to.
struct CalculatorHistoryEntry: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    let expression: String
    let value: Double

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.expression == rhs.expression && lhs.value == rhs.value }
}

/// The last answers, newest first.
struct CalculatorHistory: Equatable {
    static let limit = 20
    private(set) var entries: [CalculatorHistoryEntry]

    init(entries: [CalculatorHistoryEntry] = []) {
        self.entries = Array(entries.filter { $0.value.isFinite }.prefix(Self.limit))
    }

    /// Adds an answer. The same sum again moves to the top instead of
    /// showing twice, and the oldest falls off past the limit.
    mutating func add(_ expression: String, value: Double) {
        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, value.isFinite else { return }
        let entry = CalculatorHistoryEntry(expression: trimmed, value: value)
        entries.removeAll { $0 == entry }
        entries.insert(entry, at: 0)
        if entries.count > Self.limit { entries.removeLast(entries.count - Self.limit) }
    }

    mutating func clear() { entries = [] }

    // MARK: Storage

    init(data: Data?) {
        guard let data, let decoded = try? JSONDecoder().decode([CalculatorHistoryEntry].self, from: data) else {
            self.init()
            return
        }
        self.init(entries: decoded)
    }

    var data: Data? { try? JSONEncoder().encode(entries) }
}

/// The text Settings, the island and the Command Bar use for an answer.
enum CalculatorText {
    /// The answer as shown: grouped, in the person's separators.
    static func display(_ value: Double, places: Int, locale: Locale = .current) -> String {
        CalculatorFormat.string(value, places: places, decimalSeparator: locale.decimalSeparator ?? ".",
                                grouping: locale.groupingSeparator ?? ",")
    }

    /// The answer as copied: no grouping, so it pastes back into a sum.
    static func copied(_ value: Double, places: Int, locale: Locale = .current) -> String {
        CalculatorFormat.string(value, places: places, decimalSeparator: locale.decimalSeparator ?? ".")
    }
}
