// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Orbit icon kit. Every icon is art drawn on a 100×100 canvas over `OrbitIconBase`.

// Every icon is drawn on a 100×100 canvas, then scaled.

/// The squircle every icon sits on: near-black in Dark Mode, porcelain in
/// Light Mode, with a rim that catches light along the top.
struct OrbitIconBase: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let dark = scheme == .dark
        RoundedRectangle(cornerRadius: 23, style: .continuous)
            .fill(LinearGradient(colors: dark ? [Color(white: 0.21), Color(white: 0.075)] : [Color(white: 1), Color(white: 0.88)],
                                 startPoint: .top, endPoint: .bottom))
            .overlay(
                RoundedRectangle(cornerRadius: 23, style: .continuous)
                    .strokeBorder(LinearGradient(colors: dark ? [.white.opacity(0.28), .white.opacity(0.04), .white.opacity(0.08)]
                                                              : [.white, .black.opacity(0.06), .black.opacity(0.12)],
                                                 startPoint: .top, endPoint: .bottom), lineWidth: 1.2)
            )
            .shadow(color: .black.opacity(dark ? 0.5 : 0.18), radius: 4, y: 2)
    }
}

/// An SF Symbol filled with a gradient, a top sheen and a soft glow.
struct OrbitGlossy: View {
    let symbol: String
    let colors: [Color]
    var size: CGFloat = 52
    var body: some View {
        let g = LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        ZStack {
            Image(systemName: symbol).font(.system(size: size, weight: .semibold)).foregroundStyle(g)
                .blur(radius: 10).opacity(0.55)
            Image(systemName: symbol).font(.system(size: size, weight: .semibold)).foregroundStyle(g)
                .shadow(color: .black.opacity(0.45), radius: 2, y: 2)
            Image(systemName: symbol).font(.system(size: size, weight: .semibold))
                .foregroundStyle(LinearGradient(colors: [.white.opacity(0.55), .clear], startPoint: .top, endPoint: .center))
                .blendMode(.plusLighter)
        }
    }
}

struct OrbitSphere: View {
    let colors: [Color]
    var body: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: colors, center: UnitPoint(x: 0.35, y: 0.3), startRadius: 2, endRadius: 46))
            Circle().fill(RadialGradient(colors: [.white.opacity(0.7), .clear], center: UnitPoint(x: 0.32, y: 0.24), startRadius: 0, endRadius: 14))
        }
        .shadow(color: .black.opacity(0.45), radius: 3, y: 3)
    }
}

// MARK: - Illustrations

struct OrbitVoiceArt: View {
    var body: some View {
        ZStack {
            HStack(spacing: 3.2) {
                ForEach(0..<13) { i in
                    let h: CGFloat = [10, 18, 28, 16, 36, 24, 0, 24, 36, 16, 28, 18, 10][i]
                    Capsule().fill(LinearGradient(colors: [Color(red: 0.75, green: 0.45, blue: 1), Color(red: 1, green: 0.35, blue: 0.6)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 3.6, height: h).opacity(i == 6 ? 0 : 0.9)
                }
            }
            Capsule().fill(LinearGradient(colors: [Color(white: 0.98), Color(white: 0.72)], startPoint: .top, endPoint: .bottom))
                .frame(width: 20, height: 36).offset(y: -6)
                .overlay(VStack(spacing: 3) { ForEach(0..<4) { _ in Capsule().fill(.black.opacity(0.15)).frame(width: 12, height: 1.6) } }.offset(y: -8))
                .shadow(color: .black.opacity(0.5), radius: 2, y: 2)
            Path { p in p.addArc(center: CGPoint(x: 50, y: 50), radius: 16, startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false) }
                .stroke(Color(white: 0.85), style: StrokeStyle(lineWidth: 3, lineCap: .round)).frame(width: 100, height: 100).offset(y: -2)
            Capsule().fill(Color(white: 0.85)).frame(width: 3, height: 8).offset(y: 18)
        }
    }
}

struct OrbitKeycapArt: View {
    let label: String
    let top: [Color]
    let side: Color
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(side).frame(width: 60, height: 58).offset(y: 6)
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(LinearGradient(colors: top, startPoint: .top, endPoint: .bottom))
                .frame(width: 54, height: 48).offset(y: -2)
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(.white.opacity(0.45), lineWidth: 1).frame(width: 54, height: 48).offset(y: -2))
            Text(label).font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(.black.opacity(0.62)).offset(y: -3)
        }
        .shadow(color: .black.opacity(0.5), radius: 3, y: 3)
    }
}

struct OrbitEmojiArt: View {
    var body: some View {
        ZStack {
            OrbitSphere(colors: [Color(red: 1, green: 0.9, blue: 0.4), Color(red: 1, green: 0.68, blue: 0.1), Color(red: 0.85, green: 0.45, blue: 0.05)]).frame(width: 62, height: 62)
            HStack(spacing: 14) { Capsule().frame(width: 6, height: 11); Capsule().frame(width: 6, height: 11) }.foregroundStyle(Color(red: 0.35, green: 0.18, blue: 0.02)).offset(y: -6)
            Path { p in p.addArc(center: CGPoint(x: 50, y: 52), radius: 14, startAngle: .degrees(25), endAngle: .degrees(155), clockwise: false) }
                .stroke(Color(red: 0.35, green: 0.18, blue: 0.02), style: StrokeStyle(lineWidth: 4, lineCap: .round)).frame(width: 100, height: 100)
        }
    }
}

struct OrbitPlanetArt: View {
    var body: some View {
        ZStack {
            Ellipse().stroke(LinearGradient(colors: [Color(red: 0.6, green: 0.85, blue: 1), Color(red: 0.75, green: 0.5, blue: 1)], startPoint: .leading, endPoint: .trailing), lineWidth: 4)
                .frame(width: 84, height: 26).rotationEffect(.degrees(-18)).opacity(0.55)
            OrbitSphere(colors: [Color(red: 0.55, green: 0.8, blue: 1), Color(red: 0.25, green: 0.4, blue: 0.95), Color(red: 0.35, green: 0.15, blue: 0.6)]).frame(width: 50, height: 50)
            Ellipse().trim(from: 0.5, to: 1).stroke(LinearGradient(colors: [Color(red: 0.6, green: 0.85, blue: 1), Color(red: 0.75, green: 0.5, blue: 1)], startPoint: .leading, endPoint: .trailing), lineWidth: 4)
                .frame(width: 84, height: 26).rotationEffect(.degrees(-18)).rotationEffect(.degrees(180))
            Image(systemName: "sparkle").font(.system(size: 14, weight: .bold)).foregroundStyle(LinearGradient(colors: [Color(red: 1, green: 0.95, blue: 0.6), Color(red: 1, green: 0.7, blue: 0.2)], startPoint: .top, endPoint: .bottom)).offset(x: 30, y: -30).shadow(color: Color(red: 1, green: 0.75, blue: 0.2).opacity(0.8), radius: 4)
        }
    }
}

struct OrbitRingsArt: View {
    var body: some View {
        ZStack {
            ring(36, 0.78, [Color(red: 0.2, green: 0.9, blue: 0.45), Color(red: 0.6, green: 1, blue: 0.4)])
            ring(25, 0.52, [Color(red: 1, green: 0.8, blue: 0.2), Color(red: 1, green: 0.55, blue: 0.1)])
            ring(14, 0.2, [Color(red: 1, green: 0.3, blue: 0.3), Color(red: 1, green: 0.5, blue: 0.5)])
        }
    }
    func ring(_ r: CGFloat, _ v: CGFloat, _ c: [Color]) -> some View {
        ZStack {
            Circle().stroke(c[0].opacity(0.18), lineWidth: 8)
            Circle().trim(from: 0, to: v).stroke(AngularGradient(colors: c, center: .center), style: StrokeStyle(lineWidth: 8, lineCap: .round)).rotationEffect(.degrees(-90))
                .shadow(color: c[0].opacity(0.6), radius: 4)
        }.frame(width: r * 2, height: r * 2)
    }
}

struct OrbitShelfArt: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5).fill(LinearGradient(colors: [.white, Color(white: 0.8)], startPoint: .top, endPoint: .bottom))
                .frame(width: 30, height: 38).rotationEffect(.degrees(-12)).offset(x: -10, y: -14)
                .overlay(VStack(spacing: 4) { ForEach(0..<3) { _ in Capsule().fill(Color.black.opacity(0.18)).frame(width: 16, height: 2) } }.rotationEffect(.degrees(-12)).offset(x: -10, y: -16))
            RoundedRectangle(cornerRadius: 5).fill(LinearGradient(colors: [Color(red: 1, green: 0.7, blue: 0.3), Color(red: 1, green: 0.45, blue: 0.2)], startPoint: .top, endPoint: .bottom))
                .frame(width: 30, height: 38).rotationEffect(.degrees(10)).offset(x: 12, y: -12)
                .overlay(Image(systemName: "photo").font(.system(size: 13, weight: .bold)).foregroundStyle(.white.opacity(0.9)).rotationEffect(.degrees(10)).offset(x: 12, y: -12))
            OrbitTrayShape().fill(LinearGradient(colors: [Color(red: 0.35, green: 0.65, blue: 1), Color(red: 0.12, green: 0.35, blue: 0.9)], startPoint: .top, endPoint: .bottom))
                .frame(width: 70, height: 34).offset(y: 16)
                .overlay(OrbitTrayShape().stroke(.white.opacity(0.35), lineWidth: 1).frame(width: 70, height: 34).offset(y: 16))
                .shadow(color: .black.opacity(0.5), radius: 3, y: 2)
        }
    }
}

struct OrbitTrayShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: w * 0.3, y: 0))
        p.addQuadCurve(to: CGPoint(x: w * 0.7, y: 0), control: CGPoint(x: w * 0.5, y: h * 0.55))
        p.addLine(to: CGPoint(x: w, y: 0))
        p.addLine(to: CGPoint(x: w, y: h - 8))
        p.addQuadCurve(to: CGPoint(x: w - 8, y: h), control: CGPoint(x: w, y: h))
        p.addLine(to: CGPoint(x: 8, y: h))
        p.addQuadCurve(to: CGPoint(x: 0, y: h - 8), control: CGPoint(x: 0, y: h))
        p.closeSubpath()
        return p
    }
}

struct OrbitPocketArt: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Color(white: 0.85)).frame(width: 40, height: 70)
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.2, green: 0.85, blue: 0.75), Color(red: 0.1, green: 0.35, blue: 0.7)], startPoint: .top, endPoint: .bottom))
                .frame(width: 35, height: 65)
            Capsule().fill(.black).frame(width: 12, height: 4).offset(y: -27)
            Image(systemName: "sparkle").font(.system(size: 20, weight: .bold)).foregroundStyle(.white).shadow(color: .white.opacity(0.8), radius: 5)
        }
        .shadow(color: .black.opacity(0.5), radius: 3, y: 3)
    }
}

struct OrbitHourglassArt: View {
    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [Color(white: 0.97), Color(white: 0.78)], startPoint: .top, endPoint: .bottom)).frame(width: 64, height: 64)
                .shadow(color: .black.opacity(0.5), radius: 3, y: 3)
            Circle().trim(from: 0, to: 0.35).fill(Color(red: 1, green: 0.4, blue: 0.3))
                .frame(width: 52, height: 52).rotationEffect(.degrees(-90)).opacity(0)
            Path { p in p.move(to: CGPoint(x: 50, y: 50)); p.addArc(center: CGPoint(x: 50, y: 50), radius: 26, startAngle: .degrees(-90), endAngle: .degrees(40), clockwise: false); p.closeSubpath() }
                .fill(LinearGradient(colors: [Color(red: 0.55, green: 0.4, blue: 1), Color(red: 0.95, green: 0.35, blue: 0.75)], startPoint: .top, endPoint: .bottom)).frame(width: 100, height: 100)
            Circle().fill(Color(white: 0.2)).frame(width: 7, height: 7)
        }
    }
}

struct OrbitLaptopArt: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5).fill(Color(white: 0.82)).frame(width: 64, height: 44).offset(y: -6)
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(colors: [Color(red: 0.4, green: 0.35, blue: 1), Color(red: 1, green: 0.45, blue: 0.55)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 58, height: 38).offset(y: -6)
            Capsule().fill(.black).frame(width: 12, height: 3).offset(y: -24)
            RoundedRectangle(cornerRadius: 3).fill(LinearGradient(colors: [Color(white: 0.9), Color(white: 0.6)], startPoint: .top, endPoint: .bottom))
                .frame(width: 80, height: 7).offset(y: 19)
            Path { p in p.addArc(center: CGPoint(x: 50, y: 50), radius: 30, startAngle: .degrees(-150), endAngle: .degrees(-30), clockwise: false) }
                .stroke(.white.opacity(0.7), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [2, 5])).frame(width: 100, height: 100).offset(y: 10).opacity(0)
        }
        .shadow(color: .black.opacity(0.5), radius: 3, y: 3)
    }
}

struct OrbitFanArt: View {
    var body: some View {
        ZStack {
            ForEach(0..<3) { i in
                Ellipse().fill(LinearGradient(colors: [Color(red: 0.5, green: 0.95, blue: 1), Color(red: 0.1, green: 0.55, blue: 0.95)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 24, height: 40).offset(y: -18).rotationEffect(.degrees(Double(i) * 120 + 15))
            }
            Circle().fill(Color(white: 0.92)).frame(width: 14, height: 14)
        }
        .shadow(color: Color.cyan.opacity(0.45), radius: 8)
    }
}


/// One icon: the rich art for the store and page headers, and a compact
/// symbol for the 22 pt sidebar.
struct OrbitIcon {
    let name: String
    let group: String
    let compact: String
    let tint: [Color]
    let art: AnyView
}

/// The full icon at 100×100.
struct OrbitIconView: View {
    let icon: OrbitIcon
    var body: some View { ZStack { OrbitIconBase(); icon.art }.frame(width: 100, height: 100) }
}

/// The sidebar icon at 100×100: same base, one bold gradient symbol.
struct OrbitCompactIconView: View {
    let icon: OrbitIcon
    var body: some View {
        ZStack {
            OrbitIconBase()
            Image(systemName: icon.compact).font(.system(size: 54, weight: .bold))
                .foregroundStyle(LinearGradient(colors: icon.tint, startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: .black.opacity(0.35), radius: 2, y: 2)
        }
        .frame(width: 100, height: 100)
    }
}

/// The seed icons from the approved draft (4-icons.png).
enum OrbitSeedIcons {
    static let icons: [OrbitIcon] = [
        OrbitIcon(name: "Orbit", group: "Zenith", compact: "circle.hexagongrid.fill", tint: [Color(red: 0.55, green: 0.8, blue: 1), Color(red: 0.35, green: 0.3, blue: 0.95)], art: AnyView(OrbitPlanetArt())),
        OrbitIcon(name: "Voice Transcribe", group: "AI", compact: "waveform", tint: [Color(red: 0.75, green: 0.45, blue: 1), Color(red: 1, green: 0.35, blue: 0.6)], art: AnyView(OrbitVoiceArt())),
        OrbitIcon(name: "Mechakey", group: "Input", compact: "keyboard.fill", tint: [Color(red: 1, green: 0.88, blue: 0.4), Color(red: 1, green: 0.62, blue: 0.1)],
                  art: AnyView(OrbitKeycapArt(label: "Z", top: [Color(red: 1, green: 0.92, blue: 0.55), Color(red: 1, green: 0.78, blue: 0.2)], side: Color(red: 0.7, green: 0.45, blue: 0.05)))),
        OrbitIcon(name: "Command Bar", group: "Zenith", compact: "command", tint: [Color(white: 0.95), Color(white: 0.65)],
                  art: AnyView(OrbitKeycapArt(label: "⌘", top: [Color(white: 0.98), Color(white: 0.82)], side: Color(white: 0.5)))),
        OrbitIcon(name: "LocalSend", group: "Files", compact: "paperplane.fill", tint: [Color(red: 0.45, green: 0.85, blue: 1), Color(red: 0.15, green: 0.4, blue: 1)],
                  art: AnyView(OrbitGlossy(symbol: "paperplane.fill", colors: [Color(red: 0.45, green: 0.85, blue: 1), Color(red: 0.15, green: 0.4, blue: 1)]))),
        OrbitIcon(name: "Meetings", group: "Productivity", compact: "video.fill", tint: [Color(red: 0.45, green: 1, blue: 0.55), Color(red: 0.1, green: 0.7, blue: 0.35)],
                  art: AnyView(OrbitGlossy(symbol: "video.fill", colors: [Color(red: 0.45, green: 1, blue: 0.55), Color(red: 0.1, green: 0.7, blue: 0.35)], size: 46))),
        OrbitIcon(name: "Emoji Picker", group: "Productivity", compact: "face.smiling.inverse", tint: [Color(red: 1, green: 0.85, blue: 0.3), Color(red: 1, green: 0.55, blue: 0.1)], art: AnyView(OrbitEmojiArt())),
        OrbitIcon(name: "Batteries", group: "Devices", compact: "battery.75percent", tint: [Color(red: 0.4, green: 1, blue: 0.5), Color(red: 0.1, green: 0.75, blue: 0.35)], art: AnyView(OrbitRingsArt())),
        OrbitIcon(name: "Shelf", group: "Everyday", compact: "tray.full.fill", tint: [Color(red: 0.35, green: 0.65, blue: 1), Color(red: 0.12, green: 0.35, blue: 0.9)], art: AnyView(OrbitShelfArt())),
        OrbitIcon(name: "Pocket", group: "Devices", compact: "iphone", tint: [Color(red: 0.2, green: 0.9, blue: 0.75), Color(red: 0.1, green: 0.4, blue: 0.75)], art: AnyView(OrbitPocketArt())),
        OrbitIcon(name: "Focus Timer", group: "Island", compact: "timer", tint: [Color(red: 0.6, green: 0.45, blue: 1), Color(red: 0.95, green: 0.35, blue: 0.75)], art: AnyView(OrbitHourglassArt())),
        OrbitIcon(name: "Lid Fold", group: "System", compact: "laptopcomputer", tint: [Color(red: 0.5, green: 0.45, blue: 1), Color(red: 1, green: 0.45, blue: 0.55)], art: AnyView(OrbitLaptopArt())),
        OrbitIcon(name: "Fan Control", group: "System", compact: "fan.fill", tint: [Color(red: 0.5, green: 0.95, blue: 1), Color(red: 0.1, green: 0.55, blue: 0.95)], art: AnyView(OrbitFanArt())),
        OrbitIcon(name: "Clipboard", group: "Everyday", compact: "list.clipboard.fill", tint: [Color(red: 1, green: 0.85, blue: 0.5), Color(red: 0.95, green: 0.55, blue: 0.2)],
                  art: AnyView(OrbitGlossy(symbol: "list.clipboard.fill", colors: [Color(red: 1, green: 0.85, blue: 0.5), Color(red: 0.95, green: 0.55, blue: 0.2)], size: 48))),
        OrbitIcon(name: "Breather", group: "Productivity", compact: "drop.fill", tint: [Color(red: 0.55, green: 1, blue: 0.95), Color(red: 0.1, green: 0.6, blue: 0.75)],
                  art: AnyView(OrbitGlossy(symbol: "drop.fill", colors: [Color(red: 0.55, green: 1, blue: 0.95), Color(red: 0.1, green: 0.6, blue: 0.75)], size: 50))),
        OrbitIcon(name: "Face Unlock", group: "Devices", compact: "faceid", tint: [Color(red: 0.55, green: 0.85, blue: 1), Color(red: 0.4, green: 0.35, blue: 1)],
                  art: AnyView(OrbitGlossy(symbol: "faceid", colors: [Color(red: 0.55, green: 0.85, blue: 1), Color(red: 0.4, green: 0.35, blue: 1)], size: 50))),
    ]
}
