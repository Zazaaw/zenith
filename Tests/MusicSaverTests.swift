// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import QuartzCore

// Zenith fork: the island's music bars in the battery saver. The player's
// audio is not read (the tap is released), and the bars hold a still pose
// with no clock until the saver ends, then move again.
enum MusicSaverTests {
    static func run(_ suite: TestSuite) {
        readPolicy(suite)
        drawPolicy(suite)
        MainActor.assumeIsolated { barsView(suite) }
    }

    private static func readPolicy(_ suite: TestSuite) {
        let reads = NotchAudioLevelSupport.reads
        suite.expect(reads(true, true, false, false), "a chosen meter on a Mac that can tap reads the player")
        suite.expect(!reads(true, true, false, true), "the battery saver stops reading, so the tap is released")
        suite.expect(!reads(true, true, true, false), "Reduce Motion stops reading")
        suite.expect(!reads(false, true, false, false) && !reads(true, false, false, false),
                     "off, or a macOS without taps, never reads")
    }

    private static func drawPolicy(_ suite: TestSuite) {
        typealias Motion = NotchEqualizerMotion
        suite.expect(Motion.decide(playing: true, shown: true, savingBattery: false, hasLevels: false) == .swinging,
                     "playing where it shows steps the wave")
        suite.expect(Motion.decide(playing: true, shown: true, savingBattery: false, hasLevels: true) == .live,
                     "with the player's levels it follows them")
        for levels in [false, true] {
            for shown in [false, true] {
                suite.expect(Motion.decide(playing: true, shown: shown, savingBattery: true, hasLevels: levels) == .still,
                             "the saver holds the still pose (shown \(shown), levels \(levels))")
            }
        }
        suite.expect(Motion.decide(playing: false, shown: true, savingBattery: true, hasLevels: false) == .resting
                     && Motion.decide(playing: false, shown: true, savingBattery: false, hasLevels: true) == .resting,
                     "paused bars rest as dots, saver or not")
        suite.expect(Motion.decide(playing: true, shown: false, savingBattery: false, hasLevels: true) == .resting,
                     "out of sight, the bars rest")
    }

    @MainActor
    private static func barsView(_ suite: TestSuite) {
        final class Window: NSWindow {
            override var isVisible: Bool { true }
            override var occlusionState: NSWindow.OcclusionState { [.visible] }
        }
        let gate = IslandAgentMotionGate.shared
        let saved = (gate.islandPresenting, gate.screenAwake, gate.savingBattery)
        defer { gate.update(islandPresenting: saved.0, screenAwake: saved.1, savingBattery: saved.2) }
        gate.update(islandPresenting: true, screenAwake: true, savingBattery: false)

        let window = Window(contentRect: CGRect(x: 0, y: 0, width: 80, height: 40), styleMask: .borderless,
                            backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let container = NSView(frame: CGRect(x: 0, y: 0, width: 80, height: 40))
        window.contentView = container
        let view = NotchEqualizerView(frame: CGRect(x: 0, y: 0, width: 40, height: 20))
        container.addSubview(view)
        func heights() -> [CGFloat] { (view.layer?.sublayers ?? []).map(\.bounds.height) }
        func configure(_ playing: Bool = true, levels: [Double]? = nil) {
            view.configure(animates: playing, bars: 4, barWidth: 2, height: 20, tint: .white, levels: levels)
        }

        configure()
        suite.expect(view.isMoving && view.motion == .swinging, "playing music moves the bars")

        gate.update(savingBattery: true)
        suite.expect(!view.isMoving && view.motion == .still, "the battery saver stops the bars' clock at once")
        let still = heights()
        view.step(at: view.motionStart + 0.6)
        suite.expect(heights() == still, "and nothing steps them while it lasts")
        suite.expect(still.contains { $0 > 2 } && still.allSatisfy { $0 >= 2 && $0 <= 20 },
                     "the still pose keeps a playing shape, not the paused dots")
        configure(levels: [0.9, 0.1, 0.8, 0.2, 0.7, 0.3, 0.6])
        suite.expect(view.motion == .still && heights() == still,
                     "levels arriving late in the saver are not drawn")
        configure(false)
        suite.expect(view.motion == .resting && heights().allSatisfy { $0 == 2 }, "a pause in the saver rests as dots")

        configure()
        gate.update(savingBattery: false)
        suite.expect(view.isMoving && view.motion == .swinging, "the bars move again when the saver ends")
        configure(levels: [0.9, 0.1, 0.8, 0.2, 0.7, 0.3, 0.6])
        suite.expect(view.motion == .live && !view.isMoving, "and follow the player's levels once it reads again")
        view.stop()
        view.removeFromSuperview()
    }
}
