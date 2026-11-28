// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import Combine
import LocalAuthentication

// Zenith fork: App Lock in the running app. While it is on with an app to
// lock, it listens to the workspace (an app coming to the front, launching or
// quitting) and to the Mac locking, sleeping and starting its screen saver:
// notifications only, no timer and no polling. Off, or with no app chosen, it
// observes nothing. Tests and the catalog run quiet: no observer, no shield,
// no prompt. Decisions live in AppLockSupport; this file only carries them out.

@MainActor
final class AppLockService: ObservableObject {
    static let shared = AppLockService()

    /// Lock Now just ran: the page says so for a moment.
    @Published private(set) var lockedNow = false

    private var sessions = AppLockSessions()
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private let shield = AppLockShieldController()
    private let prompt = AppLockPrompt()
    /// The app the shield covers.
    private var covered: NSRunningApplication?
    /// Bumped by every step of an unlock, so a late answer from an earlier
    /// step (a face scan cancelled for Touch ID) changes nothing.
    private var attempt = 0
    private var lockedNowWork: DispatchWorkItem?

    private init() {}

    private var preferences: AppLockPreferences { AppLockPreferences(defaults: .standard) }

    /// At launch: only an App Lock that is on, with an app to lock, comes to life.
    static func launch() {
        guard !ZenithQuiet.isOn, AppLockPreferences(defaults: .standard).isWatching else { return }
        shared.sync()
    }

    /// Follows the preferences: called at launch and by the Settings page.
    func sync() {
        guard !ZenithQuiet.isOn else { return stop() } // tests and the catalog never watch the workspace
        let preferences = preferences
        guard preferences.isWatching else {
            stop()
            sessions.lockAll()
            return
        }
        start()
        if let covered, !preferences.isLocked(covered.bundleIdentifier ?? "") { takeShieldDown() }
        coverFrontmostIfLocked()
    }

    /// The page's Lock Now: every unlock ends and the locked apps that are
    /// open leave the screen.
    func lockNow() {
        sessions.lockAll()
        guard !ZenithQuiet.isOn else { return }
        hideRunningLockedApps()
        lockedNow = true
        lockedNowWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.lockedNow = false }
        lockedNowWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }

    /// Whether Zenith's own Face Unlock can look for a face right now: on,
    /// set up, and its face store open (Touch ID opened its session).
    static var faceUnlockReady: Bool {
        guard FaceUnlockRuntime.isSupported, FaceUnlockSetup.isRecognitionAvailable,
              UserDefaults.standard.bool(forKey: DefaultsKey.faceUnlockEnabled),
              UserDefaults.standard.bool(forKey: DefaultsKey.faceUnlockNoticeAccepted) else { return false }
        return FaceUnlock.recognizer?.hasEnrolledFace ?? false
    }

    /// Face Unlock is on and set up (its faces may still be sealed).
    static var faceUnlockSetUp: Bool {
        FaceUnlockRuntime.isSupported && FaceUnlockSetup.isRecognitionAvailable
            && UserDefaults.standard.bool(forKey: DefaultsKey.faceUnlockEnabled)
            && UserDefaults.standard.bool(forKey: DefaultsKey.faceUnlockNoticeAccepted)
    }

    // MARK: Observing

    private func start() {
        guard observers.isEmpty else { return }
        let workspace = NSWorkspace.shared.notificationCenter
        observeApp(workspace, NSWorkspace.didActivateApplicationNotification) { $0.activated($1) }
        observeApp(workspace, NSWorkspace.didLaunchApplicationNotification) { $0.launched($1) }
        observeApp(workspace, NSWorkspace.didTerminateApplicationNotification) { $0.terminated($1) }
        observe(workspace, NSWorkspace.willSleepNotification) { $0.macLocked() }
        observe(workspace, NSWorkspace.screensDidSleepNotification) { $0.macLocked() }
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification) { $0.macLocked() } // another user
        observe(workspace, NSWorkspace.didWakeNotification) { $0.macReturned() }
        let distributed = DistributedNotificationCenter.default()
        observe(distributed, Notification.Name("com.apple.screenIsLocked")) { $0.macLocked() }
        observe(distributed, Notification.Name("com.apple.screensaver.didstart")) { $0.macLocked() }
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked")) { $0.macReturned() }
    }

    private func stop() {
        for (center, token) in observers { center.removeObserver(token) }
        observers = []
        takeShieldDown()
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name,
                         _ handle: @escaping (AppLockService) -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                handle(self)
            }
        }
        observers.append((center, token))
    }

    private func observeApp(_ center: NotificationCenter, _ name: Notification.Name,
                            _ handle: @escaping (AppLockService, NSRunningApplication) -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated {
                guard let self, let app else { return }
                handle(self, app)
            }
        }
        observers.append((center, token))
    }

    // MARK: Workspace events

    private func activated(_ app: NSRunningApplication) {
        let preferences = preferences
        let bundleID = app.bundleIdentifier
        let isRegular = app.activationPolicy == .regular
        if let covered, let shielded = covered.bundleIdentifier {
            switch AppLockShieldAction.when(bundleID, isRegular: isRegular, covering: shielded) {
            case .keep: break
            case .refocus:
                shield.focus()
                return
            case .cancel:
                cancelUnlock()
            }
        }
        let previous = sessions.frontmost
        if AppLockSessions.hidesOnLeaving(previous, for: bundleID, isRegular: isRegular, preferences),
           let previous, let leaving = Self.running(previous).first {
            leaving.hide()
        }
        if sessions.activated(bundleID, isRegular: isRegular, at: Date(), preferences) == .lock {
            cover(app)
        }
    }

    private func launched(_ app: NSRunningApplication) {
        // Usually followed by its activation; this catches one that is in front already.
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier,
              covered?.processIdentifier != app.processIdentifier else { return }
        activated(app)
    }

    private func terminated(_ app: NSRunningApplication) {
        guard let bundleID = app.bundleIdentifier else { return }
        if covered?.processIdentifier == app.processIdentifier { takeShieldDown() }
        let running = Set(NSWorkspace.shared.runningApplications
            .filter { $0.processIdentifier != app.processIdentifier }
            .compactMap(\.bundleIdentifier))
        sessions.terminated(bundleID, stillRunning: running, preferences)
    }

    /// The screen locked, the screen saver started, the Mac is going to sleep
    /// or another user took over.
    private func macLocked() {
        let preferences = preferences
        if covered != nil { cancelUnlock() }
        sessions.macLocked(preferences)
        if preferences.lockWithMac { hideRunningLockedApps() }
    }

    /// Back from the lock screen or sleep: whatever is in front is checked again.
    private func macReturned() {
        coverFrontmostIfLocked()
    }

    private func coverFrontmostIfLocked() {
        guard covered == nil, !FaceUnlockScreenLock.isLocked(),
              let front = NSWorkspace.shared.frontmostApplication else { return }
        activated(front)
    }

    private func hideRunningLockedApps() {
        let preferences = preferences
        for app in NSWorkspace.shared.runningApplications
        where preferences.isLocked(app.bundleIdentifier ?? "") && app.processIdentifier != covered?.processIdentifier {
            app.hide()
        }
    }

    private static func running(_ bundleID: String) -> [NSRunningApplication] {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
    }

    // MARK: Covering and unlocking

    private func cover(_ app: NSRunningApplication) {
        guard !ZenithQuiet.isOn else { return } // never a shield or a prompt in tests or the catalog
        if covered?.processIdentifier == app.processIdentifier {
            shield.focus()
            return
        }
        if covered != nil { takeShieldDown() }
        covered = app
        let info = AppLockAppInfo(app: app)
        let model = AppLockShieldModel(name: info.name, icon: info.icon)
        model.onUnlock = { [weak self] in self?.unlockPressed() }
        model.onCancel = { [weak self] in self?.cancelUnlock() }
        shield.show(model, coveringProcess: app.processIdentifier)
        beginUnlock(tryFace: true)
    }

    private func beginUnlock(tryFace: Bool) {
        guard covered != nil else { return }
        attempt &+= 1
        let current = attempt
        let preferences = preferences
        let plan = AppLockMethod.plan(preferFace: tryFace && preferences.faceUnlock, faceUnlockReady: Self.faceUnlockReady)
        if plan.first == .face {
            shield.model?.status = .face
            let service = FaceUnlockRecognitionService.shared
            service.scan(timeout: FaceUnlockRecognition.scanTimeout,
                         while: { [weak self] in self?.attempt == current && self?.covered != nil }) { [weak self] outcome in
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        guard let self, self.attempt == current, self.covered != nil else { return }
                        if case .matched = outcome { return self.unlocked() }
                        // The Mac locked meanwhile: no prompt on the lock screen.
                        if FaceUnlockScreenLock.isLocked() { return self.cancelUnlock() }
                        self.askSystem(faceMissed: true)
                    }
                }
            }
            return
        }
        askSystem(faceMissed: false)
    }

    private func askSystem(faceMissed: Bool) {
        guard let covered else { return }
        attempt &+= 1
        let current = attempt
        shield.model?.status = faceMissed ? .faceMissed : .waiting
        let name = AppLockAppInfo(app: covered).name
        prompt.ask(reason: ZenithStrings.appLock(.enUS).reason(name)) { [weak self] result in
            MainActor.assumeIsolated {
                guard let self, self.attempt == current, self.covered != nil else { return }
                switch result {
                case .passed: self.unlocked()
                case .cancelled: self.cancelUnlock()
                case .failed:
                    self.shield.model?.status = .failed
                    self.shield.focus()
                }
            }
        }
    }

    /// The shield's Unlock button: Touch ID or the password, now. A running
    /// face scan sees the new attempt and stops on its next frame.
    private func unlockPressed() {
        guard covered != nil, shield.model?.status.isPrompting != true else { return }
        askSystem(faceMissed: false)
    }

    private func unlocked() {
        guard let app = covered, let bundleID = app.bundleIdentifier else { return takeShieldDown() }
        sessions.unlocked(bundleID, at: Date(), preferences)
        takeShieldDown()
        app.activate()
    }

    /// Cancelled, or the person went elsewhere: the app hides and the shield goes.
    private func cancelUnlock() {
        let app = covered
        takeShieldDown()
        app?.hide()
    }

    /// A face scan of ours stops by itself on its next frame (its `while`
    /// sees the new attempt). It is never cancelled from here: by now it may
    /// be the lock screen's scan that runs.
    private func takeShieldDown() {
        attempt &+= 1
        prompt.cancel()
        covered = nil
        shield.dismiss()
    }
}

// MARK: - The app's name and icon

/// A locked app as Settings and the shield show it.
struct AppLockAppInfo {
    let bundleID: String
    let name: String
    let icon: NSImage
    /// The app was found on this Mac.
    let isInstalled: Bool

    init(bundleID: String) {
        self.bundleID = bundleID
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            name = Self.name(of: url)
            icon = NSWorkspace.shared.icon(forFile: url.path)
            isInstalled = true
        } else {
            name = bundleID
            icon = NSWorkspace.shared.icon(for: .applicationBundle)
            isInstalled = false
        }
    }

    init(app: NSRunningApplication) {
        bundleID = app.bundleIdentifier ?? ""
        name = app.localizedName ?? app.bundleURL.map(Self.name(of:)) ?? bundleID
        icon = app.icon ?? NSWorkspace.shared.icon(for: .applicationBundle)
        isInstalled = true
    }

    static func name(of url: URL) -> String {
        (FileManager.default.displayName(atPath: url.path) as NSString).deletingPathExtension
    }
}

// MARK: - Touch ID or the password

/// One LocalAuthentication prompt at a time: Touch ID with the Mac password
/// as its fallback (`.deviceOwnerAuthentication`). Answers on the main thread.
final class AppLockPrompt {
    enum Result { case passed, cancelled, failed }

    private var context: LAContext?

    func ask(reason: String, completion: @escaping (Result) -> Void) {
        cancel()
        let context = LAContext()
        self.context = context
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            DispatchQueue.main.async { completion(.failed) }
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { passed, error in
            let code = (error as? LAError)?.code
            DispatchQueue.main.async {
                if passed { return completion(.passed) }
                switch code {
                case .userCancel, .appCancel, .systemCancel, .userFallback: completion(.cancelled)
                default: completion(.failed)
                }
            }
        }
    }

    /// Takes an open prompt down (the app quit, the person went elsewhere).
    func cancel() {
        context?.invalidate()
        context = nil
    }
}
