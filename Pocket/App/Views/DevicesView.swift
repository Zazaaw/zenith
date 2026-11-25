// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI

/// Every battery Pocket knows: the Mac's, this iPhone's, and the
/// accessories Zenith reads on the Mac.
struct DevicesView: View {
    @Environment(PocketModel.self) private var model
    let now: Date

    var body: some View {
        let items = model.batteryItems
        let lowest = PocketPresentation.lowest(items)
        let sentence = PocketPresentation.devicesSentence(items)
        VStack(alignment: .leading, spacing: 0) {
            Hero(eyebrow: "Batteries", badge: PocketPresentation.devicesBadge(items), sentence: sentence,
                 meter: lowest.flatMap { $0.percent }.map { Double($0) / 100 },
                 meterNote: lowest.map { $0.role == .thisPhone ? "this iphone" : $0.name.lowercased() },
                 footnote: PocketPresentation.updatedLine(model.freshness(now: now), now: now),
                 onSettings: { model.showingSettings = true })
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "All devices", trailing: model.heardAt.map {
                        "synced " + $0.formatted(date: .omitted, time: .shortened)
                    })
                    Rows {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            row(item, divider: index < items.count - 1)
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 26)
            }
        }
    }

    private func row(_ item: PocketBatteryItem, divider: Bool) -> some View {
        let tone = PocketPresentation.itemTone(item)
        let tint = K.color(tone)
        return Row(symbol: PocketPresentation.symbolName(item), title: item.name,
                   meta: PocketPresentation.itemMeta(item, now: now), divider: divider) {
            HStack(spacing: 10) {
                if let percent = item.percent {
                    Meter(value: Double(percent) / 100, tint: tone == .quiet ? Color.white.opacity(0.3) : tint, height: 4)
                        .frame(width: 46)
                    Text("\(percent)%").font(K.mono(13, .semibold)).foregroundStyle(tone == .quiet ? K.faint : tint)
                        .frame(width: 40, alignment: .trailing)
                } else {
                    Text("—").font(K.mono(13, .semibold)).foregroundStyle(K.faint).frame(width: 40, alignment: .trailing)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
