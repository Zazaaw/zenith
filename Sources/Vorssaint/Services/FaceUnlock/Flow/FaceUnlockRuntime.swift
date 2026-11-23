// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Face unlock is adapted from Glance by Jonathan Zhou (MIT),
// https://github.com/jonnyoo/glance — see the notice in About.

import AppKit
import Combine
import Foundation

/// Zenith fork: face unlock in the running app. Builds the real session and
/// coordinator, plugs the session in as `FaceUnlock.credentials` and the key
/// provider, listens for lock, wake and sleep while face unlock is on (and
/// not at all while it is off), and re-locks an idle session (Glance's
/// `LockMonitor`, `SessionAutoLocker` and app wiring). Main thread only.
final class FaceUnlockRuntime {
    static let shared = FaceUnlockRuntime()

    /// Recognition needs macOS 15 (Glance's floor); Settings says so below it.
    static var isSupported: Bool { FaceUnlockRecognition.isSupported }

    let session: FaceUnlockSession
    let spaceKeys = FaceUnlockSpaceKeyMonitor()
    private(set) lazy var coordinator = FaceUnlockCoordinator(.init(
        preferences: { FaceUnlockPreferences(defaults: .standard) },
        isScreenLocked: FaceUnlockScreenLock.isLocked,
        recognizer: { FaceUnlock.recognizer },
        credentials: { FaceUnlock.credentials },
        presence: .shared,
        scheduler: FaceUnlockMainScheduler(),
        spaceKeys: spaceKeys,
        uptime: { ProcessInfo.processInfo.systemUptime }))

    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var autoLockTimer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var sessionWatch: AnyCancellable?
    private var preparedModel = false
    /// The person said no to the session's Touch ID prompt: not asked again unprompted until next launch.
    private var sessionPromptDeclined = false
    private var sessionPromptWork: DispatchWorkItem?

    private init() {
        session = FaceUnlockSession(.init(
            keychain: FaceUnlockLoginKeychain(),
            passwordFile: FaceUnlockPasswordFile(),
            authenticator: FaceUnlockTouchID(),
            typist: FaceUnlockKeystrokes(),
            isScreenLocked: FaceUnlockScreenLock.isLocked,
            // The face store is sealed with the same key: never mint a new one over it.
            hasOtherSealedData: { SecureFaceStore.exists },
            now: Date.init,
            background: { DispatchQueue.global(qos: .userInitiated).async(execute: $0) },
            main: { work in Thread.isMainThread ? work() : DispatchQueue.main.async(execute: work) }))
    }

    /// At launch, after `FaceUnlockRecognition.install()`: plugs the session in
    /// as the credentials and the key provider, recognition's enrollment and
    /// faces in as the setup's seams, and starts listening if face unlock is on.
    func launch() {
        FaceUnlock.credentials = session
        FaceUnlockKeys.provider = session
        if Self.isSupported {
            FaceUnlockSetup.faces = FaceUnlockFaceStoreAdapter()
            FaceUnlockSetup.makeEnrollment = { FaceUnlockEnrollmentAdapter(replacing: $0) }
            MainActor.assumeIsolated {
                // A scan also ends the moment the screen is no longer locked.
                FaceUnlockRecognitionService.shared.shouldContinueScan = { FaceUnlockScreenLock.isLocked() }
                // Face Lab's Start Onboarding, Add Identity and Recapture open the setup window.
                FaceUnlockLab.enrollmentHandler = { request in
                    switch request {
                    case .fullOnboarding: FaceUnlockSetupWindow.startFirstRun()
                    case .addIdentity: FaceUnlockSetupWindow.startAddFace()
                    case .recapture(let id, let name): FaceUnlockSetupWindow.startAddFace(replacing: id, name: name)
                    }
                }
            }
        }
        sessionWatch = session.$isUnlocked.removeDuplicates().sink { [weak self] unlocked in
            self?.syncAutoLock(unlocked)
        }
        sync()
        // Once per Zenith session, as Glance: at login the person is here, so
        // ask for Touch ID now rather than leave the first lock unable to type.
        askForSessionIfNeeded(after: 3)
    }

    /// After the switch or the triggers change.
    func sync() {
        let enabled = Self.isSupported && UserDefaults.standard.bool(forKey: DefaultsKey.faceUnlockEnabled)
        if enabled { startListening() } else { stopListening() }
        coordinator.preferencesChanged()
        if enabled, !preparedModel {
            // Compiles and loads ArcFace now, so the first scan on the lock screen is not the one that waits.
            preparedModel = true
            Task { @MainActor in _ = await FaceUnlockRecognition.prepareModel() }
        }
    }

    /// On quit: the key leaves memory with the process anyway; say so first.
    func terminate() {
        stopListening()
        session.lockSession()
    }

    // MARK: Lock, wake and sleep

    private func startListening() {
        guard observers.isEmpty else { return }
        let distributed = DistributedNotificationCenter.default()
        observe(distributed, "com.apple.screenIsLocked", .screenLocked)
        observe(distributed, "com.apple.screenIsUnlocked", .screenUnlocked)
        // A key that dismisses the screen saver cannot be seen (Secure Event
        // Input), so its stop stands in for it.
        observe(distributed, "com.apple.screensaver.didstop", .wake)
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.willSleepNotification.rawValue, .willSleep)
        // Display and system wake land within ~100 ms of each other in either order.
        observe(workspace, NSWorkspace.screensDidWakeNotification.rawValue, .wake)
        observe(workspace, NSWorkspace.didWakeNotification.rawValue, .wake)
    }

    private func stopListening() {
        for (center, token) in observers { center.removeObserver(token) }
        observers = []
        spaceKeys.stop()
    }

    private func observe(_ center: NotificationCenter, _ name: String, _ event: FaceUnlockCoordinator.Event) {
        let token = center.addObserver(forName: Notification.Name(name), object: nil, queue: .main) { [weak self] _ in
            self?.coordinator.handle(event)
            // Unlocked by hand while the session was locked (the island said
            // so): the person is at the Mac, ask now so the next lock works.
            if event == .screenUnlocked { self?.askForSessionIfNeeded(after: 1.5) }
        }
        observers.append((center, token))
    }

    // MARK: Session prompt

    /// Asks for Touch ID to open the session when face unlock is on and set up
    /// but cannot type the password. Never on the lock screen, never again
    /// after a "Cancel" until Zenith starts again.
    private func askForSessionIfNeeded(after delay: TimeInterval) {
        sessionPromptWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.sessionPromptDeclined, Self.isSupported,
                  UserDefaults.standard.bool(forKey: DefaultsKey.faceUnlockEnabled),
                  self.session.hasStoredPassword, !self.session.isSessionUnlocked,
                  !self.session.isAuthenticating, !FaceUnlockScreenLock.isLocked() else { return }
            self.session.unlockSession(reason: ZenithStrings.faceUnlock(.enUS).reasonOpen) { [weak self] opened in
                if !opened { self?.sessionPromptDeclined = true }
            }
        }
        sessionPromptWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    // MARK: Auto-lock

    /// Checked every few minutes and on wake while the session is open; no
    /// timer while it is locked.
    private func syncAutoLock(_ unlocked: Bool) {
        autoLockTimer?.invalidate()
        autoLockTimer = nil
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
        wakeObserver = nil
        guard unlocked else { return }
        let timer = Timer(timeInterval: FaceUnlockAutoLocking.checkInterval, repeats: true) { [weak self] _ in
            self?.lockIfIdle()
        }
        // `.common`, so an open menu or a drag does not hold the check back.
        RunLoop.main.add(timer, forMode: .common)
        autoLockTimer = timer
        // No timer fires during sleep, but that time still counts as idle.
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.lockIfIdle()
        }
    }

    private func lockIfIdle() {
        let limit = FaceUnlockPreferences(defaults: .standard).autoLock
        session.lockIfIdle(limit: limit)
    }
}
