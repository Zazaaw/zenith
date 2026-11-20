// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import SwiftUI

// Zenith fork: the open island's silhouette. Measured from a reference
// recording of an open island (2x capture, so pixels halve into points):
//
// - The concave shoulders where the island meets the screen's top edge are
//   near-circular, about 27 points across and 27 down.
// - The bottom corners are large and smooth: their profile fits a corner of
//   about 34 points (RMS error under a point), with the gentle entry of a
//   continuous corner rather than a circle's abrupt one.
//
// The open island takes the full flare: its shoulders are circular arcs 27
// points across and 27 down, where upstream's were 14. The extra 13 points
// on each side hang outside the body like a skirt: the open island is that
// much wider and its page that much further in (`NotchLayout.horizontalInset`,
// `NotchLayout.shoulderFlare`), so the body, the page and everything laid out
// inside keep their widths. The bottom corners grow to 34 points and become
// continuous ("smoothed") corners. The closed island, every compact strip
// and the camera geometry draw exactly as before: the new profile only
// arrives as the island grows past a closed strip's height, and eases in
// with that height, so a resize morphs from one to the other and the
// shoulder widens and deepens as the island opens.
//
// Every path has the same elements at every size (three cubics per corner,
// some of them points while a corner is a plain circle), because Core
// Animation interpolates the island's keyframed paths element by element.
//
// The test executable compiles this file (build.sh, TEST_SOURCES): keep it
// free of anything outside SwiftUI and CoreGraphics.

enum ZenithIslandSilhouette {
    /// The open island's bottom corner. Inner surfaces nest inside it
    /// (`ZenithIsland.innerRadius(depth:)`).
    static let openCornerRadius: CGFloat = 34
    /// The open island's shoulder, across and down the screen edge: a
    /// circular arc, as wide as it is deep.
    static let openShoulderWidth: CGFloat = 27
    static let openShoulderDepth: CGFloat = 27
    /// Corner smoothing, 0 for a circular arc and 1 for the longest
    /// continuous entry: about the curve Apple's continuous corners draw.
    static let cornerSmoothing: CGFloat = 0.6
    /// The shoulder stays a plain arc: smoothing hugs the screen edge and
    /// would draw a thinner flare in the same width.
    static let shoulderSmoothing: CGFloat = 0
    /// Surfaces this tall or shorter are closed strips and draw as they did;
    /// at `openHeight` and taller the open profile is complete.
    static let closedHeight: CGFloat = 72
    static let openHeight: CGFloat = 128

    /// How open a surface of `height` reads, from 0 (a closed strip) to 1,
    /// eased so the profile changes gently at both ends of a resize.
    static func openness(height: CGFloat) -> CGFloat {
        guard height.isFinite else { return 0 }
        let t = min(1, max(0, (height - closedHeight) / (openHeight - closedHeight)))
        return t * t * (3 - 2 * t)
    }

    /// The island hanging from the top edge, `shoulder` wide on each side
    /// (`NotchLayout.shoulder(height:)`, flared on an open island), with
    /// bottom corners of `radius` (already scaled to the height).
    static func hangingPath(in rect: CGRect, shoulder: CGFloat, radius: CGFloat) -> Path {
        let width = max(0, rect.width), height = max(0, rect.height)
        let open = openness(height: height)
        let side = max(0, min(shoulder, width / 2))
        // A closed strip's shoulder is as deep as it is wide, as before; an
        // open one reaches `openShoulderDepth` down the screen edge.
        let depth = min(side + max(0, openShoulderDepth - side) * open * (side > 0 ? 1 : 0), height / 2)
        let body = max(0, width - side * 2)
        let bottomBudget = max(0, min(body / 2, height - depth))
        let bottom = max(0, min(radius, height / 2, body / 2, bottomBudget))

        let smoothing = cornerSmoothing * open
        let reach = Corner(radius: bottom, smoothing: smoothing, budget: bottomBudget).extent

        var path = Path()
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x, y: rect.minY + y) }
        path.move(to: point(0, 0))
        path.addLine(to: point(width, 0))
        // Top right: the screen edge turning down into the body's side.
        addCorner(to: &path, corner: point(width - side, 0), start: point(width, 0), end: point(width - side, depth),
                  radius: 1, smoothing: shoulderSmoothing * open, normalised: true)
        path.addLine(to: point(width - side, height - reach))
        addCorner(to: &path, corner: point(width - side, height), start: point(width - side, height - reach),
                  end: point(width - side - reach, height), radius: bottom, smoothing: smoothing, budget: bottomBudget)
        path.addLine(to: point(side + reach, height))
        addCorner(to: &path, corner: point(side, height), start: point(side + reach, height),
                  end: point(side, height - reach), radius: bottom, smoothing: smoothing, budget: bottomBudget)
        path.addLine(to: point(side, depth))
        addCorner(to: &path, corner: point(side, 0), start: point(side, depth), end: point(0, 0),
                  radius: 1, smoothing: shoulderSmoothing * open, normalised: true)
        path.closeSubpath()
        return path
    }

    /// A smoothed corner in its own frame: it starts at (-extent, 0), ends at
    /// (0, extent), and bows toward the origin, the corner it rounds. The
    /// middle is a circular arc of `radius`; the ends ease into the sides
    /// (Figma's corner smoothing). With no smoothing the ends are points
    /// and the arc is the whole quarter circle.
    struct Corner {
        let radius: CGFloat
        let smoothing: CGFloat
        let extent: CGFloat
        let a: CGFloat, b: CGFloat, c: CGFloat, d: CGFloat, arc: CGFloat

        init(radius: CGFloat, smoothing: CGFloat, budget: CGFloat = .infinity) {
            let r = max(0, min(radius.isFinite ? radius : 0, budget))
            var xi = min(1, max(0, smoothing.isFinite ? smoothing : 0))
            if r > 0, budget.isFinite { xi = min(xi, max(0, budget / r - 1)) }
            self.radius = r
            self.smoothing = xi
            let p = (1 + xi) * r
            let arcDegrees = 90 * (1 - xi)
            let arc = sin(arcDegrees / 2 * .pi / 180) * r * CGFloat(2).squareRoot()
            let alpha = (90 - arcDegrees) / 2
            let c = r * tan(alpha / 2 * .pi / 180) * cos(alpha * .pi / 180)
            let d = c * tan(alpha * .pi / 180)
            let b = max(0, (p - arc - c - d) / 3)
            extent = p
            self.arc = arc
            self.a = 2 * b
            self.b = b
            self.c = c
            self.d = d
        }

        /// The three cubics after the start point, each as (control 1, control 2, end).
        var segments: [(CGPoint, CGPoint, CGPoint)] {
            let p = extent, r = radius
            let start = CGPoint(x: -p, y: 0)
            let p1 = CGPoint(x: start.x + a + b + c, y: d)
            let p2 = CGPoint(x: p1.x + arc, y: p1.y + arc)
            let end = CGPoint(x: 0, y: p)
            let first = (CGPoint(x: start.x + a, y: 0), CGPoint(x: start.x + a + b, y: 0), p1)
            // The arc's centre is (-r, r); a point at angle φ is centre + r(sin φ, -cos φ).
            let alpha = 45 * smoothing * .pi / 180
            let sweep = CGFloat.pi / 2 - 2 * alpha
            let k = 4 / 3 * tan(sweep / 4) * r
            let middle = (CGPoint(x: p1.x + k * cos(alpha), y: p1.y + k * sin(alpha)),
                          CGPoint(x: p2.x - k * sin(alpha), y: p2.y - k * cos(alpha)), p2)
            let last = (CGPoint(x: p2.x + d, y: p2.y + c), CGPoint(x: p2.x + d, y: p2.y + b + c), end)
            return [first, middle, last]
        }
    }

    /// Adds a corner from `start` to `end` that bows toward `corner`.
    /// `normalised` draws a unit corner stretched onto the two legs, for a
    /// shoulder whose depth differs from its width.
    static func addCorner(to path: inout Path, corner: CGPoint, start: CGPoint, end: CGPoint,
                          radius: CGFloat, smoothing: CGFloat, budget: CGFloat = .infinity, normalised: Bool = false) {
        let shape = normalised ? Corner(radius: 1, smoothing: smoothing) : Corner(radius: radius, smoothing: smoothing, budget: budget)
        let extent = shape.extent
        let legA = CGVector(dx: start.x - corner.x, dy: start.y - corner.y)
        let legB = CGVector(dx: end.x - corner.x, dy: end.y - corner.y)
        func map(_ local: CGPoint) -> CGPoint {
            guard extent > 0 else { return corner }
            let u = -local.x / extent, v = local.y / extent
            return CGPoint(x: corner.x + u * legA.dx + v * legB.dx, y: corner.y + u * legA.dy + v * legB.dy)
        }
        for (control1, control2, to) in shape.segments {
            path.addCurve(to: extent > 0 ? map(to) : end,
                          control1: extent > 0 ? map(control1) : start,
                          control2: extent > 0 ? map(control2) : end)
        }
    }
}
