// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Face unlock is adapted from Glance by Jonathan Zhou (MIT),
// https://github.com/jonnyoo/glance — see the notice in About.

import Foundation

/// Zenith fork: joins the lock screen to recognition and the stored password
/// (Glance's `FaceUnlockCoordinator`). It hears lock, wake and sleep, decides
/// when to arm and scan, publishes what the island shows through
/// `FaceUnlockPresence`, and on a match asks the credentials to type the
/// password, which they do only while CGSession says the screen is locked.
///
/// Main thread only. Everything it touches is injected, so the tests drive
/// it with a fake recognizer, fake credentials and a manual clock.
///
/// Known limitation, as in Glance: liveness defeats a photo but not a replayed
/// video, and a successful spoof types the real password.
final class FaceUnlockCoordinator {
    enum Event: Equatable { case screenLocked, screenUnlocked, willSleep, wake }

    /// Why nothing can be scanned yet, read at each decision.
    enum Readiness: Equatable { case ready, needsTouchID, notSetUp }

    struct Dependencies {
        var preferences: () -> FaceUnlockPreferences
        /// The authoritative lock state (CGSession). Notifications only prompt a look.
        var isScreenLocked: () -> Bool
        var recognizer: () -> FaceUnlockRecognizer?
        var credentials: () -> FaceUnlockCredentials?
        var presence: FaceUnlockPresence
        var scheduler: FaceUnlockScheduling
        var spaceKeys: FaceUnlockSpaceKeyListening
        /// Monotonic seconds, for the wake debounce.
        var uptime: () -> TimeInterval
    }

    /// Glance's timings.
    enum Timing {
        /// CGSession's state can lag the notification right after a wake.
        static let settle: TimeInterval = 0.3
        /// Lets the login window finish coming in before the island arms.
        static let arm: TimeInterval = 0.25
        /// One lid-open sends several wake signals; these count as one wake.
        static let rearmDebounce: TimeInterval = 2
        /// How long a failure shows before the island rests again.
        static let failureHold: TimeInterval = 5
        /// Between headless retries, so the camera does not restart in a loop.
        static let headlessRetry: TimeInterval = 1
    }

    private let deps: Dependencies
    private var sleeping = false
    private var hasArmedForCurrentLock = false
    /// One automatic retry per lock: a retry that could retry would run the
    /// camera for the whole lock.
    private var hasAutoRetriedForCurrentLock = false
    private var lastArmedAt: TimeInterval?
    /// Bumped by every scan and every disarm; a completion from an older scan
    /// is ignored, so it never lands on the newer one (a real Glance bug).
    private var generation = 0
    private(set) var isScanning = false
    private var isTyping = false
    private var evaluateWork: FaceUnlockScheduled?
    private var armWork: FaceUnlockScheduled?
    private var failureWork: FaceUnlockScheduled?

    init(_ dependencies: Dependencies) {
        deps = dependencies
    }

    private var presence: FaceUnlockPresence { deps.presence }

    // MARK: Inputs

    /// A lock, unlock, sleep or wake signal. Sleep and wake update at once;
    /// the decision waits out the settle delay, then reads CGSession.
    func handle(_ event: Event) {
        switch event {
        case .willSleep:
            // The lock that comes with a lid close lands just before sleep:
            // nothing scans until the wake.
            sleeping = true
            cancelScan(resting: true)
        case .wake:
            sleeping = false
        case .screenLocked, .screenUnlocked:
            break
        }
        evaluateWork?.cancel()
        evaluateWork = deps.scheduler.after(Timing.settle) { [weak self] in self?.evaluate(event) }
    }

    /// The island was hovered or clicked (set as `presence.onActivate` while armed).
    func activate() {
        let preferences = deps.preferences()
        guard preferences.isEnabled, !isScanning, !isTyping, deps.isScreenLocked() else { return }
        switch presence.state {
        case .armed:
            guard preferences.triggers.contains(.onHover) else { return }
        case .failure:
            guard preferences.retryOnHover else { return }
        default:
            return
        }
        guard readiness() == .ready else { return }
        startScan()
    }

    /// Space on the lock screen, from the HID listener.
    func spaceKeyPressed() {
        let preferences = deps.preferences()
        guard preferences.isEnabled, preferences.triggers.contains(.onSpace), deps.isScreenLocked(),
              !sleeping, readiness() == .ready else { return }
        // Already looking: swallows repeats and double presses.
        guard !isScanning, !isTyping else { return }
        guard preferences.showsIsland else { return startScan() }
        switch presence.state {
        case .armed, .failure: startScan()
        default: arm(autoScan: true)
        }
    }

    /// The face unlock preferences changed (switch, triggers).
    func preferencesChanged() {
        if !deps.preferences().isEnabled {
            disarm()
            deps.spaceKeys.stop()
        } else {
            updateSpaceKeys()
        }
    }

    /// What can be scanned right now.
    func readiness() -> Readiness {
        guard let credentials = deps.credentials(), credentials.hasStoredPassword else { return .notSetUp }
        guard credentials.isSessionUnlocked else { return .needsTouchID }
        guard let recognizer = deps.recognizer(), recognizer.hasEnrolledFace else { return .notSetUp }
        return .ready
    }

    // MARK: Decisions

    /// The trigger a lock event stands for; none for unlock and sleep.
    static func trigger(for event: Event) -> FaceUnlockTrigger? {
        switch event {
        case .screenLocked: return .onLock
        case .wake: return .onWake
        case .screenUnlocked, .willSleep: return nil
        }
    }

    private func evaluate(_ event: Event) {
        evaluateWork = nil
        guard deps.isScreenLocked() else {
            hasArmedForCurrentLock = false
            hasAutoRetriedForCurrentLock = false
            disarm()
            deps.spaceKeys.stop()
            return
        }
        guard !sleeping else { return }

        // A wake is an explicit "let me back in": arm again, unless it is
        // one more signal of the wake that just armed.
        if event == .wake, !isWithinArmBurst { hasArmedForCurrentLock = false }

        updateSpaceKeys()

        let preferences = deps.preferences()
        guard preferences.isEnabled, !hasArmedForCurrentLock,
              let signal = Self.trigger(for: event) else { return }

        switch readiness() {
        case .notSetUp:
            return
        case .needsTouchID:
            // Say why face unlock is not running; it cannot read the password.
            if preferences.showsIsland, !isScanning { presence.state = .needsTouchID }
            return
        case .ready:
            break
        }

        // An unselected trigger only skips the automatic scan: the island
        // still arms for a hover. Headless, there is nothing to hover.
        let autoScan = preferences.triggers.contains(signal)
        guard preferences.showsIsland || autoScan else { return }

        hasArmedForCurrentLock = true
        lastArmedAt = deps.uptime()
        armWork?.cancel()
        armWork = deps.scheduler.after(Timing.arm) { [weak self] in
            self?.armWork = nil
            self?.arm(autoScan: autoScan)
        }
    }

    private var isWithinArmBurst: Bool {
        guard let lastArmedAt else { return false }
        return deps.uptime() - lastArmedAt < Timing.rearmDebounce
    }

    private func arm(autoScan: Bool) {
        guard deps.isScreenLocked() else { return }
        guard deps.preferences().showsIsland else {
            if autoScan { startScan() }
            return
        }
        presence.onActivate = { [weak self] in self?.activate() }
        if !isScanning { presence.state = .armed }
        if autoScan { startScan() }
    }

    private func startScan() {
        guard let recognizer = deps.recognizer() else { return }
        if isScanning { recognizer.cancelScan() }
        failureWork?.cancel()
        failureWork = nil
        generation &+= 1
        let scan = generation
        let preferences = deps.preferences()
        isScanning = true
        if preferences.showsIsland { presence.state = .scanning }
        recognizer.scan(timeout: TimeInterval(preferences.detectionSeconds)) { [weak self] outcome in
            self?.finishScan(scan, outcome)
        }
    }

    private func finishScan(_ scan: Int, _ outcome: FaceUnlockScanOutcome) {
        // A stopped or superseded scan, or a completion that came twice.
        guard scan == generation, isScanning else { return }
        isScanning = false
        // Unlocked by hand while scanning: the unlock's own evaluation hides it.
        guard deps.isScreenLocked() else { return }
        switch outcome {
        case .matched:
            guard let credentials = deps.credentials() else { return fail(.noPassword) }
            isTyping = true
            credentials.typeStoredPassword { [weak self] typed in
                guard let self, scan == self.generation else { return }
                self.isTyping = false
                if typed {
                    if self.deps.preferences().showsIsland { self.presence.state = .success }
                } else {
                    // Typing refused or failed (not locked any more, no
                    // Accessibility, the password unreadable).
                    self.fail(.noPassword)
                }
            }
        case .failed(let failure):
            fail(failure)
        }
    }

    private func fail(_ failure: FaceUnlockFailure) {
        let preferences = deps.preferences()
        let retries = preferences.autoRetryOnce && !hasAutoRetriedForCurrentLock
        if retries { hasAutoRetriedForCurrentLock = true }
        let scan = generation
        if preferences.showsIsland {
            presence.state = .failure(failure)
            failureWork = deps.scheduler.after(Timing.failureHold) { [weak self] in
                guard let self, scan == self.generation else { return }
                self.failureWork = nil
                if case .failure = self.presence.state { self.presence.state = .armed }
                if retries { self.retry() }
            }
        } else if retries {
            failureWork = deps.scheduler.after(Timing.headlessRetry) { [weak self] in
                guard let self, scan == self.generation else { return }
                self.failureWork = nil
                self.retry()
            }
        }
    }

    /// Re-checked rather than trusted: the Mac may have been unlocked by hand,
    /// or a scan started by hover, while the retry waited.
    private func retry() {
        guard deps.preferences().isEnabled, deps.isScreenLocked(), !sleeping, !isScanning, !isTyping,
              readiness() == .ready else { return }
        startScan()
    }

    private func cancelScan(resting: Bool) {
        guard isScanning else { return }
        generation &+= 1
        isScanning = false
        deps.recognizer()?.cancelScan()
        if resting, presence.state == .scanning { presence.state = .armed }
    }

    private func disarm() {
        armWork?.cancel()
        armWork = nil
        failureWork?.cancel()
        failureWork = nil
        cancelScan(resting: false)
        generation &+= 1
        isTyping = false
        presence.onActivate = nil
        if presence.state != .hidden { presence.state = .hidden }
    }

    /// The space listener runs only while locked with "On space" on and the
    /// access granted; a missing grant means "do not listen", never a prompt.
    private func updateSpaceKeys() {
        let preferences = deps.preferences()
        if preferences.isEnabled, preferences.triggers.contains(.onSpace), deps.isScreenLocked(),
           deps.spaceKeys.hasAccess {
            deps.spaceKeys.start { [weak self] in self?.spaceKeyPressed() }
        } else {
            deps.spaceKeys.stop()
        }
    }
}

protocol FaceUnlockScheduled: AnyObject {
    func cancel()
}

protocol FaceUnlockScheduling: AnyObject {
    /// Runs `work` on the main thread after `seconds`, unless cancelled.
    func after(_ seconds: TimeInterval, _ work: @escaping () -> Void) -> FaceUnlockScheduled
}

protocol FaceUnlockSpaceKeyListening: AnyObject {
    /// Input Monitoring (or Accessibility, which covers it) is granted; never prompts.
    var hasAccess: Bool { get }
    /// Idempotent; fails closed when access is missing.
    func start(_ onPress: @escaping () -> Void)
    func stop()
}

/// The app's scheduler: main-queue work items.
final class FaceUnlockMainScheduler: FaceUnlockScheduling {
    private final class Item: FaceUnlockScheduled {
        let work: DispatchWorkItem
        init(_ work: DispatchWorkItem) { self.work = work }
        func cancel() { work.cancel() }
    }

    func after(_ seconds: TimeInterval, _ work: @escaping () -> Void) -> FaceUnlockScheduled {
        let item = DispatchWorkItem(block: work)
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
        return Item(item)
    }
}
