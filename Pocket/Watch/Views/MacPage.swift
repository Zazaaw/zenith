// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI

/// The Mac at a glance: its battery as a sentence, how fresh that is, and
/// three quick actions: lock it, keep it awake for an hour, mute its mic.
struct MacPage: View {
    @Environment(WatchModel.self) private var model

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            let state = model.state
            let freshness = model.freshness(now: now)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(text: state?.macName ?? model.pairing?.macName ?? "Mac")
                    SentenceText(sentence: PocketPresentation.homeSentence(state, freshness: freshness), size: 18)
                    if let battery = state?.battery, freshness.isReachable {
                        Gauge(value: Double(battery.percent), in: 0...100) { EmptyView() }
                            .gaugeStyle(.accessoryLinearCapacity)
                            .tint(K.color(PocketPresentation.batteryTone(percent: battery.percent, charging: battery.charging)))
                            .animation(Motion.fill, value: battery.percent)
                            .accessibilityHidden(true)
                    }
                    FreshnessLine(heardAt: model.snapshot?.heardAt, checking: model.checking)
                    if let problem = model.problem {
                        Text(problem).font(.system(size: 12)).foregroundStyle(K.amber)
                    }
                    actions(state, now: now)
                        .padding(.top, 6)
                        .disabled(!freshness.isReachable)
                        .opacity(freshness.isReachable ? 1 : 0.45)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .containerBackground(K.emerald.opacity(0.18).gradient, for: .tabView)
    }

    private func actions(_ state: PocketMacState?, now: Date) -> some View {
        let awake = state?.awakeUntil != nil
        let micMuted = state?.sound?.micMuted ?? false
        let locked = state?.locked ?? false
        return HStack(spacing: 4) {
            ActionButton(symbol: locked ? "lock.fill" : "lock", title: locked ? "Locked" : "Lock",
                         on: locked, busy: model.isBusy(.lock)) { model.lock() }
            ActionButton(symbol: "cup.and.saucer.fill", title: awake ? awakeTitle(state, now: now) : "Awake 1h",
                         tint: K.amber, on: awake, busy: model.isBusy(.keepAwake(minutes: nil))) {
                model.keepAwake(awake ? nil : 60)
            }
            ActionButton(symbol: micMuted ? "mic.slash.fill" : "mic.fill", title: micMuted ? "Mic off" : "Mute mic",
                         tint: K.red, on: micMuted, busy: model.isBusy(.muteMic(true))) {
                model.muteMic(!micMuted)
            }
        }
    }

    /// "47m left", or "Awake" until turned off.
    private func awakeTitle(_ state: PocketMacState?, now: Date) -> String {
        guard let minutes = PocketPresentation.awakeMinutesLeft(state?.awakeUntil, now: now) else { return "Awake" }
        return PocketPresentation.duration(minutes: minutes) + " left"
    }
}
