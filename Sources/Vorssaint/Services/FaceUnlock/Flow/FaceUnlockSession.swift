// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Face unlock is adapted from Glance by Jonathan Zhou (MIT),
// https://github.com/jonnyoo/glance — see the notice in About.

import Combine
import CryptoKit
import Foundation

/// Zenith fork: the security side of face unlock (Glance's
/// `SecureCredentialManager` and `POCController`), behind the contract's
/// `FaceUnlockCredentials`.
///
/// Glance gates its session key with the keychain's `.userPresence`, which
/// needs an Apple-signed entitlement this build cannot have (`SecItemAdd`
/// answers -34018). So, as the owner decided:
/// - the login password is sealed with AES-GCM and kept as a 0600 file;
/// - the 256-bit key is a plain generic password in the login keychain, whose
///   default access list trusts only the app that created it;
/// - Zenith itself asks for Touch ID (LocalAuthentication) before it reads
///   the key, then holds it in memory only;
/// - the session locks again after `FaceUnlockAutoLock` idle, on quit, and
///   on demand.
/// The weaker point, said on the security notice and in Settings: macOS does
/// not enforce the Touch ID step, Zenith does.
///
/// Every dependency is injected, so the tests run it with a test key, an
/// in-memory keychain and a recording typist: never the real keychain, never
/// a keystroke.
final class FaceUnlockSession: ObservableObject, FaceUnlockCredentials, FaceUnlockKeyProvider {
    struct Dependencies {
        var keychain: FaceUnlockKeyStore
        var passwordFile: FaceUnlockBlobStore
        var authenticator: FaceUnlockAuthenticating
        var typist: FaceUnlockPasswordTyping
        /// The authoritative lock state (CGSession), never a notification.
        var isScreenLocked: () -> Bool
        /// Whether recognition keeps data sealed under the key (the face store),
        /// so a missing key is never silently replaced.
        var hasOtherSealedData: () -> Bool
        var now: () -> Date
        /// Where blocking keychain, file and typing work runs.
        var background: (@escaping () -> Void) -> Void
        /// Where results are published.
        var main: (@escaping () -> Void) -> Void
    }

    @Published private(set) var isUnlocked = false
    @Published private(set) var hasPassword = false
    @Published private(set) var lastError: FaceUnlockSecurityError?
    @Published private(set) var isAuthenticating = false

    private let deps: Dependencies
    private let lock = NSLock()
    private var key: SymmetricKey?
    private var activityAt: Date?
    private var pendingUnlocks: [(Bool) -> Void] = []

    init(_ dependencies: Dependencies) {
        deps = dependencies
        hasPassword = dependencies.passwordFile.exists()
    }

    // MARK: FaceUnlockCredentials

    var isSessionUnlocked: Bool { lock.withLock { key != nil } }
    var hasStoredPassword: Bool { deps.passwordFile.exists() }

    /// Touch ID first (Zenith asks, see the type's note), then the key: read
    /// it, or make one on first use. A cancelled prompt opens nothing, and a
    /// key that is gone while sealed data remains is an error, never a new key
    /// that would leave that data unreadable for good.
    func unlockSession(reason: String, completion: @escaping (Bool) -> Void) {
        if isSessionUnlocked { return deps.main { completion(true) } }
        let first = lock.withLock { () -> Bool in
            pendingUnlocks.append(completion)
            return pendingUnlocks.count == 1
        }
        guard first else { return }
        deps.main {
            self.isAuthenticating = true
            self.lastError = nil
        }
        deps.authenticator.authenticate(reason: reason) { [deps] passed in
            guard passed else { return self.finishUnlock(.failure(.authenticationFailed)) }
            deps.background {
                self.finishUnlock(Result { try self.loadOrCreateKey() }
                    .mapError { $0 as? FaceUnlockSecurityError ?? .keychain(nil) })
            }
        }
    }

    func lockSession() {
        let changed = lock.withLock { () -> Bool in
            defer { key = nil; activityAt = nil }
            return key != nil
        }
        deps.main {
            self.isUnlocked = false
            if changed { NotificationCenter.default.post(name: .faceUnlockSessionDidChange, object: self) }
        }
    }

    /// Decrypts the password and types it with Return, only while CGSession
    /// says the screen is locked and the session is open — checked here and
    /// again just before the first keystroke. The plaintext is zeroed after.
    func typeStoredPassword(completion: @escaping (Bool) -> Void) {
        guard deps.isScreenLocked() else { return finishTyping(.notLocked, completion) }
        guard let key = lock.withLock({ key }) else { return finishTyping(.sessionLocked, completion) }
        guard deps.typist.canType else { return finishTyping(.accessibility, completion) }
        deps.background { [deps] in
            guard let sealed = deps.passwordFile.read() else { return self.finishTyping(.noPassword, completion) }
            guard var password = try? FaceUnlockCipher.open(sealed, key: key) else {
                return self.finishTyping(.decryptionFailed, completion)
            }
            defer { password.resetBytes(in: 0..<password.count) }
            // The lock screen may have gone while the file was read.
            guard deps.isScreenLocked() else { return self.finishTyping(.notLocked, completion) }
            do {
                try deps.typist.type(password)
            } catch {
                return self.finishTyping(error as? FaceUnlockSecurityError ?? .typingFailed, completion)
            }
            self.recordActivity()
            self.finishTyping(nil, completion)
        }
    }

    // MARK: Key provider (the face store seals with the same key)

    var sessionKey: SymmetricKey? { lock.withLock { key } }

    // MARK: Password

    /// Seals and stores `password`; the session must be open.
    func savePassword(_ password: String, completion: @escaping (Result<Void, FaceUnlockSecurityError>) -> Void) {
        guard !password.isEmpty else { return deps.main { completion(.failure(.emptyPassword)) } }
        guard let key = lock.withLock({ key }) else { return deps.main { completion(.failure(.sessionLocked)) } }
        deps.background { [deps] in
            var bytes = Data(password.utf8)
            defer { bytes.resetBytes(in: 0..<bytes.count) }
            let result: Result<Void, FaceUnlockSecurityError>
            if let sealed = try? FaceUnlockCipher.seal(bytes, key: key), deps.passwordFile.write(sealed) {
                result = .success(())
            } else {
                result = .failure(.encryptionFailed)
            }
            deps.main {
                self.hasPassword = deps.passwordFile.exists()
                completion(result)
            }
        }
    }

    /// Deletes the stored password; faces and the key stay.
    func removePassword() {
        deps.passwordFile.delete()
        deps.main { self.hasPassword = self.deps.passwordFile.exists() }
    }

    /// Deletes the password and the key and locks. Whatever else was sealed
    /// under the key (the faces) is unreadable after, so the caller deletes
    /// that first.
    func resetAll() {
        deps.passwordFile.delete()
        try? deps.keychain.deleteKey()
        lockSession()
        deps.main {
            self.hasPassword = self.deps.passwordFile.exists()
            self.lastError = nil
        }
    }

    func refresh() {
#if VORSSAINT_DEVELOPMENT
        // Zenith fork: the catalog keeps its posed state.
        if IslandCatalog.isRendering { return }
#endif
        deps.main { self.hasPassword = self.deps.passwordFile.exists() }
    }

    // MARK: Auto-lock

    var lastActivityAt: Date? { lock.withLock { activityAt } }

    /// Locks once the session sat idle past `limit` (Glance's
    /// `SessionAutoLocker.evaluate`). True when it locked.
    @discardableResult
    func lockIfIdle(limit: FaceUnlockAutoLock) -> Bool {
        guard FaceUnlockAutoLocking.shouldLock(lastActivity: lastActivityAt, now: deps.now(), limit: limit) else {
            return false
        }
        lockSession()
        return true
    }

    // MARK: Private

    private func loadOrCreateKey() throws -> SymmetricKey {
        // The existence check decides, not a failed read, as in Glance: a
        // read that failed for any other reason must never mint a new key.
        if deps.keychain.keyExists() {
            let data = try deps.keychain.readKey()
            guard data.count == 32 else { throw FaceUnlockSecurityError.sessionKeyMissing }
            return SymmetricKey(data: data)
        }
        guard !deps.passwordFile.exists(), !deps.hasOtherSealedData() else {
            throw FaceUnlockSecurityError.sessionKeyMissing
        }
        let key = FaceUnlockCipher.makeKey()
        try deps.keychain.saveKey(key.withUnsafeBytes { Data($0) })
        // Read back: only a key that comes back is one the next launch can use.
        let stored = try deps.keychain.readKey()
        guard stored == key.withUnsafeBytes({ Data($0) }) else { throw FaceUnlockSecurityError.sessionKeyMissing }
        return key
    }

    private func finishUnlock(_ result: Result<SymmetricKey, FaceUnlockSecurityError>) {
        let opened: Bool
        let waiting: [(Bool) -> Void]
        (opened, waiting) = lock.withLock { () -> (Bool, [(Bool) -> Void]) in
            if case .success(let newKey) = result {
                key = newKey
                activityAt = deps.now()
            }
            defer { pendingUnlocks = [] }
            return (key != nil, pendingUnlocks)
        }
        deps.main {
            self.isAuthenticating = false
            self.isUnlocked = opened
            if case .failure(let error) = result { self.lastError = error }
            if opened { NotificationCenter.default.post(name: .faceUnlockSessionDidChange, object: self) }
            waiting.forEach { $0(opened) }
        }
    }

    private func finishTyping(_ error: FaceUnlockSecurityError?, _ completion: @escaping (Bool) -> Void) {
        deps.main {
            if let error { self.lastError = error }
            completion(error == nil)
        }
    }

    /// A successful use keeps an active session from locking itself.
    private func recordActivity() {
        lock.withLock { if key != nil { activityAt = deps.now() } }
    }
}

enum FaceUnlockSecurityError: Error, Equatable {
    case authenticationFailed
    case sessionLocked
    /// Sealed data exists but the key that reads it does not (or is broken).
    case sessionKeyMissing
    case keychain(OSStatus?)
    case emptyPassword
    case noPassword
    case encryptionFailed
    case decryptionFailed
    /// CGSession says the screen is not locked, so nothing is typed.
    case notLocked
    case accessibility
    case typingFailed
}

/// AES-GCM with a 256-bit key; the sealed form is nonce + ciphertext + tag.
enum FaceUnlockCipher {
    static func makeKey() -> SymmetricKey { SymmetricKey(size: .bits256) }

    static func seal(_ plaintext: Data, key: SymmetricKey) throws -> Data {
        guard let combined = try AES.GCM.seal(plaintext, using: key).combined else {
            throw FaceUnlockSecurityError.encryptionFailed
        }
        return combined
    }

    static func open(_ sealed: Data, key: SymmetricKey) throws -> Data {
        do {
            return try AES.GCM.open(AES.GCM.SealedBox(combined: sealed), using: key)
        } catch {
            throw FaceUnlockSecurityError.decryptionFailed
        }
    }
}

enum FaceUnlockAutoLocking {
    /// Glance's re-lock rule: idle since the last unlock or use for at least
    /// the limit. "Never" still loses the key when Zenith quits.
    static func shouldLock(lastActivity: Date?, now: Date, limit: FaceUnlockAutoLock) -> Bool {
        guard let lastActivity, let duration = limit.duration else { return false }
        return now.timeIntervalSince(lastActivity) >= duration
    }

    /// How often the idle check runs: coarse, since the shortest limit is a
    /// day and the decision compares timestamps. Also checked on wake.
    static let checkInterval: TimeInterval = 5 * 60
}

/// The login keychain item that holds the session key.
protocol FaceUnlockKeyStore: AnyObject {
    /// Attributes only: never reads the secret, never prompts.
    func keyExists() -> Bool
    func readKey() throws -> Data
    func saveKey(_ data: Data) throws
    func deleteKey() throws
}

/// The sealed password on disk.
protocol FaceUnlockBlobStore: AnyObject {
    func exists() -> Bool
    func read() -> Data?
    func write(_ data: Data) -> Bool
    func delete()
}

protocol FaceUnlockAuthenticating: AnyObject {
    /// Touch ID, or the account password where there is none; any thread.
    func authenticate(reason: String, completion: @escaping (Bool) -> Void)
}

protocol FaceUnlockPasswordTyping: AnyObject {
    /// Accessibility is granted (no prompt).
    var canType: Bool { get }
    /// Types the UTF-8 password into the focused field and presses Return. Blocking.
    func type(_ password: Data) throws
}

#if VORSSAINT_DEVELOPMENT
// Zenith fork: sample state for the island catalog's Settings renders
// (`--render-island-catalog`): a password on file, the session locked. No
// key, password or keychain is touched. The release build does not have it.
extension FaceUnlockSession {
    func catalogPose(hasPassword: Bool) {
        self.hasPassword = hasPassword
    }
}
#endif
