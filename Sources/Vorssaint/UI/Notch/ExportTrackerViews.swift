// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// MARK: Layout

/// Zenith fork: the measures of an export in the closed island, shared by
/// the island's geometry (NotchService) and the strips that draw it, so the
/// wings fit what is drawn.
///
/// Around a camera: the app's mark and the growing size left of the camera,
/// "Exporting" and the file's name right of it (once done, ✓, the final size,
/// and the time it took). In a floating capsule: all of it in one row. The
/// size's slot is as wide as its widest reading, so the wings never move while
/// it grows; the name gives way in its middle.
enum ExportTrackerLayout {
    typealias Support = ExportTrackerSupport

    static let sizeFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
    static let capsuleSizeFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
    static let nameFont = NSFont.systemFont(ofSize: 11, weight: .medium)
    static let leadFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
    static let markSpacing: CGFloat = 5
    static let wordSpacing: CGFloat = 4
    /// Below this wing the size goes and only the mark and the name stay.
    static let sizeWing: CGFloat = 50

    static func iconSize(height: CGFloat) -> CGFloat { min(13, NotchTimerSupport.stripIconSize(height: height)) }

    static func locale(_ language: AppLanguage) -> Locale { language.formattingLocale() }

    static func sizeWidth(font: NSFont, language: AppLanguage) -> CGFloat {
        width(Support.sizeTemplate(locale: locale(language)), font: font)
    }

    /// "Exporting" or "Recording" while it grows, the time it took once done.
    static func lead(_ activity: Support.Activity, language: AppLanguage) -> String {
        let text = ZenithStrings.exportTracker(language)
        switch activity.phase {
        case .running: return activity.isRecording ? text.recording : text.exporting
        case .finished: return CommandActivitySupport.clock(activity.duration)
        }
    }

    /// The file's name, or how many images a batch holds.
    static func name(_ activity: Support.Activity, language: AppLanguage) -> String {
        activity.count.map { Support.filling(ZenithStrings.exportTracker(language).images, count: $0) } ?? activity.name
    }

    static func others(_ activity: Support.Activity) -> String { activity.others > 0 ? "+\(activity.others)" : "" }

    static func detailWidth(_ activity: Support.Activity, language: AppLanguage, font: NSFont = nameFont) -> CGFloat {
        let others = others(activity)
        return width(lead(activity, language: language), font: leadFont) + wordSpacing
            + width(name(activity, language: language), font: font)
            + (others.isEmpty ? 0 : wordSpacing + width(others, font: font))
    }

    /// The wider side, measured as the strip draws it, with the clearance
    /// from the silhouette's curve and air beside the camera. A mark and a
    /// reading, like the watch, so the island lends the watch's wings, whose
    /// limit makes a long name give way rather than the island grow.
    static func stripWing(_ activity: Support.Activity?, language: AppLanguage, in geometry: NotchGeometry) -> CGFloat {
        guard let activity else { return NotchWatchSupport.stripWingRange.lowerBound }
        let provisional = geometry.compactWatchGeometry(wing: NotchWatchSupport.stripWingRange.lowerBound)
        let height = provisional.compactActivityContentHeight
        let icon = iconSize(height: height)
        let iconInset = provisional.compactActivityEdgeInset(boxHeight: icon, radius: icon / 2)
        let textInset = provisional.compactActivityEdgeInset(boxHeight: 8, radius: 0)
        let left = iconInset + icon + markSpacing + sizeWidth(font: sizeFont, language: language)
        let right = textInset + detailWidth(activity, language: language)
        return max(left, right) + NotchTimerSupport.stripCameraGap
    }

    /// The floating capsule's row: mark, size, word and name.
    static func capsuleSurface(_ activity: Support.Activity?, language: AppLanguage, geometry: NotchGeometry) -> CGSize {
        let layout = NotchCapsuleLayout.self
        guard let activity else { return geometry.restingSize(showsContent: false) }
        let content = layout.symbolWidth + layout.spacing + sizeWidth(font: capsuleSizeFont, language: language)
            + layout.groupSpacing + detailWidth(activity, language: language, font: layout.detailFont)
        return layout.surface(content: content, maximum: layout.Maximum.activity, geometry: geometry)
    }

    static func width(_ text: String, font: NSFont) -> CGFloat {
        text.isEmpty ? 0 : (text as NSString).size(withAttributes: [.font: font]).width.rounded(.up) + 2
    }

    static func accessibilityValue(_ activity: Support.Activity, live: Support.Live?, language: AppLanguage) -> String {
        let text = ZenithStrings.exportTracker(language)
        let locale = locale(language)
        let name = name(activity, language: language)
        var parts: [String]
        switch activity.phase {
        case .running:
            let bytes = live?.id == activity.id ? live?.bytes ?? 0 : 0
            parts = [activity.isRecording ? text.recording : text.exporting, name, Support.size(bytes, locale: locale)]
            if let rate = live?.rate, live?.id == activity.id, !Support.rate(rate, locale: locale).isEmpty {
                parts.append(Support.rate(rate, locale: locale))
            }
        case .finished:
            parts = [text.finished, name, Support.finishedDetail(bytes: activity.bytes ?? 0, duration: activity.duration,
                                                                 locale: locale)]
        }
        if let producer = activity.producer { parts.append(producer.name) }
        if activity.others > 0 { parts.append(others(activity)) }
        return parts.joined(separator: ", ")
    }
}

// MARK: Mark

/// The app behind the export: its own icon when it is an app, else a glyph
/// in its colour, breathing gently while the file grows (scale and opacity
/// only). Done, it gives way to a ✓ in emerald with one small spring bump,
/// 1.0 → 1.12 → 1.0. Reduce Motion keeps it still and swaps with a fade.
struct ExportStateMark: View {
    let activity: ExportTrackerSupport.Activity
    let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bumps = 0

    private var finished: Bool { activity.phase == .finished }

    private var swap: AnyTransition {
        reduceMotion ? .opacity : .scale(scale: 0.35).combined(with: .opacity)
    }

    var body: some View {
        ZStack {
            if finished {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.86, weight: .bold))
                    .foregroundStyle(ZenithStatus.success)
                    .transition(swap)
            } else {
                ExportProducerGlyph(activity: activity, size: size)
                    .modifier(ExportBreathing())
                    .transition(swap)
            }
        }
        .frame(width: size, height: size)
        .keyframeAnimator(initialValue: CGFloat(1), trigger: bumps) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                SpringKeyframe(1.12, duration: 0.14, spring: .snappy)
                SpringKeyframe(1, duration: 0.21, spring: .smooth)
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.35, bounce: 0.2), value: finished)
        .onChange(of: finished) { old, new in
            if !old, new, !reduceMotion { bumps += 1 }
        }
        .accessibilityHidden(true)
    }
}

/// The writing app's icon, or a glyph in the colour the island's palette
/// gives it, with a film for a file nobody was seen writing.
private struct ExportProducerGlyph: View {
    let activity: ExportTrackerSupport.Activity
    let size: CGFloat

    var body: some View {
        if let bundle = activity.producer?.bundlePath, let icon = ExportAppIcons.icon(bundle) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: size + 3, height: size + 3)
        } else {
            Image(systemName: activity.symbol)
                .font(.system(size: size * 0.86, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Self.color(activity.producer?.tint ?? 0x2DD4BF))
        }
    }

    static func color(_ value: UInt32) -> Color {
        Color(.sRGB, red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255,
              blue: Double(value & 0xFF) / 255, opacity: 1)
    }
}

/// App icons by bundle path, read once: the strip redraws every second.
private enum ExportAppIcons {
    private static var cache: [String: NSImage] = [:]

    static func icon(_ bundle: String) -> NSImage? {
        if let icon = cache[bundle] { return icon }
        guard FileManager.default.fileExists(atPath: bundle) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: bundle)
        cache[bundle] = icon
        return icon
    }
}

/// A slow breath on the mark while the file grows: transform and opacity
/// only, scoped to them so it never joins the island's own animations.
private struct ExportBreathing: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    func body(content: Content) -> some View {
        content
            .animation(breathing ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true) : .easeOut(duration: 0.2)) {
                $0.scaleEffect(breathing ? 0.88 : 1).opacity(breathing ? 0.7 : 1)
            }
            .onAppear { breathing = !reduceMotion }
            .onChange(of: reduceMotion) { _, reduced in breathing = !reduced }
    }
}

// MARK: Size and detail

/// The size in mono in a slot of fixed width: a new reading rolls only the
/// digits that change and never lays out anything around it.
struct ExportSizeText: View {
    let activity: ExportTrackerSupport.Activity
    let live: ExportTrackerSupport.Live?
    let font: NSFont
    let language: AppLanguage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let bytes = activity.bytes ?? (live?.id == activity.id ? live?.bytes ?? 0 : 0)
        let reading = ExportTrackerSupport.size(bytes, locale: ExportTrackerLayout.locale(language))
        Text(reading)
            .font(Font(font as CTFont))
            .monospacedDigit()
            .lineLimit(1)
            .contentTransition(.numericText(countsDown: false))
            .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: reading)
            .frame(width: ExportTrackerLayout.sizeWidth(font: font, language: language), alignment: .leading)
            .accessibilityHidden(true)
    }
}

/// "Exporting" (or the time it took, once done) in grey, then the name in
/// white, which gives way in its middle, then +N for more exports.
struct ExportDetail: View {
    let activity: ExportTrackerSupport.Activity
    let font: NSFont
    let language: AppLanguage

    var body: some View {
        let others = ExportTrackerLayout.others(activity)
        HStack(spacing: ExportTrackerLayout.wordSpacing) {
            Text(ExportTrackerLayout.lead(activity, language: language))
                .font(Font(ExportTrackerLayout.leadFont as CTFont))
                .foregroundStyle(.white.opacity(0.55))
                .contentTransition(.opacity)
                .layoutPriority(1)
            Text(ExportTrackerLayout.name(activity, language: language))
                .font(Font(font as CTFont))
                .foregroundStyle(.white.opacity(0.92))
                .truncationMode(.middle)
            if !others.isEmpty {
                Text(others)
                    .font(Font(font as CTFont))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.55))
                    .layoutPriority(1)
            }
        }
        .lineLimit(1)
        .accessibilityHidden(true)
    }
}

// MARK: Closed island

/// Zenith fork: an export in the closed island, around the camera: the mark
/// and the size on the left, the word and the name on the right, each
/// anchored to its own edge so the silhouette's curve decides the margin.
/// A click shows the file in Finder.
struct ExportActivityStrip: View {
    @ObservedObject var service: NotchService
    /// Where the island draws it: its own strip as of the last update, or
    /// another display's when the island shows on every display.
    var displayGeometry: NotchGeometry? = nil
    @ObservedObject private var exports = ExportTrackerService.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        // The result going clears the activity before the strip has left.
        NotchStripHold(exports.activity, shows: exports.activity != nil) { activity in
            if let activity { strip(activity) }
        }
    }

    private func strip(_ activity: ExportTrackerSupport.Activity) -> some View {
        let geometry = displayGeometry ?? service.compactActivityGeometry
        let height = geometry.compactActivityContentHeight
        let wing = geometry.compactActivityWingWidth
        let icon = ExportTrackerLayout.iconSize(height: height)
        let language = l10n.language
        return Button { ExportTrackerService.reveal(activity.path) } label: {
            HStack(spacing: 0) {
                HStack(spacing: ExportTrackerLayout.markSpacing) {
                    if wing >= 28 { ExportStateMark(activity: activity, size: icon) }
                    if wing >= ExportTrackerLayout.sizeWing {
                        ExportSizeText(activity: activity, live: exports.live, font: ExportTrackerLayout.sizeFont,
                                       language: language)
                            .foregroundStyle(.white.opacity(0.92))
                    }
                }
                .padding(.leading, geometry.compactActivityEdgeInset(boxHeight: icon, radius: icon / 2))
                .frame(width: wing, height: height, alignment: .leading)
                .clipped()
                Color.clear.frame(width: geometry.compactActivityCameraGap)
                Group {
                    if wing >= 36 {
                        ExportDetail(activity: activity, font: ExportTrackerLayout.nameFont, language: language)
                    }
                }
                .padding(.trailing, geometry.compactActivityEdgeInset(boxHeight: 8, radius: 0))
                .frame(width: wing, height: height, alignment: .trailing)
                .clipped()
            }
            .frame(height: height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, geometry.compactActivityHorizontalPadding)
        .padding(.top, geometry.compactActivityTopPadding)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ZenithStrings.exportTracker(language).activityTitle)
        .accessibilityValue(ExportTrackerLayout.accessibilityValue(activity, live: exports.live, language: language))
        .accessibilityAddTraits(.isButton)
    }
}

/// Zenith fork: an export in the floating capsule: mark, size, word and name
/// in one row.
struct ExportCapsuleStrip: View {
    @ObservedObject var service: NotchService
    let size: CGSize
    /// Another display's capsule, when the island shows on every display.
    var displayGeometry: NotchGeometry? = nil
    @ObservedObject private var exports = ExportTrackerService.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        NotchStripHold(exports.activity, shows: exports.activity != nil) { activity in
            if let activity { row(activity) }
        }
    }

    private func row(_ activity: ExportTrackerSupport.Activity) -> some View {
        let geometry = displayGeometry ?? service.geometry
        let layout = NotchCapsuleLayout.self
        let side = layout.side(geometry)
        let language = l10n.language
        return Button { ExportTrackerService.reveal(activity.path) } label: {
            HStack(spacing: layout.spacing) {
                ExportStateMark(activity: activity, size: layout.symbolSize)
                    .frame(width: layout.symbolWidth)
                ExportSizeText(activity: activity, live: exports.live, font: ExportTrackerLayout.capsuleSizeFont,
                               language: language)
                ExportDetail(activity: activity, font: layout.detailFont, language: language)
                    .padding(.leading, layout.groupSpacing - layout.spacing)
            }
            .padding(.leading, side + layout.endPadding)
            .padding(.trailing, side + layout.endPadding)
            .frame(width: size.width, height: geometry.stripHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ZenithStrings.exportTracker(language).activityTitle)
        .accessibilityValue(ExportTrackerLayout.accessibilityValue(activity, live: exports.live, language: language))
        .accessibilityAddTraits(.isButton)
    }
}
