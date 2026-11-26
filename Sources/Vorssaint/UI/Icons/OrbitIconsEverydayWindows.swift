// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

// Set B: Everyday, Capture and Windows icons. Drawn on the 100×100 canvas over `OrbitIconBase`.

fileprivate func c(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }
fileprivate func vgrad(_ colors: [Color]) -> LinearGradient { LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom) }
fileprivate func dgrad(_ colors: [Color]) -> LinearGradient { LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing) }
fileprivate let sheen = LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0)], startPoint: .top, endPoint: .center)

// MARK: - Shared pieces

/// A rounded card with a gradient fill, a top sheen, a light rim and a drop shadow.
struct BCard<Content: View>: View {
    let colors: [Color]
    let w: CGFloat
    let h: CGFloat
    var r: CGFloat = 7
    @ViewBuilder var content: Content
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: r, style: .continuous)
        ZStack {
            shape.fill(vgrad(colors))
            content
            shape.fill(sheen).blendMode(.plusLighter).opacity(0.7)
            shape.strokeBorder(.white.opacity(0.4), lineWidth: 1)
        }
        .frame(width: w, height: h)
        .clipShape(shape)
        .shadow(color: .black.opacity(0.45), radius: 3, y: 2)
    }
}

/// A window: light title bar with traffic lights, gradient body.
struct BWindow<Content: View>: View {
    let colors: [Color]
    let w: CGFloat
    let h: CGFloat
    @ViewBuilder var content: Content
    var body: some View {
        let bar: CGFloat = max(8, h * 0.2)
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
        ZStack(alignment: .top) {
            shape.fill(vgrad(colors))
            content.frame(width: w, height: h - bar).offset(y: bar)
            Rectangle().fill(vgrad([Color(white: 0.98), Color(white: 0.86)])).frame(height: bar)
                .overlay(alignment: .leading) {
                    HStack(spacing: bar * 0.22) {
                        Circle().fill(c(1, 0.37, 0.34))
                        Circle().fill(c(1, 0.75, 0.2))
                        Circle().fill(c(0.2, 0.8, 0.3))
                    }
                    .frame(height: bar * 0.42).padding(.leading, bar * 0.45)
                }
            shape.fill(sheen).blendMode(.plusLighter).opacity(0.5)
            shape.strokeBorder(.white.opacity(0.4), lineWidth: 1)
        }
        .frame(width: w, height: h)
        .clipShape(shape)
        .shadow(color: .black.opacity(0.45), radius: 3, y: 2)
    }
}

/// Four L-shaped viewfinder corners.
struct BCorners: Shape {
    var len: CGFloat = 14
    func path(in r: CGRect) -> Path {
        var p = Path()
        let l = len
        p.move(to: CGPoint(x: r.minX, y: r.minY + l)); p.addLine(to: CGPoint(x: r.minX, y: r.minY)); p.addLine(to: CGPoint(x: r.minX + l, y: r.minY))
        p.move(to: CGPoint(x: r.maxX - l, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY + l))
        p.move(to: CGPoint(x: r.maxX, y: r.maxY - l)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.addLine(to: CGPoint(x: r.maxX - l, y: r.maxY))
        p.move(to: CGPoint(x: r.minX + l, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY - l))
        return p
    }
}

struct BViewfinder: View {
    let colors: [Color]
    let w: CGFloat
    let h: CGFloat
    var len: CGFloat = 14
    var body: some View {
        let style = StrokeStyle(lineWidth: 5.5, lineCap: .round, lineJoin: .round)
        ZStack {
            BCorners(len: len).stroke(dgrad(colors), style: style).blur(radius: 5).opacity(0.6)
            BCorners(len: len).stroke(dgrad(colors), style: style).shadow(color: .black.opacity(0.4), radius: 1.5, y: 1.5)
        }
        .frame(width: w, height: h)
    }
}

/// Rolling hills for little landscape scenes.
struct BHills: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        p.move(to: CGPoint(x: 0, y: h * 0.72))
        p.addQuadCurve(to: CGPoint(x: w * 0.45, y: h * 0.62), control: CGPoint(x: w * 0.22, y: h * 0.4))
        p.addQuadCurve(to: CGPoint(x: w, y: h * 0.55), control: CGPoint(x: w * 0.75, y: h * 0.82))
        p.addLine(to: CGPoint(x: w, y: h)); p.addLine(to: CGPoint(x: 0, y: h)); p.closeSubpath()
        return p
    }
}

/// A round badge holding a symbol.
struct BBadge: View {
    let symbol: String
    let colors: [Color]
    var size: CGFloat = 26
    var body: some View {
        ZStack {
            Circle().fill(dgrad(colors))
            Circle().fill(sheen).blendMode(.plusLighter)
            Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1)
            Image(systemName: symbol).font(.system(size: size * 0.46, weight: .heavy)).foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.45), radius: 2.5, y: 2)
    }
}

// MARK: - Everyday

struct BMediaArt: View {
    var body: some View {
        ZStack {
            BCard(colors: [c(0.62, 0.55, 1), c(0.38, 0.25, 0.9)], w: 46, h: 38) {
                ZStack {
                    Circle().fill(c(1, 0.85, 0.45)).frame(width: 9, height: 9).offset(x: 9, y: -7)
                    BHills().fill(vgrad([c(0.85, 0.6, 1), c(0.55, 0.3, 0.85)]))
                }
            }
            .rotationEffect(.degrees(-10)).offset(x: -9, y: -11)
            BCard(colors: [c(1, 0.45, 0.75), c(0.85, 0.15, 0.55)], w: 46, h: 38) {
                ZStack {
                    Circle().fill(.white.opacity(0.25)).frame(width: 20, height: 20)
                    Image(systemName: "play.fill").font(.system(size: 11, weight: .black)).foregroundStyle(.white).offset(x: 1)
                }
            }
            .rotationEffect(.degrees(8)).offset(x: 10, y: 8)
            BBadge(symbol: "arrow.triangle.2.circlepath", colors: [c(1, 0.6, 0.9), c(0.7, 0.2, 0.85)], size: 26)
                .offset(x: -20, y: 20)
        }
    }
}

struct BNoteShape: Shape {
    var fold: CGFloat = 13
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX + 4, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - 4, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + 4), control: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - fold))
        p.addLine(to: CGPoint(x: r.maxX - fold, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + 4, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - 4), control: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + 4))
        p.addQuadCurve(to: CGPoint(x: r.minX + 4, y: r.minY), control: CGPoint(x: r.minX, y: r.minY))
        p.closeSubpath()
        return p
    }
}

struct BFoldShape: Shape {
    var fold: CGFloat = 13
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.maxX, y: r.maxY - fold))
        p.addLine(to: CGPoint(x: r.maxX - fold, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.maxX - fold + 1, y: r.maxY - fold + 1), control: CGPoint(x: r.maxX - fold - 1, y: r.maxY - fold * 0.4))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.maxY - fold), control: CGPoint(x: r.maxX - fold * 0.4, y: r.maxY - fold - 1))
        p.closeSubpath()
        return p
    }
}

struct BScribble: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width
        for (i, len) in [1.0, 0.8, 0.55].enumerated() {
            let y = r.minY + CGFloat(i) * 10
            p.move(to: CGPoint(x: r.minX, y: y))
            let segs = 4
            let end = w * len
            for s in 0..<segs {
                let x0 = end * CGFloat(s) / CGFloat(segs), x1 = end * CGFloat(s + 1) / CGFloat(segs)
                p.addQuadCurve(to: CGPoint(x: r.minX + x1, y: y), control: CGPoint(x: r.minX + (x0 + x1) / 2, y: y + (s % 2 == 0 ? -3.5 : 3.5)))
            }
        }
        return p
    }
}

struct BScratchpadArt: View {
    var body: some View {
        ZStack {
            // a second sheet peeking out underneath
            BNoteShape(fold: 0).fill(vgrad([c(1, 0.62, 0.55), c(0.95, 0.42, 0.4)]))
                .frame(width: 54, height: 56).rotationEffect(.degrees(8)).offset(x: 5, y: 3)
                .shadow(color: .black.opacity(0.35), radius: 2, y: 2)
            ZStack {
                BNoteShape().fill(vgrad([c(1, 0.93, 0.5), c(1, 0.78, 0.2)]))
                BNoteShape().fill(sheen).blendMode(.plusLighter).opacity(0.6)
                BNoteShape().stroke(.white.opacity(0.45), lineWidth: 1)
                BScribble().stroke(c(0.55, 0.35, 0.05).opacity(0.75), style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                    .frame(width: 34, height: 22).offset(x: -1, y: 2)
                BFoldShape().fill(vgrad([c(1, 0.96, 0.75), c(0.9, 0.65, 0.15)]))
                    .shadow(color: .black.opacity(0.3), radius: 1.5, x: -1, y: -1)
            }
            .frame(width: 54, height: 56)
            .shadow(color: .black.opacity(0.45), radius: 3, y: 2)
            .rotationEffect(.degrees(-6)).offset(x: -3, y: 0)
            // tape strip
            Rectangle().fill(vgrad([c(1, 1, 0.95).opacity(0.85), c(0.9, 0.88, 0.8).opacity(0.85)]))
                .frame(width: 24, height: 9)
                .overlay(Rectangle().stroke(.black.opacity(0.08), lineWidth: 0.6))
                .rotationEffect(.degrees(-10)).offset(x: -5, y: -29)
                .shadow(color: .black.opacity(0.25), radius: 1, y: 1)
        }
    }
}

struct BLinkShape: View {
    let colors: [Color]
    var body: some View {
        ZStack {
            Capsule().stroke(dgrad(colors), lineWidth: 8)
            Capsule().stroke(LinearGradient(colors: [.white.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom), lineWidth: 2.5).padding(-2)
                .blendMode(.plusLighter)
        }
        .frame(width: 40, height: 20)
    }
}

struct BURLCleanerArt: View {
    let mint = [c(0.5, 1, 0.75), c(0.1, 0.72, 0.5)]
    var body: some View {
        ZStack {
            ZStack {
                BLinkShape(colors: mint).offset(x: -13)
                BLinkShape(colors: mint).offset(x: 13)
                // re-draw the left link's right half on top so the two links interlock
                BLinkShape(colors: mint).offset(x: -13).mask(Rectangle().frame(width: 20, height: 12).offset(x: 4, y: 6))
            }
            .shadow(color: c(0.1, 0.8, 0.5).opacity(0.5), radius: 6)
            .shadow(color: .black.opacity(0.45), radius: 2, y: 2)
            .rotationEffect(.degrees(-40)).offset(x: -3, y: 4)
            BSparkle(size: 20).offset(x: 24, y: -24)
            BSparkle(size: 12).offset(x: 8, y: -32)
            BSparkle(size: 10).offset(x: 30, y: -6)
        }
    }
}

struct BSparkle: View {
    let size: CGFloat
    var body: some View {
        ZStack {
            Image(systemName: "sparkle").font(.system(size: size, weight: .bold)).foregroundStyle(c(1, 0.85, 0.3)).blur(radius: 4).opacity(0.7)
            Image(systemName: "sparkle").font(.system(size: size, weight: .bold))
                .foregroundStyle(vgrad([c(1, 0.97, 0.7), c(1, 0.72, 0.15)]))
                .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
        }
    }
}

struct BSnippetsArt: View {
    let indigo = [c(0.55, 0.6, 1), c(0.3, 0.3, 0.95)]
    var body: some View {
        ZStack {
            BCard(colors: [Color(white: 0.99), Color(white: 0.84)], w: 50, h: 58, r: 8) {
                VStack(alignment: .leading, spacing: 5.5) {
                    Capsule().fill(dgrad(indigo)).frame(width: 26, height: 5)
                    ForEach(0..<4) { i in
                        Capsule().fill(Color(white: 0.2).opacity(0.22)).frame(width: [34, 30, 34, 18][i], height: 3.5)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 8).offset(y: -4)
            }
            .rotationEffect(.degrees(-4)).offset(x: -7, y: -5)
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous).fill(dgrad(indigo))
                RoundedRectangle(cornerRadius: 9, style: .continuous).fill(sheen).blendMode(.plusLighter)
                RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(.white.opacity(0.45), lineWidth: 1)
                Text("{ }").font(.system(size: 17, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 1, y: 1).offset(y: -1)
            }
            .frame(width: 36, height: 28)
            .shadow(color: c(0.35, 0.35, 1).opacity(0.5), radius: 6)
            .shadow(color: .black.opacity(0.45), radius: 2.5, y: 2)
            .offset(x: 16, y: 20)
        }
    }
}

// MARK: - Capture

struct BScene: View {
    var body: some View {
        ZStack {
            Rectangle().fill(vgrad([c(0.35, 0.55, 1), c(0.75, 0.55, 1), c(1, 0.6, 0.6)]))
            Circle().fill(RadialGradient(colors: [c(1, 0.95, 0.6), c(1, 0.7, 0.3)], center: .center, startRadius: 0, endRadius: 8))
                .frame(width: 13, height: 13).offset(x: 9, y: -5)
            BHills().fill(vgrad([c(0.3, 0.8, 0.75), c(0.1, 0.45, 0.6)]))
            BHills().fill(vgrad([c(0.2, 0.6, 0.65), c(0.05, 0.3, 0.5)])).scaleEffect(x: -1).offset(y: 6)
        }
    }
}

struct BScreenshotArt: View {
    var body: some View {
        ZStack {
            BCard(colors: [.clear, .clear], w: 52, h: 40, r: 6) { BScene() }
            BViewfinder(colors: [c(0.45, 0.85, 1), c(0.2, 0.45, 1)], w: 70, h: 58, len: 15)
        }
    }
}

struct BScrollingArt: View {
    let teal = [c(0.35, 0.92, 0.85), c(0.05, 0.55, 0.65)]
    var body: some View {
        ZStack {
            ZStack(alignment: .top) {
                Rectangle().fill(vgrad([c(0.95, 1, 0.99), c(0.8, 0.92, 0.92)]))
                VStack(alignment: .leading, spacing: 5) {
                    RoundedRectangle(cornerRadius: 3).fill(dgrad(teal)).frame(width: 28, height: 14)
                    ForEach(0..<3) { i in Capsule().fill(Color(white: 0.2).opacity(0.22)).frame(width: [28, 22, 26][i], height: 3) }
                    RoundedRectangle(cornerRadius: 3).fill(dgrad([c(0.6, 1, 0.85), c(0.2, 0.75, 0.6)])).frame(width: 28, height: 12)
                    ForEach(0..<3) { i in Capsule().fill(Color(white: 0.2).opacity(0.22)).frame(width: [26, 28, 18][i], height: 3) }
                }
                .padding(.top, 6)
            }
            .frame(width: 38, height: 74)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(c(0.05, 0.45, 0.5).opacity(0.25), lineWidth: 1))
            .mask(vgrad([.black, .black, .black, .black.opacity(0.15)]))
            .shadow(color: .black.opacity(0.45), radius: 3, y: 2)
            .offset(x: -10)
            // scroll track and arrow
            Capsule().fill(teal[1].opacity(0.22)).frame(width: 7, height: 58).offset(x: 20, y: -8)
            Capsule().fill(vgrad(teal)).frame(width: 7, height: 22).offset(x: 20, y: -22)
                .overlay(Capsule().fill(sheen).blendMode(.plusLighter).frame(width: 7, height: 22).offset(x: 20, y: -22))
            BBadge(symbol: "arrow.down", colors: teal, size: 26).offset(x: 20, y: 20)
                .shadow(color: teal[0].opacity(0.5), radius: 6)
        }
    }
}

struct BMonitor<Content: View>: View {
    var w: CGFloat = 70
    var h: CGFloat = 48
    @ViewBuilder var content: Content
    var body: some View {
        ZStack {
            // stand
            Path { p in
                p.move(to: CGPoint(x: 44, y: 70)); p.addLine(to: CGPoint(x: 56, y: 70)); p.addLine(to: CGPoint(x: 59, y: 80)); p.addLine(to: CGPoint(x: 41, y: 80)); p.closeSubpath()
            }
            .fill(vgrad([Color(white: 0.6), Color(white: 0.78)])).frame(width: 100, height: 100)
            Capsule().fill(vgrad([Color(white: 0.9), Color(white: 0.62)])).frame(width: 30, height: 4).offset(y: 31)
            RoundedRectangle(cornerRadius: 7, style: .continuous).fill(vgrad([Color(white: 0.93), Color(white: 0.68)])).frame(width: w, height: h).offset(y: -8)
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous).fill(vgrad([Color(white: 0.24), Color(white: 0.08)]))
                content
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(LinearGradient(colors: [.white.opacity(0.14), .clear], startPoint: .topLeading, endPoint: .center))
            }
            .frame(width: w - 6, height: h - 6).clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous)).offset(y: -8)
        }
        .shadow(color: .black.opacity(0.45), radius: 3, y: 2)
    }
}

struct BRecorderArt: View {
    var body: some View {
        BMonitor {
            ZStack {
                Circle().fill(c(1, 0.2, 0.2)).frame(width: 26, height: 26).blur(radius: 8).opacity(0.8)
                Circle().strokeBorder(c(1, 0.35, 0.35).opacity(0.6), lineWidth: 2).frame(width: 30, height: 30)
                OrbitSphere(colors: [c(1, 0.55, 0.5), c(0.95, 0.15, 0.15), c(0.6, 0.02, 0.05)]).frame(width: 22, height: 22)
            }
        }
    }
}

struct BTextCaptureArt: View {
    let violet = [c(0.75, 0.55, 1), c(0.45, 0.25, 0.95)]
    var body: some View {
        ZStack {
            BViewfinder(colors: violet, w: 68, h: 58, len: 15)
            ZStack {
                Text("Aa").font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(vgrad([c(0.85, 0.6, 1), c(0.95, 0.35, 0.75)])).blur(radius: 6).opacity(0.35)
                Text("Aa").font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(vgrad([c(0.62, 0.35, 1), c(0.85, 0.15, 0.58)]))
                    .shadow(color: .black.opacity(0.4), radius: 1.5, y: 1.5)
                Text("Aa").font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .top, endPoint: .center))
                    .blendMode(.plusLighter)
            }
            .offset(y: -1)
            // scan line
            Capsule().fill(LinearGradient(colors: [c(1, 0.45, 0.8).opacity(0), c(1, 0.45, 0.8), c(1, 0.45, 0.8).opacity(0)], startPoint: .leading, endPoint: .trailing))
                .frame(width: 58, height: 2.5).offset(y: 14)
                .shadow(color: c(1, 0.4, 0.8), radius: 4)
        }
    }
}

struct BColorPickerArt: View {
    let pink = [c(1, 0.55, 0.8), c(0.9, 0.15, 0.55)]
    var body: some View {
        ZStack {
            // the dropper, drawn upright then tilted
            VStack(spacing: 0) {
                Capsule().fill(dgrad(pink)).frame(width: 17, height: 24)
                    .overlay(Capsule().fill(sheen).blendMode(.plusLighter))
                    .zIndex(1)
                RoundedRectangle(cornerRadius: 2).fill(vgrad([Color(white: 0.95), Color(white: 0.6)])).frame(width: 22, height: 6).offset(y: -2)
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 3).fill(LinearGradient(colors: [Color(white: 1).opacity(0.9), Color(white: 0.78).opacity(0.9)], startPoint: .leading, endPoint: .trailing))
                    RoundedRectangle(cornerRadius: 3).fill(dgrad(pink)).frame(height: 14)
                    RoundedRectangle(cornerRadius: 3).strokeBorder(Color(white: 0.45).opacity(0.6), lineWidth: 0.8)
                }
                .frame(width: 10, height: 28).offset(y: -2)
                Path { p in p.move(to: CGPoint(x: 0, y: 0)); p.addLine(to: CGPoint(x: 8, y: 0)); p.addLine(to: CGPoint(x: 5, y: 9)); p.addLine(to: CGPoint(x: 3, y: 9)); p.closeSubpath() }
                    .fill(vgrad([Color(white: 0.85), Color(white: 0.6)])).frame(width: 8, height: 9).offset(y: -2)
            }
            .shadow(color: .black.opacity(0.45), radius: 3, y: 2)
            .rotationEffect(.degrees(40)).offset(x: 8, y: -8)
            // the drop it picked up
            ZStack {
                Image(systemName: "drop.fill").font(.system(size: 26, weight: .semibold)).foregroundStyle(dgrad(pink)).blur(radius: 6).opacity(0.6)
                Image(systemName: "drop.fill").font(.system(size: 26, weight: .semibold)).foregroundStyle(dgrad(pink))
                    .shadow(color: .black.opacity(0.4), radius: 2, y: 2)
                Image(systemName: "drop.fill").font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: [.white.opacity(0.6), .clear], startPoint: .top, endPoint: .center)).blendMode(.plusLighter)
            }
            .offset(x: -21, y: 22)
        }
    }
}

struct BCameraArt: View {
    var body: some View {
        ZStack {
            // housing
            Circle().fill(vgrad([Color(white: 0.96), Color(white: 0.62)])).frame(width: 68, height: 68)
                .shadow(color: .black.opacity(0.5), radius: 3, y: 3)
            Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1).frame(width: 68, height: 68)
            // lens barrel
            Circle().fill(vgrad([Color(white: 0.08), Color(white: 0.3)])).frame(width: 52, height: 52)
            // glass
            Circle().fill(RadialGradient(colors: [c(0.45, 0.5, 1), c(0.2, 0.12, 0.55), c(0.04, 0.02, 0.12)], center: UnitPoint(x: 0.6, y: 0.65), startRadius: 1, endRadius: 22))
                .frame(width: 42, height: 42)
            Circle().stroke(AngularGradient(colors: [c(0.3, 0.9, 1), c(0.7, 0.4, 1), c(1, 0.4, 0.7), c(0.3, 0.9, 1)], center: .center), lineWidth: 1.6)
                .frame(width: 32, height: 32).opacity(0.65)
            Circle().fill(RadialGradient(colors: [c(0.1, 0.05, 0.25), .black], center: .center, startRadius: 0, endRadius: 9)).frame(width: 16, height: 16)
            // reflections
            Ellipse().fill(LinearGradient(colors: [.white.opacity(0.75), .white.opacity(0)], startPoint: .top, endPoint: .bottom))
                .frame(width: 18, height: 10).rotationEffect(.degrees(-35)).offset(x: -8, y: -10)
            Circle().fill(.white.opacity(0.85)).frame(width: 4, height: 4).offset(x: 9, y: 9)
            // status light
            Circle().fill(c(0.3, 1, 0.45)).frame(width: 5, height: 5).offset(y: -30).shadow(color: c(0.3, 1, 0.45), radius: 3)
        }
    }
}

struct BMagnifyArt: View {
    let gold = [c(1, 0.85, 0.4), c(0.9, 0.5, 0.05)]
    var body: some View {
        ZStack {
            // handle
            Capsule().fill(LinearGradient(colors: [c(0.75, 0.4, 0.05), c(1, 0.7, 0.3), c(0.7, 0.35, 0.02)], startPoint: .leading, endPoint: .trailing))
                .frame(width: 12, height: 30).overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                .rotationEffect(.degrees(-45)).offset(x: 22, y: 22)
                .shadow(color: .black.opacity(0.45), radius: 2.5, y: 2)
            ZStack {
                // glass with a magnified, refracted scene
                Circle().fill(RadialGradient(colors: [c(1, 0.97, 0.85), c(1, 0.85, 0.55), c(0.95, 0.62, 0.25)], center: UnitPoint(x: 0.4, y: 0.35), startRadius: 2, endRadius: 30))
                Image(systemName: "sparkle").font(.system(size: 22, weight: .bold))
                    .foregroundStyle(vgrad([c(1, 0.6, 0.2), c(0.85, 0.35, 0.05)])).offset(x: 2, y: 2)
                Path { p in p.addArc(center: CGPoint(x: 23, y: 23), radius: 16, startAngle: .degrees(195), endAngle: .degrees(255), clockwise: false) }
                    .stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                Circle().strokeBorder(dgrad(gold), lineWidth: 6.5)
                Circle().strokeBorder(LinearGradient(colors: [.white.opacity(0.7), .clear], startPoint: .top, endPoint: .bottom), lineWidth: 1.2)
            }
            .frame(width: 46, height: 46)
            .shadow(color: c(1, 0.7, 0.2).opacity(0.45), radius: 6)
            .shadow(color: .black.opacity(0.45), radius: 3, y: 2)
            .offset(x: -6, y: -6)
        }
    }
}

// MARK: - Windows

struct BWindowLines: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 3.5) {
            ForEach(0..<3) { i in Capsule().fill(.white.opacity(0.55)).frame(width: [22, 16, 20][i], height: 3) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(6)
    }
}

struct BSwitcherArt: View {
    var body: some View {
        ZStack {
            BWindow(colors: [c(0.55, 0.8, 1), c(0.3, 0.55, 0.95)], w: 48, h: 38) { EmptyView() }
                .rotationEffect(.degrees(-16)).offset(x: -16, y: -6)
            BWindow(colors: [c(0.4, 0.7, 1), c(0.2, 0.42, 0.95)], w: 48, h: 38) { EmptyView() }
                .rotationEffect(.degrees(-5)).offset(x: -4, y: -2)
            BWindow(colors: [c(0.35, 0.6, 1), c(0.15, 0.3, 0.9)], w: 50, h: 40) { BWindowLines() }
                .rotationEffect(.degrees(7)).offset(x: 10, y: 6)
        }
        .offset(x: 3, y: -2)
    }
}

struct BDockArt: View {
    let apps: [[Color]] = [
        [c(0.45, 0.85, 1), c(0.15, 0.45, 1)],
        [c(0.5, 1, 0.6), c(0.1, 0.7, 0.35)],
        [c(0.85, 0.65, 1), c(0.55, 0.3, 0.95)],
        [c(1, 0.85, 0.4), c(1, 0.55, 0.1)],
    ]
    var body: some View {
        ZStack {
            // floating preview with its pointer
            ZStack {
                Path { p in p.move(to: CGPoint(x: 0, y: 0)); p.addLine(to: CGPoint(x: 10, y: 0)); p.addLine(to: CGPoint(x: 5, y: 6)); p.closeSubpath() }
                    .fill(c(0.5, 0.28, 0.92)).frame(width: 10, height: 6).offset(x: 5, y: 21)
                BWindow(colors: [c(0.78, 0.6, 1), c(0.5, 0.28, 0.92)], w: 56, h: 40) { BWindowLines() }
            }
            .offset(y: -15)
            // dock
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(vgrad([Color(white: 0.85).opacity(0.9), Color(white: 0.55).opacity(0.9)]))
                RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.white.opacity(0.55), lineWidth: 1)
                HStack(spacing: 4) {
                    ForEach(0..<4) { i in
                        RoundedRectangle(cornerRadius: 3.5, style: .continuous).fill(dgrad(apps[i])).frame(width: 12, height: 12)
                            .overlay(RoundedRectangle(cornerRadius: 3.5, style: .continuous).fill(sheen).blendMode(.plusLighter))
                            .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
                            .scaleEffect(i == 2 ? 1.2 : 1).offset(y: i == 2 ? -1 : 0)
                    }
                }
                Circle().fill(Color(white: 0.25)).frame(width: 2.5, height: 2.5).offset(x: 8, y: 8.5)
            }
            .frame(width: 72, height: 20)
            .shadow(color: .black.opacity(0.45), radius: 3, y: 2)
            .offset(y: 24)
        }
    }
}

struct BSnapArt: View {
    let tiles: [[Color]] = [
        [c(0.5, 1, 0.6), c(0.1, 0.72, 0.38)],
        [c(0.7, 1, 0.55), c(0.35, 0.8, 0.3)],
        [c(0.45, 0.95, 0.8), c(0.1, 0.65, 0.55)],
    ]
    func tile(_ i: Int, _ w: CGFloat, _ h: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous).fill(vgrad(tiles[i]))
            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(sheen).blendMode(.plusLighter))
            .overlay(alignment: .topLeading) {
                HStack(spacing: 2) { ForEach(0..<3) { _ in Circle().fill(.white.opacity(0.7)).frame(width: 3, height: 3) } }.padding(4)
            }
            .frame(width: w, height: h)
    }
    var body: some View {
        BMonitor(w: 72, h: 54) {
            HStack(spacing: 3) {
                tile(0, 31, 42)
                VStack(spacing: 3) { tile(1, 30, 19.5); tile(2, 30, 19.5) }
            }
        }
        .offset(y: 3)
    }
}

struct BWorkspacesArt: View {
    let walls: [[Color]] = [
        [c(1, 0.7, 0.45), c(1, 0.4, 0.35)],
        [c(1, 0.55, 0.65), c(0.9, 0.3, 0.5)],
        [c(1, 0.8, 0.5), c(1, 0.55, 0.25)],
        [c(1, 0.6, 0.5), c(0.85, 0.3, 0.3)],
    ]
    func desk(_ i: Int) -> some View {
        BCard(colors: walls[i], w: 31, h: 24, r: 5) {
            ZStack(alignment: .top) {
                Rectangle().fill(.white.opacity(0.45)).frame(height: 3).frame(maxHeight: .infinity, alignment: .top)
VStack(spacing: 0) { Rectangle().fill(.white).frame(height: 2.5); Rectangle().fill(.white.opacity(0.7)) }
                    .clipShape(RoundedRectangle(cornerRadius: 2)).frame(width: 13, height: 9)
                    .offset(x: [-4, 4, 2, -3][i], y: [8, 9, 7, 10][i])
                    .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
            }
        }
    }
    var body: some View {
        ZStack {
            VStack(spacing: 5) {
                HStack(spacing: 5) { desk(0); desk(1) }
                HStack(spacing: 5) { desk(2); desk(3) }
            }
            RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(dgrad([c(1, 0.85, 0.5), c(1, 0.45, 0.2)]), lineWidth: 2.5)
                .frame(width: 37, height: 30).offset(x: -18, y: -14.5)
                .shadow(color: c(1, 0.6, 0.2).opacity(0.7), radius: 4)
        }
    }
}

struct BRadialArt: View {
    let colors: [Color] = [c(1, 0.35, 0.4), c(1, 0.6, 0.2), c(1, 0.85, 0.25), c(0.4, 0.9, 0.4), c(0.2, 0.85, 0.85), c(0.3, 0.55, 1), c(0.6, 0.4, 1), c(0.95, 0.4, 0.8)]
    var body: some View {
        ZStack {
            ForEach(0..<8) { i in
                let f = Double(i) / 8
                Circle().trim(from: f + 0.012, to: f + 0.125 - 0.012)
                    .stroke(LinearGradient(colors: [colors[i].opacity(0.85), colors[i]], startPoint: .top, endPoint: .bottom), style: StrokeStyle(lineWidth: 15, lineCap: .butt))
                    .frame(width: 58, height: 58)
                    .rotationEffect(.degrees(-90 - 22.5))
                    .scaleEffect(i == 1 ? 1.1 : 1)
                    .shadow(color: i == 1 ? colors[i].opacity(0.8) : .clear, radius: 5)
            }
            Circle().stroke(.white.opacity(0.25), lineWidth: 0.8).frame(width: 72, height: 72).opacity(0)
            OrbitSphere(colors: [Color(white: 1), Color(white: 0.82), Color(white: 0.45)]).frame(width: 26, height: 26)
        }
        .shadow(color: .black.opacity(0.4), radius: 2.5, y: 2)
    }
}

struct BAutoQuitArt: View {
    var body: some View {
        BWindow(colors: [c(0.35, 0.35, 0.85), c(0.12, 0.1, 0.4)], w: 66, h: 54) {
            ZStack {
                ForEach(0..<6) { i in
                    Circle().fill(.white.opacity(0.7)).frame(width: 2, height: 2)
                        .offset(x: [-22, -12, 20, 24, -24, 8][i], y: [-12, 10, -14, 6, 8, -16][i])
                }
                ZStack {
                    Image(systemName: "moon.fill").font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(vgrad([c(1, 0.95, 0.6), c(1, 0.72, 0.2)])).blur(radius: 6).opacity(0.7)
                    Image(systemName: "moon.fill").font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(vgrad([c(1, 0.95, 0.6), c(1, 0.72, 0.2)]))
                }
                .offset(x: -6, y: 0)
                Text("z").font(.system(size: 11, weight: .heavy, design: .rounded)).foregroundStyle(.white.opacity(0.9)).offset(x: 13, y: -6)
                Text("z").font(.system(size: 8, weight: .heavy, design: .rounded)).foregroundStyle(.white.opacity(0.75)).offset(x: 20, y: -12)
            }
        }
    }
}

// MARK: - The set

enum OrbitIconsB {
    static let icons: [OrbitIcon] = [
        OrbitIcon(name: "Media Tools", group: "Everyday", compact: "photo.on.rectangle.angled", tint: [c(1, 0.5, 0.85), c(0.65, 0.25, 0.9)], art: AnyView(BMediaArt())),
        OrbitIcon(name: "Scratchpad", group: "Everyday", compact: "note.text", tint: [c(1, 0.9, 0.45), c(1, 0.68, 0.15)], art: AnyView(BScratchpadArt())),
        OrbitIcon(name: "URL Cleaner", group: "Everyday", compact: "link", tint: [c(0.5, 1, 0.75), c(0.1, 0.72, 0.5)], art: AnyView(BURLCleanerArt())),
        OrbitIcon(name: "Text Snippets", group: "Everyday", compact: "curlybraces", tint: [c(0.55, 0.6, 1), c(0.3, 0.3, 0.95)], art: AnyView(BSnippetsArt())),

        OrbitIcon(name: "Screenshot", group: "Capture", compact: "camera.viewfinder", tint: [c(0.45, 0.85, 1), c(0.2, 0.45, 1)], art: AnyView(BScreenshotArt())),
        OrbitIcon(name: "Scrolling Screenshot", group: "Capture", compact: "arrow.up.and.down.text.horizontal", tint: [c(0.35, 0.92, 0.85), c(0.05, 0.55, 0.65)], art: AnyView(BScrollingArt())),
        OrbitIcon(name: "Screen Recorder", group: "Capture", compact: "record.circle.fill", tint: [c(1, 0.5, 0.45), c(0.9, 0.12, 0.15)], art: AnyView(BRecorderArt())),
        OrbitIcon(name: "Text Capture", group: "Capture", compact: "text.viewfinder", tint: [c(0.8, 0.6, 1), c(0.5, 0.28, 0.95)], art: AnyView(BTextCaptureArt())),
        OrbitIcon(name: "Color Picker", group: "Capture", compact: "eyedropper.halffull", tint: [c(1, 0.55, 0.8), c(0.9, 0.15, 0.55)], art: AnyView(BColorPickerArt())),
        OrbitIcon(name: "Camera Preview", group: "Capture", compact: "web.camera.fill", tint: [c(0.55, 0.6, 1), c(0.3, 0.2, 0.75)], art: AnyView(BCameraArt())),
        OrbitIcon(name: "Magnify", group: "Capture", compact: "plus.magnifyingglass", tint: [c(1, 0.85, 0.4), c(0.95, 0.55, 0.1)], art: AnyView(BMagnifyArt())),

        OrbitIcon(name: "Window Switcher", group: "Windows", compact: "macwindow.on.rectangle", tint: [c(0.45, 0.75, 1), c(0.2, 0.4, 0.95)], art: AnyView(BSwitcherArt())),
        OrbitIcon(name: "Dock Preview", group: "Windows", compact: "dock.arrow.up.rectangle", tint: [c(0.8, 0.6, 1), c(0.5, 0.28, 0.92)], art: AnyView(BDockArt())),
        OrbitIcon(name: "Window Snap", group: "Windows", compact: "rectangle.split.2x1.fill", tint: [c(0.5, 1, 0.6), c(0.1, 0.72, 0.38)], art: AnyView(BSnapArt())),
        OrbitIcon(name: "Workspaces", group: "Windows", compact: "square.grid.2x2.fill", tint: [c(1, 0.7, 0.45), c(0.95, 0.38, 0.35)], art: AnyView(BWorkspacesArt())),
        OrbitIcon(name: "Radial Menu", group: "Windows", compact: "circle.grid.cross.fill", tint: [c(1, 0.55, 0.45), c(0.6, 0.4, 1)], art: AnyView(BRadialArt())),
        OrbitIcon(name: "Auto Quit", group: "Windows", compact: "moon.zzz.fill", tint: [c(0.55, 0.55, 1), c(0.25, 0.2, 0.7)], art: AnyView(BAutoQuitArt())),
    ]
}
