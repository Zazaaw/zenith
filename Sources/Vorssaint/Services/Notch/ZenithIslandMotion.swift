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

    /// How long a side waits before it moves.
    static func lag(width: Bool, growing: Bool) -> TimeInterval {
        width ? (growing ? 0 : shrinkingWidthLag) : (growing ? growingHeightLag : 0)
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
    static func squash(_ size: CGSize, velocity: CGSize) -> CGSize {
        let narrowing = min(narrowingLimit, max(-narrowingLimit, velocity.height * narrowingPerSpeed))
        let flattening = min(flatteningLimit, max(-flatteningLimit, velocity.width * flatteningPerSpeed))
        return CGSize(width: max(0, size.width - narrowing), height: max(0, size.height - flattening))
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

/// How the content rides the shape. The page leaving fades over 0.12 s,
/// blurring up to 8 points and scaling with the island; the page arriving
/// starts at 0.05 s and eases in over 0.3 s, from a 12 point blur and 8 points
/// up, at the island's share of its own width. The two are sequenced: the
/// leaving page is all but gone before the arriving one shows.
///
/// The window host draws both pages in one hosting layer, the old as Core
/// Animation's snapshot crossfading into the new. `composite` folds the two
/// into what that layer can carry: its mask's opacity, the crossfade's share
/// of the new page, and one blur, scale and offset, each the visible pages'
/// own weighted by how much of each shows.
enum ZenithContentRide {
    static let outgoingFade: TimeInterval = 0.12
    static let outgoingBlur: CGFloat = 8
    static let incomingDelay: TimeInterval = 0.05
    static let incomingFade: TimeInterval = 0.3
    static let incomingBlur: CGFloat = 12
    static let incomingRise: CGFloat = 8
    static let outgoingScale: ClosedRange<CGFloat> = 0.35...1.3
    static let incomingScale: ClosedRange<CGFloat> = 0.35...1.04
    /// When the arriving page is fully in.
    static var duration: TimeInterval { incomingDelay + incomingFade }
    /// Reduce Motion's plain crossfade.
    static let reducedFade: TimeInterval = 0.2

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
    }

    static func smoothstep(_ x: Double) -> Double {
        let c = min(max(x, 0), 1)
        return c * c * (3 - 2 * c)
    }

    private static func ride(_ islandWidth: CGFloat, over pageWidth: CGFloat, within range: ClosedRange<CGFloat>) -> CGFloat {
        guard pageWidth > 0, islandWidth.isFinite else { return 1 }
        return min(range.upperBound, max(range.lowerBound, islandWidth / pageWidth))
    }

    static func outgoing(at time: TimeInterval, islandWidth: CGFloat, pageWidth: CGFloat) -> Layer {
        let gone = min(max(time / outgoingFade, 0), 1)
        return Layer(opacity: 1 - gone, blur: outgoingBlur * CGFloat(gone),
                     scale: ride(islandWidth, over: pageWidth, within: outgoingScale), offset: 0)
    }

    static func incoming(at time: TimeInterval, islandWidth: CGFloat, pageWidth: CGFloat) -> Layer {
        let shown = smoothstep((time - incomingDelay) / incomingFade)
        return Layer(opacity: shown, blur: incomingBlur * CGFloat(1 - shown),
                     scale: ride(islandWidth, over: pageWidth, within: incomingScale),
                     offset: -incomingRise * CGFloat(1 - shown))
    }

    /// Both pages folded into one layer at `time`. With no page leaving (a
    /// reversal mid-arrival, or content arriving after a departure) only the
    /// arriving page shows.
    static func composite(at time: TimeInterval, islandWidth: CGFloat, from fromWidth: CGFloat?,
                          to toWidth: CGFloat, reduceMotion: Bool = false) -> Composite {
        if reduceMotion {
            let shown = smoothstep(time / reducedFade)
            return Composite(opacity: fromWidth == nil ? shown : 1, crossfade: shown, blur: 0, scale: 1, offset: 0)
        }
        let arriving = incoming(at: time, islandWidth: islandWidth, pageWidth: toWidth)
        guard let fromWidth else {
            return Composite(opacity: arriving.opacity, crossfade: 1, blur: arriving.blur,
                             scale: arriving.scale, offset: arriving.offset)
        }
        let leaving = outgoing(at: time, islandWidth: islandWidth, pageWidth: fromWidth)
        let total = leaving.opacity + arriving.opacity
        guard total > 0 else {
            return Composite(opacity: 0, crossfade: 1, blur: arriving.blur, scale: arriving.scale, offset: arriving.offset)
        }
        let share = arriving.opacity / total
        func mix(_ old: CGFloat, _ new: CGFloat) -> CGFloat { old + (new - old) * CGFloat(share) }
        return Composite(opacity: min(1, total), crossfade: share, blur: mix(leaving.blur, arriving.blur),
                         scale: mix(leaving.scale, arriving.scale), offset: mix(leaving.offset, arriving.offset))
    }

    /// Where an arriving page already `opacity` shown picks up its ease, so
    /// a reversal carries on from what is on screen.
    static func resumeTime(opacity: Double) -> TimeInterval {
        let target = min(max(opacity, 0), 1)
        guard target > 0 else { return 0 }
        guard target < 1 else { return duration }
        var low = 0.0, high = 1.0
        for _ in 0..<30 {
            let mid = (low + high) / 2
            if smoothstep(mid) < target { low = mid } else { high = mid }
        }
        return incomingDelay + incomingFade * (low + high) / 2
    }

    /// The crossfade's curve, a Bézier close to `composite`'s crossfade over
    /// the leaving page's fade: nothing of the new page until the old one is
    /// half gone, then all of it by the time the old one is.
    static let crossfadeControlPoints: (Float, Float, Float, Float) = (0.9, 0, 1, 0.2)
}
