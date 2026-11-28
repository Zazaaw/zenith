// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: App Lock's decisions. Which apps it may lock, when an app
/// coming to the front is covered, how an unlock ends (time out of the front,
/// quitting, the Mac locking or sleeping, Zenith starting again), the shared
/// unlock, the shield's answer to another app, the methods, the preferences
/// and the words. No workspace, no window, no prompt.
enum AppLockTests {
    static func run(_ suite: TestSuite) {
        exemptions(suite)
        list(suite)
        locking(suite)
        expiry(suite)
        endings(suite)
        sharedUnlock(suite)
        shield(suite)
        hiding(suite)
        methods(suite)
        preferences(suite)
        quiet(suite)
        words(suite)
    }

    private static let notes = "com.apple.Notes"
    private static let messages = "com.apple.MobileSMS"
    private static let safari = "com.apple.Safari"
    private static let zenith = "id.satuvisual.zenith.dev"
    private static let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private static func at(_ minutes: Double) -> Date { start.addingTimeInterval(minutes * 60) }

    private static func prefs(_ apps: [String] = [notes, messages], relock: AppLockRelock = .fiveMinutes,
                              scope: AppLockScope = .eachApp, lockWithMac: Bool = true,
                              hide: Bool = false, enabled: Bool = true) -> AppLockPreferences {
        AppLockPreferences(enabled: enabled, apps: apps, relock: relock, scope: scope,
                           lockWithMac: lockWithMac, hideWhenInactive: hide)
    }

    // MARK: Exemptions

    private static func exemptions(_ suite: TestSuite) {
        for id in ["id.satuvisual.zenith", "id.satuvisual.zenith.dev", "id.satuvisual.zenith.fan-control",
                   "com.vorssaint.utils", "com.apple.systempreferences", "com.apple.Settings", "com.apple.finder",
                   "com.apple.loginwindow", "com.apple.SecurityAgent", "com.apple.coreautha", "COM.APPLE.FINDER"] {
            suite.expect(AppLockExemptions.isExempt(id), "\(id) is never locked")
        }
        for id in [notes, messages, safari, "id.satuvisual.zenithx", "com.apple.finderish", "id.satuvisual"] {
            suite.expect(!AppLockExemptions.isExempt(id), "\(id) can be locked")
        }
        var sessions = AppLockSessions()
        let everything = prefs([notes, zenith, "com.apple.systempreferences"])
        suite.expect(!everything.isLocked(zenith) && !everything.isLocked("com.apple.systempreferences"),
                     "an exempt app in the stored list still never locks")
        suite.expect(sessions.activated(zenith, isRegular: true, at: at(0), everything) == .ignore
                        && sessions.activated("com.apple.systempreferences", isRegular: true, at: at(0), everything) == .ignore,
                     "Zenith and System Settings come to the front untouched")
    }

    // MARK: The list

    private static func list(_ suite: TestSuite) {
        suite.expect(AppLockApps.cleaned([notes, " \(messages) ", notes, "", "COM.APPLE.NOTES", "com.apple.finder"])
                        == [notes, messages],
                     "the list keeps one entry per app, trimmed, in the order added, without exempt apps")
        let added = AppLockApps.adding([safari, "com.apple.finder", notes], to: [notes])
        suite.expect(added.apps == [notes, safari] && added.refused == ["com.apple.finder"],
                     "adding skips what is there and refuses an exempt app, saying which")
        suite.expect(AppLockApps.removing("COM.apple.notes", from: [notes, safari]) == [safari],
                     "removing matches the identifier whatever its case")
    }

    // MARK: Locking

    private static func locking(_ suite: TestSuite) {
        let preferences = prefs()
        var sessions = AppLockSessions()
        suite.expect(sessions.activated(notes, isRegular: true, at: at(0), preferences) == .lock,
                     "a locked app coming to the front is covered")
        suite.expect(sessions.activated(safari, isRegular: true, at: at(0), preferences) == .allow,
                     "an app that is not locked comes forward")
        suite.expect(sessions.activated(nil, isRegular: true, at: at(0), preferences) == .ignore
                        && sessions.activated("com.apple.LocalAuthentication.UIAgent", isRegular: false, at: at(0), preferences) == .ignore,
                     "an app without an identifier, an agent or a prompt changes nothing")
        suite.expect(sessions.activated(notes, isRegular: false, at: at(0), preferences) == .ignore,
                     "only an app the person switches to is judged")
        suite.expect(sessions.activated(notes, isRegular: true, at: at(0), prefs(enabled: false)) == .allow
                        && sessions.activated(notes, isRegular: true, at: at(0), prefs([])) == .allow,
                     "off, or with an empty list, nothing is covered")
        suite.expect(!prefs(enabled: false).isWatching && !prefs([]).isWatching && prefs().isWatching,
                     "App Lock watches the workspace only while on with an app to lock")

        sessions.unlocked(notes, at: at(0), preferences)
        suite.expect(sessions.activated(notes, isRegular: true, at: at(0.1), preferences) == .allow,
                     "once unlocked the app comes forward")
        suite.expect(sessions.activated(messages, isRegular: true, at: at(0.2), preferences) == .lock,
                     "each app on its own: another locked app still asks")
    }

    // MARK: Time out of the front

    private static func expiry(_ suite: TestSuite) {
        let preferences = prefs()
        var sessions = AppLockSessions()
        _ = sessions.activated(notes, isRegular: true, at: at(0), preferences)
        sessions.unlocked(notes, at: at(0), preferences)
        _ = sessions.activated(notes, isRegular: true, at: at(0), preferences)
        suite.expect(sessions.isUnlocked(notes, at: at(120), preferences),
                     "an unlocked app kept in front never times out")
        _ = sessions.activated(safari, isRegular: true, at: at(10), preferences)
        suite.expect(sessions.activated(notes, isRegular: true, at: at(14.9), preferences) == .allow,
                     "back within five minutes of leaving the front, it opens")
        _ = sessions.activated(safari, isRegular: true, at: at(20), preferences)
        suite.expect(sessions.activated(notes, isRegular: true, at: at(25), preferences) == .lock,
                     "five minutes out of the front, it asks again")
        suite.expect(sessions.sessions[notes] == nil, "an unlock that ran out is gone, not revived later")

        for (relock, minutes) in [(AppLockRelock.oneMinute, 1.0), (.fifteenMinutes, 15), (.thirtyMinutes, 30)] {
            let timed = prefs(relock: relock)
            var each = AppLockSessions()
            _ = each.activated(notes, isRegular: true, at: at(0), timed)
            each.unlocked(notes, at: at(0), timed)
            _ = each.activated(notes, isRegular: true, at: at(0), timed)
            _ = each.activated(safari, isRegular: true, at: at(1), timed)
            suite.expect(each.isUnlocked(notes, at: at(1 + minutes - 0.01), timed)
                            && !each.isUnlocked(notes, at: at(1 + minutes), timed),
                         "\(Int(minutes)) minutes out of the front is the limit")
        }

        let untilQuit = prefs(relock: .untilQuit)
        var forever = AppLockSessions()
        _ = forever.activated(notes, isRegular: true, at: at(0), untilQuit)
        forever.unlocked(notes, at: at(0), untilQuit)
        _ = forever.activated(safari, isRegular: true, at: at(1), untilQuit)
        suite.expect(forever.activated(notes, isRegular: true, at: at(60 * 24), untilQuit) == .allow,
                     "until it quits: time alone never locks it")
        suite.expect(AppLockRelock.untilQuit.interval == nil && AppLockRelock.fifteenMinutes.interval == 900,
                     "the choices are minutes, and none for until it quits")

        // The shield's own window and the prompt do not count as leaving.
        var shielded = AppLockSessions()
        _ = shielded.activated(notes, isRegular: true, at: at(0), preferences)
        shielded.unlocked(notes, at: at(0), preferences)
        _ = shielded.activated(notes, isRegular: true, at: at(0), preferences)
        _ = shielded.activated("com.apple.coreautha", isRegular: false, at: at(1), preferences)
        suite.expect(shielded.isUnlocked(notes, at: at(30), preferences),
                     "an agent coming forward does not start the clock")
    }

    // MARK: Quitting, the Mac, Zenith

    private static func endings(_ suite: TestSuite) {
        let preferences = prefs(relock: .untilQuit)
        func unlockedNotes() -> AppLockSessions {
            var sessions = AppLockSessions()
            _ = sessions.activated(notes, isRegular: true, at: at(0), preferences)
            sessions.unlocked(notes, at: at(0), preferences)
            _ = sessions.activated(notes, isRegular: true, at: at(0), preferences)
            return sessions
        }
        var quit = unlockedNotes()
        quit.terminated(notes, stillRunning: [safari], preferences)
        suite.expect(quit.activated(notes, isRegular: true, at: at(1), preferences) == .lock,
                     "quitting the app ends its unlock")
        suite.expect(quit.frontmost == notes, "the relaunched app is in front again")

        var locked = unlockedNotes()
        locked.macLocked(preferences)
        suite.expect(locked.activated(notes, isRegular: true, at: at(1), preferences) == .lock,
                     "the Mac locking, sleeping or starting its screen saver ends every unlock, even the one in front")

        var kept = unlockedNotes()
        kept.macLocked(prefs(relock: .untilQuit, lockWithMac: false))
        suite.expect(kept.isUnlocked(notes, at: at(1), preferences),
                     "with Lock when the Mac locks off, the unlock survives the lock screen")

        var lockNow = unlockedNotes()
        lockNow.lockAll()
        suite.expect(lockNow.sessions.isEmpty && !lockNow.isUnlocked(notes, at: at(0), preferences),
                     "Lock Now ends every unlock")

        let restarted = AppLockSessions()
        suite.expect(restarted.sessions.isEmpty && !restarted.isUnlocked(notes, at: at(0), preferences),
                     "Zenith starting again begins with every app locked: nothing is kept on disk")
    }

    // MARK: One unlock for every app

    private static func sharedUnlock(_ suite: TestSuite) {
        let preferences = prefs(scope: .allApps)
        var sessions = AppLockSessions()
        _ = sessions.activated(notes, isRegular: true, at: at(0), preferences)
        sessions.unlocked(notes, at: at(0), preferences)
        _ = sessions.activated(notes, isRegular: true, at: at(0), preferences)
        suite.expect(sessions.activated(messages, isRegular: true, at: at(1), preferences) == .allow,
                     "all locked apps: one unlock opens the next locked app too")
        _ = sessions.activated(safari, isRegular: true, at: at(2), preferences)
        suite.expect(sessions.activated(notes, isRegular: true, at: at(6), preferences) == .allow,
                     "the shared clock runs from the last locked app in front")
        _ = sessions.activated(safari, isRegular: true, at: at(7), preferences)
        suite.expect(sessions.activated(messages, isRegular: true, at: at(12), preferences) == .lock,
                     "and runs out for every app at once")

        var quitting = AppLockSessions()
        _ = quitting.activated(notes, isRegular: true, at: at(0), preferences)
        quitting.unlocked(notes, at: at(0), preferences)
        quitting.terminated(notes, stillRunning: [notes, messages, safari], preferences)
        suite.expect(quitting.isUnlocked(messages, at: at(1), preferences),
                     "the shared unlock outlives one app quitting while another locked app runs")
        quitting.terminated(messages, stillRunning: [safari], preferences)
        suite.expect(!quitting.isUnlocked(notes, at: at(1), preferences),
                     "it ends when the last locked app quits")
        suite.expect(AppLockSessions.key(for: notes, scope: .allApps) == AppLockSessions.key(for: messages, scope: .allApps)
                        && AppLockSessions.key(for: notes, scope: .eachApp) != AppLockSessions.key(for: messages, scope: .eachApp),
                     "the scope decides which apps share an unlock")
    }

    // MARK: The shield

    private static func shield(_ suite: TestSuite) {
        suite.expect(AppLockShieldAction.when(zenith, isRegular: false, covering: notes) == .keep
                        && AppLockShieldAction.when(zenith, isRegular: true, covering: notes) == .keep,
                     "Zenith taking the keyboard for the shield keeps it up")
        suite.expect(AppLockShieldAction.when("com.apple.coreautha", isRegular: false, covering: notes) == .keep
                        && AppLockShieldAction.when(nil, isRegular: true, covering: notes) == .keep,
                     "the Touch ID prompt coming forward keeps it up")
        suite.expect(AppLockShieldAction.when(notes, isRegular: true, covering: notes) == .refocus,
                     "the covered app clicked again: the shield takes the keyboard back, no second prompt")
        suite.expect(AppLockShieldAction.when(safari, isRegular: true, covering: notes) == .cancel,
                     "going to another app cancels: the covered app hides and the shield goes")
        suite.expect(AppLockShieldAction.when("com.apple.finder", isRegular: true, covering: notes) == .cancel
                        && AppLockShieldAction.when("com.apple.systempreferences", isRegular: true, covering: notes) == .cancel,
                     "switching to Finder or System Settings is leaving too")
    }

    // MARK: Hiding when you switch away

    private static func hiding(_ suite: TestSuite) {
        let on = prefs(hide: true)
        suite.expect(AppLockSessions.hidesOnLeaving(notes, for: safari, isRegular: true, on),
                     "a locked app hides as another app comes forward")
        suite.expect(!AppLockSessions.hidesOnLeaving(notes, for: safari, isRegular: true, prefs()),
                     "only with the option on")
        suite.expect(!AppLockSessions.hidesOnLeaving(safari, for: notes, isRegular: true, on)
                        && !AppLockSessions.hidesOnLeaving(notes, for: zenith, isRegular: true, on)
                        && !AppLockSessions.hidesOnLeaving(notes, for: "com.apple.coreautha", isRegular: false, on)
                        && !AppLockSessions.hidesOnLeaving(notes, for: notes, isRegular: true, on)
                        && AppLockSessions.hidesOnLeaving(notes, for: "com.apple.finder", isRegular: true, on)
                        && !AppLockSessions.hidesOnLeaving(nil, for: safari, isRegular: true, on),
                     "an unlocked app, Zenith, a prompt or the same app never hide anything")
    }

    // MARK: Methods

    private static func methods(_ suite: TestSuite) {
        suite.expect(AppLockMethod.plan(preferFace: true, faceUnlockReady: true) == [.face, .system],
                     "Face Unlock first when it is on and ready, Touch ID or the password after")
        suite.expect(AppLockMethod.plan(preferFace: true, faceUnlockReady: false) == [.system]
                        && AppLockMethod.plan(preferFace: false, faceUnlockReady: true) == [.system],
                     "Touch ID or the password always, and alone without a ready Face Unlock")
    }

    // MARK: Preferences

    private static func preferences(_ suite: TestSuite) {
        let domain = "com.vorssaint.tests.app-lock"
        guard let defaults = UserDefaults(suiteName: domain) else { return suite.expect(false, "test defaults") }
        defaults.removePersistentDomain(forName: domain)
        defer { defaults.removePersistentDomain(forName: domain) }
        let fresh = AppLockPreferences(defaults: defaults)
        suite.expect(!fresh.enabled && fresh.apps.isEmpty && fresh.relock == .fiveMinutes && fresh.scope == .eachApp
                        && fresh.faceUnlock && fresh.lockWithMac && !fresh.hideWhenInactive,
                     "off by default, five minutes, each app, Face Unlock when ready, locking with the Mac")
        defaults.set(true, forKey: AppLockDefaults.enabled)
        defaults.set([notes, notes, "com.apple.finder"], forKey: AppLockDefaults.apps)
        defaults.set(0, forKey: AppLockDefaults.relock)
        defaults.set("allApps", forKey: AppLockDefaults.scope)
        defaults.set(false, forKey: AppLockDefaults.lockWithMac)
        let stored = AppLockPreferences(defaults: defaults)
        suite.expect(stored.enabled && stored.apps == [notes] && stored.relock == .untilQuit && stored.scope == .allApps
                        && !stored.lockWithMac,
                     "the stored choices are read back, the list cleaned")
        defaults.set(7, forKey: AppLockDefaults.relock)
        defaults.set("everyone", forKey: AppLockDefaults.scope)
        let odd = AppLockPreferences(defaults: defaults)
        suite.expect(odd.relock == .fiveMinutes && odd.scope == .eachApp, "an unknown value falls back to the default")
        suite.expect(AppLockDefaults.backupKeys.count == 7
                        && AppLockDefaults.backupKeys.contains(AppLockDefaults.apps)
                        && SettingsBackupSupport.exportKeys().isSuperset(of: AppLockDefaults.backupKeys),
                     "every App Lock preference travels in the settings backup")
    }

    // MARK: Quiet runs

    /// The parts that observe, cover or ask stand down while `ZenithQuiet` is on.
    private static func quiet(_ suite: TestSuite) {
        let root = URL(fileURLWithPath: ".")
        let service = (try? String(contentsOf: root.appendingPathComponent(
            "Sources/Vorssaint/Services/AppLock/AppLockService.swift"), encoding: .utf8)) ?? ""
        let shield = (try? String(contentsOf: root.appendingPathComponent(
            "Sources/Vorssaint/UI/AppLock/AppLockShield.swift"), encoding: .utf8)) ?? ""
        func guarded(_ source: String, _ function: String) -> Bool {
            guard let start = source.range(of: function) else { return false }
            return source[start.upperBound...].prefix(400).contains("ZenithQuiet.isOn")
        }
        suite.expect(guarded(service, "static func launch()") && guarded(service, "func sync()")
                        && guarded(service, "private func cover(") && guarded(shield, "func show("),
                     "launching, syncing, covering and showing the shield all stand down in quiet runs")
        suite.expect(!service.contains("NSSound") && !shield.contains("NSSound"), "App Lock makes no sound")
    }

    // MARK: Words

    private static func words(_ suite: TestSuite) {
        let text = ZenithStrings.appLock(.enUS)
        suite.expect(text.all.allSatisfy { !$0.isEmpty } && text.all.count > 40, "every string has words")
        suite.expect(text.limitsCaption.contains("not a security boundary"),
                     "the page is honest that App Lock is a deterrent")
        suite.expect(AppLockRelock.allCases.map(text.relockTitle) == ["1 minute", "5 minutes", "15 minutes", "30 minutes",
                                                                       "Until it quits"]
                        && AppLockScope.allCases.map(text.scopeTitle) == ["Each app on its own", "All locked apps"],
                     "the choices read as the owner chose")
        suite.expect(text.appCount(1) == "1 app" && text.appCount(3) == "3 apps", "the count chip")
        suite.expect(AppLockSearch.aliases.contains("kunci aplikasi") && AppLockSearch.keywords(.enUS).contains(text.enable),
                     "Settings search finds the page in English and Indonesian")
    }
}
