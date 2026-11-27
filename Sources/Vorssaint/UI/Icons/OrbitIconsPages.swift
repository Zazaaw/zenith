// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

// Set E: the Settings pages that had no illustration of their own, drawn on
// the shared 100×100 canvas, and the page names that reuse another icon's art.

private func eRGB(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }
private func eVert(_ colors: [Color]) -> LinearGradient { LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom) }
private func eDiag(_ colors: [Color]) -> LinearGradient { LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing) }
private let eSheen = LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0)], startPoint: .top, endPoint: .center)

// MARK: - Shared pieces

/// A tiny desktop: a wallpaper with hills, a menu bar strip and, when asked,
/// a window and a dock.
struct EDesktop: View {
    let sky: [Color]
    let land: [Color]
    let w: CGFloat
    let h: CGFloat
    var window: [Color]?
    var dock = false
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: max(3, w * 0.09), style: .continuous)
        ZStack(alignment: .top) {
            Rectangle().fill(eVert(sky))
            BHills().fill(eVert(land))
            Rectangle().fill(.white.opacity(0.85)).frame(height: max(2, h * 0.1))
            if let window {
                RoundedRectangle(cornerRadius: w * 0.04, style: .continuous).fill(eVert(window))
                    .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.9)).frame(height: h * 0.08) }
                    .clipShape(RoundedRectangle(cornerRadius: w * 0.04, style: .continuous))
                    .frame(width: w * 0.46, height: h * 0.46)
                    .shadow(color: .black.opacity(0.3), radius: 1.5, y: 1)
                    .offset(x: -w * 0.12, y: h * 0.22)
            }
            if dock {
                Capsule().fill(.white.opacity(0.6)).frame(width: w * 0.42, height: max(2.5, h * 0.09))
                    .frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, h * 0.06)
            }
            shape.fill(eSheen).blendMode(.plusLighter).opacity(0.6)
            shape.strokeBorder(.white.opacity(0.45), lineWidth: 1)
        }
        .frame(width: w, height: h)
        .clipShape(shape)
    }
}

// MARK: - Input

struct EPointerArt: View {
    var body: some View {
        let violet = [eRGB(0.88, 0.72, 1), eRGB(0.52, 0.3, 0.95)]
        let arrow = Path { p in
            p.move(to: cP(38, 20)); p.addLine(to: cP(38, 72)); p.addLine(to: cP(50, 61))
            p.addLine(to: cP(59, 80)); p.addLine(to: cP(68, 76)); p.addLine(to: cP(59, 57))
            p.addLine(to: cP(75, 57)); p.closeSubpath()
        }
        ZStack {
            // The halo that finds the pointer, and the trail it leaves.
            Circle().fill(RadialGradient(colors: [violet[1].opacity(0.55), violet[1].opacity(0)], center: .center, startRadius: 4, endRadius: 30))
                .frame(width: 60, height: 60).position(x: 44, y: 34)
            Circle().strokeBorder(violet[0].opacity(0.5), lineWidth: 2).frame(width: 40, height: 40).position(x: 40, y: 28)
            ForEach(0..<3) { i in
                let y = 46 + CGFloat(i) * 9
                Capsule().fill(LinearGradient(colors: [violet[0].opacity(0), violet[0]], startPoint: .leading, endPoint: .trailing))
                    .frame(width: [16, 22, 14][i], height: 3.5).position(x: 30 - CGFloat([16, 22, 14][i]) / 2, y: y)
            }
            arrow.stroke(.white, style: StrokeStyle(lineWidth: 7, lineJoin: .round)).cCanvas().cDrop(0.5)
            CSolid(path: arrow, colors: violet, diagonal: true, sheen: 0.5, rim: 0)
        }
        .cCanvas()
    }
}

struct EMouseButtonsArt: View {
    var body: some View {
        let body = cRound(30, 15, 40, 70, 20)
        let lit = [eRGB(1, 0.85, 0.4), eRGB(1, 0.55, 0.1)]
        ZStack {
            CSolid(path: body, colors: [eRGB(0.97, 0.96, 1), eRGB(0.7, 0.68, 0.9)], sheen: 0.5, rim: 0.8).cDrop()
            // The left button, pressed and lit.
            Path(CGRect(x: 30, y: 15, width: 19.4, height: 30)).fill(eVert(lit)).clipShape(body)
                .overlay(Path(CGRect(x: 30, y: 15, width: 19.4, height: 30)).fill(eSheen).clipShape(body))
                .shadow(color: lit[1].opacity(0.8), radius: 5)
            Path { p in p.move(to: cP(50, 15)); p.addLine(to: cP(50, 45)) }.stroke(eRGB(0.4, 0.3, 0.8).opacity(0.35), lineWidth: 1.2)
            Path { p in p.move(to: cP(30.5, 45)); p.addQuadCurve(to: cP(69.5, 45), control: cP(50, 49)) }.stroke(eRGB(0.4, 0.3, 0.8).opacity(0.25), lineWidth: 1.2)
            CSolid(path: cRound(47, 24, 6, 12, 3), colors: [eRGB(0.8, 0.7, 1), eRGB(0.45, 0.3, 0.95)])
            // Side buttons.
            ForEach(0..<2) { i in
                CSolid(path: cRound(25, 50 + CGFloat(i) * 12, 7, 10, 3.5), colors: [eRGB(0.82, 0.66, 1), eRGB(0.5, 0.3, 0.95)], sheen: 0.4)
            }
            // The click.
            ForEach(0..<3) { i in
                Capsule().fill(lit[0]).frame(width: 3, height: 8)
                    .offset(y: -11).rotationEffect(.degrees(-60 + Double(i) * 32)).position(x: 26, y: 18)
            }
            .shadow(color: lit[1].opacity(0.7), radius: 2)
        }
        .cCanvas()
    }
}

// MARK: - System

struct ESleepArt: View {
    var body: some View {
        let gold = [eRGB(1, 0.95, 0.65), eRGB(1, 0.7, 0.2)]
        ZStack {
            ForEach(0..<4) { i in
                Image(systemName: "sparkle").font(.system(size: [8, 6, 7, 5][i], weight: .bold)).foregroundStyle(eVert([eRGB(0.85, 0.82, 1), eRGB(0.55, 0.5, 1)]))
                    .position(x: [76, 66, 22, 30][i], y: [26, 16, 30, 76][i])
            }
            .shadow(color: eRGB(0.5, 0.5, 1).opacity(0.8), radius: 2.5)
            Image(systemName: "moon.fill").font(.system(size: 54, weight: .semibold)).foregroundStyle(eDiag(gold))
                .blur(radius: 10).opacity(0.6).position(x: 46, y: 46)
            Image(systemName: "moon.fill").font(.system(size: 54, weight: .semibold)).foregroundStyle(eDiag(gold))
                .overlay(Image(systemName: "moon.fill").font(.system(size: 54, weight: .semibold)).foregroundStyle(eSheen).blendMode(.plusLighter))
                .shadow(color: .black.opacity(0.4), radius: 2, y: 2).position(x: 46, y: 46)
            Text("z").font(.system(size: 13, weight: .heavy, design: .rounded)).foregroundStyle(eRGB(0.6, 0.55, 1)).position(x: 66, y: 34)
            Text("z").font(.system(size: 9, weight: .heavy, design: .rounded)).foregroundStyle(eRGB(0.6, 0.55, 1).opacity(0.8)).position(x: 74, y: 25)
            // Keep awake: the cup that holds sleep off.
            BBadge(symbol: "cup.and.saucer.fill", colors: [eRGB(1, 0.64, 0.44), eRGB(0.84, 0.26, 0.16)], size: 30).position(x: 70, y: 70)
        }
        .cCanvas()
    }
}

// MARK: - Windows

struct ESpacesArt: View {
    let skies: [[Color]] = [
        [eRGB(0.45, 0.7, 1), eRGB(0.7, 0.6, 1)],
        [eRGB(0.35, 0.5, 1), eRGB(0.95, 0.6, 0.85)],
        [eRGB(0.4, 0.85, 0.95), eRGB(0.5, 0.6, 1)],
    ]
    let lands: [[Color]] = [
        [eRGB(0.3, 0.45, 0.95), eRGB(0.2, 0.25, 0.7)],
        [eRGB(0.55, 0.35, 0.95), eRGB(0.3, 0.2, 0.7)],
        [eRGB(0.2, 0.6, 0.85), eRGB(0.1, 0.35, 0.65)],
    ]
    var body: some View {
        ZStack {
            // The spaces bar: three desktops, the second one current.
            HStack(spacing: 5) {
                ForEach(0..<3) { i in
                    EDesktop(sky: skies[i], land: lands[i], w: 23, h: 16)
                        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(.white, lineWidth: i == 1 ? 2 : 0).padding(-2))
                        .shadow(color: .black.opacity(0.4), radius: 2, y: 1.5)
                }
            }
            .offset(y: -24)
            // The current space, large.
            EDesktop(sky: skies[1], land: lands[1], w: 74, h: 46, window: [eRGB(0.98, 0.98, 1), eRGB(0.82, 0.84, 0.95)], dock: true)
                .shadow(color: .black.opacity(0.45), radius: 3, y: 2)
                .offset(y: 14)
        }
    }
}

// MARK: - Files

struct EFinderToolsArt: View {
    var body: some View {
        let blue = [eRGB(0.55, 0.85, 1), eRGB(0.2, 0.5, 0.95)]
        ZStack {
            Group {
                CSolid(path: cRound(16, 22, 30, 16, 5), colors: [eRGB(0.3, 0.6, 0.95), eRGB(0.15, 0.38, 0.85)], sheen: 0.3)
                CSolid(path: cRound(16, 28, 68, 48, 8), colors: [eRGB(0.3, 0.6, 0.95), eRGB(0.12, 0.32, 0.8)], sheen: 0.15)
                // A sheet peeking out of the folder.
                CSolid(path: cRound(24, 31, 50, 30, 4), colors: [.white, eRGB(0.88, 0.9, 0.96)], sheen: 0, rim: 0)
                CSolid(path: cRound(14, 38, 72, 44, 8), colors: blue, sheen: 0.45, rim: 0.6)
            }
            .cDrop()
            Path { p in p.move(to: cP(34, 52)); p.addLine(to: cP(66, 52)) }.stroke(eRGB(0.1, 0.3, 0.75).opacity(0.35), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            BBadge(symbol: "wrench.and.screwdriver.fill", colors: [eRGB(1, 0.8, 0.4), eRGB(0.95, 0.48, 0.12)], size: 32).position(x: 72, y: 72)
        }
        .cCanvas()
    }
}

// MARK: - Sound

struct EMusicBlockerArt: View {
    var body: some View {
        let pink = [eRGB(1, 0.6, 0.78), eRGB(0.86, 0.22, 0.5)]
        let red = [eRGB(1, 0.42, 0.38), eRGB(0.85, 0.08, 0.16)]
        ZStack {
            Image(systemName: "music.note").font(.system(size: 52, weight: .heavy)).foregroundStyle(eDiag(pink))
                .blur(radius: 9).opacity(0.5).position(x: 44, y: 44)
            Image(systemName: "music.note").font(.system(size: 52, weight: .heavy)).foregroundStyle(eDiag(pink))
                .overlay(Image(systemName: "music.note").font(.system(size: 52, weight: .heavy)).foregroundStyle(eSheen).blendMode(.plusLighter))
                .shadow(color: .black.opacity(0.4), radius: 2, y: 2).position(x: 44, y: 44)
            // The stop sign over it.
            ZStack {
                Circle().fill(.white.opacity(0.18))
                Circle().strokeBorder(eDiag(red), lineWidth: 6)
                Capsule().fill(eDiag(red)).frame(width: 6, height: 30).rotationEffect(.degrees(-45))
                Circle().strokeBorder(LinearGradient(colors: [.white.opacity(0.55), .clear], startPoint: .top, endPoint: .center), lineWidth: 1)
            }
            .frame(width: 36, height: 36)
            .shadow(color: .black.opacity(0.4), radius: 2.5, y: 2)
            .position(x: 68, y: 68)
        }
        .cCanvas()
    }
}

// MARK: - Productivity

struct EQuickLauncherArt: View {
    let apps: [[Color]] = [
        [eRGB(0.45, 0.85, 1), eRGB(0.15, 0.45, 1)],
        [eRGB(0.5, 1, 0.6), eRGB(0.1, 0.7, 0.35)],
        [eRGB(1, 0.55, 0.75), eRGB(0.85, 0.2, 0.5)],
    ]
    var body: some View {
        ZStack {
            // Apps springing out of the wand's tip.
            ForEach(0..<3) { i in
                CSolid(path: cRound([46, 62, 70][i], [14, 18, 34][i], 15, 15, 4.5), colors: apps[i], diagonal: true)
                    .rotationEffect(.degrees([-10, 8, 14][i]))
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1.5)
            }
            ForEach(0..<3) { i in
                Image(systemName: "sparkle").font(.system(size: [10, 7, 8][i], weight: .bold))
                    .foregroundStyle(eVert([eRGB(1, 0.95, 0.6), eRGB(1, 0.7, 0.2)]))
                    .position(x: [40, 58, 80][i], y: [36, 40, 56][i])
            }
            .shadow(color: eRGB(1, 0.75, 0.2).opacity(0.9), radius: 3)
            // The wand.
            ZStack {
                Capsule().fill(LinearGradient(colors: [eRGB(0.22, 0.2, 0.3), eRGB(0.45, 0.42, 0.58), eRGB(0.18, 0.16, 0.26)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 10, height: 52)
                Capsule().fill(LinearGradient(colors: [eRGB(1, 0.92, 0.6), eRGB(1, 0.65, 0.15), eRGB(0.9, 0.5, 0.05)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 10, height: 14).offset(y: -19)
                Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1).frame(width: 10, height: 52)
            }
            .rotationEffect(.degrees(45)).position(x: 32, y: 66)
            .shadow(color: .black.opacity(0.45), radius: 2.5, y: 2)
            Circle().fill(RadialGradient(colors: [.white, eRGB(1, 0.85, 0.4), eRGB(1, 0.6, 0.1).opacity(0)], center: .center, startRadius: 0, endRadius: 10))
                .frame(width: 20, height: 20).position(x: 47, y: 51)
        }
        .cCanvas()
    }
}

struct EQuickTogglesArt: View {
    var body: some View {
        let panel = cRound(16, 16, 68, 68, 16)
        ZStack {
            CSolid(path: panel, colors: [eRGB(1, 0.84, 0.5), eRGB(0.95, 0.5, 0.15)], diagonal: true, sheen: 0.35).cDrop()
            toggle(on: true).position(x: 50, y: 37)
            toggle(on: false).position(x: 50, y: 63)
        }
        .cCanvas()
    }
    func toggle(on: Bool) -> some View {
        ZStack(alignment: on ? .trailing : .leading) {
            Capsule().fill(on ? AnyShapeStyle(eVert([eRGB(0.5, 1, 0.6), eRGB(0.1, 0.72, 0.38)])) : AnyShapeStyle(Color.black.opacity(0.22)))
                .overlay(Capsule().strokeBorder(.white.opacity(on ? 0.5 : 0.25), lineWidth: 1))
            Circle().fill(eVert([.white, Color(white: 0.86)])).padding(2.5)
                .shadow(color: .black.opacity(0.35), radius: 1.5, y: 1)
        }
        .frame(width: 46, height: 22)
        .shadow(color: on ? eRGB(0.2, 0.9, 0.4).opacity(0.5) : .clear, radius: 4)
    }
}

struct EQuitAppsArt: View {
    var body: some View {
        ZStack {
            CSolid(path: cRound(30, 16, 46, 46, 12), colors: [eRGB(0.75, 0.85, 1), eRGB(0.45, 0.55, 0.95)], diagonal: true, sheen: 0.3)
                .opacity(0.7).rotationEffect(.degrees(10)).cDrop(0.3)
            CSolid(path: cRound(18, 26, 52, 52, 13), colors: [eRGB(1, 0.84, 0.5), eRGB(0.95, 0.5, 0.15)], diagonal: true).cDrop()
            HStack(spacing: 3) { ForEach(0..<3) { _ in Circle().fill(.white.opacity(0.7)).frame(width: 4, height: 4) } }.position(x: 34, y: 36)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(0..<3) { i in Capsule().fill(.white.opacity(0.6)).frame(width: [26, 18, 22][i], height: 3.5) }
            }
            .frame(width: 30, alignment: .leading).position(x: 42, y: 54)
            BBadge(symbol: "xmark", colors: [eRGB(1, 0.45, 0.42), eRGB(0.85, 0.1, 0.18)], size: 32).position(x: 70, y: 72)
        }
        .cCanvas()
    }
}

// MARK: - Media

struct EWallpaperArt: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        ZStack {
            ZStack(alignment: .top) {
                Rectangle().fill(eVert([eRGB(0.98, 0.62, 0.5), eRGB(0.85, 0.45, 0.85), eRGB(0.4, 0.35, 0.9)]))
                Circle().fill(RadialGradient(colors: [eRGB(1, 0.96, 0.7), eRGB(1, 0.75, 0.35), eRGB(1, 0.6, 0.3).opacity(0)], center: .center, startRadius: 2, endRadius: 16))
                    .frame(width: 32, height: 32).offset(x: 12, y: 16)
                BHills().fill(eVert([eRGB(0.55, 0.3, 0.85), eRGB(0.3, 0.15, 0.6)])).offset(y: 6)
                BHills().fill(eVert([eRGB(0.35, 0.2, 0.7), eRGB(0.15, 0.08, 0.4)])).scaleEffect(x: -1).offset(y: 16)
                Rectangle().fill(.white.opacity(0.85)).frame(height: 6)
                Capsule().fill(.white.opacity(0.55)).frame(width: 34, height: 6)
                    .frame(maxHeight: .infinity, alignment: .bottom).padding(.bottom, 5)
                shape.fill(eSheen).blendMode(.plusLighter).opacity(0.5)
                shape.strokeBorder(.white.opacity(0.45), lineWidth: 1)
            }
            .frame(width: 74, height: 56)
            .clipShape(shape)
            .shadow(color: .black.opacity(0.45), radius: 3, y: 2)
            .offset(y: -4)
            BBadge(symbol: "paintbrush.pointed.fill", colors: [eRGB(1, 0.7, 0.9), eRGB(0.7, 0.3, 1)], size: 30).offset(x: 26, y: 24)
        }
    }
}

// MARK: - Island

struct EDownloadsArt: View {
    var body: some View {
        let blue = [eRGB(0.5, 0.85, 1), eRGB(0.25, 0.4, 0.98)]
        ZStack {
            Circle().stroke(blue[1].opacity(0.22), lineWidth: 7).frame(width: 64, height: 64)
            Circle().trim(from: 0, to: 0.7).stroke(AngularGradient(colors: [blue[0], blue[1], blue[0]], center: .center), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .frame(width: 64, height: 64).rotationEffect(.degrees(-90))
                .shadow(color: blue[0].opacity(0.7), radius: 4)
            OrbitSphere(colors: [eRGB(0.6, 0.9, 1), eRGB(0.3, 0.5, 1), eRGB(0.25, 0.2, 0.75)]).frame(width: 44, height: 44)
            Image(systemName: "arrow.down").font(.system(size: 22, weight: .black)).foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
        }
    }
}

struct EWatchArt: View {
    var body: some View {
        let violet = [eRGB(0.85, 0.7, 1), eRGB(0.55, 0.35, 1)]
        ZStack {
            CSolid(path: cRound(12, 20, 76, 58, 11), colors: [eRGB(0.26, 0.24, 0.36), eRGB(0.09, 0.08, 0.14)], sheen: 0.12, rim: 0.4).cDrop()
            // Whatever is on screen, with one area being watched.
            ForEach(0..<3) { i in
                Capsule().fill(.white.opacity(0.16)).frame(width: [22, 16, 20][i], height: 3).position(x: 18 + CGFloat([22, 16, 20][i]) / 2, y: 30 + CGFloat(i) * 7)
            }
            RoundedRectangle(cornerRadius: 6, style: .continuous).fill(violet[1].opacity(0.22)).frame(width: 46, height: 34).position(x: 56, y: 54)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(eDiag(violet), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [5, 4]))
                .frame(width: 46, height: 34).position(x: 56, y: 54)
                .shadow(color: violet[1].opacity(0.8), radius: 3)
            ZStack {
                Image(systemName: "eye.fill").font(.system(size: 22, weight: .bold)).foregroundStyle(eVert([.white, violet[0]])).blur(radius: 5).opacity(0.7)
                Image(systemName: "eye.fill").font(.system(size: 22, weight: .bold)).foregroundStyle(eVert([.white, violet[0]]))
            }
            .position(x: 56, y: 54)
        }
        .cCanvas()
    }
}

// MARK: - The set

enum OrbitIconsE {
    private static let input = [eRGB(0.85, 0.65, 1), eRGB(0.5, 0.3, 0.95)]
    private static let productivity = [eRGB(1, 0.82, 0.45), eRGB(0.95, 0.5, 0.15)]

    static let icons: [OrbitIcon] = [
        OrbitIcon(name: "Pointer", group: "Input", compact: "cursorarrow.motionlines", tint: input, art: AnyView(EPointerArt())),
        OrbitIcon(name: "Mouse Buttons", group: "Input", compact: "computermouse.fill", tint: input, art: AnyView(EMouseButtonsArt())),
        OrbitIcon(name: "Sleep", group: "System", compact: "powersleep", tint: [eRGB(0.75, 0.72, 1), eRGB(0.38, 0.3, 0.9)], art: AnyView(ESleepArt())),
        OrbitIcon(name: "Spaces", group: "Windows", compact: "rectangle.3.group.fill", tint: [eRGB(0.55, 0.75, 1), eRGB(0.3, 0.35, 0.95)], art: AnyView(ESpacesArt())),
        OrbitIcon(name: "Finder Tools", group: "Files", compact: "folder.fill.badge.gearshape", tint: [eRGB(0.5, 0.85, 1), eRGB(0.15, 0.45, 0.95)], art: AnyView(EFinderToolsArt())),
        OrbitIcon(name: "Music Blocker", group: "Sound", compact: "music.note", tint: [eRGB(1, 0.55, 0.7), eRGB(0.85, 0.2, 0.45)], art: AnyView(EMusicBlockerArt())),
        OrbitIcon(name: "Quick Launcher", group: "Productivity", compact: "wand.and.rays", tint: productivity, art: AnyView(EQuickLauncherArt())),
        OrbitIcon(name: "Quick Toggles", group: "Productivity", compact: "switch.2", tint: productivity, art: AnyView(EQuickTogglesArt())),
        OrbitIcon(name: "Quit Apps", group: "Productivity", compact: "xmark.app.fill", tint: productivity, art: AnyView(EQuitAppsArt())),
        OrbitIcon(name: "Wallpaper", group: "Media", compact: "photo.on.rectangle.angled", tint: [eRGB(1, 0.6, 0.85), eRGB(0.65, 0.3, 1)], art: AnyView(EWallpaperArt())),
        OrbitIcon(name: "Downloads", group: "Island", compact: "arrow.down.circle.fill", tint: [eRGB(0.5, 0.85, 1), eRGB(0.25, 0.4, 0.98)], art: AnyView(EDownloadsArt())),
        OrbitIcon(name: "Watch", group: "Island", compact: "eye.fill", tint: [eRGB(0.85, 0.7, 1), eRGB(0.55, 0.35, 1)], art: AnyView(EWatchArt())),

        // Page names drawn with another icon's art.
        OrbitIcon(name: "Scrolling", group: "Input", compact: "arrow.up.arrow.down", tint: [cRGB(0.75, 0.68, 1), cRGB(0.42, 0.32, 0.95)], art: AnyView(CMouseArt())),
        OrbitIcon(name: "Screen Recording", group: "Capture", compact: "record.circle.fill", tint: [eRGB(1, 0.5, 0.45), eRGB(0.9, 0.12, 0.15)], art: AnyView(BRecorderArt())),
        OrbitIcon(name: "Dock", group: "Windows", compact: "dock.rectangle", tint: [eRGB(0.8, 0.6, 1), eRGB(0.5, 0.28, 0.92)], art: AnyView(BDockArt())),
        OrbitIcon(name: "Window Layout", group: "Windows", compact: "rectangle.split.2x1.fill", tint: [eRGB(0.5, 1, 0.6), eRGB(0.1, 0.72, 0.38)], art: AnyView(BSnapArt())),
        OrbitIcon(name: "Music", group: "Island", compact: "music.note", tint: [eRGB(1, 0.55, 0.6), eRGB(0.85, 0.2, 0.6)], art: AnyView(AMediaArt())),
        OrbitIcon(name: "Timer", group: "Island", compact: "timer", tint: [eRGB(0.6, 0.45, 1), eRGB(0.95, 0.35, 0.75)], art: AnyView(OrbitHourglassArt())),
    ]
}
