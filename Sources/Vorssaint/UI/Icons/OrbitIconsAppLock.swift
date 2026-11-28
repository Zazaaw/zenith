// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

// Zenith fork: App Lock's Orbit icon, in a file of its own. A padlock over an
// app tile, drawn on the 100×100 canvas with the kit's helpers (OrbitIconsSystemAI).

enum OrbitIconsAppLock {
    static let tint = [cRGB(0.62, 0.74, 1), cRGB(0.32, 0.36, 0.78)]

    static let icons: [OrbitIcon] = [
        OrbitIcon(name: "App Lock", group: "Privacy", compact: "lock.app.dashed", tint: tint, art: AnyView(OrbitAppLockArt())),
    ]
}

/// An app's tile, its icons frosted over, with a steel padlock in front.
struct OrbitAppLockArt: View {
    var body: some View {
        let tile = cRound(13, 13, 60, 60, 15)
        let shackle = Path { p in
            p.move(to: cP(55, 62)); p.addLine(to: cP(55, 50))
            p.addArc(center: cP(67, 50), radius: 12, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            p.addLine(to: cP(79, 62))
        }
        let body = cRound(47, 58, 40, 30, 8)
        ZStack {
            // The app: a bright tile with four little icons on it.
            ZStack {
                CSolid(path: tile, colors: [cRGB(0.45, 0.78, 1), cRGB(0.42, 0.32, 0.95)], diagonal: true, sheen: 0.4)
                ForEach(0..<4) { i in
                    let x: CGFloat = 22 + CGFloat(i % 2) * 22, y: CGFloat = 22 + CGFloat(i / 2) * 22
                    cRound(x, y, 18, 18, 5).fill(.white.opacity(i == 0 ? 0.85 : 0.55))
                }
            }
            .cCanvas()
            .cDrop(0.3)
            // Frosted where the padlock keeps it.
            tile.fill(LinearGradient(colors: [.white.opacity(0.05), .white.opacity(0.4)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .cCanvas()
            // The padlock.
            shackle.stroke(LinearGradient(colors: [Color(white: 0.98), Color(white: 0.62)],
                                          startPoint: .top, endPoint: .bottom),
                           style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .cCanvas()
                .shadow(color: .black.opacity(0.35), radius: 1.5, y: 1.5)
            CSolid(path: body, colors: [cRGB(0.72, 0.8, 0.98), cRGB(0.3, 0.36, 0.62)], sheen: 0.5, rim: 0.7)
                .cDrop(0.45)
            cOval(67, 70, 7, 7).fill(cRGB(0.12, 0.14, 0.26)).cCanvas()
            cRound(65.5, 71, 3, 9, 1.5).fill(cRGB(0.12, 0.14, 0.26)).cCanvas()
        }
        .cCanvas()
    }
}
