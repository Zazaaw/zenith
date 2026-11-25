// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI

/// Dot grid and line grid with a few lit cells, each fading toward an
/// opposite corner, behind every screen. With `parallax`, the dot grid
/// drifts that many points against the phone's lean (`Tilt`; the caller
/// keeps it running with `.readsTilt()`), opposite to the state aura.
struct Ambient: View {
    var parallax: CGFloat = 0

    var body: some View {
        ZStack {
            dots
                // Drawn a little past the edges, so the drift never shows one.
                .padding(parallax == 0 ? 0 : -parallax * 2)
                .modifier(TiltShift(distance: -parallax))
            Canvas { context, size in
                let cell: CGFloat = 44
                var path = Path()
                var x: CGFloat = 0
                while x <= size.width { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height)); x += cell }
                var y: CGFloat = 0
                while y <= size.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y)); y += cell }
                context.stroke(path, with: .color(K.gridLine), lineWidth: 1)
                for (cx, cy) in [(6, 15), (7, 16), (5, 17), (8, 14)] {
                    let rect = CGRect(x: CGFloat(cx) * cell, y: CGFloat(cy) * cell, width: cell, height: cell)
                    context.fill(Path(rect), with: .color(K.wash))
                }
            }
            .mask(LinearGradient(colors: [.clear, .white], startPoint: UnitPoint(x: 0.3, y: 0.45), endPoint: .bottomTrailing))
        }
        .opacity(0.9)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var dots: some View {
        Canvas { context, size in
            let step: CGFloat = 18
            var y: CGFloat = 1
            while y < size.height {
                var x: CGFloat = 1
                while x < size.width {
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.6, height: 1.6)), with: .color(K.dot))
                    x += step
                }
                y += step
            }
        }
        .mask(LinearGradient(colors: [.white, .clear], startPoint: .topLeading, endPoint: UnitPoint(x: 0.7, y: 0.55)))
    }
}

/// A status pill: 10% fill, 20% border, full-strength text, always labelled.
struct Status: View {
    let badge: PocketBadge

    var body: some View {
        let tint = K.color(badge.tone)
        HStack(spacing: 5) {
            Circle().fill(tint).frame(width: 5, height: 5)
            Text(badge.text).font(K.sans(11, bold: true))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8).padding(.vertical, 3.5)
        .background(tint.opacity(0.10), in: Capsule())
        .overlay(Capsule().strokeBorder(tint.opacity(0.20), lineWidth: 1))
    }
}

/// An uppercase tracked section label, with an optional mono note.
struct SectionLabel: View {
    let text: String
    var trailing: String?

    var body: some View {
        HStack {
            Text(text.uppercased()).font(K.sans(11, bold: true)).tracking(1.1).foregroundStyle(K.faint)
            Spacer()
            if let trailing { Text(trailing).font(K.mono(11)).foregroundStyle(K.muted) }
        }
        .padding(.horizontal, 4)
    }
}

/// A card of rows separated by hairlines, on the theme's surface.
struct Rows<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .surface(radius: 18)
    }
}

struct Row<Trailing: View>: View {
    let symbol: String
    let title: String
    let meta: String
    var divider = true
    @ViewBuilder let trailing: Trailing

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(K.border, lineWidth: 1)
                    .background(K.wash, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(Image(systemName: symbol).font(.system(size: 13, weight: .medium)).foregroundStyle(K.muted))
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(K.sans(15, bold: true)).lineLimit(1)
                    Text(meta).font(K.mono(11)).foregroundStyle(K.faint).lineLimit(1)
                }
                Spacer(minLength: 8)
                trailing
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            if divider { Rectangle().fill(K.border).frame(height: 1).padding(.leading, 58) }
        }
    }
}

/// A thin progress capsule that fills from empty when it first appears
/// (full at once on a tab opened again) and glides to each new value.
struct Meter: View {
    let value: Double
    let tint: Color
    var height: CGFloat = 6
    @State private var shown: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.firstOpen) private var firstOpen

    var body: some View {
        GeometryReader { geometry in
            Capsule().fill(K.track).overlay(alignment: .leading) {
                Capsule().fill(tint).frame(width: geometry.size.width * min(1, max(0, shown)))
            }
        }
        .frame(height: height)
        .onAppear {
            guard firstOpen else { shown = value; return }
            withAnimation(Motion.respecting(reduceMotion, Motion.fill).delay(reduceMotion ? 0 : 0.15)) { shown = value }
        }
        .onChange(of: value) { _, next in
            withAnimation(Motion.respecting(reduceMotion, Motion.fill)) { shown = next }
        }
        .accessibilityElement()
        .accessibilityValue("\(Int((min(1, max(0, value)) * 100).rounded())) percent")
    }
}

/// The hero every tab opens with: the eyebrow and its status, then the
/// sentence, bold up to the value (in its status colour) and regular grey
/// after, at the same size; a quiet meter and a freshness line when known.
/// In a tab, its eyebrow and badge carry on in TabScroll's compact header
/// once the sentence (which fades as it leaves the top) has scrolled away.
struct Hero: View {
    let eyebrow: String
    let badge: PocketBadge?
    let sentence: PocketSentence
    var meter: Double?
    var meterNote: String?
    var footnote: String?
    var onSettings: (() -> Void)?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let tint = K.color(sentence.tone)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text(eyebrow.uppercased()).font(K.sans(11, bold: true)).tracking(1.2).foregroundStyle(K.faint).lineLimit(1)
                Spacer()
                if let badge { Status(badge: badge) }
                if let onSettings {
                    Button(action: onSettings) {
                        Image(systemName: "gearshape").font(.system(size: 15, weight: .medium)).foregroundStyle(K.muted)
                            .frame(width: 32, height: 32).contentShape(Rectangle())
                    }
                    .pressable()
                    .accessibilityLabel("Settings")
                }
            }
            .frame(minHeight: 32)
            .padding(.top, 8)
            .blurFade(index: 0)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Text(sentence.lead))\(Text(sentence.value).foregroundStyle(tint))\(Text(sentence.after))")
                    .font(K.sans(32, bold: true))
                    // Digits in the value roll when it changes (47% → 48%).
                    .contentTransition(.numericText())
                    .animation(Motion.spring, value: sentence)
                if !sentence.rest.isEmpty {
                    Text(sentence.rest).font(K.sans(32)).foregroundStyle(K.muted)
                }
            }
            .tracking(-0.9)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 12)
            .accessibilityElement(children: .combine)
            .blurFade(index: 1)
            // Leaving the top, the sentence fades, softens and settles back
            // a little, handing over to the tab's compact header.
            .scrollTransition(.interactive.threshold(.visible(0.9)), axis: .vertical) { [still = reduceMotion] content, phase in
                let out = Double(-min(0, phase.value))
                return content
                    .opacity(1 - out * 0.8)
                    .blur(radius: still ? 0 : out * 6)
                    .scaleEffect(still ? 1 : 1 - out * 0.04, anchor: .bottomLeading)
            }
            if let meter {
                HStack(spacing: 10) {
                    Meter(value: meter, tint: tint)
                    if let meterNote { Text(meterNote).font(K.mono(11)).foregroundStyle(K.faint).fixedSize() }
                }
                .padding(.top, 16)
                .blurFade(index: 2)
            }
            if let footnote {
                Text(footnote).font(K.mono(11)).foregroundStyle(K.faint).padding(.top, meter == nil ? 12 : 8)
                    .contentTransition(.opacity)
                    .blurFade(index: 3)
            }
        }
        .padding(.horizontal, 24)
        // Tells a tab's scroll view (TabScroll) what its compact header shows
        // and where the hero ends.
        .background {
            GeometryReader { geometry in
                Color.clear.preference(key: HeroSummaryKey.self, value: HeroSummary(
                    eyebrow: eyebrow, badge: badge,
                    bottom: geometry.frame(in: .named(HeroSummary.space)).maxY))
            }
        }
    }
}

/// A full-width button in the kit's two weights: solid ink (white in dark,
/// black in light), or a quiet track fill. Presses dip and tap.
struct PillButton: View {
    let title: String
    var primary = false
    var compact = false
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Text(title).font(K.sans(15, bold: true))
                .foregroundStyle(primary ? K.inverse : K.fg)
                .frame(maxWidth: .infinity).padding(.vertical, compact ? 10 : 11)
                .background(primary ? K.fg : K.track, in: Capsule())
                .contentShape(Capsule())
                .opacity(isEnabled ? 1 : 0.4)
        }
        .pressable()
    }
}
