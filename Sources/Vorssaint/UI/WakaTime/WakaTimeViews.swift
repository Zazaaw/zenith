// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Zenith fork: the WakaTime page in the Dynamic Island.
struct NotchWakaTimeView: View {
    let size: CGSize

    var body: some View {
        // Ranges add rows the page height cannot always hold: scroll, as the
        // queue and lyrics pages do, with the island's soft edges.
        ScrollView(.vertical, showsIndicators: false) {
            WakaTimeSummary(compact: false)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .notchScrollEdgeFade()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Zenith fork: the WakaTime card in the menu panel.
struct WakaTimeSection: View {
    var collapsible = true

    var body: some View {
        PanelSection(.wakatime, title: "WakaTime", collapsible: collapsible) {
            WakaTimeSummary(compact: true)
        }
    }
}

/// Coding now, the chosen range's total, languages, top project and a day chart.
/// Grey throughout, after the Style Kit: the leading language and the live dot
/// are the only colour, and today's bar is the only bright one.
struct WakaTimeSummary: View {
    let compact: Bool
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = WakaTimeService.shared
    @AppStorage(DefaultsKey.wakaTimeDailyGoalMinutes) private var goalMinutes = 0

    private var text: ZenithWakaTimeStrings { ZenithStrings.wakaTime(l10n.language) }
    private var tokenText: ZenithWakaTimeTokenStrings { ZenithStrings.wakaTimeToken(l10n.language) }
    private var locale: Locale { Locale(identifier: l10n.language.rawValue) }

    var body: some View {
        content
            .onAppear { service.viewAppeared() }
            .onDisappear { service.viewDisappeared() }
    }

    @ViewBuilder
    private var content: some View {
        switch (service.state, service.today) {
        case (.missingKey, _):
            message(symbol: "key", text.missingKey, retry: false)
        case (.failed, nil):
            message(symbol: "wifi.exclamationmark", text.failed, retry: true)
        case (_, nil):
            ProgressView().controlSize(.small).frame(maxWidth: .infinity, minHeight: 60)
        case (_, let today?):
            if compact { summary(today) } else { islandSummary(today) }
        }
    }

    // MARK: Island

    /// The island's page as a bento grid: the live state over the range's
    /// segmented control, then the total, the top project and language, the
    /// languages' shares and the day chart, each in its own cell.
    private func islandSummary(_ today: WakaTimeSupport.Today) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                islandPresence
                Spacer(minLength: 4)
                Button { service.refresh(force: true) } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 11, weight: .medium)).zenithIslandGlyph()
                        .frame(width: 22, height: 22).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .zenithIslandHoverTracked()
                .help(text.retry)
                .accessibilityLabel(text.retry)
            }
            .padding(.horizontal, 4)
            if service.hasToken {
                ZenithSegmented(selection: Binding(get: { service.range }, set: { service.select($0) }),
                                options: WakaTimeSupport.Range.allCases.map { ($0, title($0)) })
            }
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    islandTotal(today)
                }
                .fixedSize(horizontal: false, vertical: true)
                ZenithBentoDivider(.horizontal, gap: 1)
                islandTops(today)
                if let languages = languages(today), !languages.isEmpty {
                    ZenithBentoDivider(.horizontal, gap: 1)
                    ZenithBentoCell(label: tokenText.languages) {
                        WakaTimeIslandLanguages(languages: languages, othersTitle: tokenText.others)
                    }
                }
                if !service.days.isEmpty, service.range.summaryRange != nil || !service.hasToken {
                    ZenithBentoDivider(.horizontal, gap: 1)
                    ZenithBentoCell(label: service.range == .today ? text.lastSevenDays : title(service.range)) {
                        WakaTimeIslandChart(days: service.days, locale: locale, height: 52)
                    }
                }
            }
        }
        .animation(ZenithMotion.respecting(ZenithMotion.toggle()), value: service.range)
    }

    /// "● Coding now", or when the last heartbeat came, with the project and editor.
    @ViewBuilder private var islandPresence: some View {
        if let presence = service.presence {
            let coding = presence.isCoding(at: Date())
            HStack(spacing: 6) {
                ZenithStatusLine(color: coding ? ZenithStatus.success : Color.white.opacity(0.4),
                                 text: coding ? tokenText.codingNow : tokenText.lastCoded(relative(presence.lastHeartbeat)),
                                 live: coding, mono: false, size: 12, emphasised: coding)
                if let detail = [presence.project, presence.editor].compactMap({ $0 }).joined(separator: " · ").nonEmpty {
                    Text(detail).font(ZenithType.mono(10.5)).foregroundStyle(ZenithIsland.meta).lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
    }

    @ViewBuilder private func islandTotal(_ today: WakaTimeSupport.Today) -> some View {
        let stats = service.readyStats
        let seconds = service.range == .today ? today.totalSeconds : stats?.totalSeconds
        let goal = service.range == .today && goalMinutes > 0
            ? ZenithStrings.wakaTimeGoal(l10n.language).progress(WakaTimeSupport.duration(Double(goalMinutes * 60), locale: locale))
            : nil
        ZenithBentoCell(label: title(service.range), meta: goal) {
            HStack(alignment: .center, spacing: 10) {
                if let seconds {
                    ZenithFigure(text: WakaTimeSupport.duration(seconds, locale: locale), size: 30)
                        .contentTransition(.numericText())
                        .minimumScaleFactor(0.7)
                } else if service.stats == .pending {
                    Text(tokenText.calculating).font(ZenithType.mono(11)).foregroundStyle(ZenithIsland.meta)
                } else {
                    ProgressView().controlSize(.small)
                }
                Spacer(minLength: 4)
                if service.range == .today,
                   let progress = WakaTimeSupport.goalProgress(totalSeconds: today.totalSeconds, goalMinutes: goalMinutes) {
                    WakaTimeGoalRing(progress: progress, size: 22)
                }
            }
            if service.range != .today, let stats {
                HStack(spacing: 14) {
                    islandCaption(tokenText.dailyAverage, WakaTimeSupport.duration(stats.dailyAverageSeconds, locale: locale))
                    if let best = stats.bestDay {
                        islandCaption(tokenText.bestDay,
                                      "\(shortDate(best)) · \(WakaTimeSupport.duration(stats.bestDaySeconds, locale: locale))")
                    }
                }
            }
        }
    }

    @ViewBuilder private func islandTops(_ today: WakaTimeSupport.Today) -> some View {
        let project: (String, Double)? = service.range == .today
            ? today.projects.first.map { ($0.name, $0.seconds) }
            : service.readyStats?.projects.first.map { ($0.name, $0.seconds) }
        let language: (String, Double)? = service.range == .today
            ? today.languages.first.map { ($0.name, $0.seconds) }
            : service.readyStats?.languages.first.map { ($0.name, $0.seconds) }
        if service.range == .today, today.totalSeconds <= 0 {
            ZenithBentoCell(label: nil) {
                Text(text.nothingYet).font(ZenithType.footnote).foregroundStyle(ZenithIsland.secondary)
            }
        } else {
            HStack(spacing: 0) {
                islandStat(text.topProject, project)
                ZenithBentoDivider(.vertical, gap: 1)
                islandStat(text.topLanguage, language)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func islandStat(_ title: String, _ entry: (String, Double)?) -> some View {
        ZenithBentoCell(label: title, meta: entry.map { WakaTimeSupport.duration($0.1, locale: locale) }) {
            Text(entry?.0 ?? "—")
                .font(.system(size: 15, weight: .semibold))
                .tracking(-0.3)
                .foregroundStyle(ZenithIsland.primary)
                .lineLimit(1).truncationMode(.tail)
        }
    }

    private func islandCaption(_ title: String, _ value: String) -> some View {
        HStack(spacing: 5) {
            Text(title).font(ZenithType.caption).foregroundStyle(ZenithIsland.secondary)
            Text(value).font(ZenithType.mono(10.5)).foregroundStyle(ZenithIsland.primary)
        }
        .lineLimit(1)
    }

    private func summary(_ today: WakaTimeSupport.Today) -> some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 12) {
            if service.hasToken { presenceRow }
            if service.hasToken { rangePicker }
            totals(today)
            if let languages = languages(today), !languages.isEmpty {
                WakaTimeLanguageBar(languages: languages, othersTitle: tokenText.others)
            }
            topRow(today)
            if !service.days.isEmpty, service.range.summaryRange != nil || !service.hasToken {
                WakaTimeDayChart(days: service.days, locale: locale, height: compact ? 40 : 56)
            }
        }
        .animation(ZenithMotion.respecting(ZenithMotion.toggle()), value: service.range)
    }

    // MARK: Rows

    @ViewBuilder
    private var presenceRow: some View {
        if let presence = service.presence {
            let coding = presence.isCoding(at: Date())
            HStack(spacing: 6) {
                Circle()
                    .fill(coding ? ZenithStatus.success : Color.secondary.opacity(0.5))
                    .frame(width: 7, height: 7)
                Text(coding ? tokenText.codingNow : tokenText.lastCoded(relative(presence.lastHeartbeat)))
                    .font(ZenithType.footnote.weight(.semibold))
                    .foregroundStyle(coding ? .primary : .secondary)
                if let detail = [presence.project, presence.editor].compactMap({ $0 }).joined(separator: " · ").nonEmpty {
                    Text(detail).font(ZenithType.footnote).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
    }

    private var rangePicker: some View {
        ZenithPanelSegmented(selection: Binding(get: { service.range }, set: { service.select($0) }),
                             options: WakaTimeSupport.Range.allCases.map { ($0, title($0)) })
    }

    @ViewBuilder
    private func totals(_ today: WakaTimeSupport.Today) -> some View {
        let stats = service.readyStats
        let seconds = service.range == .today ? today.totalSeconds : stats?.totalSeconds
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if service.range == .today,
               let progress = WakaTimeSupport.goalProgress(totalSeconds: today.totalSeconds, goalMinutes: goalMinutes) {
                WakaTimeGoalRing(progress: progress, size: compact ? 18 : 24)
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 2 }
            }
            if let seconds {
                Text(WakaTimeSupport.duration(seconds, locale: locale))
                    .font(ZenithType.figures(compact ? 22 : 30, weight: .bold))
                    .contentTransition(.numericText())
            } else if service.stats == .pending {
                Text(tokenText.calculating).font(ZenithType.footnote).foregroundStyle(.secondary)
            } else {
                ProgressView().controlSize(.small)
            }
            Text(service.range == .today && goalMinutes > 0
                 ? ZenithStrings.wakaTimeGoal(l10n.language).progress(WakaTimeSupport.duration(Double(goalMinutes * 60), locale: locale))
                 : title(service.range))
                .font(ZenithType.footnote).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button { service.refresh(force: true) } label: {
                Image(systemName: "arrow.clockwise").font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(text.retry)
        }
        if service.range != .today, let stats {
            HStack(spacing: 16) {
                caption(tokenText.dailyAverage, WakaTimeSupport.duration(stats.dailyAverageSeconds, locale: locale))
                if let best = stats.bestDay {
                    caption(tokenText.bestDay, "\(shortDate(best)) · \(WakaTimeSupport.duration(stats.bestDaySeconds, locale: locale))")
                }
            }
        }
    }

    @ViewBuilder
    private func topRow(_ today: WakaTimeSupport.Today) -> some View {
        let project: (String, Double)? = service.range == .today
            ? today.projects.first.map { ($0.name, $0.seconds) }
            : service.readyStats?.projects.first.map { ($0.name, $0.seconds) }
        let language: (String, Double)? = service.range == .today
            ? today.languages.first.map { ($0.name, $0.seconds) }
            : service.readyStats?.languages.first.map { ($0.name, $0.seconds) }
        if service.range == .today, today.totalSeconds <= 0 {
            Text(text.nothingYet).font(ZenithType.footnote).foregroundStyle(.secondary)
        } else {
            HStack(alignment: .top, spacing: 16) {
                stat(text.topProject, project)
                stat(text.topLanguage, language)
            }
        }
    }

    /// The stacked bar's languages: the range's shares, or today's from seconds.
    private func languages(_ today: WakaTimeSupport.Today) -> [WakaTimeSupport.Share]? {
        if service.range != .today {
            return service.readyStats.map { WakaTimeSupport.stackedLanguages($0.languages) }
        }
        let total = today.languages.reduce(0) { $0 + $1.seconds }
        guard total > 0 else { return nil }
        return WakaTimeSupport.stackedLanguages(today.languages.map {
            WakaTimeSupport.Share(name: $0.name, percent: $0.seconds / total * 100, seconds: $0.seconds)
        })
    }

    // MARK: Pieces

    private func stat(_ title: String, _ entry: (String, Double)?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(ZenithType.caption).foregroundStyle(.secondary)
            Text(entry?.0 ?? "—").font(ZenithType.emphasis).lineLimit(1).truncationMode(.tail)
            if let entry {
                Text(WakaTimeSupport.duration(entry.1, locale: locale))
                    .font(ZenithType.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func caption(_ title: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(title).foregroundStyle(.secondary)
            Text(value).monospacedDigit()
        }
        .font(ZenithType.caption)
    }

    private func message(symbol: String, _ message: String, retry: Bool) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 18, weight: .light)).foregroundStyle(.secondary)
            Text(message).font(ZenithType.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            if retry {
                Button(text.retry) { service.refresh(force: true) }.controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 60)
    }

    private func title(_ range: WakaTimeSupport.Range) -> String {
        switch range {
        case .today: return tokenText.rangeToday
        case .week: return tokenText.rangeWeek
        case .month: return tokenText.rangeMonth
        case .year: return tokenText.rangeYear
        case .allTime: return tokenText.rangeAll
        }
    }

    private func relative(_ date: Date?) -> String {
        guard let date else { return "—" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func shortDate(_ key: String) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: key) else { return key }
        let out = DateFormatter()
        out.locale = locale
        out.setLocalizedDateFormatFromTemplate("d MMM")
        return out.string(from: date)
    }
}

/// Progress toward the daily goal: grey until it is reached, then emerald.
struct WakaTimeGoalRing: View {
    let progress: Double
    let size: CGFloat

    var body: some View {
        let reached = progress >= 1
        ZStack {
            Circle().stroke(Color.primary.opacity(0.15), lineWidth: size * 0.14)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(reached ? ZenithStatus.success : Color.primary,
                        style: StrokeStyle(lineWidth: size * 0.14, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(ZenithMotion.respecting(ZenithMotion.reveal(ZenithMotion.slow)), value: progress)
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
    }
}

/// Languages as one stacked bar with a legend, after the portfolio's card:
/// the leading language in emerald, the rest in steps of grey.
struct WakaTimeLanguageBar: View {
    let languages: [WakaTimeSupport.Share]
    let othersTitle: String

    private func shade(_ index: Int) -> Color {
        index == 0 ? ZenithStatus.success : Color.primary.opacity(max(0.12, 0.42 - Double(index - 1) * 0.07))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { proxy in
                HStack(spacing: 1.5) {
                    ForEach(Array(languages.enumerated()), id: \.offset) { index, language in
                        Rectangle().fill(shade(index))
                            .frame(width: max(2, proxy.size.width * language.percent / 100))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 6)
            .clipShape(Capsule())
            HStack(spacing: 10) {
                ForEach(Array(languages.prefix(4).enumerated()), id: \.offset) { index, language in
                    HStack(spacing: 4) {
                        Circle().fill(shade(index)).frame(width: 6, height: 6)
                        Text(language.name.isEmpty ? othersTitle : language.name)
                            .foregroundStyle(index == 0 ? .primary : .secondary)
                        Text("\(Int(language.percent.rounded()))%").foregroundStyle(.secondary).monospacedDigit()
                    }
                    .lineLimit(1)
                }
            }
            .font(ZenithType.caption)
        }
    }
}

/// One bar per day, oldest first. Today is drawn at full strength, the rest stepped back.
struct WakaTimeDayChart: View {
    let days: [WakaTimeSupport.Day]
    let locale: Locale
    let height: CGFloat

    var body: some View {
        let peak = max(days.map(\.seconds).max() ?? 0, 1)
        let labelled = days.count <= 7
        HStack(alignment: .bottom, spacing: labelled ? 6 : 2) {
            ForEach(days) { day in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: labelled ? ZenithRadius.small : 1.5, style: .continuous)
                        .fill(Color.primary.opacity(day.isToday ? 0.9 : 0.28))
                        .frame(height: max(3, height * day.seconds / peak))
                        .frame(height: height, alignment: .bottom)
                        .animation(ZenithMotion.respecting(ZenithMotion.reveal()), value: day.seconds)
                    if labelled {
                        Text(WakaTimeSupport.weekdayInitial(day.date, locale: locale))
                            .font(ZenithType.caption)
                            .foregroundStyle(day.isToday ? .primary : .secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(day.date): \(WakaTimeSupport.duration(day.seconds, locale: locale))")
            }
        }
    }
}

/// The island's languages: one 3-point stacked bar in steps of grey with
/// the leading language in emerald, and a legend of small swatches with the
/// shares in mono.
struct WakaTimeIslandLanguages: View {
    let languages: [WakaTimeSupport.Share]
    let othersTitle: String

    private func shade(_ index: Int) -> Color {
        index == 0 ? ZenithIsland.muted(ZenithStatus.success) : Color.white.opacity(max(0.14, 0.5 - Double(index - 1) * 0.09))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                HStack(spacing: 1.5) {
                    ForEach(Array(languages.enumerated()), id: \.offset) { index, language in
                        Rectangle().fill(shade(index))
                            .frame(width: max(2, proxy.size.width * language.percent / 100))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 3)
            .clipShape(Capsule())
            .accessibilityHidden(true)
            HStack(spacing: 12) {
                ForEach(Array(languages.prefix(4).enumerated()), id: \.offset) { index, language in
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 1.5).fill(shade(index)).frame(width: 6, height: 6)
                        Text(language.name.isEmpty ? othersTitle : language.name)
                            .font(.system(size: 11, weight: index == 0 ? .medium : .regular))
                            .foregroundStyle(index == 0 ? ZenithIsland.primary : ZenithIsland.secondary)
                        Text("\(Int(language.percent.rounded()))%")
                            .font(ZenithType.mono(10))
                            .foregroundStyle(ZenithIsland.meta)
                    }
                    .lineLimit(1)
                }
            }
        }
    }
}

/// The island's day chart: thin bars with rounded tops in grey, today's
/// bright, and the weekdays in mono under a week.
struct WakaTimeIslandChart: View {
    let days: [WakaTimeSupport.Day]
    let locale: Locale
    let height: CGFloat

    var body: some View {
        let peak = max(days.map(\.seconds).max() ?? 0, 1)
        let labelled = days.count <= 7
        HStack(alignment: .bottom, spacing: labelled ? 6 : 2) {
            ForEach(days) { day in
                VStack(spacing: 5) {
                    GeometryReader { proxy in
                        ZenithChartBar(fraction: day.seconds / peak, highlighted: day.isToday, minimum: 2)
                            .frame(width: ZenithChart.barWidth(slot: proxy.size.width))
                            .frame(maxWidth: .infinity)
                    }
                    .frame(height: height)
                    .animation(ZenithMotion.respecting(ZenithMotion.reveal()), value: day.seconds)
                    if labelled {
                        Text(WakaTimeSupport.weekdayInitial(day.date, locale: locale))
                            .font(ZenithType.mono(9.5, weight: day.isToday ? .semibold : .regular))
                            .foregroundStyle(day.isToday ? ZenithIsland.primary : ZenithIsland.meta)
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(day.date): \(WakaTimeSupport.duration(day.seconds, locale: locale))")
            }
        }
    }
}

/// Zenith fork: the personal token, in the WakaTime section's settings.
struct WakaTimeTokenSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = WakaTimeService.shared
    @AppStorage(DefaultsKey.wakaTimeDailyGoalMinutes) private var goalMinutes = 0
    @State private var draft = ""
    @State private var rejected = false

    private var text: ZenithWakaTimeTokenStrings { ZenithStrings.wakaTimeToken(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text.tokenTitle).font(ZenithType.emphasis)
            if service.hasToken {
                HStack {
                    Label(text.tokenSaved, systemImage: "checkmark.seal.fill")
                        .foregroundStyle(ZenithStatus.success)
                    Spacer()
                    Button(text.remove, role: .destructive) { service.removeToken() }
                }
            } else {
                HStack {
                    SecureField(text.tokenPlaceholder, text: $draft)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(save)
                    Button(text.save, action: save).disabled(draft.isEmpty)
                }
                if rejected {
                    Text(text.tokenRejected).font(ZenithType.caption).foregroundStyle(ZenithStatus.error)
                }
            }
            Text(text.tokenCaption).font(ZenithType.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Divider().padding(.vertical, 4)
            goalPicker
        }
        .zenithSectionAnchor(.zenithWakaTime) // Settings search lands here
    }

    private var goalPicker: some View {
        let goal = ZenithStrings.wakaTimeGoal(l10n.language)
        let locale = Locale(identifier: l10n.language.rawValue)
        return Picker(goal.goalTitle, selection: $goalMinutes) {
            ForEach(WakaTimeSupport.goalChoices, id: \.self) { minutes in
                Text(minutes == 0 ? goal.goalOff : WakaTimeSupport.duration(Double(minutes * 60), locale: locale))
                    .tag(minutes)
            }
        }
        .onChange(of: goalMinutes) { _, _ in service.syncGoalMonitoring() }
    }

    private func save() {
        guard WakaTimeSupport.isPersonalToken(draft) else { rejected = true; return }
        rejected = false
        if service.saveToken(draft) { draft = "" }
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
