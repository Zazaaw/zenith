// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Adapted from Glance by Jonathan Zhou (MIT), https://github.com/jonnyoo/glance (glance/Onboarding/OnboardingController.swift).
//
// The guided nine-pose face enrollment, without its UI: camera, pose matching,
// sample capture and the final commit. Glance keeps this inside its onboarding
// controller; here the onboarding views drive it and show its published state.

@preconcurrency import AVFoundation
import Combine
import CoreGraphics
import Foundation

enum FaceEnrollmentSessionError: LocalizedError, Equatable {
    case unsupported
    case emptyName
    case nameTaken(String)
    case nothingCaptured
    case sessionLocked

    var errorDescription: String? {
        switch self {
        case .unsupported: return "Face unlock needs macOS 15 or later."
        case .emptyName: return "Enter a name."
        case .nameTaken(let name): return "A face named \"\(name)\" is already enrolled."
        case .nothingCaptured: return "No face samples were captured."
        case .sessionLocked: return SecureFaceStoreError.sessionLocked.errorDescription
        }
    }
}

/// Zenith fork: the UI-free half of Glance's `OnboardingController` enrollment.
///
/// Typical use from the onboarding:
/// 1. `let session = FaceEnrollmentSession(target: .newIdentity)` and show
///    `FaceCameraPreviewView(session: session.camera.session)`;
/// 2. `await session.start()`; observe `currentPose`, `enrollmentInstruction`,
///    `headTurn`, `capturedPoses`, `centerPulseTick`, `overallEnrollmentProgress`;
/// 3. `onComplete` fires once all nine poses are captured; call `stop()` when the
///    completion animation is done (Glance stops the camera before naming);
/// 4. once the session key exists (Touch ID), `try session.commit(name:)`.
///
/// Samples stay in memory until `commit`, so first-run setup can capture the
/// face before the password step unlocks the session. Frames are never stored.
@MainActor
final class FaceEnrollmentSession: ObservableObject {
    /// Who this run is enrolling. Recapture is keyed by `id` rather than name so the
    /// naming step can rename an identity without orphaning it under its old name.
    enum Target: Equatable {
        case newIdentity
        case replacing(UUID)

        var identityID: UUID? {
            if case .replacing(let id) = self { return id }
            return nil
        }
    }

    let target: Target
    let camera = FaceCameraManager()
    private let store = FaceEnrollmentStore.shared
    private(set) var pipeline: FaceRecognitionPipeline?

    /// Fired once, when the last pose is captured.
    var onComplete: (() -> Void)?

    // MARK: - Tuning (Glance's values)

    /// 9 poses x 2 samples = 18 total, enough for a stable template without overlong holds.
    static let samplesPerPose = 2
    /// Consecutive matching frames required before a capture fires — debounces a lucky
    /// frame near a pose boundary.
    private let requiredMatchStreak = 3
    /// Wait this long after yaw/pitch matches before samples count, so the user has
    /// settled into the turn rather than being captured mid-motion.
    private let poseHoldDuration: Duration = .milliseconds(500)
    /// Permissive floor for Vision's capture-quality score (no fixed universal cutoff) —
    /// better to accept a mediocre sample than stall the whole flow.
    private let qualityFloor: Float = 0.2
    /// Hold off accepting captures this long once the camera comes up, so the first
    /// samples aren't taken mid-blink. Detection still runs during this window.
    private let initialCaptureDelay: Duration = .seconds(1.5)
    /// If a pose takes longer than this, matching bands widen so an unusual camera
    /// angle can't permanently strand the user.
    private let stallTimeout: Duration = .seconds(12)
    /// Enrollment wants a closer face than unlock's bystander cutoff.
    private var enrollmentMinimumFaceWidth: Float {
        max(FaceUnlockRecognitionSettings.minimumFaceWidth(), 0.2)
    }

    // MARK: - Published state

    @Published private(set) var currentPoseIndex = 0
    @Published private(set) var capturedForCurrentPose = 0
    @Published private(set) var faceDetected = false
    @Published private(set) var currentYaw: Float?
    @Published private(set) var currentPitch: Float?
    /// Whether the last-seen face read as too small to enroll reliably — swaps the pose
    /// instruction for a "move closer" prompt while true.
    @Published private(set) var isTooFar = false
    @Published private(set) var excessiveTurn: EnrollmentExcessiveTurn?
    @Published private(set) var enrollmentComplete = false
    /// Vision's capture quality of the last face seen, 0...1.
    @Published private(set) var lastQuality: Float?
    /// Camera or model trouble worth showing; nil while all is well.
    @Published private(set) var errorMessage: String?
    /// Sectors already captured — which ring ticks are lit.
    @Published private(set) var capturedPoses: Set<EnrollmentPose> = []
    /// Bumped every time `.center` is captured, to pulse the whole ring (center has no
    /// sector of its own to light).
    @Published private(set) var centerPulseTick = 0

    private struct CollectedSample {
        let embedding: [Float]
        let pose: EnrollmentPose
        /// Carried through so an enrolled identity can report how good its samples were.
        let quality: Float?
        /// Stamped at capture, not at save — samples sit in memory across the naming
        /// (and, on first run, password) step, so a save-time stamp would be wrong.
        let capturedAt: Date
    }
    /// Held in memory (not persisted) until the identity has a name and the session is unlocked.
    private var collectedSamples: [CollectedSample] = []
    private var matchStreak = 0
    private var isProcessingFrame = false
    private var isActive = false
    private var poseStartedAt: ContinuousClock.Instant = .now
    /// Set once in `start()` — not per-pose — so it only holds back the first
    /// pose rather than pausing again after every later pose change.
    private var captureReadyAt: ContinuousClock.Instant = .now
    /// When the current pose first started matching continuously; `nil` while out of band.
    /// Capture waits `poseHoldDuration` past this instant.
    private var poseHoldStartedAt: ContinuousClock.Instant?
    private var frameSubscription: AnyCancellable?

    init(target: Target = .newIdentity) {
        self.target = target
        frameSubscription = camera.$currentFrame
            .compactMap { $0 }
            .sink { [weak self] frame in
                Task { @MainActor [weak self] in
                    await self?.processEnrollFrame(frame)
                }
            }
    }

    // MARK: - Derived state

    var currentPose: EnrollmentPose? {
        EnrollmentPose(rawValue: currentPoseIndex)
    }

    /// Copy shown under the camera: pose guidance, a closer-up prompt, or the
    /// completion line.
    var enrollmentInstruction: String {
        if enrollmentComplete { return "Face captured" }
        if let excessiveTurn { return excessiveTurn.instruction }
        if isTooFar { return "Bring your face closer" }
        return currentPose?.instruction ?? ""
    }

    /// Live head direction for the ring, or `nil` when there's nothing to point at.
    var headTurn: EnrollmentHeadTurn? {
        guard isActive, !enrollmentComplete, faceDetected, !isTooFar, excessiveTurn == nil,
              let pose = currentPose, let yaw = currentYaw, let pitch = currentPitch else { return nil }
        return EnrollmentPoseRules.headTurn(yaw: yaw, pitch: pitch, toward: pose)
    }

    var overallEnrollmentProgress: Double {
        let total = Double(EnrollmentPose.allCases.count * Self.samplesPerPose)
        let done = Double(currentPoseIndex * Self.samplesPerPose + capturedForCurrentPose)
        return min(done / total, 1.0)
    }

    var collectedSampleCount: Int { collectedSamples.count }

    /// The newest camera frame, for a custom preview. Kept in memory only.
    var currentFrameImage: CGImage? { camera.currentFrame?.image }

    // MARK: - Camera

    static var cameraPermission: FaceCameraPermission {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .granted
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }

    /// Asks for camera access when macOS has not asked yet; true when granted.
    static func requestCameraAccess() async -> Bool {
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            return await AVCaptureDevice.requestAccess(for: .video)
        }
        return cameraPermission == .granted
    }

    /// Devices for a picker — refresh when the picker appears, since a camera can be
    /// plugged in after launch.
    static func availableCameras() -> [FaceCameraDevice] {
        FaceCameraCatalog.availableDevices()
    }

    /// The chosen camera (`faceUnlockCameraID`); nil is the system default.
    static var selectedCameraID: String? {
        get { FaceUnlockRecognitionSettings.cameraID() }
        set { FaceUnlockRecognitionSettings.setCameraID(newValue) }
    }

    static func cameraSelectionLabel(devices: [FaceCameraDevice]) -> String {
        FaceCameraCatalog.selectionLabel(devices: devices)
    }

    // MARK: - Lifecycle

    /// Loads the model (compiling it on first use), opens the camera and starts
    /// the guided capture from the first pose.
    func start() async {
        guard FaceUnlockRecognition.isSupported else {
            errorMessage = FaceEnrollmentSessionError.unsupported.errorDescription
            return
        }
        errorMessage = nil
        if pipeline == nil {
            pipeline = await FaceRecognitionPipeline.shared()
        }
        resetEnrollmentState()
        isActive = true
        poseStartedAt = .now
        captureReadyAt = .now + initialCaptureDelay
        poseHoldStartedAt = nil
        await camera.start()
        if let error = camera.errorMessage {
            errorMessage = error
            isActive = false
            camera.stop()
        }
    }

    /// Stops the camera. Captured samples stay until `reset()` or `commit`.
    func stop() {
        isActive = false
        camera.stop()
    }

    /// Discards every captured sample and starts over from the first pose.
    func reset() {
        resetEnrollmentState()
        poseStartedAt = .now
        poseHoldStartedAt = nil
    }

    private func resetEnrollmentState() {
        collectedSamples = []
        currentPoseIndex = 0
        capturedForCurrentPose = 0
        capturedPoses = []
        matchStreak = 0
        poseHoldStartedAt = nil
        faceDetected = false
        currentYaw = nil
        currentPitch = nil
        isTooFar = false
        excessiveTurn = nil
        enrollmentComplete = false
        lastQuality = nil
    }

    // MARK: - Guided enrollment

    private enum EnrollFrameOutcome {
        case noFace
        case tooFar
        case ready(FaceRecognitionResult)
    }

    private func processEnrollFrame(_ cameraFrame: FaceCameraFrame) async {
        guard isActive, !enrollmentComplete, !isProcessingFrame,
              let pipeline, let pose = currentPose else { return }
        isProcessingFrame = true
        defer { isProcessingFrame = false }

        let minimumWidth = enrollmentMinimumFaceWidth
        let image = cameraFrame.image
        let outcome = await Task.detached(priority: .userInitiated) { () -> EnrollFrameOutcome in
            do {
                let faces = try FaceDetector.detectFaces(in: image)
                guard let face = FaceSelection.largestFace(in: faces) else {
                    return .noFace
                }
                if Float(face.normalizedBoundingBox.width) < minimumWidth {
                    return .tooFar
                }
                return .ready(try pipeline.recognize(face, in: image))
            } catch {
                return .noFace
            }
        }.value
        guard isActive, !enrollmentComplete else { return }

        switch outcome {
        case .noFace:
            faceDetected = false
            currentYaw = nil
            currentPitch = nil
            matchStreak = 0
            poseHoldStartedAt = nil
            isTooFar = false
            excessiveTurn = nil
            lastQuality = nil
        case .tooFar:
            faceDetected = true
            currentYaw = nil
            currentPitch = nil
            matchStreak = 0
            poseHoldStartedAt = nil
            isTooFar = true
            excessiveTurn = nil
        case .ready(let result):
            lastQuality = result.quality
            guard let yaw = result.face.yaw, let pitch = result.face.pitch else {
                faceDetected = true
                currentYaw = nil
                currentPitch = nil
                matchStreak = 0
                poseHoldStartedAt = nil
                isTooFar = false
                excessiveTurn = nil
                return
            }
            faceDetected = true
            currentYaw = yaw
            currentPitch = pitch
            isTooFar = false
            excessiveTurn = EnrollmentPoseRules.excessiveTurn(yaw: yaw, pitch: pitch)
            guard excessiveTurn == nil else {
                matchStreak = 0
                poseHoldStartedAt = nil
                return
            }
            processMatchedEnrollFrame(result, yaw: yaw, pitch: pitch, pose: pose)
        }
    }

    private func processMatchedEnrollFrame(
        _ result: FaceRecognitionResult,
        yaw: Float,
        pitch: Float,
        pose: EnrollmentPose
    ) {
        // Detection above still ran; only capture is held back until settled.
        guard ContinuousClock.now >= captureReadyAt else {
            matchStreak = 0
            poseHoldStartedAt = nil
            return
        }

        let qualityOK = result.quality.map { $0 >= qualityFloor } ?? true
        // Only a 5-point alignment is reliably canonical; a 2-point/padded-crop fallback
        // isn't accepted toward enrollment.
        let alignmentOK = result.alignmentTier == .fivePoint
        let widened = ContinuousClock.now - poseStartedAt > stallTimeout
        let poseOK = EnrollmentPoseRules.poseMatches(yaw: yaw, pitch: pitch, pose: pose, widened: widened)

        guard qualityOK, alignmentOK, !isTooFar,
              EnrollmentPoseRules.excessiveTurn(yaw: yaw, pitch: pitch) == nil, poseOK else {
            matchStreak = 0
            poseHoldStartedAt = nil
            return
        }

        let holdStartedAt = poseHoldStartedAt ?? .now
        poseHoldStartedAt = holdStartedAt
        guard ContinuousClock.now - holdStartedAt >= poseHoldDuration else { return }

        matchStreak += 1
        guard matchStreak >= requiredMatchStreak else { return }
        matchStreak = 0

        collectedSamples.append(CollectedSample(
            embedding: result.embedding,
            pose: pose,
            quality: result.quality,
            capturedAt: Date()
        ))
        capturedForCurrentPose += 1

        if capturedForCurrentPose >= Self.samplesPerPose {
            if pose == .center {
                centerPulseTick += 1
            } else {
                capturedPoses.insert(pose)
            }
            currentPoseIndex += 1
            capturedForCurrentPose = 0
            poseStartedAt = .now
            poseHoldStartedAt = nil

            if currentPoseIndex >= EnrollmentPose.allCases.count {
                enrollmentComplete = true
                onComplete?()
            }
        }
    }

    // MARK: - Naming and commit

    /// Case- and diacritic-insensitive; a recapture may keep its own name.
    /// Only meaningful while the store is unlocked (a locked store reads as empty).
    func nameIsTaken(_ name: String) -> Bool {
        store.nameIsTaken(name, excluding: target.identityID)
    }

    /// The single place guided-enrollment samples are persisted. Requires an
    /// unlocked session (the key provider has a key).
    @discardableResult
    func commit(name: String) throws -> FaceIdentity {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw FaceEnrollmentSessionError.emptyName }
        guard !collectedSamples.isEmpty, let pipeline else { throw FaceEnrollmentSessionError.nothingCaptured }
        guard FaceUnlockKeys.isSessionUnlocked else { throw FaceEnrollmentSessionError.sessionLocked }
        store.reloadIfUnlocked()
        guard !store.nameIsTaken(trimmed, excluding: target.identityID) else {
            throw FaceEnrollmentSessionError.nameTaken(trimmed)
        }
        let samples = collectedSamples.map {
            FaceSample(embedding: $0.embedding, pose: $0.pose.name, capturedAt: $0.capturedAt, quality: $0.quality)
        }
        guard let identity = try store.commitEnrollment(
            replacing: target.identityID,
            name: trimmed,
            samples: samples,
            embedder: pipeline.embedder
        ) else {
            throw FaceEnrollmentSessionError.nothingCaptured
        }
        return identity
    }

    /// Only a pre-fill for the first-run naming step — never the stored name,
    /// which the user always chooses themselves.
    static let defaultName: String = {
        let name = NSFullUserName()
        return name.isEmpty ? "Owner" : name
    }()
}
