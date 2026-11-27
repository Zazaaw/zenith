// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

// Zenith fork: the hero animations of the System and Apps pages, beside the
// kit's own in ZenithHeroAnimations.swift and under the same rules: a few
// shapes drawn from `context.t`, loops of 1, 2 or 4 seconds, and a still
// frame at `t == 1.1` that reads on its own.

// MARK: - System Monitor

/// System Monitor: a usage graph runs past the icon and its reading follows.
struct ZenithSystemMonitorHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let t = context.t
        let value = Self.sample(t, at: 1)
        ZStack {
            ZenithHeroGraph(values: (0...24).map { Self.sample(t, at: Double($0) / 24) })
                .stroke(context.tint.light.color.opacity(0.85),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .frame(width: 170, height: 46)
                .offset(y: 58)
            context.icon.offset(y: -10)
            ZenithHeroBadge(text: "CPU \(Int(value * 100))%", color: context.tint.deep.color)
                .offset(x: 52, y: -50)
        }
    }

    /// A reading between 0.2 and 0.8 at time `t`, `x` of the way along the graph.
    static func sample(_ t: Double, at x: Double) -> Double {
        let s = t / 4 * 2 * .pi + x * 7
        return 0.5 + 0.2 * sin(s) + 0.1 * sin(s * 2.3)
    }
}

extension ZenithHeroAnimation where Self == ZenithSystemMonitorHeroArt {
    static var systemMonitor: Self { .init() }
}

/// A line graph of `values` (0…1) from left to right.
struct ZenithHeroGraph: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = max(1, values.count - 1)
        for (i, value) in values.enumerated() {
            let x = Double(i) / Double(steps)
            let point = CGPoint(x: rect.minX + rect.width * x, y: rect.maxY - rect.height * value)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}

/// A small capsule with a reading, in white on `color`.
struct ZenithHeroBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.92)))
            .fixedSize()
    }
}

// MARK: - Fan Control

/// Fan Control: a fan spins in the corner and air streams off the icon.
struct ZenithFanControlHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let t = context.t
        ZStack {
            ForEach(0..<3, id: \.self) { k in
                let p = ZenithKitEase.phase(t, period: 1, offset: Double(k) / 3)
                Capsule()
                    .fill(context.tint.light.color.opacity(0.55 * sin(p * .pi)))
                    .frame(width: 26, height: 3.5)
                    .offset(x: 50 + 34 * p, y: CGFloat(k - 1) * 18)
            }
            context.icon
            Image(systemName: "fanblades.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(ZenithKitEase.phase(t, period: 1) * 360))
                .frame(width: 34, height: 34)
                .background(Circle().fill(context.tint.deep.color))
                .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1.5))
                .offset(x: -40, y: 40)
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithFanControlHeroArt {
    static var fanControl: Self { .init() }
}

// MARK: - Sleep

/// Sleep: Zs drift up from the icon, which breathes slowly.
struct ZenithSleepHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let t = context.t
        ZStack {
            context.icon.scaleEffect(1 + 0.025 * ZenithKitEase.pulse(t, period: 4))
            ForEach(0..<3, id: \.self) { k in
                let p = ZenithKitEase.phase(t, period: 4, offset: Double(k) / 3)
                Text(verbatim: "z")
                    .font(.system(size: 14 + CGFloat(p) * 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(context.tint.light.color.opacity(sin(p * .pi)))
                    .offset(x: 34 + 26 * p, y: -26 - 60 * p)
            }
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithSleepHeroArt {
    static var sleep: Self { .init() }
}

// MARK: - Brightness

/// Brightness: the rays around the icon grow and shrink as the level moves.
struct ZenithBrightnessHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let level = 0.25 + 0.75 * ZenithKitEase.smooth(ZenithKitEase.pulse(context.t, period: 4))
        ZStack {
            ForEach(0..<12, id: \.self) { k in
                Capsule()
                    .fill(Color(red: 1, green: 0.82, blue: 0.3).opacity(0.35 + 0.55 * level))
                    .frame(width: 4, height: 8 + 14 * level)
                    .offset(y: -66 - 6 * level)
                    .rotationEffect(.degrees(Double(k) * 30))
            }
            context.icon
            ZenithHeroLevel(level: level, tint: context.tint.light.color)
                .frame(width: 104)
                .offset(y: 84)
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithBrightnessHeroArt {
    static var brightness: Self { .init() }
}

/// A slider's track with its knob at `level`.
struct ZenithHeroLevel: View {
    let level: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.18)).frame(height: 5)
                Capsule().fill(tint).frame(width: width * level, height: 5)
                Circle().fill(.white).frame(width: 13, height: 13)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    .offset(x: width * level - 6.5)
            }
            .frame(height: 13)
        }
        .frame(height: 13)
    }
}

// MARK: - Menu Bar

/// Menu Bar: a small bar above the icon; one item slides behind the divider
/// and comes back.
struct ZenithMenuBarHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let p = ZenithKitEase.phase(context.t, period: 4)
        let hide = p < 0.5 ? ZenithKitEase.smooth((p - 0.15) / 0.25) : 1 - ZenithKitEase.smooth((p - 0.7) / 0.25)
        ZStack {
            context.icon.offset(y: 16)
            HStack(spacing: 7) {
                Circle().fill(Color.white.opacity(0.85)).frame(width: 7, height: 7)
                    .opacity(1 - hide)
                    .frame(width: 7 * (1 - hide))
                Capsule().fill(Color.white.opacity(0.55)).frame(width: 2, height: 12)
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.85)).frame(width: 9, height: 9)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 22)
            .background(Capsule().fill(Color.black.opacity(context.dark ? 0.5 : 0.62)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.2)))
            .offset(y: -58)
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithMenuBarHeroArt {
    static var menuBar: Self { .init() }
}

// MARK: - Command Bar

/// Command Bar: a query types itself into the bar under the icon.
struct ZenithCommandBarHeroArt: ZenithHeroAnimation {
    private static let query = Array("100 km to mi")

    func art(_ context: ZenithHeroArtContext) -> some View {
        let p = ZenithKitEase.phase(context.t, period: 4)
        let typed = min(Self.query.count, Int(p / 0.6 * Double(Self.query.count + 1)))
        let caret = ZenithKitEase.phase(context.t, period: 1) < 0.5
        ZStack {
            context.icon.offset(y: -16)
            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass").font(.system(size: 9, weight: .bold))
                Text(verbatim: String(Self.query.prefix(typed)))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .fixedSize()
                Rectangle().frame(width: 1.5, height: 12).opacity(caret ? 1 : 0)
                Spacer(minLength: 0)
                if p > 0.68 {
                    Text(verbatim: "62.1 mi")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(context.tint.light.color)
                        .fixedSize()
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .frame(width: 150, height: 26)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.black.opacity(0.6)))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Color.white.opacity(0.22)))
            .offset(y: 62)
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithCommandBarHeroArt {
    static var commandBar: Self { .init() }
}

// MARK: - Cleaner

/// Cleaner: dust around the icon fades as sparkles twinkle.
struct ZenithCleanerHeroArt: ZenithHeroAnimation {
    private static let dust: [(CGFloat, CGFloat)] = [(-62, 30), (-50, 52), (58, 44), (66, 18), (-30, 64), (40, 62)]
    private static let sparkles: [(CGFloat, CGFloat, CGFloat)] = [(48, -50, 18), (-56, -38, 13), (66, -6, 10)]

    func art(_ context: ZenithHeroArtContext) -> some View {
        let t = context.t
        ZStack {
            ForEach(Self.dust.indices, id: \.self) { i in
                let p = ZenithKitEase.phase(t, period: 2, offset: Double(i) / Double(Self.dust.count))
                Circle()
                    .fill(Color.gray.opacity(0.6 * (1 - p)))
                    .frame(width: 6, height: 6)
                    .offset(x: Self.dust[i].0 * (1 + 0.3 * p), y: Self.dust[i].1 + 14 * p)
            }
            context.icon
            ForEach(Self.sparkles.indices, id: \.self) { i in
                let s = ZenithKitEase.pulse(t + Double(i) * 0.6, period: 2)
                Image(systemName: "sparkle")
                    .font(.system(size: Self.sparkles[i].2, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.35 + 0.65 * s))
                    .scaleEffect(0.7 + 0.4 * s)
                    .offset(x: Self.sparkles[i].0, y: Self.sparkles[i].1)
            }
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithCleanerHeroArt {
    static var cleaner: Self { .init() }
}

// MARK: - Uninstaller

/// Uninstaller: an app and the files it left behind fall into the icon.
struct ZenithUninstallerHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let t = context.t
        ZStack {
            context.icon.offset(y: 14)
            ForEach(0..<3, id: \.self) { k in
                let p = ZenithKitEase.phase(t, period: 4, offset: -Double(k) * 0.08)
                let fall = ZenithKitEase.smooth(p / 0.55)
                let side: CGFloat = k == 0 ? 0 : (k == 1 ? -1 : 1)
                RoundedRectangle(cornerRadius: k == 0 ? 7 : 3, style: .continuous)
                    .fill(k == 0 ? context.tint.light.color : Color.white)
                    .frame(width: k == 0 ? 26 : 15, height: k == 0 ? 26 : 19)
                    .overlay(Image(systemName: k == 0 ? "app.fill" : "doc")
                        .font(.system(size: k == 0 ? 12 : 8, weight: .bold))
                        .foregroundStyle(k == 0 ? Color.white : Color.gray))
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
                    .scaleEffect(1 - 0.5 * fall)
                    .offset(x: side * 40 * (1 - fall), y: -80 + 84 * fall)
                    .opacity(p < 0.6 ? 1 : 0)
            }
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithUninstallerHeroArt {
    static var uninstaller: Self { .init() }
}

// MARK: - Homebrew

/// Homebrew: bubbles rise from the mug and pop.
struct ZenithHomebrewHeroArt: ZenithHeroAnimation {
    private static let bubbles: [(CGFloat, CGFloat)] = [(-18, 9), (4, 7), (20, 11), (-6, 6), (12, 8)]

    func art(_ context: ZenithHeroArtContext) -> some View {
        let t = context.t
        ZStack {
            context.icon.offset(y: 14)
            ForEach(Self.bubbles.indices, id: \.self) { i in
                let p = ZenithKitEase.phase(t, period: 2, offset: Double(i) / Double(Self.bubbles.count))
                let size = Self.bubbles[i].1
                Circle()
                    .strokeBorder(Color.white.opacity(0.8 * (1 - p)), lineWidth: 1.5)
                    .background(Circle().fill(Color(red: 1, green: 0.85, blue: 0.4).opacity(0.25 * (1 - p))))
                    .frame(width: size, height: size)
                    .scaleEffect(1 + 0.5 * p)
                    .offset(x: Self.bubbles[i].0 + 4 * sin(p * 6), y: -30 - 56 * p)
            }
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithHomebrewHeroArt {
    static var homebrew: Self { .init() }
}

// MARK: - App Updates

/// App Updates: a ring fills around the icon, then a tick lands.
struct ZenithAppUpdatesHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let p = ZenithKitEase.phase(context.t, period: 4)
        let fill = ZenithKitEase.smooth(p / 0.55)
        let done = ZenithKitEase.bounceIn((p - 0.55) / 0.2)
        let fade = p < 0.9 ? 1 : 1 - (p - 0.9) / 0.1
        ZStack {
            Circle().stroke(context.tint.light.color.opacity(0.18), lineWidth: 5).frame(width: 128, height: 128)
            Circle()
                .trim(from: 0, to: fill)
                .stroke(context.tint.light.color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 128, height: 128)
                .opacity(fade)
            context.icon
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(ZenithStatus.success))
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                .scaleEffect(done)
                .opacity(fade)
                .offset(x: 44, y: -44)
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithAppUpdatesHeroArt {
    static var appUpdates: Self { .init() }
}

// MARK: - Kill Process

/// Kill Process: a list of processes beside the icon; the busy one turns
/// red and leaves, and the rows close up.
struct ZenithKillProcessHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let p = ZenithKitEase.phase(context.t, period: 4)
        let warn = ZenithKitEase.smooth((p - 0.1) / 0.2)
        let leave = ZenithKitEase.smooth((p - 0.45) / 0.2)
        let close = ZenithKitEase.smooth((p - 0.65) / 0.2)
        let reset = p < 0.92 ? 1.0 : 0.0
        ZStack {
            context.icon.offset(x: -30)
            VStack(alignment: .leading, spacing: 6) {
                row(width: 40, color: Color.white.opacity(0.75))
                row(width: 52, color: warn * reset > 0.5 ? ZenithStatus.error : Color.white.opacity(0.75))
                    .offset(x: 50 * leave * reset)
                    .opacity(1 - leave * reset)
                    .frame(height: 8 * (1 - close * reset))
                row(width: 34, color: Color.white.opacity(0.75))
                row(width: 46, color: Color.white.opacity(0.75))
            }
            .frame(width: 60, alignment: .leading)
            .offset(x: 62)
        }
    }

    private func row(width: CGFloat, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Capsule().fill(color).frame(width: width, height: 6)
        }
        .frame(height: 8)
    }
}

extension ZenithHeroAnimation where Self == ZenithKillProcessHeroArt {
    static var killProcess: Self { .init() }
}

// MARK: - Port Manager

/// Port Manager: packets travel into the icon along two lines, each with
/// the port it listens on.
struct ZenithPortManagerHeroArt: ZenithHeroAnimation {
    private static let ports = [":3000", ":5173"]

    func art(_ context: ZenithHeroArtContext) -> some View {
        let t = context.t
        ZStack {
            ForEach(0..<2, id: \.self) { k in
                let y: CGFloat = k == 0 ? -26 : 26
                Capsule().fill(context.tint.light.color.opacity(0.25)).frame(width: 70, height: 2.5)
                    .offset(x: -62, y: y)
                ForEach(0..<2, id: \.self) { j in
                    let p = ZenithKitEase.phase(t, period: 2, offset: Double(j) / 2 + Double(k) * 0.25)
                    Circle()
                        .fill(context.tint.light.color.opacity(sin(p * .pi)))
                        .frame(width: 7, height: 7)
                        .offset(x: -96 + 64 * p, y: y)
                }
                ZenithHeroBadge(text: Self.ports[k], color: context.tint.deep.color)
                    .offset(x: 58, y: y)
            }
            context.icon
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithPortManagerHeroArt {
    static var portManager: Self { .init() }
}
