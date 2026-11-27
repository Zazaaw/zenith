// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

// Zenith fork: the Island group's hero animations (docs/SETTINGS-KIT.md):
// the island itself, each section with a page of its own, and the companion.
// A few shapes from `t`, loops of 1, 1.6, 2 or 4 seconds, and a still frame
// at t = 1.1 that reads on its own.

// MARK: - Dynamic Island

/// Dynamic Island: a black island under the icon opens wide, holds, and
/// closes back to the camera.
struct ZenithIslandHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let p = ZenithKitEase.phase(context.t, period: 4)
        let open = p < 0.2 ? ZenithKitEase.smooth(p / 0.2)
            : p < 0.6 ? 1 : 1 - ZenithKitEase.smooth((p - 0.6) / 0.2)
        let still = context.moving ? open : 1
        ZStack {
            context.icon.offset(y: -10)
            RoundedRectangle(cornerRadius: 9 + 7 * still, style: .continuous)
                .fill(Color.black)
                .overlay(RoundedRectangle(cornerRadius: 9 + 7 * still, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                .frame(width: 50 + 82 * still, height: 18 + 22 * still)
                .overlay(alignment: .leading) {
                    Circle().fill(context.tint.light.color)
                        .frame(width: 8, height: 8)
                        .padding(.leading, 10 + 6 * still)
                        .opacity(0.4 + 0.6 * still)
                }
                .overlay(alignment: .trailing) {
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { k in
                            Capsule().fill(Color.white.opacity(0.75))
                                .frame(width: 3, height: 4 + 8 * still * (0.5 + 0.5 * sin(context.t * 6 + Double(k))))
                        }
                    }
                    .padding(.trailing, 12 + 6 * still)
                    .opacity(still)
                }
                .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
                .offset(y: 62)
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithIslandHeroArt {
    static var island: Self { .init() }
}

// MARK: - Calendar

/// Calendar: the next event's countdown runs round the icon, and its chip
/// rises when the ring closes.
struct ZenithCalendarHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let p = ZenithKitEase.phase(context.t, period: 4)
        let fill = ZenithKitEase.smooth(min(1, p / 0.75))
        let chip = ZenithKitEase.smooth(max(0, (p - 0.7) / 0.15)) * (1 - ZenithKitEase.smooth(max(0, (p - 0.92) / 0.08)))
        ZStack {
            Circle().stroke(context.tint.light.color.opacity(0.18), lineWidth: 5).frame(width: 128, height: 128)
            Circle()
                .trim(from: 0, to: fill)
                .stroke(context.tint.light.color.opacity(0.85), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 128, height: 128)
            context.icon
            Text(verbatim: "10:00")
                .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(ZenithStatus.error))
                .offset(x: 46, y: -50 - 8 * chip)
                .opacity(context.moving ? chip : 1)
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithCalendarHeroArt {
    static var calendar: Self { .init() }
}

// MARK: - Notifications

/// Notifications: banners drop in from above and stack, the bell rings.
struct ZenithNotificationsHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let t = context.t
        let p = ZenithKitEase.phase(t, period: 4)
        let ring = p < 0.25 ? sin(p / 0.25 * 6 * .pi) * (1 - p / 0.25) : 0
        ZStack {
            ForEach(0..<2, id: \.self) { k in
                let q = ZenithKitEase.smooth((p - Double(k) * 0.2) / 0.25)
                let leave = ZenithKitEase.smooth((p - 0.85) / 0.15)
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(context.dark ? 0.16 : 0.1))
                    .overlay(alignment: .leading) {
                        HStack(spacing: 6) {
                            Circle().fill(k == 0 ? ZenithStatus.success : context.tint.light.color).frame(width: 9, height: 9)
                            VStack(alignment: .leading, spacing: 3) {
                                Capsule().fill(Color.primary.opacity(0.55)).frame(width: 42, height: 4)
                                Capsule().fill(Color.primary.opacity(0.3)).frame(width: 60, height: 4)
                            }
                        }
                        .padding(.leading, 9)
                    }
                    .frame(width: 104, height: 26)
                    .offset(x: k == 0 ? 30 : -28, y: (k == 0 ? -64 : -48) - 30 * (1 - q))
                    .opacity(context.moving ? q * (1 - leave) : 1)
            }
            context.icon.rotationEffect(.degrees(10 * ring), anchor: .top)
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithNotificationsHeroArt {
    static var notifications: Self { .init() }
}

// MARK: - Music

/// Music: equalizer bars move on both sides of the icon, a note floats up.
struct ZenithMusicHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let t = context.t
        ZStack {
            HStack(spacing: 110) {
                bars(t, seed: 0, tint: context.tint.light.color)
                bars(t, seed: 2, tint: context.tint.light.color)
            }
            context.icon.scaleEffect(1 + 0.025 * ZenithKitEase.pulse(t * 2, period: 1))
            ForEach(0..<2, id: \.self) { k in
                let p = ZenithKitEase.phase(t, period: 4, offset: Double(k) / 2)
                Image(systemName: k == 0 ? "music.note" : "music.quarternote.3")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(context.tint.light.color.opacity(sin(p * .pi)))
                    .offset(x: (k == 0 ? 40 : -44) + 6 * sin(p * 2 * .pi), y: 30 - 100 * p)
            }
        }
    }

    private func bars(_ t: Double, seed: Int, tint: Color) -> some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<4, id: \.self) { k in
                let swing = 0.35 + 0.65 * ZenithKitEase.pulse(t * 2 + Double(k + seed) * 0.37, period: 1)
                Capsule().fill(tint.opacity(0.8)).frame(width: 4, height: 8 + 26 * swing)
            }
        }
        .frame(height: 36)
    }
}

extension ZenithHeroAnimation where Self == ZenithMusicHeroArt {
    static var music: Self { .init() }
}

// MARK: - Timer

/// Timer: the remaining time drains round the icon as a tick goes round.
struct ZenithTimerHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let p = ZenithKitEase.phase(context.t, period: 8)
        let left = context.moving ? 1 - p : 0.7
        ZStack {
            Circle().stroke(context.tint.light.color.opacity(0.16), lineWidth: 6).frame(width: 130, height: 130)
            Circle()
                .trim(from: 0, to: left)
                .stroke(context.tint.light.color.opacity(0.9), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 130, height: 130)
            Circle()
                .fill(Color.white)
                .frame(width: 9, height: 9)
                .shadow(color: context.tint.light.color, radius: 4)
                .offset(y: -65)
                .rotationEffect(.degrees(360 * left))
            context.icon
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithTimerHeroArt {
    static var timer: Self { .init() }
}

// MARK: - Agents

/// Agents: sparks circle the icon like a model at work, one pulsing bright.
struct ZenithAgentsHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let t = context.t
        let turn = ZenithKitEase.phase(t, period: 8)
        ZStack {
            Circle().strokeBorder(context.tint.light.color.opacity(0.22), style: StrokeStyle(lineWidth: 1.5, dash: [3, 6]))
                .frame(width: 140, height: 140)
                .rotationEffect(.degrees(-360 * turn))
            ForEach(0..<3, id: \.self) { k in
                let angle = (turn + Double(k) / 3) * 2 * .pi
                let glow = ZenithKitEase.pulse(t + Double(k) * 0.5, period: 1.6)
                Image(systemName: "sparkle")
                    .font(.system(size: 12 + 5 * glow, weight: .bold))
                    .foregroundStyle(context.tint.light.color.opacity(0.55 + 0.45 * glow))
                    .offset(x: 70 * cos(angle), y: 70 * sin(angle))
            }
            context.icon
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithAgentsHeroArt {
    static var agents: Self { .init() }
}

// MARK: - Downloads

/// Downloads: files fall into the icon and a progress bar fills under it.
struct ZenithDownloadsHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let p = ZenithKitEase.phase(context.t, period: 2)
        let progress = context.moving ? ZenithKitEase.phase(context.t, period: 4) : 0.6
        ZStack {
            ForEach(0..<2, id: \.self) { k in
                let q = ZenithKitEase.phase(p, period: 1, offset: Double(k) / 2)
                Image(systemName: "arrow.down")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(context.tint.light.color.opacity(sin(q * .pi)))
                    .offset(x: k == 0 ? -54 : 54, y: -50 + 70 * q)
            }
            context.icon
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.14))
                Capsule().fill(context.tint.light.color).frame(width: 96 * progress)
            }
            .frame(width: 96, height: 6)
            .offset(y: 66)
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithDownloadsHeroArt {
    static var downloads: Self { .init() }
}

// MARK: - Watch

/// Watch: a viewfinder closes in on the icon and a change flashes in it.
struct ZenithWatchHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let p = ZenithKitEase.phase(context.t, period: 4)
        let close = ZenithKitEase.pulse(context.t, period: 4)
        let size = 124 + 28 * close
        let flash = p > 0.55 && p < 0.7 ? sin((p - 0.55) / 0.15 * .pi) : 0
        ZStack {
            context.icon
            ZenithViewfinderCorners()
                .stroke(context.tint.light.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: size, height: size)
            Circle().fill(ZenithStatus.success)
                .frame(width: 12, height: 12)
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                .scaleEffect(0.8 + 0.4 * flash)
                .opacity(context.moving ? flash : 1)
                .offset(x: 40, y: -40)
        }
    }
}

/// A viewfinder's four corners.
private struct ZenithViewfinderCorners: Shape {
    func path(in rect: CGRect) -> Path {
        let arm = rect.width * 0.18
        var path = Path()
        for (x, y, dx, dy) in [(rect.minX, rect.minY, 1.0, 1.0), (rect.maxX, rect.minY, -1.0, 1.0),
                               (rect.minX, rect.maxY, 1.0, -1.0), (rect.maxX, rect.maxY, -1.0, -1.0)] {
            path.move(to: CGPoint(x: x + dx * arm, y: y))
            path.addLine(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x, y: y + dy * arm))
        }
        return path
    }
}

extension ZenithHeroAnimation where Self == ZenithWatchHeroArt {
    static var watch: Self { .init() }
}

// MARK: - Mascot

/// Mascot: the star companion hops on the icon's squircle and blinks.
struct ZenithMascotHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let t = context.t
        let beat = ZenithKitEase.phase(t, period: 2)
        let hop = beat < 0.4 ? sin(beat / 0.4 * .pi) : 0
        let squash = beat > 0.4 && beat < 0.5 ? sin((beat - 0.4) / 0.1 * .pi) : 0
        let blink = ZenithKitEase.phase(t, period: 4) > 0.9
        ZStack {
            context.base
            Ellipse().fill(Color.black.opacity(0.25))
                .frame(width: 44 - 14 * hop, height: 7)
                .offset(y: 34)
            ZenithMascotStar(blink: blink)
                .frame(width: 58, height: 58)
                .scaleEffect(x: 1 + 0.1 * squash, y: 1 - 0.1 * squash, anchor: .bottom)
                .offset(y: 2 - 18 * hop)
            ForEach(0..<2, id: \.self) { k in
                let q = ZenithKitEase.phase(t, period: 4, offset: Double(k) / 2)
                Image(systemName: "sparkle")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.35).opacity(sin(q * .pi)))
                    .offset(x: k == 0 ? -46 : 48, y: -20 - 30 * q)
            }
        }
    }
}

/// Zenith's companion as the hero draws it: a rounded golden star with two eyes.
struct ZenithMascotStar: View {
    var blink = false

    var body: some View {
        ZStack {
            ZenithStarShape()
                .fill(LinearGradient(colors: [Color(red: 1, green: 0.88, blue: 0.4), Color(red: 1, green: 0.62, blue: 0.15)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(ZenithStarShape().stroke(Color(red: 0.85, green: 0.45, blue: 0.05).opacity(0.6), lineWidth: 1.5))
            HStack(spacing: 9) {
                ForEach(0..<2, id: \.self) { _ in
                    Capsule().fill(Color(red: 0.2, green: 0.12, blue: 0.05))
                        .frame(width: 5, height: blink ? 1.5 : 8)
                }
            }
            .offset(y: 3)
        }
        .shadow(color: Color(red: 1, green: 0.6, blue: 0.1).opacity(0.45), radius: 6)
        .accessibilityHidden(true)
    }
}

/// A five-pointed star with softened points.
struct ZenithStarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY + rect.height * 0.04)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.5
        var points: [CGPoint] = []
        for i in 0..<10 {
            let radius = i % 2 == 0 ? outer : inner
            let angle = -Double.pi / 2 + Double(i) * .pi / 5
            points.append(CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle)))
        }
        var path = Path()
        // Rounded joints: each corner is cut by a quad curve through it.
        for i in 0..<10 {
            let previous = points[(i + 9) % 10], point = points[i], next = points[(i + 1) % 10]
            let start = CGPoint(x: point.x + (previous.x - point.x) * 0.18, y: point.y + (previous.y - point.y) * 0.18)
            let end = CGPoint(x: point.x + (next.x - point.x) * 0.18, y: point.y + (next.y - point.y) * 0.18)
            if i == 0 { path.move(to: start) } else { path.addLine(to: start) }
            path.addQuadCurve(to: end, control: point)
        }
        path.closeSubpath()
        return path
    }
}

extension ZenithHeroAnimation where Self == ZenithMascotHeroArt {
    static var mascot: Self { .init() }
}
