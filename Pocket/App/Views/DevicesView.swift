// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI

/// Every battery Pocket knows: the Mac's, this iPhone's, and the
/// accessories Zenith reads on the Mac. The first four as rings, like the
/// iPhone's Batteries widget; AirPods (one entry per bud and case) together
/// on their own card; then every device as a row.
struct DevicesView: View {
    @Environment(PocketModel.self) private var model
    let now: Date

    var body: some View {
        let items = model.batteryItems
        let lowest = PocketPresentation.lowest(items)
        let sentence = PocketPresentation.devicesSentence(items)
        let buds = items.filter(Self.isBuds)
        VStack(alignment: .leading, spacing: 0) {
            Hero(eyebrow: "Batteries", badge: PocketPresentation.devicesBadge(items), sentence: sentence,
                 meter: lowest.flatMap { $0.percent }.map { Double($0) / 100 },
                 meterNote: lowest.map { $0.role == .thisPhone ? "this iphone" : $0.name.lowercased() },
                 footnote: PocketPresentation.updatedLine(model.freshness(now: now), now: now),
                 onSettings: { model.showingSettings = true })
            if items.isEmpty {
                if model.state == nil && model.loading { placeholder }
            } else {
                HStack(spacing: 0) {
                    ForEach(Array(items.prefix(4).enumerated()), id: \.element.id) { index, item in
                        BatteryRing(item: item)
                            .frame(maxWidth: .infinity)
                            .blurFade(index: index, base: 0.15)
                    }
                }
                .padding(.vertical, 18).padding(.horizontal, 8)
                .surface()
                .padding(.horizontal, 20).padding(.top, 24)
                if buds.count > 1 {
                    BudsCard(items: buds)
                        .padding(.horizontal, 20).padding(.top, 12)
                        .blurFade(index: 5)
                }
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "All devices", trailing: model.heardAt.map {
                        "synced " + $0.formatted(date: .omitted, time: .shortened)
                    })
                    Rows {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            row(item, divider: index < items.count - 1)
                                .blurFade(index: index, base: 0.25)
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 22)
                .animation(Motion.spring, value: items)
            }
        }
    }

    private var placeholder: some View {
        VStack(spacing: 10) {
            Skeleton(height: 120, radius: 20)
            Skeleton(height: 220, radius: 18)
        }
        .padding(.horizontal, 20).padding(.top, 24)
    }

    static func isBuds(_ item: PocketBatteryItem) -> Bool {
        let name = item.name.lowercased()
        return item.kind == "headphones" && (name.contains("airpods") || name.contains("buds"))
    }

    private func row(_ item: PocketBatteryItem, divider: Bool) -> some View {
        let tone = PocketPresentation.itemTone(item)
        let tint = K.color(tone)
        return Row(symbol: PocketPresentation.symbolName(item), title: item.name,
                   meta: PocketPresentation.itemMeta(item, now: now), divider: divider) {
            HStack(spacing: 10) {
                if let percent = item.percent {
                    Meter(value: Double(percent) / 100, tint: tone == .quiet ? K.faint : tint, height: 4)
                        .frame(width: 46)
                    RollingNumber(value: percent) { "\($0)%" }
                        .font(K.mono(13, .semibold)).foregroundStyle(tone == .quiet ? K.faint : tint)
                        .frame(width: 40, alignment: .trailing)
                } else {
                    Text("—").font(K.mono(13, .semibold)).foregroundStyle(K.faint).frame(width: 40, alignment: .trailing)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// One battery as a ring round its device's symbol, the percentage rolling
/// up underneath; a bolt while it charges.
struct BatteryRing: View {
    let item: PocketBatteryItem
    var size: CGFloat = 58
    @State private var shown: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let tone = PocketPresentation.itemTone(item)
        let tint = tone == .quiet ? K.faint : (tone == .plain ? K.emerald : K.color(tone))
        let value = Double(item.percent ?? 0) / 100
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(K.track, lineWidth: 4.5)
                Circle().trim(from: 0, to: shown)
                    .stroke(tint, style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: PocketPresentation.symbolName(item))
                    .font(.system(size: size * 0.3, weight: .medium))
                    .foregroundStyle(K.fg)
                if item.charging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(K.emerald)
                        .padding(3)
                        .background(K.card, in: Circle())
                        .offset(y: -size / 2)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: size, height: size)
            if let percent = item.percent {
                RollingNumber(value: percent) { "\($0)%" }
                    .font(K.mono(13, .semibold)).foregroundStyle(tone == .quiet ? K.faint : K.fg)
            } else {
                Text("—").font(K.mono(13, .semibold)).foregroundStyle(K.faint)
            }
        }
        .onAppear {
            withAnimation(Motion.respecting(reduceMotion, Motion.fill).delay(0.2)) { shown = value }
        }
        .onChange(of: value) { _, next in withAnimation(Motion.fill) { shown = next } }
        .animation(Motion.spring, value: item.charging)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.name), \(item.percent.map { "\($0) percent" } ?? "unknown")\(item.charging ? ", charging" : "")")
    }
}

/// AirPods the way the iPhone shows them when the case opens: the buds and
/// the case side by side, each a ring with its own level.
private struct BudsCard: View {
    let items: [PocketBatteryItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "airpods.pro").font(.system(size: 20, weight: .medium)).foregroundStyle(K.fg)
                    .symbolEffect(.bounce, options: .nonRepeating, value: items.count)
                Text(Self.product(items)).font(K.sans(16, bold: true)).lineLimit(1)
                Spacer(minLength: 0)
                if items.contains(where: \.charging) { Status(badge: PocketBadge("Charging", .good)) }
            }
            HStack(spacing: 0) {
                ForEach(items) { item in
                    VStack(spacing: 6) {
                        BatteryRing(item: item, size: 50)
                        Text(Self.part(item)).font(K.sans(10, bold: true)).tracking(1).foregroundStyle(K.faint)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .surface()
    }

    /// "AirPods Pro" from "AirPods Pro (Left)", "Faiz's AirPods Pro – Case" …
    static func product(_ items: [PocketBatteryItem]) -> String {
        let name = items.first?.name ?? "AirPods"
        let cut = name.firstIndex(where: { "(-–".contains($0) }).map { String(name[..<$0]) } ?? name
        return cut.trimmingCharacters(in: .whitespaces)
    }

    /// "LEFT", "RIGHT", "CASE", or the name when it says none of them.
    static func part(_ item: PocketBatteryItem) -> String {
        let name = item.name.lowercased()
        if name.contains("left") { return "LEFT" }
        if name.contains("right") { return "RIGHT" }
        if name.contains("case") { return "CASE" }
        return item.name.uppercased()
    }
}
