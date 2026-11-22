// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Face unlock is adapted from Glance by Jonathan Zhou (MIT),
// https://github.com/jonnyoo/glance — see the notice in About.

import Combine
import Foundation
import SwiftUI

// Zenith fork: recognition's enrollment and face store, behind the seams the
// setup window and Settings use (FaceUnlockSeams). Recognition's types are
// main-actor; the seams are called on the main thread only, so each call
// asserts that rather than hopping.

/// `FaceEnrollmentSession` as the setup window's guided sweep.
final class FaceUnlockEnrollmentAdapter: FaceUnlockEnrollmentDriver {
    private let session: FaceEnrollmentSession
    private var watch: AnyCancellable?
    var onProgress: ((FaceUnlockEnrollmentProgress) -> Void)?

    init(replacing: UUID?) {
        session = MainActor.assumeIsolated {
            FaceEnrollmentSession(target: replacing.map { .replacing($0) } ?? .newIdentity)
        }
        // objectWillChange fires before the change lands: read it on the next turn.
        watch = MainActor.assumeIsolated { session.objectWillChange }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.emit() }
    }

    var progress: FaceUnlockEnrollmentProgress {
        MainActor.assumeIsolated { Self.progress(of: session) }
    }

    func start() {
        let session = session
        Task { @MainActor [weak self] in
            await session.start()
            self?.emit()
        }
    }

    func stop() { MainActor.assumeIsolated { session.stop() } }

    func reset() {
        MainActor.assumeIsolated { session.reset() }
        emit()
    }

    func cameraPreview() -> AnyView {
        // Built inside, rather than returned out of, the main-actor closure: a view is not Sendable.
        var preview = AnyView(EmptyView())
        MainActor.assumeIsolated { preview = AnyView(FaceCameraPreviewView(session: session.camera.session)) }
        return preview
    }

    func commit(name: String) throws {
        try MainActor.assumeIsolated { _ = try session.commit(name: name) }
    }

    private func emit() {
        onProgress?(progress)
    }

    @MainActor
    private static func progress(of session: FaceEnrollmentSession) -> FaceUnlockEnrollmentProgress {
        let hint: FaceUnlockEnrollmentProgress.Hint
        if let turn = session.excessiveTurn {
            hint = .tooFarTurned(pose(for: turn))
        } else if session.isTooFar {
            hint = .tooFar
        } else if !session.faceDetected, session.camera.currentFrame != nil {
            hint = .noFace
        } else {
            hint = .none
        }
        return FaceUnlockEnrollmentProgress(
            pose: session.enrollmentComplete ? nil : session.currentPose.flatMap { FaceUnlockEnrollmentPose(rawValue: $0.rawValue) },
            captured: Set(session.capturedPoses.compactMap { FaceUnlockEnrollmentPose(rawValue: $0.rawValue) }),
            fraction: session.overallEnrollmentProgress,
            hint: hint,
            headTurn: session.headTurn.map { .init(angle: $0.angle, progress: $0.progress) },
            isComplete: session.enrollmentComplete,
            cameraError: session.errorMessage)
    }

    private static func pose(for turn: EnrollmentExcessiveTurn) -> FaceUnlockEnrollmentPose {
        switch turn {
        case .left: return .left
        case .topLeft: return .topLeft
        case .up: return .top
        case .topRight: return .topRight
        case .right: return .right
        case .bottomRight: return .bottomRight
        case .down: return .bottom
        case .bottomLeft: return .bottomLeft
        }
    }
}

/// `FaceEnrollmentStore` as Settings' list of faces.
final class FaceUnlockFaceStoreAdapter: FaceUnlockFaceLibrary {
    var faces: [FaceUnlockFace]? {
        MainActor.assumeIsolated {
            let store = FaceEnrollmentStore.shared
            guard !store.isLocked, store.loadFailure == nil else { return nil }
            let embedder = FaceRecognitionPipeline.loaded?.embedder
            return store.identities.map {
                FaceUnlockFace(id: $0.id, name: $0.name, isEnabled: $0.isEnabled, createdAt: $0.createdAt,
                               needsRecapture: embedder.map($0.isStale(comparedTo:)) ?? false)
            }
        }
    }

    var hasSealedData: Bool { SecureFaceStore.exists }

    func reload() { MainActor.assumeIsolated { FaceEnrollmentStore.shared.reloadIfUnlocked() } }

    func nameIsTaken(_ name: String, excluding: UUID?) -> Bool {
        MainActor.assumeIsolated { FaceEnrollmentStore.shared.nameIsTaken(name, excluding: excluding) }
    }

    func rename(_ id: UUID, to name: String) throws {
        try MainActor.assumeIsolated { _ = try FaceEnrollmentStore.shared.rename(id, to: name) }
    }

    func setEnabled(_ id: UUID, _ isEnabled: Bool) throws {
        try MainActor.assumeIsolated { try FaceEnrollmentStore.shared.setEnabled(isEnabled, for: id) }
    }

    func delete(_ id: UUID) throws {
        try MainActor.assumeIsolated {
            let store = FaceEnrollmentStore.shared
            guard let identity = store.identities.first(where: { $0.id == id }) else { return }
            try store.delete(identity)
        }
    }

    func deleteAll() { MainActor.assumeIsolated { FaceEnrollmentStore.shared.deleteAll() } }
}
