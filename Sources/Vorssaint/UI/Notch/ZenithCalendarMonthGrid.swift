// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Zenith fork: the Calendar page's month beside the chosen day's events.
/// Only the month's own days: today a filled red circle, the chosen day a
/// ring, days gone by dimmed, and up to three dots in the colours of the
/// calendars with events that day. The title, Week or Month, the arrows and
/// Today are in the island's top row.
struct ZenithCalendarMonthGridView: View {
    let month: Date
    let selectedDay: Date
    let now: Date
    let events: [NotchCalendarEvent]
    let text: NotchCalendarStrings
    let select: (Date) -> Void
    @Environment(\.locale) private var locale
    private let todayTint = Color(red: 1, green: 0.36, blue: 0.39)

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.locale = locale
        return calendar
    }

    var body: some View {
        let calendar = calendar
        let cells = ZenithCalendarGrid.cells(month: month, calendar: calendar)
        let rows = cells.count / 7
        GeometryReader { proxy in
            let rowHeight = ZenithCalendarGrid.rowHeight(height: proxy.size.height, rows: rows)
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(Array(ZenithCalendarGrid.weekdaySymbols(calendar: calendar).enumerated()), id: \.offset) { _, symbol in
                        Text(symbol)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(ZenithIsland.label)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: ZenithCalendarGrid.weekdayHeight)
                .accessibilityHidden(true)
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { column in
                            if let day = cells[row * 7 + column] {
                                dayButton(day, height: rowHeight, calendar: calendar)
                            } else {
                                Color.clear.frame(maxWidth: .infinity).frame(height: rowHeight)
                            }
                        }
                    }
                }
            }
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(month, format: .dateTime.month(.wide).year()))
    }

    private func dayButton(_ date: Date, height: CGFloat, calendar: Calendar) -> some View {
        let tone = ZenithCalendarGrid.tone(date, now: now, calendar: calendar)
        let selected = calendar.isDate(date, inSameDayAs: selectedDay)
        let dayEvents = NotchCalendarSupport.events(events, on: date)
        let colors = ZenithCalendarGrid.dots(dayEvents.map(\.color))
        let circle = min(30, height - 8)
        return Button { select(date) } label: {
            VStack(spacing: 2) {
                Text(calendar.component(.day, from: date), format: .number)
                    .font(.system(size: min(13, circle * 0.48), weight: tone == .today || selected ? .bold : .medium))
                    .monospacedDigit()
                    .foregroundStyle(tone == .past ? Color.white.opacity(0.4) : .white)
                    .frame(width: circle, height: circle)
                    .background { if tone == .today { Circle().fill(todayTint) } }
                    .overlay {
                        Circle().strokeBorder(.white.opacity(selected ? (tone == .today ? 0.85 : 0.55) : 0), lineWidth: 1.5)
                    }
                HStack(spacing: 2.5) {
                    ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                        Circle().fill(color.color).frame(width: 4, height: 4)
                    }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity).frame(height: height)
            .contentShape(Rectangle())
        }
        .buttonStyle(NotchButtonStyle(cornerRadius: 8, lifts: false))
        .help(date.formatted(.dateTime.weekday(.wide).day().month(.wide).year().locale(locale)))
        .accessibilityLabel(Text(date, format: .dateTime.weekday(.wide).day().month(.wide).year()))
        .accessibilityValue([tone == .today ? text.today : "", dayEvents.isEmpty ? "" : text.hasEvents]
            .filter { !$0.isEmpty }.joined(separator: ", "))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
