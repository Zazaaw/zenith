// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: App Lock's text, for its Settings page and the shield that
// covers a locked app's windows. English in every language, by the owner's decision,
// as Mechakey's. Settings search still finds the page by Indonesian aliases
// (AppLockSearch).

struct ZenithAppLockStrings {
    // Page.
    let title = "App Lock"
    let subtitle = "Ask for Touch ID, your face or your Mac password before the apps you choose come to the front."
    let enable = "Enable App Lock"
    let enableHint = "Off, Zenith watches no app."

    // Stage.
    let stageCaption = "A locked app’s windows, covered until you unlock it"
    let stageLocked = "Locked"
    let stageScanning = "Face Unlock"
    let stageUnlocked = "Unlocked"

    // Locked apps.
    let appsSection = "Locked apps"
    let noApps = "No apps yet. Add the ones you want to keep to yourself."
    let addRow = "Lock another app"
    let addApp = "Add App…"
    let addRunning = "Add Running App"
    let remove = "Remove"
    let notInstalled = "Not on this Mac"
    let exemptRefused = "Zenith, Finder and System Settings can’t be locked, so the Mac stays reachable."
    let chooseAppsPrompt = "Lock"
    let chooseAppsMessage = "Choose the apps App Lock covers."

    // Unlocking.
    let unlockSection = "Unlocking"
    let coverTitle = "Covers only the app’s windows"
    let coverCaption = "A blur sits on each window of the locked app and follows it as it moves, resizes or changes Space; the rest of the screen stays yours, and clicking another app hides the locked one. Typing goes to the shield: Return unlocks, Esc hides the app. With Accessibility allowed for Zenith the blur follows at once, otherwise a moment later."
    let systemMethod = "Touch ID or password"
    let systemMethodCaption = "macOS asks with Touch ID, or your Mac password where Touch ID is not available or you choose Use Password."
    let always = "Always"
    let faceMethod = "Try Face Unlock first"
    let faceMethodCaption = "Zenith’s own Face Unlock looks for your face before Touch ID asks. It needs Face Unlock on and set up, with Touch ID opened once since Zenith started."
    let faceNotSetUp = "Set up Face Unlock to use your face here."
    let faceUnsupported = "Face Unlock needs macOS 15 or later."
    let openFaceUnlock = "Set Up"

    // Lock again.
    let relockSection = "Lock again"
    let relock = "Lock again after"
    let relockCaption = "Time the app spends out of the front. Quitting the app, locking or sleeping the Mac and quitting Zenith always lock it again."
    let scope = "One unlock opens"
    let scopeCaption = "Each app on its own asks for every locked app. All locked apps opens every one of them with one unlock, until it runs out."
    let lockWithMac = "Lock when the Mac locks or sleeps"
    let lockWithMacCaption = "The screen locking, the screen saver starting or the Mac sleeping ends every unlock and hides the locked apps, so nothing shows when you come back."
    let hideWhenInactive = "Hide locked apps when you switch away"
    let hideWhenInactiveCaption = "Their windows leave the screen, Mission Control and App Exposé whenever another app comes to the front."
    let lockNow = "Lock Now"
    let lockNowTitle = "Lock every app now"
    let lockNowCaption = "Ends every unlock and hides the locked apps that are open. Each asks again the next time it comes to the front."
    let lockedNow = "Every locked app will ask again."

    // Limits.
    let limitsSection = "Limits"
    let limitsTitle = "A deterrent, not a vault"
    let limitsCaption = "App Lock keeps casual snooping out; it is not a security boundary. A locked app keeps running underneath: its notifications, Dock menu, Mission Control, Quick Look, Spotlight and other apps can still show what is in it, and anyone who can quit Zenith, or knows your password, can open it. For data that must stay private, use FileVault, a separate user account or the app’s own lock."

    // Shield.
    let lockedBy = "Locked by Zenith"
    let unlock = "Unlock"
    let cancel = "Cancel"
    let usePassword = "Use Touch ID or Password"
    let lookingForFace = "Looking for your face…"
    let waiting = "Waiting for Touch ID or your password…"
    let faceNotRecognized = "Face not recognized. Use Touch ID or your password."
    let failed = "Not unlocked. Try again, or cancel to hide it."

    // Chips.
    func appCount(_ count: Int) -> String { count == 1 ? "1 app" : "\(count) apps" }
    let chipFace = "Face Unlock"
    let chipTouchID = "Touch ID"

    /// The reason macOS shows in its Touch ID or password prompt.
    func reason(_ app: String) -> String { "unlock \(app)" }

    func relockTitle(_ relock: AppLockRelock) -> String {
        switch relock {
        case .oneMinute: return "1 minute"
        case .fiveMinutes: return "5 minutes"
        case .fifteenMinutes: return "15 minutes"
        case .thirtyMinutes: return "30 minutes"
        case .untilQuit: return "Until it quits"
        }
    }

    func scopeTitle(_ scope: AppLockScope) -> String {
        switch scope {
        case .eachApp: return "Each app on its own"
        case .allApps: return "All locked apps"
        }
    }

    /// Every string, for the coverage tests.
    var all: [String] {
        Mirror(reflecting: self).children.compactMap { $0.value as? String }
    }
}

extension ZenithStrings {
    /// English in every language (see the file's note).
    static func appLock(_ language: AppLanguage) -> ZenithAppLockStrings {
        ZenithAppLockStrings()
    }
}

/// Settings search: the page by its English words and the Indonesian ones its
/// owner types.
enum AppLockSearch {
    static let aliases = ["app lock", "lock app", "lock apps", "applock", "app locker", "password app", "touch id app",
                          "kunci aplikasi", "kunci app", "gembok aplikasi", "kunci apl", "sandi aplikasi",
                          "privasi aplikasi", "kunci"]

    static func keywords(_ language: AppLanguage) -> [String] {
        let text = ZenithStrings.appLock(language)
        return [text.enable, text.appsSection, text.relock, text.scope, text.lockWithMac, text.faceMethod]
    }
}
