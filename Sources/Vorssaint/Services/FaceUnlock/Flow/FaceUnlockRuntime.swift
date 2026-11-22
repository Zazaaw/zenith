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
    static var isSupported: Bool {
        if #available(macOS 15, *) { return true }
        return false
    }

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

    private init() {
        session = FaceUnlockSession(.init(
            keychain: FaceUnlockLoginKeychain(),
            passwordFile: FaceUnlockPasswordFile(),
            authenticator: FaceUnlockTouchID(),
            typist: FaceUnlockKeystrokes(),
            isScreenLocked: FaceUnlockScreenLock.isLocked,
            hasOtherSealedData: { FaceUnlockSetup.faces?.hasSealedData ?? false },
            now: Date.init,
            background: { DispatchQueue.global(qos: .userInitiated).async(execute: $0) },
            main: { work in Thread.isMainThread ? work() : DispatchQueue.main.async(execute: work) }))
    }

    /// At launch: plugs the session in and starts listening if face unlock is on.
    func launch() {
        FaceUnlock.credentials = session
        FaceUnlockKeys.provider = session
        sessionWatch = session.$isUnlocked.removeDuplicates().sink { [weak self] unlocked in
            self?.syncAutoLock(unlocked)
        }
        sync()
    }

    /// After the switch or the triggers change.
    func sync() {
        let enabled = Self.isSupported && UserDefaults.standard.bool(forKey: DefaultsKey.faceUnlockEnabled)
        if enabled { startListening() } else { stopListening() }
        coordinator.preferencesChanged()
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
        }
        observers.append((center, token))
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
