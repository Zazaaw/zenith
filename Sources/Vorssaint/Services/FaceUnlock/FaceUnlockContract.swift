// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Face unlock is adapted from Glance by Jonathan Zhou (MIT),
// https://github.com/jonnyoo/glance — see the notice in About.

import Combine
import CoreGraphics
import Foundation

/// Zenith fork: the shared contract between the three parts of face unlock,
/// built in parallel:
/// - recognition (camera, detection, ArcFace, liveness, enrollment store, Face Lab),
/// - security and the unlock flow (credentials, Touch ID session, typing the
///   password, triggers, settings),
/// - the lock screen island that shows it (scan, success, failure).
/// Each side depends only on what is declared here; the coordinator that joins
/// them is written once all three exist.

/// What the lock screen island shows for face unlock.
enum FaceUnlockIslandState: Equatable {
    /// Face unlock is off, or nothing to show.
    case hidden
    /// Armed on the lock screen and waiting for a trigger (hover / space / wake).
    case armed
    /// Looking for a face: Glance's idle animation.
    case scanning
    /// Matched: Glance's success animation, then the island becomes the welcome.
    case success
    /// Not matched (wrong face, spoof suspected, timed out): Glance's failure animation.
    case failure(FaceUnlockFailure)
    /// The Touch ID session is locked, so face unlock cannot type the password yet.
    case needsTouchID
}

enum FaceUnlockFailure: String, Equatable {
    case wrongFace, spoofSuspected, timedOut, cameraUnavailable, noPassword
}

/// The island's state, published by the coordinator and read by the lock
/// screen island on the main thread.
final class FaceUnlockPresence: ObservableObject {
    static let shared = FaceUnlockPresence()
    @Published var state: FaceUnlockIslandState = .hidden
    /// Set by the island while it is shown on the lock screen: hovering it
    /// (or clicking it) asks the coordinator to start or retry a scan.
    var onActivate: (() -> Void)?
}

/// What can start a scan (Glance's triggers).
enum FaceUnlockTrigger: String, CaseIterable, Identifiable {
    case onLock, onWake, onHover, onSpace
    var id: String { rawValue }
}

/// How long the Touch-ID-unlocked session may sit idle before it locks again.
enum FaceUnlockAutoLock: Int, CaseIterable, Identifiable {
    case sevenDays = 7, fourteenDays = 14, thirtyDays = 30, never = 0
    var id: Int { rawValue }
    var duration: TimeInterval? { self == .never ? nil : TimeInterval(rawValue) * 86_400 }
}

/// Which unlock animation plays (Glance's styles).
enum FaceUnlockAnimationStyle: String, CaseIterable, Identifiable {
    case original, minimal, none
    var id: String { rawValue }
}

/// Recognition side: what the coordinator and onboarding need from it.
/// Implemented by the recognition part (camera, pipeline, liveness, store).
protocol FaceUnlockRecognizer: AnyObject {
    /// Whether at least one enabled face is enrolled (needs the session open).
    var hasEnrolledFace: Bool { get }
    /// Runs one scan window: camera on, recognise and check liveness until a
    /// decision or `timeout`, camera off. Calls back on the main thread.
    func scan(timeout: TimeInterval, completion: @escaping (FaceUnlockScanOutcome) -> Void)
    /// Stops a running scan early; its completion still fires once.
    func cancelScan()
}

enum FaceUnlockScanOutcome: Equatable {
    case matched(name: String)
    case failed(FaceUnlockFailure)
}

/// Security side: the Touch ID session, the stored password and typing it.
/// Implemented by the security part.
protocol FaceUnlockCredentials: AnyObject {
    var isSessionUnlocked: Bool { get }
    var hasStoredPassword: Bool { get }
    /// Asks for Touch ID (LocalAuthentication) and opens the session.
    func unlockSession(reason: String, completion: @escaping (Bool) -> Void)
    func lockSession()
    /// Types the stored password into the lock screen and presses Return.
    /// Only while the screen is actually locked (CGSession), never otherwise.
    func typeStoredPassword(completion: @escaping (Bool) -> Void)
}

/// Where the parts are plugged in at launch; the coordinator reads these.
enum FaceUnlock {
    nonisolated(unsafe) static var recognizer: FaceUnlockRecognizer?
    nonisolated(unsafe) static var credentials: FaceUnlockCredentials?
}
