// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

// Zenith fork: the Privacy shelf's icons, drawn on the shared 100×100 canvas
// with Set C's helpers (cRGB, cRound, CSolid).

/// Privacy Blur: a chat window, its conversation clear on the left and
/// frosted over on the right, with the frost's edge catching the light.
struct PrivacyBlurIconArt: View {
    private static let ice = [cRGB(0.6, 0.9, 1), cRGB(0.22, 0.48, 0.9)]

    var body: some View {
        let window = cRound(12, 20, 76, 62, 12)
        let frost = Path { p in
            p.move(to: cP(54, 20)); p.addLine(to: cP(76, 20))
            p.addArc(center: cP(76, 32), radius: 12, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            p.addLine(to: cP(88, 70))
            p.addArc(center: cP(76, 70), radius: 12, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            p.addLine(to: cP(46, 82)); p.closeSubpath()
        }
        ZStack {
            // The window.
            CSolid(path: window, colors: [cRGB(0.98, 0.99, 1), cRGB(0.8, 0.85, 0.93)], sheen: 0.3, rim: 0.6)
                .cDrop(0.4)
            // Its title bar dots.
            ForEach(0..<3) { i in
                Circle().fill([cRGB(1, 0.4, 0.38), cRGB(1, 0.75, 0.25), cRGB(0.35, 0.82, 0.4)][i])
                    .frame(width: 4.5, height: 4.5).position(x: 21 + CGFloat(i) * 7, y: 27)
            }
            // The conversation: their bubble and mine.
            Capsule().fill(cRGB(0.86, 0.89, 0.95)).frame(width: 30, height: 9).position(x: 34, y: 42)
            Capsule().fill(cRGB(0.86, 0.89, 0.95)).frame(width: 22, height: 9).position(x: 30, y: 54)
            Capsule().fill(LinearGradient(colors: [cRGB(0.4, 0.88, 0.55), cRGB(0.15, 0.68, 0.4)],
                                          startPoint: .top, endPoint: .bottom))
                .frame(width: 34, height: 10).position(x: 58, y: 66)
            Capsule().fill(cRGB(0.86, 0.89, 0.95)).frame(width: 28, height: 9).position(x: 66, y: 44)
            // The frost over the right half: soft blobs where the text was.
            ZStack {
                frost.fill(LinearGradient(colors: [cRGB(0.75, 0.92, 1).opacity(0.92), cRGB(0.45, 0.68, 0.98).opacity(0.92)],
                                          startPoint: .topLeading, endPoint: .bottomTrailing))
                ForEach(0..<3) { i in
                    Capsule().fill(.white.opacity(0.4))
                        .frame(width: [20, 14, 18][i], height: 6)
                        .position(x: [70, 74, 66][i], y: [38, 52, 66][i])
                }
                frost.fill(LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0)],
                                          startPoint: .top, endPoint: .center))
            }
            .cCanvas()
            .clipShape(window)
            // The frost's leading edge, catching the light.
            Path { p in p.move(to: cP(54, 21)); p.addLine(to: cP(46.5, 81)) }
                .stroke(LinearGradient(colors: [.white, Self.ice[0].opacity(0.4)], startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                .cCanvas()
                .shadow(color: Self.ice[0].opacity(0.9), radius: 3)
            CGlyph(symbol: "eye.slash.fill", colors: [.white, cRGB(0.85, 0.95, 1)], size: 13, at: cP(74, 72))
        }
        .cCanvas()
    }
}

enum OrbitIconsPrivacy {
    static let icons: [OrbitIcon] = [
        OrbitIcon(name: "Privacy Blur", group: "Privacy", compact: "eye.slash.fill",
                  tint: [cRGB(0.6, 0.9, 1), cRGB(0.22, 0.48, 0.9)], art: AnyView(PrivacyBlurIconArt())),
    ]
}
