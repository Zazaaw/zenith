// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Set A: Zenith, Island and Sound icons. Art on a 100×100 canvas over `OrbitIconBase`.

private func aRGB(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }

/// A soft top highlight laid over a shape.
private func aSheen(_ top: Double = 0.5) -> LinearGradient {
    LinearGradient(colors: [.white.opacity(top), .clear], startPoint: .top, endPoint: .center)
}

// MARK: - Zenith

struct AGearArt: View {
    var body: some View {
        let steel = AngularGradient(colors: [Color(white: 0.93), Color(white: 0.58), Color(white: 0.96), Color(white: 0.5),
                                             Color(white: 0.9), Color(white: 0.55), Color(white: 0.93)], center: .center)
        ZStack {
            Image(systemName: "gearshape.fill").font(.system(size: 66)).foregroundStyle(steel)
                .shadow(color: .black.opacity(0.5), radius: 3, y: 3)
            Image(systemName: "gearshape.fill").font(.system(size: 66)).foregroundStyle(aSheen(0.45))
            Circle().fill(steel).frame(width: 30, height: 30).rotationEffect(.degrees(30))
                .shadow(color: .black.opacity(0.35), radius: 1.5, y: 1)
            Circle().fill(RadialGradient(colors: [aRGB(0.55, 0.85, 1), aRGB(0.2, 0.45, 1), aRGB(0.12, 0.2, 0.7)],
                                         center: UnitPoint(x: 0.35, y: 0.3), startRadius: 1, endRadius: 14))
                .frame(width: 20, height: 20)
                .shadow(color: aRGB(0.3, 0.6, 1).opacity(0.8), radius: 4)
            Circle().fill(.white.opacity(0.75)).frame(width: 5, height: 5).offset(x: -3, y: -3).blur(radius: 0.6)
        }
    }
}

struct APaletteArt: View {
    var body: some View {
        ZStack {
            ZStack {
                Ellipse().fill(LinearGradient(colors: [aRGB(1, 0.94, 0.84), aRGB(0.95, 0.76, 0.55)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 72, height: 56)
                Ellipse().strokeBorder(aRGB(0.75, 0.5, 0.3).opacity(0.5), lineWidth: 1).frame(width: 72, height: 56)
                Circle().frame(width: 13, height: 13).offset(x: 16, y: 11).blendMode(.destinationOut)
            }
            .compositingGroup()
            .shadow(color: .black.opacity(0.45), radius: 3, y: 3)
            dab([aRGB(1, 0.45, 0.45), aRGB(0.85, 0.1, 0.2)], x: -22, y: 4)
            dab([aRGB(1, 0.85, 0.35), aRGB(1, 0.55, 0.05)], x: -15, y: -12)
            dab([aRGB(0.5, 0.95, 0.5), aRGB(0.1, 0.65, 0.3)], x: 2, y: -17)
            dab([aRGB(0.45, 0.75, 1), aRGB(0.15, 0.35, 0.95)], x: 18, y: -10)
            dab([aRGB(0.85, 0.55, 1), aRGB(0.55, 0.2, 0.9)], x: -6, y: 15)
        }
        .rotationEffect(.degrees(-12))
        .overlay(ABrush().rotationEffect(.degrees(40)).offset(x: 16, y: 10))
    }
    func dab(_ c: [Color], x: CGFloat, y: CGFloat) -> some View {
        Circle().fill(RadialGradient(colors: c, center: UnitPoint(x: 0.35, y: 0.3), startRadius: 1, endRadius: 8))
            .frame(width: 13, height: 13)
            .overlay(Circle().fill(.white.opacity(0.7)).frame(width: 3.5, height: 3.5).offset(x: -2.5, y: -2.5))
            .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
            .offset(x: x, y: y)
    }
}

/// A paintbrush pointing up, with a pink tip.
struct ABrush: View {
    var body: some View {
        VStack(spacing: 0) {
            ABrushTip().fill(LinearGradient(colors: [aRGB(1, 0.5, 0.7), aRGB(0.9, 0.2, 0.45)], startPoint: .top, endPoint: .bottom))
                .frame(width: 9, height: 13)
            Rectangle().fill(LinearGradient(colors: [Color(white: 0.6), Color(white: 0.98), Color(white: 0.6)], startPoint: .leading, endPoint: .trailing))
                .frame(width: 9, height: 8)
            UnevenRoundedRectangle(bottomLeadingRadius: 3.5, bottomTrailingRadius: 3.5)
                .fill(LinearGradient(colors: [aRGB(0.35, 0.2, 0.55), aRGB(0.6, 0.4, 0.85), aRGB(0.3, 0.15, 0.5)], startPoint: .leading, endPoint: .trailing))
                .frame(width: 7, height: 26)
        }
        .shadow(color: .black.opacity(0.45), radius: 2, y: 2)
    }
}

struct ABrushTip: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: 0))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY), control: CGPoint(x: r.maxX, y: r.height * 0.3))
        p.addLine(to: CGPoint(x: 0, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: 0), control: CGPoint(x: 0, y: r.height * 0.3))
        return p
    }
}

// MARK: - Island

/// A small black island pill with a rim that keeps it visible on dark.
struct AIsland: View {
    var width: CGFloat
    var height: CGFloat
    var body: some View {
        Capsule().fill(LinearGradient(colors: [Color(white: 0.16), Color(white: 0.02)], startPoint: .top, endPoint: .bottom))
            .overlay(Capsule().strokeBorder(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
            .frame(width: width, height: height)
            .shadow(color: .black.opacity(0.5), radius: 2.5, y: 2)
    }
}

struct AWaveBars: View {
    var heights: [CGFloat]
    var colors: [Color]
    var body: some View {
        HStack(spacing: 2) {
            ForEach(heights.indices, id: \.self) { i in
                Capsule().fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)).frame(width: 2.6, height: heights[i])
            }
        }
    }
}

/// The island as it hangs from the top edge of the screen: flat on top,
/// rounded below, with small fillets where it meets the edge.
struct ANotchShape: Shape {
    var radius: CGFloat = 10
    var fillet: CGFloat = 4
    func path(in r: CGRect) -> Path {
        var p = Path()
        let f = fillet, rad = min(radius, r.height)
        p.move(to: CGPoint(x: r.minX - f, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX + f, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + f), control: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - rad))
        p.addQuadCurve(to: CGPoint(x: r.maxX - rad, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + rad, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - rad), control: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + f))
        p.addQuadCurve(to: CGPoint(x: r.minX - f, y: r.minY), control: CGPoint(x: r.minX, y: r.minY))
        p.closeSubpath()
        return p
    }
}

struct ADynamicIslandArt: View {
    var body: some View {
        let screen = RoundedRectangle(cornerRadius: 13, style: .continuous)
        ZStack {
            RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color(white: 0.86)).frame(width: 80, height: 64)
            ZStack(alignment: .top) {
                Rectangle().fill(LinearGradient(colors: [aRGB(0.35, 0.85, 1), aRGB(0.3, 0.4, 1), aRGB(0.5, 0.25, 0.9)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle().fill(RadialGradient(colors: [aRGB(1, 0.75, 0.9).opacity(0.7), .clear], center: .center, startRadius: 0, endRadius: 22))
                    .frame(width: 44, height: 44).offset(x: 20, y: 30)
                // The menu bar, and the island opened from the notch with what is playing.
                Rectangle().fill(.white.opacity(0.75)).frame(height: 8)
                HStack(spacing: 3) {
                    ForEach(0..<3) { _ in Capsule().fill(aRGB(0.2, 0.25, 0.6).opacity(0.5)).frame(width: 5, height: 2.4) }
                    Spacer()
                    ForEach(0..<2) { _ in Circle().fill(aRGB(0.2, 0.25, 0.6).opacity(0.5)).frame(width: 3.2, height: 3.2) }
                }
                .padding(.horizontal, 6).frame(height: 8)
                ZStack {
                    ANotchShape(radius: 11).fill(LinearGradient(colors: [Color(white: 0.12), Color(white: 0.01)], startPoint: .top, endPoint: .bottom))
                    ANotchShape(radius: 11).stroke(LinearGradient(colors: [.clear, .white.opacity(0.3)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                            .fill(LinearGradient(colors: [aRGB(1, 0.7, 0.3), aRGB(1, 0.3, 0.5)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 13, height: 13)
                        Capsule().fill(.white.opacity(0.85)).frame(width: 12, height: 3)
                        Image(systemName: "play.fill").font(.system(size: 8, weight: .bold)).foregroundStyle(.white)
                    }
                    .padding(.top, 3)
                }
                .frame(width: 44, height: 24)
                .shadow(color: .black.opacity(0.5), radius: 3, y: 2)
                RoundedRectangle(cornerRadius: 13, style: .continuous).fill(aSheen(0.3))
            }
            .frame(width: 75, height: 59)
            .clipShape(screen)
        }
        .shadow(color: .black.opacity(0.45), radius: 3, y: 3)
    }
}

struct ALiveActivityArt: View {
    var body: some View {
        let green = [aRGB(0.55, 1, 0.55), aRGB(0.1, 0.78, 0.4)]
        ZStack {
            Capsule().strokeBorder(aRGB(0.2, 0.9, 0.45).opacity(0.25), lineWidth: 2).frame(width: 92, height: 52)
            Capsule().strokeBorder(aRGB(0.2, 0.9, 0.45).opacity(0.5), lineWidth: 2.5).frame(width: 82, height: 42)
            Capsule().fill(aRGB(0.2, 0.9, 0.45).opacity(0.45)).frame(width: 70, height: 30).blur(radius: 8)
            AIsland(width: 70, height: 30)
            ZStack {
                Circle().stroke(green[1].opacity(0.3), lineWidth: 3.5)
                Circle().trim(from: 0, to: 0.68).stroke(LinearGradient(colors: green, startPoint: .top, endPoint: .bottom), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 17, height: 17).offset(x: -22)
            .shadow(color: green[1].opacity(0.8), radius: 3)
            AWaveBars(heights: [6, 12, 16, 9, 13, 7], colors: green).offset(x: 14)
                .shadow(color: green[1].opacity(0.7), radius: 3)
        }
    }
}

struct AMediaArt: View {
    var body: some View {
        ZStack {
            // Record peeking out of the sleeve.
            ZStack {
                Circle().fill(RadialGradient(colors: [Color(white: 0.36), Color(white: 0.14)], center: .center, startRadius: 4, endRadius: 28))
                ForEach([22.0, 18, 14, 11], id: \.self) { r in Circle().stroke(.white.opacity(0.18), lineWidth: 0.8).frame(width: r * 2, height: r * 2) }
                Circle().fill(AngularGradient(colors: [.clear, .white.opacity(0.35), .clear, .clear, .white.opacity(0.25), .clear], center: .center))
                Circle().strokeBorder(LinearGradient(colors: [.white.opacity(0.6), .white.opacity(0.15)], startPoint: .top, endPoint: .bottom), lineWidth: 1.2)
                Circle().fill(LinearGradient(colors: [aRGB(1, 0.6, 0.8), aRGB(0.9, 0.2, 0.55)], startPoint: .top, endPoint: .bottom)).frame(width: 16, height: 16)
                Circle().fill(Color(white: 0.1)).frame(width: 3, height: 3)
            }
            .frame(width: 52, height: 52).offset(x: 14, y: -6)
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(LinearGradient(colors: [aRGB(1, 0.55, 0.45), aRGB(0.95, 0.25, 0.55), aRGB(0.55, 0.2, 0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 52, height: 52)
                .overlay(Circle().fill(RadialGradient(colors: [aRGB(1, 0.9, 0.55), aRGB(1, 0.6, 0.35).opacity(0)], center: .center, startRadius: 2, endRadius: 18)).frame(width: 36, height: 36).offset(x: -8, y: -8))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(.white.opacity(0.35), lineWidth: 1))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(aSheen(0.3)))
                .shadow(color: .black.opacity(0.45), radius: 3, y: 3)
                .offset(x: -8, y: -4)
            Circle().fill(LinearGradient(colors: [Color(white: 1), Color(white: 0.84)], startPoint: .top, endPoint: .bottom))
                .frame(width: 28, height: 28)
                .overlay(Image(systemName: "play.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(aRGB(0.9, 0.2, 0.5)).offset(x: 1.5))
                .shadow(color: .black.opacity(0.45), radius: 2.5, y: 2)
                .offset(x: 18, y: 20)
        }
    }
}

struct ALockArt: View {
    var body: some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: 35, y: 52))
                p.addLine(to: CGPoint(x: 35, y: 38))
                p.addArc(center: CGPoint(x: 50, y: 38), radius: 15, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                p.addLine(to: CGPoint(x: 65, y: 52))
            }
            .stroke(LinearGradient(colors: [Color(white: 0.55), Color(white: 0.97), Color(white: 0.6), Color(white: 0.85)], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round))
            .frame(width: 100, height: 100)
            .shadow(color: .black.opacity(0.4), radius: 2, y: 2)
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(LinearGradient(colors: [aRGB(1, 0.86, 0.45), aRGB(0.98, 0.65, 0.15), aRGB(0.8, 0.45, 0.05)], startPoint: .top, endPoint: .bottom))
                .frame(width: 56, height: 42)
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(LinearGradient(colors: [.white.opacity(0.7), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom), lineWidth: 1.2))
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(aSheen(0.35)).frame(width: 56, height: 42))
                .overlay(AKeyhole().fill(aRGB(0.4, 0.2, 0.02)).frame(width: 10, height: 17).shadow(color: .white.opacity(0.5), radius: 0, y: 1))
                .shadow(color: .black.opacity(0.5), radius: 3, y: 3)
                .offset(y: 13)
        }
    }
}

struct AKeyhole: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.addEllipse(in: CGRect(x: 0, y: 0, width: r.width, height: r.width))
        p.move(to: CGPoint(x: r.width * 0.3, y: r.width * 0.6))
        p.addLine(to: CGPoint(x: r.width * 0.7, y: r.width * 0.6))
        p.addLine(to: CGPoint(x: r.width * 0.82, y: r.height))
        p.addLine(to: CGPoint(x: r.width * 0.18, y: r.height))
        p.closeSubpath()
        return p
    }
}

struct ABellArt: View {
    var body: some View {
        ZStack {
            OrbitGlossy(symbol: "bell.fill", colors: [aRGB(1, 0.8, 0.35), aRGB(1, 0.45, 0.1)], size: 50)
                .rotationEffect(.degrees(-12))
            Circle().fill(LinearGradient(colors: [aRGB(1, 0.42, 0.38), aRGB(0.88, 0.1, 0.18)], startPoint: .top, endPoint: .bottom))
                .frame(width: 24, height: 24)
                .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1))
                .overlay(Text("3").font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(.white))
                .shadow(color: .black.opacity(0.45), radius: 2, y: 2)
                .offset(x: 20, y: -20)
        }
    }
}

struct ACalendarArt: View {
    var body: some View {
        ZStack {
            // A second page beneath for depth.
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(white: 0.72)).frame(width: 58, height: 60).offset(y: 9)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 1), Color(white: 0.87)], startPoint: .top, endPoint: .bottom))
                .frame(width: 62, height: 62).offset(y: 4)
            UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [aRGB(1, 0.45, 0.4), aRGB(0.88, 0.15, 0.2)], startPoint: .top, endPoint: .bottom))
                .frame(width: 62, height: 18)
                .overlay(UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12, style: .continuous).fill(aSheen(0.35)))
                .offset(y: -18)
            Text("JUL").font(.system(size: 10, weight: .heavy, design: .rounded)).tracking(1).foregroundStyle(.white).offset(y: -16)
            Text("17").font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(Color(white: 0.2)).offset(y: 13)
            HStack(spacing: 26) {
                ForEach(0..<2) { _ in
                    Capsule().fill(LinearGradient(colors: [Color(white: 0.6), Color(white: 0.98), Color(white: 0.55)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: 5, height: 14).shadow(color: .black.opacity(0.4), radius: 1, y: 1)
                }
            }.offset(y: -27)
        }
        .shadow(color: .black.opacity(0.45), radius: 3, y: 3)
    }
}

struct ACloud: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        var p = Path()
        p.addRoundedRect(in: CGRect(x: 0, y: h * 0.5, width: w, height: h * 0.5), cornerSize: CGSize(width: h * 0.25, height: h * 0.25))
        p.addEllipse(in: CGRect(x: w * 0.08, y: h * 0.3, width: w * 0.36, height: w * 0.36))
        p.addEllipse(in: CGRect(x: w * 0.3, y: 0, width: w * 0.48, height: w * 0.48))
        p.addEllipse(in: CGRect(x: w * 0.6, y: h * 0.32, width: w * 0.32, height: w * 0.32))
        return p
    }
}

struct AWeatherArt: View {
    var body: some View {
        ZStack {
            Circle().fill(aRGB(1, 0.75, 0.2).opacity(0.55)).frame(width: 46, height: 46).blur(radius: 9).offset(x: -12, y: -14)
            OrbitSphere(colors: [aRGB(1, 0.95, 0.5), aRGB(1, 0.72, 0.15), aRGB(0.95, 0.45, 0.05)]).frame(width: 42, height: 42).offset(x: -12, y: -14)
            ACloud().fill(LinearGradient(colors: [Color(white: 1), aRGB(0.8, 0.88, 0.98), aRGB(0.62, 0.74, 0.92)], startPoint: .top, endPoint: .bottom))
                .frame(width: 66, height: 40)
                .overlay(ACloud().fill(aSheen(0.6)).frame(width: 66, height: 40))
                .shadow(color: .black.opacity(0.4), radius: 3, y: 3)
                .offset(x: 7, y: 12)
        }
    }
}

struct ABubble: Shape {
    func path(in r: CGRect) -> Path {
        let body = CGRect(x: 0, y: 0, width: r.width, height: r.height * 0.8)
        var p = Path(roundedRect: body, cornerRadius: 15, style: .continuous)
        p.move(to: CGPoint(x: r.width * 0.2, y: body.maxY - 2))
        p.addLine(to: CGPoint(x: r.width * 0.14, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.width * 0.42, y: body.maxY - 2), control: CGPoint(x: r.width * 0.32, y: r.maxY - 4))
        p.closeSubpath()
        return p
    }
}

struct ALyricsArt: View {
    var body: some View {
        ZStack {
            ABubble().fill(LinearGradient(colors: [aRGB(0.5, 1, 0.85), aRGB(0.1, 0.75, 0.7), aRGB(0.05, 0.5, 0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 68, height: 58)
                .overlay(ABubble().fill(aSheen(0.4)).frame(width: 68, height: 58))
                .overlay(ABubble().stroke(.white.opacity(0.35), lineWidth: 1).frame(width: 68, height: 58))
                .shadow(color: .black.opacity(0.45), radius: 3, y: 3)
            Image(systemName: "music.note").font(.system(size: 24, weight: .bold)).foregroundStyle(.white)
                .shadow(color: aRGB(0.0, 0.3, 0.35).opacity(0.6), radius: 1.5, y: 1)
                .offset(x: -16, y: -6)
            VStack(alignment: .leading, spacing: 5) {
                Capsule().fill(.white).frame(width: 22, height: 3.6)
                Capsule().fill(.white.opacity(0.75)).frame(width: 15, height: 3.6)
                Capsule().fill(.white.opacity(0.55)).frame(width: 19, height: 3.6)
            }
            .frame(width: 24, alignment: .leading)
            .shadow(color: aRGB(0.0, 0.3, 0.35).opacity(0.5), radius: 1, y: 1)
            .offset(x: 10, y: -6)
        }
    }
}

struct AAgentArt: View {
    var body: some View {
        ZStack {
            Circle().fill(aRGB(0.6, 0.4, 1).opacity(0.5)).frame(width: 60, height: 60).blur(radius: 10).offset(y: 4)
            // Antenna.
            Capsule().fill(LinearGradient(colors: [aRGB(0.75, 0.65, 1), aRGB(0.35, 0.2, 0.75)], startPoint: .leading, endPoint: .trailing)).frame(width: 3, height: 12).offset(y: -30)
            Circle().fill(RadialGradient(colors: [.white, aRGB(0.5, 0.95, 1)], center: .center, startRadius: 0, endRadius: 4)).frame(width: 7, height: 7).offset(y: -36)
                .shadow(color: aRGB(0.4, 0.9, 1), radius: 4)
            OrbitSphere(colors: [aRGB(0.8, 0.65, 1), aRGB(0.5, 0.3, 0.98), aRGB(0.22, 0.1, 0.55)]).frame(width: 58, height: 58).offset(y: 4)
            Capsule().fill(LinearGradient(colors: [aRGB(0.06, 0.04, 0.2), aRGB(0.14, 0.08, 0.35)], startPoint: .top, endPoint: .bottom))
                .frame(width: 42, height: 22)
                .overlay(Capsule().strokeBorder(LinearGradient(colors: [.white.opacity(0.1), .white.opacity(0.45)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
                .offset(y: 7)
            HStack(spacing: 1.5) {
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .black))
                Capsule().frame(width: 9, height: 3).offset(y: 4)
            }
            .foregroundStyle(aRGB(0.45, 1, 0.95))
            .shadow(color: aRGB(0.3, 0.95, 1), radius: 3)
            .offset(x: -1, y: 7)
            Image(systemName: "sparkle").font(.system(size: 15, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [aRGB(0.55, 0.9, 1), aRGB(0.5, 0.3, 1)], startPoint: .top, endPoint: .bottom))
                .shadow(color: aRGB(0.55, 0.4, 1).opacity(0.9), radius: 3)
                .offset(x: 28, y: -22)
        }
    }
}

struct ANotesArt: View {
    var body: some View {
        ZStack {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(colors: [aRGB(1, 0.98, 0.85), aRGB(1, 0.88, 0.55)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 50, height: 62)
                UnevenRoundedRectangle(topLeadingRadius: 8, topTrailingRadius: 8, style: .continuous)
                    .fill(LinearGradient(colors: [aRGB(1, 0.8, 0.3), aRGB(0.95, 0.62, 0.15)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 50, height: 12).offset(y: -25)
                VStack(spacing: 7) {
                    ForEach(0..<4) { i in Capsule().fill(aRGB(0.75, 0.55, 0.25).opacity(0.45)).frame(width: i == 3 ? 20 : 34, height: 2) }
                }
                .frame(width: 34, alignment: .leading)
                .offset(y: 7)
                HStack(spacing: 6) {
                    ForEach(0..<5) { _ in
                        Capsule().fill(LinearGradient(colors: [Color(white: 0.6), Color(white: 0.98), Color(white: 0.55)], startPoint: .leading, endPoint: .trailing)).frame(width: 3.2, height: 10)
                    }
                }.offset(y: -30)
            }
            .rotationEffect(.degrees(-6))
            .shadow(color: .black.opacity(0.45), radius: 3, y: 3)
            .offset(x: -6)
            APencil().rotationEffect(.degrees(35)).offset(x: 18, y: 6)
        }
    }
}

/// A pencil pointing down.
struct APencil: View {
    var body: some View {
        VStack(spacing: 0) {
            UnevenRoundedRectangle(topLeadingRadius: 3, topTrailingRadius: 3)
                .fill(LinearGradient(colors: [aRGB(1, 0.6, 0.65), aRGB(0.9, 0.4, 0.5)], startPoint: .leading, endPoint: .trailing)).frame(width: 10, height: 6)
            Rectangle().fill(LinearGradient(colors: [Color(white: 0.6), Color(white: 0.98), Color(white: 0.6)], startPoint: .leading, endPoint: .trailing)).frame(width: 10, height: 5)
            Rectangle().fill(LinearGradient(colors: [aRGB(1, 0.62, 0.25), aRGB(1, 0.8, 0.4), aRGB(0.85, 0.42, 0.1)], startPoint: .leading, endPoint: .trailing)).frame(width: 10, height: 34)
            ZStack(alignment: .bottom) {
                APencilTip().fill(aRGB(0.98, 0.85, 0.65)).frame(width: 10, height: 11)
                APencilTip().fill(Color(white: 0.3)).frame(width: 3.6, height: 4)
            }
        }
        .shadow(color: .black.opacity(0.45), radius: 2, y: 2)
    }
}

struct APencilTip: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: .zero)
        p.addLine(to: CGPoint(x: r.maxX, y: 0))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

struct AWakaArt: View {
    var body: some View {
        let blue = [aRGB(0.45, 0.78, 1), aRGB(0.15, 0.38, 0.95)]
        ZStack {
            // Crown and side button.
            RoundedRectangle(cornerRadius: 2).fill(LinearGradient(colors: [Color(white: 0.6), Color(white: 0.97), Color(white: 0.6)], startPoint: .leading, endPoint: .trailing))
                .frame(width: 6, height: 9).offset(y: -33)
            RoundedRectangle(cornerRadius: 3).fill(LinearGradient(colors: blue, startPoint: .top, endPoint: .bottom))
                .frame(width: 16, height: 7).offset(y: -38)
            RoundedRectangle(cornerRadius: 2).fill(LinearGradient(colors: [Color(white: 0.6), Color(white: 0.97), Color(white: 0.6)], startPoint: .leading, endPoint: .trailing))
                .frame(width: 6, height: 8).offset(y: -32).rotationEffect(.degrees(45))
            Circle().fill(LinearGradient(colors: blue, startPoint: .top, endPoint: .bottom)).frame(width: 64, height: 64)
                .overlay(Circle().strokeBorder(.white.opacity(0.4), lineWidth: 1))
                .overlay(Circle().fill(aSheen(0.35)))
            Circle().fill(LinearGradient(colors: [Color(white: 1), Color(white: 0.86)], startPoint: .top, endPoint: .bottom)).frame(width: 50, height: 50)
            ForEach(0..<12) { i in
                Capsule().fill(Color(white: 0.45)).frame(width: 1.6, height: i % 3 == 0 ? 5 : 3)
                    .offset(y: -20).rotationEffect(.degrees(Double(i) * 30))
            }
            Circle().trim(from: 0, to: 0.32).stroke(LinearGradient(colors: [aRGB(0.3, 0.85, 1), aRGB(0.2, 0.45, 1)], startPoint: .top, endPoint: .bottom), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 34, height: 34).rotationEffect(.degrees(-90))
            Text("</>").font(.system(size: 13, weight: .heavy, design: .monospaced)).foregroundStyle(aRGB(0.12, 0.3, 0.8)).offset(y: 1)
        }
        .shadow(color: .black.opacity(0.45), radius: 3, y: 3)
        .offset(y: 4)
    }
}

struct AStar: Shape {
    func path(in r: CGRect) -> Path {
        let c = CGPoint(x: r.midX, y: r.midY + r.height * 0.04)
        let outer = min(r.width, r.height) / 2, inner = outer * 0.5
        var p = Path()
        for i in 0..<10 {
            let a = Double(i) * .pi / 5 - .pi / 2
            let rad = i.isMultiple(of: 2) ? outer : inner
            let pt = CGPoint(x: c.x + CGFloat(cos(a)) * rad, y: c.y + CGFloat(sin(a)) * rad)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

struct AMascotArt: View {
    var body: some View {
        let gold = LinearGradient(colors: [aRGB(1, 0.92, 0.45), aRGB(1, 0.72, 0.12), aRGB(0.95, 0.5, 0.05)], startPoint: .top, endPoint: .bottom)
        let brown = aRGB(0.35, 0.18, 0.02)
        ZStack {
            AStar().fill(aRGB(1, 0.75, 0.2).opacity(0.5)).frame(width: 70, height: 70).blur(radius: 8)
            ZStack {
                AStar().fill(gold)
                AStar().stroke(gold, style: StrokeStyle(lineWidth: 9, lineJoin: .round))
            }
            .frame(width: 66, height: 66)
            .compositingGroup()
            .shadow(color: .black.opacity(0.45), radius: 3, y: 3)
            AStar().fill(aSheen(0.45)).frame(width: 60, height: 60).offset(y: -1)
            HStack(spacing: 12) {
                ForEach(0..<2) { _ in
                    Capsule().fill(brown).frame(width: 8, height: 13)
                        .overlay(Circle().fill(.white).frame(width: 3.4, height: 3.4).offset(x: -1.2, y: -3))
                }
            }.offset(y: 2)
            HStack(spacing: 27) {
                ForEach(0..<2) { _ in Ellipse().fill(aRGB(1, 0.4, 0.4).opacity(0.55)).frame(width: 9, height: 5).blur(radius: 1) }
            }.offset(y: 11)
            Path { p in p.addArc(center: CGPoint(x: 50, y: 59), radius: 5, startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false) }
                .stroke(brown, style: StrokeStyle(lineWidth: 2.6, lineCap: .round)).frame(width: 100, height: 100)
        }
    }
}

// MARK: - Sound

struct AMixerArt: View {
    var body: some View {
        let level = [aRGB(1, 0.5, 0.8), aRGB(0.6, 0.3, 1)]
        ZStack {
            ForEach(0..<3) { i in
                let x: CGFloat = [-20, 0, 20][i]
                let knob: CGFloat = [-6, 14, -20][i]
                ZStack {
                    Capsule().fill(LinearGradient(colors: [aRGB(0.22, 0.17, 0.35), aRGB(0.32, 0.26, 0.48)], startPoint: .top, endPoint: .bottom))
                        .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.8))
                        .frame(width: 8, height: 66)
                    Capsule().fill(LinearGradient(colors: level, startPoint: .top, endPoint: .bottom))
                        .frame(width: 8, height: 33 - knob)
                        .offset(y: (33 + knob) / 2)
                        .shadow(color: level[1].opacity(0.8), radius: 4)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(LinearGradient(colors: [Color(white: 1), Color(white: 0.74)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 20, height: 12)
                        .overlay(Capsule().fill(Color(white: 0.45)).frame(width: 12, height: 1.6))
                        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(Color(white: 0.55).opacity(0.6), lineWidth: 0.6))
                        .shadow(color: .black.opacity(0.5), radius: 2, y: 2)
                        .offset(y: knob)
                }
                .offset(x: x)
            }
        }
    }
}

struct AMicMuteArt: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let gap = scheme == .dark ? Color(white: 0.14) : Color(white: 0.94)
        let red = [aRGB(1, 0.45, 0.42), aRGB(0.85, 0.1, 0.2)]
        ZStack {
            Circle().fill(red[1].opacity(scheme == .dark ? 0.35 : 0.12)).frame(width: 56, height: 56).blur(radius: 12)
            Capsule().fill(LinearGradient(colors: [Color(white: 0.92), Color(white: 0.5)], startPoint: .top, endPoint: .bottom))
                .overlay(Capsule().strokeBorder(Color(white: 0.35).opacity(0.5), lineWidth: 0.8))
                .frame(width: 24, height: 40).offset(y: -10)
                .overlay(VStack(spacing: 3.4) { ForEach(0..<5) { _ in Capsule().fill(.black.opacity(0.22)).frame(width: 14, height: 1.6) } }.offset(y: -14))
                .shadow(color: .black.opacity(0.45), radius: 2, y: 2)
            Path { p in p.addArc(center: CGPoint(x: 50, y: 42), radius: 19, startAngle: .degrees(10), endAngle: .degrees(170), clockwise: false) }
                .stroke(LinearGradient(colors: [Color(white: 0.8), Color(white: 0.48)], startPoint: .leading, endPoint: .trailing), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
                .frame(width: 100, height: 100)
            Capsule().fill(Color(white: 0.52)).frame(width: 4, height: 10).offset(y: 24)
            Capsule().fill(LinearGradient(colors: [Color(white: 0.8), Color(white: 0.45)], startPoint: .top, endPoint: .bottom)).frame(width: 22, height: 4.5).offset(y: 29)
                .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
            // The slash, cut out of the mic by a gap the colour of the base.
            slash.stroke(gap, style: StrokeStyle(lineWidth: 13, lineCap: .round))
            slash.stroke(LinearGradient(colors: red, startPoint: .top, endPoint: .bottom), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .shadow(color: red[1].opacity(0.7), radius: 3)
        }
        .frame(width: 100, height: 100)
    }
    var slash: Path { Path { p in p.move(to: CGPoint(x: 26, y: 22)); p.addLine(to: CGPoint(x: 74, y: 78)) } }
}

struct ASoundOutputArt: View {
    var body: some View {
        let wave = [aRGB(0.55, 0.85, 1), aRGB(0.25, 0.5, 1)]
        ZStack {
            // One speaker, playing.
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(LinearGradient(colors: [aRGB(0.45, 0.75, 1), aRGB(0.15, 0.32, 0.88)], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(.white.opacity(0.4), lineWidth: 1))
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(aSheen(0.3)))
                    .frame(width: 42, height: 62)
                driver(10).offset(y: -18)
                driver(27).offset(y: 8)
            }
            .shadow(color: .black.opacity(0.45), radius: 3, y: 3)
            .offset(x: -12, y: -4)
            ForEach(0..<2) { i in
                let r: CGFloat = 12 + CGFloat(i) * 9
                Path { p in p.addArc(center: CGPoint(x: 58, y: 38), radius: r, startAngle: .degrees(-40), endAngle: .degrees(40), clockwise: false) }
                    .stroke(LinearGradient(colors: wave, startPoint: .top, endPoint: .bottom), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .opacity(i == 0 ? 1 : 0.65)
            }
            .shadow(color: wave[1].opacity(0.6), radius: 3)
            // The switch to another output.
            BBadge(symbol: "arrow.left.arrow.right", colors: [aRGB(0.5, 1, 0.65), aRGB(0.1, 0.7, 0.4)], size: 32)
                .offset(x: 22, y: 22)
        }
    }
    func driver(_ d: CGFloat) -> some View {
        ZStack {
            Circle().fill(Color(white: 0.92)).frame(width: d + 4, height: d + 4)
            Circle().fill(RadialGradient(colors: [aRGB(0.35, 0.45, 0.75), aRGB(0.06, 0.1, 0.3)], center: UnitPoint(x: 0.4, y: 0.35), startRadius: 0, endRadius: d * 0.6)).frame(width: d, height: d)
            Circle().fill(aRGB(0.5, 0.65, 0.95)).frame(width: d * 0.3, height: d * 0.3)
        }
    }
}

// MARK: - Icons

enum OrbitIconsA {
    static let icons: [OrbitIcon] = [
        OrbitIcon(name: "General", group: "Zenith", compact: "gearshape.fill", tint: [Color(white: 0.85), Color(white: 0.5)], art: AnyView(AGearArt())),
        OrbitIcon(name: "Appearance", group: "Zenith", compact: "paintpalette.fill", tint: [aRGB(1, 0.6, 0.7), aRGB(0.6, 0.3, 0.95)], art: AnyView(APaletteArt())),
        OrbitIcon(name: "Dynamic Island", group: "Island", compact: "capsule.fill", tint: [aRGB(0.35, 0.85, 1), aRGB(0.45, 0.3, 0.95)], art: AnyView(ADynamicIslandArt())),
        OrbitIcon(name: "Live Activities", group: "Island", compact: "dot.radiowaves.left.and.right", tint: [aRGB(0.55, 1, 0.55), aRGB(0.1, 0.75, 0.4)], art: AnyView(ALiveActivityArt())),
        OrbitIcon(name: "Media", group: "Island", compact: "play.circle.fill", tint: [aRGB(1, 0.55, 0.6), aRGB(0.85, 0.2, 0.6)], art: AnyView(AMediaArt())),
        OrbitIcon(name: "Lock Screen", group: "Island", compact: "lock.fill", tint: [aRGB(1, 0.86, 0.45), aRGB(0.9, 0.55, 0.1)], art: AnyView(ALockArt())),
        OrbitIcon(name: "Notifications", group: "Island", compact: "bell.badge.fill", tint: [aRGB(1, 0.75, 0.3), aRGB(1, 0.4, 0.1)], art: AnyView(ABellArt())),
        OrbitIcon(name: "Calendar", group: "Island", compact: "calendar", tint: [aRGB(1, 0.45, 0.4), aRGB(0.85, 0.12, 0.2)], art: AnyView(ACalendarArt())),
        OrbitIcon(name: "Weather", group: "Island", compact: "cloud.sun.fill", tint: [aRGB(1, 0.8, 0.3), aRGB(0.35, 0.6, 1)], art: AnyView(AWeatherArt())),
        OrbitIcon(name: "Lyrics", group: "Island", compact: "quote.bubble.fill", tint: [aRGB(0.45, 1, 0.85), aRGB(0.05, 0.6, 0.65)], art: AnyView(ALyricsArt())),
        OrbitIcon(name: "Agents", group: "Island", compact: "sparkles", tint: [aRGB(0.8, 0.6, 1), aRGB(0.45, 0.25, 0.95)], art: AnyView(AAgentArt())),
        OrbitIcon(name: "Notes", group: "Island", compact: "note.text", tint: [aRGB(1, 0.88, 0.4), aRGB(0.95, 0.6, 0.15)], art: AnyView(ANotesArt())),
        OrbitIcon(name: "WakaTime", group: "Island", compact: "stopwatch.fill", tint: [aRGB(0.45, 0.78, 1), aRGB(0.15, 0.38, 0.95)], art: AnyView(AWakaArt())),
        OrbitIcon(name: "Mascot", group: "Island", compact: "star.fill", tint: [aRGB(1, 0.9, 0.4), aRGB(1, 0.6, 0.1)], art: AnyView(AMascotArt())),
        OrbitIcon(name: "Volume Mixer", group: "Sound", compact: "slider.vertical.3", tint: [aRGB(1, 0.5, 0.8), aRGB(0.6, 0.3, 1)], art: AnyView(AMixerArt())),
        OrbitIcon(name: "Mic Mute", group: "Sound", compact: "mic.slash.fill", tint: [aRGB(1, 0.45, 0.42), aRGB(0.85, 0.1, 0.2)], art: AnyView(AMicMuteArt())),
        OrbitIcon(name: "Sound Output", group: "Sound", compact: "hifispeaker.fill", tint: [aRGB(0.45, 0.78, 1), aRGB(0.15, 0.35, 0.9)], art: AnyView(ASoundOutputArt())),
    ]
}
