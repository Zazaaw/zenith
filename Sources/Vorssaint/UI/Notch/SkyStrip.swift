// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// MARK: Colours

/// Zenith fork: the Sky section's colours. Identity, never status: a dusk
/// indigo for the prayers (the section's own), a warm amber for the golden
/// hour and a soft blue for the blue hour.
enum SkyPalette {
    static let goldenHex: UInt32 = 0xFCD34D  // amber 300
    static let blueHex: UInt32 = 0x93C5FD    // blue 300
    static var prayer: Color { NotchModule.sky.zenithTint }
    static var golden: Color { ZenithIslandPalette.color(hex: goldenHex) }
    static var blue: Color { ZenithIslandPalette.color(hex: blueHex) }

    static func color(_ band: SolarSupport.Band) -> Color { band == .golden ? golden : blue }
}

enum SkyStripKind: Equatable { case prayer, golden }

/// What a strip shows, kept by the strip while it leaves the island.
enum SkyStripState: Equatable {
    case prayer(PrayerTimesSupport.Activity)
    case golden(SkyGoldenSupport.Activity)
}

// MARK: Layout

/// Zenith fork: a prayer's countdown and the golden hour in the closed
/// island, measured for the island's geometry (NotchService) and drawn by
/// the strips below, so the wings fit what is drawn.
///
/// Around a camera: the glyph and a mono reading left of it (the countdown
/// `-12:04`, or the time once it came; the golden hour's start, then its
/// end), the words right of it (the prayer's name, "Waktunya Dzuhur",
/// "Golden hour in 32 min"). Each side is measured for its widest reading in
/// every phase of the activity, so the wings never move while it counts
/// down or when the time comes.
enum SkyStripLayout {
    static let readingFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
    static let capsuleReadingFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
    static let wordsFont = NSFont.systemFont(ofSize: 11, weight: .medium)
    static let markSpacing: CGFloat = 5
    /// Below this wing only the glyph stays on the left.
    static let readingWing: CGFloat = 50

    static func iconSize(height: CGFloat) -> CGFloat { min(12, NotchTimerSupport.stripIconSize(height: height)) }

    /// The activity the service publishes for this kind, if any.
    static func state(_ kind: SkyStripKind) -> SkyStripState? {
        switch kind {
        case .prayer: return SkyService.shared.prayerActivity.map(SkyStripState.prayer)
        case .golden: return SkyService.shared.goldenActivity.map(SkyStripState.golden)
        }
    }

    /// What each side reads at `now`.
    static func reading(_ state: SkyStripState, now: Date, language: AppLanguage) -> (left: String, right: String) {
        let sky = SkyService.shared
        let text = ZenithStrings.sky(language)
        let locale = language.formattingLocale()
        switch state {
        case .prayer(let activity):
            let prayer = activity.moment.prayer
            switch activity {
            case .upcoming(let moment):
                return (PrayerTimesSupport.countdown(moment.time.timeIntervalSince(now)), sky.name(prayer, language: language))
            case .arrived(let moment):
                return (PrayerTimesSupport.clock(moment.time, locale: locale),
                        text.arrival(prayer, indonesian: sky.usesIndonesianNames))
            }
        case .golden(let activity):
            switch activity {
            case .upcoming(let window):
                let minutes = PrayerTimesSupport.minutesLeft(window.start.timeIntervalSince(now))
                return (PrayerTimesSupport.clock(window.start, locale: locale), text.filling(text.goldenIn, text.minutes(minutes)))
            case .during(let window):
                let minutes = PrayerTimesSupport.minutesLeft(window.end.timeIntervalSince(now))
                return (PrayerTimesSupport.clock(window.end, locale: locale), text.filling(text.goldenLeft, text.minutes(minutes)))
            }
        }
    }

    /// The widest each side gets in any phase of the current activity.
    static func templates(_ kind: SkyStripKind, language: AppLanguage) -> (left: [String], right: [String]) {
        let sky = SkyService.shared
        let text = ZenithStrings.sky(language)
        let clock = PrayerTimesSupport.clock(Self.widestClock, timeZone: TimeZone(identifier: "UTC") ?? .current,
                                             locale: language.formattingLocale())
        switch kind {
        case .prayer:
            let prayer = sky.prayerActivity?.moment.prayer ?? .maghrib
            return ([PrayerTimesSupport.countdownTemplate(long: false), clock],
                    [sky.name(prayer, language: language), text.arrival(prayer, indonesian: sky.usesIndonesianNames)])
        case .golden:
            let minutes = text.minutes(88)
            return ([clock], [text.filling(text.goldenIn, minutes), text.filling(text.goldenLeft, minutes)])
        }
    }

    /// 22:58 UTC: the widest digits a clock shows, in 24 and 12 hours.
    private static let widestClock = Date(timeIntervalSince1970: 22 * 3600 + 58 * 60)

    static func stripWing(_ kind: SkyStripKind, language: AppLanguage, in geometry: NotchGeometry) -> CGFloat {
        let provisional = geometry.compactWatchGeometry(wing: NotchWatchSupport.stripWingRange.lowerBound)
        let height = provisional.compactActivityContentHeight
        let icon = iconSize(height: height)
        let iconInset = provisional.compactActivityEdgeInset(boxHeight: icon, radius: icon / 2)
        let textInset = provisional.compactActivityEdgeInset(boxHeight: 8, radius: 0)
        let templates = templates(kind, language: language)
        let left = iconInset + icon + markSpacing + (templates.left.map { width($0, font: readingFont) }.max() ?? 0)
        let right = textInset + (templates.right.map { width($0, font: wordsFont) }.max() ?? 0)
        return max(left, right) + NotchTimerSupport.stripCameraGap
    }

    /// The floating capsule's row: glyph, reading and words.
    static func capsuleSurface(_ kind: SkyStripKind, language: AppLanguage, geometry: NotchGeometry) -> CGSize {
        let layout = NotchCapsuleLayout.self
        let active = kind == .prayer ? SkyService.shared.prayerActivity != nil : SkyService.shared.goldenActivity != nil
        guard active else { return geometry.restingSize(showsContent: false) }
        let templates = templates(kind, language: language)
        let content = layout.symbolWidth + layout.spacing
            + (templates.left.map { width($0, font: capsuleReadingFont) }.max() ?? 0)
            + layout.groupSpacing + (templates.right.map { layout.width($0, font: layout.detailFont) }.max() ?? 0)
        return layout.surface(content: content, maximum: layout.Maximum.activity, geometry: geometry)
    }

    static func width(_ text: String, font: NSFont) -> CGFloat {
        text.isEmpty ? 0 : (text as NSString).size(withAttributes: [.font: font]).width.rounded(.up) + 2
    }

    static func symbol(_ state: SkyStripState) -> String {
        switch state {
        case .prayer(let activity): return activity.moment.prayer.symbol
        case .golden: return NotchCompactActivity.golden.symbol
        }
    }

    static func tint(_ kind: SkyStripKind) -> Color { kind == .prayer ? SkyPalette.prayer : SkyPalette.golden }

    /// A key for the phase, so the words swap through the morph only when it changes.
    static func phase(_ state: SkyStripState) -> String {
        switch state {
        case .prayer(.upcoming(let moment)): return "up." + moment.prayer.rawValue
        case .prayer(.arrived(let moment)): return "at." + moment.prayer.rawValue
        case .golden(.upcoming): return "up"
        case .golden(.during): return "during"
        }
    }

    static func title(_ kind: SkyStripKind, language: AppLanguage) -> String {
        kind == .prayer ? NotchCompactActivity.prayer.title(language) : NotchCompactActivity.golden.title(language)
    }
}

// MARK: Pieces

/// The activity's glyph in its colour. A prayer's time coming gives it one
/// soft bump; the glyph itself swaps by scale and opacity. Reduce Motion
/// keeps it still.
private struct SkyStripGlyph: View {
    let symbol: String
    let tint: Color
    let size: CGFloat
    let phase: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bumps = 0

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.92, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .id(symbol)
            .transition(reduceMotion ? .opacity : .scale(scale: 0.5).combined(with: .opacity))
            .keyframeAnimator(initialValue: CGFloat(1), trigger: bumps) { content, scale in
                content.scaleEffect(scale)
            } keyframes: { _ in
                KeyframeTrack(\.self) {
                    SpringKeyframe(1.16, duration: 0.16, spring: .snappy)
                    SpringKeyframe(1, duration: 0.24, spring: .smooth)
                }
            }
            .onChange(of: phase) { old, new in
                if old.hasPrefix("up"), !new.hasPrefix("up"), !reduceMotion { bumps += 1 }
            }
            .animation(reduceMotion ? IslandMotion.easeInOut(0.2) : IslandMotion.spring(duration: 0.35, bounce: 0.2), value: symbol)
            .accessibilityHidden(true)
    }
}

/// The two readings, ticking once a second inside a TimelineView that wraps
/// only them: the digits roll in a slot of fixed width, nothing around them
/// lays out again.
private struct SkyStripReadings<Content: View>: View {
    let state: SkyStripState
    let language: AppLanguage
    @ViewBuilder let content: (_ left: String, _ right: String) -> Content

    var body: some View {
        TimelineView(.periodic(from: Calendar.current.startOfDay(for: Date()), by: 1)) { context in
            let reading = SkyStripLayout.reading(state, now: context.date, language: language)
            content(reading.left, reading.right)
        }
    }
}

// MARK: Closed island

/// Zenith fork: a prayer's countdown or the golden hour in the closed
/// island, around the camera.
struct SkyActivityStrip: View {
    @ObservedObject var service: NotchService
    let kind: SkyStripKind
    /// Where the island draws it: its own strip as of the last update, or
    /// another display's when the island shows on every display.
    var displayGeometry: NotchGeometry? = nil
    @ObservedObject private var sky = SkyService.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let current = SkyStripLayout.state(kind)
        // The activity ending clears it before the strip has left.
        NotchStripHold(current, shows: current != nil) { state in
            if let state { strip(state) }
        }
    }

    private func strip(_ state: SkyStripState) -> some View {
        let geometry = displayGeometry ?? service.compactActivityGeometry
        let height = geometry.compactActivityContentHeight
        let wing = geometry.compactActivityWingWidth
        let icon = SkyStripLayout.iconSize(height: height)
        let phase = SkyStripLayout.phase(state)
        let readingWidth = SkyStripLayout.templates(kind, language: l10n.language).left
            .map { SkyStripLayout.width($0, font: SkyStripLayout.readingFont) }.max() ?? 0
        return Button { service.openActivity(.sky) } label: {
            SkyStripReadings(state: state, language: l10n.language) { left, right in
                HStack(spacing: 0) {
                    HStack(spacing: SkyStripLayout.markSpacing) {
                        if wing >= 28 {
                            SkyStripGlyph(symbol: SkyStripLayout.symbol(state), tint: SkyStripLayout.tint(kind), size: icon, phase: phase)
                        }
                        if wing >= SkyStripLayout.readingWing {
                            Text(left)
                                .font(Font(SkyStripLayout.readingFont as CTFont))
                                .monospacedDigit()
                                .lineLimit(1)
                                .foregroundStyle(.white.opacity(0.92))
                                .contentTransition(.numericText(countsDown: true))
                                .animation(reduceMotion ? nil : IslandMotion.smooth(0.3), value: left)
                                .frame(width: readingWidth, alignment: .leading)
                        }
                    }
                    .padding(.leading, geometry.compactActivityEdgeInset(boxHeight: icon, radius: icon / 2))
                    .frame(width: wing, height: height, alignment: .leading)
                    .clipped()
                    Color.clear.frame(width: geometry.compactActivityCameraGap)
                    Group {
                        if wing >= 36 {
                            Text(right)
                                .font(Font(SkyStripLayout.wordsFont as CTFont))
                                .monospacedDigit()
                                .lineLimit(1).truncationMode(.tail)
                                .contentTransition(.numericText(countsDown: true))
                                .animation(reduceMotion ? nil : IslandMotion.smooth(0.3), value: right)
                                .zenithMorph(on: phase)
                        }
                    }
                    .padding(.trailing, geometry.compactActivityEdgeInset(boxHeight: 8, radius: 0))
                    .frame(width: wing, height: height, alignment: .trailing)
                    .clipped()
                }
                .frame(height: height)
                .contentShape(Rectangle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(SkyStripLayout.title(kind, language: l10n.language))
                .accessibilityValue(right + ", " + left)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, geometry.compactActivityHorizontalPadding)
        .padding(.top, geometry.compactActivityTopPadding)
        .accessibilityHint(FeatureStrings.notch(l10n.language).open)
    }
}

/// Zenith fork: a prayer's countdown or the golden hour in the floating
/// capsule, in one row.
struct SkyCapsuleStrip: View {
    @ObservedObject var service: NotchService
    let kind: SkyStripKind
    let size: CGSize
    /// Another display's capsule, when the island shows on every display.
    var displayGeometry: NotchGeometry? = nil
    @ObservedObject private var sky = SkyService.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let current = SkyStripLayout.state(kind)
        NotchStripHold(current, shows: current != nil) { state in
            if let state { row(state) }
        }
    }

    private func row(_ state: SkyStripState) -> some View {
        let geometry = displayGeometry ?? service.geometry
        let layout = NotchCapsuleLayout.self
        let side = layout.side(geometry)
        let phase = SkyStripLayout.phase(state)
        let readingWidth = SkyStripLayout.templates(kind, language: l10n.language).left
            .map { SkyStripLayout.width($0, font: SkyStripLayout.capsuleReadingFont) }.max() ?? 0
        return Button { service.openActivity(.sky) } label: {
            SkyStripReadings(state: state, language: l10n.language) { left, right in
                HStack(spacing: layout.spacing) {
                    SkyStripGlyph(symbol: SkyStripLayout.symbol(state), tint: SkyStripLayout.tint(kind),
                                  size: layout.symbolSize, phase: phase)
                        .frame(width: layout.symbolWidth)
                    Text(left)
                        .font(Font(SkyStripLayout.capsuleReadingFont as CTFont))
                        .monospacedDigit()
                        .lineLimit(1)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(reduceMotion ? nil : IslandMotion.smooth(0.3), value: left)
                        .frame(width: readingWidth, alignment: .leading)
                    Text(right)
                        .font(Font(layout.detailFont as CTFont))
                        .lineLimit(1).truncationMode(.tail)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(reduceMotion ? nil : IslandMotion.smooth(0.3), value: right)
                        .zenithMorph(on: phase)
                        .padding(.leading, layout.groupSpacing - layout.spacing)
                }
                .padding(.leading, side + layout.endPadding)
                .padding(.trailing, side + layout.endPadding)
                .frame(width: size.width, height: geometry.stripHeight)
                .contentShape(Rectangle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(SkyStripLayout.title(kind, language: l10n.language))
                .accessibilityValue(right + ", " + left)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .accessibilityHint(FeatureStrings.notch(l10n.language).open)
    }
}
