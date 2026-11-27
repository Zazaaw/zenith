// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

// Zenith fork: the hero animations of the Input, Windows and quick tool
// pages (docs/SETTINGS-KIT.md). Each draws what its feature does in a few
// shapes driven by `context.t`, loops of 1.6, 2, 4 or 8 seconds, and reads
// on its still frame (`t == 1.1`).

/// A small window drawn in the art: a light body under a darker title strip.
private struct HeroWindow: View {
    var width: CGFloat
    var height: CGFloat
    var tint: Color = .white
    var lit = false

    var body: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(tint.opacity(0.92))
            .overlay(alignment: .top) {
                UnevenRoundedRectangle(topLeadingRadius: 5, topTrailingRadius: 5, style: .continuous)
                    .fill(Color.black.opacity(0.22))
                    .frame(height: max(4, height * 0.18))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(lit ? Color.accentColor : Color.black.opacity(0.12), lineWidth: lit ? 2 : 1)
            }
            .frame(width: width, height: height)
            .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
    }
}

// MARK: - Scrolling

/// Scrolling: lines of a page stream upwards on both sides of the icon.
struct ZenithScrollingHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        ZStack {
            ForEach(0..<2, id: \.self) { side in
                ForEach(0..<5, id: \.self) { k in
                    let p = ZenithKitEase.phase(context.t, period: 2, offset: Double(k) / 5)
                    let fade = sin(p * .pi)
                    Capsule()
                        .fill(context.tint.light.color.opacity(0.75 * fade))
                        .frame(width: k % 2 == 0 ? 22 : 14, height: 4)
                        .offset(x: side == 0 ? -64 : 64, y: 60 - 120 * p)
                }
            }
            context.icon.offset(y: -3 * sin(context.t / 2 * 2 * .pi))
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithScrollingHeroArt {
    static var scrolling: Self { .init() }
}

// MARK: - Pointer

/// Pointer: the arrow glides around the icon, a fading trail behind it.
struct ZenithPointerHeroArt: ZenithHeroAnimation {
    private func point(_ t: Double) -> CGPoint {
        let a = t / 4 * 2 * .pi
        return CGPoint(x: 62 * cos(a), y: 44 * sin(2 * a))
    }

    func art(_ context: ZenithHeroArtContext) -> some View {
        let tip = point(context.t)
        ZStack {
            context.icon
            ForEach(1..<7, id: \.self) { k in
                let p = point(context.t - Double(k) * 0.07)
                Circle()
                    .fill(context.tint.light.color.opacity(0.5 * (1 - Double(k) / 7)))
                    .frame(width: 7 - CGFloat(k) * 0.7)
                    .offset(x: p.x, y: p.y)
            }
            Image(systemName: "cursorarrow")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
                .offset(x: tip.x + 6, y: tip.y + 10)
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithPointerHeroArt {
    static var pointer: Self { .init() }
}

// MARK: - Mouse Buttons

/// Mouse Buttons: the two sides click in turn, each with a ring of its own.
struct ZenithMouseButtonsHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let t = context.t
        let p = ZenithKitEase.phase(t, period: 1.6)
        let side: CGFloat = p < 0.5 ? -1 : 1
        let local = p < 0.5 ? p * 2 : (p - 0.5) * 2
        let press = local < 0.15 ? ZenithKitEase.smooth(local / 0.15) : 1 - ZenithKitEase.smooth((local - 0.15) / 0.3)
        ZStack {
            Circle()
                .strokeBorder(context.tint.light.color.opacity(0.6 * (1 - local)), lineWidth: 2)
                .frame(width: 30 + 60 * local, height: 30 + 60 * local)
                .offset(x: side * 40, y: -40)
            context.icon
                .rotationEffect(.degrees(Double(side) * 2.5 * press))
                .offset(y: 2 * press)
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithMouseButtonsHeroArt {
    static var mouseButtons: Self { .init() }
}

// MARK: - Key Debounce

/// Key Debounce: each press drops two marks; the first passes the filter,
/// the bounce behind it stops at the line and fades.
struct ZenithKeyDebounceHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let p = ZenithKitEase.phase(context.t, period: 2)
        let press = p < 0.08 ? ZenithKitEase.smooth(p / 0.08) : 1 - ZenithKitEase.smooth((p - 0.08) / 0.2)
        ZStack {
            Capsule()
                .fill(context.tint.light.color.opacity(0.7))
                .frame(width: 96, height: 3)
                .offset(y: 66)
            mark(progress: ZenithKitEase.smooth((p - 0.1) / 0.5), stopsAt: nil, color: ZenithStatus.success)
            mark(progress: ZenithKitEase.smooth((p - 0.2) / 0.3), stopsAt: 0.55, color: ZenithStatus.error)
            context.icon.offset(y: -14 + 4 * press)
        }
    }

    private func mark(progress: Double, stopsAt: Double?, color: Color) -> some View {
        let travel = min(progress, stopsAt ?? 1)
        let fade = stopsAt.map { progress >= $0 ? max(0, 1 - (progress - $0) * 4) : 1 } ?? (1 - progress * 0.6)
        return Circle()
            .fill(color)
            .frame(width: 9, height: 9)
            .offset(y: 34 + 52 * travel)
            .opacity(progress <= 0 ? 0 : fade)
    }
}

extension ZenithHeroAnimation where Self == ZenithKeyDebounceHeroArt {
    static var keyDebounce: Self { .init() }
}

// MARK: - Super Key

/// Super Key: the four modifiers circle the key and light up one by one.
struct ZenithSuperKeyHeroArt: ZenithHeroAnimation {
    private static let glyphs = ["⇧", "⌃", "⌥", "⌘"]

    func art(_ context: ZenithHeroArtContext) -> some View {
        let t = context.t
        let lit = Int(ZenithKitEase.phase(t, period: 2) * 4) % 4
        ZStack {
            ForEach(0..<4, id: \.self) { k in
                let a = t / 8 * 2 * .pi + Double(k) * .pi / 2
                Text(verbatim: Self.glyphs[k])
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(k == lit ? Color.white : Color.primary.opacity(0.7))
                    .frame(width: 28, height: 28)
                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(k == lit ? context.tint.deep.color : Color.primary.opacity(0.1)))
                    .shadow(color: k == lit ? context.tint.light.color : .clear, radius: 6)
                    .offset(x: 72 * cos(a), y: 58 * sin(a))
            }
            context.icon
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithSuperKeyHeroArt {
    static var superKey: Self { .init() }
}

// MARK: - Window Switcher

/// Window Switcher: three windows in a row, the selection stepping along.
struct ZenithSwitcherHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let step = Int(ZenithKitEase.phase(context.t, period: 2) * 3) % 3
        ZStack {
            context.icon.offset(y: -22)
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { k in
                    HeroWindow(width: 40, height: 28, lit: k == step)
                        .scaleEffect(k == step ? 1.1 : 0.94)
                }
            }
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.black.opacity(0.55)))
            .offset(y: 52)
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithSwitcherHeroArt {
    static var switcher: Self { .init() }
}

// MARK: - Dock

/// Dock: a dock under the icon, one tile bouncing and a preview over it.
struct ZenithDockHeroArt: ZenithHeroAnimation {
    private static let colors: [Color] = [
        Color(red: 0.38, green: 0.65, blue: 0.98), Color(red: 0.2, green: 0.83, blue: 0.6),
        Color(red: 0.98, green: 0.45, blue: 0.52), Color(red: 0.98, green: 0.8, blue: 0.3),
    ]

    func art(_ context: ZenithHeroArtContext) -> some View {
        let p = ZenithKitEase.phase(context.t, period: 2)
        let bounce = p < 0.4 ? sin(p / 0.4 * .pi) : 0
        let preview = ZenithKitEase.smooth((p - 0.35) / 0.15) * (1 - ZenithKitEase.smooth((p - 0.85) / 0.15))
        ZStack {
            context.icon.offset(y: -26)
            HeroWindow(width: 42, height: 28)
                .scaleEffect(0.6 + 0.4 * preview)
                .opacity(preview)
                .offset(x: 13, y: 30)
            HStack(spacing: 6) {
                ForEach(Self.colors.indices, id: \.self) { k in
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Self.colors[k])
                        .frame(width: 20, height: 20)
                        .offset(y: k == 2 ? -10 * bounce : 0)
                }
            }
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.white.opacity(0.22)))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Color.white.opacity(0.3)))
            .offset(y: 66)
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithDockHeroArt {
    static var dock: Self { .init() }
}

// MARK: - Spaces

/// Spaces: three desktops slide past in the same order, 1, 2, 3.
struct ZenithSpacesHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let p = ZenithKitEase.phase(context.t, period: 4)
        let shift = ZenithKitEase.smooth(p * 3 - floor(p * 3)) + floor(p * 3)
        ZStack {
            ForEach(0..<4, id: \.self) { k in
                let x = (Double(k) - shift) * 64 + 64
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(context.tint.light.color.opacity(0.3))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(context.tint.light.color.opacity(0.7), lineWidth: 1.5))
                    .overlay(Text(verbatim: "\(k % 3 + 1)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white))
                    .frame(width: 52, height: 36)
                    .offset(x: x, y: 64)
                    .opacity(max(0, 1 - abs(x) / 110))
            }
            context.icon.offset(y: -16)
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithSpacesHeroArt {
    static var spaces: Self { .init() }
}

// MARK: - Window Layout

/// Window Layout: two windows snap to the halves of a screen around the icon.
struct ZenithWindowLayoutHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let p = ZenithKitEase.phase(context.t, period: 4)
        let snap = ZenithKitEase.bounceIn(ZenithKitEase.smooth((p - 0.1) / 0.3)) * (1 - ZenithKitEase.smooth((p - 0.85) / 0.15))
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(context.tint.light.color.opacity(0.6), lineWidth: 2)
                .frame(width: 164, height: 112)
            HeroWindow(width: 40 + 36 * snap, height: 56 + 44 * snap)
                .offset(x: -20 - 21 * snap, y: 8 - 8 * snap)
            HeroWindow(width: 40 + 36 * snap, height: 56 + 44 * snap, tint: Color(white: 0.85))
                .offset(x: 20 + 21 * snap, y: 8 - 8 * snap)
            context.icon.scaleEffect(0.62).offset(y: 2)
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithWindowLayoutHeroArt {
    static var windowLayout: Self { .init() }
}

// MARK: - Auto Quit

/// Auto Quit: the app's last window closes, and its running dot goes out.
struct ZenithAutoQuitHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let p = ZenithKitEase.phase(context.t, period: 4)
        let close = ZenithKitEase.smooth((p - 0.25) / 0.2)
        let dot = 1 - ZenithKitEase.smooth((p - 0.5) / 0.15)
        let back = ZenithKitEase.smooth((p - 0.85) / 0.15)
        ZStack {
            context.icon
            HeroWindow(width: 50, height: 36)
                .overlay(alignment: .topLeading) {
                    Circle().fill(ZenithStatus.error).frame(width: 6, height: 6).offset(x: 4, y: 1)
                }
                .scaleEffect(max(0.01, 1 - close + back))
                .opacity(1 - close + back)
                .offset(x: 46, y: -46)
            Circle()
                .fill(Color.primary.opacity(0.75))
                .frame(width: 6, height: 6)
                .opacity(min(1, dot + back))
                .offset(y: 56)
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithAutoQuitHeroArt {
    static var autoQuit: Self { .init() }
}

// MARK: - Quit Protection

/// Quit Protection: ⌘Q is held while a ring fills; only then does it go through.
struct ZenithQuitProtectionHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let p = ZenithKitEase.phase(context.t, period: 2)
        let fill = ZenithKitEase.smooth(p / 0.7)
        let done = p > 0.7
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.12), lineWidth: 6)
                .frame(width: 128, height: 128)
            Circle()
                .trim(from: 0, to: fill)
                .stroke(done ? ZenithStatus.success : context.tint.light.color,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 128, height: 128)
            context.icon.scaleEffect(done ? 0.96 : 1)
            Text(verbatim: "⌘Q")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.black.opacity(0.6)))
                .offset(y: 76)
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithQuitProtectionHeroArt {
    static var quitProtection: Self { .init() }
}

// MARK: - Workspaces

/// Workspaces: three coloured workspaces fan out behind the icon and gather again.
struct ZenithWorkspacesHeroArt: ZenithHeroAnimation {
    private static let colors: [Color] = [
        Color(red: 0.55, green: 0.45, blue: 0.98), Color(red: 0.2, green: 0.78, blue: 0.7),
        Color(red: 0.98, green: 0.6, blue: 0.3),
    ]

    func art(_ context: ZenithHeroArtContext) -> some View {
        let fan = ZenithKitEase.smooth(ZenithKitEase.pulse(context.t, period: 4))
        ZStack {
            ForEach(0..<3, id: \.self) { k in
                let side = Double(k) - 1
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Self.colors[k].opacity(0.9))
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(side * 18 * fan))
                    .offset(x: side * 52 * fan, y: -6 - 8 * fan * (1 - abs(side)))
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            }
            context.icon.offset(y: 18 * fan)
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithWorkspacesHeroArt {
    static var workspaces: Self { .init() }
}

// MARK: - Radial Menu

/// Radial Menu: actions sit in a ring around the icon, the choice sweeping round.
struct ZenithRadialMenuHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let chosen = Int(ZenithKitEase.phase(context.t, period: 4) * 6) % 6
        ZStack {
            Circle()
                .strokeBorder(context.tint.light.color.opacity(0.35), lineWidth: 22)
                .frame(width: 168, height: 168)
            ForEach(0..<6, id: \.self) { k in
                let a = Double(k) / 6 * 2 * .pi - .pi / 2
                Circle()
                    .fill(k == chosen ? Color.white : context.tint.light.color.opacity(0.8))
                    .frame(width: k == chosen ? 16 : 10, height: k == chosen ? 16 : 10)
                    .shadow(color: k == chosen ? context.tint.light.color : .clear, radius: 6)
                    .offset(x: 73 * cos(a), y: 73 * sin(a))
            }
            context.icon.scaleEffect(0.86)
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithRadialMenuHeroArt {
    static var radialMenu: Self { .init() }
}

// MARK: - Quick Launcher

/// Quick Launcher: a grid of tools around the icon, one lighting after another.
struct ZenithQuickLauncherHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let lit = Int(ZenithKitEase.phase(context.t, period: 4) * 8) % 8
        ZStack {
            ForEach(0..<8, id: \.self) { k in
                let a = Double(k) / 8 * 2 * .pi
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(k == lit ? context.tint.light.color : Color.primary.opacity(0.14))
                    .frame(width: 20, height: 20)
                    .scaleEffect(k == lit ? 1.25 : 1)
                    .shadow(color: k == lit ? context.tint.light.color : .clear, radius: 5)
                    .offset(x: 74 * cos(a), y: 62 * sin(a))
            }
            context.icon
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithQuickLauncherHeroArt {
    static var quickLauncher: Self { .init() }
}

// MARK: - Quick Toggles

/// Quick Toggles: a switch beside the icon flips, the sun turning to the moon.
struct ZenithQuickTogglesHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let p = ZenithKitEase.phase(context.t, period: 4)
        let on = ZenithKitEase.smooth((p - 0.2) / 0.1) * (1 - ZenithKitEase.smooth((p - 0.7) / 0.1))
        ZStack {
            context.icon.offset(y: -16)
            HStack(spacing: 10) {
                Image(systemName: on > 0.5 ? "moon.fill" : "sun.max.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(on > 0.5 ? Color(red: 0.7, green: 0.75, blue: 1) : Color(red: 1, green: 0.8, blue: 0.3))
                Capsule()
                    .fill(ZenithStatus.success.opacity(on))
                    .background(Capsule().fill(Color.primary.opacity(0.2)))
                    .frame(width: 44, height: 24)
                    .overlay(alignment: .leading) {
                        Circle().fill(.white).frame(width: 20, height: 20)
                            .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
                            .offset(x: 2 + 20 * on)
                    }
            }
            .offset(y: 62)
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithQuickTogglesHeroArt {
    static var quickToggles: Self { .init() }
}

// MARK: - Quit Apps

/// Quit Apps: the running apps under the icon go out one by one, then return.
struct ZenithQuitAppsHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let p = ZenithKitEase.phase(context.t, period: 4)
        ZStack {
            context.icon.offset(y: -18)
            HStack(spacing: 7) {
                ForEach(0..<5, id: \.self) { k in
                    let out = ZenithKitEase.smooth((p - 0.2 - Double(k) * 0.08) / 0.1)
                        * (1 - ZenithKitEase.smooth((p - 0.88) / 0.1))
                    let kept = k == 0
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(context.tint.light.color.opacity(kept ? 1 : 0.85))
                            .frame(width: 20, height: 20)
                        Circle().fill(Color.primary.opacity(0.7)).frame(width: 4, height: 4)
                    }
                    .opacity(kept ? 1 : 1 - 0.75 * out)
                    .scaleEffect(kept ? 1 : 1 - 0.2 * out)
                }
            }
            .offset(y: 62)
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithQuitAppsHeroArt {
    static var quitApps: Self { .init() }
}

// MARK: - Cleaning Mode

/// Cleaning Mode: a shine wipes across the icon while bubbles rise.
struct ZenithCleaningModeHeroArt: ZenithHeroAnimation {
    func art(_ context: ZenithHeroArtContext) -> some View {
        let t = context.t
        let sweep = ZenithKitEase.phase(t, period: 2)
        ZStack {
            ForEach(0..<6, id: \.self) { k in
                let p = ZenithKitEase.phase(t, period: 2, offset: Double(k) / 6)
                Circle()
                    .strokeBorder(Color.white.opacity(0.7 * sin(p * .pi)), lineWidth: 1.5)
                    .frame(width: 8 + CGFloat(k % 3) * 5)
                    .offset(x: CGFloat(k - 3) * 22 + 6 * sin(p * 4), y: 60 - 120 * p)
            }
            context.icon
                .overlay {
                    LinearGradient(colors: [.clear, .white.opacity(0.55), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: 26)
                        .rotationEffect(.degrees(20))
                        .offset(x: -70 + 140 * sweep)
                        .mask(RoundedRectangle(cornerRadius: 22, style: .continuous).frame(width: 88, height: 88))
                }
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithCleaningModeHeroArt {
    static var cleaningMode: Self { .init() }
}

// MARK: - Wallpaper

/// Wallpaper: the picture behind the icon changes, one gradient to the next.
struct ZenithWallpaperHeroArt: ZenithHeroAnimation {
    private static let pictures: [[Color]] = [
        [Color(red: 0.19, green: 0.18, blue: 0.5), Color(red: 0.66, green: 0.33, blue: 0.97)],
        [Color(red: 0.06, green: 0.46, blue: 0.43), Color(red: 0.6, green: 0.96, blue: 0.89)],
        [Color(red: 0.6, green: 0.2, blue: 0.07), Color(red: 0.99, green: 0.73, blue: 0.45)],
        [Color(red: 0.12, green: 0.23, blue: 0.54), Color(red: 0.38, green: 0.65, blue: 0.98)],
    ]

    func art(_ context: ZenithHeroArtContext) -> some View {
        let p = ZenithKitEase.phase(context.t, period: 8) * Double(Self.pictures.count)
        let index = Int(p) % Self.pictures.count
        let blend = ZenithKitEase.smooth((p - floor(p) - 0.75) / 0.25)
        ZStack {
            picture(index).frame(width: 150, height: 104)
            picture((index + 1) % Self.pictures.count).frame(width: 150, height: 104).opacity(blend)
            context.icon.scaleEffect(0.8)
        }
    }

    private func picture(_ index: Int) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(LinearGradient(colors: Self.pictures[index], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.35)))
            .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
    }
}

extension ZenithHeroAnimation where Self == ZenithWallpaperHeroArt {
    static var wallpaper: Self { .init() }
}

// MARK: - Scratchpad

/// Scratchpad: a note beside the icon fills in line by line, the caret blinking.
struct ZenithScratchpadHeroArt: ZenithHeroAnimation {
    private static let widths: [CGFloat] = [52, 40, 46]

    func art(_ context: ZenithHeroArtContext) -> some View {
        let p = ZenithKitEase.phase(context.t, period: 4)
        let typed = ZenithKitEase.smooth(p / 0.75) * 3
        let caret = ZenithKitEase.phase(context.t, period: 1) < 0.5
        ZStack {
            context.icon.offset(x: -28)
            VStack(alignment: .leading, spacing: 7) {
                ForEach(0..<3, id: \.self) { k in
                    let share = min(max(typed - Double(k), 0), 1)
                    HStack(spacing: 2) {
                        Capsule().fill(Color.black.opacity(0.45)).frame(width: Self.widths[k] * share, height: 4)
                        if Int(typed) == k || (k == 2 && typed >= 3) {
                            Rectangle().fill(Color.accentColor).frame(width: 1.5, height: 9).opacity(caret ? 1 : 0)
                        }
                    }
                    .frame(width: 60, alignment: .leading)
                }
            }
            .padding(10)
            .frame(width: 78, height: 70, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(red: 1, green: 0.95, blue: 0.7)))
            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            .rotationEffect(.degrees(4))
            .offset(x: 46, y: 26)
        }
    }
}

extension ZenithHeroAnimation where Self == ZenithScratchpadHeroArt {
    static var scratchpad: Self { .init() }
}
