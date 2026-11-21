// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Zenith fork: what a burst draws inside the grown island: a row below the
/// camera, clear of the shoulders by the room rule. The window host morphs
/// the island to its size and blurs it in; this only lays out the row.
struct ZenithIslandBurstView: View {
    let burst: ZenithIslandBurst
    let geometry: NotchGeometry

    private typealias Layout = ZenithIslandBurstLayout

    var body: some View {
        let size = Layout.size(burst, geometry: geometry)
        let shoulder = geometry.floats ? 0 : NotchLayout.shoulder(height: size.height)
        Group {
            switch burst.content {
            case .prayer(let prayer): ZenithPrayerBurstRow(prayer: prayer, burst: burst)
            case .charge(let charge): ZenithChargeBurstRow(charge: charge)
            }
        }
        .padding(.horizontal, ZenithIslandRoom.edge + shoulder)
        .padding(.top, Layout.rowTop(geometry: geometry))
        .frame(width: size.width, height: size.height, alignment: .top)
        .foregroundStyle(.white)
    }
}

/// The prayer's tile in sky blue, “Waktunya Ashar” over its time and method,
/// the next prayer at the end, and a line that empties while it stays.
private struct ZenithPrayerBurstRow: View {
    let prayer: ZenithPrayerBurst
    let burst: ZenithIslandBurst
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private typealias Layout = ZenithIslandBurstLayout
    private var blue: Color { SkyPalette.blue }

    var body: some View {
        VStack(spacing: Layout.progressGap) {
            HStack(spacing: Layout.tileGap) {
                Image(systemName: prayer.symbol)
                    .font(.system(size: 21, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(blue)
                    .frame(width: Layout.tile, height: Layout.tile)
                    .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(blue.opacity(0.14)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(prayer.title)
                        .font(Font(Layout.prayerTitleFont))
                        .foregroundStyle(ZenithIsland.primary)
                    Text(prayer.subtitle)
                        .font(Font(Layout.prayerSubtitleFont))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .lineLimit(1)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .leading)
                if let next = prayer.next {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(prayer.nextLabel)
                            .font(Font(Layout.nextLabelFont))
                            .foregroundStyle(.white.opacity(0.45))
                        Text(next)
                            .font(Font(Layout.nextValueFont))
                            .foregroundStyle(.white.opacity(0.85))
                            .monospacedDigit()
                    }
                    .lineLimit(1)
                    .fixedSize()
                }
            }
            .frame(height: Layout.prayerRow)
            TimelineView(.animation(minimumInterval: reduceMotion ? 0.5 : 1.0 / 30, paused: false)) { context in
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.12))
                        Capsule().fill(blue)
                            .frame(width: proxy.size.width * burst.remaining(at: context.date))
                    }
                }
            }
            .frame(height: Layout.progressHeight)
            .accessibilityHidden(true)
        }
    }
}

/// The battery filled to its charge with the bolt while a charger is in,
/// the percentage in the state's colour, and what it is doing at the end.
private struct ZenithChargeBurstRow: View {
    let charge: ZenithChargeBurst

    private typealias Layout = ZenithIslandBurstLayout

    var body: some View {
        HStack(spacing: 0) {
            if let percent = charge.percent {
                ZenithBatteryFigure(percent: percent, color: charge.tone.color, bolt: charge.bolt)
            } else {
                ZenithBatteryGlyph(percent: 100, color: charge.tone.color, bolt: charge.bolt)
            }
            Spacer(minLength: Layout.columnGap)
            VStack(alignment: .trailing, spacing: 2) {
                Text(charge.title)
                    .font(Font(Layout.chargeTitleFont))
                    .foregroundStyle(ZenithIsland.primary)
                Text(charge.subtitle)
                    .font(Font(Layout.chargeSubtitleFont))
                    .foregroundStyle(.white.opacity(0.55))
                    .monospacedDigit()
            }
            .lineLimit(1)
        }
        .frame(height: Layout.chargeRow)
    }
}
