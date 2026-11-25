// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI

/// The first round's controls on the Mac tab: lock, and keep awake.
struct MacControls: View {
    @Environment(PocketModel.self) private var model
    let now: Date

    /// What the segments mean: nil off, 0 until turned off.
    private static let segments: [(String, Int?)] = [("Off", nil), ("15m", 15), ("1h", 60), ("4h", 240), ("∞", 0)]

    var body: some View {
        let enabled = model.canControl(now: now)
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Control", trailing: awakeNote)
            HStack(spacing: 8) {
                Button {
                    Haptics.press()
                    model.lock()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill").font(.system(size: 13, weight: .bold))
                        Text("Lock").font(K.sans(14, bold: true))
                    }
                    .foregroundStyle(K.bg)
                    .padding(.horizontal, 16).frame(height: 44)
                    .background(K.fg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel("Lock Mac")
                awakePicker
            }
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.45)
            .animation(Motion.quick, value: enabled)
        }
    }

    private var awakeNote: String? {
        guard let until = model.state?.awakeUntil, until > now else { return nil }
        if PocketPresentation.isIndefinite(until, now: now) { return "awake until off" }
        return PocketPresentation.awakeMinutesLeft(until, now: now).map { "awake · " + PocketPresentation.duration(minutes: $0) }
    }

    private var selected: Int?? {
        guard let state = model.state else { return .none }
        guard let until = state.awakeUntil, until > now else { return .some(nil) }
        if PocketPresentation.isIndefinite(until, now: now) { return .some(0) }
        // The length asked for here, unless the Mac was since set for longer.
        if let choice = model.awakeChoice, PocketModel.awakeChoices.contains(choice),
           let left = PocketPresentation.awakeMinutesLeft(until, now: now), left <= choice { return .some(choice) }
        return .none
    }

    private var awakePicker: some View {
        let current = selected
        return HStack(spacing: 2) {
            ForEach(Self.segments, id: \.0) { title, minutes in
                let isOn = current == .some(minutes)
                Button {
                    Haptics.select()
                    model.keepAwake(minutes)
                } label: {
                    Text(title).font(K.sans(13, bold: true)).frame(maxWidth: .infinity).frame(height: 36)
                        .foregroundStyle(isOn ? K.bg : K.muted)
                        .background {
                            if isOn {
                                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(K.fg)
                                    .matchedGeometryEffect(id: "awake", in: segment)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel(minutes == nil ? "Keep awake off" : minutes == 0 ? "Keep awake until turned off" : "Keep awake \(title)")
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .animation(Motion.spring, value: current.map { $0 ?? -1 })
        .padding(4)
        .background(K.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(K.border, lineWidth: 1))
    }

    @Namespace private var segment
}

/// The Mac tab's card: the kit's hairline surface.
struct MacCard: ViewModifier {
    var padding: CGFloat = 14
    var tint: Color?

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(K.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(tint.map { $0.opacity(0.35) } ?? K.border, lineWidth: 1))
    }
}

extension View {
    func macCard(padding: CGFloat = 14, tint: Color? = nil) -> some View {
        modifier(MacCard(padding: padding, tint: tint))
    }
}
