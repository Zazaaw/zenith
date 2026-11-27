// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: the Sky section on the home page (two widgets for Customize
// Home) and on the lock screen (one item each in the line under the clock).
// They read the day SkyService keeps and never start anything; the
// approximate location is renewed only when access was already granted.

// MARK: - Home

/// The next prayer, its time and the countdown, with the day's five as dots
/// along the bottom. Without a place, the location prompt; never a request.
struct SkyHomePrayerWidget: View {
    let service: NotchService
    @ObservedObject private var sky = SkyService.shared
    @ObservedObject private var weather = WeatherService.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let text = ZenithStrings.sky(l10n.language)
        TimelineView(.periodic(from: Calendar.current.startOfDay(for: Date()), by: 1)) { context in
            let now = context.date
            let day = sky.currentDay(now: now)
            Button { service.select(.sky) } label: {
                VStack(alignment: .leading, spacing: 4) {
                    SkyHomeHeader(symbol: Prayer.maghrib.symbol, hex: ZenithIslandPalette.hex(.sky), title: text.prayerTab)
                    if let day, let next = PrayerTimesSupport.next(after: now, in: day.moments) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(sky.name(next.prayer, language: l10n.language))
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(SkyPalette.prayer)
                                .lineLimit(1)
                            Text(PrayerTimesSupport.clock(next.time, locale: l10n.language.formattingLocale()))
                                .font(ZenithType.mono(11))
                                .foregroundStyle(ZenithIsland.secondary)
                                .lineLimit(1)
                        }
                        let interval = next.time.timeIntervalSince(now)
                        Text(PrayerTimesSupport.countdown(interval))
                            .font(ZenithType.mono(18, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(ZenithIsland.primary)
                            .contentTransition(.numericText(countsDown: true))
                            .animation(reduceMotion ? nil : IslandMotion.smooth(0.3), value: Int(interval.rounded(.up)))
                            .lineLimit(1)
                    } else {
                        SkyLocationPrompt(text: text, access: weather.access, compact: true)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .onAppear { sky.viewShown() }
    }
}

/// The next golden hour (or the one under way) with its countdown, and the
/// sun's small arc for today.
struct SkyHomeGoldenWidget: View {
    let service: NotchService
    @ObservedObject private var sky = SkyService.shared
    @ObservedObject private var weather = WeatherService.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let text = ZenithStrings.sky(l10n.language)
        TimelineView(.periodic(from: Calendar.current.startOfDay(for: Date()), by: 1)) { context in
            let now = context.date
            let day = sky.currentDay(now: now)
            Button {
                UserDefaults.standard.set(SkyPageTab.golden.rawValue, forKey: DefaultsKey.notchSkyPage)
                service.select(.sky)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    SkyHomeHeader(symbol: "sun.horizon.fill", hex: SkyPalette.goldenHex, title: text.goldenTab)
                    if let day {
                        HStack(alignment: .bottom, spacing: 8) {
                            if let golden = day.upcomingWindows(after: now).first(where: { $0.band == .golden }) {
                                let during = golden.contains(now)
                                let interval = (during ? golden.end : golden.start).timeIntervalSince(now)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(PrayerTimesSupport.clock(golden.start, locale: l10n.language.formattingLocale()) + "–"
                                         + PrayerTimesSupport.clock(golden.end, locale: l10n.language.formattingLocale()))
                                        .font(ZenithType.mono(10.5))
                                        .foregroundStyle(ZenithIsland.secondary)
                                        .lineLimit(1)
                                    Text(PrayerTimesSupport.countdown(interval))
                                        .font(ZenithType.mono(18, weight: .semibold))
                                        .monospacedDigit()
                                        .foregroundStyle(during ? SkyPalette.golden : ZenithIsland.primary)
                                        .contentTransition(.numericText(countsDown: true))
                                        .animation(reduceMotion ? nil : IslandMotion.smooth(0.3), value: Int(interval.rounded(.up)))
                                        .lineLimit(1)
                                }
                            }
                            Spacer(minLength: 0)
                            SkySunArc(day: day).frame(width: 72, height: 34)
                        }
                    } else {
                        SkyLocationPrompt(text: text, access: weather.access, compact: true)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .onAppear { sky.viewShown() }
    }
}

/// A widget's heading, as the other home widgets draw theirs.
private struct SkyHomeHeader: View {
    let symbol: String
    let hex: UInt32
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            ZenithIslandIcon(symbol: symbol, hex: hex, size: 16, lifted: false)
            Text(title.uppercased())
                .font(ZenithType.mono(9.5, weight: .medium))
                .tracking(0.4)
                .foregroundStyle(ZenithIsland.label)
                .lineLimit(1)
            Spacer(minLength: 4)
        }
        .frame(height: 16)
    }
}

// MARK: - Lock screen

/// The lock screen's items: white like the rest of the line, the place never named.
enum SkyLockScreen {
    /// Whether the item has something to show at `date`.
    static func showsPrayer(at date: Date) -> Bool {
        SkyService.shared.currentDay(now: date).flatMap { PrayerTimesSupport.next(after: date, in: $0.moments) } != nil
    }

    static func showsGolden(at date: Date) -> Bool {
        SkyService.shared.currentDay(now: date)?.upcomingWindows(after: date).contains { $0.band == .golden } == true
    }
}

/// `☾ Ashar 15:04` and a dim `in 1h 04m`.
struct SkyLockScreenPrayerEntry: View {
    let date: Date
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let sky = SkyService.shared
        if let day = sky.currentDay(now: date), let next = PrayerTimesSupport.next(after: date, in: day.moments) {
            let name = sky.name(next.prayer, language: l10n.language)
            let time = PrayerTimesSupport.clock(next.time, locale: l10n.language.formattingLocale())
            HStack(spacing: 7) {
                Image(systemName: next.prayer.symbol)
                Text(name + " " + time)
                Text(PrayerTimesSupport.shortDuration(next.time.timeIntervalSince(date)))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(ZenithStrings.sky(l10n.language).lockPrayer)
            .accessibilityValue(name + ", " + time)
        }
    }
}

/// `☀ 17:21–18:04`, or the minutes left while it lasts.
struct SkyLockScreenGoldenEntry: View {
    let date: Date
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let text = ZenithStrings.sky(l10n.language)
        let locale = l10n.language.formattingLocale()
        if let window = SkyService.shared.currentDay(now: date)?.upcomingWindows(after: date).first(where: { $0.band == .golden }) {
            let range = PrayerTimesSupport.clock(window.start, locale: locale) + "–" + PrayerTimesSupport.clock(window.end, locale: locale)
            HStack(spacing: 7) {
                Image(systemName: "sun.horizon.fill")
                if window.contains(date) {
                    Text(text.filling(text.goldenLeft, text.minutes(PrayerTimesSupport.minutesLeft(window.end.timeIntervalSince(date)))))
                } else {
                    Text(range)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(text.lockGolden)
            .accessibilityValue(range)
        }
    }
}
