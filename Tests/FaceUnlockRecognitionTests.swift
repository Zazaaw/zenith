// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Face unlock is adapted from Glance by Jonathan Zhou (MIT), https://github.com/jonnyoo/glance.

import CoreGraphics
import CryptoKit
import Foundation

/// Zenith fork: face unlock's recognition logic — embedding math, matching,
/// the sealed store, settings, enrollment poses, the scan window and the model
/// cache. Nothing here opens the camera, loads the model or touches the real store.
enum FaceUnlockRecognitionTests {
    static func run(_ suite: TestSuite) {
        embeddingMath(suite)
        matching(suite)
        identityCoding(suite)
        sealing(suite)
        names(suite)
        settings(suite)
        poses(suite)
        faceSelection(suite)
        scanWindow(suite)
        calibration(suite)
        modelCache(suite)
    }

    // MARK: - Helpers

    private static let model = "arcface-w600k_mbf-v1"

    private static func unit(_ values: [Float]) -> [Float] { FaceEmbedding.l2Normalized(values) }

    private static func identity(
        _ name: String,
        _ embeddings: [[Float]],
        model: String = model,
        enabled: Bool = true
    ) -> FaceIdentity {
        FaceIdentity(
            id: UUID(),
            name: name,
            samples: embeddings.map { FaceSample(embedding: $0, pose: nil, capturedAt: Date(timeIntervalSince1970: 0), quality: 0.6) },
            modelIdentifier: model,
            embeddingDimension: embeddings.first?.count ?? 0,
            createdAt: Date(timeIntervalSince1970: 0),
            isEnabled: enabled
        )
    }

    private static func scored(_ name: String, similarity: Float, model: String = model) -> ScoredIdentity {
        ScoredIdentity(identity: identity(name, [[1, 0]], model: model), centroidSimilarity: similarity, maxSampleSimilarity: similarity)
    }

    private static func face(width: CGFloat, centerX: CGFloat, centerY: CGFloat = 0.5) -> DetectedFace {
        let normalized = CGRect(x: centerX - width / 2, y: centerY - width / 2, width: width, height: width)
        let imageSize = CGSize(width: 640, height: 480)
        return DetectedFace(
            boundingBox: FaceDetector.convertToImageSpace(normalized, imageSize: imageSize),
            normalizedBoundingBox: normalized,
            quality: 0.5, yaw: 0, roll: 0, pitch: 0, landmarks: nil, imageSize: imageSize
        )
    }

    // MARK: - Embeddings

    private static func embeddingMath(_ suite: TestSuite) {
        let normalized = FaceEmbedding.l2Normalized([3, 4])
        suite.expect(abs(normalized[0] - 0.6) < 1e-6 && abs(normalized[1] - 0.8) < 1e-6,
                     "an embedding scales to unit length")
        suite.expect(FaceEmbedding.l2Normalized([0, 0]) == [0, 0], "a zero vector stays as it is rather than dividing by zero")
        suite.expect(abs(FaceEmbedding.cosineSimilarity([1, 0], [1, 0]) - 1) < 1e-6
                        && abs(FaceEmbedding.cosineSimilarity([1, 0], [0, 1])) < 1e-6
                        && abs(FaceEmbedding.cosineSimilarity([1, 0], [-1, 0]) + 1) < 1e-6,
                     "cosine similarity is 1 for the same direction, 0 across, -1 opposite")
        suite.expect(FaceEmbedding.cosineSimilarity([1, 0], [1, 0, 0]) == 0 && FaceEmbedding.cosineSimilarity([], []) == 0,
                     "vectors of different or no length never look similar")
        // A larger-magnitude sample must not dominate the template.
        let average = FaceEmbedding.average([[10, 0], [0, 1]]) ?? []
        suite.expect(average.count == 2 && abs(average[0] - average[1]) < 1e-6
                        && abs(average[0] * average[0] + average[1] * average[1] - 1) < 1e-5,
                     "the template averages normalized samples and is renormalized")
        suite.expect(FaceEmbedding.average([]) == nil, "no samples give no template")
        suite.expect(abs(FaceEmbedding.similarityPercent([1, 0], [1, 0]) - 100) < 1e-6
                        && abs(FaceEmbedding.similarityPercent([1, 0], [-1, 0])) < 1e-6,
                     "the legacy percentage maps -1...1 onto 0...100")
    }

    // MARK: - Matching

    private static func matching(_ suite: TestSuite) {
        let me = identity("Faiz", [unit([1, 0.1]), unit([1, -0.1])])
        let other = identity("Other", [unit([0, 1])])
        let probe = unit([1, 0])
        let result = FaceMatching.score(probe, against: [other, me])
        suite.expect(result.map(\.identity.name) == ["Faiz", "Other"], "scores sort by centroid similarity, best first")
        suite.expect(result.first.map { $0.maxSampleSimilarity >= $0.centroidSimilarity - 0.2 && $0.centroidSimilarity > 0.99 } == true,
                     "an identity is scored on its template and its closest sample")
        suite.expect(FaceMatching.score(probe, against: [identity("Empty", [])]).isEmpty,
                     "an identity without samples is not scored")

        suite.expect(FaceMatching.bestMatch(in: result, threshold: 0.66, modelIdentifier: model)?.identity.name == "Faiz",
                     "the best identity matches once it clears the threshold")
        suite.expect(FaceMatching.bestMatch(in: [scored("Faiz", similarity: 0.65)], threshold: 0.66, modelIdentifier: model) == nil,
                     "below the threshold nothing matches")
        let split = ScoredIdentity(identity: me, centroidSimilarity: 0.9, maxSampleSimilarity: 0.5)
        suite.expect(FaceMatching.bestMatch(in: [split], threshold: 0.66, modelIdentifier: model) == nil,
                     "the closest sample must clear the threshold too, not just the template")
        suite.expect(FaceMatching.bestMatch(in: [scored("Faiz", similarity: 0.99, model: "vision-feature-print-v1")],
                                            threshold: 0.66, modelIdentifier: model) == nil,
                     "samples from another embedder never match")
        suite.expect(FaceMatching.bestMatch(in: [scored("Faiz", similarity: 0.8), scored("Faiz again", similarity: 0.79)],
                                            threshold: 0.66, modelIdentifier: model)?.identity.name == "Faiz",
                     "two close profiles of the same person still match (no runner-up margin)")
        suite.expect(me.isStale(modelIdentifier: model) == false && me.isStale(modelIdentifier: "other") == true,
                     "an identity is stale under a different model")
    }

    // MARK: - Identities on disk

    private static func identityCoding(_ suite: TestSuite) {
        let legacy = """
        [{"id":"8A5E3F4C-1B7D-4C2A-9F3E-2D1C0B9A8E7F","name":"Faiz","samples":[{"embedding":[1,0],"pose":"center","capturedAt":0,"quality":0.5}],"modelIdentifier":"arcface-w600k_mbf-v1","embeddingDimension":2,"createdAt":0}]
        """
        let decoded = try? JSONDecoder().decode([FaceIdentity].self, from: Data(legacy.utf8))
        suite.expect(decoded?.count == 1 && decoded?.first?.isEnabled == true,
                     "an identity saved before the enable switch existed decodes as enabled")

        var disabled = identity("Faiz", [[1, 0]])
        disabled.isEnabled = false
        let roundTrip = (try? JSONEncoder().encode([disabled])).flatMap { try? JSONDecoder().decode([FaceIdentity].self, from: $0) }
        suite.expect(roundTrip == [disabled], "identities round-trip, the enable switch included")

        let qualities: [(Float?, FaceSample.QualityTier)] = [(nil, .unrated), (0.39, .poor), (0.4, .fair), (0.49, .fair), (0.5, .good)]
        suite.expect(qualities.allSatisfy { quality, tier in
            FaceSample(embedding: [], pose: nil, capturedAt: Date(), quality: quality).qualityTier == tier
        }, "sample quality bands: unrated, poor under 0.4, fair under 0.5, good from 0.5")

        let posed = FaceIdentity(
            id: UUID(), name: "Faiz",
            samples: ["center", "center", "left", nil].map { FaceSample(embedding: [1], pose: $0, capturedAt: Date(), quality: nil) },
            modelIdentifier: model, embeddingDimension: 1, createdAt: Date()
        )
        suite.expect(posed.posesCaptured == 2, "poses captured counts distinct tagged poses only")
    }

    private static func sealing(_ suite: TestSuite) {
        let key = SymmetricKey(size: .bits256)
        let identities = [identity("Faiz", [unit([1, 0.2])]), identity("Guest", [unit([0, 1])], enabled: false)]
        guard let sealed = try? FaceIdentitySealing.seal(identities, key: key) else {
            suite.expect(false, "identities seal under the session key")
            return
        }
        let plaintext = (try? JSONEncoder().encode(identities)) ?? Data()
        suite.expect(sealed.range(of: Data("Faiz".utf8)) == nil && sealed != plaintext,
                     "sealed identities do not contain the plaintext")
        suite.expect((try? FaceIdentitySealing.open(sealed, key: key)) == identities, "the same key opens them again")
        let wrongKey: Error?
        do { _ = try FaceIdentitySealing.open(sealed, key: SymmetricKey(size: .bits256)); wrongKey = nil } catch { wrongKey = error }
        suite.expect((wrongKey as? SecureFaceStoreError) == .decryptionFailed, "another key cannot open them")
        var tampered = sealed
        tampered[tampered.count - 1] ^= 0xFF
        suite.expect((try? FaceIdentitySealing.open(tampered, key: key)) == nil, "a tampered store is rejected, not misread")
        suite.expect((try? FaceIdentitySealing.open(Data(), key: key)) == nil, "an empty file is not an empty store")
    }

    private static func names(_ suite: TestSuite) {
        let faiz = identity("Faiz", [[1]])
        let alex = identity("Álex", [[1]])
        let people = [faiz, alex]
        suite.expect(FaceEnrollmentNames.isTaken("faiz", among: people) && FaceEnrollmentNames.isTaken("  alex ", among: people),
                     "names are taken regardless of case, accents and surrounding spaces")
        suite.expect(!FaceEnrollmentNames.isTaken("Faiz", among: people, excluding: faiz.id),
                     "a recapture may keep its own name")
        suite.expect(!FaceEnrollmentNames.isTaken("   ", among: people) && !FaceEnrollmentNames.isTaken("Sam", among: people),
                     "an empty or new name is never taken")
    }

    // MARK: - Settings

    private static func settings(_ suite: TestSuite) {
        let domain = "com.vorssaint.tests.face-unlock-recognition"
        let defaults = UserDefaults(suiteName: domain)!
        defaults.removePersistentDomain(forName: domain)
        defer { defaults.removePersistentDomain(forName: domain) }
        typealias S = FaceUnlockRecognitionSettings

        suite.expect(S.livenessEnabled(defaults) && S.livenessMode(defaults) == .light
                        && S.matchThreshold(defaults) == 0.66 && S.cameraID(defaults) == nil
                        && S.detectionSeconds(defaults) == 5 && S.minimumFaceWidth(defaults) == 0.21,
                     "before anything is set: liveness on in Light mode, threshold 0.66, default camera, 5 s, Glance's face width")

        defaults.set(false, forKey: S.livenessEnabledKey)
        defaults.set("heavy", forKey: S.livenessModeKey)
        defaults.set(0.5 as Double, forKey: S.matchThresholdKey)
        defaults.set(8, forKey: S.detectionSecondsKey)
        S.setCameraID("camera-1", defaults)
        suite.expect(!S.livenessEnabled(defaults) && S.livenessMode(defaults) == .heavy && S.matchThreshold(defaults) == 0.5
                        && S.detectionSeconds(defaults) == 8 && S.cameraID(defaults) == "camera-1",
                     "stored settings are read back, the threshold stored as a Double")

        defaults.set("medium", forKey: S.livenessModeKey)
        defaults.set(42, forKey: S.detectionSecondsKey)
        defaults.set(3.5 as Double, forKey: S.matchThresholdKey)
        suite.expect(S.livenessMode(defaults) == .light && S.detectionSeconds(defaults) == 10 && S.matchThreshold(defaults) == 1,
                     "an unknown mode reads as Light, and out-of-range values are clamped")
        defaults.set(1, forKey: S.detectionSecondsKey)
        suite.expect(S.detectionSeconds(defaults) == 3, "the scan window is at least 3 s")

        defaults.set("", forKey: S.cameraIDKey)
        suite.expect(S.cameraID(defaults) == nil, "an empty camera ID is the default camera")
        S.setCameraID("camera-1", defaults)
        S.setCameraID(nil, defaults)
        suite.expect(defaults.object(forKey: S.cameraIDKey) == nil, "choosing the default camera removes the stored ID")
    }

    // MARK: - Enrollment poses

    private static func poses(_ suite: TestSuite) {
        typealias R = EnrollmentPoseRules
        suite.expect(EnrollmentPose.allCases.count == 9 && EnrollmentPose.allCases.first == .center,
                     "nine poses, center first")
        suite.expect(Set(EnrollmentPose.allCases.map(\.name)).count == 9
                        && EnrollmentPose.allCases.compactMap(\.compassAngle).count == 8,
                     "every pose has its own stored name, and every pose but center its own ring sector")

        suite.expect(R.poseMatches(yaw: 0, pitch: 0, pose: .center, widened: false)
                        && !R.poseMatches(yaw: 0.2, pitch: 0, pose: .center, widened: false),
                     "center wants a level, straight head")
        // Vision: +yaw is a left turn, -pitch looks up.
        suite.expect(R.poseMatches(yaw: 0.3, pitch: 0, pose: .left, widened: false)
                        && !R.poseMatches(yaw: -0.3, pitch: 0, pose: .left, widened: false)
                        && R.poseMatches(yaw: -0.3, pitch: 0, pose: .right, widened: false),
                     "left wants positive yaw, right negative")
        suite.expect(R.poseMatches(yaw: 0, pitch: -0.2, pose: .top, widened: false)
                        && R.poseMatches(yaw: 0, pitch: 0.2, pose: .bottom, widened: false)
                        && !R.poseMatches(yaw: 0, pitch: 0.2, pose: .top, widened: false),
                     "up is negative pitch, down positive")
        suite.expect(R.poseMatches(yaw: 0.3, pitch: -0.2, pose: .topLeft, widened: false)
                        && !R.poseMatches(yaw: 0.3, pitch: 0, pose: .topLeft, widened: false),
                     "a diagonal pose needs both turns")
        suite.expect(!R.poseMatches(yaw: 0.22, pitch: 0, pose: .left, widened: false)
                        && R.poseMatches(yaw: 0.22, pitch: 0, pose: .left, widened: true),
                     "a stalled pose widens its band")
        suite.expect(R.poseMatches(yaw: 0.17, pitch: 0.12, pose: .bottomLeft, widened: false),
                     "the lower diagonals are more lenient")

        suite.expect(R.excessiveTurn(yaw: 0.3, pitch: 0.1) == nil, "a normal turn is not too far")
        suite.expect(R.excessiveTurn(yaw: 0.6, pitch: 0) == .left && R.excessiveTurn(yaw: -0.6, pitch: 0) == .right
                        && R.excessiveTurn(yaw: 0, pitch: -0.4) == .up && R.excessiveTurn(yaw: 0, pitch: 0.4) == .down,
                     "too far reports the axis that went past its cap")
        suite.expect(R.excessiveTurn(yaw: 0.6, pitch: -0.4) == .topLeft && R.excessiveTurn(yaw: -0.6, pitch: 0.4) == .bottomRight,
                     "past both caps reads as the diagonal")
        suite.expect(R.excessiveTurn(yaw: 0.55, pitch: 0.38) == .bottomLeft, "both caps exceeded, left and down")

        suite.expect(R.headTurn(yaw: 0.3, pitch: 0, toward: .center) == nil
                        && R.headTurn(yaw: 0.01, pitch: 0.01, toward: .left) == nil,
                     "no ring indicator at center or inside the dead zone")
        let left = R.headTurn(yaw: 0.24, pitch: 0, toward: .left)
        suite.expect(left.map { abs($0.angle - 270) < 0.5 && $0.progress == 1 } == true,
                     "a full left turn points at the left sector with full progress")
        let up = R.headTurn(yaw: 0, pitch: -0.085, toward: .top)
        suite.expect(up.map { $0.angle < 0.5 && abs($0.progress - 0.5) < 0.01 } == true,
                     "half an upward turn points up at half progress")

        suite.expect(EnrollmentSweepDirection(pose: .center) == nil && EnrollmentSweepDirection(pose: .top) == .up
                        && EnrollmentSweepDirection(pose: .bottomRight) == .bottomRight,
                     "every pose but center has a sweep direction")
        suite.expect(EnrollmentSweepDirection.allCases.allSatisfy { abs(hypot($0.travel.dx, $0.travel.dy) - 1) < 1e-9 },
                     "sweep directions travel at unit length")
    }

    private static func faceSelection(_ suite: TestSuite) {
        let big = face(width: 0.4, centerX: 0.3)
        let medium = face(width: 0.35, centerX: 0.75)
        let bystander = face(width: 0.1, centerX: 0.5)
        suite.expect(FaceSelection.selectDominantFace(in: [bystander], minimumWidth: 0.21) == nil,
                     "a face smaller than the minimum width is a bystander")
        suite.expect(FaceSelection.selectDominantFace(in: [medium, bystander, big], minimumWidth: 0.21)?.normalizedBoundingBox == big.normalizedBoundingBox,
                     "without history the largest candidate wins")
        suite.expect(FaceSelection.selectDominantFace(in: [medium, big], preferNear: medium.normalizedBoundingBox, minimumWidth: 0.21)?
                        .normalizedBoundingBox == medium.normalizedBoundingBox,
                     "the person selected last frame stays selected")
        let far = CGRect(x: 0.0, y: 0.9, width: 0.05, height: 0.05)
        suite.expect(FaceSelection.selectDominantFace(in: [medium, big], preferNear: far, minimumWidth: 0.21)?
                        .normalizedBoundingBox == big.normalizedBoundingBox,
                     "a jump beyond the continuity tolerance picks afresh")
        suite.expect(FaceSelection.largestFace(in: [bystander])?.normalizedBoundingBox == bystander.normalizedBoundingBox,
                     "enrollment's largest face has no width cutoff, so it can say move closer")
        let pixels = FaceDetector.convertToImageSpace(CGRect(x: 0.25, y: 0.5, width: 0.5, height: 0.25), imageSize: CGSize(width: 100, height: 200))
        suite.expect(pixels == CGRect(x: 25, y: 50, width: 50, height: 50), "Vision's bottom-left box flips to top-left pixels")
    }

    // MARK: - Scan window

    private static func scanWindow(_ suite: TestSuite) {
        let start = ContinuousClock.now
        let me = scored("Faiz", similarity: 0.8)

        var off = FaceScanWindow(livenessEnabled: false)
        suite.expect(off.observe(match: me, liveness: nil, at: start) == .matched(name: "Faiz", similarity: 0.8, livenessNote: "liveness off"),
                     "with liveness off, a match unlocks on the first frame")

        var pending = FaceScanWindow(livenessEnabled: true)
        suite.expect(pending.observe(match: me, liveness: .pending, at: start) == nil,
                     "a match waits while liveness is undecided")
        suite.expect(pending.observe(match: me, liveness: .confirmed(by: .blink), at: start + .milliseconds(100))
                        == .matched(name: "Faiz", similarity: 0.8, livenessNote: "live via Blink"),
                     "the match lands once liveness confirms")

        var latched = FaceScanWindow(livenessEnabled: true)
        _ = latched.observe(match: nil, liveness: .confirmed(by: nil), at: start)
        suite.expect(latched.livenessConfirmed
                        && latched.observe(match: me, liveness: .pending, at: start + .milliseconds(200))
                        == .matched(name: "Faiz", similarity: 0.8, livenessNote: "liveness clear"),
                     "liveness latches: a confirmation before the match still counts")

        var spoof = FaceScanWindow(livenessEnabled: true)
        _ = spoof.observe(match: me, liveness: .confirmed(by: nil), at: start)
        suite.expect(spoof.observe(match: me, liveness: .denied(by: .deviceDetected), at: start) == .spoofSuspected(reason: LivenessDecision.denied(by: .deviceDetected).denialReason),
                     "a denial overrides a match")

        var ignored = FaceScanWindow(livenessEnabled: false)
        suite.expect(ignored.observe(match: me, liveness: .denied(by: .glossGlare), at: start)
                        == .matched(name: "Faiz", similarity: 0.8, livenessNote: "liveness off"),
                     "with liveness off, the cues are not consulted")

        var wrong = FaceScanWindow(livenessEnabled: true)
        suite.expect(wrong.observe(match: nil, liveness: .confirmed(by: nil), at: start) == nil
                        && wrong.observe(match: nil, liveness: .confirmed(by: nil), at: start + .milliseconds(1900)) == nil,
                     "a wrong face gets a two-second grace")
        suite.expect(wrong.observe(match: nil, liveness: .confirmed(by: nil), at: start + .seconds(2)) == .consistentlyWrongFace,
                     "a wrong face for two seconds fails the scan")

        var lookingAway = FaceScanWindow(livenessEnabled: true)
        _ = lookingAway.observe(match: nil, liveness: .pending, at: start)
        lookingAway.observeNoFace()
        suite.expect(lookingAway.observe(match: nil, liveness: .pending, at: start + .milliseconds(2500)) == nil,
                     "a frame without a face restarts the wrong-face clock")
        _ = lookingAway.observe(match: me, liveness: .pending, at: start + .milliseconds(2600))
        suite.expect(lookingAway.wrongFaceStartedAt == nil, "a match clears the wrong-face clock")

        var handover = FaceScanWindow(livenessEnabled: true)
        _ = handover.observe(match: me, liveness: .pending, at: start)
        suite.expect(handover.readyMatch != nil, "a match is kept while liveness catches up")
        _ = handover.observe(match: nil, liveness: .pending, at: start + .milliseconds(50))
        suite.expect(handover.readyMatch == nil
                        && handover.observe(match: nil, liveness: .confirmed(by: nil), at: start + .milliseconds(100)) == nil,
                     "a latched match is dropped when someone else steps in, so it can't unlock for them")

        suite.expect(FaceScanWindow.Outcome.matched(name: "Faiz", similarity: 0.8, livenessNote: "x").scanOutcome == .matched(name: "Faiz")
                        && FaceScanWindow.Outcome.consistentlyWrongFace.scanOutcome == .failed(.wrongFace)
                        && FaceScanWindow.Outcome.spoofSuspected(reason: nil).scanOutcome == .failed(.spoofSuspected),
                     "scan outcomes map onto the unlock flow's")
        suite.expect(FaceScanWindow.Outcome.matched(name: "Faiz", similarity: 0.81234, livenessNote: "liveness off").summary
                        == "Matched Faiz at 0.812, liveness off.",
                     "a match reads as Glance's outcome line")
    }

    private static func calibration(_ suite: TestSuite) {
        let samples = [0.7, 0.8].map { FaceLabCalibrationSample(centroidSimilarity: $0, isGenuine: true) }
            + [0.2, 0.4].map { FaceLabCalibrationSample(centroidSimilarity: $0, isGenuine: false) }
        suite.expect(FaceLabCalibration.suggestedThreshold(samples).map { abs($0 - 0.55) < 1e-6 } == true
                        && !FaceLabCalibration.distributionsOverlap(samples),
                     "the suggested threshold sits between the lowest genuine and highest impostor score")
        let overlapping = samples + [FaceLabCalibrationSample(centroidSimilarity: 0.75, isGenuine: false)]
        suite.expect(FaceLabCalibration.distributionsOverlap(overlapping), "an impostor above a genuine score is an overlap")
        suite.expect(FaceLabCalibration.suggestedThreshold(Array(samples.prefix(2))) == nil,
                     "no suggestion without both kinds of sample")
    }

    // MARK: - Model cache

    private static func modelCache(_ suite: TestSuite) {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent("vorss-face-model-\(UUID().uuidString)", isDirectory: true)
        defer { try? manager.removeItem(at: root) }
        let package = root.appendingPathComponent("ArcFace.mlpackage", isDirectory: true)
        let weights = package.appendingPathComponent("Data/com.apple.CoreML/weights", isDirectory: true)
        try? manager.createDirectory(at: weights, withIntermediateDirectories: true)
        try? Data("{}".utf8).write(to: package.appendingPathComponent("Manifest.json"))
        try? Data([1, 2, 3]).write(to: weights.appendingPathComponent("weight.bin"))

        let first = try? FaceModelCache.contentHash(ofPackageAt: package)
        let again = try? FaceModelCache.contentHash(ofPackageAt: package)
        suite.expect(first != nil && first == again && first?.count == 64, "a package hashes the same every time")
        try? Data([1, 2, 4]).write(to: weights.appendingPathComponent("weight.bin"))
        let changed = try? FaceModelCache.contentHash(ofPackageAt: package)
        suite.expect(changed != nil && changed != first, "changed weights give a new hash")
        try? manager.moveItem(at: weights.appendingPathComponent("weight.bin"), to: weights.appendingPathComponent("weight2.bin"))
        suite.expect((try? FaceModelCache.contentHash(ofPackageAt: package)) != changed, "a renamed file gives a new hash")
        suite.expect((try? FaceModelCache.contentHash(ofPackageAt: root.appendingPathComponent("Missing.mlpackage"))) == nil,
                     "a missing package cannot be hashed")

        let cache = root.appendingPathComponent("Models", isDirectory: true)
        let current = FaceModelCache.compiledModelURL(in: cache, hash: changed ?? "")
        suite.expect(current.lastPathComponent == "ArcFace-\((changed ?? "").prefix(16)).mlmodelc",
                     "the compiled model is named after its package's hash")
        try? manager.createDirectory(at: current, withIntermediateDirectories: true)
        let old = FaceModelCache.compiledModelURL(in: cache, hash: "0123456789abcdef0000")
        try? manager.createDirectory(at: old, withIntermediateDirectories: true)
        let unrelated = cache.appendingPathComponent("Other.mlmodelc", isDirectory: true)
        try? manager.createDirectory(at: unrelated, withIntermediateDirectories: true)
        suite.expect(FaceModelCache.staleModels(in: cache, keeping: current).map(\.lastPathComponent) == [old.lastPathComponent],
                     "only older compiled ArcFace copies are stale")
    }
}
