// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI

/// One battery up close, opened from a ring or a row on Devices: the device,
/// a large ring (liquid while it charges), the level large and its state,
/// then how it is powered, how long it has, where the reading comes from and
/// how old it is. It follows the live reading while it stays open.
struct BatteryDetailSheet: View {
    let initial: PocketBatteryItem
    @Environment(PocketModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let item = model.batteryItems.first { $0.id == initial.id } ?? initial
        let state = Self.state(item)
        let tint = K.color(state.tone)
        VStack(alignment: .leading, spacing: 0) {
            header(item)
                .blurFade()
            HStack(spacing: 22) {
                BatteryRing(item: item, size: 112, showsPercent: false)
                VStack(alignment: .leading, spacing: 8) {
                    if let percent = item.percent {
                        RollingNumber(value: percent) { "\($0)%" }
                            .font(K.sans(54, bold: true))
                            .tracking(-1.6)
                            .foregroundStyle(state.tone == .quiet ? K.muted : (state.tone == .alert ? K.red : K.fg))
                    } else {
                        Text("—").font(K.sans(54, bold: true)).foregroundStyle(K.faint)
                    }
                    Status(badge: state)
                        .animation(Motion.spring, value: state)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24).padding(.top, 22)
            .blurFade(delay: 0.06)
            facts(item, tint: tint)
                .padding(.horizontal, 20).padding(.top, 22)
                .blurFade(delay: 0.12)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background { K.bg.ignoresSafeArea() }
        .foregroundStyle(K.fg)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(K.bg)
        .sensoryFeedback(.success, trigger: item.charging) { was, now in !was && now }
    }

    private func header(_ item: PocketBatteryItem) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(K.border, lineWidth: 1)
                .background(K.wash, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(Image(systemName: PocketPresentation.symbolName(item)).font(.system(size: 16, weight: .medium)).foregroundStyle(K.muted))
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(K.sans(18, bold: true)).lineLimit(1)
                Text(Self.kindName(item).uppercased()).font(K.sans(10, bold: true)).tracking(1.1).foregroundStyle(K.faint)
            }
            Spacer(minLength: 8)
            Button("Done") { dismiss() }
                .font(K.sans(15, bold: true)).foregroundStyle(K.fg)
        }
        .padding(.horizontal, 24).padding(.top, 26)
    }

    private func facts(_ item: PocketBatteryItem, tint: Color) -> some View {
        let lines = Self.facts(item, battery: item.role == .mac ? model.state?.battery : nil)
        let updated = updatedAt(item)
        return VStack(spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                fact(line.label, divider: index < lines.count - 1 || updated != nil) {
                    Text(line.value).contentTransition(.numericText())
                }
            }
            if let updated {
                fact(item.seenAt != nil ? "Last seen" : "Updated", divider: false) {
                    // Only this line ticks every second.
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(PocketPresentation.ago(updated, now: context.date))
                            .contentTransition(.numericText())
                            .animation(Motion.spring, value: PocketPresentation.ago(updated, now: context.date))
                    }
                }
            }
        }
        .surface(radius: 18)
        .animation(Motion.spring, value: lines.map { $0.value })
    }

    private func fact<Value: View>(_ label: String, divider: Bool, @ViewBuilder value: () -> Value) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label).font(K.sans(14)).foregroundStyle(K.muted)
                Spacer(minLength: 12)
                value().font(K.mono(13, .semibold)).foregroundStyle(K.fg).lineLimit(1)
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
            if divider { Rectangle().fill(K.border).frame(height: 1).padding(.leading, 16) }
        }
        .accessibilityElement(children: .combine)
    }

    /// When the reading was taken: this iPhone's own reading, a last-known
    /// level's time, or when the Mac last spoke.
    private func updatedAt(_ item: PocketBatteryItem) -> Date? {
        switch item.role {
        case .thisPhone: return model.phone?.readAt
        case .thisWatch: return model.watch?.readAt
        case .mac: return model.heardAt
        case .accessory: return item.seenAt ?? model.heardAt
        }
    }

    // MARK: Words

    /// Charging, full, low, on power, last known or fine.
    static func state(_ item: PocketBatteryItem) -> PocketBadge {
        guard let percent = item.percent else { return PocketBadge("No reading", .quiet) }
        if item.seenAt != nil { return PocketBadge("Last known", .quiet) }
        if item.charging { return percent >= 100 ? PocketBadge("Full", .good) : PocketBadge("Charging", .good) }
        if PocketPresentation.isLow(item) { return PocketBadge("Low", .alert) }
        if item.pluggedIn { return PocketBadge("On power", .info) }
        return PocketBadge("Good", .good)
    }

    static func facts(_ item: PocketBatteryItem, battery: PocketMacState.Battery?) -> [(label: String, value: String)] {
        var lines: [(label: String, value: String)] = []
        let power: String
        if item.percent == nil || item.seenAt != nil {
            power = "Unknown"
        } else if item.charging {
            power = (item.percent ?? 0) >= 100 ? "Charged" : "Charging"
        } else if item.pluggedIn {
            power = "Plugged in, held"
        } else {
            power = "On battery"
        }
        lines.append(("Power", power))
        if let battery, let minutes = battery.minutesRemaining, minutes > 0 {
            if battery.charging, battery.percent < 100 {
                lines.append(("Full in", PocketPresentation.duration(minutes: minutes)))
            } else if !battery.charging, battery.pluggedIn != true {
                lines.append(("Time left", PocketPresentation.duration(minutes: minutes)))
            }
        }
        let source: String
        switch item.role {
        case .mac: source = "Your Mac"
        case .thisPhone: source = "This iPhone"
        case .thisWatch: source = "Your Apple Watch"
        case .accessory: source = "Zenith, on your Mac"
        }
        lines.append(("Read by", source))
        return lines
    }

    static func kindName(_ item: PocketBatteryItem) -> String {
        switch item.kind {
        case "mac": return "Mac"
        case "iphone": return "iPhone"
        case "ipad": return "iPad"
        case "watch": return "Apple Watch"
        case "headphones": return "Headphones"
        case "keyboard": return "Keyboard"
        case "mouse": return "Mouse"
        case "trackpad": return "Trackpad"
        case "speaker": return "Speaker"
        case "gamepad": return "Game controller"
        default: return "Accessory"
        }
    }
}
