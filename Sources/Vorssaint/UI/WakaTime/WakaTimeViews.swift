// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Zenith fork: the WakaTime page in the Dynamic Island.
struct NotchWakaTimeView: View {
    let size: CGSize

    var body: some View {
        WakaTimeSummary(compact: false)
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

/// Today's total, the top project and language, and the last seven days.
/// Grey throughout, after the Style Kit: today's bar is the only bright one.
struct WakaTimeSummary: View {
    let compact: Bool
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = WakaTimeService.shared

    private var text: ZenithWakaTimeStrings { ZenithStrings.wakaTime(l10n.language) }
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
            summary(today)
        }
    }

    private func summary(_ today: WakaTimeSupport.Today) -> some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(WakaTimeSupport.duration(today.totalSeconds, locale: locale))
                    .font(ZenithType.figures(compact ? 22 : 30, weight: .bold))
                    .contentTransition(.numericText())
                Text(text.today)
                    .font(ZenithType.footnote)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Button { service.refresh() } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(text.retry)
            }
            if today.totalSeconds <= 0 {
                Text(text.nothingYet).font(ZenithType.footnote).foregroundStyle(.secondary)
            } else {
                HStack(alignment: .top, spacing: 16) {
                    stat(text.topProject, today.projects.first)
                    stat(text.topLanguage, today.languages.first)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(text.lastSevenDays).font(ZenithType.caption).foregroundStyle(.secondary)
                WakaTimeWeekChart(days: service.days, locale: locale, height: compact ? 44 : 64)
            }
        }
    }

    private func stat(_ title: String, _ entry: WakaTimeSupport.Entry?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(ZenithType.caption).foregroundStyle(.secondary)
            Text(entry?.name ?? "—").font(ZenithType.emphasis).lineLimit(1).truncationMode(.tail)
            if let entry {
                Text(WakaTimeSupport.duration(entry.seconds, locale: locale))
                    .font(ZenithType.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func message(symbol: String, _ message: String, retry: Bool) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 18, weight: .light)).foregroundStyle(.secondary)
            Text(message).font(ZenithType.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            if retry {
                Button(text.retry) { service.refresh() }.controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 60)
    }
}

/// Seven bars, oldest first. Today is drawn at full strength, the rest stepped back.
struct WakaTimeWeekChart: View {
    let days: [WakaTimeSupport.Day]
    let locale: Locale
    let height: CGFloat

    var body: some View {
        let peak = max(days.map(\.seconds).max() ?? 0, 1)
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(days) { day in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: ZenithRadius.small, style: .continuous)
                        .fill(Color.primary.opacity(day.isToday ? 0.9 : 0.28))
                        .frame(height: max(3, height * day.seconds / peak))
                        .frame(height: height, alignment: .bottom)
                        .animation(ZenithMotion.respecting(ZenithMotion.reveal()), value: day.seconds)
                    Text(WakaTimeSupport.weekdayInitial(day.date, locale: locale))
                        .font(ZenithType.caption)
                        .foregroundStyle(day.isToday ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(day.date): \(WakaTimeSupport.duration(day.seconds, locale: locale))")
            }
        }
    }
}
