// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI
import WidgetKit

// MARK: Battery

/// "At **47%**," / "charging." with the 3pt bar; on the Lock Screen a gauge
/// and an inline line.
struct BatteryView: View {
    let entry: PocketEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        switch family {
        case .accessoryCircular:
            BatteryGauge(entry: entry)
                .containerBackground(.clear, for: .widget)
                .widgetURL(WidgetRoute.url("home"))
        case .accessoryInline:
            Text(PocketWidgetPresentation.inline(entry.snapshot, paired: entry.paired, now: entry.date))
                .containerBackground(.clear, for: .widget)
                .widgetURL(WidgetRoute.url("home"))
        default:
            small
        }
    }

    private var small: some View {
        let lines = PocketWidgetPresentation.battery(entry.snapshot, paired: entry.paired, now: entry.date)
        let palette = WidgetPalette(scheme)
        return SmallCard(lines: lines, palette: palette) {
            if let share = PocketWidgetPresentation.batteryShare(entry.snapshot), entry.paired {
                ThinBar(value: share, tint: palette.color(lines.sentence.tone), palette: palette)
                    .padding(.top, 10)
            }
            if let meta = lines.meta {
                MetaLine(text: meta, color: palette.faint).padding(.top, 7)
            }
        }
        .widgetCard(scheme)
        .widgetURL(WidgetRoute.url("home"))
    }
}

/// The Mac's battery as the Lock Screen's round gauge.
struct BatteryGauge: View {
    let entry: PocketEntry

    var body: some View {
        let mac = entry.snapshot?.mac
        let reachable = entry.paired && PocketPresentation.freshness(heardAt: mac?.heardAt, live: false, now: entry.date).isReachable
        let battery = mac?.state.battery
        Gauge(value: reachable ? PocketWidgetPresentation.batteryShare(entry.snapshot) ?? 0 : 0) {
            Image(systemName: battery?.charging == true ? "bolt.fill" : "laptopcomputer")
        } currentValueLabel: {
            Text(reachable ? battery.map { "\($0.percent)" } ?? "—" : "—")
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()
        .accessibilityLabel(PocketWidgetPresentation.inline(entry.snapshot, paired: entry.paired, now: entry.date))
    }
}

// MARK: Lock

/// "Unlocked," / "tap to lock.": the whole card is the button while the
/// Mac is in reach and unlocked. On the Lock Screen, a round lock button.
struct LockView: View {
    let entry: PocketEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme

    private var canLock: Bool { PocketWidgetPresentation.canLock(entry.snapshot, paired: entry.paired, now: entry.date) }

    var body: some View {
        if family == .accessoryCircular {
            tappable(circle)
                .containerBackground(.clear, for: .widget)
        } else {
            tappable(small)
                .widgetCard(scheme)
        }
    }

    @ViewBuilder
    private func tappable(_ content: some View) -> some View {
        if canLock {
            Button(intent: LockMacIntent()) { content }
                .buttonStyle(.plain)
        } else {
            content.widgetURL(WidgetRoute.url("mac"))
        }
    }

    private var small: some View {
        let lines = PocketWidgetPresentation.lock(entry.snapshot, paired: entry.paired, now: entry.date)
        let palette = WidgetPalette(scheme)
        return SmallCard(lines: lines, palette: palette) {
            if let meta = lines.meta {
                MetaLine(text: meta, color: palette.faint).padding(.top, 8)
            }
        }
        .contentShape(Rectangle())
    }

    private var circle: some View {
        let locked = entry.snapshot?.mac?.state.locked ?? false
        return ZStack {
            AccessoryWidgetBackground()
            Image(systemName: locked ? "lock.fill" : "lock.open.fill")
                .font(.system(size: 22, weight: .semibold))
                .widgetAccentable()
        }
        .accessibilityLabel(locked ? "Your Mac is locked" : canLock ? "Lock your Mac" : "Your Mac is out of reach")
    }
}

// MARK: Claude

/// "Your turn," / "18 min left." with an amber hairline while Claude waits
/// on the person; a tap opens the Claude tab. On the Lock Screen, the same
/// sentence while a session is busy, else the Mac's battery.
struct ClaudeView: View {
    let entry: PocketEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if family == .accessoryRectangular {
            rectangle
                .containerBackground(.clear, for: .widget)
                .widgetURL(WidgetRoute.url("claude"))
        } else {
            small
        }
    }

    private var small: some View {
        let lines = PocketWidgetPresentation.claude(entry.snapshot, paired: entry.paired, now: entry.date)
        let palette = WidgetPalette(scheme)
        return SmallCard(lines: lines, palette: palette) {
            if let meta = lines.meta {
                MetaLine(text: meta, color: lines.metaTone == .attention ? K.amber : palette.faint)
                    .padding(.top, 8)
            }
        }
        .widgetCard(scheme, attention: lines.needsYou)
        .widgetURL(WidgetRoute.url("claude"))
    }

    private var rectangle: some View {
        let claude = PocketWidgetPresentation.rectangleShowsClaude(entry.snapshot, now: entry.date)
        let lines = claude
            ? PocketWidgetPresentation.claude(entry.snapshot, paired: entry.paired, now: entry.date)
            : PocketWidgetPresentation.battery(entry.snapshot, paired: entry.paired, now: entry.date)
        let sentence = lines.sentence
        return VStack(alignment: .leading, spacing: 0) {
            Text(lines.eyebrow.uppercased())
                .font(K.sans(10, bold: true))
                .tracking(0.8)
                .foregroundStyle(.secondary)
            Text("\(sentence.lead)\(sentence.value)\(sentence.after)")
                .font(K.sans(16, bold: true))
                .widgetAccentable()
            if !sentence.rest.isEmpty {
                Text(sentence.rest).font(K.sans(14))
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: Batteries

/// Up to four rings, Apple's Batteries widget's way: the Mac, this iPhone,
/// the Watch, then the Mac's accessories. Green, red when low, grey when
/// the reading is old; a bolt while charging.
struct BatteriesView: View {
    let entry: PocketEntry
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = WidgetPalette(scheme)
        let snapshot = entry.paired ? entry.snapshot : nil
        let items = Array(PocketPresentation.batteryItems(snapshot?.mac?.state, phone: snapshot?.phone,
                                                          watch: snapshot?.watch, now: entry.date).prefix(4))
        let macAway = !PocketPresentation.freshness(heardAt: snapshot?.mac?.heardAt, live: false, now: entry.date).isReachable
        Group {
            if items.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Eyebrow(text: "Batteries", palette: palette)
                    Spacer(minLength: 0)
                    SentenceText(sentence: entry.paired
                                     ? PocketPresentation.devicesSentence([])
                                     : PocketWidgetPresentation.battery(nil, paired: false, now: entry.date).sentence,
                                 palette: palette, size: 19)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                HStack(spacing: 0) {
                    ForEach(items) { item in
                        RingCell(item: item, stale: item.seenAt != nil || (macAway && item.role != .thisPhone && item.role != .thisWatch),
                                 palette: palette)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .widgetCard(scheme)
        .widgetURL(WidgetRoute.url("devices"))
    }
}

private struct RingCell: View {
    let item: PocketBatteryItem
    let stale: Bool
    let palette: WidgetPalette

    var body: some View {
        let percent = item.percent
        let charging = item.charging && !stale
        let tint: Color = stale || percent == nil ? palette.faint
            : PocketPresentation.isLow(item) && !charging ? RingTone.red : RingTone.green
        VStack(spacing: 10) {
            ZStack {
                BatteryRing(value: Double(percent ?? 0) / 100, tint: tint, track: palette.track)
                Image(systemName: PocketPresentation.symbolName(item))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(stale ? palette.muted : palette.fg)
            }
            .frame(width: 56, height: 56)
            HStack(spacing: 2) {
                if charging {
                    Image(systemName: "bolt.fill").font(.system(size: 10, weight: .bold)).foregroundStyle(tint)
                }
                Text(percent.map { "\($0)%" } ?? "—")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(stale ? palette.muted : palette.fg)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.role == .thisPhone ? "This iPhone" : item.name), \(percent.map { "\($0)%" } ?? "no reading")"
                            + (charging ? ", charging" : "") + (stale ? ", last known" : ""))
    }
}
