// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Batteries is adapted from the Batteries droplet by Akhil Chandran (MIT) —
// see the notice in About.

import AppKit
import SwiftUI

// Zenith fork: the Batteries page in the open island, in the droplet's own
// look. Rings (the default) is the droplet's shelf widget: one row of 62
// point rings, centred, at most five side by side and the rest scrolling
// with a fade on the side that has more. List is two columns of rows, a
// small ring around each device's symbol. Levels and rows move on the
// island's spring; the page's states swap through its morph. Reduce Motion
// fades.

struct BatteriesPage: View {
    let size: CGSize
    /// Zenith fork: readings to draw instead of the store's, for the
    /// Settings preview (always with `notchSettingsPreview`).
    var sample: [BatteryDevice]? = nil
    @ObservedObject private var store = BatteriesStore.shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(BatteriesDefaults.layout) private var layoutRaw = BatteriesLayout.rings.rawValue
    @AppStorage(BatteriesDefaults.threshold) private var thresholdRaw = BatteriesDefaults.defaultThreshold
    @Environment(\.notchSettingsPreview) private var preview

    private var text: ZenithBatteriesIslandStrings { ZenithStrings.batteriesIsland(l10n.language) }

    private enum Stage: Hashable { case reading, empty, rings, list }

    private var devices: [BatteryDevice] {
        if let sample { return sample }
        return BatteriesIslandSupport.shown(store.devices, hidden: BatteriesIslandSupport.hiddenDeviceIDs())
    }

    private var stage: Stage {
        let devices = self.devices
        if devices.isEmpty { return store.lastUpdated == nil && store.isRefreshing ? .reading : .empty }
        return BatteriesLayout(rawValue: layoutRaw) == .list ? .list : .rings
    }

    var body: some View {
        content
            .frame(width: size.width, height: size.height, alignment: .center)
            .zenithMorph(on: stage)
            .onAppear {
                guard !preview else { return }
                BatteriesIslandService.shared.shown(page: true)
                store.refreshNow()
            }
            .onDisappear {
                guard !preview else { return }
                BatteriesIslandService.shared.hidden()
            }
    }

    @ViewBuilder private var content: some View {
        let threshold = BatteriesDefaults.thresholdOptions.contains(thresholdRaw) ? thresholdRaw
            : BatteriesDefaults.defaultThreshold
        switch stage {
        case .reading:
            ProgressView().controlSize(.small).frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            BatteriesEmpty(text: text)
        case .rings:
            BatteriesRingsRow(devices: devices, threshold: threshold, width: size.width)
        case .list:
            BatteriesList(devices: devices, threshold: threshold, text: text)
        }
    }
}

/// Refresh, in the page's top row; it spins while a scan runs.
struct BatteriesPageActions: View {
    @ObservedObject private var store = BatteriesStore.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let text = ZenithStrings.batteriesIsland(l10n.language)
        if store.isRefreshing {
            ProgressView().controlSize(.mini).frame(width: 28, height: 28).help(text.refresh)
        } else {
            NotchIconButton(symbol: "arrow.clockwise", title: text.refresh) { store.refreshNow() }
        }
    }
}

// MARK: Colours and motion

enum BatteriesPalette {
    static let green = ZenithIslandPalette.color(hex: BatteriesPaletteHex.green)
    static let red = ZenithIslandPalette.color(hex: BatteriesPaletteHex.red)
    static let yellow = ZenithIslandPalette.color(hex: BatteriesPaletteHex.yellow)
    /// The ring's track: the droplet's tertiary text at a fifth.
    static let track = ZenithIsland.secondary.opacity(0.2)

    /// The droplet's tint rule: green while charging or above the alert
    /// level, red at or below it.
    static func tint(_ device: BatteryDevice, threshold: Int) -> Color {
        device.isLow(threshold: threshold) ? red : green
    }
}

enum BatteriesMotion {
    /// A level changing, rings and rows arriving or leaving.
    static func change(reduceMotion: Bool) -> Animation {
        reduceMotion ? IslandMotion.easeInOut(ZenithMotion.fast) : ZenithMorph.animation
    }

    /// A ring or a row rises out of a blur as it arrives and blurs out a
    /// little smaller as it leaves; under Reduce Motion it only fades.
    static func item(reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .modifier(active: BatteriesItemEffect(amount: 1, rise: 8), identity: BatteriesItemEffect(amount: 0, rise: 8)),
            removal: .modifier(active: BatteriesItemEffect(amount: 1, rise: 0), identity: BatteriesItemEffect(amount: 0, rise: 0)))
    }
}

private struct BatteriesItemEffect: ViewModifier {
    let amount: CGFloat
    let rise: CGFloat

    func body(content: Content) -> some View {
        content
            .blur(radius: 8 * amount)
            .opacity(Double(1 - amount))
            .scaleEffect(1 - 0.06 * amount)
            .offset(y: rise * amount)
    }
}

// MARK: Pieces

/// The level as an arc around the device's symbol, from the top, with round
/// caps over a faint track; nothing but the track while the level is unknown.
struct BatteriesRingGauge: View {
    let device: BatteryDevice
    let threshold: Int
    let diameter: CGFloat
    let lineWidth: CGFloat
    let symbolSize: CGFloat
    var symbolWeight: Font.Weight = .regular
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let inset = lineWidth / 2
        let level = CGFloat(BatteriesIslandSupport.clamped(device.percent ?? 0)) / 100
        ZStack {
            Circle()
                .inset(by: inset)
                .stroke(BatteriesPalette.track, lineWidth: lineWidth)
            if device.percent != nil {
                Circle()
                    .inset(by: inset)
                    .trim(from: 0, to: level)
                    .stroke(BatteriesPalette.tint(device, threshold: threshold),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(BatteriesMotion.change(reduceMotion: reduceMotion), value: level)
            }
            // Monochrome, so an outline symbol stays an outline.
            Image(systemName: device.symbolName)
                .font(.system(size: symbolSize, weight: symbolWeight))
                .foregroundStyle(ZenithIsland.primary)
        }
        .frame(width: diameter, height: diameter)
    }
}

/// The yellow bolt on its dark disc, at a ring's bottom-trailing corner.
struct BatteriesChargingBadge: View {
    let size: CGFloat
    let bolt: CGFloat

    var body: some View {
        Image(systemName: "bolt.fill")
            .font(.system(size: bolt, weight: .bold))
            .foregroundStyle(BatteriesPalette.yellow)
            .frame(width: size, height: size)
            .background(Circle().fill(Color.black.opacity(0.8)))
    }
}

/// One device as the droplet's ring: the level's arc around the device's
/// symbol, the level and the name below.
struct BatteriesRing: View {
    let device: BatteryDevice
    let displayName: String
    let threshold: Int
    var metrics = BatteriesRingMetrics.solo
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let text = ZenithStrings.batteriesIsland(l10n.language)
        VStack(spacing: 0) {
            BatteriesRingGauge(device: device, threshold: threshold, diameter: metrics.diameter,
                               lineWidth: metrics.lineWidth, symbolSize: metrics.symbolSize)
                .overlay(alignment: .bottomTrailing) {
                    if device.isCharging {
                        BatteriesChargingBadge(size: metrics.badgeSize, bolt: metrics.boltSize)
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                    }
                }
            Text(verbatim: BatteriesIslandSupport.percentText(device.percent, text: text))
                .font(.system(size: metrics.labelSize, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(ZenithIsland.primary)
                .lineLimit(1)
                .contentTransition(.numericText())
                .padding(.top, metrics.gap)
            Text(verbatim: displayName)
                .font(.system(size: metrics.nameSize))
                .foregroundStyle(ZenithIsland.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: metrics.cellWidth)
                .padding(.top, metrics.nameGap)
        }
        // Every column one width, whatever its name, so the gaps are even.
        .frame(width: metrics.cellWidth)
        .opacity(device.isReachable ? 1 : 0.45)
        .help(device.name)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: device.name))
        .accessibilityValue(Text(verbatim: BatteriesIslandSupport.accessibilityValue(device, now: Date(), text: text)))
    }
}

// MARK: Rings

/// One row, centred. Up to five rings it keeps its own width; past five it
/// scrolls in the width of five and a peek of the sixth, fading at the side
/// that has more.
private struct BatteriesRingsRow: View {
    let devices: [BatteryDevice]
    let threshold: Int
    let width: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let metrics = BatteriesRingMetrics.solo

    var body: some View {
        let names = BatteriesIslandSupport.displayNames(for: devices)
        let row = HStack(alignment: .top, spacing: metrics.spacing) {
            ForEach(devices) { device in
                BatteriesRing(device: device, displayName: names[device.id] ?? device.name, threshold: threshold,
                              metrics: metrics)
                    .transition(BatteriesMotion.item(reduceMotion: reduceMotion))
            }
        }
        .animation(BatteriesMotion.change(reduceMotion: reduceMotion), value: devices)
        Group {
            if metrics.scrolls(count: devices.count, available: width) {
                ScrollView(.horizontal, showsIndicators: false) { row }
                    .notchScrollEdgeFade(.horizontal, length: 14)
                    .defaultScrollAnchor(.leading)
                    .frame(width: metrics.visibleWidth(count: devices.count, available: width))
            } else {
                row
            }
        }
        .frame(height: metrics.columnHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: List

/// Two columns of rows, left to right then down, a hairline between the
/// columns and between the rows. More than fit scroll, fading at the edges.
private struct BatteriesList: View {
    let devices: [BatteryDevice]
    let threshold: Int
    let text: ZenithBatteriesIslandStrings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    private typealias Metrics = BatteriesListMetrics

    var body: some View {
        let rows = Metrics.rows(devices)
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, pair in
                    if index > 0 { divider.frame(height: 1) }
                    HStack(spacing: 0) {
                        cell(pair.first)
                            .padding(.trailing, Metrics.columnGap)
                        divider.frame(width: 1)
                            .padding(.top, index == 0 ? 6 : 0)
                            .padding(.bottom, index == rows.count - 1 ? 6 : 0)
                        cell(pair.count > 1 ? pair[1] : nil)
                            .padding(.leading, Metrics.columnGap)
                    }
                    .frame(height: Metrics.rowHeight)
                }
            }
            .animation(BatteriesMotion.change(reduceMotion: reduceMotion), value: devices)
        }
        .scrollBounceBehavior(.basedOnSize)
        .notchScrollEdgeFade()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: rows.count > 3 ? .top : .center)
    }

    private var divider: some View { Rectangle().fill(ZenithIsland.divider(contrast)) }

    @ViewBuilder private func cell(_ device: BatteryDevice?) -> some View {
        Group {
            if let device {
                BatteriesListRow(device: device, threshold: threshold, text: text)
                    .id(device.id)
                    .transition(BatteriesMotion.item(reduceMotion: reduceMotion))
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct BatteriesListRow: View {
    let device: BatteryDevice
    let threshold: Int
    let text: ZenithBatteriesIslandStrings

    private typealias Metrics = BatteriesListMetrics

    var body: some View {
        let low = device.isLow(threshold: threshold)
        HStack(spacing: Metrics.ringGap) {
            BatteriesRingGauge(device: device, threshold: threshold, diameter: Metrics.ringDiameter,
                               lineWidth: Metrics.ringLine, symbolSize: Metrics.symbolSize)
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: device.name)
                    .font(.system(size: Metrics.nameSize, weight: .semibold))
                    .tracking(-0.2)
                    .foregroundStyle(ZenithIsland.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    Text(verbatim: BatteriesIslandSupport.caption(device, now: context.date, text: text))
                        .font(ZenithType.mono(Metrics.captionSize, weight: .medium))
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .foregroundStyle(ZenithIsland.label)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 4) {
                if device.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: Metrics.boltSize, weight: .bold))
                        .foregroundStyle(BatteriesPalette.yellow)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
                Text(verbatim: BatteriesIslandSupport.percentText(device.percent, text: text))
                    .font(.system(size: Metrics.percentSize, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(low ? BatteriesPalette.red : ZenithIsland.primary)
                    .contentTransition(.numericText())
            }
            .lineLimit(1)
            .fixedSize()
        }
        .opacity(device.isReachable ? 1 : 0.45)
        .help(device.name)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: device.name))
        .accessibilityValue(Text(verbatim: BatteriesIslandSupport.accessibilityValue(device, now: Date(), text: text)))
    }
}

// MARK: Empty

private struct BatteriesEmpty: View {
    let text: ZenithBatteriesIslandStrings

    var body: some View {
        VStack(spacing: 10) {
            ZenithIslandGlyphTile(symbol: NotchModule.batteries.zenithIconSymbol, tint: NotchModule.batteries.zenithTint,
                                  size: 44)
            Text(text.empty)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ZenithIsland.primary)
            Text(text.emptyHint)
                .font(.system(size: 11.5))
                .foregroundStyle(ZenithIsland.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
