// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Batteries is adapted from the Batteries droplet by Akhil Chandran (MIT) —
// see the notice in About.

import AppKit
import SwiftUI

// Zenith fork: a device's low battery in the island. The card is the
// droplet's Battery Low card (LowBatteryCard), drawn inside the island grown
// for five seconds (ZenithIslandBurst): the device's name and its level over
// two lines of advice on the left, a red battery filled to the level beside
// the device's symbol on the right. After it, the compact form keeps the
// closed island's wings: the device's symbol left of the camera, a red
// battery and the level right of it, so it never reads as the Mac's own.

/// The card's row, as the burst lays it out below the camera.
struct BatteriesLowCard: View {
    let low: ZenithBatteryLowBurst

    private typealias Metrics = BatteriesCardMetrics

    var body: some View {
        HStack(alignment: .center, spacing: Metrics.rowSpacing) {
            VStack(alignment: .leading, spacing: Metrics.titleDescriptionSpacing) {
                HStack(spacing: Metrics.titleRowSpacing) {
                    Text(verbatim: low.name)
                        .font(Font(Metrics.titleFont))
                        .foregroundStyle(ZenithIsland.primary.opacity(0.8))
                        .lineLimit(1)
                    Text(verbatim: "\(low.percent)%")
                        .font(Font(Metrics.percentFont))
                        .monospacedDigit()
                        .foregroundStyle(BatteriesPalette.red)
                        .fixedSize()
                }
                Text(verbatim: low.detail)
                    .font(Font(Metrics.detailFont))
                    .foregroundStyle(ZenithIsland.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .fixedSize(horizontal: false, vertical: true)
            // The words take the room the slot leaves, keeping the droplet's
            // spacer (its minimum and the gap after it) before the slot.
            .padding(.trailing, Metrics.textSpacerMinimum + Metrics.rowSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)

            // The symbol's ink, not its box, ends on the card's inset,
            // whatever the device's symbol is.
            HStack(spacing: Metrics.indicatorSpacing) {
                BatteriesCardBattery(level: CGFloat(low.percent) / 100, tint: BatteriesPalette.red,
                                     width: Metrics.batteryWidth, height: Metrics.batteryHeight)
                Image(systemName: low.symbol)
                    .font(.system(size: Metrics.symbolSize, weight: .semibold))
                    .foregroundStyle(ZenithIsland.primary)
                    .frame(minWidth: 0, maxWidth: Metrics.symbolWidth)
                    .fixedSize()
                    .padding(.trailing, -BatteriesSymbolInk.trailingBearing(of: low.symbol, pointSize: Metrics.symbolSize))
            }
            .frame(width: Metrics.slot.width, height: Metrics.slot.height, alignment: .trailing)
        }
        .frame(height: Metrics.rowHeight)
        .accessibilityElement(children: .ignore)
    }
}

// MARK: - Symbol ink

/// How far an SF Symbol's ink stops short of its image's trailing edge at a
/// point size and semibold: drawn once per symbol at 2x and scanned.
enum BatteriesSymbolInk {
    nonisolated(unsafe) private static var cache: [String: CGFloat] = [:]

    static func trailingBearing(of name: String, pointSize: CGFloat) -> CGFloat {
        let key = "\(name)@\(pointSize)"
        if let cached = cache[key] { return cached }
        let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) else { return 0 }
        let scale: CGFloat = 2
        let width = Int((image.size.width * scale).rounded(.up)), height = Int((image.size.height * scale).rounded(.up))
        guard width > 0, height > 0,
              let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        else { return 0 }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        NSGraphicsContext.restoreGraphicsState()
        var lastInkColumn = -1
        for x in stride(from: width - 1, through: 0, by: -1) {
            var lit = false
            for y in 0..<height where (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.5 {
                lit = true
                break
            }
            if lit { lastInkColumn = x; break }
        }
        let bearing = lastInkColumn < 0 ? 0 : CGFloat(width - 1 - lastInkColumn) / scale
        cache[key] = bearing
        return bearing
    }
}

// MARK: - The card's battery

/// The droplet's battery, measured from the box it is drawn in: every
/// proportion derives from the body's height and every fixed edge lands on
/// the pixel grid.
private struct BatteriesBatteryGeometry {
    static let cornerRatio: CGFloat = 0.3
    static let capGapRatio: CGFloat = 0.07
    static let capWidthRatio: CGFloat = 0.12
    static let capHeightRatio: CGFloat = 0.4
    static let minimumAspect: CGFloat = 1.5
    static let fullLevel: CGFloat = 0.995

    let body: CGRect
    let cap: CGRect
    let cornerRadius: CGFloat
    let capRadius: CGFloat

    init(in rect: CGRect, scale: CGFloat) {
        let pixel = 1 / max(scale, 1)
        func snapped(_ value: CGFloat) -> CGFloat { (value / pixel).rounded() * pixel }

        let height = max(pixel * 4, snapped(min(rect.height, rect.width / Self.minimumAspect)))
        let gap = max(pixel, snapped(height * Self.capGapRatio))
        let capWidth = max(pixel, snapped(height * Self.capWidthRatio))
        var capHeight = max(pixel * 2, snapped(height * Self.capHeightRatio))
        if Int(((height - capHeight) / pixel).rounded()) % 2 != 0 {
            capHeight += pixel
        }
        let bodyWidth = max(height, (rect.width / pixel).rounded(.down) * pixel - gap - capWidth)
        let origin = CGPoint(x: rect.minX + snapped((rect.width - (bodyWidth + gap + capWidth)) / 2),
                             y: rect.minY + snapped((rect.height - height) / 2))
        body = CGRect(origin: origin, size: CGSize(width: bodyWidth, height: height))
        cap = CGRect(x: body.maxX + gap, y: body.minY + (height - capHeight) / 2, width: capWidth, height: capHeight)
        cornerRadius = height * Self.cornerRatio
        capRadius = min(capWidth * 0.9, capHeight / 2)
    }
}

private struct BatteriesBatteryBody: InsettableShape {
    var scale: CGFloat
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let geometry = BatteriesBatteryGeometry(in: rect, scale: scale)
        return Path(roundedRect: geometry.body.insetBy(dx: insetAmount, dy: insetAmount),
                    cornerRadius: max(0, geometry.cornerRadius - insetAmount), style: .continuous)
    }

    func inset(by amount: CGFloat) -> BatteriesBatteryBody {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}

private struct BatteriesBatteryCap: Shape {
    var scale: CGFloat

    func path(in rect: CGRect) -> Path {
        let geometry = BatteriesBatteryGeometry(in: rect, scale: scale)
        let outer = geometry.capRadius
        let inner = min(outer, geometry.cap.width * 0.25)
        return Path(roundedRect: geometry.cap,
                    cornerRadii: RectangleCornerRadii(topLeading: inner, bottomLeading: inner,
                                                      bottomTrailing: outer, topTrailing: outer),
                    style: .continuous)
    }
}

private struct BatteriesBatteryCharge: Shape {
    var level: CGFloat
    var scale: CGFloat

    var animatableData: CGFloat {
        get { level }
        set { level = min(1, max(0, newValue)) }
    }

    func path(in rect: CGRect) -> Path {
        let body = BatteriesBatteryGeometry(in: rect, scale: scale).body
        let overdraw: CGFloat = 1
        let charged = body.width * min(1, max(0, level))
        guard charged > 0 else { return Path() }
        return Path(CGRect(x: body.minX - overdraw, y: body.minY - overdraw,
                           width: charged + overdraw, height: body.height + overdraw * 2))
    }
}

/// The battery's finish on the island's black.
private struct BatteriesBatteryTone {
    let emptyTop: Double
    let emptyBottom: Double
    let emptyCap: Double
    let rim: Double
    let edgeLight: Double
    let highlight: Double
    let shade: Double

    init(isHighContrast: Bool) {
        let boost = isHighContrast ? 0.14 : 0
        emptyTop = 0.36 + boost
        emptyBottom = 0.25 + boost
        emptyCap = 0.32 + boost
        rim = isHighContrast ? 0.6 : 0
        edgeLight = 0.2
        highlight = 0.28
        shade = 0.12
    }

    var depth: LinearGradient {
        LinearGradient(stops: [.init(color: .white.opacity(highlight), location: 0),
                               .init(color: .white.opacity(0), location: 0.55),
                               .init(color: .black.opacity(shade), location: 1)],
                       startPoint: .top, endPoint: .bottom)
    }
}

/// A continuous-cornered body with a terminal cap, filled left to right to
/// the exact level, the empty part a translucent form of the same tint.
struct BatteriesCardBattery: View {
    let level: CGFloat
    let tint: Color
    let width: CGFloat
    let height: CGFloat

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let scale = displayScale
        let tone = BatteriesBatteryTone(isHighContrast: colorSchemeContrast == .increased)
        let charge = level.isFinite ? min(1, max(0, level)) : 0
        let isFull = charge >= BatteriesBatteryGeometry.fullLevel

        ZStack {
            BatteriesBatteryBody(scale: scale)
                .fill(LinearGradient(colors: [tint.opacity(tone.emptyTop), tint.opacity(tone.emptyBottom)],
                                     startPoint: .top, endPoint: .bottom))
            ZStack {
                BatteriesBatteryCharge(level: charge, scale: scale).fill(tint)
                BatteriesBatteryCharge(level: charge, scale: scale).fill(tone.depth)
            }
            .clipShape(BatteriesBatteryBody(scale: scale))
            if tone.rim > 0 {
                BatteriesBatteryBody(scale: scale)
                    .strokeBorder(tint.opacity(tone.rim), lineWidth: 1 / max(scale, 1))
            }
            BatteriesBatteryBody(scale: scale)
                .strokeBorder(LinearGradient(colors: [.white.opacity(tone.edgeLight), .white.opacity(0)],
                                             startPoint: .top, endPoint: .center),
                              lineWidth: 1 / max(scale, 1))
            BatteriesBatteryCap(scale: scale)
                .fill(tint.opacity(isFull ? 1 : tone.emptyCap))
            BatteriesBatteryCap(scale: scale)
                .fill(tone.depth)
                .opacity(isFull ? 1 : 0)
        }
        .frame(width: width, height: height)
        .compositingGroup()
        .accessibilityHidden(true)
    }
}

// MARK: - The compact form

enum BatteriesStripLayout {
    private typealias Metrics = BatteriesStripMetrics

    /// A symbol's box at the strip's size, as the strip draws it.
    static func symbolWidth(_ name: String, size: CGFloat) -> CGFloat {
        let configuration = NSImage.SymbolConfiguration(pointSize: size, weight: .semibold)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(configuration)
        return (image?.size.width ?? size).rounded(.up)
    }

    /// The red battery and the level, right of the camera.
    static func readingWidth(_ indicator: BatteriesLowIndicator) -> CGFloat {
        symbolWidth(BatteriesIslandSupport.batterySymbol(percent: indicator.percent), size: Metrics.batterySize)
            + Metrics.batteryGap + Metrics.percentWidth(indicator.percent)
    }

    /// The wider side, measured as the strip draws it, with the clearance
    /// from the silhouette's curve and air beside the camera.
    static func stripWing(_ indicator: BatteriesLowIndicator?, in geometry: NotchGeometry) -> CGFloat {
        let range = NotchWatchSupport.stripWingRange
        guard let indicator else { return range.lowerBound }
        let provisional = geometry.compactWatchGeometry(wing: range.lowerBound)
        let glyphInset = provisional.compactActivityEdgeInset(boxHeight: Metrics.glyphSize, radius: 0)
        let textInset = provisional.compactActivityEdgeInset(boxHeight: 8, radius: 0)
        let left = glyphInset + symbolWidth(indicator.symbol, size: Metrics.glyphSize)
        let right = textInset + readingWidth(indicator)
        return min(range.upperBound, max(left, right) + NotchTimerSupport.stripCameraGap)
    }

    /// The floating capsule's row: the device, the battery and the level.
    static func capsuleSurface(_ indicator: BatteriesLowIndicator?, geometry: NotchGeometry) -> CGSize {
        let layout = NotchCapsuleLayout.self
        guard let indicator else { return geometry.restingSize(showsContent: false) }
        let content = layout.symbolWidth + layout.groupSpacing + readingWidth(indicator)
        return layout.surface(content: content, maximum: layout.Maximum.activity, geometry: geometry)
    }

    static func accessibilityValue(_ indicator: BatteriesLowIndicator, language: AppLanguage) -> String {
        let text = ZenithStrings.batteriesIsland(language)
        return [indicator.name, text.lowTitle,
                text.percentValue.replacingOccurrences(of: "{percent}", with: "\(indicator.percent)")]
            .joined(separator: ", ")
    }
}

/// The device's symbol, white.
private struct BatteriesStripDevice: View {
    let indicator: BatteriesLowIndicator
    var size: CGFloat = BatteriesStripMetrics.glyphSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: indicator.symbol)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(ZenithIsland.primary)
            .fixedSize()
            .id(indicator.deviceID)
            .transition(reduceMotion ? AnyTransition.opacity : AnyTransition(.blurReplace))
    }
}

/// A red battery at the level's step and the level beside it.
private struct BatteriesStripReading: View {
    let indicator: BatteriesLowIndicator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private typealias Metrics = BatteriesStripMetrics

    var body: some View {
        HStack(spacing: Metrics.batteryGap) {
            Image(systemName: BatteriesIslandSupport.batterySymbol(percent: indicator.percent))
                .font(.system(size: Metrics.batterySize, weight: .semibold))
                .foregroundStyle(BatteriesPalette.red)
                .contentTransition(.symbolEffect(.replace))
            Text(verbatim: "\(indicator.percent)%")
                .font(Font(Metrics.percentFont as CTFont))
                .foregroundStyle(BatteriesPalette.red)
                .contentTransition(reduceMotion ? .opacity : .numericText(value: Double(indicator.percent)))
        }
        .lineLimit(1)
        .fixedSize()
        .animation(reduceMotion ? nil : IslandMotion.smooth(0.3), value: indicator.percent)
    }
}

struct BatteriesActivityStrip: View {
    @ObservedObject var service: NotchService
    /// Where the island draws it: its own strip as of the last update, or
    /// another display's when the island shows on every display.
    var displayGeometry: NotchGeometry? = nil
    @ObservedObject private var batteries = BatteriesIslandService.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        // The alert answered clears it before the strip has left.
        NotchStripHold(batteries.indicator, shows: batteries.indicator != nil) { indicator in
            if let indicator { strip(indicator) }
        }
    }

    private func strip(_ indicator: BatteriesLowIndicator) -> some View {
        let geometry = displayGeometry ?? service.compactActivityGeometry
        return Button { service.openActivity(NotchCompactActivity.batteries.module) } label: {
            BatteriesStripContent(indicator: indicator, geometry: geometry)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, geometry.compactActivityHorizontalPadding)
        .padding(.top, geometry.compactActivityTopPadding)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ZenithStrings.batteriesIsland(l10n.language).title)
        .accessibilityValue(BatteriesStripLayout.accessibilityValue(indicator, language: l10n.language))
        .accessibilityHint(ZenithStrings.batteriesIsland(l10n.language).open)
    }
}

/// The compact form's wings in the closed island at `geometry`: the device
/// left of the camera, the reading right of it, inside the strip's padding.
/// Also the Settings preview's.
struct BatteriesStripContent: View {
    let indicator: BatteriesLowIndicator
    let geometry: NotchGeometry

    var body: some View {
        let height = geometry.compactActivityContentHeight
        let wing = geometry.compactActivityWingWidth
        HStack(spacing: 0) {
            BatteriesStripDevice(indicator: indicator)
                .padding(.leading, geometry.compactActivityEdgeInset(boxHeight: BatteriesStripMetrics.glyphSize, radius: 0))
                .frame(width: wing, height: height, alignment: .leading)
                .clipped()
            Color.clear.frame(width: geometry.compactActivityCameraGap)
            BatteriesStripReading(indicator: indicator)
                .padding(.trailing, geometry.compactActivityEdgeInset(boxHeight: 8, radius: 0))
                .frame(width: wing, height: height, alignment: .trailing)
                .clipped()
        }
        .frame(height: height)
        .contentShape(Rectangle())
    }
}

/// The compact form in the floating capsule: the device, the battery and the level in one row.
struct BatteriesCapsuleStrip: View {
    @ObservedObject var service: NotchService
    let size: CGSize
    /// Another display's capsule, when the island shows on every display.
    var displayGeometry: NotchGeometry? = nil
    @ObservedObject private var batteries = BatteriesIslandService.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        NotchStripHold(batteries.indicator, shows: batteries.indicator != nil) { indicator in
            if let indicator { row(indicator) }
        }
    }

    private func row(_ indicator: BatteriesLowIndicator) -> some View {
        let geometry = displayGeometry ?? service.geometry
        let layout = NotchCapsuleLayout.self
        let side = layout.side(geometry)
        return HStack(spacing: layout.groupSpacing) {
            BatteriesStripDevice(indicator: indicator, size: layout.symbolSize)
                .frame(width: layout.symbolWidth)
            BatteriesStripReading(indicator: indicator)
        }
        .padding(.leading, side + layout.endPadding)
        .padding(.trailing, side + layout.endPadding)
        .frame(width: size.width, height: geometry.stripHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ZenithStrings.batteriesIsland(l10n.language).title)
        .accessibilityValue(BatteriesStripLayout.accessibilityValue(indicator, language: l10n.language))
        .accessibilityHint(ZenithStrings.batteriesIsland(l10n.language).open)
    }
}
