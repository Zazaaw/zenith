// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI
import UIKit
import WidgetKit

/// Pocket's iPhone widgets: the Mac's battery, its lock, Claude Code, and
/// every battery Pocket knows; their Lock Screen accessories; and three
/// Control Center controls.
///
/// They show what the app last heard (a file in the App Group, see
/// `WidgetVault`), and read the Mac's box themselves over HTTPS when that is
/// older than ten minutes or missing, with the pairing the app shares in a
/// Keychain group. Buttons and controls send their command from here, sealed
/// as the iPhone, over REST broadcast (`PocketCourier`).
@main
struct PocketWidgets: WidgetBundle {
    var body: some Widget {
        BatteryWidget()
        LockWidget()
        ClaudeWidget()
        BatteriesWidget()
        LockControl()
        AwakeControl()
        MicControl()
    }
}

// MARK: Timeline

struct PocketEntry: TimelineEntry {
    let date: Date
    let snapshot: PocketWidgetSnapshot?
    let paired: Bool

    var relevance: TimelineEntryRelevance? {
        let score = PocketWidgetPresentation.relevance(snapshot, now: date)
        return TimelineEntryRelevance(score: score, duration: score >= 1 ? 15 * 60 : 0)
    }

    /// The widget gallery's: a MacBook charging, Claude waiting for a reply.
    static func sample(_ now: Date = Date()) -> PocketEntry {
        var state = PocketMacState(macName: "MacBook Pro", battery: .init(percent: 47, charging: true))
        var session = PocketClaude.Session(id: "s", project: "zenith", state: .waiting,
                                           waitingSince: now.addingTimeInterval(-60), acceptsReply: true)
        session.replyDeadline = now.addingTimeInterval(18 * 60)
        state.claude = PocketClaude(sessions: [session], away: true)
        state.accessories = [.init(id: "a", name: "AirPods Pro", kind: "headphones", percent: 18, charging: false)]
        let snapshot = PocketWidgetSnapshot(
            mac: PocketWatchSnapshot(state: state, sentAt: now, heardAt: now),
            phone: .init(kind: .iphone, name: "iPhone", percent: 94, charging: false, readAt: now),
            watch: .init(kind: .watch, name: "Apple Watch", percent: 61, charging: false, readAt: now))
        return PocketEntry(date: now, snapshot: snapshot, paired: true)
    }
}

struct PocketProvider: TimelineProvider {
    func placeholder(in context: Context) -> PocketEntry { .sample() }

    func getSnapshot(in context: Context, completion: @escaping (PocketEntry) -> Void) {
        if context.isPreview { completion(.sample()); return }
        completion(PocketEntry(date: Date(), snapshot: WidgetVault.load(), paired: PairingStore.load() != nil))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PocketEntry>) -> Void) {
        let done = Done(completion)
        Task {
            let now = Date()
            let (snapshot, paired) = await Self.read(now: now)
            let entries = PocketWidgetPresentation.entryDates(snapshot, now: now).map {
                PocketEntry(date: $0, snapshot: snapshot, paired: paired)
            }
            done.call(Timeline(entries: entries, policy: .after(now.addingTimeInterval(PocketWidgetPresentation.timelineSpan))))
        }
    }

    /// The shared file, the box when that is old, and this iPhone's battery
    /// as it is now.
    static func read(now: Date = Date()) async -> (PocketWidgetSnapshot?, paired: Bool) {
        guard let pairing = PairingStore.load() else { return (nil, false) }
        var snapshot = await WidgetVault.current(pairing, now: now)
        if let phone = await PhoneReading.now(name: snapshot.phone?.name) { snapshot.phone = phone }
        return (snapshot, true)
    }
}

/// WidgetKit's completion, called once from the task that built the timeline.
private struct Done: @unchecked Sendable {
    let call: (Timeline<PocketEntry>) -> Void
    init(_ call: @escaping (Timeline<PocketEntry>) -> Void) { self.call = call }
}

/// This iPhone's battery, read in the extension; nil when iOS gives none
/// (the app's last reading stays then).
@MainActor
enum PhoneReading {
    static func now(name: String?) -> PocketDeviceReport.Device? {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        let level = device.batteryLevel
        guard level >= 0 else { return nil }
        let charging = device.batteryState == .charging || device.batteryState == .full
        return PocketDeviceReport.Device(kind: .iphone, name: name ?? "iPhone", percent: Int((level * 100).rounded()),
                                         charging: charging, readAt: Date())
    }
}

/// Where a tap opens the app: `zenith-pocket://<tab>`.
enum WidgetRoute {
    static func url(_ tab: String) -> URL { URL(string: PocketPairing.urlScheme + "://" + tab)! }
}

// MARK: Widgets

struct BatteryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PocketBattery", provider: PocketProvider()) { entry in
            BatteryView(entry: entry)
        }
        .configurationDisplayName("Mac Battery")
        .description("Your Mac's battery, as a sentence.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryInline])
    }
}

struct LockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PocketLock", provider: PocketProvider()) { entry in
            LockView(entry: entry)
        }
        .configurationDisplayName("Lock Mac")
        .description("Whether your Mac is locked, and a button to lock it.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

struct ClaudeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PocketClaude", provider: PocketProvider()) { entry in
            ClaudeView(entry: entry)
        }
        .configurationDisplayName("Claude")
        .description("What Claude Code does on your Mac, and when it's your turn.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}

struct BatteriesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PocketBatteries", provider: PocketProvider()) { entry in
            BatteriesView(entry: entry)
        }
        .configurationDisplayName("Batteries")
        .description("Your Mac, this iPhone, your Apple Watch and what Zenith reads.")
        .supportedFamilies([.systemMedium])
    }
}
