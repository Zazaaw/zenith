// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CryptoKit
import Foundation

// Zenith fork: INTEGRATION SHIM — delete this file when the recognition
// branch merges. It declares, as briefed, the two names recognition owns and
// the security side uses, so this branch builds on its own:
// - `FaceUnlockKeyProvider` / `FaceUnlockKeys.provider`: recognition's face
//   store seals with the session key; `FaceUnlockSession` conforms and is set
//   at launch (FaceUnlockRuntime).
// - `FaceUnlockLab.open()`: Settings → Face Unlock opens Face Lab.
// If recognition's declarations differ, adapt the conformance and the call in
// FaceUnlockRuntime and FaceUnlockSettingsPage; nothing else names them.

protocol FaceUnlockKeyProvider: AnyObject {
    var sessionKey: SymmetricKey? { get }
}

enum FaceUnlockKeys {
    nonisolated(unsafe) static var provider: FaceUnlockKeyProvider?
}

enum FaceUnlockLab {
    /// Recognition's Face Lab window. Until it merges there is none, and
    /// Settings keeps the button off while no recognizer is plugged in.
    static func open() {}
}
