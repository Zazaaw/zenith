// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI
import WidgetKit

/// Pocket's complications and Smart Stack card: the Mac's battery as a
/// gauge, and what Claude does. They show what the Watch app last saw (a
/// file in the App Group), and read the Mac's box themselves when that is
/// older than a few minutes or missing. Their relevance rises while Claude
/// waits for the person, so the Smart Stack brings Pocket up then.
@main
struct PocketWidgets: WidgetBundle {
    var body: some Widget {
        PocketMacWidget()
    }
}

struct PocketMacWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PocketMac", provider: PocketProvider()) { entry in
            PocketWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Pocket")
        .description("Your Mac's battery and Claude Code.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline, .accessoryRectangular])
    }
}

struct PocketEntry: TimelineEntry {
    let date: Date
    let snapshot: PocketWatchSnapshot?
    let paired: Bool
    var relevance: TimelineEntryRelevance? {
        let score = PocketWatchPresentation.relevance(snapshot, now: date)
        return TimelineEntryRelevance(score: score, duration: score >= 1 ? 15 * 60 : 0)
    }
}

struct PocketProvider: TimelineProvider {
    /// A saved state older than this is read again from the relay.
    static let refetchAfter: TimeInterval = 5 * 60

    func placeholder(in context: Context) -> PocketEntry {
        var state = PocketMacState(macName: "Mac", battery: .init(percent: 76, charging: false))
        state.claude = PocketClaude(sessions: [PocketClaude.Session(id: "s", project: "zenith", state: .working)])
        return PocketEntry(date: Date(), snapshot: PocketWatchSnapshot(state: state, sentAt: Date(), heardAt: Date()), paired: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (PocketEntry) -> Void) {
        if context.isPreview { completion(placeholder(in: context)); return }
        completion(PocketEntry(date: Date(), snapshot: WatchVault.loadSnapshot(), paired: WatchVault.loadPairing() != nil))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PocketEntry>) -> Void) {
        let done = Done(completion)
        Task {
            let entry = await Self.entry()
            // Freshness words change with time: a few entries, then ask again.
            let entries = [0, 5, 10].map { minutes in
                PocketEntry(date: entry.date.addingTimeInterval(TimeInterval(minutes * 60)), snapshot: entry.snapshot, paired: entry.paired)
            }
            done.call(Timeline(entries: entries, policy: .after(entry.date.addingTimeInterval(15 * 60))))
        }
    }

    static func entry(now: Date = Date()) async -> PocketEntry {
        let pairing = WatchVault.loadPairing()
        var snapshot = pairing == nil ? nil : WatchVault.loadSnapshot()
        if let pairing, now.timeIntervalSince(snapshot?.heardAt ?? .distantPast) > refetchAfter,
           let fetched = try? await WatchVault.fetch(pairing) {
            snapshot = PocketWatchSnapshot.newest(snapshot, fetched)
            if snapshot == fetched { WatchVault.saveSnapshot(fetched) }
        }
        return PocketEntry(date: now, snapshot: snapshot, paired: pairing != nil)
    }
}

/// WidgetKit's completion, called once from the task that built the timeline.
private struct Done: @unchecked Sendable {
    let call: (Timeline<PocketEntry>) -> Void
    init(_ call: @escaping (Timeline<PocketEntry>) -> Void) { self.call = call }
}

// MARK: Views

struct PocketWidgetView: View {
    let entry: PocketEntry
    @Environment(\.widgetFamily) private var family

    private var state: PocketMacState? { entry.snapshot?.state }
    private var reachable: Bool {
        PocketPresentation.freshness(heardAt: entry.snapshot?.heardAt, live: false, now: entry.date).isReachable
    }
    private var share: Double { reachable ? PocketWatchPresentation.batteryShare(state) ?? 0 : 0 }
    private var tint: Color {
        guard reachable, let battery = state?.battery else { return .gray }
        return WidgetTone.color(PocketPresentation.batteryTone(percent: battery.percent, charging: battery.charging))
    }

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryCorner: corner
        case .accessoryInline: Text(PocketWatchPresentation.inline(entry.paired ? entry.snapshot : nil, now: entry.date))
        default: rectangular
        }
    }

    private var symbol: String {
        state?.battery?.charging == true ? "bolt.fill" : "laptopcomputer"
    }

    private var circular: some View {
        Gauge(value: share) {
            Image(systemName: symbol)
        } currentValueLabel: {
            Text(reachable ? state?.battery.map { "\($0.percent)" } ?? "—" : "—")
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(tint)
        .widgetAccentable()
        .accessibilityLabel(PocketWatchPresentation.inline(entry.snapshot, now: entry.date))
    }

    private var corner: some View {
        Image(systemName: symbol)
            .font(.system(size: 20, weight: .medium))
            .widgetLabel {
                Gauge(value: share) {
                    Text("Mac")
                } currentValueLabel: {
                    Text(state?.battery.map { "\($0.percent)%" } ?? "")
                }
                .tint(tint)
            }
            .widgetAccentable()
    }

    private var rectangular: some View {
        let session = PocketPresentation.claudeFocus(state?.claude, chosen: nil)
        let claudeTone = session.map { PocketPresentation.claudeTone($0.state) } ?? .quiet
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 12, weight: .semibold))
                Text(reachable ? state?.battery.map { "\($0.percent)%" } ?? "Online" : "Away")
                    .font(.system(size: 15, weight: .bold))
                Spacer(minLength: 0)
                Gauge(value: share) { EmptyView() }
                    .gaugeStyle(.accessoryLinearCapacity)
                    .tint(tint)
                    .frame(width: 44)
            }
            .widgetAccentable()
            if entry.paired, let session {
                Text("Claude · " + PocketPresentation.claudeBadge(session).text)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(WidgetTone.color(claudeTone))
                Text(session.project).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
            } else {
                Text(entry.paired ? "Claude is quiet" : "Open Pocket on your iPhone")
                    .font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The status palette (the Style Kit's Tailwind 500s).
enum WidgetTone {
    static func color(_ tone: PocketTone) -> Color {
        switch tone {
        case .good: return Color(red: 0.063, green: 0.725, blue: 0.506)
        case .attention: return Color(red: 0.961, green: 0.620, blue: 0.043)
        case .alert: return Color(red: 0.937, green: 0.267, blue: 0.267)
        case .progress: return Color(red: 0.659, green: 0.333, blue: 0.969)
        case .info: return Color(red: 0.231, green: 0.510, blue: 0.965)
        case .plain: return .primary
        case .quiet: return .secondary
        }
    }
}
