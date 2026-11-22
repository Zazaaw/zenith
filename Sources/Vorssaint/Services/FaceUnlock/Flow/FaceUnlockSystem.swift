// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Face unlock is adapted from Glance by Jonathan Zhou (MIT),
// https://github.com/jonnyoo/glance — see the notice in About.

import CoreGraphics
import Foundation
import LocalAuthentication
import Security

// Zenith fork: the real keychain, password file, Touch ID prompt and lock
// state behind `FaceUnlockSession` (Glance's `KeychainManager`, `LockMonitor.
// isScreenActuallyLocked` and the LocalAuthentication part of its session).
// App only: the tests use fakes and never reach any of these.

/// The session key as a generic password in the login keychain. No access
/// control flags (`.userPresence` needs an entitlement this build lacks) and
/// no data-protection keychain (same reason): a file-keychain item whose
/// default access list trusts only the app that created it, so another app
/// reading it gets the system's allow/deny prompt. Not synchronised.
final class FaceUnlockLoginKeychain: FaceUnlockKeyStore {
    private let service: String
    private let account = "session-key"

    init(bundleID: String = Bundle.main.bundleIdentifier ?? "id.satuvisual.zenith") {
        service = bundleID + ".face-unlock"
    }

    private var itemQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    func keyExists() -> Bool {
        var query = itemQuery
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnAttributes as String] = true
        var item: CFTypeRef?
        return SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess
    }

    func readKey() throws -> Data {
        var query = itemQuery
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { throw Self.error(status) }
        guard let data = item as? Data else { throw FaceUnlockSecurityError.sessionKeyMissing }
        return data
    }

    func saveKey(_ data: Data) throws {
        let update = SecItemUpdate(itemQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if update == errSecSuccess { return }
        guard update == errSecItemNotFound else { throw Self.error(update) }
        var add = itemQuery
        add[kSecValueData as String] = data
        add[kSecAttrLabel as String] = "Zenith Face Unlock"
        add[kSecAttrDescription as String] = "Unlocks the password Zenith types for face unlock"
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw Self.error(status) }
    }

    func deleteKey() throws {
        let status = SecItemDelete(itemQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw Self.error(status) }
    }

    private static func error(_ status: OSStatus) -> FaceUnlockSecurityError {
        switch status {
        case errSecUserCanceled, errSecAuthFailed, errSecInteractionNotAllowed: return .authenticationFailed
        case errSecItemNotFound: return .sessionKeyMissing
        default: return .keychain(status)
        }
    }
}

/// The sealed password as an owner-only file in the container
/// (`ZenithSecretStore`: folder 0700, file 0600, out of Time Machine), never
/// in preferences or a settings backup. Base64, since that store keeps text.
final class FaceUnlockPasswordFile: FaceUnlockBlobStore {
    static let name = "face-unlock-password"

    func exists() -> Bool {
        guard let url = ZenithSecretStore.url(for: Self.name) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    func read() -> Data? {
        ZenithSecretStore.read(Self.name).flatMap { Data(base64Encoded: $0) }
    }

    func write(_ data: Data) -> Bool {
        ZenithSecretStore.save(data.base64EncodedString(), as: Self.name)
    }

    func delete() {
        ZenithSecretStore.delete(Self.name)
    }
}

/// Touch ID through LocalAuthentication, falling back to the account
/// password where Touch ID is unavailable (no sensor, the lid closed, locked
/// out) or when the person chooses "Use Password".
final class FaceUnlockTouchID: FaceUnlockAuthenticating {
    func authenticate(reason: String, completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return evaluate(.deviceOwnerAuthentication, reason: reason, completion: completion)
        }
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { [weak self] passed, error in
            if passed { return completion(true) }
            let code = (error as? LAError)?.code
            if code == .userFallback || code == .biometryLockout {
                self?.evaluate(.deviceOwnerAuthentication, reason: reason, completion: completion)
            } else {
                completion(false)
            }
        }
    }

    private func evaluate(_ policy: LAPolicy, reason: String, completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(policy, error: &error) else { return completion(false) }
        context.evaluatePolicy(policy, localizedReason: reason) { passed, _ in completion(passed) }
    }
}

enum FaceUnlockScreenLock {
    /// From the CoreGraphics session server, not a notification any process
    /// can post. Fails closed: unknown reads as not locked, so nothing is typed.
    static func isLocked() -> Bool {
        isLocked(CGSessionCopyCurrentDictionary() as? [String: Any])
    }

    static func isLocked(_ session: [String: Any]?) -> Bool {
        session?["CGSSessionScreenIsLocked"] as? Bool ?? false
    }
}
