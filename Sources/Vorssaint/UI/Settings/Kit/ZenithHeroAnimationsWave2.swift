// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

// Zenith fork: the hero animations of Orbit wave 2's pages, under the rules
// of docs/SETTINGS-KIT.md: a few shapes from `t`, loops of 2 and 4 seconds,
// and a still frame (t = 1.1) that reads on its own.

// MARK: - Remove Background

/// Remove Background: a dashed outline traces the subject and the
/// background's checkerboard fades in behind the icon, then out.
struct ZenithRemoveBackgroundHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let p = ZenithKitEase.phase(context.t, period: 4)
        // Traced in the first half, held, then let go.
        let trace = ZenithKitEase.smooth(min(1, p / 0.45))
        let lifted = p < 0.45 ? 0 : p < 0.85 ? 1 : 1 - ZenithKitEase.smooth((p - 0.85) / 0.15)
        ZStack {
            ZenithHeroChecker(square: 10, dark: context.dark)
                .frame(width: 132, height: 132)
                .mask(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .opacity(0.55 * lifted)
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .trim(from: 0, to: trace)
                .stroke(context.tint.light.color.opacity(0.9),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 5],
                                           dashPhase: CGFloat(context.t * 12)))
                .frame(width: 112, height: 112)
            context.icon
                .offset(y: -6 * lifted)
                .shadow(color: .black.opacity(0.35 * lifted), radius: 8, y: 6)
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithRemoveBackgroundHeroArt {
    static var removeBackground: Self { .init() }
}

/// A small checkerboard, the mark of transparency, drawn in one path.
struct ZenithHeroChecker: View {
    let square: CGFloat
    let dark: Bool

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .color(dark ? Color(white: 0.2) : Color(white: 0.86)))
            var path = Path()
            let columns = Int(size.width / square) + 1, rows = Int(size.height / square) + 1
            for row in 0..<rows {
                for column in 0..<columns where (row + column) % 2 == 0 {
                    path.addRect(CGRect(x: CGFloat(column) * square, y: CGFloat(row) * square,
                                        width: square, height: square))
                }
            }
            context.fill(path, with: .color(dark ? Color(white: 0.32) : Color.white))
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Emoji Picker

/// Emoji Picker: a few emoji orbit the icon and bob in turn, as if picked.
struct ZenithEmojiPickerHeroArt: ZenithHeroAnimation {
    static let emoji = ["😀", "🎉", "👍", "❤️", "🚀", "✨"]

    func art(_ context: ZenithHeroArtContext) -> some View {
        let t = context.t
        ZStack {
            ForEach(Self.emoji.indices, id: \.self) { i in
                let angle = (Double(i) / Double(Self.emoji.count) + ZenithKitEase.phase(t, period: 8)) * 2 * .pi
                // One emoji at a time steps forward, half a second each.
                let turn = ZenithKitEase.phase(t, period: 4, offset: -Double(i) / Double(Self.emoji.count))
                let picked = turn < 0.16 ? sin(turn / 0.16 * .pi) : 0
                Text(verbatim: Self.emoji[i])
                    .font(.system(size: 20))
                    .scaleEffect(0.85 + 0.35 * picked)
                    .offset(x: 72 * cos(angle), y: 62 * sin(angle))
                    .opacity(0.65 + 0.35 * picked)
            }
            context.icon.scaleEffect(1 + 0.02 * ZenithKitEase.pulse(t, period: 2))
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithEmojiPickerHeroArt {
    static var emojiPicker: Self { .init() }
}

// MARK: - Calculator

/// Calculator: digits and operators rise past the icon, which ticks as an
/// answer lands.
struct ZenithCalculatorHeroArt: ZenithHeroAnimation {
    static let marks = ["7", "+", "3", "×", "2", "=", "%", "√"]

    func art(_ context: ZenithHeroArtContext) -> some View {
        let t = context.t
        let beat = ZenithKitEase.phase(t, period: 2)
        let tick = beat < 0.1 ? sin(beat / 0.1 * .pi) : 0
        ZStack {
            ForEach(Self.marks.indices, id: \.self) { i in
                let p = ZenithKitEase.phase(t, period: 4, offset: Double(i) / Double(Self.marks.count))
                let side: CGFloat = i % 2 == 0 ? -1 : 1
                let fade = sin(p * .pi)
                Text(verbatim: Self.marks[i])
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(context.tint.light.color.opacity(0.9 * fade))
                    .offset(x: side * (58 + CGFloat(i % 3) * 9), y: 48 - CGFloat(p) * 100)
            }
            context.icon.scaleEffect(1 + 0.05 * tick)
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithCalculatorHeroArt {
    static var calculator: Self { .init() }
}
