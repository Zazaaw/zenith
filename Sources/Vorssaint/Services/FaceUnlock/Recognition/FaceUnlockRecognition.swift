// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Adapted from Glance by Jonathan Zhou (MIT), https://github.com/jonnyoo/glance (glance/FaceUnlockCoordinator.swift).
//
// The recognition side of face unlock, plugged into `FaceUnlock.recognizer` at
// launch. One scan window is Glance's `runScanCycle` + `observeScanWindow`: camera
// on, recognise and check liveness until a decision or the deadline, camera off.
// Typing the password on a match is the unlock flow's job, not this one's.
//
// Known limitation (Glance's): LivenessAnalyzer defeats a photo but not a replayed
// video (real non-rigid motion looks live).

import CoreGraphics
import Foundation

/// Zenith fork: entry points for the rest of the app.
enum FaceUnlockRecognition {
    /// Face unlock (Glance) targets macOS 15; Zenith runs on 14 and keeps the
    /// feature off there.
    static var isSupported: Bool {
        if #available(macOS 15, *) { return true }
        return false
    }

    /// Called once at launch. Cheap: nothing opens, loads or compiles until the
    /// first scan, enrollment or Face Lab session.
    static func install() {
        guard isSupported else { return }
        FaceUnlock.recognizer = FaceUnlockRecognitionService.shared
    }

    /// The scan window the settings ask for (`faceUnlockDetectionSeconds`).
    static var scanTimeout: TimeInterval {
        TimeInterval(FaceUnlockRecognitionSettings.detectionSeconds())
    }

    /// Compiles and loads the model ahead of the first scan, e.g. when face
    /// unlock is switched on. Returns nil with ArcFace in use, otherwise why the
    /// Vision fallback is.
    @MainActor
    static func prepareModel() async -> String? {
        await FaceRecognitionPipeline.shared().fallbackReason
    }

    /// Which embedder is active, once loaded; nil before the first use.
    @MainActor
    static var modelStatus: String? {
        guard let pipeline = FaceRecognitionPipeline.loaded else { return nil }
        if let reason = pipeline.fallbackReason {
            return "\(pipeline.embedder.name) (ArcFace unavailable: \(reason))"
        }
        return pipeline.embedder.name
    }
}

/// `FaceUnlockRecognizer` for the unlock flow. Safe to call from any thread;
/// the work runs on the main actor and completions arrive on the main thread.
final class FaceUnlockRecognitionService: FaceUnlockRecognizer, @unchecked Sendable {
    static let shared = FaceUnlockRecognitionService()

    /// Optional extra stop condition checked every frame, e.g. "the screen is
    /// still locked" (Glance's `LockMonitor.isScreenActuallyLocked()` guard).
    /// Returning false ends the scan as timed out.
    @MainActor var shouldContinueScan: (() -> Bool)?

    @MainActor private lazy var scanner = FaceUnlockScanner()

    private init() {}

    var hasEnrolledFace: Bool {
        Self.onMain { !FaceEnrollmentStore.shared.activeIdentities.isEmpty }
    }

    func scan(timeout: TimeInterval, completion: @escaping (FaceUnlockScanOutcome) -> Void) {
        Task { @MainActor in
            self.scanner.shouldContinue = self.shouldContinueScan
            self.scanner.scan(timeout: timeout, completion: completion)
        }
    }

    /// Zenith fork: one scan away from the lock screen (App Lock's shield),
    /// with its own stop condition in place of `shouldContinueScan` for this
    /// scan only. The next lock screen scan puts that one back.
    @MainActor
    func scan(timeout: TimeInterval, while shouldContinue: @escaping () -> Bool,
              completion: @escaping (FaceUnlockScanOutcome) -> Void) {
        scanner.shouldContinue = shouldContinue
        scanner.scan(timeout: timeout, completion: completion)
    }

    func cancelScan() {
        Task { @MainActor in self.scanner.cancel() }
    }

    /// The last decision in words (Glance's `lastOutcome`), for diagnostics.
    @MainActor var lastOutcomeDescription: String? { scanner.lastOutcome }
    /// What the scan is doing now (Glance's `statusMessage`).
    @MainActor var statusMessage: String { scanner.statusMessage }

    private static func onMain<T>(_ body: @MainActor () -> T) -> T {
        if Thread.isMainThread {
            return MainActor.assumeIsolated { body() }
        }
        return DispatchQueue.main.sync { MainActor.assumeIsolated { body() } }
    }
}

/// One scan at a time; a new scan supersedes the running one, whose completion
/// then fires as timed out.
@MainActor
final class FaceUnlockScanner {
    let camera = FaceCameraManager()
    var shouldContinue: (() -> Bool)?
    private(set) var statusMessage = "Idle"
    private(set) var lastOutcome: String?

    private var scanTask: Task<Void, Never>?
    /// Bumped by every `scan`; a cycle bails once superseded. `Task.cancel()` is cooperative, so a superseded
    /// cycle still runs to its end, and its side effects (`camera.stop()`) must not land on the newer cycle.
    private var generation = 0
    private var pending: PendingScan?

    /// Fires its completion exactly once.
    private final class PendingScan {
        let generation: Int
        private var completion: ((FaceUnlockScanOutcome) -> Void)?
        init(generation: Int, completion: @escaping (FaceUnlockScanOutcome) -> Void) {
            self.generation = generation
            self.completion = completion
        }
        func finish(_ outcome: FaceUnlockScanOutcome) {
            let completion = self.completion
            self.completion = nil
            completion?(outcome)
        }
    }

    func scan(timeout: TimeInterval, completion: @escaping (FaceUnlockScanOutcome) -> Void) {
        let superseded = pending
        scanTask?.cancel()
        generation &+= 1
        let current = PendingScan(generation: generation, completion: completion)
        pending = current
        superseded?.finish(.failed(.timedOut))
        scanTask = Task { [weak self] in
            await self?.runScanCycle(current, timeout: timeout)
        }
    }

    func cancel() {
        scanTask?.cancel()
        guard let pending else { return }
        self.pending = nil
        generation &+= 1
        camera.stop()
        statusMessage = "Idle"
        pending.finish(.failed(.timedOut))
    }

    private func runScanCycle(_ scan: PendingScan, timeout: TimeInterval) async {
        let isCurrent = { [weak self] in self?.generation == scan.generation && !Task.isCancelled }

        guard FaceUnlockRecognition.isSupported else {
            complete(scan, .failed(.cameraUnavailable), note: "Face unlock needs macOS 15 or later.")
            return
        }
        let pipeline = await FaceRecognitionPipeline.shared()
        guard isCurrent() else { return }

        // Nobody to match (or the session is locked): Glance would scan and then
        // fail as a wrong face; this says so without turning the camera on.
        guard !FaceEnrollmentStore.shared.activeIdentities.isEmpty else {
            complete(scan, .failed(.wrongFace), note: "No enabled face is enrolled, or the session is locked.")
            return
        }

        await camera.start()
        guard isCurrent() else {
            // Cancelled while the camera was coming up: nobody else owns it, so it must not stay on.
            if pending == nil { camera.stop() }
            return
        }
        if let error = camera.errorMessage {
            camera.stop()
            complete(scan, .failed(.cameraUnavailable), note: error)
            return
        }

        statusMessage = "Looking for your face…"
        let decided = await observeScanWindow(
            pipeline: pipeline,
            deadline: Date().addingTimeInterval(max(timeout, 0.5)),
            isCurrent: isCurrent
        )

        // A newer cycle now owns the camera — leave it alone.
        guard generation == scan.generation else { return }
        camera.stop()

        if let decided {
            complete(scan, decided.scanOutcome, note: decided.summary)
        } else {
            complete(scan, .failed(.timedOut), note: "No face detected.")
        }
    }

    private func complete(_ scan: PendingScan, _ outcome: FaceUnlockScanOutcome, note: String) {
        lastOutcome = note
        statusMessage = "Idle"
        if pending === scan { pending = nil }
        scan.finish(outcome)
    }

    /// Glance's `observeScanWindow`: nil when the deadline passed without a decision.
    private func observeScanWindow(
        pipeline: FaceRecognitionPipeline,
        deadline: Date,
        isCurrent: () -> Bool
    ) async -> FaceScanWindow.Outcome? {
        let livenessEnabled = FaceUnlockRecognitionSettings.livenessEnabled()
        let liveness = LivenessAnalyzer()
        liveness.modeProvider = { FaceUnlockRecognitionSettings.livenessMode() }
        let matchThreshold = FaceUnlockRecognitionSettings.matchThreshold()
        var window = FaceScanWindow(livenessEnabled: livenessEnabled)

        /// Last frame's selected face, passed back so `selectDominantFace` stays on the same person instead of flip-flopping.
        var lastFaceBoundingBox: CGRect?
        /// Cheap way to detect "no new camera frame yet" vs. "fresh frame" — without it a repeat frame would corrupt the liveness motion signal.
        var lastProcessedFrameID: UInt64?

        while Date() < deadline, isCurrent() {
            if let shouldContinue, !shouldContinue() { return nil }

            guard let frame = camera.currentFrame, frame.id != lastProcessedFrameID else {
                // 20ms keeps the liveness window's sample count high while staying close to the camera's native ~33ms cadence.
                try? await Task.sleep(nanoseconds: 20_000_000)
                continue
            }
            lastProcessedFrameID = frame.id

            let previousBoundingBox = lastFaceBoundingBox
            let outcome = await Task.detached(priority: .userInitiated) { () -> (FaceRecognitionResult, LivenessFrame)? in
                guard let result = try? pipeline.recognize(in: frame.image, preferNear: previousBoundingBox) else { return nil }
                let faceCrop = FaceCameraManager.renderCrop(from: frame, imageRect: result.face.boundingBox)
                return (result, LivenessFeatureExtractor.extract(from: result, frame: frame.image, faceCrop: faceCrop))
            }.value

            guard let (result, livenessFrame) = outcome else {
                window.observeNoFace()
                lastFaceBoundingBox = nil
                try? await Task.sleep(nanoseconds: 20_000_000)
                continue
            }
            lastFaceBoundingBox = result.face.normalizedBoundingBox

            let decision = livenessEnabled ? liveness.observe(livenessFrame).decision : nil
            // `activeIdentities`, not `identities`: someone switched off stays enrolled but must not unlock.
            let scored = pipeline.score(result.embedding, against: FaceEnrollmentStore.shared.activeIdentities)
            let matched = pipeline.bestMatch(in: scored, threshold: matchThreshold)

            if let decided = window.observe(match: matched, liveness: decision) {
                if case .matched = decided { statusMessage = "Recognized — unlocking…" }
                return decided
            }

            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return nil
    }
}
