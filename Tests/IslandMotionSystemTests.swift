// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import CoreGraphics
import Foundation

// Zenith fork: the island's one motion source (IslandMotion) and the agents'
// frame-rate policy (IslandAgentMotion): Zenith 1× keeps the tuned motion,
// speed scales it, Snappy stages it, Reduce Motion and the battery saver
// strip it down, a change applies to the next animation, and the agents'
// loop runs at 30 fps only while someone can see it.
enum IslandMotionSystemTests {
    static func run(_ suite: TestSuite) {
        reference(suite)
        speed(suite)
        staged(suite)
        presets(suite)
        reduceMotion(suite)
        batterySaver(suite)
        smallCurves(suite)
        liveUpdates(suite)
        agentPolicy(suite)
        MainActor.assumeIsolated { agentView(suite) }
    }

    private typealias Spring = NotchMotion.Spring
    private typealias Ride = ZenithContentRide
    private static let closed = CGSize(width: 200, height: 32)
    private static let open = CGSize(width: 680, height: 360)

    private static func settings(_ preset: IslandMotionPreset, speed: Double = 1) -> IslandMotionSettings {
        IslandMotionSettings(preset: preset, values: preset.values, speed: speed)
    }

    private static func motion(_ preset: IslandMotionPreset, speed: Double = 1, reduce: Bool = false,
                               saving: Bool = false) -> IslandMotion {
        IslandMotion(settings: settings(preset, speed: speed), reduceMotion: reduce, savingBattery: saving)
    }

    /// Runs `body` with `motion` in force, then puts the previous one back.
    private static func with<T>(_ motion: IslandMotion, _ body: () -> T) -> T {
        let previous = IslandMotion.current
        IslandMotion.current = motion
        defer { IslandMotion.current = previous }
        return body()
    }

    private static func overshoot(from: CGSize, to: CGSize) -> CGFloat {
        NotchMotion.frames(from: from, to: to).sizes.map { $0.height - to.height }.max() ?? 0
    }

    // MARK: Zenith 1× is the tuned motion

    private static func reference(_ suite: TestSuite) {
        let zenith = IslandMotion.standard
        suite.expect(IslandMotion.current == .standard || IslandMotion.current.settings == .standard,
                     "the tests start from the standard motion")
        suite.expect(zenith.style == .full && zenith.bounceScale == 1 && zenith.blurScale == 1
                     && zenith.shapeTimeScale == 1 && zenith.contentTimeScale == 1 && zenith.squashScale == 1,
                     "Zenith 1× scales nothing")
        for spring in [ZenithIslandMotion.growingWidth, ZenithIslandMotion.growingHeight, ZenithIslandMotion.shrinkingWidth,
                       ZenithIslandMotion.shrinkingHeight, ZenithIslandMotion.landingWidth, NotchMotion.steadyWidth] {
            suite.expect(zenith.shape(spring) == spring, "Zenith 1× keeps the approved spring \(spring)")
        }
        suite.expect(zenith.opening == Ride.Timing(outgoingFade: 0.1, incomingDelay: 0.03, incomingFade: 0.2, outgoingCap: 1.1)
                     && zenith.closing == Ride.Timing(outgoingFade: 0.17, incomingDelay: 0.1, incomingFade: 0.2, outgoingCap: 1),
                     "Zenith 1× rides the content on the tuned timing, blurs and rise")
        suite.expect(zenith.opening.incomingBlur == 6 && zenith.opening.outgoingBlur == 8 && zenith.opening.incomingRise == 8
                     && zenith.opening.incomingFloor == 0.35,
                     "the arriving page grows with the island from a 6 point blur, 8 points up")
        // The mockup the owner chose: a bouncier container, content growing from 90% into focus.
        suite.expect(zenith.morph == IslandCurve(.spring(damping: 1 - 0.45 * 0.7), duration: 0.46)
                     && zenith.arriving == IslandCurve(.bezier(0.22, 1, 0.36, 1), duration: 0.32, delay: 0.06)
                     && zenith.morphBlurIn == 10 && zenith.morphScaleIn == 0.9,
                     "SwiftUI swaps follow Nanti · Zenith: spring 0.46 / 0.685, content from 90% and a 10 point blur")
        suite.expect(abs(IslandMotionSettings.standard.springDamping - 0.685) < 1e-9
                     && zenith.morph.duration > ZenithMorphReference.previousResponse
                     && IslandMotionSettings.standard.springDamping < ZenithMorphReference.previousDamping,
                     "Zenith's swap spring bounces more than the 0.38 / 0.86 it replaces")
    }

    private enum ZenithMorphReference {
        static let previousResponse = 0.38
        static let previousDamping = 0.86
    }

    // MARK: Speed

    private static func speed(_ suite: TestSuite) {
        let fast = motion(.zenith, speed: 2), slow = motion(.zenith, speed: 0.5)
        let width = ZenithIslandMotion.growingWidth
        suite.expect(abs(fast.shape(width).duration - width.duration / 2) < 1e-12
                     && abs(slow.shape(width).duration - width.duration * 2) < 1e-12
                     && fast.shape(width).bounce == width.bounce,
                     "speed scales the shape's time, not its bounce")
        suite.expect(abs(fast.shapeTime(ZenithIslandMotion.growingHeightLag) - 0.01) < 1e-12,
                     "the lag between the sides scales with the speed")
        suite.expect(abs(fast.opening.duration - 0.115) < 1e-9 && abs(slow.opening.duration - 0.46) < 1e-9
                     && abs(fast.closing.outgoingFade - 0.085) < 1e-9,
                     "the content's ride scales with the speed")
        let base = NotchMotion.settlingTime(from: closed, to: open)
        let quick = with(fast) { NotchMotion.settlingTime(from: closed, to: open) }
        let unhurried = with(slow) { NotchMotion.settlingTime(from: closed, to: open) }
        suite.expect(abs(quick - base / 2) < 0.02 && unhurried > base * 1.8,
                     "the island settles twice as fast at 2× and half as fast at 0.5×: \(quick) \(base) \(unhurried)")
        let baseSwing = overshoot(from: closed, to: open)
        let quickSwing = with(fast) { overshoot(from: closed, to: open) }
        suite.expect(abs(quickSwing - baseSwing) < 2,
                     "at any speed the island swings and squashes as far: \(quickSwing) vs \(baseSwing)")
        suite.expect(abs(fast.curve(IslandCurve(.easeOut, duration: 0.15)).duration - 0.075) < 1e-12
                     && abs(slow.curve(IslandCurve(.smooth, duration: 0.3)).duration - 0.6) < 1e-12,
                     "hovers and strips scale with the speed")
        let paced = with(fast) { IslandMotion.paced(0.42) }
        suite.expect(abs(paced - 0.21) < 1e-12, "a wait timed against a curve keeps pace with it")
    }

    // MARK: Snappy: shape first, then sharp content

    private static func staged(_ suite: TestSuite) {
        let snappy = motion(.snappy)
        let values = IslandMotionPreset.snappy.values
        suite.expect(snappy.staged && snappy.bounceScale == 0 && snappy.squashScale == 0,
                     "Snappy's shape lands without a swing or a squash")
        suite.expect(abs(snappy.shape(ZenithIslandMotion.growingWidth).duration - 0.52 * 0.36) < 1e-12
                     && snappy.shape(ZenithIslandMotion.growingWidth).bounce == 0,
                     "Snappy's container runs on a short critically damped spring")
        let swing = with(snappy) { overshoot(from: closed, to: open) }
        let settle = with(snappy) { NotchMotion.settlingTime(from: closed, to: open) }
        suite.expect(swing <= 0.5 && settle < 0.32, "Snappy's island never passes its size and settles within 0.32 s: \(swing) \(settle)")
        let settings = settings(.snappy)
        suite.expect(snappy.opening.incomingDelay == settings.contentDelay && snappy.opening.incomingFade == settings.contentDuration
                     && abs(settings.contentDelay - 0.135 / values.contentPace) < 1e-12,
                     "Snappy's content waits for the shape, then arrives quickly")
        suite.expect(snappy.opening.incomingRise == 0 && snappy.opening.incomingFloor == 0.98 && snappy.opening.outgoingCap == 1,
                     "Snappy's content lands in place, sharp, with only a hint of growth")
        let shapeAtContent = with(snappy) {
            NotchMotion.size(at: snappy.opening.incomingDelay, from: closed, to: open).height
        }
        let zenithAtContent = NotchMotion.size(at: IslandMotion.standard.opening.incomingDelay, from: closed, to: open).height
        suite.expect((shapeAtContent - closed.height) / (open.height - closed.height) > 0.6
                     && (zenithAtContent - closed.height) / (open.height - closed.height) < 0.2,
                     "staged, most of the shape is there when the content starts; riding along, the content starts with it")
        suite.expect(snappy.morph == IslandCurve(.bezier(0.22, 1, 0.36, 1), duration: 0.135)
                     && snappy.arriving.delay == settings.contentDelay && snappy.morphScaleIn == 0.98
                     && snappy.morphBlurIn == CGFloat(values.blur),
                     "a staged SwiftUI swap: a 135 ms container, then the content")
        let zenith = IslandMotion.standard
        suite.expect(zenith.arrivingGrowth != zenith.arriving && snappy.arrivingGrowth == snappy.arriving,
                     "only riding along does the content grow on the shape's spring")
    }

    // MARK: Calm and Playful

    private static func presets(_ suite: TestSuite) {
        let zenithSwing = overshoot(from: closed, to: open)
        let playfulSwing = with(motion(.playful)) { overshoot(from: closed, to: open) }
        let calmSwing = with(motion(.calm)) { overshoot(from: closed, to: open) }
        suite.expect(playfulSwing > zenithSwing && calmSwing < zenithSwing && calmSwing >= 0,
                     "Playful swings further than Zenith and Calm less: \(playfulSwing) \(zenithSwing) \(calmSwing)")
        let calm = motion(.calm)
        suite.expect(calm.opening.duration > IslandMotion.standard.opening.duration
                     && calm.blurScale > 1 && calm.opening.incomingBlur > 6,
                     "Calm's content arrives more slowly through a softer blur")
        var custom = settings(.custom)
        custom.values.bounce = 0
        custom.values.blur = 0
        let flat = IslandMotion(settings: custom)
        suite.expect(flat.bounceScale == 0 && flat.opening.incomingBlur == 0 && flat.morphBlurIn == 0,
                     "Custom at no bounce and no blur moves without either")
        suite.expect(motion(.playful).shape(ZenithIslandMotion.growingWidth).bounce < 0.85,
                     "no preset bounces past the cap")
    }

    // MARK: Reduce Motion

    private static func reduceMotion(_ suite: TestSuite) {
        for preset in IslandMotionPreset.allCases {
            let reduced = motion(preset, reduce: true, saving: preset == .playful)
            suite.expect(reduced.style == .reduced && reduced.bounceScale == 0 && reduced.squashScale == 0
                         && reduced.blurScale == 0, "Reduce Motion drops bounce, squash and blur (\(preset))")
            suite.expect(reduced.opening.incomingBlur == 0 && reduced.opening.outgoingBlur == 0
                         && reduced.opening.incomingRise == 0 && reduced.opening.incomingFloor == 1,
                         "Reduce Motion's content only fades (\(preset))")
            suite.expect(reduced.morph == IslandCurve(.easeInOut, duration: 0.2) && reduced.morphScaleIn == 1
                         && reduced.morphBlurIn == 0, "Reduce Motion's swaps are short cross-fades (\(preset))")
            let spring = reduced.curve(IslandCurve(.spring(damping: 0.7), duration: 0.4))
            let slow = reduced.curve(IslandCurve(.smooth, duration: 0.6))
            suite.expect(spring.kind == .easeInOut && spring.duration <= 0.2 && slow.duration <= 0.2,
                         "under Reduce Motion every small curve is a short cross-fade (\(preset))")
        }
        let frame = Ride.composite(at: 0.1, islandWidth: 300, from: 300, to: 300, reduceMotion: true)
        suite.expect(frame.blur == 0 && frame.scale == 1 && frame.offset == 0, "the window host's ride is a plain crossfade")
    }

    // MARK: Battery saver

    private static func batterySaver(_ suite: TestSuite) {
        let saving = motion(.zenith, saving: true)
        suite.expect(saving.style == .plain && saving.bounceScale == 0 && saving.blurScale == 0 && saving.squashScale == 0,
                     "the saver drops bounce, squash and blur")
        suite.expect(saving.opening.incomingBlur == 0 && saving.opening.outgoingBlur == 0 && saving.opening.incomingRise == 0
                     && saving.opening.incomingFloor == 1 && saving.opening.outgoingFloor == 1 && saving.opening.outgoingCap == 1,
                     "the saver's content fades in place")
        suite.expect(saving.opening.duration == IslandMotion.standard.opening.duration,
                     "the saver keeps the preset's pace")
        let swing = with(saving) { overshoot(from: closed, to: open) }
        let squashed = with(saving) { NotchMotion.shape(at: 0.1, from: closed, to: open) == NotchMotion.size(at: 0.1, from: closed, to: open) }
        suite.expect(swing <= 0.5 && squashed, "the saver's island neither swings nor squashes: \(swing)")
        let times = stride(from: 0.0, through: 0.5, by: 1.0 / 120).map { $0 }
        let frames = with(saving) {
            Ride.frames(at: times, islandWidths: times.map { _ in 680 }, from: 200, to: 680)
        }
        suite.expect(frames.allSatisfy { $0.blur == 0 && $0.scale == 1 && $0.offset == 0 },
                     "the saver's ride has no blur, so the window host adds no blur filter")
        suite.expect(saving.morph.kind == .spring(damping: 1) && saving.morphBlurIn == 0 && saving.morphScaleIn == 1,
                     "the saver's swaps glide without a bounce or a blur")
        suite.expect(saving.curve(IslandCurve(.spring(damping: 0.6), duration: 0.3)).kind == .spring(damping: 1)
                     && saving.curve(IslandCurve(.smooth, duration: 0.3)).kind == .easeInOut
                     && saving.curve(IslandCurve(.bezier(0.34, 1.36, 0.5, 1), duration: 0.3)).kind == .bezier(0.34, 1, 0.5, 1),
                     "the saver takes the overshoot out of the small curves")
        suite.expect(motion(.zenith, reduce: true, saving: true).style == .reduced, "Reduce Motion wins over the saver")
    }

    // MARK: Small curves

    private static func smallCurves(_ suite: TestSuite) {
        let zenith = IslandMotion.standard
        let hover = IslandCurve(.easeOut, duration: 0.15)
        suite.expect(zenith.curve(hover) == hover, "Zenith 1× keeps every hover as it was")
        let press = IslandCurve(.spring(damping: 0.7), duration: 0.3)
        suite.expect(zenith.curve(press) == press, "Zenith 1× keeps every spring as it was")
        let playful = motion(.playful).curve(press), snappy = motion(.snappy).curve(press)
        if case let .spring(lively) = playful.kind, case let .spring(still) = snappy.kind {
            suite.expect(lively < 0.7 && lively >= 0.3 && still == 1,
                         "a press springs more under Playful and not at all under Snappy: \(lively) \(still)")
        } else {
            suite.expect(false, "springs stay springs")
        }
        let pop = motion(.calm).curve(IslandCurve(.bezier(0.34, 1.36, 0.5, 1), duration: 0.3))
        if case let .bezier(_, y1, _, _) = pop.kind {
            suite.expect(y1 > 1 && y1 < 1.36, "Calm softens an overshooting curve: \(y1)")
        } else {
            suite.expect(false, "a bezier stays a bezier")
        }
        let delayed = motion(.zenith, speed: 2).curve(IslandCurve(.easeOut, duration: 0.2, delay: 0.1))
        suite.expect(abs(delayed.delay - 0.05) < 1e-12, "a curve's delay keeps pace with the speed")
    }

    // MARK: Live updates

    private static func liveUpdates(_ suite: TestSuite) {
        let before = Ride.Timing.opening
        let during = with(motion(.snappy, speed: 2)) { (Ride.Timing.opening, ZenithMorph.response, Ride.duration) }
        suite.expect(during.0 == motion(.snappy, speed: 2).opening && during.1 < 0.1 && during.2 < before.duration,
                     "a new motion applies to the very next animation, without a restart")
        suite.expect(Ride.Timing.opening == before, "and the previous motion returns when it is put back")
        let defaults = UserDefaults(suiteName: "vorss.tests.island-motion-system")!
        defaults.removePersistentDomain(forName: "vorss.tests.island-motion-system")
        defer { defaults.removePersistentDomain(forName: "vorss.tests.island-motion-system") }
        defaults.set(IslandMotionPreset.custom.rawValue, forKey: ZenithAppearanceDefaults.motionPreset)
        defaults.set(0.0, forKey: ZenithAppearanceDefaults.motionBounce)
        defaults.set(2.0, forKey: ZenithAppearanceDefaults.motionSpeed)
        let loaded = IslandMotion(settings: IslandMotionSettings.load(from: defaults))
        suite.expect(loaded.bounceScale == 0 && loaded.speed == 2 && abs(loaded.opening.duration - 0.115) < 1e-9,
                     "the sliders in Settings become the island's motion")
    }

    // MARK: The agents' frame rate

    private static func agentPolicy(_ suite: TestSuite) {
        typealias Policy = IslandAgentMotion
        let seen = Policy.Conditions(animates: true, visible: true, inIsland: true, islandPresenting: true,
                                     screenAwake: true, savingBattery: false)
        suite.expect(Policy.decide(seen) == .running(framesPerSecond: 30) && Policy.rate == 30,
                     "an agent working where it can be seen animates at 30 fps")
        func with(_ change: (inout Policy.Conditions) -> Void) -> Policy {
            var conditions = seen
            change(&conditions)
            return Policy.decide(conditions)
        }
        suite.expect(with { $0.animates = false } == .paused, "idle agents, or Reduce Motion, rest")
        suite.expect(with { $0.visible = false } == .paused, "a hidden or covered island (a full-screen app) pauses the loop")
        suite.expect(with { $0.islandPresenting = false } == .paused, "the island locked or its displays off pauses the loop")
        suite.expect(with { $0.screenAwake = false } == .paused, "a sleeping screen pauses the loop")
        suite.expect(with { $0.savingBattery = true } == .paused, "the battery saver shows the still pose instead")
        suite.expect(with { $0.inIsland = false; $0.islandPresenting = false } == .running(framesPerSecond: 30),
                     "the lock screen's own agents keep moving while the island is away")
        suite.expect(with { $0.inIsland = false; $0.screenAwake = false } == .paused,
                     "and stop once the screen sleeps")
        suite.expect(Policy.rate <= NotchDecorativeClock.rate, "the agents' loop never asks for more than the decorations' rate")
    }

    @MainActor
    private static func agentView(_ suite: TestSuite) {
        final class Window: NSWindow {
            override var isVisible: Bool { true }
            override var occlusionState: NSWindow.OcclusionState { [.visible] }
        }
        final class IslandWindow: NSPanel, IslandAgentHostWindow {
            override var isVisible: Bool { true }
            override var occlusionState: NSWindow.OcclusionState { [.visible] }
        }
        let gate = IslandAgentMotionGate.shared
        let saved = (gate.islandPresenting, gate.screenAwake, gate.savingBattery)
        defer { gate.update(islandPresenting: saved.0, screenAwake: saved.1, savingBattery: saved.2) }
        gate.update(islandPresenting: true, screenAwake: true, savingBattery: false)
        let image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)
        for island in [true, false] {
            let window: NSWindow = island
                ? IslandWindow(contentRect: CGRect(x: 0, y: 0, width: 40, height: 40), styleMask: .borderless,
                               backing: .buffered, defer: false)
                : Window(contentRect: CGRect(x: 0, y: 0, width: 40, height: 40), styleMask: .borderless,
                         backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            let container = NSView(frame: window.frame)
            window.contentView = container
            let view = NotchAgentAnimationView(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
            view.configureGlyph(image: image, size: 13, tint: .white, animates: true)
            container.addSubview(view)
            let place = island ? "the island" : "the lock screen"
            suite.expect(view.isMoving && view.motion == .running(framesPerSecond: 30),
                         "a working agent in \(place) animates")
            if let cap = view.frameRateCap {
                suite.expect(cap == 30, "its display link asks for at most 30 frames a second in \(place): \(cap)")
            }
            gate.update(savingBattery: true)
            suite.expect(!view.isMoving && view.motion == .paused, "the battery saver stops it at once in \(place)")
            view.step(at: view.motionStart + 0.6)
            suite.expect((view.layer?.sublayers?.first?.transform.m11 ?? 0) == 1,
                         "and leaves it in its still pose in \(place)")
            gate.update(savingBattery: false)
            suite.expect(view.isMoving, "it resumes when the saver ends in \(place)")
            gate.update(islandPresenting: false)
            suite.expect(view.isMoving == !island, island ? "the island locked stops its agents"
                         : "the lock screen's agents keep moving while locked")
            gate.update(islandPresenting: true, screenAwake: false)
            suite.expect(!view.isMoving, "a sleeping screen stops the agents in \(place)")
            gate.update(screenAwake: true)
            suite.expect(view.isMoving, "waking the screen resumes them in \(place)")
            view.stop()
            view.removeFromSuperview()
        }
    }
}
