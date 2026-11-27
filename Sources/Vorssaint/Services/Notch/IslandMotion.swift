// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CoreGraphics
import Foundation
import SwiftUI

// Zenith fork: one source for every island animation, derived from the motion
// chosen on Settings → Appearance (IslandMotionSettings), Reduce Motion and the
// battery saver. The island's tuned curves (ZenithIslandMotion's springs,
// ZenithContentRide's timing, each view's hover and press) were drawn for the
// Zenith preset at 1×; every other preset and speed scales them from there, so
// Zenith at 1× moves exactly as it always has.
//
// - Zenith rides along: the shape bounces, the content follows a moment later,
//   growing with the island from a blur.
// - Snappy is staged: the shape lands first without a swing, then the content
//   arrives sharp, a few hundredths of a second later.
// - Reduce Motion: short cross-fades, no blur, no bounce, no squash.
// - Battery saver: plain fades without blur, no bounce, at the preset's pace.
//
// Every interaction and transition here runs at the display's full rate; only
// the agents' looping decoration is capped (IslandAgentMotion).

struct IslandMotion: Equatable {
    typealias Spring = NotchMotion.Spring

    var settings: IslandMotionSettings
    var reduceMotion: Bool
    var savingBattery: Bool

    init(settings: IslandMotionSettings = .standard, reduceMotion: Bool = false, savingBattery: Bool = false) {
        self.settings = settings
        self.reduceMotion = reduceMotion
        self.savingBattery = savingBattery
    }

    static let standard = IslandMotion()

    /// How much of the motion is left: all of it, plain fades, or Reduce Motion's.
    enum Style: Equatable { case full, plain, reduced }

    var style: Style { reduceMotion ? .reduced : savingBattery ? .plain : .full }

    // MARK: The reference

    /// The values the island's curves were tuned for: Zenith's.
    static let referenceBounce = IslandMotionPreset.zenith.values.bounce
    static let referenceBlur = IslandMotionPreset.zenith.values.blur
    /// A staged shape lands in this share of the ride-along springs' time:
    /// the 0.52 s growing width becomes a 0.19 s spring without a swing,
    /// 95% of the way by about 0.14 s, as the Snappy mockup's 135 ms container.
    static let stagedShapeShare = 0.36
    /// A staged swap's container in SwiftUI, at 1×.
    static let stagedShapeDuration: TimeInterval = 0.135
    /// Reduce Motion's cross-fade.
    static let reducedFade: TimeInterval = 0.2

    var speed: Double { settings.speed }
    var staged: Bool { settings.values.staged }

    /// The shape's swing against Zenith's: 0 for Snappy, the battery saver
    /// and Reduce Motion; above 1 for Playful.
    var bounceScale: Double {
        guard style == .full, Self.referenceBounce > 0 else { return 0 }
        return settings.values.bounce / Self.referenceBounce
    }

    /// The content's blur against Zenith's; none in the saver or Reduce Motion.
    var blurScale: CGFloat {
        guard style == .full, Self.referenceBlur > 0 else { return 0 }
        return CGFloat(settings.values.blur / Self.referenceBlur)
    }

    /// Seconds of the island's shape per second of the tuned springs.
    var shapeTimeScale: Double { (staged ? Self.stagedShapeShare : 1) / speed }
    /// Seconds of content per second of the tuned ride.
    var contentTimeScale: Double { 1 / (speed * settings.values.contentPace) }

    // MARK: The shape

    /// One of the island's tuned springs, as this motion runs it.
    func shape(_ spring: Spring) -> Spring {
        Spring(duration: spring.duration * shapeTimeScale, bounce: min(0.85, max(0, spring.bounce * bounceScale)))
    }

    /// A lag or ease of the shape's, as this motion runs it.
    func shapeTime(_ time: TimeInterval) -> TimeInterval { time * shapeTimeScale }

    /// How much squash and stretch the body shows: it follows the swing.
    var squashScale: CGFloat { CGFloat(min(bounceScale, 1.5)) }

    // MARK: The content riding the shape

    /// Opening and swaps: the page leaving goes fast for the page arriving.
    var opening: ZenithContentRide.Timing {
        let pace = contentTimeScale
        var timing = ZenithContentRide.Timing(outgoingFade: 0.1 * pace, incomingDelay: 0.03 * pace,
                                              incomingFade: 0.2 * pace, outgoingCap: 1.1)
        if staged {
            // Shape first, then the content, sharp and in place.
            timing.incomingDelay = settings.contentDelay
            timing.incomingFade = settings.contentDuration
            timing.outgoingFade = min(timing.outgoingFade, settings.contentDelay)
            timing.outgoingCap = 1
        }
        return styled(timing)
    }

    /// Closing: the page leaving rides the shrink, the closed content follows it.
    var closing: ZenithContentRide.Timing {
        let shape = shapeTimeScale
        var timing = ZenithContentRide.Timing(outgoingFade: 0.17 * shape, incomingDelay: 0.1 * shape,
                                              incomingFade: 0.2 * contentTimeScale, outgoingCap: 1)
        if staged { timing.incomingFade = settings.contentDuration }
        return styled(timing)
    }

    private func styled(_ base: ZenithContentRide.Timing) -> ZenithContentRide.Timing {
        var timing = base
        timing.outgoingBlur = ZenithContentRide.outgoingBlur * blurScale
        timing.incomingBlur = ZenithContentRide.incomingBlur * blurScale
        switch style {
        case .full where !staged:
            break
        case .full:
            // Staged content lands sharp where it rests: no rise, only a hint of growth.
            timing.incomingRise = 0
            timing.incomingFloor = 0.98
            timing.outgoingFloor = 1
        case .plain, .reduced:
            // Plain fades: nothing moves, blurs or grows.
            timing.incomingRise = 0
            timing.incomingFloor = 1
            timing.outgoingFloor = 1
            timing.outgoingCap = 1
        }
        return timing
    }

    // MARK: SwiftUI swaps (ZenithMorph)

    /// The container's move for a SwiftUI swap.
    var morph: IslandCurve {
        switch style {
        case .reduced: return IslandCurve(.easeInOut, duration: Self.reducedFade)
        case .plain: return IslandCurve(.spring(damping: 1), duration: settings.springResponse)
        case .full where staged:
            return IslandCurve(.bezier(0.22, 1, 0.36, 1), duration: Self.stagedShapeDuration / speed)
        case .full: return IslandCurve(.spring(damping: settings.springDamping), duration: settings.springResponse)
        }
    }

    /// The arriving view's fade and focus.
    var arriving: IslandCurve {
        switch style {
        case .reduced: return IslandCurve(.easeInOut, duration: Self.reducedFade)
        case .plain: return IslandCurve(.easeOut, duration: settings.contentDuration, delay: settings.contentDelay)
        case .full where staged:
            return IslandCurve(.bezier(0.4, 0, 0.2, 1), duration: settings.contentDuration, delay: settings.contentDelay)
        case .full:
            return IslandCurve(.bezier(0.22, 1, 0.36, 1), duration: settings.contentDuration, delay: settings.contentDelay)
        }
    }

    /// The arriving view's growth: Zenith's swells on the shape's own spring,
    /// a beat after it, so the content grows with the island and settles.
    var arrivingGrowth: IslandCurve {
        guard style == .full, !staged else { return arriving }
        return IslandCurve(.spring(damping: settings.springDamping), duration: settings.springResponse,
                           delay: 0.04 / speed)
    }

    /// The leaving view's fade.
    var leaving: IslandCurve {
        style == .reduced ? IslandCurve(.easeInOut, duration: Self.reducedFade)
            : IslandCurve(.linear, duration: opening.outgoingFade)
    }

    /// Peak blur of a SwiftUI swap's arriving and leaving view.
    var morphBlurIn: CGFloat { style == .full ? CGFloat(settings.values.blur) : 0 }
    var morphBlurOut: CGFloat { style == .full ? CGFloat(settings.values.blur) * 0.8 : 0 }
    /// The scale an arriving view grows from.
    var morphScaleIn: CGFloat {
        guard style == .full else { return 1 }
        return staged ? 0.98 : 0.9
    }

    // MARK: Small curves: hovers, presses, strips, capsules

    /// One of the island's small curves as this motion runs it: scaled by the
    /// speed, keeping its character (a hover stays quick). The saver drops
    /// bounce; Reduce Motion leaves a short cross-fade.
    func curve(_ base: IslandCurve) -> IslandCurve {
        let duration = base.duration / speed, delay = base.delay / speed
        switch style {
        case .reduced:
            return IslandCurve(.easeInOut, duration: min(duration, Self.reducedFade), delay: delay)
        case .plain:
            switch base.kind {
            case .spring: return IslandCurve(.spring(damping: 1), duration: duration, delay: delay)
            case .smooth: return IslandCurve(.easeInOut, duration: duration, delay: delay)
            case let .bezier(x1, y1, x2, y2):
                return IslandCurve(.bezier(x1, min(y1, 1), x2, min(y2, 1)), duration: duration, delay: delay)
            default: return IslandCurve(base.kind, duration: duration, delay: delay)
            }
        case .full:
            switch base.kind {
            case let .spring(damping):
                let swing = (1 - damping) * bounceScale
                return IslandCurve(.spring(damping: min(1, max(0.3, 1 - swing))), duration: duration, delay: delay)
            case let .bezier(x1, y1, x2, y2) where y1 > 1 || y2 > 1:
                func overshoot(_ y: Double) -> Double { y > 1 ? 1 + (y - 1) * min(bounceScale, 1.5) : y }
                return IslandCurve(.bezier(x1, overshoot(y1), x2, overshoot(y2)), duration: duration, delay: delay)
            default: return IslandCurve(base.kind, duration: duration, delay: delay)
            }
        }
    }

    // MARK: The motion in force

    private static let lock = NSLock()
    private static var stored = IslandMotion.standard

    /// The island's motion right now. `IslandMotionLive` keeps it in step with
    /// Settings, Reduce Motion and the battery saver; the next animation takes
    /// a change up, with nothing to restart.
    static var current: IslandMotion {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}

/// A curve the island animates with, kept as values so tests can read it.
struct IslandCurve: Equatable {
    enum Kind: Equatable {
        case smooth, easeOut, easeIn, easeInOut, linear
        case bezier(Double, Double, Double, Double)
        /// `duration` is the spring's response.
        case spring(damping: Double)
    }

    var kind: Kind
    var duration: TimeInterval
    var delay: TimeInterval = 0

    init(_ kind: Kind, duration: TimeInterval, delay: TimeInterval = 0) {
        self.kind = kind
        self.duration = max(0, duration)
        self.delay = max(0, delay)
    }

    var animation: Animation {
        let base: Animation
        switch kind {
        case .smooth: base = .smooth(duration: duration)
        case .easeOut: base = .easeOut(duration: duration)
        case .easeIn: base = .easeIn(duration: duration)
        case .easeInOut: base = .easeInOut(duration: duration)
        case .linear: base = .linear(duration: duration)
        case let .bezier(x1, y1, x2, y2): base = .timingCurve(x1, y1, x2, y2, duration: duration)
        case let .spring(damping): base = .spring(response: max(0.01, duration), dampingFraction: damping)
        }
        return delay > 0 ? base.delay(delay) : base
    }
}

/// The island's tokens, read from the motion in force when the animation is
/// made. Each mirrors the SwiftUI curve it replaced, scaled by the speed.
extension IslandMotion {
    static func smooth(_ duration: TimeInterval) -> Animation { token(.smooth, duration) }
    static func easeOut(_ duration: TimeInterval) -> Animation { token(.easeOut, duration) }
    static func easeIn(_ duration: TimeInterval) -> Animation { token(.easeIn, duration) }
    static func easeInOut(_ duration: TimeInterval) -> Animation { token(.easeInOut, duration) }
    static func linear(_ duration: TimeInterval) -> Animation { token(.linear, duration) }

    /// `.spring(response:dampingFraction:)`; SwiftUI's own default damping.
    static func spring(response: Double = 0.5, damping: Double = 0.825) -> Animation {
        token(.spring(damping: damping), response)
    }

    /// `.spring(duration:bounce:)`, as a response and damping.
    static func spring(duration: TimeInterval, bounce: Double = 0) -> Animation {
        token(.spring(damping: 1 - min(max(bounce, 0), 0.95)), duration)
    }

    /// `.snappy`: a short spring with a little bounce.
    static func snappy(_ duration: TimeInterval = 0.5) -> Animation { token(.spring(damping: 0.85), duration) }

    /// ZenithMotion's curves for the island: entrances, toggles, the pop.
    static func reveal(_ duration: TimeInterval = ZenithMotion.standard) -> Animation {
        token(.bezier(0.22, 1, 0.36, 1), duration)
    }

    static func toggle(_ duration: TimeInterval = ZenithMotion.standard) -> Animation {
        token(.bezier(0.4, 0, 0.2, 1), duration)
    }

    static func pop(_ duration: TimeInterval = ZenithMotion.standard) -> Animation {
        token(.bezier(0.34, 1.36, 0.5, 1), duration)
    }

    /// Pressing down fast; release with `pop`.
    static var press: Animation { token(.bezier(0.4, 0, 0.2, 1), 0.1) }

    /// A wait timed against one of these curves, at the same speed.
    static func paced(_ time: TimeInterval) -> TimeInterval { time / current.speed }

    private static func token(_ kind: IslandCurve.Kind, _ duration: TimeInterval) -> Animation {
        current.curve(IslandCurve(kind, duration: duration)).animation
    }
}

// MARK: - The agents' looping decoration

/// How the agents' working animation (a glyph breathing, a pulse spreading)
/// may run. Everything else on the island runs at the display's full rate;
/// this loop runs for as long as an agent works, so it steps at most 30
/// times a second, and not at all while no one can see it or the battery
/// saver is on, when it rests in its still pose.
enum IslandAgentMotion: Equatable {
    case paused
    case running(framesPerSecond: Float)

    /// The most steps a second.
    static let rate: Float = 30

    /// What the loop's view knows about where it is.
    struct Conditions: Equatable {
        /// An agent works and Reduce Motion is off.
        var animates: Bool
        /// The view is in a window, not hidden, and the window is on screen and not covered.
        var visible: Bool
        /// The view belongs to the island's own window, which only shows
        /// while the island can present.
        var inIsland: Bool
        /// The island can present: unlocked, awake, displays on, this user at the Mac.
        var islandPresenting: Bool
        /// The Mac is awake with its displays on and this user at it (the
        /// lock screen and Settings only need this).
        var screenAwake: Bool
        var savingBattery: Bool
    }

    static func decide(_ conditions: Conditions) -> IslandAgentMotion {
        guard conditions.animates, conditions.visible, conditions.screenAwake, !conditions.savingBattery,
              !conditions.inIsland || conditions.islandPresenting else { return .paused }
        return .running(framesPerSecond: rate)
    }

    var isRunning: Bool { if case .running = self { return true } else { return false } }
}

/// A window that holds the island; its agent loops also stop whenever the
/// island cannot present.
protocol IslandAgentHostWindow: AnyObject {}

/// What the agents' loops hear from the rest of the app: whether the island
/// can present, whether the screen is awake, and the battery saver. Every
/// change is posted, so running loops stop or resume at once.
@MainActor
final class IslandAgentMotionGate {
    static let shared = IslandAgentMotionGate()
    static let didChange = Notification.Name("IslandAgentMotionGateDidChange")

    private(set) var islandPresenting = true
    private(set) var screenAwake = true
    private(set) var savingBattery = false

    func update(islandPresenting: Bool? = nil, screenAwake: Bool? = nil, savingBattery: Bool? = nil) {
        let next = (islandPresenting ?? self.islandPresenting, screenAwake ?? self.screenAwake,
                    savingBattery ?? self.savingBattery)
        guard next != (self.islandPresenting, self.screenAwake, self.savingBattery) else { return }
        (self.islandPresenting, self.screenAwake, self.savingBattery) = next
        NotificationCenter.default.post(name: Self.didChange, object: self)
    }

    /// The decision for a view that knows its own visibility.
    func decide(animates: Bool, visible: Bool, inIsland: Bool) -> IslandAgentMotion {
        IslandAgentMotion.decide(.init(animates: animates, visible: visible, inIsland: inIsland,
                                       islandPresenting: islandPresenting, screenAwake: screenAwake,
                                       savingBattery: savingBattery))
    }
}
