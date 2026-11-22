// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Adapted from Glance by Jonathan Zhou (MIT), https://github.com/jonnyoo/glance (tools/liveness_selftest.swift).

import CoreGraphics
import Foundation

/// Zenith fork: Glance's offline, camera-free liveness self-test as a suite.
///
/// Two halves:
///
/// 1. The flat-vs-3D cue, against synthetic landmark sequences — a PLANAR
///    generator (everything a printed photo or phone screen can physically
///    do: rigid 2D rotation/scale/translation, plus a perspective/shear
///    "wobble" simulating someone tilting the phone to fake parallax, plus
///    per-point detector noise) versus a 3D one (nose protruding off the
///    eye plane, undergoing the same small head rotation). Asserts the 3D
///    sequence scores materially higher, and that a still 3D head
///    *abstains* rather than being called a photo.
///
/// 2. The decision model itself — that deny cues fire and latch, that they
///    override a confirmation, that Light mode auto-confirms while Heavy
///    mode waits for real proof, and that every cue abstains rather than
///    guessing when it has no data.
enum FaceUnlockLivenessTests {
    static func run(_ suite: TestSuite) {
        geometry(suite)
        decisionModel(suite)
        abstention(suite)
        analyzer(suite)
    }

    // MARK: - Flat vs 3D (the one cue with real geometry behind it)

    private static let frameCount = 20 // ~1s at ~20fps

    private static func planarScore(_ window: [LivenessFrame]) -> CueReading {
        GeometryLiveness.evaluate(window).planarReading
    }

    private static func geometry(_ suite: TestSuite) {
        // Glance prints a sweep over noise levels to find where separation breaks down;
        // here the clean end of that sweep must separate a live face from a wobbled photo.
        for noise: CGFloat in [0, 0.5, 1.0] {
            let wobble = planarScore(generatePlanarSequence(frameCount: frameCount, noiseStd: noise, seed: 1))
            let live = planarScore(generateLiveSequence(frameCount: frameCount, noiseStd: noise, seed: 2))
            suite.expect(live.level - wobble.level > 0.05,
                         "flat vs 3D ranks a live face above a wobbled photo at \(noise)px noise (\(live.level) vs \(wobble.level))")
        }

        // A true-homography tilted photo must score below a 3D face, and a
        // still 3D face must abstain (confidence 0) rather than being
        // called a photo — the failure mode that makes a cue unusable as a
        // *confirm* signal is a false confirm, not a missed one.
        let live = planarScore(generateLiveSequence(frameCount: frameCount, noiseStd: 1.0, seed: 2))
        let tilted = planarScore(generateTiltedPhotoSequence(frameCount: frameCount, noiseStd: 1.0, seed: 4))
        let stillLive = planarScore(generateStillLiveSequence(frameCount: frameCount, noiseStd: 0.3, seed: 5))

        suite.expect(live.confidence > 0,
                     "a live 3D face clears the motion gate and gets geometry confidence")
        suite.expect(live.level > tilted.level + 0.15,
                     "flat vs 3D ranks a 3D face (\(live.level)) above a tilted photo (\(tilted.level))")
        suite.expect(stillLive.confidence < 0.05,
                     "a still 3D face abstains from geometry, got confidence \(stillLive.confidence)")
        // Load-bearing for the whole confirm-cue design: a photo must never
        // be able to *fire* this cue, since one firing is enough to pass.
        suite.expect(tilted.confidence == 0 || tilted.level < LivenessTuning.default.flatVs3DLevel,
                     "a tilted photo never reaches the flat vs 3D fire level (\(tilted.level))")

        let yawRange = GeometryLiveness.evaluate(
            generateLiveSequence(frameCount: frameCount, noiseStd: 1.0, seed: 2)
        ).diagnosticRatios["yaw range (deg)"] ?? 0
        suite.expect(yawRange >= 12, "the live sequence's yaw range (\(yawRange)) clears the minimum-rotation gate")
    }

    // MARK: - Decision model

    /// A frame carrying only what the deny cues read — everything else is a
    /// harmless placeholder, since no geometry is under test here.
    private static func makeCueFrame(
        at t: TimeInterval, glare: GlareSample? = nil, deviceOverlap: CGFloat? = nil
    ) -> LivenessFrame {
        LivenessFrame(
            timestamp: Date(timeIntervalSince1970: t), landmarks: [], interocularDistance: nil,
            yaw: nil, leftEyeAspectRatio: nil, rightEyeAspectRatio: nil, noseOffsetRatio: nil,
            hasReliableLandmarks: true, deviceOverlapFraction: deviceOverlap, glare: glare
        )
    }

    /// Skin: a few small scattered highlights. Screen: a big concentrated
    /// glare blob. Plausible rather than measured — real-device readings
    /// were ~0% on a live face and 30-40% against a phone, which is the
    /// separation these stand in for.
    private static let skinGlare = GlareSample(cropPixelWidth: 140, specularFraction: 0.004, specularClusterRatio: 0.15)
    private static let screenGlare = GlareSample(cropPixelWidth: 140, specularFraction: 0.09, specularClusterRatio: 0.75)

    private static func evaluate(
        _ frames: [LivenessFrame], mode: LivenessMode, cues: Set<LivenessCue> = Set(LivenessCue.allCases)
    ) -> LivenessSnapshot {
        var evaluator = LivenessEvaluator(mode: mode, tuning: .default, enabledCues: cues)
        var window: [LivenessFrame] = []
        var snapshot = LivenessSnapshot.empty
        for frame in frames {
            window.append(frame)
            window.removeAll { frame.timestamp.timeIntervalSince($0.timestamp) > 2.0 }
            snapshot = evaluator.observe(LivenessCues.readings(window: window, geometry: GeometryLiveness.evaluate(window)))
        }
        return snapshot
    }

    private static func decisionModel(_ suite: TestSuite) {
        // Glare sustained across enough frames must deny, in either mode.
        let glareFrames = (0..<8).map { makeCueFrame(at: Double($0) * 0.05, glare: screenGlare) }
        for mode in LivenessMode.allCases {
            let result = evaluate(glareFrames, mode: mode)
            suite.expect(result.decision == .denied(by: .glossGlare),
                         "sustained screen glare denies in \(mode.title) mode, got \(result.decision)")
        }

        // Device overlap above the fire level must deny, even well below
        // the old 0.55 bezel threshold — 20% for a few frames is the rule.
        let deviceFrames = (0..<8).map { makeCueFrame(at: Double($0) * 0.05, glare: skinGlare, deviceOverlap: 0.25) }
        let deviceResult = evaluate(deviceFrames, mode: .light)
        suite.expect(deviceResult.decision == .denied(by: .deviceDetected),
                     "25% device overlap over 8 frames denies, got \(deviceResult.decision)")

        // A single glare frame is not enough — the frame count is what
        // separates a real tell from one bright reflection.
        let blipFrames = [makeCueFrame(at: 0, glare: screenGlare)]
            + (1..<8).map { makeCueFrame(at: Double($0) * 0.05, glare: skinGlare) }
        let blipResult = evaluate(blipFrames, mode: .light)
        suite.expect(!blipResult.decision.isDenied, "one glare frame does not deny on its own, got \(blipResult.decision)")

        // Clean skin: Light auto-confirms, Heavy stays pending (nothing has
        // proven the face is real, but nothing has failed it either).
        let cleanFrames = (0..<8).map { makeCueFrame(at: Double($0) * 0.05, glare: skinGlare) }
        let cleanLight = evaluate(cleanFrames, mode: .light)
        suite.expect(cleanLight.decision == .confirmed(by: nil), "Light mode auto-confirms a clean face, got \(cleanLight.decision)")
        let cleanHeavy = evaluate(cleanFrames, mode: .heavy)
        suite.expect(cleanHeavy.decision == .pending,
                     "Heavy mode stays pending with no confirm cue, got \(cleanHeavy.decision)")

        // Light mode must not confirm before the deny cues have had a
        // chance to run — otherwise "confirmed unless proven wrong" would
        // be hollow on a first-frame match.
        let oneFrame = evaluate([makeCueFrame(at: 0, glare: skinGlare)], mode: .light)
        suite.expect(oneFrame.decision == .pending,
                     "Light mode waits for its minimum observation window, got \(oneFrame.decision) on frame 1")

        // Deny overrides an existing confirmation: a real 3D face that
        // fires flat-vs-3D, then a device rectangle appears.
        var mixed = generateLiveSequence(frameCount: frameCount, noiseStd: 0.2, seed: 2)
        let lastTime = mixed.last!.timestamp.timeIntervalSince1970
        var confirmedFirst = LivenessEvaluator(mode: .heavy)
        var window: [LivenessFrame] = []
        for frame in mixed {
            window.append(frame)
            window.removeAll { frame.timestamp.timeIntervalSince($0.timestamp) > 2.0 }
            _ = confirmedFirst.observe(LivenessCues.readings(window: window, geometry: GeometryLiveness.evaluate(window)))
        }
        suite.expect(confirmedFirst.states[.flatVs3D]?.hasFired == true,
                     "the synthetic live sequence fires flat vs 3D, so the override check is meaningful")
        mixed += (1...6).map { makeCueFrame(at: lastTime + Double($0) * 0.05, glare: skinGlare, deviceOverlap: 0.4) }
        var overridden = LivenessEvaluator(mode: .heavy)
        window = []
        var finalDecision = LivenessDecision.pending
        for frame in mixed {
            window.append(frame)
            window.removeAll { frame.timestamp.timeIntervalSince($0.timestamp) > 2.0 }
            finalDecision = overridden.observe(
                LivenessCues.readings(window: window, geometry: GeometryLiveness.evaluate(window))
            ).decision
        }
        suite.expect(finalDecision == .denied(by: .deviceDetected),
                     "a device rectangle after a confirmation overrides it, got \(finalDecision)")

        // Disabling a cue in Face Lab must actually take it out of the vote.
        let glareDisabled = evaluate(glareFrames, mode: .light, cues: [.deviceDetected, .flatVs3D, .depthPose, .blink])
        suite.expect(!glareDisabled.decision.isDenied, "a disabled cue drops out of the decision, got \(glareDisabled.decision)")

        // The depth/pose level is a remapped correlation, so r = 0 lands at
        // exactly 0.5. Guard the gate against ever being lowered to where
        // pure noise would read as proof of depth.
        suite.expect(LivenessTuning.default.depthPoseLevel > 0.5,
                     "the depth/pose gate (\(LivenessTuning.default.depthPoseLevel)) sits above zero correlation")
    }

    // MARK: - Abstention

    private static func abstention(_ suite: TestSuite) {
        // No crop, no landmarks, no overlap: every cue must abstain rather
        // than read zero, so an absent measurement can neither convict nor
        // acquit.
        let blankWindow = (0..<8).map { makeCueFrame(at: Double($0) * 0.05) }
        let readings = LivenessCues.readings(window: blankWindow, geometry: GeometryLiveness.evaluate(blankWindow))
        for cue in LivenessCue.allCases {
            let reading = readings[cue] ?? .none
            suite.expect(reading.confidence == 0, "\(cue.title) abstains with no data, got confidence \(reading.confidence)")
        }
    }

    // MARK: - Analyzer (Zenith fork)

    /// The rolling window the unlock scan actually uses: the evaluator's fire counts
    /// outlive the ~2 s window, so a spoof tell can't be waited out, and reset clears them.
    private static func analyzer(_ suite: TestSuite) {
        MainActor.assumeIsolated {
            let analyzer = LivenessAnalyzer()
            analyzer.modeProvider = { .light }
            var decision = LivenessDecision.pending
            for i in 0..<8 {
                decision = analyzer.observe(makeCueFrame(at: Double(i) * 0.05, glare: screenGlare)).decision
            }
            suite.expect(decision == .denied(by: .glossGlare), "the analyzer denies sustained glare")
            for i in 0..<60 {
                decision = analyzer.observe(makeCueFrame(at: 3 + Double(i) * 0.05, glare: skinGlare)).decision
            }
            suite.expect(decision == .denied(by: .glossGlare), "a denial latches for the scan after the glare leaves the window")
            analyzer.reset()
            suite.expect(analyzer.lastSnapshot == .empty && analyzer.observe(makeCueFrame(at: 10, glare: skinGlare)).decision == .pending,
                         "reset clears the latched denial")
        }
    }
}

// MARK: - Face template

/// A crude but topologically faithful 2D face template — enough points per
/// region for `solveSimilarityTransform` (needs >= 2, anchor regions here
/// give 8-11) and for the flexible-region residual signals to have several
/// independent points to work with. Units are arbitrary; interocular
/// distance is ~140, in the same ballpark as a face filling a meaningful
/// fraction of a 640px-wide downscaled camera frame.
private func baseTemplate() -> [LandmarkRegion: [CGPoint]] {
    [
        .leftEye: [CGPoint(x: -80, y: -5), CGPoint(x: -75, y: 5), CGPoint(x: -65, y: 5), CGPoint(x: -60, y: -5)],
        .rightEye: [CGPoint(x: 60, y: -5), CGPoint(x: 65, y: 5), CGPoint(x: 75, y: 5), CGPoint(x: 80, y: -5)],
        .nose: [CGPoint(x: -5, y: -35), CGPoint(x: 0, y: -45), CGPoint(x: 5, y: -35)],
        .outerLips: [
            CGPoint(x: -25, y: -95), CGPoint(x: -12, y: -105), CGPoint(x: 0, y: -108),
            CGPoint(x: 12, y: -105), CGPoint(x: 25, y: -95), CGPoint(x: 0, y: -90),
        ],
        .leftEyebrow: [CGPoint(x: -85, y: 20), CGPoint(x: -72, y: 26), CGPoint(x: -58, y: 22)],
        .rightEyebrow: [CGPoint(x: 58, y: 22), CGPoint(x: 72, y: 26), CGPoint(x: 85, y: 20)],
        .noseCrest: [CGPoint(x: 0, y: -10), CGPoint(x: 0, y: -22), CGPoint(x: 0, y: -32)],
        .medianLine: [CGPoint(x: 0, y: -5), CGPoint(x: 0, y: -40), CGPoint(x: 0, y: -70)],
        .faceContour: (0..<8).map { i -> CGPoint in
            let angle = Double(i) / 8 * 2 * .pi
            return CGPoint(x: 150 * cos(angle), y: -30 + 170 * sin(angle))
        },
    ]
}

/// Per-point depth (z, toward the camera is positive) for the 3D generator.
/// Only the nose protrudes — the physical fact `poseDepthConsistency`
/// exploits. Everything else sits flush on the eye plane, same as a real
/// face's eyes/brow/jaw line does relative to the nose.
private func depthTemplate() -> [LandmarkRegion: CGFloat] {
    [.leftEye: 0, .rightEye: 0, .nose: 28, .noseCrest: 18, .medianLine: 12, .outerLips: 4, .leftEyebrow: 2, .rightEyebrow: 2, .faceContour: 0]
}

private let anchorRegions: Set<LandmarkRegion> = [.leftEye, .rightEye, .nose]
private let flexibleRegions: Set<LandmarkRegion> = [.outerLips, .innerLips, .leftEyebrow, .rightEyebrow, .faceContour, .noseCrest, .medianLine]

// MARK: - Random helpers

/// Seedable PRNG so the sweep and the load-bearing assertions see the
/// same sequences. `SystemRandomNumberGenerator` cannot be seeded, which
/// made the 0.20 live-vs-still margin flake from run to run.
private struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9e3779b97f4a7c15 : seed }
    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}

private func gaussian(std: CGFloat, using rng: inout SplitMix64) -> CGFloat {
    guard std > 0 else { return 0 }
    // Box-Muller.
    let u1 = Double.random(in: 0.0001...0.9999, using: &rng)
    let u2 = Double.random(in: 0...1, using: &rng)
    return CGFloat(sqrt(-2 * log(u1)) * cos(2 * .pi * u2)) * std
}

// MARK: - Sequence generators

/// A flat presentation: the WHOLE template moves as one rigid-ish 2D
/// transform (small rotation, small scale drift, translation) plus a slow
/// shear/perspective "wobble" term — the adversarial case of someone
/// deliberately tilting the phone to fake parallax, which a pure
/// similarity-transform fit can't perfectly absorb either. Every point,
/// anchor or flexible, gets the same transform plus independent noise —
/// there is no such thing as an independently-moving mouth on a photo.
private func generatePlanarSequence(frameCount: Int, noiseStd: CGFloat, seed: UInt64) -> [LivenessFrame] {
    var rng = SplitMix64(seed: seed)
    let template = baseTemplate()
    var frames: [LivenessFrame] = []

    for i in 0..<frameCount {
        let t = Double(i) / Double(max(frameCount - 1, 1))
        let rotation = CGFloat(0.05 * sin(t * 2 * .pi * 0.7))       // small rocking rotation
        let scale: CGFloat = 1 + 0.01 * CGFloat(sin(t * 2 * .pi * 0.5))
        let translation = CGPoint(x: 3 * CGFloat(sin(t * 2 * .pi * 0.3)), y: 2 * CGFloat(cos(t * 2 * .pi * 0.4)))
        // Perspective/shear wobble: grows and decays over the window,
        // shearing X proportional to Y — what a tilted phone does to a
        // flat image. Deliberately affects every region equally.
        let shear = CGFloat(0.018 * sin(t * 2 * .pi * 0.9))

        var landmarks: [LandmarkPoint] = []
        for region in LandmarkRegion.allCases {
            guard let points = template[region] else { continue }
            for (index, base) in points.enumerated() {
                let sheared = CGPoint(x: base.x + shear * base.y, y: base.y)
                let cosT = cos(rotation), sinT = sin(rotation)
                let rotated = CGPoint(
                    x: (sheared.x * cosT - sheared.y * sinT) * scale,
                    y: (sheared.x * sinT + sheared.y * cosT) * scale
                )
                let noisy = CGPoint(
                    x: rotated.x + translation.x + gaussian(std: noiseStd, using: &rng),
                    y: rotated.y + translation.y + gaussian(std: noiseStd, using: &rng)
                )
                landmarks.append(LandmarkPoint(point: noisy, region: region, indexInRegion: index))
            }
        }

        let interocular: CGFloat = 140 * scale
        frames.append(LivenessFrame(
            timestamp: Date(timeIntervalSince1970: t),
            landmarks: landmarks,
            interocularDistance: interocular,
            yaw: Float(rotation),
            leftEyeAspectRatio: 0.35, rightEyeAspectRatio: 0.35,
            noseOffsetRatio: 0,   // a plane's nose offset doesn't move with "yaw" — the whole point
            hasReliableLandmarks: true, deviceOverlapFraction: nil
        ))
    }
    return frames
}

/// A phone held still: the template never moves, only per-point detector
/// noise. This is the case that used to beat a live face on "Motion
/// smoothness" (zero jerk looked "perfectly smooth") and "Motion
/// structure" (a frozen fit-error map looked "highly structured").
private func generateStillPlanarSequence(frameCount: Int, noiseStd: CGFloat, seed: UInt64) -> [LivenessFrame] {
    var rng = SplitMix64(seed: seed)
    let template = baseTemplate()
    var frames: [LivenessFrame] = []

    for i in 0..<frameCount {
        let t = Double(i) / Double(max(frameCount - 1, 1))
        // Spatially correlated jitter: the whole face nudges together,
        // plus a much smaller independent term. Matches real Vision
        // noise; independent-per-point noise made Motion variation
        // think the leftover map was "changing" when it was just
        // uncorrelated detector hash.
        let shared = CGPoint(
            x: gaussian(std: noiseStd, using: &rng),
            y: gaussian(std: noiseStd, using: &rng)
        )
        var landmarks: [LandmarkPoint] = []
        for region in LandmarkRegion.allCases {
            guard let points = template[region] else { continue }
            for (index, base) in points.enumerated() {
                landmarks.append(LandmarkPoint(
                    point: CGPoint(
                        x: base.x + shared.x + gaussian(std: noiseStd * 0.25, using: &rng),
                        y: base.y + shared.y + gaussian(std: noiseStd * 0.25, using: &rng)
                    ),
                    region: region,
                    indexInRegion: index
                ))
            }
        }
        frames.append(LivenessFrame(
            timestamp: Date(timeIntervalSince1970: t),
            landmarks: landmarks,
            interocularDistance: 140,
            yaw: 0,
            leftEyeAspectRatio: 0.35, rightEyeAspectRatio: 0.35,
            noseOffsetRatio: 0,
            hasReliableLandmarks: true, deviceOverlapFraction: nil
        ))
    }
    return frames
}

/// A crude 3D face: small head rotation about the vertical axis (real
/// pose change, not a plane's fake one), applied via simple orthographic
/// projection so the protruding nose's projected X position genuinely
/// shifts with yaw — plus small independent non-rigid motion on the
/// flexible regions only (a live face's soft tissue moving on its own),
/// plus the same per-point noise the planar generator gets.
private func generateLiveSequence(frameCount: Int, noiseStd: CGFloat, seed: UInt64) -> [LivenessFrame] {
    var rng = SplitMix64(seed: seed)
    let template = baseTemplate()
    let depths = depthTemplate()
    var frames: [LivenessFrame] = []

    for i in 0..<frameCount {
        let t = Double(i) / Double(max(frameCount - 1, 1))
        // A few degrees of passive rotation — plausible for someone just
        // sitting normally, not deliberately posing.
        let yaw = CGFloat(0.18 * sin(t * 2 * .pi * 0.6))

        var landmarks: [LandmarkPoint] = []
        for region in LandmarkRegion.allCases {
            guard let points = template[region] else { continue }
            let z = depths[region] ?? 0
            for (index, base) in points.enumerated() {
                // Independent small non-rigid motion — only on soft tissue,
                // never on the anchor set (eyes/nose don't deform).
                var moved = base
                // Nose/crest/median stay rigid-with-depth: independent
                // dancing on the geometry probe set destroys residual
                // coherence, which is the opposite of real nose parallax.
                if flexibleRegions.contains(region), region != .noseCrest, region != .medianLine {
                    // Mouth deforms more than brows/contour — a real
                    // expression, not uniform soft-tissue noise. Equal
                    // amplitudes made Motion variation look the same on
                    // a still photo (even jitter) and a live face.
                    let amplitude: CGFloat
                    switch region {
                    case .outerLips, .innerLips: amplitude = 1.0
                    case .leftEyebrow, .rightEyebrow: amplitude = 0.3
                    default: amplitude = 0.25
                    }
                    let phase = Double(index) * 1.7 + Double(region.rawValue.count) * 0.6
                    moved.x += 8.0 * amplitude * CGFloat(sin(t * 2 * .pi * 1.3 + phase))
                    moved.y += 5.0 * amplitude * CGFloat(cos(t * 2 * .pi * 1.1 + phase))
                }

                // Rotate about Y: x' = x cosY + z sinY (orthographic — drop
                // the resulting z). This is what makes the protruding
                // nose's projected X track yaw and everything else barely
                // move relative to it.
                let cosY = cos(yaw), sinY = sin(yaw)
                let projectedX = moved.x * cosY + z * sinY

                let noisy = CGPoint(
                    x: projectedX + gaussian(std: noiseStd, using: &rng),
                    y: moved.y + gaussian(std: noiseStd, using: &rng)
                )
                landmarks.append(LandmarkPoint(point: noisy, region: region, indexInRegion: index))
            }
        }

        let noseOffset = (28 * sin(yaw)) / 140  // matches the analyzer's own normalization
        frames.append(LivenessFrame(
            timestamp: Date(timeIntervalSince1970: t),
            landmarks: landmarks,
            interocularDistance: 140,
            yaw: Float(yaw),
            leftEyeAspectRatio: 0.35, rightEyeAspectRatio: 0.35,
            noseOffsetRatio: noseOffset,
            hasReliableLandmarks: true, deviceOverlapFraction: nil
        ))
    }
    return frames
}

/// A phone tilted in 3D: every landmark lives on z=0 and is projected
/// with a real focal length, so frame-to-frame motion is a true
/// homography. This is the attack a 4-DOF similarity-transform fit
/// cannot reject, and the one geometry liveness is supposed to catch.
private func generateTiltedPhotoSequence(frameCount: Int, noiseStd: CGFloat, seed: UInt64) -> [LivenessFrame] {
    var rng = SplitMix64(seed: seed)
    let template = baseTemplate()
    let focal: CGFloat = 400
    var frames: [LivenessFrame] = []

    for i in 0..<frameCount {
        let t = Double(i) / Double(max(frameCount - 1, 1))
        let yaw = CGFloat(0.18 * sin(t * 2 * .pi * 0.55))
        let cosY = cos(yaw), sinY = sin(yaw)

        var landmarks: [LandmarkPoint] = []
        for region in LandmarkRegion.allCases {
            guard let points = template[region] else { continue }
            for (index, base) in points.enumerated() {
                let x2 = base.x * cosY
                let z2 = -base.x * sinY
                let denom = focal - z2
                let projected = CGPoint(
                    x: focal * x2 / denom + gaussian(std: noiseStd, using: &rng),
                    y: focal * base.y / denom + gaussian(std: noiseStd, using: &rng)
                )
                landmarks.append(LandmarkPoint(point: projected, region: region, indexInRegion: index))
            }
        }

        frames.append(LivenessFrame(
            timestamp: Date(timeIntervalSince1970: t),
            landmarks: landmarks,
            interocularDistance: 140,
            yaw: Float(yaw),
            leftEyeAspectRatio: 0.35, rightEyeAspectRatio: 0.35,
            noseOffsetRatio: 0,
            hasReliableLandmarks: true, deviceOverlapFraction: nil
        ))
    }
    return frames
}

/// A 3D head that isn't turning — depths are real, but without rotation
/// there is no parallax, so geometry liveness must abstain rather than
/// guess "photo."
private func generateStillLiveSequence(frameCount: Int, noiseStd: CGFloat, seed: UInt64) -> [LivenessFrame] {
    var rng = SplitMix64(seed: seed)
    let template = baseTemplate()
    let depths = depthTemplate()
    var frames: [LivenessFrame] = []

    for i in 0..<frameCount {
        let t = Double(i) / Double(max(frameCount - 1, 1))
        var landmarks: [LandmarkPoint] = []
        for region in LandmarkRegion.allCases {
            guard let points = template[region] else { continue }
            let z = depths[region] ?? 0
            for (index, base) in points.enumerated() {
                // Orthographic at yaw 0: x' = x + 0*z
                _ = z
                landmarks.append(LandmarkPoint(
                    point: CGPoint(
                        x: base.x + gaussian(std: noiseStd, using: &rng),
                        y: base.y + gaussian(std: noiseStd, using: &rng)
                    ),
                    region: region,
                    indexInRegion: index
                ))
            }
        }
        frames.append(LivenessFrame(
            timestamp: Date(timeIntervalSince1970: t),
            landmarks: landmarks,
            interocularDistance: 140,
            yaw: 0,
            leftEyeAspectRatio: 0.35, rightEyeAspectRatio: 0.35,
            noseOffsetRatio: 0,
            hasReliableLandmarks: true, deviceOverlapFraction: nil
        ))
    }
    return frames
}
