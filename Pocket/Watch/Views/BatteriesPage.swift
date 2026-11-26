// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI

/// Every battery Pocket knows, as on the iPhone's Devices tab: the Mac,
/// the iPhone, this Watch and the accessories Zenith reads, each a row with
/// a small ring.
struct BatteriesPage: View {
    @Environment(WatchModel.self) private var model

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let items = model.batteryItems
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(text: "Batteries")
                    SentenceText(sentence: PocketPresentation.devicesSentence(items), size: 16)
                    ForEach(items) { item in
                        row(item, now: context.date)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(Motion.spring, value: items)
            }
        }
        .containerBackground(K.emerald.opacity(0.14).gradient, for: .tabView)
    }

    private func row(_ item: PocketBatteryItem, now: Date) -> some View {
        let tone = PocketPresentation.itemTone(item)
        let tint = tone == .quiet ? K.faint : (tone == .plain ? K.emerald : K.color(tone))
        return HStack(spacing: 10) {
            LevelRing(value: Double(item.percent ?? 0) / 100, tint: tint, symbol: PocketPresentation.symbolName(item),
                      charging: item.charging)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(K.fg).lineLimit(1)
                Text(meta(item, now: now)).font(.system(size: 11)).foregroundStyle(K.faint).lineLimit(1)
            }
            Spacer(minLength: 2)
            Text(item.percent.map { "\($0)%" } ?? "—")
                .font(.system(size: 14, weight: .bold).monospacedDigit())
                .foregroundStyle(tone == .quiet ? K.faint : (PocketPresentation.isLow(item) ? K.red : K.fg))
                .contentTransition(.numericText(value: Double(item.percent ?? 0)))
        }
        .padding(.vertical, 6).padding(.horizontal, 8)
        .background(K.card.opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    /// The iPhone's words, from where the Watch stands.
    private func meta(_ item: PocketBatteryItem, now: Date) -> String {
        switch item.role {
        case .thisPhone: return item.charging ? "charging · iphone" : "iphone"
        case .thisWatch: return item.charging ? "charging · this watch" : "this watch"
        default: return PocketPresentation.itemMeta(item, now: now)
        }
    }
}
