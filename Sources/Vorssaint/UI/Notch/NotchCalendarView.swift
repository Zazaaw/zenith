// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI
import EventKit

struct NotchCalendarView: View {
    let size: CGSize
    @Environment(\.notchSettingsPreview) private var preview
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var calendar = NotchCalendarService.shared
    @ObservedObject private var permissions = Permissions.shared
    @AppStorage(DefaultsKey.notchCalendarCountdown) private var countdownForEvery = false
    @Environment(\.notchBand) private var band
    /// The day the month grid or the week strip is built around.
    @State private var focus = Date()
    @State private var selectedDay: Date?
    /// Zenith fork: the page's Week or Month, as last chosen.
    @AppStorage(DefaultsKey.zenithCalendarMode) private var storedMode = ZenithCalendarMode.week.rawValue
    private var mode: ZenithCalendarMode { ZenithCalendarMode.stored(storedMode) }
    /// Zenith fork: Month on a page too narrow for the grid beside the day's
    /// events: the grid alone, in place of the strip and the cards.
    private var showingMonth: Bool { mode == .month && !showsMonth }
    private var text: NotchCalendarStrings { FeatureStrings.notchCalendar(l10n.language) }
    /// Zenith fork: Month shows the grid beside the chosen day's events where
    /// the page is wide enough; Week shows the strip above a vertical agenda.
    private var showsMonth: Bool { mode == .month && ZenithCalendarGrid.fitsBesideAgenda(size) }

    var body: some View {
        Group {
            if permissions.calendarAccess == .fullAccess {
                TimelineView(.everyMinute) { context in
                    Group {
                        if showsMonth {
                            // Zenith fork: the month grid, the chosen day's events beside it.
                            HStack(alignment: .top, spacing: 18) {
                                ZenithCalendarMonthGridView(month: focus, selectedDay: monthDay(now: context.date),
                                                            now: context.date, events: calendar.events, text: text,
                                                            select: select)
                                    .frame(width: ZenithCalendarGrid.gridWidth(size.width))
                                Rectangle().fill(.white.opacity(0.12)).frame(width: 1)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 8) {
                                    agendaHeader {
                                        NotchCalendarDayLabel(day: monthDay(now: context.date), now: context.date, text: text)
                                    }
                                    agenda(now: context.date)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            }
                        } else if showingMonth {
                            VStack(spacing: 4) { // Zenith fork: Week or Month above a grid the row cannot hold it beside
                                if !pickerInBand { agendaHeader { EmptyView() } }
                                monthGrid(now: context.date)
                            }
                        } else {
                            VStack(spacing: NotchLayout.rowSpacing) {
                                weekStrip(now: context.date)
                                if !pickerInBand { // Zenith fork: Week or Month heads the agenda
                                    agendaHeader {
                                        Group {
                                            if let selectedDay {
                                                Text(selectedDay, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                                            } else {
                                                Text(text.week)
                                            }
                                        }
                                        .modifier(ZenithBentoLabelStyle())
                                        .lineLimit(1)
                                    }
                                }
                                agenda(now: context.date)
                            }
                        }
                    }
                    .onChange(of: Calendar.current.startOfDay(for: context.date)) { _, _ in
                        if selectedDay == nil { focus = context.date }
                    }
                }
                // The month's name and the way through it head the page from
                // the island's top row, the same in all three layouts.
                .notchBand { monthTitle } trailing: { navigation }
            } else {
                permissionCard
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Day and month names follow the app's language; the order of the
        // date and the 12/24-hour clock follow the user's region.
        .environment(\.locale, l10n.language.formattingLocale())
        .onAppear { if ownsMonth { calendar.showMonth(focus) } }
        .onChange(of: focus) { previous, date in
            // A month read already covers every week of that month, so
            // moving the strip within it keeps the loaded events.
            if !Calendar.current.isDate(previous, equalTo: date, toGranularity: .month) { calendar.showMonth(date) }
        }
        // Escape returns from the month grid to the strip before the island closes.
        .onChange(of: showingMonth, initial: true) { _, showing in // Zenith fork: Month remembered, so from the start
            guard !preview else { return }
            NotchService.shared.setPageLayer(.calendar, close: showing ? { storedMode = ZenithCalendarMode.week.rawValue } : nil)
        }
        .onDisappear {
            if ownsMonth { calendar.showMonth(nil) }
            if !preview { NotchService.shared.setPageLayer(.calendar, close: nil); calendar.revealing = nil }
        }
    }

    /// The month the service reads belongs to the island's own page; a preview
    /// in Settings borrows it only while the island shows another page.
    private var ownsMonth: Bool {
        !preview || !(NotchService.shared.expanded && NotchService.shared.selected == .calendar)
    }

    /// Zenith fork: the day Month shows the events of: the one chosen, else today.
    private func monthDay(now: Date) -> Date {
        selectedDay ?? Calendar.current.startOfDay(for: now)
    }

    private func weekStrip(now: Date) -> some View {
        NotchCalendarWeekStrip(focus: focus, selectedDay: selectedDay, now: now,
                               events: calendar.events, text: text, select: select) {
            selectedDay = nil
            focus = now
        }
    }

    /// Picking a day lands back on the strip with that day.
    private func monthGrid(now: Date) -> some View {
        NotchCalendarMonthGrid(month: focus, selectedDay: selectedDay, now: now,
                               height: size.height - (pickerInBand ? 0 : 30), // Zenith fork: below Week or Month
                               events: calendar.events, text: text) { date in
            select(date)
            storedMode = ZenithCalendarMode.week.rawValue // Zenith fork
        }
    }

    /// The month the page shows, named in the language's own words: in full
    /// where the row has room, abbreviated where the camera leaves less. Over
    /// the week strip it opens the month grid, and over that grid it closes it.
    private var monthTitle: some View {
        let title = ViewThatFits(in: .horizontal) {
            Text(focus, format: .dateTime.month(.wide).year())
            Text(focus, format: .dateTime.month(.abbreviated).year())
        }
        .font(.system(size: 13, weight: .semibold))
        .lineLimit(1)
        // The row is drawn by the island, outside this page's own locale.
        .environment(\.locale, l10n.language.formattingLocale())
        // Zenith fork: Week or Month is chosen beside the arrows, so the title is only a title.
        return title.accessibilityAddTraits(.isHeader)
    }

    /// Zenith fork: Week or Month, remembered for the next time the page opens.
    private var modePicker: some View {
        let island = ZenithStrings.island(l10n.language)
        return ZenithSegmented(selection: Binding(get: { mode }, set: { chosen in
            guard chosen != mode else { return }
            storedMode = chosen.rawValue
            // Month opens on the chosen day's month; Week on the chosen day's week.
            if chosen == .month, selectedDay == nil { selectedDay = Calendar.current.startOfDay(for: Date()) }
        }), options: ZenithCalendarMode.allCases.map { (value: $0, title: $0 == .week ? island.week : island.month) })
        .fixedSize()
    }

    /// Calendar itself follows the arrows where the row has room for four
    /// buttons, the last one apart; the island's own update or pin give way
    /// to it. Elsewhere an empty agenda offers it, and every appointment card
    /// opens it as well.
    private var rowOpensCalendar: Bool { !band.besideCamera || band.side >= 28 * 4 + 6 }

    /// The arrows step by week over the strip and by month over a grid,
    /// around the way back to today, as Calendar's own toolbar does.
    private var navigation: some View {
        // Zenith fork: Week or Month ahead of the arrows where the row has
        // room; beside a camera it heads the agenda instead (`agendaHeader`).
        HStack(spacing: 10) {
            if pickerInBand { modePicker }
            arrows(opensCalendar: rowOpensCalendar)
        }
    }

    /// Zenith fork: whether Week or Month fits the island's top row with the
    /// arrows: a row below the camera has the page's width, one beside it
    /// only the side the camera leaves.
    private var pickerInBand: Bool { !band.besideCamera || band.side >= 28 * 4 + 6 + 120 }

    /// Zenith fork: the agenda's heading, with Week or Month at its end when
    /// the top row has no room for it.
    private func agendaHeader<Label: View>(@ViewBuilder label: () -> Label) -> some View {
        HStack(spacing: 8) {
            label().frame(maxWidth: .infinity, alignment: .leading)
            if !pickerInBand { modePicker }
        }
        .frame(minHeight: pickerInBand ? 0 : 26)
    }

    private func arrows(opensCalendar: Bool) -> some View {
        let byWeek = mode == .week // Zenith fork
        return HStack(spacing: 6) {
            HStack(spacing: 0) {
                NotchIconButton(symbol: "chevron.left", title: byWeek ? text.previousWeek : text.previousMonth) {
                    byWeek ? moveWeek(-1) : moveMonth(-1)
                }
                NotchIconButton(symbol: "circle.circle", title: text.today) {
                    today(now: Date())
                }
                NotchIconButton(symbol: "chevron.right", title: byWeek ? text.nextWeek : text.nextMonth) {
                    byWeek ? moveWeek(1) : moveMonth(1)
                }
            }
            if opensCalendar {
                NotchIconButton(symbol: "arrow.up.forward.app", title: text.openCalendar) { openCalendar() }
            }
        }
    }

    private func moveWeek(_ offset: Int) {
        guard let date = Calendar.current.date(byAdding: .day, value: offset * 7, to: focus) else { return }
        selectedDay = Calendar.current.startOfDay(for: date)
        focus = date
    }

    private func moveMonth(_ offset: Int) {
        guard let start = Calendar.current.dateInterval(of: .month, for: focus)?.start,
              let date = Calendar.current.date(byAdding: .month, value: offset, to: start) else { return }
        selectedDay = date
        focus = date
    }

    private func select(_ date: Date) {
        selectedDay = date
        focus = date
    }

    private func today(now: Date) {
        selectedDay = Calendar.current.startOfDay(for: now)
        focus = now
    }

    private struct DayGroup {
        let day: Date
        let events: [NotchCalendarEvent]
    }

    /// Zenith fork: the one day the agenda lists, nil for the coming week. A
    /// month beside its agenda always lists one day, today until one is chosen.
    private func agendaDay(now: Date) -> Date? {
        showsMonth ? monthDay(now: now) : selectedDay
    }

    private func groups(now: Date) -> [DayGroup] {
        let selectedDay = agendaDay(now: now) // Zenith fork
        let days = selectedDay.map { [$0] } ?? (0..<7).compactMap {
            Calendar.current.date(byAdding: .day, value: $0, to: Calendar.current.startOfDay(for: now))
        }
        let events = selectedDay == nil ? NotchCalendarSupport.upcoming(calendar.events, now: now) : calendar.events
        return days.map { DayGroup(day: $0, events: NotchCalendarSupport.events(events, on: $0)) }
            .filter { !$0.events.isEmpty }
    }

    /// Scrolls once to the countdown's event opened from the closed island,
    /// after the reload that opening the page starts has finished.
    private func agenda(now: Date) -> some View {
        ScrollViewReader { proxy in
            ScrollView { appointmentList(now: now) }
                .scrollIndicators(.automatic)
                // Zenith fork: rows past the page's end fade instead of being cut.
                .modifier(NotchScrollEdgeFade(length: 24))
                .id(selectedDay)
                .onChange(of: calendar.loading ? nil : calendar.revealing, initial: true) { _, target in
                    guard !preview, let target else { return }
                    DispatchQueue.main.async {
                        guard !calendar.loading, calendar.revealing == target else { return }
                        calendar.revealing = nil
                        proxy.scrollTo(target, anchor: .center)
                    }
                }
        }
    }

    @ViewBuilder private func appointmentList(now: Date) -> some View {
        let groups = groups(now: now)
        let next = NotchCalendarSupport.next(calendar.events, now: now)
        if calendar.loading {
            ProgressView().controlSize(.small)
                .frame(maxWidth: .infinity, minHeight: 72)
        } else if groups.isEmpty {
            emptyAgenda.frame(maxWidth: .infinity, minHeight: 72)
        } else {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(groups, id: \.day) { group in
                    VStack(alignment: .leading, spacing: 4) { // Zenith fork: a timeline of rows
                        if agendaDay(now: now) == nil { dayLabel(group.day, now: now) } // Zenith fork
                        ForEach(group.events) { event in
                            if event.id != group.events.first?.id { ZenithBentoDivider(.horizontal, gap: 3) } // Zenith fork
                            NotchCalendarEventRow(event: event, day: group.day, now: now,
                                                  isNext: event.id == next?.id, text: text,
                                                  countdown: countdownChoice(event, now: now),
                                                  choose: { calendar.setCountdown($0, for: event) }) {
                                openCalendar(showing: event)
                            }
                            .id(event.id)
                        }
                    }
                }
                // Zenith fork: Month says how to see another day's events.
                if showsMonth {
                    Text(ZenithStrings.island(l10n.language).pickDay)
                        .font(.system(size: 11))
                        .foregroundStyle(ZenithIsland.meta)
                        .padding(.top, 6)
                }
            }
            // Zenith fork: the last row can scroll clear of the fade.
            .padding(.bottom, 16)
        }
    }

    /// Whether a timed event yet to start counts down on its own, or nil when
    /// its menu has nothing to offer: the countdown for every event covers it.
    private func countdownChoice(_ event: NotchCalendarEvent, now: Date) -> Bool? {
        guard !countdownForEvery, !event.allDay, event.start > now, !event.countdownKey.isEmpty else { return nil }
        return calendar.isChosen(event)
    }

    private func dayLabel(_ day: Date, now: Date) -> some View {
        NotchCalendarDayLabel(day: day, now: now, text: text)
    }

    private var emptyAgenda: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.white.opacity(0.45))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text(selectedDay == nil && !showsMonth ? text.empty : text.emptyDay) // Zenith fork: Month lists a day
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
                // With no card to open it from and no room for it in the row.
                if !rowOpensCalendar {
                    NotchPillButton(title: text.openCalendar) { openCalendar() }
                }
            }
        }
        .padding(.horizontal, 12)
    }

    private var permissionCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.clock").font(.system(size: 28))
            Text(permissions.calendarAccess == .denied || permissions.calendarAccess == .restricted
                 ? text.denied : text.permission)
                .font(.callout).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                if permissions.calendarAccess == .denied || permissions.calendarAccess == .restricted {
                    Button(text.settings) { permissions.openCalendarSettings() }
                } else {
                    Button(text.allow) {
                        NotchService.shared.open(.calendar)
                        permissions.requestCalendar()
                    }
                    .disabled(permissions.requestingCalendar)
                }
                if permissions.requestingCalendar { ProgressView().controlSize(.small) }
            }
            if permissions.calendarRequestFailed {
                Text(text.requestFailed).font(.caption).foregroundStyle(ZenithStatus.warning)
            }
        }
        .buttonStyle(ZenithIslandPrimaryButtonStyle()) // Zenith fork: the page's one solid step
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 12)
    }

    /// Calendar itself gets the link: another app claiming the `ical` scheme
    /// would not know EventKit's identifiers.
    private func openCalendar(showing event: NotchCalendarEvent? = nil) {
        guard let application = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        if let url = event.flatMap({ NotchCalendarSupport.eventURL($0) }) {
            NSWorkspace.shared.open([url], withApplicationAt: application, configuration: configuration)
        } else {
            NSWorkspace.shared.openApplication(at: application, configuration: configuration)
        }
    }
}

private struct NotchCalendarDayLabel: View {
    let day: Date
    let now: Date
    let text: NotchCalendarStrings

    var body: some View {
        HStack(spacing: 5) {
            if Calendar.current.isDate(day, inSameDayAs: now) {
                Text(text.today).foregroundStyle(ZenithIsland.primary) // Zenith fork
            } else {
                Text(day, format: .dateTime.weekday(.abbreviated))
            }
            Text(day, format: .dateTime.day().month(.abbreviated))
        }
        .modifier(ZenithBentoLabelStyle()) // Zenith fork: a bento heading
        .lineLimit(1)
    }
}

private struct NotchCalendarEventRow: View {
    let event: NotchCalendarEvent
    let day: Date
    let now: Date
    let isNext: Bool
    let text: NotchCalendarStrings
    /// Whether the event counts down on its own; nil when it cannot.
    let countdown: Bool?
    let choose: (Bool) -> Void
    let open: () -> Void
    @Environment(\.colorSchemeContrast) private var contrast

    private var ongoing: Bool { !event.allDay && event.start <= now && event.end > now }
    private var ended: Bool { event.end <= now }

    var body: some View {
        Button(action: open) { card }
            .buttonStyle(ZenithBentoButtonStyle(cornerRadius: ZenithRadius.large)) // Zenith fork: a wash, no lift
            .accessibilityValue(event.calendar) // Zenith fork: read, though no longer drawn
            .help(text.openCalendar)
            .accessibilityHint(text.openCalendar)
            .modifier(NotchCountdownChoice(chosen: countdown, text: text, choose: choose))
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 4) {
            if ongoing || isNext {
                HStack(spacing: 3) { // Zenith fork: a timeline dot, emerald and glowing while it runs
                    ZenithStatusDot(color: ongoing ? ZenithStatus.success : ZenithIsland.secondary, live: ongoing)
                        .padding(.leading, -3)
                    Text(ongoing ? text.ongoing : text.next)
                        .modifier(ZenithBentoLabelStyle(color: ongoing ? ZenithStatus.success : ZenithIsland.label))
                        .lineLimit(1)
                }
            }
            Text(event.title.isEmpty ? text.untitled : event.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(ended ? 0.65 : 1))
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Group {
                    if event.allDay {
                        Text(text.allDay)
                    } else if Calendar.current.isDate(event.start, inSameDayAs: day)
                                && Calendar.current.isDate(event.end.addingTimeInterval(-1), inSameDayAs: day) {
                        Text(event.start, format: .dateTime.hour().minute())
                            + Text(" · ") + Text(event.end, format: .dateTime.hour().minute())
                    } else {
                        Text(event.start, format: .dateTime.day().month(.abbreviated).hour().minute())
                            + Text(" → ") + Text(event.end, format: .dateTime.day().month(.abbreviated).hour().minute())
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                // The mark of an event chosen to count down on its own.
                if countdown == true {
                    Image(systemName: "timer")
                        .accessibilityLabel(text.countdown)
                }
            }
            .font(ZenithType.mono(11)) // Zenith fork: times in mono
            .foregroundStyle(.white.opacity(0.75))
            // Zenith fork: the calendar's name is left to its coloured bar, so a row stays short.
            if !event.location.isEmpty {
                Label(event.location, systemImage: "mappin")
                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 12)
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2).fill(event.color.color)
                .frame(width: 3)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 8) // Zenith fork: a row on the island, no card;
        .padding(.horizontal, 4) // the calendar's colour stays on its 3-point bar.
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .clipped()
    }
}

/// A timed event yet to start offers its own countdown from its menu, and
/// to VoiceOver as an action, while the countdown for every event is off.
private struct NotchCountdownChoice: ViewModifier {
    let chosen: Bool?
    let text: NotchCalendarStrings
    let choose: (Bool) -> Void

    @ViewBuilder func body(content: Content) -> some View {
        if let chosen {
            let title = chosen ? text.removeCountdown : text.addCountdown
            content
                .contextMenu { Button(title) { choose(!chosen) } }
                .accessibilityAction(named: Text(title)) { choose(!chosen) }
        } else {
            content
        }
    }
}

extension NotchCalendarColor {
    var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: 1) }
}
