// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

// Zenith fork: Privacy Blur's hero animation, under the rules of
// docs/SETTINGS-KIT.md: a few shapes from `t`, a 4 second loop, no blur
// modifier (the frost is drawn), and a still frame (t = 1.1) with the
// bubbles frosted over.

/// Privacy Blur: chat bubbles float either side of the icon; a pane of
/// frost slides over them, holds, and lifts for a peek before it returns.
struct ZenithPrivacyBlurHeroArt: ZenithHeroAnimation {
    /// x, y, width; positive x for my bubbles on the right.
    private static let bubbles: [(CGFloat, CGFloat, CGFloat)] = [
        (-70, -38, 34), (-74, -10, 26), (-66, 18, 38), (70, -26, 30), (74, 2, 38), (68, 30, 24),
    ]

    func art(_ context: ZenithHeroArtContext) -> some View {
        let p = ZenithKitEase.phase(context.t, period: 4)
        // In over the first fifth, held, lifted in the last fifth.
        let cover = p < 0.2 ? ZenithKitEase.smooth(p / 0.2) : p < 0.75 ? 1 : 1 - ZenithKitEase.smooth((p - 0.75) / 0.2)
        let light = context.tint.light.color
        ZStack {
            ForEach(Self.bubbles.indices, id: \.self) { i in
                let (x, y, width) = Self.bubbles[i]
                let mine = x > 0
                Capsule()
                    .fill(mine ? light.opacity(0.85) : Color.primary.opacity(context.dark ? 0.55 : 0.35))
                    .frame(width: width, height: 13)
                    .offset(x: x, y: y + 2 * CGFloat(ZenithKitEase.pulse(context.t + Double(i) * 0.3, period: 4)))
            }
            ForEach([-1, 1], id: \.self) { side in
                frost(dark: context.dark, light: light)
                    .frame(width: 58, height: 104)
                    .offset(x: CGFloat(side) * 70, y: -4)
                    .opacity(cover)
                    .offset(y: CGFloat(1 - cover) * -10)
            }
            context.icon.offset(y: -2 * (ZenithKitEase.pulse(context.t, period: 4) - 0.5))
        }
    }

    /// A frosted pane: a pale fill, a sheen and a few soft blobs.
    private func frost(dark: Bool, light: Color) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return ZStack {
            shape.fill(Color.white.opacity(dark ? 0.22 : 0.6))
            shape.fill(LinearGradient(colors: [light.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
            VStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule().fill(Color.white.opacity(dark ? 0.18 : 0.5)).frame(width: [34, 26, 30][i], height: 9)
                }
            }
            shape.strokeBorder(Color.white.opacity(dark ? 0.35 : 0.8), lineWidth: 1)
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithPrivacyBlurHeroArt {
    static var privacyBlur: Self { .init() }
}
