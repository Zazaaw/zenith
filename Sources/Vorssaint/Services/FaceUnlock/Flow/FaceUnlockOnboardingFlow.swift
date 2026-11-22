// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Face unlock is adapted from Glance by Jonathan Zhou (MIT),
// https://github.com/jonnyoo/glance — see the notice in About.

import Combine
import Foundation

/// Zenith fork: the steps of setting up face unlock (Glance's
/// `OnboardingController`), shown in a window rather than the notch:
/// intro, permissions, the security notice, pre-setup, camera, the guided
/// enrollment sweep, naming the face, the login password, done.
///
/// First run takes every step and turns face unlock on at the end. "Add a
/// face" starts at the sweep (the session is already open) and saves at the
/// name. "Change password" is the password step alone.
///
/// Captured samples stay in memory until a name is confirmed and the session
/// is open: in first run that is the password step, where Touch ID opens the
/// session (creating the key the first time) before the face and then the
/// password are sealed.
final class FaceUnlockOnboardingFlow: ObservableObject {
    enum Step: String, CaseIterable {
        case intro, permissions, securityNotice, preSetup, selectCamera, enroll, name, password, complete
    }

    enum Mode: Equatable {
        case firstRun
        /// Enroll another face, or replace the one `replacing` names.
        case addFace(replacing: UUID?)
        case password
    }

    enum Problem: Equatable {
        case nameEmpty
        case nameTaken(String)
        case recognitionUnavailable
        case saveFailed(String)
        case security(FaceUnlockSecurityError)
    }

    enum CameraAccess: Equatable { case granted, denied, notDetermined }

    struct Camera: Identifiable, Equatable {
        let id: String
        let name: String
    }

    struct Dependencies {
        var session: FaceUnlockSession
        var faces: () -> FaceUnlockFaceLibrary?
        var makeEnrollment: () -> FaceUnlockEnrollmentDriver?
        var defaults: UserDefaults
        var accessibility: () -> Bool
        var camera: () -> CameraAccess
        var requestAccessibility: () -> Void
        var requestCamera: () -> Void
        var cameras: () -> [Camera]
        var scheduler: FaceUnlockScheduling
        /// Asked for when the session has to open, shown in the Touch ID prompt.
        var touchIDReason: String
    }

    /// How long "Face captured" shows before naming, and "You're all set" before the window closes.
    enum Timing {
        static let captured: TimeInterval = 1.4
        static let complete: TimeInterval = 1.8
    }

    let mode: Mode
    @Published private(set) var step: Step
    @Published private(set) var movedForward = true
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var cameraAccess: CameraAccess = .notDetermined
    @Published private(set) var cameras: [Camera] = []
    @Published private(set) var progress = FaceUnlockEnrollmentProgress()
    /// The sweep is done and the checkmark shows, before naming.
    @Published private(set) var showsCaptured = false
    @Published var pendingName: String
    @Published private(set) var problem: Problem?
    @Published private(set) var isSaving = false
    /// Set when the flow is over (done or cancelled): the window closes.
    @Published private(set) var isFinished = false

    private let deps: Dependencies
    private var driver: FaceUnlockEnrollmentDriver?
    private var hasSamples = false
    private var capturedWork: FaceUnlockScheduled?
    private var completeWork: FaceUnlockScheduled?

    init(mode: Mode, prefillName: String, _ dependencies: Dependencies) {
        self.mode = mode
        deps = dependencies
        pendingName = prefillName
        switch mode {
        case .firstRun: step = .intro
        case .addFace: step = .enroll
        case .password: step = .password
        }
        refreshPermissions()
        if step == .enroll { beginEnrollment() }
    }

    // MARK: Navigation

    var showsBack: Bool {
        switch step {
        case .permissions, .securityNotice, .preSetup, .selectCamera, .name, .password: return true
        case .intro, .enroll, .complete: return false
        }
    }

    var canAdvance: Bool {
        switch step {
        case .permissions: return accessibilityGranted && cameraAccess == .granted
        case .name: return !trimmedName.isEmpty
        default: return true
        }
    }

    func advance() {
        guard canAdvance else { return }
        movedForward = true
        problem = nil
        switch step {
        case .intro: step = .permissions
        case .permissions: step = .securityNotice
        case .securityNotice:
            deps.defaults.set(true, forKey: DefaultsKey.faceUnlockNoticeAccepted)
            step = .preSetup
        case .preSetup:
            refreshCameras()
            step = .selectCamera
        case .selectCamera:
            step = .enroll
            beginEnrollment()
        case .enroll, .complete: break // the sweep advances itself; done closes itself
        case .name: confirmName()
        case .password: break // finish(password:)
        }
    }

    /// Back, or cancel where nothing comes before (add a face, change password).
    func back() {
        movedForward = false
        problem = nil
        switch (mode, step) {
        case (.password, _), (.addFace, .enroll), (.addFace, .name):
            cancel()
        case (_, .enroll):
            // The sweep cannot resume halfway.
            stopEnrollment(discard: true)
            step = .selectCamera
        case (_, .name):
            stopEnrollment(discard: true)
            step = .selectCamera
        case (_, .password):
            // The samples and the name survive a typo fix.
            step = .name
        case (_, .selectCamera): step = .preSetup
        case (_, .preSetup): step = .securityNotice
        case (_, .securityNotice): step = .permissions
        case (_, .permissions): step = .intro
        case (_, .intro), (_, .complete): break
        }
    }

    /// Closes the flow without saving anything not saved yet.
    func cancel() {
        teardown()
        isFinished = true
    }

    /// Camera off and timers stopped. Idempotent.
    func teardown() {
        capturedWork?.cancel()
        completeWork?.cancel()
        driver?.stop()
    }

    // MARK: Permissions

    func refreshPermissions() {
        let accessibility = deps.accessibility()
        let camera = deps.camera()
        if accessibilityGranted != accessibility { accessibilityGranted = accessibility }
        if cameraAccess != camera { cameraAccess = camera }
    }

    func grantAccessibility() {
        deps.requestAccessibility()
        refreshPermissions()
    }

    func grantCamera() {
        deps.requestCamera()
        refreshPermissions()
    }

    // MARK: Camera

    func refreshCameras() {
        cameras = deps.cameras()
    }

    var selectedCameraID: String? {
        deps.defaults.string(forKey: DefaultsKey.faceUnlockCameraID)
    }

    /// Nil is the system default (the built-in camera where there is one).
    func selectCamera(_ id: String?) {
        if let id { deps.defaults.set(id, forKey: DefaultsKey.faceUnlockCameraID) }
        else { deps.defaults.removeObject(forKey: DefaultsKey.faceUnlockCameraID) }
        objectWillChange.send()
    }

    // MARK: Enrollment

    func cameraPreview() -> FaceUnlockEnrollmentDriver? { driver }

    private func beginEnrollment() {
        guard let driver = driver ?? deps.makeEnrollment() else {
            problem = .recognitionUnavailable
            return
        }
        self.driver = driver
        showsCaptured = false
        progress = driver.progress
        driver.onProgress = { [weak self] progress in self?.enrollmentDidProgress(progress) }
        driver.start()
    }

    private func enrollmentDidProgress(_ next: FaceUnlockEnrollmentProgress) {
        guard step == .enroll else { return }
        progress = next
        guard next.isComplete, !showsCaptured else { return }
        hasSamples = true
        showsCaptured = true
        capturedWork = deps.scheduler.after(Timing.captured) { [weak self] in
            guard let self, self.step == .enroll else { return }
            self.driver?.stop()
            self.movedForward = true
            self.step = .name
        }
    }

    private func stopEnrollment(discard: Bool) {
        capturedWork?.cancel()
        driver?.stop()
        if discard {
            driver?.reset()
            hasSamples = false
            showsCaptured = false
            progress = driver?.progress ?? FaceUnlockEnrollmentProgress()
        }
    }

    // MARK: Name

    private var trimmedName: String { pendingName.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var replacing: UUID? {
        if case .addFace(let id) = mode { return id }
        return nil
    }

    func confirmName() {
        let name = trimmedName
        guard !name.isEmpty else {
            problem = .nameEmpty
            return
        }
        // In first run the faces are still sealed (no session yet); the
        // password step checks again once they can be read.
        if deps.session.isSessionUnlocked, deps.faces()?.nameIsTaken(name, excluding: replacing) == true {
            problem = .nameTaken(name)
            return
        }
        problem = nil
        movedForward = true
        guard case .addFace = mode else {
            step = .password
            return
        }
        do {
            try commitFace(name)
        } catch {
            // The session lapsed since it was opened: stay, rather than
            // saying "all set" over a save that did not happen.
            problem = .saveFailed(String(describing: error))
            return
        }
        complete()
    }

    private func commitFace(_ name: String) throws {
        guard let driver else { throw FaceUnlockSecurityError.sessionLocked }
        try driver.commit(name: name, replacing: replacing)
        hasSamples = false
        deps.faces()?.reload()
    }

    // MARK: Password

    /// Opens the session (Touch ID), seals the face captured in this run if
    /// any, then seals and stores the password. Single-flight: Return in the
    /// field and the button can land back to back.
    func finish(password: String) {
        guard !isSaving else { return }
        guard !password.isEmpty else {
            problem = .security(.emptyPassword)
            return
        }
        isSaving = true
        problem = nil
        deps.session.unlockSession(reason: deps.touchIDReason) { [weak self] opened in
            guard let self else { return }
            guard opened else {
                self.isSaving = false
                self.problem = .security(self.deps.session.lastError ?? .authenticationFailed)
                return
            }
            if self.hasSamples {
                let name = self.trimmedName
                self.deps.faces()?.reload()
                if self.deps.faces()?.nameIsTaken(name, excluding: self.replacing) == true {
                    self.isSaving = false
                    self.problem = .nameTaken(name)
                    self.movedForward = false
                    self.step = .name
                    return
                }
                do {
                    try self.commitFace(name)
                } catch {
                    self.isSaving = false
                    self.problem = .saveFailed(String(describing: error))
                    return
                }
            }
            self.deps.session.savePassword(password) { [weak self] result in
                guard let self else { return }
                self.isSaving = false
                switch result {
                case .success: self.complete()
                case .failure(let error): self.problem = .security(error)
                }
            }
        }
    }

    // MARK: Done

    private func complete() {
        if mode == .firstRun {
            deps.defaults.set(true, forKey: DefaultsKey.faceUnlockNoticeAccepted)
            deps.defaults.set(true, forKey: DefaultsKey.faceUnlockEnabled)
        }
        movedForward = true
        step = .complete
        completeWork = deps.scheduler.after(Timing.complete) { [weak self] in
            self?.teardown()
            self?.isFinished = true
        }
    }
}
