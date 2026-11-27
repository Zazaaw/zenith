// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation

// Zenith fork: the island's motion, after the phone's Dynamic Island and the
// simulation Faiz approved ("ala iOS, mantul lebih"). Each side follows its
// own bouncy spring, a little apart from the other; the body narrows while it
// drops fast and flattens while it spreads fast; and the content rides the
// shape: the page leaving fades and blurs out with the island, then the page
// arriving eases in, blurred and small, growing with it. Everything here is
// pure maths, so the window host, the tests and the frame renderer share it.

/// The springs, the lags between the sides, the swing's sanity cap and the
/// squash and stretch.
enum ZenithIslandMotion {
    typealias Spring = NotchMotion.Spring

    /// Growing, the width leads and the height follows 20 ms later.
    static let growingWidth = Spring(duration: 0.52, bounce: 0.42)
    static let growingHeight = Spring(duration: 0.56, bounce: 0.38)
    /// Shrinking, the height leads and the width follows 35 ms later.
    static let shrinkingWidth = Spring(duration: 0.48, bounce: 0.36)
    static let shrinkingHeight = Spring(duration: 0.44, bounce: 0.30)
    static let growingHeightLag: TimeInterval = 0.02
    static let shrinkingWidthLag: TimeInterval = 0.035

    static func spring(width: Bool, growing: Bool) -> Spring {
        width ? (growing ? growingWidth : shrinkingWidth) : (growing ? growingHeight : shrinkingHeight)
    }

    // MARK: The floor

    /// A side landing on the closed island settles from above: a softer
    /// spring whose small swing past the floor rebounds outward instead, like
    /// a ball on the ground. The island never shows narrower or shorter than
    /// the camera cutout it covers, which would bare the cutout beside it.
    /// Tuned so the closed size is reached within a point at about 0.45 s:
    /// as unhurried as the opening, at the owner's request.
    static let landingWidth = Spring(duration: 0.4, bounce: 0.1)
    static let landingHeight = Spring(duration: 0.44, bounce: 0.1)

    /// Whether a side heading from `from` to `to` lands on `floor`: it
    /// shrinks, and its target is the floor (or below it, as a hidden island).
    static func lands(from: CGFloat, to: CGFloat, floor: CGFloat) -> Bool {
        floor > 0 && to < from && to <= floor + 0.5
    }

    /// The least a side may show while moving between `from` and `to`: the
    /// floor, unless an end is already below it (an island hiding or
    /// revealing from hidden).
    static func bottom(floor: CGFloat, from: CGFloat, to: CGFloat) -> CGFloat {
        max(0, min(floor, from, to))
    }

    /// A closing side eases in over its first 40 ms instead of setting off at
    /// the spring's own pace; an opening one leaves at once.
    static let closingEaseIn: TimeInterval = 0.04

    static func easeIn(from: CGFloat, to: CGFloat) -> TimeInterval {
        to < from ? IslandMotion.current.shapeTime(closingEaseIn) : 0
    }

    /// Time as the spring sees it, and how fast it runs: slowly at first over
    /// `easeIn`, gathering pace until it runs with the clock, which it then
    /// keeps (`easeIn / 2` behind it). Its rate is continuous throughout.
    static func warp(_ time: TimeInterval, easeIn: TimeInterval) -> (time: TimeInterval, rate: Double) {
        guard easeIn > 0, time > 0 else { return (time, 1) }
        guard time < easeIn else { return (time - easeIn / 2, 1) }
        return (time * time / (2 * easeIn), time / easeIn)
    }

    /// A spring's progress and rate `time` after it starts, `lag` later,
    /// eased in over `easeIn`; a landing reflects its swing past the target
    /// back to the side it came from.
    static func progress(_ spring: Spring, lag: TimeInterval, easeIn: TimeInterval = 0, landing: Bool,
                         at time: TimeInterval) -> (progress: Double, rate: Double) {
        let warped = warp(time - lag, easeIn: easeIn)
        let progress = spring.progress(at: warped.time), rate = spring.velocity(at: warped.time) * warped.rate
        guard landing, progress > 1 else { return (progress, rate) }
        return (2 - progress, -rate)
    }

    /// How long a side waits before it moves.
    static func lag(width: Bool, growing: Bool) -> TimeInterval {
        IslandMotion.current.shapeTime(width ? (growing ? 0 : shrinkingWidthLag) : (growing ? growingHeightLag : 0))
    }

    /// The farthest a side may swing past its target. Only a sanity cap: a
    /// long travel keeps the island on the display. The tallest island leaves
    /// 48 points free below it, which holds this swing and the squash.
    static let widthSwingLimit: CGFloat = 64
    static let heightSwingLimit: CGFloat = 36

    static func swingLimit(width: Bool) -> CGFloat { width ? widthSwingLimit : heightSwingLimit }

    /// Points the width gives up per point per second the height moves, and
    /// the most it gives; and the same for the height against the width.
    static let narrowingPerSpeed: CGFloat = 0.011
    static let narrowingLimit: CGFloat = 14
    static let flatteningPerSpeed: CGFloat = 0.004
    static let flatteningLimit: CGFloat = 7

    /// The body as drawn: narrower while it drops fast (wider while it pulls
    /// up), flatter while it spreads fast (taller while it draws in).
    /// Zenith fork: as much as the motion in force swings (none without a
    /// bounce), and the same at every speed for the same share of the way.
    static func squash(_ size: CGSize, velocity: CGSize) -> CGSize {
        let motion = IslandMotion.current
        let share = motion.squashScale * CGFloat(motion.shapeTimeScale)
        guard share > 0 else { return size }
        let narrowing = min(narrowingLimit, max(-narrowingLimit, velocity.height * narrowingPerSpeed * share))
        let flattening = min(flatteningLimit, max(-flatteningLimit, velocity.width * flatteningPerSpeed * share))
        return CGSize(width: max(0, size.width - narrowing), height: max(0, size.height - flattening))
    }
}

/// The floor an island's motion keeps above: on a display with a camera
/// cutout, the bare cutout, and when closing onto a strip, that strip, which
/// it then settles onto from above. A floating capsule has no cutout to bare.
enum NotchMotionFloor {
    static func floor(camera: CGSize, target: CGSize, closedHeight: CGFloat) -> CGSize {
        guard camera.width > 0, camera.height > 0 else { return .zero }
        guard target.height <= closedHeight + 0.5 else { return camera }
        return CGSize(width: max(camera.width, target.width), height: max(camera.height, target.height))
    }

    static func floor(for target: CGSize, geometry: NotchGeometry) -> CGSize {
        guard geometry.isNotched, !geometry.floats else { return .zero }
        return floor(camera: geometry.restingSize(showsContent: false), target: target, closedHeight: geometry.collapsed.height)
    }
}

/// How solid a glass island is while it moves. The owner preferred the glass
/// to stay glass through the motion (darkening and clearing read as a blink),
/// so `moving` is 0 and the island never darkens; the curve stays for a later
/// choice.
enum NotchMotionSurface {
    static let moving: Double = 0
    static let easeIn: TimeInterval = 0.08
    static let easeBack: TimeInterval = 0.3

    static func solidity(elapsed: TimeInterval, duration: TimeInterval) -> Double {
        guard duration > 0, elapsed > 0, elapsed < duration else { return 0 }
        let left = duration - elapsed
        return moving * ZenithContentRide.smoothstep(elapsed / easeIn)
            * ZenithContentRide.smoothstep(left / min(easeBack, duration))
    }
}

extension NotchMotion.Spring {
    /// Progress per second at `time`, from the spring's own equation rather
    /// than the difference between two frames.
    func velocity(at time: TimeInterval) -> Double {
        guard time > 0 else { return 0 }
        let natural = 2 * Double.pi / duration
        let damping = 1 - bounce
        if damping >= 1 { return natural * natural * time * exp(-natural * time) }
        let damped = natural * (1 - damping * damping).squareRoot()
        return exp(-damping * natural * time) * natural * natural / damped * sin(damped * time)
    }
}

/// How the content rides the shape. Opening, the page leaving (the closed
/// strip) fades fast over 0.1 s, growing no more than 10% with the island;
/// the page arriving starts at 0.03 s and is sharp and whole by about
/// 0.23 s, from a 6 point blur and 8 points up, at the island's share of its
/// own width, never past its own size and never shrinking back once grown,
/// so only the shape bounces. Closing, the page leaving rides the shrinking
/// island down (never past its own size) and fades over the first 60% of
/// the shrink, and the closed content follows straight after it.
///
/// The window host draws both pages in one hosting layer, the old as Core
/// Animation's snapshot crossfading into the new. `composite` folds the two
/// into what that layer can carry: its mask's opacity, the crossfade's share
/// of the new page, and one blur, scale and offset, each the visible pages'
/// own weighted by how much of each shows.
enum ZenithContentRide {
    /// When each page fades, and how far the leaving one may grow.
    struct Timing: Equatable {
        var outgoingFade: TimeInterval
        var incomingDelay: TimeInterval
        var incomingFade: TimeInterval
        var outgoingCap: CGFloat
        /// Zenith fork: how the pages look on their way, from IslandMotion:
        /// their peak blurs, the arriving page's rise, and the least each
        /// may scale to while riding the island.
        var outgoingBlur: CGFloat = ZenithContentRide.outgoingBlur
        var incomingBlur: CGFloat = ZenithContentRide.incomingBlur
        var incomingRise: CGFloat = ZenithContentRide.incomingRise
        var incomingFloor: CGFloat = ZenithContentRide.incomingScale.lowerBound
        var outgoingFloor: CGFloat = ZenithContentRide.outgoingFloor

        /// When the arriving page is fully in.
        var duration: TimeInterval { incomingDelay + incomingFade }

        /// Zenith fork: both from the motion in force (IslandMotion); at
        /// Zenith 1× these are the tuned values the comments describe.
        static var opening: Timing { IslandMotion.current.opening }
        /// The shrink onto the closed island takes about 0.28 s; the page
        /// leaving fades over the first 60% of it.
        static var closing: Timing { IslandMotion.current.closing }
    }

    /// The tuned values at Zenith 1×; the timing in force is `Timing.opening`.
    static let outgoingFade: TimeInterval = 0.1
    static let outgoingBlur: CGFloat = 8
    static let incomingDelay: TimeInterval = 0.03
    static let incomingFade: TimeInterval = 0.2
    static let incomingBlur: CGFloat = 6
    static let incomingRise: CGFloat = 8
    static let outgoingFloor: CGFloat = 0.35
    static let incomingScale: ClosedRange<CGFloat> = 0.35...1
    /// When an opening's arriving page is fully in.
    static var duration: TimeInterval { Timing.opening.duration }
    /// Reduce Motion's plain crossfade.
    static let reducedFade: TimeInterval = IslandMotion.reducedFade

    struct Layer: Equatable {
        var opacity: Double
        var blur: CGFloat
        var scale: CGFloat
        /// Points down from where the page rests; negative is above.
        var offset: CGFloat
    }

    struct Composite: Equatable {
        /// The content mask's opacity.
        var opacity: Double
        /// How much of what shows is the arriving page.
        var crossfade: Double
        var blur: CGFloat
        var scale: CGFloat
        var offset: CGFloat
        /// The arriving page's own scale, for the next frame's floor.
        var incomingScale: CGFloat = 1
    }

    static func smoothstep(_ x: Double) -> Double {
        let c = min(max(x, 0), 1)
        return c * c * (3 - 2 * c)
    }

    private static func ride(_ islandWidth: CGFloat, over pageWidth: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        guard pageWidth > 0, islandWidth.isFinite else { return 1 }
        return min(upper, max(lower, islandWidth / pageWidth))
    }

    static func outgoing(at time: TimeInterval, islandWidth: CGFloat, pageWidth: CGFloat, timing: Timing = .opening) -> Layer {
        let gone = min(max(time / timing.outgoingFade, 0), 1)
        return Layer(opacity: 1 - gone, blur: timing.outgoingBlur * CGFloat(gone),
                     scale: ride(islandWidth, over: pageWidth, lower: min(timing.outgoingFloor, timing.outgoingCap),
                                 upper: timing.outgoingCap), offset: 0)
    }

    /// The arriving page `time` in. `scaleFloor` is the largest scale it has
    /// already shown, which it never falls back below.
    static func incoming(at time: TimeInterval, islandWidth: CGFloat, pageWidth: CGFloat, timing: Timing = .opening,
                         scaleFloor: CGFloat = 0) -> Layer {
        let shown = smoothstep((time - timing.incomingDelay) / timing.incomingFade)
        let scale = max(min(scaleFloor, incomingScale.upperBound),
                        ride(islandWidth, over: pageWidth, lower: timing.incomingFloor, upper: incomingScale.upperBound))
        return Layer(opacity: shown, blur: timing.incomingBlur * CGFloat(1 - shown), scale: scale,
                     offset: -timing.incomingRise * CGFloat(1 - shown))
    }

    /// Both pages folded into one layer at `time`. With no page leaving (a
    /// reversal mid-arrival, or content arriving after a departure) only the
    /// arriving page shows.
    static func composite(at time: TimeInterval, islandWidth: CGFloat, from fromWidth: CGFloat?,
                          to toWidth: CGFloat, reduceMotion: Bool = false, timing: Timing = .opening,
                          scaleFloor: CGFloat = 0) -> Composite {
        if reduceMotion {
            let shown = smoothstep(time / reducedFade)
            return Composite(opacity: fromWidth == nil ? shown : 1, crossfade: shown, blur: 0, scale: 1, offset: 0)
        }
        let arriving = incoming(at: time, islandWidth: islandWidth, pageWidth: toWidth, timing: timing, scaleFloor: scaleFloor)
        guard let fromWidth else {
            return Composite(opacity: arriving.opacity, crossfade: 1, blur: arriving.blur,
                             scale: arriving.scale, offset: arriving.offset, incomingScale: arriving.scale)
        }
        let leaving = outgoing(at: time, islandWidth: islandWidth, pageWidth: fromWidth, timing: timing)
        let total = leaving.opacity + arriving.opacity
        guard total > 0 else {
            return Composite(opacity: 0, crossfade: 1, blur: arriving.blur, scale: arriving.scale, offset: arriving.offset,
                             incomingScale: arriving.scale)
        }
        let share = arriving.opacity / total
        func mix(_ old: CGFloat, _ new: CGFloat) -> CGFloat { old + (new - old) * CGFloat(share) }
        return Composite(opacity: min(1, total), crossfade: share, blur: mix(leaving.blur, arriving.blur),
                         scale: mix(leaving.scale, arriving.scale), offset: mix(leaving.offset, arriving.offset),
                         incomingScale: arriving.scale)
    }

    /// A whole ride frame by frame, `islandWidths` sampled at `times`: the
    /// arriving page's scale only ever grows, and the last frame is at rest.
    static func frames(at times: [TimeInterval], islandWidths: [CGFloat], from fromWidth: CGFloat?, to toWidth: CGFloat,
                       timing: Timing = .opening, skipped: TimeInterval = 0) -> [Composite] {
        var floor: CGFloat = 0
        return zip(times, islandWidths).map { time, width in
            let frame = composite(at: time + skipped, islandWidth: width, from: fromWidth, to: toWidth, timing: timing,
                                  scaleFloor: floor)
            floor = max(floor, frame.incomingScale)
            return frame
        }
    }

    /// Where an arriving page already `opacity` shown picks up its ease, so
    /// a reversal carries on from what is on screen.
    static func resumeTime(opacity: Double, timing: Timing = .opening) -> TimeInterval {
        let target = min(max(opacity, 0), 1)
        guard target > 0 else { return 0 }
        guard target < 1 else { return timing.duration }
        var low = 0.0, high = 1.0
        for _ in 0..<30 {
            let mid = (low + high) / 2
            if smoothstep(mid) < target { low = mid } else { high = mid }
        }
        return timing.incomingDelay + timing.incomingFade * (low + high) / 2
    }

    /// The crossfade's curve, a Bézier close to `composite`'s crossfade over
    /// the leaving page's fade: nothing of the new page until the old one is
    /// half gone, then all of it by the time the old one is.
    static let crossfadeControlPoints: (Float, Float, Float, Float) = (0.9, 0, 1, 0.2)
}
