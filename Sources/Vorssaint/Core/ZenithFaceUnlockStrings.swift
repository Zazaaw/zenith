// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: face unlock's text (Settings → Face Unlock, the setup window,
// the Touch ID prompts). English in every language, by the owner's decision:
// the feature is for this Mac's owner, and Zenith has no Indonesian locale.
// Settings search still finds it by Indonesian aliases (FaceUnlockSearch).

struct ZenithFaceUnlockStrings {
    // Page.
    let title = "Face Unlock"
    let subtitle = "Unlock this Mac by looking at it. Once it recognizes your face, Zenith types your login password for you."
    let enable = "Enable Face Unlock"
    let enableCaption = "Off until you turn it on, and not as secure as Touch ID. Read the notes below first."
    let setUp = "Set Up Face Unlock…"
    let setUpCaption = "Add your face and your login password to turn it on."
    let unsupported = "Face Unlock needs macOS 15 or later."
    let recognitionMissing = "Face recognition is not part of this build yet, so there is nothing to enroll or unlock with."

    // Session.
    let session = "Session"
    let sessionOpen = "Session open"
    let sessionLocked = "Session locked"
    let sessionOpenCaption = "Face unlock can read your password. The session locks again after the time below without use, when Zenith quits, or now."
    let sessionLockedCaption = "Face unlock cannot read your password until you unlock the session with Touch ID once."
    let lockNow = "Lock Now"
    let unlockWithTouchID = "Unlock with Touch ID"
    let authenticating = "Authenticating…"
    let autoLock = "Lock the session after"
    let sevenDays = "7 days"
    let fourteenDays = "14 days"
    let thirtyDays = "30 days"
    let never = "Never"
    let neverCaption = "Never still locks when Zenith quits."

    // Triggers.
    let triggers = "Start scanning"
    let triggersCaption = "At least one stays on. With the island hidden, only these start a scan."
    let onLock = "When the Mac locks"
    let onWake = "When the display wakes"
    let onHover = "When the pointer is on the island"
    let onSpace = "When Space is pressed"
    let spaceAccess = "“When Space is pressed” reads the keyboard on the lock screen, which needs Input Monitoring. Zenith asks only while it is on."
    let openInputMonitoring = "Open Input Monitoring Settings…"

    // Scanning.
    let scanning = "Scanning"
    let scanDuration = "Look for a face for"
    let retryOnHover = "Retry when the pointer is on the island"
    let autoRetry = "Try once more after a failed scan"
    let camera = "Camera"
    let systemDefault = "System default"

    // Recognition.
    let recognition = "Recognition"
    let matchStrictness = "Match strictness"
    let lessStrict = "Less strict"
    let standard = "Default"
    let moreStrict = "More strict"
    let liveness = "Liveness check"
    let livenessCaption = "Checks for a live person, not a photo. May add a moment to each unlock."
    let livenessLevel = "Check"
    let light = "Light"
    let heavy = "Heavy"
    let lightCaption = "Rejects photos and phone screens."
    let heavyCaption = "Also needs a blink or a small head movement. Safer, slower."

    // Animation.
    let animation = "Unlock animation"
    let original = "Original"
    let minimal = "Minimal"
    let noAnimation = "None"
    let noAnimationCaption = "With none, nothing shows on the lock screen and scans run on their own."

    // Faces.
    let faces = "Faces"
    let facesCaption = "Add a face for each person, or for glasses and different light. Switched off faces stay enrolled but cannot unlock."
    let facesEmpty = "No faces yet."
    let facesLocked = "Unlock the session to see your faces."
    let facesNoneOn = "No face is on, so face unlock recognizes no one."
    let recapture = "Captured with another model. Add it again before it can unlock."
    let addFace = "Add a Face…"
    let rename = "Rename"
    let delete = "Delete"
    let save = "Save"
    let cancel = "Cancel"
    /// `{name}` is the face's name.
    let deleteConfirm = "Delete “{name}”? It stops unlocking this Mac."
    let nameEmpty = "Enter a name."
    /// `{name}` is the name typed.
    let nameTaken = "A face named “{name}” is already enrolled."

    // Password.
    let password = "Password"
    let passwordStored = "Your login password is stored, encrypted."
    let passwordMissing = "No password stored, so face unlock cannot unlock."
    let changePassword = "Change…"
    let setPassword = "Set Password…"
    let removePassword = "Remove"
    let removePasswordConfirm = "Remove the stored password? Face unlock stops working until you set it again."
    let reset = "Reset Face Unlock…"
    let resetCaption = "Deletes your faces, the stored password and the key, and turns face unlock off."
    let resetConfirm = "Delete your faces, the stored password and the key?"
    let resetButton = "Reset"

    // Face Lab.
    let lab = "Face Lab"
    let labCaption = "Watch recognition and liveness live, and tune them, without unlocking anything."
    let openLab = "Open Face Lab…"

    // Notes.
    let notes = "Before you turn it on"
    let noteSecurity = "Face unlock is not as secure as Touch ID or Face ID. It uses your Mac’s ordinary camera and is built for convenience, not for high-security sign-in."
    let noteVideo = "Someone holding up a video of you may fool it. The liveness check stops photos and screens, not every video."
    let noteTyping = "When it recognizes you, it types your login password into the lock screen. Anyone it mistakes for you gets in."
    let noteStorage = "How your password is kept: sealed with AES-GCM in a file only your account can read. The key is in your login keychain, where only Zenith may read it, and Zenith asks for Touch ID before it opens the key. macOS itself does not guard the key with Touch ID, since that needs an Apple-signed entitlement this build does not have. While the session is open, the key stays in Zenith’s memory."

    // Errors.
    let errorAuthentication = "Touch ID was cancelled or did not pass."
    let errorKeyMissing = "Something is sealed with a key that is no longer in the keychain. Nothing was deleted. Reset Face Unlock to start again."
    /// `{code}` is the keychain’s status number.
    let errorKeychain = "The keychain refused ({code})."
    let errorSave = "The password could not be saved."
    let errorSessionLocked = "The session is locked. Unlock it with Touch ID first."
    let errorEmptyPassword = "Enter your password."
    let errorAccessibility = "Zenith needs Accessibility to type your password."
    let errorOther = "Something went wrong. Try again."

    // Touch ID prompts: macOS shows "Zenith is trying to …".
    let reasonOpen = "open the Face Unlock session"
    let reasonSetUp = "set up Face Unlock"
    let reasonAddFace = "add a face to Face Unlock"

    // Setup window.
    let windowTitle = "Set Up Face Unlock"
    let next = "Next"
    let back = "Back"
    let done = "Done"
    let introTitle = "Face Unlock"
    let introBody = "Unlock your Mac by looking at it. Setup takes about a minute."
    let permissionsTitle = "Permissions"
    let permissionsBody = "Face unlock needs two permissions. Both stay on this Mac."
    let accessibility = "Accessibility"
    let accessibilityDetail = "So Zenith can type your password on the lock screen"
    let cameraPermission = "Camera"
    let cameraDetail = "So Zenith can recognize your face"
    let allow = "Allow"
    let allowed = "Allowed"
    let openSettings = "Open Settings"
    let noticeTitle = "Face unlock is not as secure as Touch ID."
    let understand = "I Understand"
    let preSetupTitle = "Set up your face"
    let preSetupBody = "Look at the camera, then turn your head slowly where the ring points, until every mark is lit."
    let selectCameraTitle = "Choose a camera"
    let selectCameraBody = "Used to add your face and to unlock your Mac."
    let captured = "Face captured"
    let nameTitle = "Name this face"
    let nameBody = "Tells faces apart when more than one is set up on this Mac."
    let namePlaceholder = "Name"
    let passwordTitle = "Enter your login password"
    let passwordBody = "Zenith types it on the lock screen when it recognizes you. It is encrypted and stays on this Mac; face unlock works offline."
    let passwordPlaceholder = "Login password"
    let confirm = "Confirm"
    let saving = "Saving…"
    let completeTitle = "You’re all set"
    let completeBody = "Lock your Mac to try it."
    let close = "Close"

    // The sweep's guidance.
    let lookStraight = "Look straight at the camera"
    let turnLeft = "Turn your head slightly left"
    let turnTopLeft = "Turn your head to the top left"
    let turnUp = "Turn your head slightly up"
    let turnTopRight = "Turn your head to the top right"
    let turnRight = "Turn your head slightly right"
    let turnBottomRight = "Turn your head to the bottom right"
    let turnDown = "Turn your head slightly down"
    let turnBottomLeft = "Turn your head to the bottom left"
    let noFace = "Bring your face into view"
    let moveCloser = "Bring your face closer"
    /// `{direction}` is one of the directions below.
    let tooFarTurned = "Too far {direction}"
    let directionLeft = "left"
    let directionRight = "right"
    let directionUp = "up"
    let directionDown = "down"
    let directionTopLeft = "toward the top left"
    let directionTopRight = "toward the top right"
    let directionBottomLeft = "toward the bottom left"
    let directionBottomRight = "toward the bottom right"

    // About.
    let credits = "Credits"
    let glanceCredit = "Face Unlock is adapted from Glance by Jonathan Zhou, used under the MIT License."
    let arcFaceCredit = "Face recognition runs an ArcFace model from InsightFace, whose weights are licensed for non-commercial research use only."
    let showLicense = "Show License"
    let hideLicense = "Hide License"

    func seconds(_ value: Int) -> String { "\(value) s" }
    func named(_ format: String, _ name: String) -> String { format.replacingOccurrences(of: "{name}", with: name) }

    func autoLockTitle(_ value: FaceUnlockAutoLock) -> String {
        switch value {
        case .sevenDays: return sevenDays
        case .fourteenDays: return fourteenDays
        case .thirtyDays: return thirtyDays
        case .never: return never
        }
    }

    func trigger(_ value: FaceUnlockTrigger) -> String {
        switch value {
        case .onLock: return onLock
        case .onWake: return onWake
        case .onHover: return onHover
        case .onSpace: return onSpace
        }
    }

    func match(_ value: FaceUnlockMatchLevel) -> String {
        switch value {
        case .lessStrict: return lessStrict
        case .standard: return standard
        case .moreStrict: return moreStrict
        }
    }

    func liveness(_ value: FaceUnlockLivenessLevel) -> String { value == .light ? light : heavy }

    func animation(_ value: FaceUnlockAnimationStyle) -> String {
        switch value {
        case .original: return original
        case .minimal: return minimal
        case .none: return noAnimation
        }
    }

    func instruction(_ pose: FaceUnlockEnrollmentPose) -> String {
        switch pose {
        case .center: return lookStraight
        case .left: return turnLeft
        case .topLeft: return turnTopLeft
        case .top: return turnUp
        case .topRight: return turnTopRight
        case .right: return turnRight
        case .bottomRight: return turnBottomRight
        case .bottom: return turnDown
        case .bottomLeft: return turnBottomLeft
        }
    }

    func direction(_ pose: FaceUnlockEnrollmentPose) -> String {
        switch pose {
        case .center, .top: return directionUp
        case .left: return directionLeft
        case .topLeft: return directionTopLeft
        case .topRight: return directionTopRight
        case .right: return directionRight
        case .bottomRight: return directionBottomRight
        case .bottom: return directionDown
        case .bottomLeft: return directionBottomLeft
        }
    }

    /// The line under the camera while the sweep runs.
    func guidance(_ progress: FaceUnlockEnrollmentProgress) -> String {
        if progress.isComplete { return captured }
        switch progress.hint {
        case .noFace: return noFace
        case .tooFar: return moveCloser
        case .tooFarTurned(let pose): return tooFarTurned.replacingOccurrences(of: "{direction}", with: direction(pose))
        case .none: return progress.pose.map(instruction) ?? captured
        }
    }

    func error(_ error: FaceUnlockSecurityError) -> String {
        switch error {
        case .authenticationFailed: return errorAuthentication
        case .sessionKeyMissing, .decryptionFailed: return errorKeyMissing
        case .keychain(let status): return errorKeychain.replacingOccurrences(of: "{code}", with: status.map(String.init) ?? "?")
        case .encryptionFailed: return errorSave
        case .sessionLocked: return errorSessionLocked
        case .emptyPassword: return errorEmptyPassword
        case .accessibility: return errorAccessibility
        case .noPassword: return passwordMissing
        case .notLocked, .typingFailed: return errorOther
        }
    }

    /// Every string, for the coverage tests.
    var all: [String] {
        Mirror(reflecting: self).children.compactMap { $0.value as? String }
    }
}

extension ZenithStrings {
    /// English in every language (see the file's note).
    static func faceUnlock(_ language: AppLanguage) -> ZenithFaceUnlockStrings {
        ZenithFaceUnlockStrings()
    }
}

/// Settings search: the page by its English words and the Indonesian ones its
/// owner types.
enum FaceUnlockSearch {
    static let aliases = ["face id", "face unlock", "faceid", "unlock with face", "face recognition", "glance",
                          "buka pakai wajah", "buka kunci wajah", "buka dengan wajah", "wajah", "pengenalan wajah",
                          "kunci wajah", "touch id", "liveness", "face lab"]

    static func keywords(_ language: AppLanguage) -> [String] {
        let text = ZenithStrings.faceUnlock(language)
        return [text.enable, text.triggers, text.faces, text.password, text.session, text.liveness, text.lab]
    }
}
