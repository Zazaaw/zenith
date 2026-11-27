// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

// Zenith fork: each feature's own little animation around its hero icon,
// after the approved mockup. A new one is a struct conforming to
// `ZenithHeroAnimation` plus a static member, so a page writes
// `animation: .mechakey`. See docs/SETTINGS-KIT.md for the rules.

/// What a hero animation draws with.
struct ZenithHeroArtContext {
    /// Seconds. While the art may not move it holds `ZenithKitMotionRule.stillTime`,
    /// so every animation shows one well-chosen still frame.
    let t: Double
    /// Whether time is running.
    let moving: Bool
    /// The page's category tint.
    let tint: ZenithCategoryTint
    let dark: Bool
    /// The page's icon at 88 pt from the bitmap cache, ready to move.
    let icon: ZenithHeroIcon
    /// The icon's empty squircle, for art that draws its own glyph.
    var base: ZenithHeroIconBase { ZenithHeroIconBase() }
}

/// A feature's animation around its hero icon, drawn on a 190 pt square
/// centred on the icon. Keep it light: a few shapes driven by `context.t`,
/// no state, no timers, no blur; loops of 0.5, 1, 1.6, 2, 4 or 8 seconds
/// (the clock wraps at 80). Hold to the category's tint or the status
/// colours, and make the still frame (`t == 1.1`) read on its own.
///
///     struct ZenithMyFeatureHeroArt: ZenithHeroAnimation {
///         func art(_ context: ZenithHeroArtContext) -> some View {
///             context.icon.offset(y: 3 * sin(context.t * .pi))
///         }
///     }
///     extension ZenithHeroAnimation where Self == ZenithMyFeatureHeroArt {
///         static var myFeature: Self { .init() }
///     }
protocol ZenithHeroAnimation {
    associatedtype Art: View
    @MainActor @ViewBuilder func art(_ context: ZenithHeroArtContext) -> Art
}

// MARK: - The icon alone

/// The default: the icon, floating a little.
struct ZenithHeroIconArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        context.icon.offset(y: -3 * (ZenithKitEase.pulse(context.t, period: 4) - 0.5))
    }
}

extension ZenithHeroAnimation where Self == ZenithHeroIconArt {
    static var icon: Self { .init() }
}

// MARK: - Mechakey

/// Mechakey: the key goes down twice a second and rings go out with each press.
struct ZenithMechakeyHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let t = context.t
        let beat = ZenithKitEase.phase(t, period: 0.5)
        let press = beat < 0.12 ? ZenithKitEase.smooth(beat / 0.12) : 1 - ZenithKitEase.smooth((beat - 0.12) / 0.25)
        ZStack {
            ForEach(0..<3, id: \.self) { k in
                let p = ZenithKitEase.phase(t, period: 0.5, offset: Double(k) / 3)
                Circle()
                    .strokeBorder(context.tint.light.color.opacity(0.5 * (1 - p)), lineWidth: 2)
                    .frame(width: 90 + 90 * p, height: 90 + 90 * p)
            }
            context.icon
                .offset(y: 4 * press)
                .scaleEffect(x: 1, y: 1 - 0.04 * press, anchor: .bottom)
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithMechakeyHeroArt {
    static var mechakey: Self { .init() }
}

// MARK: - Translate

/// Translate: greetings in other languages rise past the icon, which sways.
struct ZenithTranslateHeroArt: ZenithHeroAnimation {
    static let words = ["Halo", "Hola", "你好", "Bonjour", "Ciao", "こんにちは"]

    func art(_ context: ZenithHeroArtContext) -> some View {
        let t = context.t
        ZStack {
            ForEach(Self.words.indices, id: \.self) { i in
                let p = ZenithKitEase.phase(t, period: 4, offset: Double(i) / Double(Self.words.count))
                let side: CGFloat = i % 2 == 0 ? -1 : 1
                let fade = sin(p * .pi)
                Text(verbatim: Self.words[i])
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.primary.opacity(fade * 0.85))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.primary.opacity(0.08 * fade)))
                    .fixedSize()
                    .offset(x: side * (52 + CGFloat(i % 3) * 8), y: 46 - CGFloat(p) * 104)
                    .scaleEffect(0.9)
            }
            context.icon.rotationEffect(.degrees(3 * sin(t / 4 * 2 * .pi)))
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithTranslateHeroArt {
    static var translate: Self { .init() }
}

// MARK: - Meetings

/// Meetings: the call rings out in rounded squares, a live dot pulses.
struct ZenithMeetingsHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let t = context.t
        let beat = ZenithKitEase.pulse(t, period: 1)
        ZStack {
            ForEach(0..<2, id: \.self) { k in
                let p = ZenithKitEase.phase(t, period: 1.6, offset: Double(k) / 2)
                RoundedRectangle(cornerRadius: 28 + 20 * p, style: .continuous)
                    .strokeBorder(context.tint.light.color.opacity(0.55 * (1 - p)), lineWidth: 2)
                    .frame(width: 92 + 80 * p, height: 92 + 80 * p)
            }
            context.icon
            Circle()
                .fill(ZenithStatus.error)
                .frame(width: 14, height: 14)
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                .scaleEffect(0.85 + 0.25 * beat)
                .shadow(color: ZenithStatus.error, radius: 6 * beat)
                .offset(x: 38, y: -38)
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithMeetingsHeroArt {
    static var meetings: Self { .init() }
}

// MARK: - Shelf

/// Shelf: a document and a picture drop into the tray and bounce.
struct ZenithShelfHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let p = ZenithKitEase.phase(context.t, period: 2)
        ZStack {
            context.icon
            ForEach(0..<2, id: \.self) { k in
                let q = p - Double(k) * 0.18
                let fall = ZenithKitEase.bounceIn(ZenithKitEase.smooth(q / 0.45))
                RoundedRectangle(cornerRadius: 4)
                    .fill(k == 0 ? Color.white : Color(red: 1, green: 0.55, blue: 0.25))
                    .frame(width: 22, height: 28)
                    .overlay(Image(systemName: k == 0 ? "doc.text" : "photo")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(k == 0 ? Color.gray : .white))
                    .rotationEffect(.degrees(k == 0 ? -14 : 12))
                    .offset(x: k == 0 ? -12 : 14, y: -110 + 80 * fall)
                    .opacity(q < 0 || q > 0.8 ? 0 : 1)
                    .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
            }
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithShelfHeroArt {
    static var shelf: Self { .init() }
}

// MARK: - Batteries

/// Batteries: three rings fill, as the widget's do.
struct ZenithBatteriesHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let p = ZenithKitEase.smooth(ZenithKitEase.phase(context.t, period: 4) / 0.55)
        ZStack {
            context.base
            ring(34, 0.82 * p, [Color(red: 0.2, green: 0.9, blue: 0.45), Color(red: 0.6, green: 1, blue: 0.4)])
            ring(23, 0.56 * p, [Color(red: 1, green: 0.8, blue: 0.2), Color(red: 1, green: 0.55, blue: 0.1)])
            ring(12, 0.24 * p, [Color(red: 1, green: 0.3, blue: 0.3), Color(red: 1, green: 0.5, blue: 0.5)])
        }
    }

    private func ring(_ radius: CGFloat, _ value: Double, _ colors: [Color]) -> some View {
        ZStack {
            Circle().stroke(colors[0].opacity(0.18), lineWidth: 7)
            Circle()
                .trim(from: 0, to: value)
                .stroke(AngularGradient(colors: colors, center: .center),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: colors[0].opacity(0.7), radius: 4)
        }
        .frame(width: radius * 2, height: radius * 2)
    }
}

extension ZenithHeroAnimation where Self == ZenithBatteriesHeroArt {
    static var batteries: Self { .init() }
}

// MARK: - Lock Screen

/// Lock Screen: the padlock opens, waits, and locks again.
struct ZenithLockScreenHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let p = ZenithKitEase.phase(context.t, period: 4)
        let open: Double = p < 0.35 ? 0
            : p < 0.5 ? ZenithKitEase.bounceIn((p - 0.35) / 0.15)
            : p < 0.75 ? 1 : 1 - ZenithKitEase.bounceIn((p - 0.75) / 0.15)
        let shackle = context.dark ? [Color(white: 0.95), Color(white: 0.6)] : [Color(white: 0.62), Color(white: 0.38)]
        ZStack {
            context.base
            Path { path in
                path.addArc(center: CGPoint(x: 50, y: 40), radius: 15, startAngle: .degrees(180),
                            endAngle: .degrees(0), clockwise: false)
                path.addLine(to: CGPoint(x: 65, y: 52))
                path.move(to: CGPoint(x: 35, y: 40))
                path.addLine(to: CGPoint(x: 35, y: 52))
            }
            .stroke(LinearGradient(colors: shackle, startPoint: .top, endPoint: .bottom),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round))
            .frame(width: 100, height: 100)
            .offset(y: -10 * open)
            .rotationEffect(.degrees(-8 * open), anchor: UnitPoint(x: 0.65, y: 0.5))
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 1, green: 0.82, blue: 0.35), Color(red: 0.9, green: 0.55, blue: 0.1)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 46, height: 36)
                .overlay(Circle().fill(Color(red: 0.45, green: 0.25, blue: 0.02)).frame(width: 8).offset(y: 2))
                .offset(y: 12)
                .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithLockScreenHeroArt {
    static var lockScreen: Self { .init() }
}
