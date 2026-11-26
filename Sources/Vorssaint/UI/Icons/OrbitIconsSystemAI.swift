// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

// Set C: System, Input, Devices, AI and Productivity features.
// Every art view draws in the same 100×100 canvas as the seeds.

// MARK: - Helpers

func cRGB(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }
func cP(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
func cRound(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> Path {
    Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r, style: .continuous)
}
func cOval(_ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path {
    Path(ellipseIn: CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h))
}

/// A path in canvas coordinates, filled with a gradient over its own bounds,
/// with a top sheen and a rim that catches light along the top.
struct CSolid: View {
    let path: Path
    let colors: [Color]
    var diagonal = false
    var sheen = 0.45
    var rim = 0.45
    var body: some View {
        let b = path.boundingRect
        let s = UnitPoint(x: (diagonal ? b.minX : b.midX) / 100, y: b.minY / 100)
        let e = UnitPoint(x: (diagonal ? b.maxX : b.midX) / 100, y: b.maxY / 100)
        let top = UnitPoint(x: 0.5, y: b.minY / 100), mid = UnitPoint(x: 0.5, y: (b.minY + b.height * 0.55) / 100)
        ZStack {
            path.fill(LinearGradient(colors: colors, startPoint: s, endPoint: e))
            path.fill(LinearGradient(colors: [.white.opacity(sheen), .white.opacity(0)], startPoint: top, endPoint: mid))
            path.stroke(LinearGradient(colors: [.white.opacity(rim), .white.opacity(0)], startPoint: top, endPoint: mid), lineWidth: 1)
        }
        .frame(width: 100, height: 100)
    }
}

/// A symbol filled with a gradient and a small shadow, placed at a canvas point.
struct CGlyph: View {
    let symbol: String
    let colors: [Color]
    let size: CGFloat
    let at: CGPoint
    var weight: Font.Weight = .bold
    var body: some View {
        Image(systemName: symbol).font(.system(size: size, weight: weight))
            .foregroundStyle(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
            .position(at)
    }
}

extension View {
    func cDrop(_ o: Double = 0.45) -> some View { shadow(color: .black.opacity(o), radius: 3, y: 3) }
    func cCanvas() -> some View { frame(width: 100, height: 100) }
}

// MARK: - System

struct CCoffeeArt: View {
    var body: some View {
        let mug = [cRGB(1, 0.64, 0.44), cRGB(0.84, 0.26, 0.16)]
        ZStack {
            ForEach(0..<3) { i in
                let x: CGFloat = 39 + CGFloat(i) * 11
                let top: CGFloat = i == 1 ? 10 : 17
                Path { p in
                    p.move(to: cP(x, 38))
                    p.addCurve(to: cP(x, top), control1: cP(x - 7, 31), control2: cP(x + 7, top + 9))
                }
                .stroke(LinearGradient(colors: [cRGB(1, 0.62, 0.42), cRGB(1, 0.62, 0.42).opacity(0)],
                                       startPoint: UnitPoint(x: 0.5, y: 0.36), endPoint: UnitPoint(x: 0.5, y: top / 100)),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round))
            }
            Group {
                CSolid(path: cOval(50, 79, 68, 14), colors: [cRGB(1, 0.78, 0.64), cRGB(0.86, 0.38, 0.24)], sheen: 0.5)
                cOval(50, 77, 42, 7).fill(cRGB(0.6, 0.18, 0.1).opacity(0.45))
                Circle().trim(from: 0.72, to: 1.28).stroke(LinearGradient(colors: mug, startPoint: .top, endPoint: .bottom), lineWidth: 6)
                    .frame(width: 20, height: 20).position(x: 70, y: 55)
                Circle().stroke(LinearGradient(colors: mug, startPoint: .top, endPoint: .bottom), lineWidth: 6)
                    .frame(width: 20, height: 20).position(x: 70, y: 55)
                CSolid(path: Path { p in
                    p.move(to: cP(27, 40)); p.addLine(to: cP(73, 40)); p.addLine(to: cP(69, 68))
                    p.addQuadCurve(to: cP(59, 77), control: cP(68, 77)); p.addLine(to: cP(41, 77))
                    p.addQuadCurve(to: cP(31, 68), control: cP(32, 77)); p.closeSubpath()
                }, colors: mug, diagonal: true)
                cOval(50, 40, 46, 10).fill(LinearGradient(colors: [cRGB(0.36, 0.18, 0.07), cRGB(0.55, 0.3, 0.14)], startPoint: .top, endPoint: .bottom))
                cOval(50, 40, 46, 10).stroke(cRGB(1, 0.8, 0.66), lineWidth: 2)
                cOval(45, 39, 16, 3).fill(.white.opacity(0.22))
            }
            .cDrop()
        }
        .cCanvas()
    }
}

struct CSunArt: View {
    var body: some View {
        ZStack {
            Circle().fill(cRGB(1, 0.78, 0.2)).frame(width: 60, height: 60).blur(radius: 12).opacity(0.7)
            ForEach(0..<8) { i in
                Capsule().fill(LinearGradient(colors: [cRGB(1, 0.92, 0.4), cRGB(1, 0.6, 0.1)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 7, height: 13).offset(y: -34).rotationEffect(.degrees(Double(i) * 45))
            }
            .shadow(color: .black.opacity(0.3), radius: 1.5, y: 1.5)
            OrbitSphere(colors: [cRGB(1, 0.97, 0.62), cRGB(1, 0.8, 0.2), cRGB(0.98, 0.5, 0.08)]).frame(width: 46, height: 46)
        }
        .cCanvas()
    }
}

struct CMonitorArt: View {
    var body: some View {
        let pts = [cP(21, 64), cP(29, 58), cP(36, 61), cP(44, 47), cP(52, 55), cP(60, 42), cP(68, 49), cP(76, 34)]
        let line = Path { p in p.addLines(pts) }
        let area = Path { p in p.addLines(pts); p.addLine(to: cP(76, 73)); p.addLine(to: cP(21, 73)); p.closeSubpath() }
        ZStack {
            CSolid(path: cRound(15, 20, 70, 60, 13), colors: [cRGB(0.52, 0.44, 1), cRGB(0.2, 0.12, 0.55)], diagonal: true, sheen: 0.3).cDrop()
            ForEach(0..<3) { i in
                Path { p in let y = 40 + CGFloat(i) * 12; p.move(to: cP(21, y)); p.addLine(to: cP(79, y)) }
                    .stroke(.white.opacity(0.13), lineWidth: 1)
            }
            HStack(spacing: 3) { ForEach(0..<3) { _ in Circle().fill(.white.opacity(0.45)).frame(width: 4, height: 4) } }
                .position(x: 28, y: 28)
            area.fill(LinearGradient(colors: [cRGB(0.35, 0.95, 1).opacity(0.45), cRGB(0.35, 0.95, 1).opacity(0)],
                                     startPoint: UnitPoint(x: 0.5, y: 0.36), endPoint: UnitPoint(x: 0.5, y: 0.74)))
            line.stroke(LinearGradient(colors: [cRGB(0.35, 0.95, 1), cRGB(1, 0.5, 0.85)], startPoint: UnitPoint(x: 0.2, y: 0.5), endPoint: UnitPoint(x: 0.78, y: 0.5)),
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                .shadow(color: cRGB(0.4, 0.9, 1).opacity(0.8), radius: 4)
            Circle().fill(.white).frame(width: 8, height: 8).position(x: 76, y: 34)
                .shadow(color: cRGB(1, 0.5, 0.85), radius: 5)
        }
        .cCanvas()
    }
}

struct CBroomArt: View {
    var body: some View {
        let pink = [cRGB(1, 0.62, 0.86), cRGB(0.78, 0.25, 0.68)]
        ZStack {
            ZStack {
                CSolid(path: cRound(47, 6, 6, 44, 3), colors: [cRGB(0.96, 0.78, 0.55), cRGB(0.7, 0.45, 0.25)])
                CSolid(path: Path { p in
                    p.move(to: cP(39, 56)); p.addLine(to: cP(61, 56)); p.addLine(to: cP(71, 80))
                    p.addQuadCurve(to: cP(29, 80), control: cP(50, 86)); p.closeSubpath()
                }, colors: pink)
                ForEach(0..<5) { i in
                    let t = CGFloat(i) / 4
                    Path { p in p.move(to: cP(42 + 16 * t, 60)); p.addLine(to: cP(33 + 34 * t, 80 + (i == 2 ? 2.5 : 1.5))) }
                        .stroke(cRGB(0.55, 0.12, 0.45).opacity(0.35), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
                }
                CSolid(path: cRound(38, 48, 24, 9, 3.5), colors: [cRGB(1, 0.86, 0.45), cRGB(0.88, 0.55, 0.15)])
            }
            .rotationEffect(.degrees(28))
            .offset(x: -4, y: -2)
            .cDrop()
            CGlyph(symbol: "sparkle", colors: [cRGB(1, 0.72, 0.92), cRGB(0.9, 0.3, 0.7)], size: 15, at: cP(78, 70))
            CGlyph(symbol: "sparkle", colors: [cRGB(1, 0.72, 0.92), cRGB(0.9, 0.3, 0.7)], size: 9, at: cP(68, 84))
            ForEach(0..<3) { i in
                let c = [cP(24, 28), cP(32, 18), cP(20, 42)][i]
                let d: CGFloat = [10, 6, 5][i]
                Circle().fill(cRGB(1, 0.7, 0.9).opacity(0.25))
                    .overlay(Circle().stroke(cRGB(0.95, 0.45, 0.8), lineWidth: 1.4))
                    .overlay(Circle().fill(.white.opacity(0.8)).frame(width: d * 0.25, height: d * 0.25).offset(x: -d * 0.2, y: -d * 0.2))
                    .frame(width: d, height: d).position(c)
            }
        }
        .cCanvas()
    }
}

struct CBinArt: View {
    var body: some View {
        let red = [cRGB(1, 0.48, 0.42), cRGB(0.78, 0.1, 0.16)]
        ZStack {
            CSolid(path: cOval(50, 47, 50, 14), colors: [cRGB(1, 0.62, 0.56), cRGB(0.86, 0.24, 0.24)], sheen: 0.3).cDrop(0.3)
            cOval(50, 47, 42, 9).fill(cRGB(0.42, 0.04, 0.08))
            ZStack {
                CSolid(path: cRound(37, 20, 26, 26, 8), colors: [cRGB(0.5, 0.82, 1), cRGB(0.2, 0.42, 0.98)], diagonal: true)
                ForEach(0..<4) { i in
                    RoundedRectangle(cornerRadius: 1.6).fill(.white.opacity(0.9)).frame(width: 7, height: 7)
                        .position(x: 45.5 + CGFloat(i % 2) * 9, y: 28.5 + CGFloat(i / 2) * 9)
                }
            }
            .rotationEffect(.degrees(18), anchor: UnitPoint(x: 0.5, y: 0.33))
            .shadow(color: .black.opacity(0.3), radius: 2, y: 2)
            CSolid(path: Path { p in
                p.move(to: cP(25, 47)); p.addQuadCurve(to: cP(75, 47), control: cP(50, 61))
                p.addLine(to: cP(69, 81)); p.addQuadCurve(to: cP(62, 88), control: cP(68, 88)); p.addLine(to: cP(38, 88))
                p.addQuadCurve(to: cP(31, 81), control: cP(32, 88)); p.closeSubpath()
            }, colors: red, sheen: 0.3, rim: 0).cDrop()
            cOval(50, 47, 50, 14).trim(from: 0, to: 0.5).stroke(cRGB(1, 0.7, 0.66), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            ForEach(0..<3) { i in
                Capsule().fill(.white.opacity(0.22)).frame(width: 3.5, height: 22).position(x: 40 + CGFloat(i) * 10, y: 71)
            }
        }
        .cCanvas()
    }
}

struct CBottleArt: View {
    var body: some View {
        ZStack {
            Group {
                CSolid(path: Path { p in
                    p.move(to: cP(44, 20)); p.addLine(to: cP(56, 20)); p.addLine(to: cP(56, 31))
                    p.addCurve(to: cP(68, 46), control1: cP(56, 38), control2: cP(68, 39)); p.addLine(to: cP(68, 80))
                    p.addQuadCurve(to: cP(62, 87), control: cP(68, 87)); p.addLine(to: cP(38, 87))
                    p.addQuadCurve(to: cP(32, 80), control: cP(32, 87)); p.addLine(to: cP(32, 46))
                    p.addCurve(to: cP(44, 31), control1: cP(32, 39), control2: cP(44, 38)); p.closeSubpath()
                }, colors: [cRGB(1, 0.76, 0.3), cRGB(0.72, 0.34, 0.05)], diagonal: true, sheen: 0.35)
                CSolid(path: cRound(42, 18, 16, 5, 2), colors: [cRGB(1, 0.82, 0.45), cRGB(0.8, 0.45, 0.1)])
                CSolid(path: cRound(44, 9, 12, 11, 3), colors: [cRGB(0.92, 0.76, 0.56), cRGB(0.66, 0.45, 0.26)])
            }
            .cDrop()
            cRound(36, 45, 3.5, 34, 1.75).fill(.white.opacity(0.4))
            Circle().fill(.white.opacity(0.5)).frame(width: 3, height: 3).position(x: 52, y: 37)
            Circle().fill(.white.opacity(0.4)).frame(width: 2, height: 2).position(x: 49, y: 30)
            CSolid(path: cRound(38, 52, 26, 22, 5), colors: [cRGB(1, 0.98, 0.92), cRGB(0.94, 0.86, 0.74)], sheen: 0.3)
                .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
            Text(">_").font(.system(size: 13, weight: .heavy, design: .monospaced)).foregroundStyle(cRGB(0.45, 0.22, 0.05))
                .position(x: 51, y: 62.5)
        }
        .cCanvas()
    }
}

struct CUpdateArt: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        ZStack {
            CSolid(path: cRound(15, 15, 58, 58, 16), colors: [cRGB(0.48, 0.8, 1), cRGB(0.16, 0.36, 0.95)], diagonal: true, sheen: 0.4).cDrop()
            CGlyph(symbol: "cube.fill", colors: [.white, cRGB(0.85, 0.92, 1)], size: 26, at: cP(44, 44))
            Circle().fill(scheme == .dark ? Color(white: 0.11) : Color(white: 0.93)).frame(width: 38, height: 38).position(x: 71, y: 71)
            CSolid(path: cOval(71, 71, 31, 31), colors: [cRGB(0.5, 0.95, 0.6), cRGB(0.1, 0.68, 0.4)], sheen: 0.45)
                .shadow(color: cRGB(0.2, 0.9, 0.5).opacity(0.5), radius: 4)
            CGlyph(symbol: "arrow.clockwise", colors: [.white, cRGB(0.9, 1, 0.92)], size: 15, at: cP(71, 70), weight: .heavy)
        }
        .cCanvas()
    }
}

struct CPortArt: View {
    var body: some View {
        let socket = Path { p in
            p.move(to: cP(34, 40)); p.addLine(to: cP(66, 40)); p.addLine(to: cP(66, 62)); p.addLine(to: cP(58, 62))
            p.addLine(to: cP(58, 68)); p.addLine(to: cP(42, 68)); p.addLine(to: cP(42, 62)); p.addLine(to: cP(34, 62)); p.closeSubpath()
        }
        ZStack {
            CSolid(path: cRound(15, 24, 70, 58, 14), colors: [cRGB(0.42, 0.96, 0.8), cRGB(0.05, 0.54, 0.55)], diagonal: true, sheen: 0.4).cDrop()
            socket.fill(LinearGradient(colors: [cRGB(0.02, 0.18, 0.22), cRGB(0.06, 0.32, 0.34)], startPoint: UnitPoint(x: 0.5, y: 0.4), endPoint: UnitPoint(x: 0.5, y: 0.68)))
            socket.stroke(.white.opacity(0.4), lineWidth: 1).offset(y: 0.8)
            ForEach(0..<6) { i in
                RoundedRectangle(cornerRadius: 0.8).fill(LinearGradient(colors: [cRGB(1, 0.9, 0.5), cRGB(0.85, 0.6, 0.15)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 2.4, height: 8).position(x: 39 + CGFloat(i) * 4.4, y: 45)
            }
            Circle().fill(cRGB(0.6, 1, 0.5)).frame(width: 4, height: 4).position(x: 25, y: 74).shadow(color: cRGB(0.6, 1, 0.5), radius: 3)
            Circle().fill(cRGB(1, 0.8, 0.3)).frame(width: 4, height: 4).position(x: 75, y: 74).shadow(color: cRGB(1, 0.8, 0.3), radius: 3)
            ZStack {
                Capsule().fill(LinearGradient(colors: [.white, cRGB(0.86, 0.95, 0.93)], startPoint: .top, endPoint: .bottom))
                Text("443").font(.system(size: 11, weight: .heavy, design: .rounded)).foregroundStyle(cRGB(0.03, 0.42, 0.42))
            }
            .frame(width: 30, height: 15).position(x: 72, y: 24).cDrop(0.35)
        }
        .cCanvas()
    }
}

struct CMenuBarArt: View {
    var body: some View {
        let screen = cRound(12, 18, 76, 64, 13)
        let ink = cRGB(0.32, 0.22, 0.78)
        ZStack {
            CSolid(path: screen, colors: [cRGB(0.66, 0.54, 1), cRGB(0.3, 0.2, 0.75)], diagonal: true, sheen: 0.15).cDrop()
            ZStack {
                Path { p in p.move(to: cP(12, 70)); p.addCurve(to: cP(88, 58), control1: cP(36, 50), control2: cP(60, 76)); p.addLine(to: cP(88, 82)); p.addLine(to: cP(12, 82)); p.closeSubpath() }
                    .fill(LinearGradient(colors: [cRGB(1, 0.55, 0.85).opacity(0.75), cRGB(0.6, 0.3, 0.9).opacity(0.3)], startPoint: .top, endPoint: .bottom))
                Rectangle().fill(LinearGradient(colors: [.white.opacity(0.95), cRGB(0.92, 0.9, 1).opacity(0.9)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 76, height: 24).position(x: 50, y: 30)
                Rectangle().fill(ink.opacity(0.18)).frame(width: 76, height: 1).position(x: 50, y: 42)
            }
            .clipShape(screen)
            // items sliding behind the chevron
            ForEach(0..<3) { i in
                RoundedRectangle(cornerRadius: 2.2).fill(ink.opacity([0.6, 0.35, 0.16][i])).frame(width: 8.5, height: 8.5)
                    .position(x: 39 - CGFloat(i) * 10.5, y: 30)
            }
            CSolid(path: cRound(40, 22, 19, 16, 8), colors: [cRGB(0.74, 0.6, 1), cRGB(0.42, 0.28, 0.95)])
                .shadow(color: ink.opacity(0.45), radius: 2, x: -1.5)
            CGlyph(symbol: "chevron.left", colors: [.white, .white], size: 9, at: cP(49, 30), weight: .black)
            ForEach(0..<3) { i in
                Circle().fill(ink).frame(width: 7.5, height: 7.5).position(x: 66 + CGFloat(i) * 8.5, y: 30)
            }
        }
        .cCanvas()
    }
}

struct CCleanKeysArt: View {
    var body: some View {
        let sky = [cRGB(0.6, 0.88, 1), cRGB(0.18, 0.55, 0.95)]
        ZStack {
            Group {
                cRound(12, 46, 76, 38, 10).fill(Color(white: 0.55))
                CSolid(path: cRound(12, 42, 76, 38, 10), colors: [Color(white: 0.96), Color(white: 0.78)], sheen: 0.3)
            }
            .cDrop()
            ForEach(0..<15) { i in
                let r = i / 6, c = i % 6
                let x: CGFloat = r < 2 ? 17 + CGFloat(c) * 11.3 : [17, 28.3, 73.5][min(c, 2)]
                let w: CGFloat = r == 2 && c == 1 ? 43.2 : 9.5
                keycap(x: x, y: 47 + CGFloat(r) * 10.5, w: w)
            }
            CSolid(path: Path { p in
                p.move(to: cP(52, 27)); p.addQuadCurve(to: cP(82, 14), control: cP(66, 16))
                p.addQuadCurve(to: cP(92, 42), control: cP(92, 26))
                p.addCurve(to: cP(68, 60), control1: cP(86, 52), control2: cP(76, 50))
                p.addCurve(to: cP(59, 44), control1: cP(62, 58), control2: cP(57, 52))
                p.addCurve(to: cP(52, 27), control1: cP(61, 36), control2: cP(50, 34)); p.closeSubpath()
            }, colors: sky, diagonal: true, sheen: 0.45).cDrop(0.35)
            Path { p in p.move(to: cP(88, 41)); p.addCurve(to: cP(69, 55.5), control1: cP(83, 48), control2: cP(75, 47)) }
                .stroke(.white.opacity(0.7), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [2, 2]))
            Path { p in p.move(to: cP(62, 26)); p.addQuadCurve(to: cP(74, 44), control: cP(72, 30)) }
                .stroke(cRGB(0.1, 0.4, 0.85).opacity(0.35), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            CGlyph(symbol: "sparkle", colors: [cRGB(0.85, 0.97, 1), cRGB(0.25, 0.62, 1)], size: 16, at: cP(28, 28))
            CGlyph(symbol: "sparkle", colors: [cRGB(0.85, 0.97, 1), cRGB(0.25, 0.62, 1)], size: 9, at: cP(40, 18))
        }
        .cCanvas()
    }
    func keycap(x: CGFloat, y: CGFloat, w: CGFloat) -> some View {
        ZStack {
            cRound(x, y + 1.2, w, 8.5, 2.5).fill(Color(white: 0.62))
            cRound(x, y, w, 8.5, 2.5).fill(LinearGradient(colors: [.white, Color(white: 0.9)], startPoint: .top, endPoint: .bottom))
        }
        .cCanvas()
    }
}

// MARK: - Input

struct CMouseArt: View {
    var body: some View {
        let flow = [cRGB(0.6, 0.5, 1), cRGB(0.35, 0.6, 1)]
        ZStack {
            ForEach(0..<4) { i in
                let left = i < 2
                let x: CGFloat = left ? (i == 0 ? 24 : 16) : (i == 2 ? 76 : 84)
                let k: CGFloat = left ? -1 : 1
                Path { p in p.move(to: cP(x, 22 + CGFloat(i % 2) * 8)); p.addCurve(to: cP(x, 78 - CGFloat(i % 2) * 8), control1: cP(x + 6 * k, 40), control2: cP(x - 6 * k, 60)) }
                    .stroke(LinearGradient(colors: [flow[0].opacity(0), flow[i % 2], flow[1].opacity(0)], startPoint: UnitPoint(x: 0.5, y: 0.22), endPoint: UnitPoint(x: 0.5, y: 0.78)),
                            style: StrokeStyle(lineWidth: i % 2 == 0 ? 3.5 : 2.5, lineCap: .round))
            }
            CSolid(path: cRound(33, 19, 34, 63, 17), colors: [cRGB(0.97, 0.96, 1), cRGB(0.72, 0.7, 0.92)], sheen: 0.5, rim: 0.8).cDrop()
            Path { p in p.move(to: cP(50, 20)); p.addLine(to: cP(50, 46)) }.stroke(cRGB(0.4, 0.3, 0.8).opacity(0.3), lineWidth: 1.2)
            Path { p in p.move(to: cP(34, 46)); p.addQuadCurve(to: cP(66, 46), control: cP(50, 50)) }.stroke(cRGB(0.4, 0.3, 0.8).opacity(0.2), lineWidth: 1.2)
            CSolid(path: cRound(46.5, 27, 7, 14, 3.5), colors: [cRGB(0.78, 0.65, 1), cRGB(0.45, 0.3, 0.95)])
                .shadow(color: cRGB(0.55, 0.4, 1).opacity(0.8), radius: 4)
        }
        .cCanvas()
    }
}

struct CSuperKeyArt: View {
    var body: some View {
        ZStack {
            OrbitKeycapArt(label: "", top: [cRGB(0.96, 0.72, 1), cRGB(0.78, 0.4, 0.96)], side: cRGB(0.45, 0.16, 0.62))
            Image(systemName: "sparkle").font(.system(size: 26, weight: .heavy))
                .foregroundStyle(LinearGradient(colors: [.white, cRGB(1, 0.88, 1)], startPoint: .top, endPoint: .bottom))
                .shadow(color: cRGB(0.4, 0.1, 0.55).opacity(0.55), radius: 1.5, y: 1.5)
                .shadow(color: .white.opacity(0.6), radius: 5)
                .offset(y: -3)
        }
    }
}

// MARK: - Devices

struct CRemoteArt: View {
    var body: some View {
        let green = [cRGB(0.5, 1, 0.62), cRGB(0.08, 0.62, 0.42)]
        ZStack {
            ZStack {
                CSolid(path: cRound(14, 26, 28, 54, 8), colors: [Color(white: 0.9), Color(white: 0.6)])
                cRound(16.5, 28.5, 23, 49, 6).fill(LinearGradient(colors: green, startPoint: .top, endPoint: .bottom))
                Capsule().fill(Color(white: 0.1)).frame(width: 8, height: 2.8).position(x: 28, y: 32)
                CGlyph(symbol: "play.fill", colors: [.white, cRGB(0.9, 1, 0.9)], size: 12, at: cP(29, 54))
            }
            .rotationEffect(.degrees(-8))
            .cDrop()
            ForEach(0..<3) { i in
                let r = CGFloat(5 + i * 5)
                Path { p in p.addArc(center: cP(43, 44), radius: r, startAngle: .degrees(-45), endAngle: .degrees(25), clockwise: false) }
                    .stroke(LinearGradient(colors: [cRGB(0.4, 0.95, 0.55), cRGB(0.1, 0.7, 0.4)], startPoint: .top, endPoint: .bottom).opacity(1 - Double(i) * 0.2), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .shadow(color: green[1].opacity(0.5), radius: 2)
            }
            Group {
                CSolid(path: Path { p in p.move(to: cP(68, 60)); p.addLine(to: cP(78, 60)); p.addLine(to: cP(80, 69)); p.addLine(to: cP(66, 69)); p.closeSubpath() },
                       colors: [Color(white: 0.8), Color(white: 0.55)])
                CSolid(path: cRound(62, 67.5, 22, 3.5, 1.7), colors: [Color(white: 0.9), Color(white: 0.62)])
                CSolid(path: cRound(57, 38, 32, 24, 4), colors: [Color(white: 0.92), Color(white: 0.64)])
                cRound(59, 40, 28, 17, 2.5).fill(LinearGradient(colors: [cRGB(0.55, 1, 0.72), cRGB(0.1, 0.62, 0.45)], startPoint: .topLeading, endPoint: .bottomTrailing))
                CGlyph(symbol: "play.fill", colors: [.white, cRGB(0.9, 1, 0.9)], size: 8, at: cP(73.5, 48.5))
            }
            .cDrop()
        }
        .cCanvas()
    }
}

// MARK: - AI

struct CGraphArt: View {
    var body: some View {
        let nodes: [(CGPoint, CGFloat)] = [(cP(24, 27), 16), (cP(78, 29), 14), (cP(23, 75), 13), (cP(77, 74), 17)]
        let hub = cP(50, 51)
        ZStack {
            Path { p in
                for (n, _) in nodes { p.move(to: hub); p.addLine(to: n) }
                p.move(to: nodes[0].0); p.addLine(to: nodes[1].0)
                p.move(to: nodes[2].0); p.addLine(to: nodes[3].0)
            }
            .stroke(LinearGradient(colors: [cRGB(0.5, 0.95, 1), cRGB(0.25, 0.55, 1)], startPoint: .top, endPoint: .bottom),
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
            .shadow(color: cRGB(0.3, 0.85, 1).opacity(0.7), radius: 4)
            ForEach(0..<2) { i in
                Circle().fill(.white).frame(width: 4.5, height: 4.5)
                    .position([cP(37, 39), cP(64, 63)][i]).shadow(color: cRGB(0.4, 0.95, 1), radius: 3)
            }
            ForEach(0..<4) { i in
                CNode(colors: [cRGB(0.8, 1, 1), cRGB(0.15, 0.78, 0.95), cRGB(0.03, 0.36, 0.72)], d: nodes[i].1).position(nodes[i].0)
            }
            CNode(colors: [cRGB(0.85, 0.95, 1), cRGB(0.32, 0.55, 1), cRGB(0.2, 0.16, 0.72)], d: 27).position(hub)
        }
        .cCanvas()
    }
}

/// A small glossy ball whose gradient is scaled to its own size.
struct CNode: View {
    let colors: [Color]
    let d: CGFloat
    var body: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: colors, center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: d * 0.8))
            Circle().fill(RadialGradient(colors: [.white.opacity(0.75), .clear], center: UnitPoint(x: 0.33, y: 0.26), startRadius: 0, endRadius: d * 0.3))
        }
        .frame(width: d, height: d)
        .shadow(color: .black.opacity(0.4), radius: 2, y: 2)
    }
}

struct CTranslateArt: View {
    var body: some View {
        let one = cRound(13, 16, 44, 34, 12).union(Path { p in p.move(to: cP(20, 44)); p.addLine(to: cP(32, 46)); p.addLine(to: cP(17, 58)); p.closeSubpath() })
        let two = cRound(43, 42, 44, 34, 12).union(Path { p in p.move(to: cP(68, 72)); p.addLine(to: cP(80, 70)); p.addLine(to: cP(83, 84)); p.closeSubpath() })
        ZStack {
            CSolid(path: one, colors: [cRGB(0.48, 0.78, 1), cRGB(0.2, 0.4, 0.95)], diagonal: true).cDrop()
            Text("A").font(.system(size: 22, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 1, y: 1).position(x: 35, y: 33)
            CSolid(path: two, colors: [.white, cRGB(0.84, 0.89, 0.97)], diagonal: true, sheen: 0.2).cDrop()
            Text("文").font(.system(size: 21, weight: .bold)).foregroundStyle(LinearGradient(colors: [cRGB(0.3, 0.55, 1), cRGB(0.15, 0.3, 0.85)], startPoint: .top, endPoint: .bottom))
                .position(x: 65, y: 59)
        }
        .cCanvas()
    }
}

struct CCutoutArt: View {
    var body: some View {
        let tile = cRound(16, 16, 68, 68, 14)
        let head = cOval(50, 42, 22, 24)
        let torso = Path { p in
            p.move(to: cP(24, 86)); p.addCurve(to: cP(50, 58), control1: cP(24, 66), control2: cP(36, 58))
            p.addCurve(to: cP(76, 86), control1: cP(64, 58), control2: cP(76, 66)); p.closeSubpath()
        }
        ZStack {
            ZStack {
                Rectangle().fill(Color(white: 0.97))
                ForEach(0..<64) { i in
                    if (i / 8 + i % 8) % 2 == 0 {
                        Rectangle().fill(Color(white: 0.8)).frame(width: 8.5, height: 8.5)
                            .position(x: 16 + 4.25 + CGFloat(i % 8) * 8.5, y: 16 + 4.25 + CGFloat(i / 8) * 8.5)
                    }
                }
            }
            .cCanvas()
            .clipShape(tile)
            .overlay(tile.stroke(.white.opacity(0.6), lineWidth: 1))
            .cDrop(0.35)
            ZStack {
                CSolid(path: torso, colors: [cRGB(1, 0.55, 0.72), cRGB(0.85, 0.18, 0.5)], sheen: 0.35)
                CSolid(path: head, colors: [cRGB(1, 0.6, 0.76), cRGB(0.88, 0.25, 0.55)], sheen: 0.5)
            }
            .clipShape(tile)
            .shadow(color: cRGB(0.9, 0.2, 0.5).opacity(0.45), radius: 4, y: 2)
            head.stroke(cRGB(0.95, 0.3, 0.6), style: StrokeStyle(lineWidth: 1.2, dash: [2.5, 2])).scaleEffect(1.25, anchor: UnitPoint(x: 0.5, y: 0.42))
            CGlyph(symbol: "sparkle", colors: [cRGB(1, 0.75, 0.88), cRGB(0.95, 0.3, 0.6)], size: 14, at: cP(73, 28))
        }
        .cCanvas()
    }
}

// MARK: - Productivity

struct CPrompterArt: View {
    var body: some View {
        let widths: [CGFloat] = [30, 42, 36, 44, 28, 38]
        let alphas: [Double] = [0.22, 0.45, 0.75, 1, 0.55, 0.25]
        ZStack {
            CSolid(path: cRound(16, 16, 68, 68, 13), colors: [Color(white: 0.62), Color(white: 0.3)], sheen: 0.35, rim: 0.6).cDrop()
            cRound(21, 30, 58, 49, 7).fill(LinearGradient(colors: [cRGB(0.12, 0.16, 0.32), cRGB(0.05, 0.07, 0.18)], startPoint: .top, endPoint: .bottom))
            Circle().fill(RadialGradient(colors: [cRGB(0.5, 0.6, 1), cRGB(0.08, 0.08, 0.15)], center: UnitPoint(x: 0.35, y: 0.35), startRadius: 0, endRadius: 4))
                .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1)).frame(width: 8, height: 8).position(x: 50, y: 23)
            Circle().fill(cRGB(1, 0.25, 0.25)).frame(width: 4, height: 4).position(x: 60, y: 23).shadow(color: cRGB(1, 0.2, 0.2), radius: 3)
            ForEach(0..<6) { i in
                let isNow = i == 3
                Capsule().fill(isNow ? AnyShapeStyle(LinearGradient(colors: [cRGB(1, 0.9, 0.5), cRGB(1, 0.75, 0.3)], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Color.white.opacity(alphas[i])))
                    .frame(width: widths[i], height: isNow ? 4 : 3).position(x: 50, y: 36 + CGFloat(i) * 7.2)
            }
            Path { p in p.move(to: cP(24, 54.6 - 3)); p.addLine(to: cP(27.5, 57.6 - 3)); p.addLine(to: cP(24, 60.6 - 3)); p.closeSubpath() }
                .fill(cRGB(1, 0.3, 0.3))
        }
        .cCanvas()
    }
}

struct CCalcArt: View {
    var body: some View {
        ZStack {
            CSolid(path: cRound(24, 12, 52, 76, 13), colors: [cRGB(1, 0.68, 0.32), cRGB(0.9, 0.36, 0.08)], diagonal: true, sheen: 0.4).cDrop()
            CSolid(path: cRound(30, 18, 40, 18, 5), colors: [cRGB(0.3, 0.16, 0.08), cRGB(0.45, 0.24, 0.1)], sheen: 0.12, rim: 0)
            Text("42").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(cRGB(1, 0.88, 0.7))
                .frame(width: 32, alignment: .trailing).position(x: 50, y: 27.5)
            ForEach(0..<9) { i in
                let c = i % 3, r = i / 3
                let op = c == 2
                let x = 30 + CGFloat(c) * 14, y = 41 + CGFloat(r) * 14.5
                ZStack {
                    cRound(x, y + 1.8, 12, 11, 3.5).fill(op ? cRGB(0.4, 0.12, 0.05) : cRGB(0.78, 0.45, 0.25))
                    CSolid(path: cRound(x, y, 12, 11, 3.5), colors: op ? [cRGB(0.7, 0.28, 0.12), cRGB(0.52, 0.18, 0.08)] : [.white, cRGB(1, 0.9, 0.8)], sheen: op ? 0.25 : 0, rim: 0)
                    Text(op ? ["+", "−", "="][r] : "").font(.system(size: 10, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                        .position(x: x + 6, y: y + 5.2)
                }
                .cCanvas()
            }
        }
        .cCanvas()
    }
}

struct CDropClipArt: View {
    var body: some View {
        let widths: [CGFloat] = [40, 34, 40, 26, 36]
        ZStack {
            ZStack {
                CSolid(path: cRound(14, 26, 56, 60, 9), colors: [.white, Color(white: 0.84)], sheen: 0.2, rim: 0.8)
                cRound(19, 44.5, 46, 15, 3).fill(cRGB(0.4, 0.62, 1).opacity(0.45))
                ForEach(0..<5) { i in
                    let sel = i == 1 || i == 2
                    Capsule().fill(sel ? cRGB(0.15, 0.3, 0.75) : Color(white: 0.55).opacity(0.7)).frame(width: widths[i], height: 3.2)
                        .position(x: 22 + widths[i] / 2, y: 38 + CGFloat(i) * 9.5)
                }
                Capsule().fill(cRGB(0.25, 0.45, 1)).frame(width: 2, height: 15).position(x: 19, y: 52)
                Circle().fill(cRGB(0.25, 0.45, 1)).frame(width: 4.5, height: 4.5).position(x: 19, y: 44)
                Capsule().fill(cRGB(0.25, 0.45, 1)).frame(width: 2, height: 15).position(x: 65, y: 52)
                Circle().fill(cRGB(0.25, 0.45, 1)).frame(width: 4.5, height: 4.5).position(x: 65, y: 60)
            }
            .rotationEffect(.degrees(-6))
            .cDrop(0.35)
            CSolid(path: cOval(72, 28, 30, 30).union(Path { p in p.move(to: cP(60, 36)); p.addLine(to: cP(68, 41)); p.addLine(to: cP(56, 47)); p.closeSubpath() }),
                   colors: [cRGB(0.6, 0.55, 1), cRGB(0.32, 0.22, 0.92)], diagonal: true)
                .cDrop()
            CGlyph(symbol: "bolt.fill", colors: [cRGB(1, 0.95, 0.55), cRGB(1, 0.75, 0.2)], size: 16, at: cP(72, 28))
        }
        .cCanvas()
    }
}

// MARK: - Icons

enum OrbitIconsC {
    static let icons: [OrbitIcon] = [
        OrbitIcon(name: "Keep Awake", group: "System", compact: "cup.and.saucer.fill", tint: [cRGB(1, 0.64, 0.44), cRGB(0.84, 0.26, 0.16)], art: AnyView(CCoffeeArt())),
        OrbitIcon(name: "Brightness", group: "System", compact: "sun.max.fill", tint: [cRGB(1, 0.9, 0.4), cRGB(1, 0.58, 0.1)], art: AnyView(CSunArt())),
        OrbitIcon(name: "System Monitor", group: "System", compact: "waveform.path.ecg.rectangle.fill", tint: [cRGB(0.6, 0.52, 1), cRGB(0.3, 0.2, 0.75)], art: AnyView(CMonitorArt())),
        OrbitIcon(name: "Cleaner", group: "System", compact: "bubbles.and.sparkles.fill", tint: [cRGB(1, 0.62, 0.86), cRGB(0.78, 0.25, 0.68)], art: AnyView(CBroomArt())),
        OrbitIcon(name: "Uninstaller", group: "System", compact: "trash.fill", tint: [cRGB(1, 0.48, 0.42), cRGB(0.82, 0.12, 0.18)], art: AnyView(CBinArt())),
        OrbitIcon(name: "Homebrew", group: "System", compact: "terminal.fill", tint: [cRGB(1, 0.76, 0.3), cRGB(0.75, 0.36, 0.06)], art: AnyView(CBottleArt())),
        OrbitIcon(name: "App Updates", group: "System", compact: "arrow.down.app.fill", tint: [cRGB(0.48, 0.8, 1), cRGB(0.16, 0.36, 0.95)], art: AnyView(CUpdateArt())),
        OrbitIcon(name: "Port Manager", group: "System", compact: "powerplug.fill", tint: [cRGB(0.42, 0.96, 0.8), cRGB(0.05, 0.54, 0.55)], art: AnyView(CPortArt())),
        OrbitIcon(name: "Menu Bar Hider", group: "System", compact: "menubar.arrow.up.rectangle", tint: [cRGB(0.7, 0.58, 1), cRGB(0.36, 0.24, 0.85)], art: AnyView(CMenuBarArt())),
        OrbitIcon(name: "Cleaning Mode", group: "System", compact: "sparkles", tint: [cRGB(0.6, 0.88, 1), cRGB(0.18, 0.55, 0.95)], art: AnyView(CCleanKeysArt())),
        OrbitIcon(name: "Smooth Scroll", group: "Input", compact: "computermouse.fill", tint: [cRGB(0.75, 0.68, 1), cRGB(0.42, 0.32, 0.95)], art: AnyView(CMouseArt())),
        OrbitIcon(name: "Super Key", group: "Input", compact: "star.square.fill", tint: [cRGB(0.95, 0.65, 1), cRGB(0.68, 0.28, 0.9)],
                  art: AnyView(CSuperKeyArt())),
        OrbitIcon(name: "iPhone Remote", group: "Devices", compact: "iphone.radiowaves.left.and.right", tint: [cRGB(0.5, 1, 0.62), cRGB(0.08, 0.62, 0.42)], art: AnyView(CRemoteArt())),
        OrbitIcon(name: "MCP", group: "AI", compact: "point.3.filled.connected.trianglepath.dotted", tint: [cRGB(0.5, 0.95, 1), cRGB(0.2, 0.45, 0.95)], art: AnyView(CGraphArt())),
        OrbitIcon(name: "Quick Translate", group: "AI", compact: "translate", tint: [cRGB(0.48, 0.78, 1), cRGB(0.2, 0.4, 0.95)], art: AnyView(CTranslateArt())),
        OrbitIcon(name: "Remove Background", group: "AI", compact: "person.and.background.dotted", tint: [cRGB(1, 0.58, 0.75), cRGB(0.86, 0.2, 0.52)], art: AnyView(CCutoutArt())),
        OrbitIcon(name: "Teleprompter", group: "Productivity", compact: "text.alignleft", tint: [cRGB(1, 0.5, 0.45), cRGB(0.85, 0.2, 0.25)], art: AnyView(CPrompterArt())),
        OrbitIcon(name: "Calculator", group: "Productivity", compact: "plus.forwardslash.minus", tint: [cRGB(1, 0.68, 0.32), cRGB(0.9, 0.36, 0.08)], art: AnyView(CCalcArt())),
        OrbitIcon(name: "DropClip", group: "Productivity", compact: "bolt.horizontal.circle.fill", tint: [cRGB(0.6, 0.55, 1), cRGB(0.32, 0.22, 0.92)], art: AnyView(CDropClipArt())),
    ]
}
