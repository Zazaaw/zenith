// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: which reminders the lock screen reads out. `RemindersService`
/// reads them from EventKit; everything here is plain values and dates.
enum RemindersSupport {
    /// The lock screen line has room for a few titles, no more.
    static let limit = 3
    /// While the lock screen stays, a day can turn; it reads again this often.
    static let refreshInterval: TimeInterval = 30 * 60

    struct Item: Equatable, Identifiable {
        let id: String
        let title: String
        /// For a reminder without a time, the start of its day.
        let due: Date
        let hasTime: Bool
    }

    struct Entry: Equatable, Identifiable {
        let item: Item
        let overdue: Bool

        var id: String { item.id }
    }

    struct Selection: Equatable {
        var shown: [Entry] = []
        /// Due today or overdue, beyond those shown.
        var hidden = 0

        var isEmpty: Bool { shown.isEmpty }
    }

    /// A reminder as the lock screen needs it: incomplete and with a due date,
    /// or nothing. Only the title and the due date are kept, never notes.
    static func item(id: String, title: String?, due components: DateComponents?, completed: Bool,
                     calendar: Calendar) -> Item? {
        guard !completed, let components else { return nil }
        let hasTime = components.hour != nil
        // A due date with only a day falls on that day wherever the Mac is,
        // so it is read in the person's own calendar.
        guard let date = (hasTime ? components.calendar ?? calendar : calendar).date(from: components) else { return nil }
        return Item(id: id, title: (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                    due: hasTime ? date : calendar.startOfDay(for: date), hasTime: hasTime)
    }

    /// The reminders due today or already overdue, earliest first, at most `limit`.
    /// A timed reminder is overdue once its time has passed; a reminder with
    /// only a day, once that day has.
    static func selection(_ items: [Item], now: Date, calendar: Calendar, limit: Int = limit) -> Selection {
        let today = calendar.startOfDay(for: now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return Selection() }
        let due = items.filter { $0.due < tomorrow }.sorted {
            if $0.due != $1.due { return $0.due < $1.due }
            if $0.title != $1.title { return $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            return $0.id < $1.id
        }
        let shown = due.prefix(max(0, limit)).map {
            Entry(item: $0, overdue: $0.hasTime ? $0.due < now : $0.due < today)
        }
        return Selection(shown: Array(shown), hidden: due.count - shown.count)
    }

    /// The end of the window EventKit is asked for: everything due before tomorrow.
    static func readEnd(now: Date, calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: 1, to: today) ?? now
    }
}
