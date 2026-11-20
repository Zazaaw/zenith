// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// MARK: Layout

/// Zenith fork: a card import in the closed island, measured for the
/// island's geometry (NotchService) and drawn by the strips below, so the
/// wings fit what is drawn.
///
/// Around a camera: the camera glyph and the percentage left of it, the files
/// left and the time left right of it over a thin bar. In a floating capsule
/// the same in one row. Every slot is as wide as its widest reading for this
/// import (100%, the card's whole count left, 1h 59m), so the wings never
/// move while the numbers roll; only the import ending changes them, once.
enum CardImportStripLayout {
    static let percentFont = NSFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
    static let capsulePercentFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
    static let detailFont = NSFont.monospacedSystemFont(ofSize: 10.5, weight: .medium)
    static let resultFont = NSFont.systemFont(ofSize: 11, weight: .medium)
    static let markSpacing: CGFloat = 5
    static let barHeight: CGFloat = 2
    static let capsuleBarWidth: CGFloat = 34
    /// Below this wing only the glyph stays on the left.
    static let percentWing: CGFloat = 48

    static func iconSize(height: CGFloat) -> CGFloat { min(12, NotchTimerSupport.stripIconSize(height: height)) }

    static func percentText(_ percent: Int) -> String { "\(min(100, max(0, percent)))%" }

    /// What the right side reads: `812 left · 3m` while copying, the count
    /// and size once done, what went wrong after a failure.
    static func detail(_ activity: CardImportActivity, progress: CardImportProgress?, language: AppLanguage) -> String {
        let text = ZenithStrings.cardImport(language)
        let locale = language.formattingLocale()
        switch activity {
        case .copying(let total):
            let left = progress.map { $0.totalFiles > 0 ? $0.filesLeft : total } ?? total
            var reading = CardImportFormat.filling(text.left, CardImportFormat.count(left, locale: locale))
            if let eta = progress?.eta { reading += " · " + CardImportFormat.eta(eta, locale: locale) }
            return reading
        case let .finished(files, bytes):
            return CardImportFormat.summary(files: files, bytes: bytes, language: language)
        case .failed(let failure):
            switch failure {
            case .cardRemoved: return text.cardRemoved
            case .diskFull: return text.diskFull
            case .failed: return text.failed
            }
        }
    }

    /// The widest the right side gets during this activity.
    static func detailTemplate(_ activity: CardImportActivity, language: AppLanguage) -> String {
        guard case .copying(let total) = activity else { return detail(activity, progress: nil, language: language) }
        let text = ZenithStrings.cardImport(language)
        let locale = language.formattingLocale()
        let count = CardImportFormat.filling(text.left, CardImportFormat.count(max(total, 10), locale: locale))
        let times = [CardImportFormat.eta(55, locale: locale), CardImportFormat.eta(59 * 60, locale: locale),
                     CardImportFormat.eta(119 * 60, locale: locale)]
        return times.map { count + " · " + $0 }.max { width($0, font: detailFont) < width($1, font: detailFont) } ?? count
    }

    static func font(for activity: CardImportActivity) -> NSFont {
        if case .copying = activity { return detailFont }
        return resultFont
    }

    static func stripWing(_ activity: CardImportActivity?, language: AppLanguage, in geometry: NotchGeometry) -> CGFloat {
        guard let activity else { return NotchWatchSupport.stripWingRange.lowerBound }
        let provisional = geometry.compactWatchGeometry(wing: NotchWatchSupport.stripWingRange.lowerBound)
        let height = provisional.compactActivityContentHeight
        let icon = iconSize(height: height)
        let iconInset = provisional.compactActivityEdgeInset(boxHeight: icon, radius: icon / 2)
        let textInset = provisional.compactActivityEdgeInset(boxHeight: 8, radius: 0)
        let left = iconInset + icon + markSpacing + width(percentText(100), font: percentFont)
        let right = textInset + width(detailTemplate(activity, language: language), font: font(for: activity))
        return max(left, right) + NotchTimerSupport.stripCameraGap
    }

    /// The floating capsule's row: glyph, percent, bar and the reading.
    static func capsuleSurface(_ activity: CardImportActivity?, language: AppLanguage,
                               geometry: NotchGeometry) -> CGSize {
        let layout = NotchCapsuleLayout.self
        guard let activity else { return geometry.restingSize(showsContent: false) }
        var content = layout.symbolWidth + layout.groupSpacing
            + layout.width(detailTemplate(activity, language: language), font: font(for: activity))
        if case .copying = activity {
            content += layout.spacing + width(percentText(100), font: capsulePercentFont) + layout.spacing + capsuleBarWidth
        }
        return layout.surface(content: content, maximum: layout.Maximum.activity, geometry: geometry)
    }

    static func width(_ text: String, font: NSFont) -> CGFloat {
        text.isEmpty ? 0 : (text as NSString).size(withAttributes: [.font: font]).width.rounded(.up) + 2
    }

    static func accessibilityValue(_ activity: CardImportActivity, progress: CardImportProgress,
                                   language: AppLanguage) -> String {
        let reading = detail(activity, progress: progress, language: language)
        if case .copying = activity { return percentText(progress.percent) + ", " + reading }
        return reading
    }
}

// MARK: Mark

/// The import's state: the camera glyph in the module's colour while it
/// copies, then a check in emerald that draws itself with `trim`, or a cross
/// in red. The glyph shrinks away as the result grows in; only scale,
/// opacity and trim animate. Reduce Motion swaps them with a fade.
struct CardImportMark: View {
    enum Phase: Equatable { case copying, finished, failed }

    let phase: Phase
    let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ activity: CardImportActivity, size: CGFloat) {
        switch activity {
        case .copying: phase = .copying
        case .finished: phase = .finished
        case .failed: phase = .failed
        }
        self.size = size
    }

    private var swap: AnyTransition {
        reduceMotion ? .opacity : .scale(scale: 0.4).combined(with: .opacity)
    }

    var body: some View {
        ZStack {
            switch phase {
            case .copying:
                Image(systemName: NotchCompactActivity.cardImport.symbol)
                    .font(.system(size: size * 0.86, weight: .semibold))
                    .foregroundStyle(NotchModule.cardImport.zenithTint)
                    .transition(swap)
            case .finished:
                CardImportCheck(color: ZenithStatus.success, lineWidth: max(1.6, size * 0.16))
                    .frame(width: size * 0.9, height: size * 0.9)
                    .transition(swap)
            case .failed:
                Image(systemName: "xmark")
                    .font(.system(size: size * 0.78, weight: .bold))
                    .foregroundStyle(ZenithStatus.error)
                    .transition(swap)
            }
        }
        .frame(width: size, height: size)
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.35, bounce: 0.2), value: phase)
        .accessibilityHidden(true)
    }
}

/// A checkmark that draws itself once it appears, with `trim`.
struct CardImportCheck: View {
    let color: Color
    var lineWidth: CGFloat = 2
    var delay: Double = 0.08
    @State private var drawn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        CardImportCheckShape()
            .trim(from: 0, to: drawn || reduceMotion ? 1 : 0)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 0.32).delay(delay)) { drawn = true }
            }
    }
}

struct CardImportCheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.midY + rect.height * 0.04))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.4, y: rect.maxY - rect.height * 0.16))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.06, y: rect.minY + rect.height * 0.16))
        return path
    }
}

/// A thin bar whose fill slides by scale from its leading edge, so a new
/// reading never lays the strip out again.
struct CardImportBar: View {
    let fraction: Double
    var height: CGFloat = CardImportStripLayout.barHeight
    var tint: Color = NotchModule.cardImport.zenithTint
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let value = fraction.isFinite ? min(1, max(0, fraction)) : 0
        ZStack(alignment: .leading) {
            Capsule(style: .continuous).fill(Color.white.opacity(0.14))
            Capsule(style: .continuous).fill(tint)
                .scaleEffect(x: max(0.0001, value), y: 1, anchor: .leading)
                .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: value)
        }
        .frame(height: height)
        .clipShape(Capsule(style: .continuous))
        .accessibilityHidden(true)
    }
}

/// The percentage in mono, its digits rolling.
struct CardImportPercent: View {
    let percent: Int
    let font: NSFont
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(CardImportStripLayout.percentText(percent))
            .font(Font(font as CTFont))
            .monospacedDigit()
            .lineLimit(1)
            .contentTransition(.numericText(value: Double(percent)))
            .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: percent)
            .frame(width: CardImportStripLayout.width(CardImportStripLayout.percentText(100), font: font),
                   alignment: .leading)
            .accessibilityHidden(true)
    }
}

// MARK: Closed island

/// Zenith fork: a card import in the closed island, around the camera.
struct CardImportActivityStrip: View {
    @ObservedObject var service: NotchService
    /// Where the island draws it: its own strip as of the last update, or
    /// another display's when the island shows on every display.
    var displayGeometry: NotchGeometry? = nil
    @ObservedObject private var imports = CardImportService.shared
    @ObservedObject private var meter = CardImportService.shared.meter
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        // The result going clears the activity before the strip has left.
        NotchStripHold(imports.activity, shows: imports.activity != nil) { activity in
            if let activity { strip(activity) }
        }
    }

    private func strip(_ activity: CardImportActivity) -> some View {
        let geometry = displayGeometry ?? service.compactActivityGeometry
        let height = geometry.compactActivityContentHeight
        let wing = geometry.compactActivityWingWidth
        let icon = CardImportStripLayout.iconSize(height: height)
        let progress = meter.progress
        let copying: Bool = { if case .copying = activity { return true } else { return false } }()
        return Button { service.openActivity(NotchCompactActivity.cardImport.module) } label: {
            HStack(spacing: 0) {
                HStack(spacing: CardImportStripLayout.markSpacing) {
                    if wing >= 28 { CardImportMark(activity, size: icon) }
                    if wing >= CardImportStripLayout.percentWing, copying {
                        CardImportPercent(percent: progress.percent, font: CardImportStripLayout.percentFont)
                            .foregroundStyle(.white.opacity(0.92))
                            .transition(.opacity)
                    }
                }
                .padding(.leading, geometry.compactActivityEdgeInset(boxHeight: icon, radius: icon / 2))
                .frame(width: wing, height: height, alignment: .leading)
                .clipped()
                Color.clear.frame(width: geometry.compactActivityCameraGap)
                Group {
                    if wing >= 36 {
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(CardImportStripLayout.detail(activity, progress: progress, language: l10n.language))
                                .font(Font(CardImportStripLayout.font(for: activity) as CTFont))
                                .monospacedDigit()
                                .lineLimit(1).truncationMode(.tail)
                                .contentTransition(.numericText())
                                .animation(ZenithMotion.respecting(.smooth(duration: 0.3)), value: progress.filesLeft)
                            if copying { CardImportBar(fraction: progress.fraction).frame(maxWidth: .infinity) }
                        }
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
        .accessibilityLabel(ZenithStrings.cardImport(l10n.language).title)
        .accessibilityValue(CardImportStripLayout.accessibilityValue(activity, progress: progress, language: l10n.language))
        .accessibilityHint(FeatureStrings.notch(l10n.language).open)
    }
}

/// Zenith fork: a card import in the floating capsule, in one row.
struct CardImportCapsuleStrip: View {
    @ObservedObject var service: NotchService
    let size: CGSize
    /// Another display's capsule, when the island shows on every display.
    var displayGeometry: NotchGeometry? = nil
    @ObservedObject private var imports = CardImportService.shared
    @ObservedObject private var meter = CardImportService.shared.meter
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        NotchStripHold(imports.activity, shows: imports.activity != nil) { activity in
            if let activity { row(activity) }
        }
    }

    private func row(_ activity: CardImportActivity) -> some View {
        let geometry = displayGeometry ?? service.geometry
        let layout = NotchCapsuleLayout.self
        let side = layout.side(geometry)
        let progress = meter.progress
        let copying: Bool = { if case .copying = activity { return true } else { return false } }()
        return Button { service.openActivity(NotchCompactActivity.cardImport.module) } label: {
            HStack(spacing: layout.spacing) {
                CardImportMark(activity, size: layout.symbolSize)
                    .frame(width: layout.symbolWidth)
                if copying {
                    CardImportPercent(percent: progress.percent, font: CardImportStripLayout.capsulePercentFont)
                    CardImportBar(fraction: progress.fraction, height: 3)
                        .frame(width: CardImportStripLayout.capsuleBarWidth)
                }
                Text(CardImportStripLayout.detail(activity, progress: progress, language: l10n.language))
                    .font(Font(CardImportStripLayout.font(for: activity) as CTFont))
                    .monospacedDigit()
                    .lineLimit(1).truncationMode(.tail)
                    .contentTransition(.numericText())
                    .animation(ZenithMotion.respecting(.smooth(duration: 0.3)), value: progress.filesLeft)
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
        .accessibilityLabel(ZenithStrings.cardImport(l10n.language).title)
        .accessibilityValue(CardImportStripLayout.accessibilityValue(activity, progress: progress, language: l10n.language))
        .accessibilityHint(FeatureStrings.notch(l10n.language).open)
    }
}
