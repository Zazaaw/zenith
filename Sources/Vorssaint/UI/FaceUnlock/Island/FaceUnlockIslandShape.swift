// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// The corners follow Glance by Jonathan Zhou (MIT), https://github.com/jonnyoo/glance.

import CoreGraphics
import SwiftUI

// Zenith fork: the padlock island's outline while it shows face unlock (the
// armed pill with its Face ID glyph, the scan and its results, the Touch ID
// line): Glance's continuous (squircle) bottom corners under Zenith's own
// shoulders. Every other island keeps ZenithIslandSilhouette's corners.
// `continuous` blends one into the other (0 Zenith's, 1 Glance's), so the
// scan becoming the welcome eases its corners instead of jumping. Both
// corners are three cubics, blended point by point.
//
// The test executable compiles this file (build.sh, TEST_SOURCES): keep it
// free of anything outside SwiftUI and CoreGraphics.

enum FaceUnlockIslandSilhouette {
    /// Apple's continuous corner reaches 1.528 times its radius along each side.
    static let reach: CGFloat = 1.528
    /// Glance's corner: 12 points on a closed pill, 60 on the open panel.
    static let closedRadius: CGFloat = 12
    static let openRadius: CGFloat = 60
    /// The heights over which the corner opens, from the closed pill up.
    static let closedHeight: CGFloat = 38
    static let openSpan: CGFloat = 140
    /// The padding inner elements keep from the outline (concentric radius).
    static let padding: CGFloat = 20

    /// How open the island reads at `height`, 0 to 1.
    static func openness(height: CGFloat) -> CGFloat {
        guard height.isFinite else { return 0 }
        return min(1, max(0, (height - closedHeight) / openSpan))
    }

    /// The squircle's radius for a surface `size` whose shoulders take `depth`
    /// down its sides and leave `body` across: 12 → 60 with the height, kept
    /// on the straight edges (the reach never runs past them).
    static func radius(height: CGFloat, body: CGFloat, depth: CGFloat) -> CGFloat {
        let wanted = closedRadius + (openRadius - closedRadius) * openness(height: height)
        return max(0, min(wanted, (height - depth) / reach, (body / 2) / reach))
    }

    /// An element `padding` in from the outline's bottom corner, concentric with it.
    static func innerRadius(height: CGFloat) -> CGFloat {
        max(8, closedRadius + (openRadius - closedRadius) * openness(height: height) - padding)
    }

    /// The island hanging from the top edge with Zenith's shoulders (as
    /// ZenithIslandSilhouette draws them) and bottom corners blended from
    /// Zenith's (`radius`, its smoothing) to Glance's squircle by `continuous`.
    static func path(in rect: CGRect, shoulder: CGFloat, radius: CGFloat, continuous: CGFloat) -> Path {
        typealias Z = ZenithIslandSilhouette
        let width = max(0, rect.width), height = max(0, rect.height)
        let open = Z.openness(height: height)
        let side = max(0, min(shoulder, width / 2))
        let depth = min(side + max(0, Z.openShoulderDepth - side) * open * (side > 0 ? 1 : 0), height / 2)
        let body = max(0, width - side * 2)
        let budget = max(0, min(body / 2, height - depth))
        let zenith = Z.Corner(radius: max(0, min(radius, height / 2, body / 2, budget)), smoothing: Z.cornerSmoothing * open,
                              budget: budget)
        let blend = min(1, max(0, continuous.isFinite ? continuous : 0))
        let glance = Self.radius(height: height, body: body, depth: depth)
        let corner = blended(zenith.segments, extent: zenith.extent, squircle(glance), extent: glance * reach, by: blend)

        var path = Path()
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x, y: rect.minY + y) }
        path.move(to: point(0, 0))
        path.addLine(to: point(width, 0))
        Z.addCorner(to: &path, corner: point(width - side, 0), start: point(width, 0), end: point(width - side, depth),
                    radius: 1, smoothing: Z.shoulderSmoothing * open, normalised: true)
        // Bottom right: local (u up the side, v left along the bottom) from the corner.
        let right = { (u: CGFloat, v: CGFloat) in point(width - side - v, height - u) }
        path.addLine(to: right(corner.extent, 0))
        for (c1, c2, to) in corner.segments { path.addCurve(to: right(to.x, to.y), control1: right(c1.x, c1.y), control2: right(c2.x, c2.y)) }
        // Bottom left: local (u right along the bottom, v up the side).
        let left = { (u: CGFloat, v: CGFloat) in point(side + u, height - v) }
        path.addLine(to: left(corner.extent, 0))
        for (c1, c2, to) in corner.segments { path.addCurve(to: left(to.x, to.y), control1: left(c1.x, c1.y), control2: left(c2.x, c2.y)) }
        path.addLine(to: point(side, depth))
        Z.addCorner(to: &path, corner: point(side, 0), start: point(side, depth), end: point(0, 0),
                    radius: 1, smoothing: Z.shoulderSmoothing * open, normalised: true)
        path.closeSubpath()
        return path
    }

    /// A corner in leg coordinates: (distance along the first side from the
    /// corner, distance along the second), from (extent, 0) to (0, extent).
    struct Legs {
        let extent: CGFloat
        let segments: [(CGPoint, CGPoint, CGPoint)]
    }

    /// Apple's continuous corner of `radius` (the curve Glance draws), as three cubics.
    static func squircle(_ r: CGFloat) -> [(CGPoint, CGPoint, CGPoint)] {
        func p(_ u: CGFloat, _ v: CGFloat) -> CGPoint { CGPoint(x: u * r, y: v * r) }
        return [(p(1.0885, 0), p(0.8684, 0), p(0.6315, 0.0749)),
                (p(0.3728, 0.1691), p(0.1691, 0.3728), p(0.0749, 0.6315)),
                (p(0, 0.8684), p(0, 1.0885), p(0, reach))]
    }

    /// Zenith's corner (in its local frame: from (-extent, 0) to (0, extent))
    /// and the squircle (in legs), blended into legs.
    static func blended(_ zenith: [(CGPoint, CGPoint, CGPoint)], extent zenithExtent: CGFloat,
                        _ squircle: [(CGPoint, CGPoint, CGPoint)], extent squircleExtent: CGFloat, by t: CGFloat) -> Legs {
        func legs(_ local: CGPoint) -> CGPoint { CGPoint(x: -local.x, y: local.y) }
        func mix(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t) }
        let segments = zip(zenith, squircle).map { z, s in
            (mix(legs(z.0), s.0), mix(legs(z.1), s.1), mix(legs(z.2), s.2))
        }
        return Legs(extent: zenithExtent + (squircleExtent - zenithExtent) * t, segments: segments)
    }
}

/// Zenith fork: the corner style easing from `from` to `to` (0 Zenith's,
/// 1 Glance's) over `duration` from `begin` (reference date seconds), drawn
/// per frame with the island's own motion.
struct FaceUnlockCornerBlend: Equatable {
    static let duration: TimeInterval = 0.35
    var from: CGFloat
    var to: CGFloat
    var begin: TimeInterval

    func value(at time: TimeInterval) -> CGFloat {
        guard time.isFinite, begin.isFinite else { return to }
        let t = min(1, max(0, (time - begin) / Self.duration))
        let eased = CGFloat(t * t * (3 - 2 * t))
        return from + (to - from) * eased
    }
}

/// Zenith fork: the face unlock island's outline, its corner style animating.
struct FaceUnlockIslandShape: Shape {
    var radius: CGFloat
    var continuous: CGFloat
    var animatableData: CGFloat {
        get { continuous }
        set { continuous = newValue }
    }

    func path(in rect: CGRect) -> Path {
        FaceUnlockIslandSilhouette.path(in: CGRect(origin: .zero, size: rect.size),
                                        shoulder: NotchLayout.shoulder(height: rect.height), radius: radius, continuous: continuous)
    }
}
