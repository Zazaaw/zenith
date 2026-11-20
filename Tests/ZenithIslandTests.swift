// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import SwiftUI

// Zenith fork: the open island's silhouette, its concentric radii, the
// morph's reach and the modules' colours.
enum ZenithIslandTests {
    static func run(_ suite: TestSuite) {
        closedStripsUnchanged(suite)
        openProfile(suite)
        morphableKeyframes(suite)
        concentricRadii(suite)
        morphReach(suite)
        palette(suite)
    }

    /// Upstream's silhouette, as it drew before the fork reshaped the open island.
    private static func upstreamPath(_ size: CGSize) -> Path {
        let rect = CGRect(origin: .zero, size: size)
        let shoulder = NotchLayout.shoulder(height: rect.height)
        // Upstream's corner: 0.34 of the height, up to 28 points.
        let bottom = min(min(28, rect.height * 0.34), rect.height / 2, (rect.width - shoulder * 2) / 2)
        let tangent: CGFloat = 0.55228475
        var path = Path()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addCurve(to: CGPoint(x: rect.width - shoulder, y: shoulder),
                      control1: CGPoint(x: rect.width - shoulder * tangent, y: 0),
                      control2: CGPoint(x: rect.width - shoulder, y: shoulder * (1 - tangent)))
        path.addLine(to: CGPoint(x: rect.width - shoulder, y: rect.height - bottom))
        path.addCurve(to: CGPoint(x: rect.width - shoulder - bottom, y: rect.height),
                      control1: CGPoint(x: rect.width - shoulder, y: rect.height - bottom * (1 - tangent)),
                      control2: CGPoint(x: rect.width - shoulder - bottom * (1 - tangent), y: rect.height))
        path.addLine(to: CGPoint(x: shoulder + bottom, y: rect.height))
        path.addCurve(to: CGPoint(x: shoulder, y: rect.height - bottom),
                      control1: CGPoint(x: shoulder + bottom * (1 - tangent), y: rect.height),
                      control2: CGPoint(x: shoulder, y: rect.height - bottom * (1 - tangent)))
        path.addLine(to: CGPoint(x: shoulder, y: shoulder))
        path.addCurve(to: .zero, control1: CGPoint(x: shoulder, y: shoulder * (1 - tangent)),
                      control2: CGPoint(x: shoulder * tangent, y: 0))
        path.closeSubpath()
        return path
    }

    private static func zenithPath(_ size: CGSize) -> Path {
        NotchShape(attached: true, radius: NotchLayout.surfaceRadius(height: size.height))
            .path(in: CGRect(origin: .zero, size: size))
    }

    private static func closedStripsUnchanged(_ suite: TestSuite) {
        for height: CGFloat in [16, 22, 24, 32, 37, 44, 64, ZenithIslandSilhouette.closedHeight] {
            for width: CGFloat in [120, 240, 420] {
                let size = CGSize(width: width, height: height)
                let old = upstreamPath(size), new = zenithPath(size)
                var differs = 0
                for x in stride(from: CGFloat(0.25), to: width, by: 1.5) {
                    for y in stride(from: CGFloat(0.25), to: height, by: 0.75) {
                        let point = CGPoint(x: x, y: y)
                        if old.contains(point) != new.contains(point) { differs += 1 }
                    }
                }
                suite.expect(differs == 0, "a \(Int(height))-point strip keeps upstream's silhouette exactly (\(differs) points differ)")
            }
        }
    }

    private static func openProfile(_ suite: TestSuite) {
        let size = CGSize(width: 480, height: 260)
        let open = zenithPath(size), old = upstreamPath(size)
        let side = NotchLayout.shoulder
        // The shoulder now flares further down the screen edge.
        let flare = CGPoint(x: side - 1.5, y: 10)
        suite.expect(open.contains(flare) && !old.contains(flare),
                     "the open island's shoulder runs deeper down the screen edge")
        suite.expect(abs(open.boundingRect.width - size.width) < 0.01 && abs(open.boundingRect.height - size.height) < 0.01,
                     "the open island keeps its window's width and height")
        // The body keeps its sides: content inset from them is not cut.
        suite.expect(open.contains(CGPoint(x: side + 0.5, y: size.height / 2))
                     && !open.contains(CGPoint(x: side - 0.5, y: size.height / 2)),
                     "the open island's body keeps its width")
        // The bottom corner is the larger, smoothed one.
        let nearCorner = CGPoint(x: side + 8.3, y: size.height - 10)
        suite.expect(old.contains(nearCorner) && !open.contains(nearCorner),
                     "the open island's bottom corners are larger than upstream's")
        let content = CGPoint(x: NotchLayout.horizontalInset, y: size.height - NotchLayout.bottomInset)
        suite.expect(open.contains(content), "a page's bottom corner stays inside the larger corner")
        suite.expect(ZenithIslandSilhouette.openness(height: 32) == 0 && ZenithIslandSilhouette.openness(height: 400) == 1
                     && ZenithIslandSilhouette.openness(height: .nan) == 0,
                     "the open profile reaches only open islands")
    }

    /// Core Animation interpolates the island's keyframed outlines element by
    /// element, so every size must draw the same elements.
    private static func morphableKeyframes(_ suite: TestSuite) {
        func elements(_ size: CGSize) -> [String] {
            var kinds: [String] = []
            zenithPath(size).forEach { element in
                switch element {
                case .move: kinds.append("m")
                case .line: kinds.append("l")
                case .quadCurve: kinds.append("q")
                case .curve: kinds.append("c")
                case .closeSubpath: kinds.append("z")
                }
            }
            return kinds
        }
        let reference = elements(CGSize(width: 200, height: 32))
        for size in [CGSize(width: 200, height: 0), CGSize(width: 0, height: 0), CGSize(width: 300, height: 90),
                     CGSize(width: 520, height: 300), CGSize(width: 40, height: 400)] {
            suite.expect(elements(size) == reference, "an outline of \(size) keeps the elements every resize interpolates")
        }
        var finite = true
        zenithPath(CGSize(width: 0, height: 0)).forEach { element in
            if case .curve(let to, let one, let two) = element {
                finite = finite && [to, one, two].allSatisfy { $0.x.isFinite && $0.y.isFinite }
            }
        }
        suite.expect(finite, "an island drawn from nothing has no undefined points")
    }

    private static func concentricRadii(_ suite: TestSuite) {
        suite.expect(ZenithIsland.islandRadius == ZenithIslandSilhouette.openCornerRadius,
                     "inner surfaces nest in the island's own corner")
        suite.expect(ZenithIsland.cardRadius == ZenithIsland.islandRadius - ZenithIsland.pageInset,
                     "a card on the page runs parallel to the island's corner")
        suite.expect(ZenithIsland.nestedRadius(padding: 8) == ZenithIsland.cardRadius - 8,
                     "something inside a card runs parallel to the card")
        suite.expect(ZenithIsland.innerRadius(depth: 400) == ZenithRadius.small
                     && ZenithIsland.innerRadius(depth: .nan) == ZenithRadius.small
                     && ZenithIsland.innerRadius(depth: -4) == ZenithIsland.islandRadius,
                     "an inner radius never pinches to a point or grows past its outer one")
        suite.expect(ZenithIsland.radius(18) == ZenithIsland.cardRadius,
                     "upstream's large island cards take the concentric radius")
    }

    private static func morphReach(_ suite: TestSuite) {
        suite.expect(!ZenithMorph.morphs(height: 32) && !ZenithMorph.morphs(height: 64) && ZenithMorph.morphs(height: 220),
                     "open pages morph, while a closed strip's reading only fades")
        suite.expect(ZenithMorph.blur == 10 && ZenithMorph.scale == 0.97
                     && ZenithMorph.layerPeak > 0 && ZenithMorph.layerPeak < 1
                     && ZenithMorph.layerDuration <= ZenithMotion.slow,
                     "the morph blurs to 10, dips to 97% and lasts no longer than a large transform")
    }

    private static func palette(_ suite: TestSuite) {
        let hues = NotchModule.allCases.map(ZenithIslandPalette.hex)
        suite.expect(Set(hues).count == NotchModule.allCases.count, "every module wears a colour of its own")
        suite.expect(NotchModule.timer.zenithTint == ZenithIslandPalette.color(.timer), "a module reads its colour from the palette")
    }
}
