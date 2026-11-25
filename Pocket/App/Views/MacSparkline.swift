// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// A health reading's last minutes as a soft line over a gradient fill, the
/// newest point a dot that pulses while the tile is on screen. The heights
/// (0…1, a fixed count) glide to their new places when a reading arrives.
struct Sparkline: View {
    let heights: [Double]
    let tint: Color
    /// Whether the newest point may pulse (on screen, Reduce Motion off).
    var pulses = true

    var body: some View {
        let points = Self.points(heights)
        GeometryReader { geo in
            let last = points.last ?? CGPoint(x: 1, y: 0.5)
            ZStack(alignment: .topLeading) {
                SparkShape(points: AnimatablePoints(points), closed: true)
                    .fill(LinearGradient(colors: [tint.opacity(0.30), tint.opacity(0)], startPoint: .top, endPoint: .bottom))
                SparkShape(points: AnimatablePoints(points), closed: false)
                    .stroke(tint, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                SparkDot(tint: tint, pulses: pulses)
                    .position(x: last.x * geo.size.width, y: last.y * geo.size.height)
            }
        }
        .animation(Motion.spring, value: heights)
        .accessibilityHidden(true)
    }

    /// Heights to points across the width, with room above and below for the
    /// line's width and the dot.
    static func points(_ heights: [Double]) -> [CGPoint] {
        guard heights.count >= 2 else { return [] }
        let top = 0.14, bottom = 0.9
        return heights.enumerated().map { index, height in
            CGPoint(x: Double(index) / Double(heights.count - 1), y: bottom - (bottom - top) * min(1, max(0, height)))
        }
    }
}

/// The line through the points (in shares of the frame), smoothed through
/// their midpoints; closed, it runs down to the bottom for the fill.
private struct SparkShape: Shape {
    var points: AnimatablePoints
    let closed: Bool

    var animatableData: AnimatablePoints {
        get { points }
        set { points = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let scaled = points.points.map { CGPoint(x: rect.minX + $0.x * rect.width, y: rect.minY + $0.y * rect.height) }
        var path = Path()
        guard let first = scaled.first, let last = scaled.last, scaled.count >= 2 else { return path }
        path.move(to: first)
        for index in 1..<scaled.count {
            let previous = scaled[index - 1], point = scaled[index]
            let middle = CGPoint(x: (previous.x + point.x) / 2, y: (previous.y + point.y) / 2)
            path.addQuadCurve(to: middle, control: previous)
            if index == scaled.count - 1 { path.addQuadCurve(to: point, control: middle) }
        }
        if closed {
            path = Path { fill in
                fill.addPath(path)
                fill.addLine(to: CGPoint(x: last.x, y: rect.maxY))
                fill.addLine(to: CGPoint(x: first.x, y: rect.maxY))
                fill.closeSubpath()
            }
        }
        return path
    }
}

/// The newest reading: a dot, and a ring that keeps swelling out of it.
private struct SparkDot: View {
    let tint: Color
    let pulses: Bool
    @State private var out = false

    var body: some View {
        ZStack {
            if pulses {
                Circle().fill(tint.opacity(0.35))
                    .frame(width: 6, height: 6)
                    .scaleEffect(out ? 2.8 : 1)
                    .opacity(out ? 0 : 1)
                    .onAppear {
                        out = false
                        withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { out = true }
                    }
                    .onDisappear { out = false }
            }
            Circle().fill(tint).frame(width: 6, height: 6)
                .overlay(Circle().strokeBorder(K.card, lineWidth: 1.2))
        }
        .frame(width: 18, height: 18)
    }
}
