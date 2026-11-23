// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CryptoKit
import Foundation
import SwiftUI

/// Zenith fork: face unlock's security side and flow. Everything runs against
/// fakes: a test key and an in-memory keychain (never the real keychain), a
/// recording typist (never a keystroke), a fake recognizer, a manual clock.
/// Nothing asks for a permission or reads the camera.
enum FaceUnlockFlowTests {
    static func run(_ suite: TestSuite) {
        cipher(suite)
        preferences(suite)
        session(suite)
        typingGuard(suite)
        autoLock(suite)
        triggerDecisions(suite)
        coordinator(suite)
        retries(suite)
        spaceKey(suite)
        endToEnd(suite)
        onboarding(suite)
        strings(suite)
    }

    // MARK: Crypto

    private static func cipher(_ suite: TestSuite) {
        let key = SymmetricKey(data: Data(repeating: 7, count: 32))
        let password = Data("hunter2 · ñ 🔑".utf8)
        let sealed = try? FaceUnlockCipher.seal(password, key: key)
        suite.expect(sealed.flatMap { try? FaceUnlockCipher.open($0, key: key) } == password,
                     "a password sealed with a key opens with it, byte for byte")
        suite.expect(sealed.map { $0.range(of: password) == nil } == true && (sealed?.count ?? 0) == password.count + 28,
                     "the sealed form hides the password: nonce, ciphertext and tag")
        let other = SymmetricKey(data: Data(repeating: 8, count: 32))
        suite.expect(sealed.flatMap { try? FaceUnlockCipher.open($0, key: other) } == nil,
                     "another key does not open it")
        var tampered = sealed ?? Data()
        if !tampered.isEmpty { tampered[tampered.count / 2] ^= 0x01 }
        suite.expect((try? FaceUnlockCipher.open(tampered, key: key)) == nil, "a changed byte fails the tag")
        suite.expect(sealed != (try? FaceUnlockCipher.seal(password, key: key)), "every seal uses a fresh nonce")
        suite.expect(FaceUnlockCipher.makeKey().withUnsafeBytes { $0.count } == 32, "keys are 256-bit")
    }

    // MARK: Preferences

    private static func preferences(_ suite: TestSuite) {
        suite.expect(FaceUnlockTriggers.decode(nil) == [.onLock, .onWake, .onHover]
                     && FaceUnlockTriggers.decode("") == FaceUnlockTriggers.defaultSet,
                     "the default triggers are Glance's: lock, wake and hover, not space")
        suite.expect(FaceUnlockTriggers.decode("onSpace, bogus,onWake") == [.onSpace, .onWake],
                     "unknown names are skipped")
        suite.expect(FaceUnlockTriggers.decode("bogus") == FaceUnlockTriggers.defaultSet,
                     "nothing readable falls back to the defaults, never to none")
        suite.expect(FaceUnlockTriggers.encode([.onWake, .onLock]) == "onLock,onWake", "encoding is in a fixed order")
        suite.expect(FaceUnlockTriggers.toggled(.onLock, on: false, in: [.onLock]) == [.onLock]
                     && FaceUnlockTriggers.toggled(.onLock, on: false, in: [.onLock, .onSpace]) == [.onSpace],
                     "the last trigger cannot be turned off")

        let registered = Defaults.registeredDefaults
        suite.expect(registered[DefaultsKey.faceUnlockEnabled] == nil
                     && registered[DefaultsKey.faceUnlockCameraID] == nil
                     && registered[DefaultsKey.faceUnlockNoticeAccepted] == nil,
                     "the switch, the camera and the notice stay on this Mac, never in a settings backup")
        suite.expect(registered[DefaultsKey.faceUnlockTriggers] as? String == "onLock,onWake,onHover"
                     && registered[DefaultsKey.faceUnlockAutoLockDays] as? Int == 7
                     && registered[DefaultsKey.faceUnlockLivenessEnabled] as? Bool == true
                     && registered[DefaultsKey.faceUnlockLivenessMode] as? String == "light"
                     && registered[DefaultsKey.faceUnlockMatchThreshold] as? Double == 0.66
                     && registered[DefaultsKey.faceUnlockMinimumFaceWidth] as? Double == 0.21
                     && registered[DefaultsKey.faceUnlockDetectionSeconds] as? Int == 5
                     && registered[DefaultsKey.faceUnlockRetryOnHover] as? Bool == true
                     && registered[DefaultsKey.faceUnlockAutoRetry] as? Bool == false
                     && registered[DefaultsKey.faceUnlockAnimationStyle] as? String == "original",
                     "the other preferences are registered with Glance's defaults (auto-lock 7 days)")
        let backed = SettingsBackupSupport.exportKeys()
        suite.expect(backed.contains(DefaultsKey.faceUnlockTriggers) && !backed.contains(DefaultsKey.faceUnlockEnabled)
                     && !backed.contains(where: { $0.lowercased().contains("password") && $0.hasPrefix("faceUnlock") }),
                     "a backup carries the preferences, not the switch, and no secret")

        let domain = "com.vorssaint.tests.face-unlock-preferences"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        suite.expect(FaceUnlockPreferences(defaults: defaults) == .defaults, "nothing stored reads as the defaults")
        defaults.set(true, forKey: DefaultsKey.faceUnlockEnabled)
        defaults.set(40, forKey: DefaultsKey.faceUnlockDetectionSeconds)
        defaults.set(99, forKey: DefaultsKey.faceUnlockAutoLockDays)
        defaults.set("none", forKey: DefaultsKey.faceUnlockAnimationStyle)
        let read = FaceUnlockPreferences(defaults: defaults)
        suite.expect(read.isEnabled && read.detectionSeconds == 10 && read.autoLock == .sevenDays
                     && read.animationStyle == FaceUnlockAnimationStyle.none && !read.showsIsland,
                     "stored values are clamped or fall back, and no animation means no island")
        suite.expect(FaceUnlockMatchLevel.nearest(to: 0.70) == .moreStrict
                     && FaceUnlockMatchLevel.nearest(to: 0.6) == .lessStrict
                     && FaceUnlockMatchLevel.nearest(to: 0.66) == .standard
                     && FaceUnlockDistanceLevel.nearest(to: 0.21) == .standard
                     && FaceUnlockDistanceLevel.nearest(to: 0.3) == .close,
                     "a stored value reads as its nearest stop, and the defaults read as Default")
        suite.expect(abs(Double(FaceUnlockRecognitionSettings.defaultMatchThreshold) - FaceUnlockMatchLevel.standard.threshold) < 1e-6
                     && abs(Double(FaceUnlockRecognitionSettings.defaultMinimumFaceWidth)
                            - FaceUnlockDistanceLevel.standard.minimumFaceWidth) < 1e-6
                     && FaceUnlockRecognitionSettings.matchThresholdKey == DefaultsKey.faceUnlockMatchThreshold
                     && FaceUnlockRecognitionSettings.minimumFaceWidthKey == DefaultsKey.faceUnlockMinimumFaceWidth
                     && FaceUnlockRecognitionSettings.cameraIDKey == DefaultsKey.faceUnlockCameraID
                     && FaceUnlockRecognitionSettings.livenessModeKey == DefaultsKey.faceUnlockLivenessMode
                     && FaceUnlockRecognitionSettings.detectionSecondsKey == DefaultsKey.faceUnlockDetectionSeconds
                     && FaceUnlockRecognitionSettings.livenessEnabledKey == DefaultsKey.faceUnlockLivenessEnabled
                     && FaceUnlockIslandStyle.defaultsKey == DefaultsKey.faceUnlockAnimationStyle,
                     "recognition and the island read the keys Settings writes, with one default each")
        suite.expect(Set(FaceUnlockLivenessLevel.allCases.map(\.rawValue)) == Set(LivenessMode.allCases.map(\.rawValue)),
                     "the liveness levels are recognition's modes")
    }

    // MARK: Session

    private static func session(_ suite: TestSuite) {
        let world = SessionWorld()
        let session = world.session
        var opened: Bool?
        suite.expect(!session.isSessionUnlocked && session.sessionKey == nil, "the session starts locked, with no key")

        world.auth.passes = false
        session.unlockSession(reason: "test") { opened = $0 }
        suite.expect(opened == false && !session.isSessionUnlocked && world.keychain.stored == nil
                     && session.lastError == .authenticationFailed,
                     "a cancelled Touch ID opens nothing and makes no key")

        world.auth.passes = true
        session.unlockSession(reason: "test") { opened = $0 }
        suite.expect(opened == true && session.isSessionUnlocked && world.keychain.stored?.count == 32
                     && world.auth.reasons == ["test", "test"],
                     "Touch ID first, then a 256-bit key is made and kept in the keychain")
        let key = session.sessionKey
        suite.expect(key?.withUnsafeBytes({ Data($0) }) == world.keychain.stored,
                     "the key provider hands recognition the same key while the session is open")

        var saved: Result<Void, FaceUnlockSecurityError>?
        session.savePassword("correct horse") { saved = $0 }
        suite.expect((try? saved?.get()) != nil && session.hasStoredPassword && session.hasPassword,
                     "the password is saved")
        suite.expect(world.file.data.map { $0.range(of: Data("correct horse".utf8)) == nil } == true,
                     "only its sealed form is on disk")

        session.lockSession()
        suite.expect(!session.isSessionUnlocked && session.sessionKey == nil, "locking drops the key from memory")
        session.savePassword("x") { saved = $0 }
        if case .failure(.sessionLocked)? = saved {} else { suite.expect(false, "a locked session saves nothing") }

        // Reopening reads the same key instead of making another.
        let reads = world.keychain.reads
        session.unlockSession(reason: "again") { opened = $0 }
        suite.expect(opened == true && world.keychain.reads == reads + 1
                     && session.sessionKey?.withUnsafeBytes({ Data($0) }) == key?.withUnsafeBytes({ Data($0) }),
                     "the next session reads the stored key")
        session.unlockSession(reason: "open") { opened = $0 }
        suite.expect(opened == true && world.auth.reasons.last == "again", "an open session asks for nothing")

        // The key gone while something is still sealed: an error, never a new key.
        let lost = SessionWorld()
        lost.file.data = Data([1, 2, 3])
        lost.session.unlockSession(reason: "lost") { opened = $0 }
        suite.expect(opened == false && lost.keychain.stored == nil && lost.session.lastError == .sessionKeyMissing,
                     "a missing key with a sealed password left is reported, not replaced")
        let faces = SessionWorld()
        faces.otherSealed = true
        faces.session.unlockSession(reason: "faces") { opened = $0 }
        suite.expect(opened == false && faces.keychain.stored == nil,
                     "a sealed face store also keeps a new key from being made")
        let broken = SessionWorld()
        broken.keychain.stored = Data([1])
        broken.session.unlockSession(reason: "broken") { opened = $0 }
        suite.expect(opened == false && broken.keychain.stored == Data([1]), "a damaged key is not overwritten")

        session.removePassword()
        suite.expect(!session.hasStoredPassword && session.isSessionUnlocked && world.keychain.stored != nil,
                     "removing the password keeps the key and the session")
        session.resetAll()
        suite.expect(!session.isSessionUnlocked && world.keychain.stored == nil && world.file.data == nil,
                     "a reset deletes the key and the password and locks")
    }

    private static func typingGuard(_ suite: TestSuite) {
        let world = SessionWorld()
        world.openWithPassword("pässwörd")
        var typed: Bool?

        world.locked = false
        world.session.typeStoredPassword { typed = $0 }
        suite.expect(typed == false && world.typist.typed.isEmpty && world.session.lastError == .notLocked,
                     "nothing is typed while CGSession says the screen is not locked")

        world.locked = true
        world.typist.canType = false
        world.session.typeStoredPassword { typed = $0 }
        suite.expect(typed == false && world.typist.typed.isEmpty, "nothing is typed without Accessibility")

        world.typist.canType = true
        world.session.lockSession()
        world.session.typeStoredPassword { typed = $0 }
        suite.expect(typed == false && world.typist.typed.isEmpty, "nothing is typed while the session is locked")

        world.openWithPassword("pässwörd")
        world.session.typeStoredPassword { typed = $0 }
        suite.expect(typed == true && world.typist.typed == [Data("pässwörd".utf8)],
                     "locked, session open, Accessibility granted: the exact password is typed")

        // The lock screen goes while the password is read: the second look stops it.
        world.typist.typed = []
        var looks = 0
        world.lockedProvider = { looks += 1; return looks == 1 }
        world.session.typeStoredPassword { typed = $0 }
        suite.expect(typed == false && world.typist.typed.isEmpty && looks == 2,
                     "CGSession is read again just before the first keystroke")
        world.lockedProvider = nil

        world.file.data = Data([9, 9, 9])
        world.session.typeStoredPassword { typed = $0 }
        suite.expect(typed == false && world.typist.typed.isEmpty, "a password that does not open is never typed")

        suite.expect(FaceUnlockScreenLock.isLocked(["CGSSessionScreenIsLocked": true])
                     && !FaceUnlockScreenLock.isLocked(["CGSSessionScreenIsLocked": false])
                     && !FaceUnlockScreenLock.isLocked([:]) && !FaceUnlockScreenLock.isLocked(nil),
                     "the lock state fails closed: unknown is not locked")
        let units = Array("ab😀".utf16)
        suite.expect(FaceUnlockKeystrokes.batches(units, length: 3) == [[units[0], units[1]], [units[2], units[3]]]
                     && FaceUnlockKeystrokes.batches(Array(String(repeating: "x", count: 45).utf16), length: 20)
                        .map(\.count) == [20, 20, 5],
                     "typing goes in short batches that never split a surrogate pair")
    }

    private static func autoLock(_ suite: TestSuite) {
        let start = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let day: TimeInterval = 86_400
        suite.expect(!FaceUnlockAutoLocking.shouldLock(lastActivity: start, now: start + 7 * day - 1, limit: .sevenDays)
                     && FaceUnlockAutoLocking.shouldLock(lastActivity: start, now: start + 7 * day, limit: .sevenDays),
                     "seven days idle locks, a second less does not")
        suite.expect(!FaceUnlockAutoLocking.shouldLock(lastActivity: start, now: start + 20 * day, limit: .thirtyDays)
                     && FaceUnlockAutoLocking.shouldLock(lastActivity: start, now: start + 14 * day, limit: .fourteenDays),
                     "each limit is its own number of days")
        suite.expect(!FaceUnlockAutoLocking.shouldLock(lastActivity: start, now: start + 400 * day, limit: .never)
                     && !FaceUnlockAutoLocking.shouldLock(lastActivity: nil, now: start + 400 * day, limit: .sevenDays),
                     "never does not lock by time, and a locked session has nothing to age")

        let world = SessionWorld()
        world.now = start
        world.openWithPassword("pw")
        world.now = start + 6 * day
        suite.expect(!world.session.lockIfIdle(limit: .sevenDays) && world.session.isSessionUnlocked,
                     "six days idle keeps the session")
        world.session.typeStoredPassword { _ in }
        world.now = start + 12 * day
        suite.expect(!world.session.lockIfIdle(limit: .sevenDays), "an unlock by face counts as use and restarts the count")
        world.now = start + 13 * day
        suite.expect(world.session.lockIfIdle(limit: .sevenDays) && !world.session.isSessionUnlocked,
                     "seven days after the last use the session locks")
    }

    // MARK: Coordinator

    private static func triggerDecisions(_ suite: TestSuite) {
        suite.expect(FaceUnlockCoordinator.trigger(for: .screenLocked) == .onLock
                     && FaceUnlockCoordinator.trigger(for: .wake) == .onWake
                     && FaceUnlockCoordinator.trigger(for: .screenUnlocked) == nil
                     && FaceUnlockCoordinator.trigger(for: .willSleep) == nil,
                     "lock and wake stand for their triggers; unlock and sleep for none")

        // An unselected trigger arms for a hover but does not scan.
        let world = CoordinatorWorld()
        world.preferences.triggers = [.onWake, .onHover]
        world.lock()
        suite.expect(world.presence.state == .armed && world.recognizer.scans.isEmpty,
                     "with On lock off, a lock arms the island without scanning")
        world.presence.onActivate?()
        suite.expect(world.presence.state == .scanning && world.recognizer.scans.count == 1,
                     "hovering the armed island starts the scan")

        let noHover = CoordinatorWorld()
        noHover.preferences.triggers = [.onWake]
        noHover.lock()
        noHover.presence.onActivate?()
        suite.expect(noHover.presence.state == .armed && noHover.recognizer.scans.isEmpty,
                     "with On hover off, hovering does nothing")

        // Headless: nothing to hover, so an unselected trigger does nothing at all.
        let headless = CoordinatorWorld()
        headless.preferences.animationStyle = .none
        headless.preferences.triggers = [.onWake]
        headless.lock()
        suite.expect(headless.presence.state == .hidden && headless.recognizer.scans.isEmpty,
                     "without the island, an unselected trigger starts nothing")
        headless.event(.wake)
        suite.expect(headless.presence.state == .hidden && headless.recognizer.scans.count == 1,
                     "without the island, a selected trigger scans with nothing shown")

        let off = CoordinatorWorld()
        off.preferences.isEnabled = false
        off.lock()
        suite.expect(off.presence.state == .hidden && off.recognizer.scans.isEmpty, "switched off, nothing happens")

        let notSetUp = CoordinatorWorld()
        notSetUp.credentials.hasStoredPassword = false
        notSetUp.lock()
        suite.expect(notSetUp.presence.state == .hidden && notSetUp.recognizer.scans.isEmpty,
                     "without a stored password, nothing shows")
        let noFace = CoordinatorWorld()
        noFace.recognizer.hasEnrolledFace = false
        noFace.lock()
        suite.expect(noFace.presence.state == .hidden && noFace.recognizer.scans.isEmpty,
                     "without an enrolled face, nothing shows")

        let touchID = CoordinatorWorld()
        touchID.credentials.isSessionUnlocked = false
        touchID.lock()
        suite.expect(touchID.presence.state == .needsTouchID && touchID.recognizer.scans.isEmpty,
                     "a locked session shows that Touch ID is needed and never scans")

        // The notification is only a prompt: CGSession decides.
        let spoofed = CoordinatorWorld()
        spoofed.locked = false
        spoofed.event(.screenLocked)
        suite.expect(spoofed.presence.state == .hidden && spoofed.recognizer.scans.isEmpty,
                     "a lock notification without a locked session arms nothing")
    }

    private static func coordinator(_ suite: TestSuite) {
        let world = CoordinatorWorld()
        world.locked = true
        world.coordinator.handle(.screenLocked)
        world.scheduler.advance(by: FaceUnlockCoordinator.Timing.settle - 0.01)
        suite.expect(world.presence.state == .hidden, "nothing happens before the settle delay")
        world.scheduler.advance(by: 0.01 + FaceUnlockCoordinator.Timing.arm)
        suite.expect(world.presence.state == .scanning && world.recognizer.scans.count == 1
                     && world.recognizer.scans.first?.timeout == 5,
                     "after the settle and arm delays the island scans for the chosen duration")
        suite.expect(world.presence.onActivate != nil, "the island can call back to retry")

        world.recognizer.finish(.matched(name: "Faiz"))
        suite.expect(world.credentials.typeCalls == 1 && world.presence.state == .success,
                     "a match shows success as it asks the credentials to type, so the unlock finds it playing")
        world.credentials.finishTyping(true)
        suite.expect(world.presence.state == .success, "typed: the island keeps the success")
        world.presence.onActivate?()
        suite.expect(world.recognizer.scans.count == 1, "hovering a success starts nothing")

        world.unlock()
        suite.expect(world.presence.state == .hidden && world.presence.onActivate == nil, "the unlock hides the island")

        // Wrong face: failure, then rest; hover retries.
        let wrong = CoordinatorWorld()
        wrong.lock()
        wrong.recognizer.finish(.failed(.wrongFace))
        suite.expect(wrong.presence.state == .failure(.wrongFace) && wrong.credentials.typeCalls == 0,
                     "a wrong face shows the failure and types nothing")
        wrong.scheduler.advance(by: FaceUnlockCoordinator.Timing.failureHold)
        suite.expect(wrong.presence.state == .armed, "after the hold the island rests, armed")
        wrong.recognizer.finish(.failed(.spoofSuspected))
        suite.expect(wrong.presence.state == .armed, "a completion nobody waits for changes nothing")
        wrong.presence.onActivate?()
        suite.expect(wrong.presence.state == .scanning && wrong.recognizer.scans.count == 2,
                     "hovering the rested island scans again")
        wrong.recognizer.finish(.failed(.spoofSuspected))
        wrong.presence.onActivate?()
        suite.expect(wrong.recognizer.scans.count == 3, "hovering a held failure retries at once")

        let noRetry = CoordinatorWorld()
        noRetry.preferences.retryOnHover = false
        noRetry.lock()
        noRetry.recognizer.finish(.failed(.timedOut))
        noRetry.presence.onActivate?()
        suite.expect(noRetry.recognizer.scans.count == 1 && noRetry.presence.state == .failure(.timedOut),
                     "with Retry on hover off, hovering a failure does nothing")

        // Typing refused: no success.
        let refused = CoordinatorWorld()
        refused.lock()
        refused.recognizer.finish(.matched(name: "Faiz"))
        refused.credentials.finishTyping(false)
        suite.expect(refused.presence.state == .failure(.noPassword), "a match that could not type is a failure")

        // Typed, but the Mac stays locked: the stored password is out of date.
        let stale = CoordinatorWorld()
        stale.lock()
        stale.recognizer.finish(.matched(name: "Faiz"))
        stale.credentials.finishTyping(true)
        stale.scheduler.advance(by: FaceUnlockCoordinator.Timing.unlockGrace - 0.1)
        suite.expect(stale.presence.state == .success, "the unlock gets its moment")
        stale.scheduler.advance(by: 0.1)
        suite.expect(stale.presence.state == .failure(.noPassword), "still locked after it: a failure")
        let unlocks = CoordinatorWorld()
        unlocks.lock()
        unlocks.recognizer.finish(.matched(name: "Faiz"))
        unlocks.credentials.finishTyping(true)
        unlocks.unlock()
        unlocks.scheduler.advance(by: FaceUnlockCoordinator.Timing.unlockGrace)
        suite.expect(unlocks.presence.state == .hidden, "an unlock in time clears the watch")

        // Unlocked by hand mid-scan: the scan is cancelled and nothing typed.
        let byHand = CoordinatorWorld()
        byHand.lock()
        byHand.unlock()
        suite.expect(byHand.recognizer.cancels == 1 && byHand.presence.state == .hidden, "an unlock cancels the scan")
        byHand.recognizer.finish(.matched(name: "Faiz"))
        suite.expect(byHand.credentials.typeCalls == 0, "a late match after an unlock types nothing")

        // Sleep: the lock that lands just before it waits for the wake.
        let lid = CoordinatorWorld()
        lid.locked = true
        lid.coordinator.handle(.willSleep)
        lid.coordinator.handle(.screenLocked)
        lid.settle()
        suite.expect(lid.recognizer.scans.isEmpty && lid.presence.state == .hidden, "nothing scans while asleep")
        lid.event(.wake)
        suite.expect(lid.recognizer.scans.count == 1 && lid.presence.state == .scanning, "the wake scans")
        lid.coordinator.handle(.willSleep)
        suite.expect(lid.recognizer.cancels == 1 && lid.presence.state == .armed, "sleep stops a running scan")
        lid.recognizer.finish(.failed(.cameraUnavailable))
        suite.expect(lid.presence.state == .armed, "the stopped scan's completion is ignored")

        // One lid-open sends several wakes: one arm.
        let burst = CoordinatorWorld()
        burst.event(.wake)
        burst.recognizer.finish(.failed(.wrongFace))
        burst.clock += 1
        burst.event(.wake)
        suite.expect(burst.recognizer.scans.count == 1, "a second wake within 2 s is the same wake")
        burst.clock += 5
        burst.event(.wake)
        suite.expect(burst.recognizer.scans.count == 2, "a later wake arms again")

        // Switched off while locked.
        let switched = CoordinatorWorld()
        switched.lock()
        switched.preferences.isEnabled = false
        switched.coordinator.preferencesChanged()
        suite.expect(switched.presence.state == .hidden && switched.recognizer.cancels == 1,
                     "turning it off disarms at once")
    }

    private static func retries(_ suite: TestSuite) {
        let world = CoordinatorWorld()
        world.preferences.autoRetryOnce = true
        world.lock()
        world.recognizer.finish(.failed(.wrongFace))
        world.scheduler.advance(by: FaceUnlockCoordinator.Timing.failureHold)
        suite.expect(world.recognizer.scans.count == 2 && world.presence.state == .scanning,
                     "with auto-retry, one more scan follows the failure's hold")
        world.recognizer.finish(.failed(.wrongFace))
        world.scheduler.advance(by: FaceUnlockCoordinator.Timing.failureHold * 2)
        suite.expect(world.recognizer.scans.count == 2 && world.presence.state == .armed, "only once per lock")

        let headless = CoordinatorWorld()
        headless.preferences.autoRetryOnce = true
        headless.preferences.animationStyle = .none
        headless.lock()
        headless.recognizer.finish(.failed(.timedOut))
        headless.scheduler.advance(by: FaceUnlockCoordinator.Timing.headlessRetry)
        suite.expect(headless.recognizer.scans.count == 2 && headless.presence.state == .hidden,
                     "headless, the retry follows a second later with nothing shown")

        let unlocked = CoordinatorWorld()
        unlocked.preferences.autoRetryOnce = true
        unlocked.lock()
        unlocked.recognizer.finish(.failed(.wrongFace))
        unlocked.locked = false
        unlocked.scheduler.advance(by: FaceUnlockCoordinator.Timing.failureHold)
        suite.expect(unlocked.recognizer.scans.count == 1, "no retry once the Mac is unlocked")
    }

    private static func spaceKey(_ suite: TestSuite) {
        let world = CoordinatorWorld()
        world.preferences.triggers = [.onSpace]
        world.lock()
        suite.expect(world.spaceKeys.isListening, "with On space on, the HID listener runs while locked")
        suite.expect(world.presence.state == .armed && world.recognizer.scans.isEmpty,
                     "a lock arms but waits for Space")
        world.spaceKeys.press()
        suite.expect(world.recognizer.scans.count == 1, "Space starts the scan")
        world.spaceKeys.press()
        suite.expect(world.recognizer.scans.count == 1, "Space again while scanning is swallowed")
        world.unlock()
        suite.expect(!world.spaceKeys.isListening, "the listener stops on unlock")

        let noAccess = CoordinatorWorld()
        noAccess.preferences.triggers = [.onSpace, .onLock]
        noAccess.spaceKeys.hasAccess = false
        noAccess.lock()
        suite.expect(!noAccess.spaceKeys.isListening && noAccess.spaceKeys.starts == 0,
                     "without Input Monitoring it does not listen, and never asks")

        let unselected = CoordinatorWorld()
        unselected.lock()
        suite.expect(!unselected.spaceKeys.isListening, "with On space off, nothing listens")
    }

    /// The coordinator with the real session behind it: the guard holds end to end.
    private static func endToEnd(_ suite: TestSuite) {
        let security = SessionWorld()
        security.openWithPassword("letmein")
        let world = CoordinatorWorld()
        world.credentialsProvider = { security.session }
        world.lock()
        security.locked = true
        world.recognizer.finish(.matched(name: "Faiz"))
        suite.expect(security.typist.typed == [Data("letmein".utf8)] && world.presence.state == .success,
                     "a match on a locked screen types the password once, then success")

        let early = SessionWorld()
        early.openWithPassword("letmein")
        let unlockedWorld = CoordinatorWorld()
        unlockedWorld.credentialsProvider = { early.session }
        unlockedWorld.lock()
        early.locked = false // CGSession: unlocked, though the coordinator still thinks locked
        unlockedWorld.recognizer.finish(.matched(name: "Faiz"))
        suite.expect(early.typist.typed.isEmpty && unlockedWorld.presence.state != .success,
                     "if the session server says unlocked, the credentials refuse to type")

        let wrong = SessionWorld()
        wrong.openWithPassword("letmein")
        let wrongWorld = CoordinatorWorld()
        wrongWorld.credentialsProvider = { wrong.session }
        wrongWorld.lock()
        wrongWorld.recognizer.finish(.failed(.wrongFace))
        suite.expect(wrong.typist.typed.isEmpty, "no match, nothing typed")
    }

    // MARK: Onboarding

    private static func onboarding(_ suite: TestSuite) {
        let domain = "com.vorssaint.tests.face-unlock-onboarding"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let security = SessionWorld()
        let driver = FakeEnrollment()
        let library = FakeFaces()
        let scheduler = ManualScheduler()
        var accessibility = false
        var camera = FaceUnlockOnboardingFlow.CameraAccess.notDetermined
        func flow(_ mode: FaceUnlockOnboardingFlow.Mode, prefill: String = "Faiz") -> FaceUnlockOnboardingFlow {
            FaceUnlockOnboardingFlow(mode: mode, prefillName: prefill, .init(
                session: security.session, faces: { library }, makeEnrollment: { driver.madeFor.append($0); return driver }, defaults: defaults,
                accessibility: { accessibility }, camera: { camera }, requestAccessibility: { accessibility = true },
                requestCamera: { camera = .granted }, cameras: { [.init(id: "cam-1", name: "FaceTime HD")] },
                scheduler: scheduler, touchIDReason: "set up"))
        }

        let first = flow(.firstRun)
        suite.expect(first.step == .intro, "first run starts at the intro")
        first.advance()
        suite.expect(first.step == .permissions && !first.canAdvance, "permissions hold the flow until both are granted")
        first.advance()
        suite.expect(first.step == .permissions, "Next does nothing without them")
        first.grantAccessibility()
        first.grantCamera()
        first.advance()
        suite.expect(first.step == .securityNotice, "then the security notice")
        first.advance()
        suite.expect(first.step == .preSetup && defaults.bool(forKey: DefaultsKey.faceUnlockNoticeAccepted),
                     "\"I Understand\" is remembered")
        first.advance()
        suite.expect(first.step == .selectCamera && first.cameras.map(\.id) == ["cam-1"], "the cameras are listed")
        first.selectCamera("cam-1")
        suite.expect(defaults.string(forKey: DefaultsKey.faceUnlockCameraID) == "cam-1", "the pick is what recognition reads")
        first.selectCamera(nil)
        suite.expect(defaults.object(forKey: DefaultsKey.faceUnlockCameraID) == nil, "the system default stores nothing")
        first.advance()
        suite.expect(first.step == .enroll && driver.starts == 1, "the sweep starts the camera")
        first.back()
        suite.expect(first.step == .selectCamera && driver.stops == 1 && driver.resets == 1,
                     "leaving the sweep stops the camera and discards what it caught")
        first.advance()
        driver.report(.init(pose: .left, captured: [.center], fraction: 0.2))
        suite.expect(first.progress.pose == .left && first.step == .enroll, "progress shows as it comes")
        driver.report(.init(pose: nil, captured: Set(FaceUnlockEnrollmentPose.allCases), fraction: 1, isComplete: true))
        suite.expect(first.showsCaptured && first.step == .enroll, "the sweep done, the checkmark shows")
        scheduler.advance(by: FaceUnlockOnboardingFlow.Timing.captured)
        suite.expect(first.step == .name && driver.stops == 2 && first.pendingName == "Faiz",
                     "then the name, pre-filled, with the camera off")
        first.pendingName = "  "
        suite.expect(!first.canAdvance, "a blank name cannot continue")
        first.pendingName = "Faiz"
        first.advance()
        suite.expect(first.step == .password && driver.commits.isEmpty,
                     "first run saves nothing at the name: the session is not open yet")

        security.auth.passes = false
        first.finish(password: "pw")
        suite.expect(first.step == .password && first.problem == .security(.authenticationFailed) && driver.commits.isEmpty
                     && !first.isSaving,
                     "a cancelled Touch ID stays on the password, nothing saved")
        security.auth.passes = true
        library.taken = ["faiz"]
        first.finish(password: "pw")
        suite.expect(first.step == .name && first.problem == .nameTaken("Faiz") && driver.commits.isEmpty,
                     "a name already enrolled sends the flow back to the name once the faces can be read")
        library.taken = []
        first.advance()
        first.finish(password: "pw")
        suite.expect(driver.commits.count == 1 && driver.commits.first?.name == "Faiz"
                     && security.session.hasStoredPassword && first.step == .complete,
                     "Touch ID opens the session, the face is sealed, then the password")
        suite.expect(defaults.bool(forKey: DefaultsKey.faceUnlockEnabled), "finishing setup turns face unlock on")
        scheduler.advance(by: FaceUnlockOnboardingFlow.Timing.complete)
        suite.expect(first.isFinished, "the window closes itself after a moment")

        // Add a face: starts at the sweep, saves at the name.
        let addDriver = FakeEnrollment()
        func addFlow() -> FaceUnlockOnboardingFlow {
            FaceUnlockOnboardingFlow(mode: .addFace(replacing: nil), prefillName: "", .init(
                session: security.session, faces: { library }, makeEnrollment: { addDriver.madeFor.append($0); return addDriver }, defaults: defaults,
                accessibility: { true }, camera: { .granted }, requestAccessibility: {}, requestCamera: {},
                cameras: { [] }, scheduler: scheduler, touchIDReason: "add"))
        }
        let add = addFlow()
        suite.expect(add.step == .enroll && addDriver.starts == 1, "adding a face starts at the sweep")
        addDriver.report(.init(pose: nil, fraction: 1, isComplete: true))
        scheduler.advance(by: FaceUnlockOnboardingFlow.Timing.captured)
        add.pendingName = "Glasses"
        add.advance()
        suite.expect(addDriver.commits.map(\.name) == ["Glasses"] && add.step == .complete && library.reloads > 0,
                     "and saves at the name")
        let replaced = UUID()
        let recapture = FaceUnlockOnboardingFlow(mode: .addFace(replacing: replaced), prefillName: "Faiz", .init(
            session: security.session, faces: { library }, makeEnrollment: { addDriver.madeFor.append($0); return addDriver },
            defaults: defaults, accessibility: { true }, camera: { .granted }, requestAccessibility: {},
            requestCamera: {}, cameras: { [] }, scheduler: scheduler, touchIDReason: "recapture"))
        suite.expect(addDriver.madeFor.last == .some(replaced) && recapture.pendingName == "Faiz",
                     "a recapture makes its enrollment for the face it replaces, its name kept")
        recapture.cancel()
        let cancelled = addFlow()
        cancelled.back()
        suite.expect(cancelled.isFinished && addDriver.stops >= 1, "Back on the sweep cancels adding a face")

        // Change password.
        let change = FaceUnlockOnboardingFlow(mode: .password, prefillName: "", .init(
            session: security.session, faces: { library }, makeEnrollment: { _ in nil }, defaults: defaults,
            accessibility: { true }, camera: { .granted }, requestAccessibility: {}, requestCamera: {},
            cameras: { [] }, scheduler: scheduler, touchIDReason: "pw"))
        suite.expect(change.step == .password, "changing the password is the password step alone")
        change.finish(password: "")
        suite.expect(change.problem == .security(.emptyPassword), "an empty password is refused")
        change.finish(password: "new one")
        suite.expect(change.step == .complete && security.typedAfterUnlock("new one"), "the new password is the one typed")

        let missing = FaceUnlockOnboardingFlow(mode: .addFace(replacing: nil), prefillName: "", .init(
            session: security.session, faces: { nil }, makeEnrollment: { _ in nil }, defaults: defaults,
            accessibility: { true }, camera: { .granted }, requestAccessibility: {}, requestCamera: {},
            cameras: { [] }, scheduler: scheduler, touchIDReason: "x"))
        suite.expect(missing.problem == .recognitionUnavailable, "without recognition the sweep says so")
    }

    private static func strings(_ suite: TestSuite) {
        let text = ZenithStrings.faceUnlock(.de)
        suite.expect(text.all.count > 150 && text.all.allSatisfy { !$0.isEmpty }, "every face unlock string has text")
        suite.expect(text.noteSecurity.contains("not as secure as Touch ID") && text.noteVideo.contains("video")
                     && text.noteTyping.contains("types your login password") && text.noteStorage.contains("AES-GCM"),
                     "the notes keep Glance's warnings and say how the password is kept")
        suite.expect(text.guidance(.init(pose: .left)) == text.turnLeft
                     && text.guidance(.init(pose: .left, hint: .tooFar)) == text.moveCloser
                     && text.guidance(.init(pose: .top, hint: .tooFarTurned(.bottomRight))) == "Too far toward the bottom right"
                     && text.guidance(.init(pose: nil, isComplete: true)) == text.captured,
                     "the sweep's guidance follows the pose and the hints")
        let aliases = ZenithSettingsSearch.pageAliases[.page(.faceUnlock)] ?? []
        suite.expect(["face id", "buka pakai wajah", "wajah"].allSatisfy(aliases.contains),
                     "Settings search finds the page in English and Indonesian")
    }
}

// MARK: - Fakes

private final class SessionWorld {
    final class Keychain: FaceUnlockKeyStore {
        var stored: Data?
        var reads = 0
        func keyExists() -> Bool { stored != nil }
        func readKey() throws -> Data {
            reads += 1
            guard let stored else { throw FaceUnlockSecurityError.sessionKeyMissing }
            return stored
        }
        func saveKey(_ data: Data) throws { stored = data }
        func deleteKey() throws { stored = nil }
    }

    final class File: FaceUnlockBlobStore {
        var data: Data?
        func exists() -> Bool { data != nil }
        func read() -> Data? { data }
        func write(_ data: Data) -> Bool { self.data = data; return true }
        func delete() { data = nil }
    }

    final class Auth: FaceUnlockAuthenticating {
        var passes = true
        var reasons: [String] = []
        func authenticate(reason: String, completion: @escaping (Bool) -> Void) {
            reasons.append(reason)
            completion(passes)
        }
    }

    final class Typist: FaceUnlockPasswordTyping {
        var canType = true
        var typed: [Data] = []
        func type(_ password: Data) throws { typed.append(Data(password)) }
    }

    let keychain = Keychain()
    let file = File()
    let auth = Auth()
    let typist = Typist()
    var locked = true
    var lockedProvider: (() -> Bool)?
    var otherSealed = false
    var now = Date(timeIntervalSinceReferenceDate: 0)
    lazy var session = FaceUnlockSession(.init(
        keychain: keychain, passwordFile: file, authenticator: auth, typist: typist,
        isScreenLocked: { [unowned self] in self.lockedProvider?() ?? self.locked },
        hasOtherSealedData: { [unowned self] in self.otherSealed },
        now: { [unowned self] in self.now },
        background: { $0() }, main: { $0() }))

    func openWithPassword(_ password: String) {
        session.unlockSession(reason: "test") { _ in }
        session.savePassword(password) { _ in }
    }

    /// Types the stored password on a locked screen and says whether it was `expected`.
    func typedAfterUnlock(_ expected: String) -> Bool {
        let wasLocked = locked
        locked = true
        defer { locked = wasLocked }
        typist.typed = []
        session.typeStoredPassword { _ in }
        return typist.typed == [Data(expected.utf8)]
    }
}

private final class ManualScheduler: FaceUnlockScheduling {
    private final class Item: FaceUnlockScheduled {
        let due: TimeInterval
        let order: Int
        let work: () -> Void
        var cancelled = false
        init(due: TimeInterval, order: Int, work: @escaping () -> Void) {
            self.due = due
            self.order = order
            self.work = work
        }
        func cancel() { cancelled = true }
    }

    private var items: [Item] = []
    private var now: TimeInterval = 0
    private var counter = 0

    func after(_ seconds: TimeInterval, _ work: @escaping () -> Void) -> FaceUnlockScheduled {
        counter += 1
        let item = Item(due: now + seconds, order: counter, work: work)
        items.append(item)
        return item
    }

    /// Runs what falls due, in time then insertion order, including work scheduled meanwhile.
    func advance(by seconds: TimeInterval) {
        let end = now + seconds + 1e-9
        while let next = items.filter({ !$0.cancelled && $0.due <= end })
            .min(by: { ($0.due, $0.order) < ($1.due, $1.order) }) {
            items.removeAll { $0 === next }
            now = max(now, next.due)
            next.work()
        }
        now = end
        items.removeAll { $0.cancelled }
    }
}

private final class FakeRecognizer: FaceUnlockRecognizer {
    var hasEnrolledFace = true
    var scans: [(timeout: TimeInterval, completion: (FaceUnlockScanOutcome) -> Void)] = []
    var cancels = 0

    func scan(timeout: TimeInterval, completion: @escaping (FaceUnlockScanOutcome) -> Void) {
        scans.append((timeout, completion))
    }

    func cancelScan() {
        cancels += 1
    }

    /// Completes the latest scan (as the contract says, a cancelled one still completes once).
    func finish(_ outcome: FaceUnlockScanOutcome) {
        scans.last?.completion(outcome)
    }
}

private final class FakeCredentials: FaceUnlockCredentials {
    var isSessionUnlocked = true
    var hasStoredPassword = true
    var typeCalls = 0
    private var typing: ((Bool) -> Void)?
    func unlockSession(reason: String, completion: @escaping (Bool) -> Void) { completion(true) }
    func lockSession() { isSessionUnlocked = false }
    func typeStoredPassword(completion: @escaping (Bool) -> Void) {
        typeCalls += 1
        typing = completion
    }
    func finishTyping(_ typed: Bool) {
        typing?(typed)
        typing = nil
    }
}

private final class FakeSpaceKeys: FaceUnlockSpaceKeyListening {
    var hasAccess = true
    var starts = 0
    private var onPress: (() -> Void)?
    var isListening: Bool { onPress != nil }
    func start(_ onPress: @escaping () -> Void) {
        if self.onPress == nil { starts += 1 }
        self.onPress = onPress
    }
    func stop() { onPress = nil }
    func press() { onPress?() }
}

private final class CoordinatorWorld {
    var preferences = FaceUnlockPreferences(
        isEnabled: true, triggers: FaceUnlockTriggers.defaultSet, autoLock: .sevenDays, retryOnHover: true,
        autoRetryOnce: false, detectionSeconds: 5, animationStyle: .original)
    var locked = true
    var clock: TimeInterval = 100
    let presence = FaceUnlockPresence()
    let scheduler = ManualScheduler()
    let recognizer = FakeRecognizer()
    let credentials = FakeCredentials()
    let spaceKeys = FakeSpaceKeys()
    var credentialsProvider: (() -> FaceUnlockCredentials?)?
    lazy var coordinator = FaceUnlockCoordinator(.init(
        preferences: { [unowned self] in self.preferences },
        isScreenLocked: { [unowned self] in self.locked },
        recognizer: { [unowned self] in self.recognizer },
        credentials: { [unowned self] in self.credentialsProvider?() ?? self.credentials },
        presence: presence, scheduler: scheduler, spaceKeys: spaceKeys,
        uptime: { [unowned self] in self.clock }))

    func settle() {
        scheduler.advance(by: FaceUnlockCoordinator.Timing.settle + FaceUnlockCoordinator.Timing.arm)
    }

    func event(_ event: FaceUnlockCoordinator.Event) {
        coordinator.handle(event)
        settle()
    }

    func lock() {
        locked = true
        event(.screenLocked)
    }

    func unlock() {
        locked = false
        event(.screenUnlocked)
    }
}

private final class FakeEnrollment: FaceUnlockEnrollmentDriver {
    var progress = FaceUnlockEnrollmentProgress()
    var onProgress: ((FaceUnlockEnrollmentProgress) -> Void)?
    var starts = 0
    var stops = 0
    var resets = 0
    var commits: [(name: String, replacing: UUID?)] = []
    var madeFor: [UUID?] = []
    func start() { starts += 1 }
    func stop() { stops += 1 }
    func reset() {
        resets += 1
        progress = FaceUnlockEnrollmentProgress()
    }
    func cameraPreview() -> AnyView { AnyView(EmptyView()) }
    func commit(name: String) throws { commits.append((name, madeFor.last ?? nil)) }
    func report(_ next: FaceUnlockEnrollmentProgress) {
        progress = next
        onProgress?(next)
    }
}

private final class FakeFaces: FaceUnlockFaceLibrary {
    var faces: [FaceUnlockFace]? = []
    var hasSealedData = false
    var taken: Set<String> = []
    var reloads = 0
    func reload() { reloads += 1 }
    func nameIsTaken(_ name: String, excluding: UUID?) -> Bool { taken.contains(name.lowercased()) }
    func rename(_ id: UUID, to name: String) throws {}
    func setEnabled(_ id: UUID, _ isEnabled: Bool) throws {}
    func delete(_ id: UUID) throws {}
    func deleteAll() {}
}
