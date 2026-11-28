// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

// Zenith fork: the hero animations of the Privacy pages, under the rules of
// docs/SETTINGS-KIT.md: a few shapes from `t`, a 4 second loop, and a still
// frame (t = 1.1) that reads on its own.

// MARK: - App Lock

/// App Lock: the icon's own glyph, drawn here so its padlock can move. An
/// app tile sits on the base; the padlock in front opens, then snaps shut
/// with a ring going out, and a frosted veil covers the tile for as long as
/// it is locked. The still frame is locked.
struct ZenithAppLockHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let p = ZenithKitEase.phase(context.t, period: 4)
        let open = Self.shackle(p)
        let veil = 1 - open
        // The ring leaves as the shackle lands.
        let ring = min(1, p / 0.35)
        ZStack {
            Circle()
                .stroke(context.tint.light.color.opacity(0.7 * (1 - ring)), lineWidth: 2)
                .frame(width: 96 + 70 * ring, height: 96 + 70 * ring)
            context.base
                .shadow(color: .black.opacity(0.4), radius: 14, y: 8)
            ZenithHeroAppTile(veil: veil)
                .frame(width: 52, height: 52)
                .offset(x: -8, y: -8)
            ZenithHeroPadlock(open: open, tint: context.tint)
                .offset(x: 14, y: 18)
        }
    }
}

/// An app's tile with four little icons, frosted over by `veil`.
struct ZenithHeroAppTile: View {
    let veil: Double

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 13, style: .continuous)
        ZStack {
            shape.fill(LinearGradient(colors: [Color(red: 0.45, green: 0.78, blue: 1), Color(red: 0.42, green: 0.32, blue: 0.95)],
                                      startPoint: .topLeading, endPoint: .bottomTrailing))
            VStack(spacing: 6) {
                ForEach(0..<2) { row in
                    HStack(spacing: 6) {
                        ForEach(0..<2) { column in
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(.white.opacity(row == 0 && column == 0 ? 0.85 : 0.55))
                                .frame(width: 15, height: 15)
                        }
                    }
                }
            }
            shape.fill(.white.opacity(0.35 * veil))
            shape.strokeBorder(.white.opacity(0.35), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
        .accessibilityHidden(true)
    }
}

extension ZenithAppLockHeroArt {
    /// How far the shackle is open over the loop: shut from 0.1 to 0.7,
    /// opening to 0.85, open, then snapping shut with a bounce by 0.1.
    static func shackle(_ p: Double) -> Double {
        if p < 0.1 { return 1 - ZenithKitEase.bounceIn(p / 0.1) }
        if p < 0.7 { return 0 }
        if p < 0.85 { return ZenithKitEase.smooth((p - 0.7) / 0.15) }
        return 1
    }
}

extension ZenithHeroAnimation where Self == ZenithAppLockHeroArt {
    static var appLock: Self { .init() }
}

/// A padlock drawn from shapes: the body in the category's tint and a
/// shackle that rises by `open` (0 shut, 1 open).
struct ZenithHeroPadlock: View {
    let open: Double
    let tint: ZenithCategoryTint

    var body: some View {
        ZStack {
            ZenithHeroShackle()
                .stroke(LinearGradient(colors: [Color(white: 0.96), Color(white: 0.68)], startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: 22, height: 22)
                .offset(x: 5 * open, y: -14 - 9 * open)
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(LinearGradient(colors: [tint.light.color, tint.deep.color], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(.white.opacity(0.45), lineWidth: 1))
                .frame(width: 34, height: 26)
            Capsule()
                .fill(.black.opacity(0.45))
                .frame(width: 4, height: 9)
                .offset(y: 1)
        }
        .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
        .accessibilityHidden(true)
    }
}

/// The shackle's upturned U, its legs reaching into the body.
struct ZenithHeroShackle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = rect.width / 2
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addArc(center: CGPoint(x: rect.midX, y: rect.minY + radius), radius: radius,
                    startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}
