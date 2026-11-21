// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AVFoundation
import CoreGraphics
import SwiftUI

// Zenith fork: the open island's silhouette and its shoulders' skirt, its
// concentric radii, the morph's reach, the modules' colours and the Camera
// page starting its mirror.
enum ZenithIslandTests {
    static func run(_ suite: TestSuite) {
        closedStripsUnchanged(suite)
        openProfile(suite)
        openShoulder(suite)
        shoulderSkirt(suite)
        morphableKeyframes(suite)
        concentricRadii(suite)
        morphReach(suite)
        palette(suite)
        cameraAutoStart(suite)
    }

    /// Upstream's silhouette, as it drew before the fork reshaped the open island.
    private static func upstreamPath(_ size: CGSize) -> Path {
        let rect = CGRect(origin: .zero, size: size)
        // Upstream's shoulder: 0.19 of the height, up to 14 points.
        let shoulder = min(14, rect.height * 0.19)
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
        // Upstream's 480-point island and Zenith's around the same body: the
        // shoulders' flare hangs outside it on both sides.
        let flare = NotchLayout.shoulderFlare
        let body = CGSize(width: 480, height: 260)
        let size = CGSize(width: body.width + flare * 2, height: body.height)
        let open = zenithPath(size), upstream = upstreamPath(body)
        func old(_ point: CGPoint) -> Bool { upstream.contains(CGPoint(x: point.x - flare, y: point.y)) }
        let side = NotchLayout.shoulder(height: size.height)
        suite.expect(abs(flare - 13) < 0.001 && side == ZenithIslandSilhouette.openShoulderWidth,
                     "the open island's shoulder is 27 points across, 13 past upstream's")
        // The shoulder flares further out along and down the screen edge.
        let deeper = CGPoint(x: flare + 12.5, y: 10), skirt = CGPoint(x: 8, y: 1)
        suite.expect(open.contains(deeper) && !old(deeper) && open.contains(skirt) && skirt.x < flare,
                     "the open island's shoulder flares past upstream's, outside its body")
        suite.expect(abs(open.boundingRect.width - size.width) < 0.01 && abs(open.boundingRect.height - size.height) < 0.01,
                     "the open island fills its window's width and height")
        // The body keeps upstream's sides: content inset from them is not cut.
        let middle = size.height / 2
        suite.expect(open.contains(CGPoint(x: side + 0.5, y: middle)) && !open.contains(CGPoint(x: side - 0.5, y: middle))
                     && old(CGPoint(x: side + 0.5, y: middle)) && !old(CGPoint(x: side - 0.5, y: middle))
                     && !open.contains(CGPoint(x: size.width - side + 0.5, y: middle))
                     && open.contains(CGPoint(x: size.width - side - 0.5, y: middle)),
                     "the open island's body keeps upstream's width")
        // The bottom corner is the larger, smoothed one.
        let nearCorner = CGPoint(x: side + 8.3, y: size.height - 10)
        suite.expect(old(nearCorner) && !open.contains(nearCorner),
                     "the open island's bottom corners are larger than upstream's")
        let content = CGPoint(x: NotchLayout.horizontalInset, y: size.height - NotchLayout.bottomInset)
        suite.expect(open.contains(content), "a page's bottom corner stays inside the larger corner")
        suite.expect(ZenithIslandSilhouette.openness(height: 32) == 0 && ZenithIslandSilhouette.openness(height: 400) == 1
                     && ZenithIslandSilhouette.openness(height: .nan) == 0,
                     "the open profile reaches only open islands")
    }

    /// The open shoulder as the reference draws it, a circle about 27 points
    /// across and down, which grows from upstream's as the island opens.
    private static func openShoulder(_ suite: TestSuite) {
        let size = CGSize(width: 506, height: 260)
        let open = zenithPath(size)
        // Where the island starts along a row, from the screen's edge inward.
        func edge(_ y: CGFloat) -> CGFloat {
            var low: CGFloat = 0, high: CGFloat = 60
            for _ in 0..<40 {
                let middle = (low + high) / 2
                if open.contains(CGPoint(x: middle, y: y)) { high = middle } else { low = middle }
            }
            return high
        }
        // The curves themselves, sampled: `contains` flattens them coarsely.
        let radius = ZenithIslandSilhouette.openShoulderWidth
        var worst: CGFloat = 0, sides = Set<Bool>(), current = CGPoint.zero
        open.forEach { element in
            switch element {
            case .move(let to), .line(let to): current = to
            case .curve(let to, let one, let two):
                let points = [current, one, two, to]
                let left = points.allSatisfy { $0.x <= radius + 0.001 && $0.y <= radius + 0.001 }
                let right = points.allSatisfy { $0.x >= size.width - radius - 0.001 && $0.y <= radius + 0.001 }
                if left || right, points.contains(where: { $0 != current }) {
                    // Each shoulder bows around a centre on the screen's edge, 27 points down.
                    let centre = CGPoint(x: left ? 0 : size.width, y: radius)
                    for step in 0...24 {
                        let t = CGFloat(step) / 24, s = 1 - t
                        let x = s * s * s * points[0].x + 3 * s * s * t * points[1].x + 3 * s * t * t * points[2].x + t * t * t * points[3].x
                        let y = s * s * s * points[0].y + 3 * s * s * t * points[1].y + 3 * s * t * t * points[2].y + t * t * t * points[3].y
                        worst = max(worst, abs(hypot(x - centre.x, y - centre.y) - radius))
                    }
                    sides.insert(left)
                }
                current = to
            default: break
            }
        }
        suite.expect(sides.count == 2 && worst < 0.1,
                     "both open shoulders are 27-point circles, as wide as they are deep (off by \(worst))")
        suite.expect(abs(edge(radius + 1) - radius) < 0.05 && abs(edge(radius - 3) - radius) > 0.1,
                     "the open shoulder reaches 27 points down the screen edge before the body runs straight")
        suite.expect(ZenithIslandSilhouette.openShoulderDepth == ZenithIslandSilhouette.openShoulderWidth,
                     "the open shoulder is circular")
        // Closing, the flare narrows with the height, continuously, to none
        // on a closed strip, and the outline keeps its body there.
        var previous = NotchLayout.shoulder(height: 60), smooth = true, monotonic = true, bodies = true
        for height in stride(from: CGFloat(60.5), through: 140, by: 0.5) {
            let shoulder = NotchLayout.shoulder(height: height)
            smooth = smooth && shoulder - previous <= 0.3
            monotonic = monotonic && shoulder >= previous
            previous = shoulder
            if Int(height * 2) % 20 == 0 {
                let path = zenithPath(CGSize(width: 506, height: height))
                let y = height * 0.45
                bodies = bodies && path.contains(CGPoint(x: shoulder + 0.3, y: y))
                    && !path.contains(CGPoint(x: shoulder - 0.3, y: y))
            }
        }
        suite.expect(smooth && monotonic, "the shoulder widens smoothly as the island opens and narrows as it closes")
        suite.expect(bodies, "every height of the morph draws its body where its shoulder ends")
        suite.expect(NotchLayout.shoulder(height: ZenithIslandSilhouette.closedHeight)
                        == NotchLayout.plainShoulder(height: ZenithIslandSilhouette.closedHeight)
                     && NotchLayout.shoulderFlare(height: 32) == 0
                     && NotchLayout.shoulder(height: ZenithIslandSilhouette.openHeight) == ZenithIslandSilhouette.openShoulderWidth,
                     "closed strips keep upstream's shoulder and open islands take the full one")
    }

    /// The flare is a skirt: the island grows around its body, and its pages
    /// keep the widths and places they had.
    private static func shoulderSkirt(_ suite: TestSuite) {
        let flare = NotchLayout.shoulderFlare
        // Zenith fork: the page sits the open island's one padding inside its body.
        let inset = NotchLayout.shoulder + ZenithIslandInset.padding
        suite.expect(NotchLayout.horizontalInset == inset + flare
                     && NotchLayout.horizontalInset - NotchLayout.shoulder(height: 300) == ZenithIsland.pageInset
                     && ZenithIsland.pageInset == ZenithIslandInset.padding
                     && NotchLayout.bottomInset == ZenithIslandInset.padding,
                     "a page sits one padding inside the open island's body and above its bottom, past the wider shoulder")
        let screen = CGRect(x: 0, y: 0, width: 1710, height: 1112)
        var widths = true, bodies = true
        for camera: CGFloat in [0, 185, 210] {
            for layout: NotchSize in [.compact, .spacious, .custom] {
                for custom: Double in [360, 480, 600] where layout == .custom || custom == 480 {
                    let geometry = NotchGeometry(screen: screen, safeAreaTop: camera > 0 ? 32 : 0, cameraWidth: camera,
                                                 layout: layout, customWidth: custom, customHeight: 480,
                                                 silhouette: camera == 0 ? .capsule : .notch)
                    let chosen = NotchLayout.preferredWidth(layout, custom: CGFloat(custom))
                    let size = geometry.expanded
                    // Zenith fork: the padding's growth past upstream's inset hangs outside the page too.
                    let growth = NotchLayout.paddingGrowth
                    widths = widths && geometry.expandedWidth == chosen + (flare + growth) * 2
                        && NotchLayout.openGrowth == flare + growth && growth == inset - 28
                        && geometry.contentWidth == chosen - 56
                        && geometry.contentSize(for: size).width == chosen - 56
                    bodies = bodies && size.width - NotchLayout.shoulder(height: size.height) * 2 == chosen - 28 + growth * 2
                }
            }
        }
        suite.expect(widths, "the open island grows by the flare and the padding while its page keeps upstream's width")
        suite.expect(bodies, "the open island's body grows by the padding past upstream's on every preset and width")
        // Shorter surfaces with insets of their own keep their bodies too.
        let geometry = NotchGeometry(screen: screen, safeAreaTop: 32, cameraWidth: 185)
        let peek = geometry.peek
        suite.expect(abs(peek.width - NotchLayout.shoulder(height: peek.height) * 2
                         - (geometry.peekWidth - NotchLayout.plainShoulder(height: peek.height) * 2)) < 0.001
                     && abs(NotchLayout.horizontalInset(height: peek.height) - NotchLayout.shoulder(height: peek.height)
                            - (inset - NotchLayout.plainShoulder(height: peek.height))) < 0.001,
                     "the peek keeps its body and its row's place inside it")
        for rows in [1, 2, 3] {
            let picker = NotchActivityPickerLayout(count: rows * 3, labelWidth: 60,
                                                   stripSize: CGSize(width: 300, height: 32), screenWidth: 1710)
            let shoulder = NotchLayout.shoulder(height: picker.size.height)
            suite.expect(abs(picker.horizontalPadding - shoulder
                             - (NotchActivityPickerLayout.horizontalInset - NotchLayout.plainShoulder(height: picker.size.height))) < 0.001
                         && picker.horizontalPadding >= shoulder,
                         "an activity picker of \(rows) rows keeps its buttons inside its body")
        }
        // Closed strips take no flare: they keep upstream's sizes.
        for size in [geometry.collapsed, geometry.restingSize(showsContent: false), geometry.notice, geometry.musicStrip] {
            suite.expect(NotchLayout.flared(size) == size && NotchLayout.shoulderFlare(height: size.height) == 0,
                         "a closed \(Int(size.width))-point strip keeps its size and shoulder")
        }
    }

    /// The Camera page starts its mirror itself only with access granted,
    /// once per visit, and only while its switch is on.
    private static func cameraAutoStart(_ suite: TestSuite) {
        suite.expect(ZenithCameraAutoStart.startsOnAppear(status: .authorized, isOn: true, attempted: false),
                     "with access granted the Camera page starts its mirror as it appears")
        suite.expect(!ZenithCameraAutoStart.startsOnAppear(status: .notDetermined, isOn: true, attempted: false)
                     && !ZenithCameraAutoStart.startsOnAppear(status: .denied, isOn: true, attempted: false)
                     && !ZenithCameraAutoStart.startsOnAppear(status: .restricted, isOn: true, attempted: false),
                     "without access the page never raises the prompt or starts by itself")
        suite.expect(!ZenithCameraAutoStart.startsOnAppear(status: .authorized, isOn: false, attempted: false)
                     && !ZenithCameraAutoStart.startsOnAppear(status: .authorized, isOn: true, attempted: true),
                     "turned off, or stopped by hand on this visit, the mirror stays off")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.notchCameraAutoStart] as? Bool == true,
                     "the switch starts on and travels with settings backups")
        let domain = "com.vorssaint.tests.camera-auto-start"
        let defaults = UserDefaults(suiteName: domain)!
        defaults.removePersistentDomain(forName: domain)
        defer { defaults.removePersistentDomain(forName: domain) }
        suite.expect(ZenithCameraAutoStart.isOn(in: defaults), "without a choice the mirror starts by itself")
        defaults.set(false, forKey: DefaultsKey.notchCameraAutoStart)
        suite.expect(!ZenithCameraAutoStart.isOn(in: defaults), "turned off, the page waits for Open camera")
        suite.expect(ZenithCameraAutoStart.blur == 10 && ZenithCameraAutoStart.loadingDelay == 0.15,
                     "the image blurs in from 10 and a spinner waits 150 ms")
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
        islandInset(suite)
    }

    /// Zenith fork: the open island's one padding and the corners nested in it.
    private static func islandInset(_ suite: TestSuite) {
        typealias Inset = ZenithIslandInset
        suite.expect(ZenithIslandSilhouette.openCornerRadius == 40 && Inset.cornerRadius == 40 && Inset.padding == 20,
                     "the open island's corner is 40 points and its padding half of it")
        suite.expect(Inset.padding == (Inset.cornerRadius / 2).rounded(),
                     "the padding follows the corner, so a rounder island brings its content in with it")
        suite.expect(Inset.concentricRadius(inset: Inset.padding) == 20 && ZenithIsland.cardRadius == 20,
                     "a card on the padding line runs concentric with the island's corner")
        suite.expect(Inset.concentricRadius(inset: 8, outer: 20) == 12
                        && Inset.concentricRadius(inset: 0) == Inset.cornerRadius
                        && Inset.concentricRadius(inset: -6) == Inset.cornerRadius,
                     "an element nested deeper takes a smaller corner, never a larger one than its surface")
        suite.expect(Inset.concentricRadius(inset: 100) == Inset.minimumRadius
                        && Inset.concentricRadius(inset: .nan) == Inset.minimumRadius
                        && Inset.concentricRadius(inset: 4, outer: .infinity) == Inset.minimumRadius
                        && Inset.concentricRadius(inset: 30, minimum: 0) == 10,
                     "a corner never pinches below its least, and a measure that is not one reads as the least")
        suite.expect(Inset.itemWidth(count: 3, in: 540) == 172 && Inset.itemWidth(count: 1, in: 540) == 540
                        && Inset.itemWidth(count: 2, in: 100, gap: 20) == 40,
                     "repeated cards split the width evenly between one even gap")
        suite.expect(Inset.itemWidth(count: 0, in: 540) == 0 && Inset.itemWidth(count: 3, in: 10) == 0
                        && Inset.itemWidth(count: 2, in: .infinity) == 0,
                     "no cards, no room or no measure leave no width")
        let width = Inset.itemWidth(count: 3, in: 540)
        suite.expect(abs(width * 3 + Inset.gap * 2 - 540) < 0.001,
                     "the cards and their gaps end exactly on the padding line")
        suite.expect(Inset.height(content: 48, strip: 38) == 38 + Inset.belowCamera + 48 + Inset.padding
                        && Inset.height(content: -5, strip: -2) == Inset.belowCamera + Inset.padding,
                     "a grown row starts right under the camera and keeps the padding below it")
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
