// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation

// Zenith fork: the island Calendar page's Week or Month, and the month grid
// beside the chosen day's events. Pure, and compiled into the tests.

enum ZenithCalendarMode: String, CaseIterable {
    case week, month

    /// What was stored, or Week for nothing or something unknown.
    static func stored(_ raw: String?) -> ZenithCalendarMode {
        raw.flatMap(ZenithCalendarMode.init(rawValue:)) ?? .week
    }
}

enum ZenithCalendarGrid {
    /// How a day reads: today filled, a day gone by dimmed, the rest plain.
    enum Tone: Equatable { case today, past, future }

    /// The month of `date` in rows of seven, the first column the calendar's
    /// first weekday: nil before the 1st and after the last day, so the grid
    /// holds that month alone.
    static func cells(month date: Date, calendar: Calendar) -> [Date?] {
        guard let month = calendar.dateInterval(of: .month, for: date),
              let days = calendar.range(of: .day, in: .month, for: month.start) else { return [] }
        let lead = (calendar.component(.weekday, from: month.start) - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: lead)
        for offset in 0..<days.count {
            cells.append(calendar.date(byAdding: .day, value: offset, to: month.start))
        }
        let rows = (cells.count + 6) / 7
        cells += Array(repeating: nil, count: rows * 7 - cells.count)
        return cells
    }

    /// The weekday initials in the grid's order, from the calendar's first weekday.
    static func weekdaySymbols(calendar: Calendar) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        guard symbols.count == 7 else { return symbols }
        return (0..<7).map { symbols[(calendar.firstWeekday - 1 + $0) % 7] }
    }

    static func tone(_ day: Date, now: Date, calendar: Calendar) -> Tone {
        if calendar.isDate(day, inSameDayAs: now) { return .today }
        return day < calendar.startOfDay(for: now) ? .past : .future
    }

    /// The first `limit` distinct values, in order: a day's calendar colours.
    static func dots<Value: Equatable>(_ values: [Value], limit: Int = 3) -> [Value] {
        values.reduce(into: [Value]()) { result, value in
            if result.count < limit, !result.contains(value) { result.append(value) }
        }
    }

    /// Whether a page of `size` holds the grid beside the day's events;
    /// narrower, Month shows the grid alone.
    static func fitsBesideAgenda(_ size: CGSize) -> Bool { size.width >= 420 && size.height >= 180 }

    /// The grid's share of a page `width` wide, the rest for the day's events.
    static func gridWidth(_ width: CGFloat) -> CGFloat { min(320, max(224, (width * 0.52).rounded(.down))) }

    /// A row's height in a grid `height` tall with `rows` rows below the weekday line.
    static func rowHeight(height: CGFloat, rows: Int) -> CGFloat {
        let rows = max(1, rows)
        return min(40, max(22, ((height - weekdayHeight) / CGFloat(rows)).rounded(.down)))
    }

    static let weekdayHeight: CGFloat = 22
}
