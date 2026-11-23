// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation

// Zenith fork: the island's iOS-style motion (ZenithIslandMotion and
// ZenithContentRide): its springs and their speeds, the lag between the
// sides, the swing's sanity cap, squash and stretch, the content's sequence,
// interruptions and Reduce Motion.
enum IslandMotionTests {
    static func run(_ suite: TestSuite) {
        springs(suite)
        lags(suite)
        swing(suite)
        squash(suite)
        contentSequence(suite)
        interruptions(suite)
        reduceMotion(suite)
    }

    private static let closed = CGSize(width: 200, height: 32)
    private static let open = CGSize(width: 680, height: 360)

    private static func springs(_ suite: TestSuite) {
        typealias Spring = NotchMotion.Spring
        suite.expect(ZenithIslandMotion.growingWidth == Spring(duration: 0.52, bounce: 0.42)
                     && ZenithIslandMotion.growingHeight == Spring(duration: 0.56, bounce: 0.38)
                     && ZenithIslandMotion.shrinkingWidth == Spring(duration: 0.48, bounce: 0.36)
                     && ZenithIslandMotion.shrinkingHeight == Spring(duration: 0.44, bounce: 0.30),
                     "the island's springs are the approved ones")
        suite.expect(NotchMotion.growingWidth == ZenithIslandMotion.growingWidth
                     && NotchMotion.shrinkingHeight == ZenithIslandMotion.shrinkingHeight,
                     "the window host moves on those same springs")
        for spring in [ZenithIslandMotion.growingWidth, ZenithIslandMotion.growingHeight,
                       ZenithIslandMotion.shrinkingWidth, ZenithIslandMotion.shrinkingHeight, Spring(duration: 0.3, bounce: 0)] {
            suite.expect(spring.progress(at: 0) == 0 && spring.velocity(at: 0) == 0 && spring.velocity(at: -1) == 0,
                         "a spring starts at rest")
            suite.expect(abs(spring.progress(at: 3) - 1) < 0.001 && abs(spring.velocity(at: 3)) < 0.01,
                         "a spring comes to rest at its target")
            let step = 1e-5
            let agrees = stride(from: 0.01, through: 1.2, by: 0.01).allSatisfy { time in
                let numeric = (spring.progress(at: time + step) - spring.progress(at: time - step)) / (2 * step)
                return abs(numeric - spring.velocity(at: time)) < 1e-3 * max(1, abs(numeric))
            }
            suite.expect(agrees, "a spring's speed is the derivative of its progress: \(spring)")
        }
        let bouncy = ZenithIslandMotion.growingWidth
        let peak = stride(from: 0.0, through: 1.5, by: 0.001).map(bouncy.progress).max() ?? 0
        suite.expect(abs((peak - 1) - bouncy.overshoot) < 0.002 && bouncy.overshoot > 0.1,
                     "growing, the width swings about a tenth past its target")
    }

    private static func lags(_ suite: TestSuite) {
        let early = NotchMotion.size(at: 0.015, from: closed, to: open)
        suite.expect(early.width > closed.width && early.height == closed.height,
                     "growing, the width leads and the height waits 20 ms")
        let later = NotchMotion.size(at: 0.025, from: closed, to: open)
        suite.expect(later.height > closed.height, "then the height follows")
        let closing = NotchMotion.size(at: 0.03, from: open, to: closed)
        suite.expect(closing.height < open.height && closing.width == open.width,
                     "shrinking, the height leads and the width waits 35 ms")
        suite.expect(NotchMotion.size(at: 0.04, from: open, to: closed).width < open.width, "then the width follows")
        let timeline = NotchMotionTimeline(from: closed, to: open, begin: 5)
        suite.expect([0.0, 0.015, 0.03, 0.1, 0.4].allSatisfy { time in
                         let a = timeline.size(at: 5 + time), b = NotchMotion.size(at: time, from: closed, to: open)
                         return abs(a.width - b.width) < 0.001 && abs(a.height - b.height) < 0.001
                     },
                     "a motion in flight keeps the same lags")
        suite.expect(NotchMotion.lag(from: 300, to: 320, width: true, steady: true) == 0,
                     "a steady width does not wait")
    }

    private static func swing(_ suite: TestSuite) {
        let motion = NotchMotion.frames(from: closed, to: open)
        let widest = motion.sizes.map(\.width).max() ?? 0
        let tallest = motion.sizes.map(\.height).max() ?? 0
        suite.expect(widest > open.width + 12 && tallest > open.height + 12,
                     "the old 12 point cap is gone: the island swings well past a large target")
        let huge = NotchMotion.frames(from: CGSize(width: 200, height: 32), to: CGSize(width: 1_400, height: 900))
        let reach = huge.sizes.reduce(CGSize.zero) { CGSize(width: max($0.width, $1.width), height: max($0.height, $1.height)) }
        suite.expect(reach.width <= 1_400 + ZenithIslandMotion.widthSwingLimit + ZenithIslandMotion.narrowingLimit
                     && reach.height <= 900 + ZenithIslandMotion.heightSwingLimit + ZenithIslandMotion.flatteningLimit
                     && reach.height <= 900 + 48,
                     "a huge travel stays within the sanity cap, inside the 48 points the tallest island leaves free")
        let envelope = NotchMotion.envelope(from: closed, to: open)
        suite.expect(envelope.width >= widest && envelope.height >= tallest,
                     "the reserved area holds every frame as drawn")
        let closing = NotchMotion.frames(from: open, to: closed)
        suite.expect((closing.sizes.map(\.width).min() ?? 0) < closed.width,
                     "shrinking swings a little past its target too")
        suite.expect(closing.sizes.last == closed && motion.sizes.last == open && motion.sizes.first == closed,
                     "the motion starts on screen and ends exactly at its target")
        suite.expect(motion.duration < 1.6 && closing.duration < 1.6,
                     "the island settles within a second and a half: \(motion.duration), \(closing.duration)")
        let peekHeight = NotchMotion.frames(from: CGSize(width: 200, height: 0), to: CGSize(width: 200, height: 32))
        suite.expect(peekHeight.sizes.allSatisfy { $0.width >= 0 && $0.height >= 0 }, "no frame turns inside out")
    }

    private static func squash(_ suite: TestSuite) {
        let size = CGSize(width: 400, height: 200)
        let dropping = ZenithIslandMotion.squash(size, velocity: CGSize(width: 0, height: 600))
        let spreading = ZenithIslandMotion.squash(size, velocity: CGSize(width: 1_000, height: 0))
        suite.expect(abs(dropping.width - (400 - 6.6)) < 0.001 && dropping.height == 200,
                     "the body narrows while it drops")
        suite.expect(abs(spreading.height - 196) < 0.001 && spreading.width == 400, "and flattens while it spreads")
        let flung = ZenithIslandMotion.squash(size, velocity: CGSize(width: 90_000, height: -90_000))
        suite.expect(flung.width == 414 && flung.height == 193, "squash and stretch stay within 14 and 7 points")
        suite.expect(ZenithIslandMotion.squash(size, velocity: .zero) == size, "a body at rest keeps its shape")
        // Drawn frames differ from the springs' sizes by the squash alone,
        // driven by the springs' own speed.
        let bounded = stride(from: 0.0, through: 1.2, by: 1.0 / 120).allSatisfy { time in
            let raw = NotchMotion.size(at: time, from: closed, to: open)
            let drawn = NotchMotion.shape(at: time, from: closed, to: open)
            let speed = NotchMotion.velocity(at: time, from: closed, to: open)
            return abs(raw.width - drawn.width) <= 14 + 1e-9 && abs(raw.height - drawn.height) <= 7 + 1e-9
                && drawn == ZenithIslandMotion.squash(raw, velocity: speed)
        }
        suite.expect(bounded, "every drawn frame is the spring's size squashed by its speed")
        let step = 1e-5
        let speedAgrees = stride(from: 0.05, through: 1.0, by: 0.05).allSatisfy { time in
            let before = NotchMotion.size(at: time - step, from: closed, to: open)
            let after = NotchMotion.size(at: time + step, from: closed, to: open)
            let speed = NotchMotion.velocity(at: time, from: closed, to: open)
            return abs((after.height - before.height) / (2 * step) - speed.height) < 0.05
                && abs((after.width - before.width) / (2 * step) - speed.width) < 0.05
        }
        suite.expect(speedAgrees, "the island's speed is the derivative of its size, lag included")
        let opening = NotchMotion.frames(from: closed, to: open)
        let narrowest = zip(opening.sizes, opening.keyTimes).contains { size, key in
            let raw = NotchMotion.size(at: key * opening.duration, from: closed, to: open)
            return key < 1 && size.width < raw.width - 5
        }
        suite.expect(narrowest, "an opening island visibly narrows while it drops fast")
        suite.expect(NotchMotion.shape(at: 0.1, from: CGSize(width: 315, height: 33), to: CGSize(width: 329, height: 33), steady: true)
                     == NotchMotion.size(at: 0.1, from: CGSize(width: 315, height: 33), to: CGSize(width: 329, height: 33), steady: true),
                     "a steady width keeps its shape")
    }

    private static func contentSequence(_ suite: TestSuite) {
        typealias Ride = ZenithContentRide
        let start = Ride.outgoing(at: 0, islandWidth: 300, pageWidth: 300)
        let gone = Ride.outgoing(at: 0.1, islandWidth: 300, pageWidth: 300)
        suite.expect(start.opacity == 1 && start.blur == 0 && gone.opacity == 0 && gone.blur == 8,
                     "opening, the leaving strip fades fast, over 0.1 s, blurring up to 8 points")
        suite.expect(Ride.outgoing(at: 0.05, islandWidth: 600, pageWidth: 300).scale == 1.1
                     && Ride.outgoing(at: 0.05, islandWidth: 60, pageWidth: 300).scale == 0.35
                     && abs(Ride.outgoing(at: 0.05, islandWidth: 315, pageWidth: 300).scale - 1.05) < 1e-9,
                     "the leaving strip grows with the island by at most 10%")
        let closing = Ride.Timing.closing
        suite.expect(Ride.outgoing(at: 0.05, islandWidth: 600, pageWidth: 300, timing: closing).scale == 1
                     && abs(Ride.outgoing(at: 0.05, islandWidth: 150, pageWidth: 300, timing: closing).scale - 0.5) < 1e-9
                     && Ride.outgoing(at: 0.1, islandWidth: 300, pageWidth: 300, timing: closing).opacity > 0.3
                     && Ride.outgoing(at: 0.17, islandWidth: 300, pageWidth: 300, timing: closing).opacity == 0,
                     "closing, the leaving page rides the shrink down, never past its size, over its first 60%")
        let before = Ride.incoming(at: 0.03, islandWidth: 680, pageWidth: 680)
        let arrived = Ride.incoming(at: 0.23, islandWidth: 680, pageWidth: 680)
        suite.expect(before.opacity == 0 && before.blur == 6 && before.offset == -8
                     && arrived.opacity == 1 && arrived.blur == 0 && arrived.offset == 0,
                     "the arriving page starts at 0.03 s and is sharp and whole by 0.23 s: blur 6 to 0, 8 points up to its place")
        suite.expect(Ride.incoming(at: 0.2, islandWidth: 900, pageWidth: 680).scale == 1
                     && Ride.incoming(at: 0.2, islandWidth: 100, pageWidth: 680).scale == 0.35
                     && Ride.incoming(at: 0.2, islandWidth: 340, pageWidth: 680, scaleFloor: 0.9).scale == 0.9,
                     "the arriving page rides the island's width up to its own size, never shrinking back")
        // Frame by frame through an opening's swing, the page only grows, to
        // exactly its size, while the island passes it and settles.
        let open = CGSize(width: 680, height: 360), shut = CGSize(width: 200, height: 32)
        let times = stride(from: 0.0, through: 1.2, by: 1.0 / 120).map { $0 }
        let ride = Ride.frames(at: times, islandWidths: times.map { NotchMotion.shape(at: $0, from: shut, to: open).width },
                               from: nil, to: open.width)
        let scales = ride.map(\.incomingScale)
        suite.expect(zip(scales, scales.dropFirst()).allSatisfy { $1 >= $0 } && scales.allSatisfy { $0 <= 1 }
                     && scales.last == 1 && ride.last == Ride.Composite(opacity: 1, crossfade: 1, blur: 0, scale: 1, offset: 0),
                     "an opening page's scale never passes 100% or falls back, and ends exactly at rest")
        let eased = stride(from: 0.03, through: 0.23, by: 0.01).map { Ride.incoming(at: $0, islandWidth: 1, pageWidth: 1).opacity }
        suite.expect(zip(eased, eased.dropFirst()).allSatisfy { $1 >= $0 }, "the arriving page only grows clearer")
        // Sequenced: never two blurred pages on top of each other.
        for timing in [Ride.Timing.opening, .closing] {
            let sequenced = stride(from: 0.0, through: 0.5, by: 0.005).allSatisfy { time in
                let leaving = Ride.outgoing(at: time, islandWidth: 300, pageWidth: 300, timing: timing).opacity
                let arriving = Ride.incoming(at: time, islandWidth: 300, pageWidth: 300, timing: timing).opacity
                return min(leaving, arriving) < 0.3
            }
            suite.expect(sequenced, "the arriving page only shows as the leaving one is mostly gone")
            // Never an empty island for more than a couple of frames between them.
            let empty = stride(from: 0.0, through: timing.duration, by: 1.0 / 120).filter { time in
                Ride.outgoing(at: time, islandWidth: 300, pageWidth: 300, timing: timing).opacity
                    + Ride.incoming(at: time, islandWidth: 300, pageWidth: 300, timing: timing).opacity < 0.05
            }.count
            suite.expect(empty <= 2, "the island is never empty between the pages for more than two frames: \(empty)")
        }
        let early = Ride.composite(at: 0.02, islandWidth: 300, from: 300, to: 300)
        let late = Ride.composite(at: 0.11, islandWidth: 300, from: 300, to: 300)
        suite.expect(early.crossfade == 0 && late.crossfade == 1 && early.opacity > 0.75,
                     "the folded layer shows only the old page first and only the new one after it")
        suite.expect(Ride.composite(at: 0.23, islandWidth: 300, from: 300, to: 300)
                     == Ride.Composite(opacity: 1, crossfade: 1, blur: 0, scale: 1, offset: 0),
                     "the folded layer ends exactly at rest")
        let nothingLeaving = Ride.composite(at: 0, islandWidth: 300, from: nil, to: 300)
        suite.expect(nothingLeaving.opacity == 0 && nothingLeaving.crossfade == 1, "with nothing leaving, only the arrival shows")
        for opacity in [0.1, 0.4, 0.8] {
            let resumed = Ride.incoming(at: Ride.resumeTime(opacity: opacity), islandWidth: 1, pageWidth: 1).opacity
            suite.expect(abs(resumed - opacity) < 1e-6, "a reversal picks up the arrival at the opacity on screen")
        }
        suite.expect(Ride.resumeTime(opacity: 0) == 0 && Ride.resumeTime(opacity: 1) == Ride.duration,
                     "a reversal from nothing starts the arrival afresh; from everything, it is done")
        // The crossfade's Bézier keeps the new page out until the old one is half gone.
        let curve = Ride.crossfadeControlPoints
        func bezier(_ s: Double) -> (x: Double, y: Double) {
            let a = 3 * (1 - s) * (1 - s) * s, b = 3 * (1 - s) * s * s, c = s * s * s
            return (a * Double(curve.0) + b * Double(curve.2) + c, a * Double(curve.1) + b * Double(curve.3) + c)
        }
        let samples = stride(from: 0.0, through: 1.0, by: 0.01).map(bezier)
        let atHalf = samples.first { $0.x >= 0.5 }?.y ?? 1
        suite.expect(atHalf < 0.08, "the crossfade's curve holds the new page back until the old one is half gone")
    }

    private static func interruptions(_ suite: TestSuite) {
        let begin = 20.0
        let opening = NotchMotionTimeline(from: closed, to: open, begin: begin)
        for retarget in [0.06, 0.15, 0.3] {
            let time = begin + retarget
            guard let closing = opening.continued(to: closed, at: time) else {
                suite.expect(false, "a motion turning back carries on")
                continue
            }
            let at = opening.size(at: time), speed = opening.velocity(at: time)
            let carriedSize = closing.size(at: time), carriedSpeed = closing.velocity(at: time)
            suite.expect(abs(carriedSize.width - at.width) < 1e-6 && abs(carriedSize.height - at.height) < 1e-6,
                         "turning back keeps the island where it is")
            suite.expect(abs(carriedSpeed.width - speed.width) < 1e-6 && abs(carriedSpeed.height - speed.height) < 1e-6,
                         "turning back keeps its speed, instead of starting from rest")
            let shape = opening.shape(at: time), carriedShape = closing.shape(at: time)
            suite.expect(abs(shape.width - carriedShape.width) < 1e-6 && abs(shape.height - carriedShape.height) < 1e-6,
                         "the squash carries on through the turn too")
            // No jump frame to frame across the turn.
            let instant = 1e-4
            let after = closing.shape(at: time + instant), before = opening.shape(at: time - instant)
            suite.expect(abs(after.width - before.width) < 1 && abs(after.height - before.height) < 1,
                         "an interrupted island moves on without jumping")
            let frames = closing.frames()
            suite.expect(frames.sizes.last == closed && frames.duration < 2.1, "the turned motion still lands on its target")
        }
        suite.expect(NotchMotionTimeline(from: closed, to: open, begin: 0, steady: true).continued(to: closed, at: 0.05) == nil
                     && NotchMotionTimeline(from: closed, to: open, begin: 0, offset: 40).continued(to: closed, at: 0.05) == nil,
                     "a steady width or a centre on its way still starts again from where it is drawn")
    }

    private static func reduceMotion(_ suite: TestSuite) {
        typealias Ride = ZenithContentRide
        let frames = stride(from: 0.0, through: 0.3, by: 0.01).map {
            Ride.composite(at: $0, islandWidth: 120, from: 680, to: 680, reduceMotion: true)
        }
        suite.expect(frames.allSatisfy { $0.blur == 0 && $0.scale == 1 && $0.offset == 0 && $0.opacity == 1 },
                     "Reduce Motion is a plain crossfade: no blur, no scale, no rise")
        suite.expect(frames.first?.crossfade == 0 && frames.last?.crossfade == 1
                     && zip(frames, frames.dropFirst()).allSatisfy { $1.crossfade >= $0.crossfade },
                     "Reduce Motion crossfades within 0.2 s")
        suite.expect(Ride.composite(at: 0.1, islandWidth: 1, from: nil, to: 1, reduceMotion: true).opacity < 1,
                     "content arriving with nothing leaving fades in under Reduce Motion")
    }
}
