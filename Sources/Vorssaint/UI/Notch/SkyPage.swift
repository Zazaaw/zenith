// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: the Sky page in the open island. Two views behind one calm
// switch: today's prayer times (the next one tinted, the period under way
// marked softly, a mono countdown), and the golden and blue hours for a
// photographer (the next windows, a countdown, the sun's elevation and a
// small arc of its path today). Swaps go through the island's morph; the
// countdown rolls its digits in a slot of fixed width, ticking inside a
// TimelineView that wraps only the text.

enum SkyPageTab: String, CaseIterable { case prayer, golden }

struct SkyPage: View {
    let size: CGSize
    @ObservedObject private var sky = SkyService.shared
    @ObservedObject private var weather = WeatherService.shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchSkyPage) private var tab = SkyPageTab.prayer.rawValue

    private var text: ZenithSkyStrings { ZenithStrings.sky(l10n.language) }
    private var selected: SkyPageTab { SkyPageTab(rawValue: tab) ?? .prayer }

    var body: some View {
        TimelineView(.everyMinute) { context in
            let day = sky.currentDay(now: context.date)
            VStack(alignment: .leading, spacing: 10) {
                header(day)
                Group {
                    if let day {
                        switch selected {
                        case .prayer: SkyPrayerView(day: day, text: text)
                        case .golden: SkyGoldenView(day: day, text: text)
                        }
                    } else {
                        SkyLocationPrompt(text: text, access: weather.access)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .zenithMorph(on: day == nil ? "none" : selected.rawValue)
            }
        }
        .frame(width: size.width, height: max(size.height, SkyPageMetrics.minimumHeight), alignment: .top)
        .environment(\.locale, l10n.language.formattingLocale())
        .onAppear {
            weather.refreshAccess()
            sky.viewShown()
        }
    }

    private func header(_ day: SkyDay?) -> some View {
        HStack(spacing: 10) {
            ZenithSegmented(selection: Binding(get: { selected }, set: { tab = $0.rawValue }),
                            options: [(SkyPageTab.prayer, text.prayerTab), (SkyPageTab.golden, text.goldenTab)],
                            height: 26, fontSize: 11.5, fills: false)
                .fixedSize()
            Spacer(minLength: 8)
            if let day {
                // A chosen city by name; an approximate position never.
                Text([day.place.name, selected == .prayer ? day.configuration.method.title : nil]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(ZenithType.mono(10))
                    .foregroundStyle(ZenithIsland.meta)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Prayer times

private struct SkyPrayerView: View {
    let day: SkyDay
    let text: ZenithSkyStrings
    @ObservedObject private var sky = SkyService.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let now = Date()
        let next = PrayerTimesSupport.next(after: now, in: day.moments)
        let current = PrayerTimesSupport.current(at: now, in: day.moments)
        VStack(alignment: .leading, spacing: 12) {
            if let next {
                SkyCountdownHero(label: text.next + " · " + sky.name(next.prayer, language: l10n.language),
                                 symbol: next.prayer.symbol, tint: SkyPalette.prayer, target: next.time,
                                 detail: PrayerTimesSupport.clock(next.time, locale: l10n.language.formattingLocale()))
            }
            HStack(spacing: 6) {
                ForEach(Prayer.allCases) { prayer in
                    if let time = day.today?.time(prayer) {
                        SkyPrayerTile(name: sky.name(prayer, language: l10n.language),
                                      time: PrayerTimesSupport.clock(time, locale: l10n.language.formattingLocale()),
                                      isNext: next.map { $0.prayer == prayer && day.contains($0.time) } ?? false,
                                      isCurrent: current.map { $0.prayer == prayer && day.contains($0.time) } ?? false,
                                      isPast: time <= now && current?.time != time)
                    }
                }
            }
            if day.today?.approximated == true {
                Text(text.approximated)
                    .font(.system(size: 10.5))
                    .foregroundStyle(ZenithIsland.meta)
            }
        }
    }
}

/// One time of the day on a soft card: the next tinted in the section's
/// colour, the one under way with a small dot, those past dimmer.
private struct SkyPrayerTile: View {
    let name: String
    let time: String
    let isNext: Bool
    let isCurrent: Bool
    let isPast: Bool
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: ZenithIsland.nestedRadius(padding: 6), style: .continuous)
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                if isCurrent {
                    Circle().fill(Color.white.opacity(0.7)).frame(width: 4, height: 4)
                }
                Text(name)
                    .font(.system(size: 10.5, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(isNext ? SkyPalette.prayer : isPast ? ZenithIsland.meta : ZenithIsland.secondary)
            Text(time)
                .font(ZenithType.mono(12, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(isPast ? ZenithIsland.secondary : ZenithIsland.primary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .background(isNext ? ZenithIsland.tileFill(SkyPalette.prayer, contrast: contrast) : ZenithIsland.cardFill, in: shape)
        .overlay {
            shape.strokeBorder(isNext ? ZenithIsland.tileStroke(SkyPalette.prayer, contrast: contrast)
                               : contrast == .increased ? ZenithIsland.contrastHairline : ZenithIsland.cardStroke,
                               lineWidth: 0.75)
        }
        .animation(ZenithMotion.respecting(ZenithMorph.animation), value: isNext)
        .accessibilityElement(children: .combine)
    }
}

/// A heading with its glyph on a soft tile, a large mono countdown that rolls
/// its digits, and a quieter reading beside it.
private struct SkyCountdownHero<Trailing: View>: View {
    let label: String
    let symbol: String
    let tint: Color
    let target: Date
    let detail: String
    @ViewBuilder var trailing: () -> Trailing
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZenithIslandGlyphTile(symbol: symbol, tint: tint, size: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(label.uppercased())
                    .font(ZenithType.mono(9.5, weight: .medium))
                    .tracking(0.4)
                    .foregroundStyle(ZenithIsland.label)
                    .lineLimit(1)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    TimelineView(.periodic(from: Calendar.current.startOfDay(for: Date()), by: 1)) { context in
                        let interval = target.timeIntervalSince(context.date)
                        Text(PrayerTimesSupport.countdown(interval))
                            .font(.system(size: 24, weight: .semibold, design: .monospaced))
                            .monospacedDigit()
                            .tracking(-0.5)
                            .foregroundStyle(ZenithIsland.primary)
                            .contentTransition(.numericText(countsDown: true))
                            .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: Int(interval.rounded(.up)))
                            .lineLimit(1)
                    }
                    // Fixed to the widest reading, so a tick never moves what follows.
                    .frame(width: SkyStripLayout.width(PrayerTimesSupport.countdownTemplate(long: true),
                                                       font: .monospacedSystemFont(ofSize: 24, weight: .semibold)),
                           alignment: .leading)
                    Text(detail)
                        .font(ZenithType.mono(12))
                        .foregroundStyle(ZenithIsland.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            trailing()
        }
        .accessibilityElement(children: .combine)
    }
}

extension SkyCountdownHero where Trailing == EmptyView {
    init(label: String, symbol: String, tint: Color, target: Date, detail: String) {
        self.init(label: label, symbol: symbol, tint: tint, target: target, detail: detail) { EmptyView() }
    }
}

// MARK: - Golden hour

private struct SkyGoldenView: View {
    let day: SkyDay
    let text: ZenithSkyStrings
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let now = Date()
        let upcoming = day.upcomingWindows(after: now)
        let golden = upcoming.first { $0.band == .golden }
        let locale = l10n.language.formattingLocale()
        VStack(alignment: .leading, spacing: 12) {
            if let golden {
                let during = golden.contains(now)
                SkyCountdownHero(label: during ? text.goldenTab : text.next + " · " + text.goldenTab,
                                 symbol: golden.morning ? "sunrise.fill" : "sunset.fill", tint: SkyPalette.golden,
                                 target: during ? golden.end : golden.start,
                                 detail: range(golden, locale: locale)) {
                    SkySunArc(day: day)
                        .frame(width: 150, height: 52)
                }
            } else {
                HStack {
                    Text(text.noWindows)
                        .font(.system(size: 12))
                        .foregroundStyle(ZenithIsland.secondary)
                    Spacer()
                    SkySunArc(day: day).frame(width: 150, height: 52)
                }
            }
            HStack(spacing: 6) {
                ForEach(upcoming.prefix(4)) { window in
                    SkyWindowTile(title: window.band == .golden ? text.goldenTab : text.blueHour,
                                  when: day.contains(window.start) ? (window.morning ? text.morning : text.evening) : text.tomorrow,
                                  range: range(window, locale: locale), tint: SkyPalette.color(window.band),
                                  live: window.contains(now))
                }
            }
        }
    }

    private func range(_ window: SolarSupport.Window, locale: Locale) -> String {
        PrayerTimesSupport.clock(window.start, locale: locale) + "–" + PrayerTimesSupport.clock(window.end, locale: locale)
    }
}

/// A window on a soft card: its band in its colour, when, and its range in mono.
private struct SkyWindowTile: View {
    let title: String
    let when: String
    let range: String
    let tint: Color
    let live: Bool
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: ZenithIsland.nestedRadius(padding: 6), style: .continuous)
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Circle().fill(tint).frame(width: 5, height: 5)
                Text(title).font(.system(size: 10.5, weight: .medium)).foregroundStyle(tint).lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
                Text(when).font(.system(size: 10)).foregroundStyle(ZenithIsland.meta).lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Text(range)
                .font(ZenithType.mono(11.5, weight: .semibold))
                .foregroundStyle(ZenithIsland.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(live ? ZenithIsland.tileFill(tint, contrast: contrast) : ZenithIsland.cardFill, in: shape)
        .overlay {
            shape.strokeBorder(live ? ZenithIsland.tileStroke(tint, contrast: contrast)
                               : contrast == .increased ? ZenithIsland.contrastHairline : ZenithIsland.cardStroke,
                               lineWidth: 0.75)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Today's sun path as a thin arc over a hairline horizon, the golden band a
/// faint warm strip, and a small marker where the sun is now with its
/// elevation beside it. Redrawn each minute; the marker glides there.
struct SkySunArc: View {
    let day: SkyDay
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The elevation the arc's height spans, above and below the horizon.
    private static let top: Double = 90
    private static let bottom: Double = -30

    var body: some View {
        let path = SolarSupport.path(midnight: day.start, coordinate: day.place.coordinate)
        TimelineView(.everyMinute) { context in
            let now = context.date
            let fraction = min(1, max(0, now.timeIntervalSince(day.start) / 86_400))
            let elevation = SolarSupport.elevation(at: now, coordinate: day.place.coordinate)
            GeometryReader { proxy in
                let size = proxy.size
                let peak = max(10, path.max() ?? 60)
                let low = min(-10, path.min() ?? -30)
                let y: (Double) -> CGFloat = { value in
                    let clamped = min(peak, max(low, value))
                    return size.height * CGFloat((peak - clamped) / (peak - low))
                }
                let horizon = y(0)
                ZStack(alignment: .topLeading) {
                    // The golden band, from −4° to +6°.
                    Rectangle()
                        .fill(SkyPalette.golden.opacity(0.10))
                        .frame(height: max(1, y(-4) - y(6)))
                        .offset(y: y(6))
                    Rectangle().fill(Color.white.opacity(0.16)).frame(height: 0.75).offset(y: horizon)
                    Path { line in
                        for (index, value) in path.enumerated() {
                            let point = CGPoint(x: size.width * CGFloat(index) / CGFloat(max(1, path.count - 1)), y: y(value))
                            index == 0 ? line.move(to: point) : line.addLine(to: point)
                        }
                    }
                    .stroke(Color.white.opacity(0.4), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
                    .mask {
                        // Bright above the horizon, faint below it.
                        VStack(spacing: 0) {
                            Color.white.frame(height: max(0, horizon))
                            Color.white.opacity(0.35)
                        }
                    }
                    let marker = CGPoint(x: size.width * CGFloat(fraction), y: y(elevation))
                    Circle()
                        .fill(elevation > -6 ? SkyPalette.golden : SkyPalette.blue)
                        .frame(width: 7, height: 7)
                        .shadow(color: (elevation > -6 ? SkyPalette.golden : SkyPalette.blue).opacity(0.7), radius: 4)
                        .position(marker)
                        .animation(reduceMotion ? nil : .smooth(duration: 0.6), value: marker)
                    Text(SkyGoldenSupport.elevationText(elevation, locale: L10n.shared.language.formattingLocale()))
                        .font(ZenithType.mono(9.5, weight: .medium))
                        .foregroundStyle(ZenithIsland.label)
                        .position(x: min(max(18, marker.x), size.width - 18),
                                  y: marker.y > size.height / 2 ? marker.y - 11 : marker.y + 11)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(ZenithStrings.sky(L10n.shared.language).sun)
            .accessibilityValue(SkyGoldenSupport.elevationText(elevation, locale: L10n.shared.language.formattingLocale()))
        }
    }
}

// MARK: - No place yet

/// Before there is a place: allow the approximate location (the same flow
/// as the weather, asked only by this button), open System Settings when it
/// was denied, or choose a city in Settings.
struct SkyLocationPrompt: View {
    let text: ZenithSkyStrings
    let access: LockScreenWidgetAccess
    var compact = false
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let home = ZenithStrings.home(l10n.language)
        let automatic = SkyService.shared.settings.source == .automatic
        VStack(spacing: compact ? 6 : 10) {
            if !compact {
                ZenithIslandGlyphTile(symbol: NotchModule.sky.symbol, tint: SkyPalette.prayer, size: 40)
            }
            Text(access == .denied && automatic ? text.locationDenied : text.needsLocation)
                .font(.system(size: compact ? 10.5 : 12))
                .foregroundStyle(ZenithIsland.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(compact ? 2 : 3)
                .frame(maxWidth: 300)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                if automatic, access == .notDetermined {
                    button(home.allowLocation, primary: true) { WeatherService.shared.requestAccess() }
                } else if automatic, access == .denied, !compact {
                    button(home.openSettings, primary: false) { WeatherService.shared.openLocationSettings() }
                }
                if !compact || access != .notDetermined {
                    button(text.chooseCity, primary: !(automatic && access == .notDetermined)) {
                        NotchService.shared.openSettings(showing: .sky)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func button(_ title: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .frame(height: 22)
                .modifier(SkyPromptButton(primary: primary))
        }
        .buttonStyle(.plain)
    }
}

private struct SkyPromptButton: ViewModifier {
    let primary: Bool

    func body(content: Content) -> some View {
        if primary {
            content.modifier(ZenithIslandPrimaryAction())
        } else {
            content
                .foregroundStyle(ZenithIsland.primary)
                .background(Capsule().fill(Color.white.opacity(0.1)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.75))
        }
    }
}
