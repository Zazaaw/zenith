// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: App Lock's decisions, without windows, workspace observers or
// authentication, so the tests reach every one: the preferences, which apps
// can never be locked, whether an app coming to the front is covered, how an
// unlock ends (time out of the front, the app quitting, the Mac locking or
// sleeping, Zenith starting again), and what the shield does when another
// app comes forward while it is up.
//
// App Lock keeps casual snooping out; it is not a security boundary (see the
// page's Limits row).

/// App Lock's preferences. Kept here, not in `DefaultsKey`, so the feature's
/// files never edit a shared registry.
enum AppLockDefaults {
    static let enabled = "zenithAppLockEnabled"                   // Bool, default false
    static let apps = "zenithAppLockApps"                         // [String] bundle identifiers, in the order added
    static let relock = "zenithAppLockRelock"                     // Int, AppLockRelock.rawValue, default 5
    static let scope = "zenithAppLockScope"                       // String, AppLockScope.rawValue, default eachApp
    static let faceUnlock = "zenithAppLockFaceUnlock"             // Bool, default true (only while Face Unlock is set up)
    static let lockWithMac = "zenithAppLockWithMac"               // Bool, default true
    static let hideWhenInactive = "zenithAppLockHideWhenInactive" // Bool, default false

    /// Every key, for the settings backup. The list is bundle identifiers,
    /// the same on any Mac.
    static let backupKeys: Set<String> = [enabled, apps, relock, scope, faceUnlock, lockWithMac, hideWhenInactive]
}

/// How long an unlocked app may stay out of the front before it asks again.
enum AppLockRelock: Int, CaseIterable, Identifiable {
    case oneMinute = 1, fiveMinutes = 5, fifteenMinutes = 15, thirtyMinutes = 30
    /// Until the app quits, the Mac locks or sleeps, or Zenith starts again.
    case untilQuit = 0

    static let standard = AppLockRelock.fiveMinutes

    var id: Int { rawValue }

    /// Nil: time alone never locks the app again.
    var interval: TimeInterval? { self == .untilQuit ? nil : TimeInterval(rawValue) * 60 }
}

/// Whether one unlock opens one app or every locked app.
enum AppLockScope: String, CaseIterable, Identifiable {
    case eachApp, allApps
    var id: String { rawValue }
}

/// App Lock's preferences, read in one place.
struct AppLockPreferences: Equatable {
    var enabled: Bool
    var apps: [String]
    var relock: AppLockRelock
    var scope: AppLockScope
    var faceUnlock: Bool
    var lockWithMac: Bool
    var hideWhenInactive: Bool

    init(enabled: Bool = true, apps: [String] = [], relock: AppLockRelock = .standard, scope: AppLockScope = .eachApp,
         faceUnlock: Bool = true, lockWithMac: Bool = true, hideWhenInactive: Bool = false) {
        self.enabled = enabled
        self.apps = AppLockApps.cleaned(apps)
        self.relock = relock
        self.scope = scope
        self.faceUnlock = faceUnlock
        self.lockWithMac = lockWithMac
        self.hideWhenInactive = hideWhenInactive
    }

    init(defaults: UserDefaults) {
        self.init(enabled: defaults.object(forKey: AppLockDefaults.enabled) as? Bool ?? false,
                  apps: defaults.stringArray(forKey: AppLockDefaults.apps) ?? [],
                  relock: (defaults.object(forKey: AppLockDefaults.relock) as? Int).flatMap(AppLockRelock.init) ?? .standard,
                  scope: defaults.string(forKey: AppLockDefaults.scope).flatMap(AppLockScope.init) ?? .eachApp,
                  faceUnlock: defaults.object(forKey: AppLockDefaults.faceUnlock) as? Bool ?? true,
                  lockWithMac: defaults.object(forKey: AppLockDefaults.lockWithMac) as? Bool ?? true,
                  hideWhenInactive: defaults.object(forKey: AppLockDefaults.hideWhenInactive) as? Bool ?? false)
    }

    var locked: Set<String> { Set(apps) }

    /// Whether App Lock watches the workspace: on, with an app to lock.
    var isWatching: Bool { enabled && !apps.isEmpty }

    func isLocked(_ bundleID: String) -> Bool {
        enabled && locked.contains(bundleID) && !AppLockExemptions.isExempt(bundleID)
    }
}

/// The locked apps list: one entry per app, never an exempt one.
enum AppLockApps {
    static func cleaned(_ apps: [String]) -> [String] {
        var seen = Set<String>()
        return apps.compactMap { raw in
            let id = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty, !AppLockExemptions.isExempt(id), seen.insert(id.lowercased()).inserted else { return nil }
            return id
        }
    }

    /// The list with `bundleIDs` added at the end, or why one could not be.
    static func adding(_ bundleIDs: [String], to apps: [String]) -> (apps: [String], refused: [String]) {
        let refused = bundleIDs.filter(AppLockExemptions.isExempt)
        return (cleaned(apps + bundleIDs), refused)
    }

    static func removing(_ bundleID: String, from apps: [String]) -> [String] {
        apps.filter { $0.caseInsensitiveCompare(bundleID) != .orderedSame }
    }
}

/// Apps App Lock never covers: Zenith itself (it draws the shield and holds
/// the switch), the system's own surfaces, the password and Touch ID prompts,
/// and System Settings, so the Mac can always be reached.
enum AppLockExemptions {
    static let bundleIDs: Set<String> = [
        "com.apple.systempreferences", "com.apple.Settings", // System Settings
        "com.apple.finder", "com.apple.dock", "com.apple.loginwindow", "com.apple.SecurityAgent",
        "com.apple.coreautha", "com.apple.LocalAuthentication.UIAgent", "com.apple.UserNotificationCenter",
        "com.apple.ScreenSaver.Engine", "com.apple.systemuiserver", "com.apple.controlcenter",
        "com.apple.notificationcenterui", "com.apple.Spotlight", "com.apple.WindowManager",
        "com.apple.accessibility.universalAccessAuthWarn",
    ]

    /// Zenith, its Developer build and helpers, and the Vorssaint apps it grew from.
    static let ownPrefixes = ["id.satuvisual.zenith", "com.vorssaint."]

    static func isExempt(_ bundleID: String) -> Bool {
        let lowered = bundleID.lowercased()
        return isZenith(bundleID) || bundleIDs.contains { $0.lowercased() == lowered }
    }

    /// Zenith or one of its helpers: the shield's own windows belong to it.
    static func isZenith(_ bundleID: String) -> Bool {
        let lowered = bundleID.lowercased()
        return ownPrefixes.contains { lowered == $0 || lowered.hasPrefix($0.hasSuffix(".") ? $0 : $0 + ".") }
    }
}

/// What App Lock does with an app that just came to the front.
enum AppLockDecision: Equatable {
    /// Not an app the person switches to (an agent, a prompt) or one App Lock
    /// never covers: nothing changes.
    case ignore
    /// Not locked, or unlocked and still within its time.
    case allow
    /// Locked: cover it and ask.
    case lock
}

/// What the shield does when an app comes to the front while it covers one.
enum AppLockShieldAction: Equatable {
    /// Zenith (the shield itself), a prompt or an agent: the shield stays as it is.
    case keep
    /// The covered app itself: the shield takes the keyboard back.
    case refocus
    /// The person went elsewhere (Finder and System Settings included): hide
    /// the covered app and take the shield down.
    case cancel

    static func when(_ activated: String?, isRegular: Bool, covering shielded: String) -> AppLockShieldAction {
        guard let activated, isRegular, !AppLockExemptions.isZenith(activated) else { return .keep }
        return activated == shielded ? .refocus : .cancel
    }
}

/// The unlocks App Lock holds, in memory only: Zenith starting again begins
/// with none. Time out of the front is measured from the moment the app
/// left it, so an app kept in front never times out, and nothing polls: an
/// unlock that ran out is noticed when the app next comes forward.
struct AppLockSessions: Equatable {
    struct Session: Equatable {
        var unlockedAt: Date
        /// When an app under this unlock was last in front.
        var lastActive: Date
        /// An app under this unlock is in front right now.
        var inFront: Bool
    }

    /// The one unlock all locked apps share in `.allApps`.
    static let everyApp = "*"

    private(set) var sessions: [String: Session] = [:]
    /// The regular app in front, as App Lock last heard.
    private(set) var frontmost: String?

    static func key(for bundleID: String, scope: AppLockScope) -> String {
        scope == .allApps ? everyApp : bundleID
    }

    /// Whether `bundleID` may show without asking at `now`.
    func isUnlocked(_ bundleID: String, at now: Date, _ preferences: AppLockPreferences) -> Bool {
        guard let session = sessions[Self.key(for: bundleID, scope: preferences.scope)] else { return false }
        if session.inFront { return true }
        guard let interval = preferences.relock.interval else { return true }
        return now.timeIntervalSince(session.lastActive) < interval
    }

    /// A regular app came to the front. `isRegular` is false for agents and
    /// prompts (the Touch ID sheet, a menu bar app), which change nothing.
    mutating func activated(_ bundleID: String?, isRegular: Bool, at now: Date,
                            _ preferences: AppLockPreferences) -> AppLockDecision {
        guard let bundleID, isRegular else { return .ignore }
        if let previous = frontmost, previous != bundleID { left(previous, at: now, preferences) }
        frontmost = bundleID
        if AppLockExemptions.isExempt(bundleID) { return .ignore }
        guard preferences.isLocked(bundleID) else { return .allow }
        let key = Self.key(for: bundleID, scope: preferences.scope)
        guard isUnlocked(bundleID, at: now, preferences) else {
            sessions[key] = nil // ran out: it asks again
            return .lock
        }
        sessions[key]?.inFront = true
        sessions[key]?.lastActive = now
        return .allow
    }

    /// The app passed Touch ID, Face Unlock or the password.
    mutating func unlocked(_ bundleID: String, at now: Date, _ preferences: AppLockPreferences) {
        let key = Self.key(for: bundleID, scope: preferences.scope)
        sessions[key] = Session(unlockedAt: now, lastActive: now, inFront: frontmost == bundleID)
    }

    /// The app quit. Its unlock ends; the shared unlock of `.allApps` ends
    /// when no locked app is left running.
    mutating func terminated(_ bundleID: String, stillRunning: Set<String>, _ preferences: AppLockPreferences) {
        if frontmost == bundleID { frontmost = nil }
        switch preferences.scope {
        case .eachApp:
            sessions[bundleID] = nil
        case .allApps:
            let others = stillRunning.subtracting([bundleID]).filter(preferences.isLocked)
            if others.isEmpty { sessions[Self.everyApp] = nil }
        }
    }

    /// The Mac locked, slept or started its screen saver.
    mutating func macLocked(_ preferences: AppLockPreferences) {
        guard preferences.lockWithMac else { return }
        lockAll()
    }

    /// Every unlock ends now (Lock Now, App Lock turned off).
    mutating func lockAll() {
        sessions.removeAll()
    }

    /// Whether the app that just left the front should be hidden (the
    /// "hide when you switch away" option keeps locked windows out of sight).
    static func hidesOnLeaving(_ bundleID: String?, for activated: String?, isRegular: Bool,
                               _ preferences: AppLockPreferences) -> Bool {
        guard preferences.hideWhenInactive, let bundleID, let activated, isRegular,
              activated != bundleID, !AppLockExemptions.isZenith(activated) else { return false }
        return preferences.isLocked(bundleID)
    }

    private mutating func left(_ bundleID: String, at now: Date, _ preferences: AppLockPreferences) {
        guard preferences.isLocked(bundleID) else { return }
        let key = Self.key(for: bundleID, scope: preferences.scope)
        guard sessions[key] != nil else { return }
        sessions[key]?.inFront = false
        sessions[key]?.lastActive = now
    }
}

/// How App Lock asks: Zenith's own Face Unlock first when it is on, set up
/// and has a face to match, then Touch ID or the Mac password.
enum AppLockMethod: Equatable {
    case face, system

    static func plan(preferFace: Bool, faceUnlockReady: Bool) -> [AppLockMethod] {
        preferFace && faceUnlockReady ? [.face, .system] : [.system]
    }
}
