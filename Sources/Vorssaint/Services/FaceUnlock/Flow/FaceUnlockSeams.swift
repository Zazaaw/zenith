// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Face unlock is adapted from Glance by Jonathan Zhou (MIT),
// https://github.com/jonnyoo/glance — see the notice in About.

import Foundation
import SwiftUI

// Zenith fork: what onboarding and Settings need from recognition beyond the
// contract's `FaceUnlockRecognizer`: guided enrollment and the enrolled faces.
// Recognition's own API (`FaceEnrollmentSession`, `FaceEnrollmentStore`) is
// adapted to these two protocols in FaceUnlockRecognitionAdapters; the tests
// drive them with fakes. Modelled on Glance's `OnboardingController`
// (the nine-pose sweep) and `FaceEnrollmentStore`.

/// Where recognition plugs in at launch, beside `FaceUnlock.recognizer`.
enum FaceUnlockSetup {
    nonisolated(unsafe) static var faces: FaceUnlockFaceLibrary?
    /// A fresh guided enrollment for onboarding (camera off until `start()`),
    /// for a new face or replacing the one the id names.
    nonisolated(unsafe) static var makeEnrollment: ((UUID?) -> FaceUnlockEnrollmentDriver)?

    /// Recognition is there to enroll with and to unlock with.
    static var isRecognitionAvailable: Bool { faces != nil && makeEnrollment != nil && FaceUnlock.recognizer != nil }
}

/// One guided head pose, centre then the eight compass directions, in the
/// order they are asked for (Glance's `EnrollmentPose`).
enum FaceUnlockEnrollmentPose: Int, CaseIterable, Hashable {
    case center, left, topLeft, top, topRight, right, bottomRight, bottom, bottomLeft

    /// The ring sector it lights, 0 = up, clockwise; none for centre, which
    /// pulses the whole ring.
    var compassAngle: Double? {
        switch self {
        case .center: return nil
        case .top: return 0
        case .topRight: return 45
        case .right: return 90
        case .bottomRight: return 135
        case .bottom: return 180
        case .bottomLeft: return 225
        case .left: return 270
        case .topLeft: return 315
        }
    }
}

/// What the enroll step shows while recognition guides the sweep.
struct FaceUnlockEnrollmentProgress: Equatable {
    enum Hint: Equatable {
        case none
        case noFace
        case tooFar
        /// Turned past where a sample is any use, toward this direction.
        case tooFarTurned(FaceUnlockEnrollmentPose)
    }

    /// Where the head points now, for the ring's live marker.
    struct HeadTurn: Equatable {
        /// 0 = up, clockwise, like `FaceUnlockEnrollmentPose.compassAngle`.
        var angle: Double
        /// 0...1 of the way to the current pose's threshold.
        var progress: Double
    }

    /// The pose being asked for; nil once every pose is captured.
    var pose: FaceUnlockEnrollmentPose? = .center
    var captured: Set<FaceUnlockEnrollmentPose> = []
    /// 0...1 over all samples.
    var fraction: Double = 0
    var hint: Hint = .none
    var headTurn: HeadTurn?
    var isComplete = false
    /// The camera could not start (permission, device gone): shown in place of guidance.
    var cameraError: String?
}

protocol FaceUnlockEnrollmentDriver: AnyObject {
    var progress: FaceUnlockEnrollmentProgress { get }
    /// Called on the main thread whenever `progress` changes.
    var onProgress: ((FaceUnlockEnrollmentProgress) -> Void)? { get set }
    /// Camera on (the camera `faceUnlockCameraID` names) and the sweep begins.
    func start()
    /// Camera off. Captured samples stay in memory until `commit` or `reset`.
    func stop()
    /// Discards the captured samples, back to the first pose.
    func reset()
    /// The live, mirrored preview of the running camera.
    func cameraPreview() -> AnyView
    /// Seals the captured samples as a face named `name` (replacing the face
    /// the driver was made for, if any). The session must be open (the key seals it).
    func commit(name: String) throws
}

/// An enrolled face, as Settings lists it.
struct FaceUnlockFace: Identifiable, Equatable {
    let id: UUID
    var name: String
    var isEnabled: Bool
    var createdAt: Date
    /// Captured with another recognition model: kept, but cannot unlock.
    var needsRecapture: Bool
}

protocol FaceUnlockFaceLibrary: AnyObject {
    /// Nil while the session is locked: the faces are sealed under its key.
    var faces: [FaceUnlockFace]? { get }
    /// A face store exists on disk, readable or not.
    var hasSealedData: Bool { get }
    func reload()
    func nameIsTaken(_ name: String, excluding: UUID?) -> Bool
    func rename(_ id: UUID, to name: String) throws
    func setEnabled(_ id: UUID, _ isEnabled: Bool) throws
    func delete(_ id: UUID) throws
    func deleteAll()
}
