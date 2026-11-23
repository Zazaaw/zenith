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
        let fit = Layout.fit(burst, geometry: geometry)
        let shoulder = NotchLayout.shoulder(height: fit.size.height)
        ZenithIslandBurstRow(burst: burst, lines: fit.lines)
            .padding(.horizontal, ZenithIslandRoom.edge(floats: geometry.floats) + shoulder)
            .padding(.top, Layout.rowTop(geometry: geometry))
            .frame(width: fit.size.width, height: fit.size.height, alignment: .top)
            .foregroundStyle(.white)
    }
}

/// The row of one burst on `lines` lines. Every piece and gap comes from
/// ZenithIslandBurstLayout, which measures the island from the same
/// constants (`ZenithIslandBurstLayout.row`); the selftest checks the two
/// against each other.
struct ZenithIslandBurstRow: View {
    let burst: ZenithIslandBurst
    var lines = 1

    var body: some View {
        switch burst.content {
        case .prayer(let prayer): ZenithPrayerBurstRow(prayer: prayer, burst: burst, lines: lines)
        case .charge(let charge): ZenithChargeBurstRow(charge: charge, lines: lines)
        case .welcome(let welcome): ZenithWelcomeBurstRow(welcome: welcome, lines: lines)
        case .agent(let agent): ZenithAgentBurstRow(agent: agent, lines: lines)
        case .remote(let remote): ZenithRemoteBurstRow(remote: remote, lines: lines)
        case .batteryLow(let low): BatteriesLowCard(low: low) // Zenith fork
        }
    }
}

/// A title over a subtitle that takes a second line when the island is at
/// its widest, as every two line burst reads.
struct ZenithBurstWords: View {
    let title: String
    let subtitle: String
    var titleFont = ZenithIslandBurstLayout.chargeTitleFont
    var subtitleFont = ZenithIslandBurstLayout.chargeSubtitleFont
    var lines = 1
    /// The title's lines, where the title is what wraps (ZenithIslandBurstLayout.Row.wrapsTitle).
    var titleLines = 1
    var alignment = HorizontalAlignment.leading

    var body: some View {
        VStack(alignment: alignment, spacing: ZenithIslandBurstLayout.lineSpacing) {
            Text(title)
                .font(Font(titleFont))
                .foregroundStyle(ZenithIsland.primary)
                .lineLimit(max(1, titleLines))
                .multilineTextAlignment(alignment == .trailing ? .trailing : .leading)
                .fixedSize(horizontal: false, vertical: true)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(Font(subtitleFont))
                    .foregroundStyle(.white.opacity(0.55))
                    .monospacedDigit()
                    .lineLimit(max(1, lines))
                    .multilineTextAlignment(alignment == .trailing ? .trailing : .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// A glyph on a rounded tile of its own colour, as the prayer's, the
/// welcome's and the lock screen's padlock read.
struct ZenithBurstTile: View {
    let symbol: String
    let tint: Color
    var side = ZenithIslandBurstLayout.markSide
    var radius = ZenithIslandBurstLayout.markRadius
    var glyph: CGFloat = 17
    var weight = Font.Weight.semibold
    var fill = 0.14

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: glyph, weight: weight))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tint)
            .frame(width: side, height: side)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(tint.opacity(fill)))
    }
}

/// The prayer's tile in sky blue, “Waktunya Ashar” over its time and method,
/// the next prayer at the end, and a line that empties while it stays.
private struct ZenithPrayerBurstRow: View {
    let prayer: ZenithPrayerBurst
    let burst: ZenithIslandBurst
    let lines: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private typealias Layout = ZenithIslandBurstLayout
    private var blue: Color { SkyPalette.blue }

    var body: some View {
        VStack(spacing: Layout.progressGap) {
            HStack(spacing: 0) {
                ZenithBurstTile(symbol: prayer.symbol, tint: blue, side: Layout.tile, radius: 13, glyph: 21,
                                weight: .medium)
                ZenithBurstWords(title: prayer.title, subtitle: prayer.subtitle, titleFont: Layout.prayerTitleFont,
                                 subtitleFont: Layout.prayerSubtitleFont, lines: lines)
                    .padding(.leading, Layout.tileGap)
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
                    .padding(.leading, Layout.columnGap)
                }
            }
            .frame(minHeight: Layout.prayerRow)
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
    let lines: Int

    private typealias Layout = ZenithIslandBurstLayout

    var body: some View {
        HStack(spacing: 0) {
            if let percent = charge.percent {
                ZenithBatteryFigure(percent: percent, color: charge.tone.color, bolt: charge.bolt)
            } else {
                ZenithBatteryGlyph(percent: 100, color: charge.tone.color, bolt: charge.bolt)
            }
            Spacer(minLength: Layout.columnGap)
            ZenithBurstWords(title: charge.title, subtitle: charge.subtitle, lines: lines, alignment: .trailing)
        }
        .frame(minHeight: Layout.chargeRow)
    }
}

/// The green open padlock on its tile, "Welcome back, Faiz" over how long
/// the Mac was locked, and the account's picture.
private struct ZenithWelcomeBurstRow: View {
    let welcome: ZenithWelcomeBurst
    let lines: Int

    private typealias Layout = ZenithIslandBurstLayout

    var body: some View {
        HStack(spacing: 0) {
            ZenithBurstTile(symbol: "lock.open.fill", tint: ZenithIslandPalette.color(hex: ZenithLockIsland.chargingHex))
            ZenithBurstWords(title: welcome.title, subtitle: welcome.subtitle, lines: lines)
                .padding(.leading, Layout.tileGap)
                .frame(maxWidth: .infinity, alignment: .leading)
            Group {
                if let photo = welcome.photo {
                    Image(nsImage: photo).resizable().aspectRatio(contentMode: .fill)
                } else {
                    Text(welcome.initials)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.white.opacity(0.16))
                }
            }
            .frame(width: Layout.photoSide, height: Layout.photoSide)
            .clipShape(Circle())
            .padding(.leading, Layout.columnGap)
        }
        .frame(minHeight: Layout.welcomeRow)
    }
}

/// The agent's mark, "Claude needs you" and the project's folder.
private struct ZenithAgentBurstRow: View {
    let agent: ZenithAgentBurst
    let lines: Int

    private typealias Layout = ZenithIslandBurstLayout

    var body: some View {
        HStack(spacing: 0) {
            NotchAgentGlyph(provider: agent.provider, size: 20, working: false)
                .frame(width: Layout.markSide, height: Layout.markSide)
            ZenithBurstWords(title: agent.title, subtitle: agent.subtitle, lines: lines)
                .padding(.leading, Layout.tileGap)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: Layout.chargeRow)
    }
}

/// Zenith fork: the iPhone, "Faiz’s iPhone checked status" on one line, and an
/// eye at the end; at the widest island, what it did goes below the name.
private struct ZenithRemoteBurstRow: View {
    let remote: ZenithRemoteBurst
    let lines: Int

    private typealias Layout = ZenithIslandBurstLayout

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: "iphone")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(ZenithIsland.primary)
                .frame(width: Layout.remoteGlyph, height: Layout.remoteRow)
            Group {
                if lines > 1 {
                    ZenithBurstWords(title: remote.device, subtitle: remote.subtitle,
                                     subtitleFont: Layout.remoteDetailFont)
                } else {
                    HStack(spacing: Layout.remoteWordGap) {
                        Text(remote.device)
                            .font(Font(Layout.chargeTitleFont))
                            .foregroundStyle(ZenithIsland.primary)
                        Text(remote.subtitle)
                            .font(Font(Layout.remoteDetailFont))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .lineLimit(1)
                }
            }
            .padding(.leading, Layout.remoteGap)
            Spacer(minLength: Layout.columnGap)
            Image(systemName: "eye")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: Layout.remoteGlyph, height: Layout.remoteRow)
        }
        .frame(minHeight: lines > 1 ? Layout.welcomeRow : Layout.remoteRow)
    }
}
