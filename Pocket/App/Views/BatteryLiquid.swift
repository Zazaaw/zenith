// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Liquid filling a battery ring while it charges: two sine waves, a little
/// out of step, risen to the level. Static and flat when `moving` is off
/// (Reduce Motion, off screen), so the level still reads.
struct LiquidFill: View {
    /// 0…1. Animate it to make the liquid rise.
    var level: Double
    var tint: Color
    var moving: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !moving)) { context in
            let t = moving ? context.date.timeIntervalSinceReferenceDate : 0
            ZStack {
                Wave(level: level, phase: t * 2.1 + 1.7, amplitude: moving ? 0.045 : 0, cycles: 1.1)
                    .fill(tint.opacity(0.16))
                Wave(level: level, phase: t * 2.9, amplitude: moving ? 0.032 : 0, cycles: 1.4)
                    .fill(LinearGradient(colors: [tint.opacity(0.34), tint.opacity(0.22)], startPoint: .top, endPoint: .bottom))
            }
        }
        .clipShape(Circle())
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A rectangle's lower part, up to `level`, with a sine wave for its surface.
struct Wave: Shape {
    var level: Double
    var phase: Double
    /// The wave's height as a share of the rect's height.
    var amplitude: Double
    /// Whole waves across the width.
    var cycles: Double

    var animatableData: Double {
        get { level }
        set { level = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let level = min(1, max(0, level))
        // Calmer near empty and full, where the circle narrows.
        let calm = min(1, min(level, 1 - level) * 5 + 0.25)
        let height = rect.height * amplitude * calm
        let surface = rect.maxY - rect.height * level
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        let steps = 24
        for step in 0...steps {
            let fraction = Double(step) / Double(steps)
            let x = rect.minX + rect.width * fraction
            let y = surface + sin(fraction * cycles * 2 * .pi + phase) * height
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A ring of the alert colour swelling out from a low battery and fading,
/// slowly; a still, soft halo when `moving` is off.
struct LowPulse: View {
    var tint: Color
    var moving: Bool
    @State private var out = false

    var body: some View {
        ZStack {
            Circle().fill(tint.opacity(0.08))
            if moving {
                Circle().stroke(tint.opacity(0.6), lineWidth: 2)
                    .scaleEffect(out ? 1.32 : 1)
                    .opacity(out ? 0 : 1)
                    .onAppear {
                        out = false
                        withAnimation(.easeOut(duration: 1.7).repeatForever(autoreverses: false)) { out = true }
                    }
                    .onDisappear { out = false }
            } else {
                Circle().stroke(tint.opacity(0.25), lineWidth: 3).blur(radius: 2).scaleEffect(1.12)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
