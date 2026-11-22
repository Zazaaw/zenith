// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Adapted from Glance by Jonathan Zhou (MIT), https://github.com/jonnyoo/glance
// (glance/FaceEnrollmentStore.swift, glance/SecureFaceStore.swift).
//
// Persisted encrypted under the same Touch-ID-gated session key as the stored Mac password (see SecureFaceStore);
// `isLocked`/`reloadIfUnlocked()` let the UI distinguish "locked" from "nothing enrolled."

import Combine
import CryptoKit
import Foundation

enum FaceEnrollmentStoreError: LocalizedError {
    case storeUnreadable

    var errorDescription: String? {
        switch self {
        case .storeUnreadable:
            return "Your enrolled faces couldn't be read, so nothing was saved — writing now would overwrite them."
        }
    }
}

/// Zenith fork: Glance's `@Observable FaceEnrollmentStore` as an `ObservableObject`.
@MainActor
final class FaceEnrollmentStore: ObservableObject {
    /// Shared so Face Lab, enrollment and unlock observe and persist the same identities, not diverging copies.
    static let shared = FaceEnrollmentStore()

    @Published private(set) var identities: [FaceIdentity] = []
    /// True until a successful load — distinguishes "nothing enrolled yet" from "locked, needs Touch ID."
    @Published private(set) var isLocked = true

    /// Non-nil when unlocked but the encrypted store still couldn't be read (decrypt/decode failure, not a missing key) —
    /// unlike `isLocked`, unlocking again won't fix this.
    @Published private(set) var loadFailure: String?

    /// False until a load succeeds. Guards `persist()` so an unreadable store is never overwritten by an empty array.
    private var hasLoadedSuccessfully = false
    private var sessionObserver: NSObjectProtocol?

    /// Everyone the user hasn't switched off — what unlock actually scores against. `identities` stays the full list.
    var activeIdentities: [FaceIdentity] {
        identities.filter(\.isEnabled)
    }

    private init() {
        reloadIfUnlocked()
        // Reload whenever the session key changes, regardless of call site, so this store can't go stale
        // relative to whichever UI changed the session.
        sessionObserver = NotificationCenter.default.addObserver(
            forName: .faceUnlockSessionDidChange,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reloadIfUnlocked()
            }
        }
    }

    /// Re-attempts loading from encrypted storage. A no-op (leaves
    /// `isLocked = true`) if the session isn't unlocked yet. Locking the session
    /// again drops the decrypted identities from memory.
    func reloadIfUnlocked() {
        guard FaceUnlockKeys.isSessionUnlocked else {
            isLocked = true
            identities = []
            hasLoadedSuccessfully = false
            loadFailure = nil
            return
        }
        do {
            identities = try SecureFaceStore.load()
            hasLoadedSuccessfully = true
            loadFailure = nil
        } catch {
            // Deliberately not `(try? load()) ?? []` — a store we couldn't read isn't an empty store, and the next
            // write must not persist an empty array over a file that still holds every sample.
            identities = []
            hasLoadedSuccessfully = false
            loadFailure = error.localizedDescription
        }
        isLocked = false
    }

    /// Adds one captured sample to `name`'s identity (creating it if new). Existing samples from a different embedder
    /// are discarded first, since mixing them would corrupt the template.
    @discardableResult
    func addSample(name: String, embedding: [Float], embedder: FaceEmbedder, pose: String? = nil, quality: Float? = nil) throws -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let sample = FaceSample(embedding: embedding, pose: pose, capturedAt: Date(), quality: quality)

        var updated = identities
        if let index = updated.firstIndex(where: { $0.name == trimmed }) {
            if updated[index].modelIdentifier != embedder.modelIdentifier {
                updated[index].samples = [sample]
            } else {
                updated[index].samples.append(sample)
            }
            updated[index].modelIdentifier = embedder.modelIdentifier
            updated[index].embeddingDimension = embedder.embeddingDimension
        } else {
            updated.append(FaceIdentity(
                id: UUID(),
                name: trimmed,
                samples: [sample],
                modelIdentifier: embedder.modelIdentifier,
                embeddingDimension: embedder.embeddingDimension,
                createdAt: Date()
            ))
        }
        try persist(updated)
        return true
    }

    /// Commits a whole guided enrollment in a single write. When `existingID` names a known identity, its samples are
    /// replaced wholesale (a recapture is a redo, not an append) and it can be renamed since matching is by id.
    @discardableResult
    func commitEnrollment(
        replacing existingID: UUID?,
        name: String,
        samples: [FaceSample],
        embedder: FaceEmbedder
    ) throws -> FaceIdentity? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !samples.isEmpty else { return nil }

        // Local copy, only assigned once the write succeeds — otherwise a locked session would show an unsaved save.
        var updated = identities
        let committed: FaceIdentity
        if let existingID, let index = updated.firstIndex(where: { $0.id == existingID }) {
            updated[index].name = trimmed
            updated[index].samples = samples
            updated[index].modelIdentifier = embedder.modelIdentifier
            updated[index].embeddingDimension = embedder.embeddingDimension
            committed = updated[index]
        } else {
            // Also the fallback if `existingID` no longer resolves (deleted mid-flow) — saving as new beats discarding.
            committed = FaceIdentity(
                id: UUID(),
                name: trimmed,
                samples: samples,
                modelIdentifier: embedder.modelIdentifier,
                embeddingDimension: embedder.embeddingDimension,
                createdAt: Date()
            )
            updated.append(committed)
        }
        try persist(updated)
        return committed
    }

    /// Case- and diacritic-insensitive, unlike `addSample`'s exact match: "alex"/"Alex"/"Álex" are one person to the
    /// user even though storage would treat them as separate identities. `excluding` lets a recapture keep its own name.
    func nameIsTaken(_ name: String, excluding id: UUID? = nil) -> Bool {
        FaceEnrollmentNames.isTaken(name, among: identities, excluding: id)
    }

    /// Zenith fork: renames without recapturing. Returns false for an empty name
    /// or one already taken by someone else.
    @discardableResult
    func rename(_ identityID: UUID, to name: String) throws -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !nameIsTaken(trimmed, excluding: identityID),
              let index = identities.firstIndex(where: { $0.id == identityID }) else { return false }
        var updated = identities
        updated[index].name = trimmed
        try persist(updated)
        return true
    }

    /// Writes before showing the change, rather than showing a toggle state that isn't on disk.
    func setEnabled(_ isEnabled: Bool, for identityID: UUID) throws {
        guard let index = identities.firstIndex(where: { $0.id == identityID }) else { return }
        guard identities[index].isEnabled != isEnabled else { return }
        var updated = identities
        updated[index].isEnabled = isEnabled
        try persist(updated)
    }

    func delete(_ identity: FaceIdentity) throws {
        var updated = identities
        updated.removeAll { $0.id == identity.id }
        try persist(updated)
    }

    /// Removes the file outright (rather than writing an empty array) — the teardown path when the session key
    /// itself is being removed, so no orphaned encrypted file is left behind for the next setup to trip over.
    func deleteAll() {
        identities.removeAll()
        SecureFaceStore.deleteAll()
        loadFailure = nil
        hasLoadedSuccessfully = true
    }

    private func persist(_ updated: [FaceIdentity]) throws {
        // Refuses to write when the last load failed, so an unreadable store can't be silently replaced by an empty array.
        guard hasLoadedSuccessfully else {
            throw FaceEnrollmentStoreError.storeUnreadable
        }
        try SecureFaceStore.save(updated)
        identities = updated
    }
}

/// Low-level encrypted persistence for enrolled face identities — AES-GCM under the session key the security side
/// also uses for the Mac password, rather than a second key. `FaceEnrollmentStore` delegates its load/save here.
enum SecureFaceStore {
    /// Distinct filename/extension so plaintext can never be mistaken for ciphertext.
    /// `~/Library/Application Support/<bundle id>/FaceUnlock/face-identities.enc`.
    static var fileURL: URL? {
        PrivateFileStore.containerURL?
            .appendingPathComponent("FaceUnlock", isDirectory: true)
            .appendingPathComponent("face-identities.enc")
    }

    /// True if a store exists on disk, regardless of whether the session is currently unlocked enough to read it.
    /// The security side checks this before minting a new session key, which would make the store unreadable.
    static var exists: Bool {
        guard let fileURL else { return false }
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    /// Throws `.sessionLocked` rather than returning an empty array, so callers can distinguish "nothing enrolled" from "enrolled, but locked".
    static func load() throws -> [FaceIdentity] {
        guard let key = FaceUnlockKeys.sessionKey else { throw SecureFaceStoreError.sessionLocked }
        guard let fileURL, let ciphertext = try? Data(contentsOf: fileURL) else { return [] }
        return try FaceIdentitySealing.open(ciphertext, key: key)
    }

    static func save(_ identities: [FaceIdentity]) throws {
        guard let key = FaceUnlockKeys.sessionKey else { throw SecureFaceStoreError.sessionLocked }
        guard let fileURL else { throw CocoaError(.fileWriteNoPermission) }
        let ciphertext = try FaceIdentitySealing.seal(identities, key: key)
        guard PrivateFileStore.createDirectory(at: fileURL.deletingLastPathComponent()),
              PrivateFileStore.write(ciphertext, to: fileURL) else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: fileURL.path])
        }
    }

    static func deleteAll() {
        guard let fileURL else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }
}
