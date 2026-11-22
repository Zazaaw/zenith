// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Adapted from Glance by Jonathan Zhou (MIT), https://github.com/jonnyoo/glance
// (glance/FaceEnrollmentStore.swift, glance/SecureFaceStore.swift, glance/FaceRecognitionPipeline.swift).
//
// The enrolled identities, how a probe embedding is scored against them, and how
// they are sealed on disk. No camera, Vision or Core ML here, so it is testable.

import CryptoKit
import Foundation

struct FaceSample: Codable, Equatable {
    let embedding: [Float]
    /// Which guided-enrollment pose this came from, or nil for untagged captures (e.g. Face Lab's manual capture).
    let pose: String?
    let capturedAt: Date
    /// Vision's capture-quality score (0...1), or nil if unavailable.
    let quality: Float?
}

extension FaceSample {
    /// Lives here rather than in a view so Face Lab's debug list and the settings tick strip can't drift apart.
    enum QualityTier {
        /// No score recorded. Never counted as poor.
        case unrated
        case poor
        case fair
        case good
    }

    var qualityTier: QualityTier {
        guard let quality else { return .unrated }
        if quality < 0.4 { return .poor }
        if quality < 0.5 { return .fair }
        return .good
    }
}

struct FaceIdentity: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var samples: [FaceSample]
    /// Which `FaceEmbedder.modelIdentifier` produced these samples — different models' embeddings live in unrelated
    /// vector spaces. See `isStale(comparedTo:)`.
    var modelIdentifier: String
    var embeddingDimension: Int
    var createdAt: Date
    /// Turning off keeps the enrollment intact but excludes it from `activeIdentities`, which unlock scores against.
    var isEnabled: Bool

    init(
        id: UUID,
        name: String,
        samples: [FaceSample],
        modelIdentifier: String,
        embeddingDimension: Int,
        createdAt: Date,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.samples = samples
        self.modelIdentifier = modelIdentifier
        self.embeddingDimension = embeddingDimension
        self.createdAt = createdAt
        self.isEnabled = isEnabled
    }

    /// Hand-written so `isEnabled` defaults to `true` when absent — a synthesized decoder would throw on a missing
    /// key and, since the whole store decodes as one array, lose every identity in it.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        samples = try container.decode([FaceSample].self, forKey: .samples)
        modelIdentifier = try container.decode(String.self, forKey: .modelIdentifier)
        embeddingDimension = try container.decode(Int.self, forKey: .embeddingDimension)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
    }

    /// The single vector actually compared against at recognition time.
    var template: [Float]? {
        FaceEmbedding.average(samples.map(\.embedding))
    }

    /// True if samples came from a different embedder than the one currently active — should prompt re-enrollment.
    func isStale(comparedTo embedder: FaceEmbedder) -> Bool {
        isStale(modelIdentifier: embedder.modelIdentifier)
    }

    func isStale(modelIdentifier current: String) -> Bool {
        modelIdentifier != current
    }

    /// How many distinct guided poses the samples cover.
    var posesCaptured: Int {
        Set(samples.compactMap(\.pose)).count
    }
}

struct ScoredIdentity {
    let identity: FaceIdentity
    /// Similarity against the identity's averaged template.
    let centroidSimilarity: Float
    /// Similarity against the single closest individual sample — catches
    /// cases where averaging blurred together poses that shouldn't be
    /// blended.
    let maxSampleSimilarity: Float
}

/// Zenith fork: Glance's `FaceRecognitionPipeline.score` / `bestMatch`, free of the embedder.
enum FaceMatching {
    /// Sorted by centroid similarity descending; includes stale identities (different embedder) since `bestMatch` is what excludes them from actually matching.
    static func score(_ embedding: [Float], against identities: [FaceIdentity]) -> [ScoredIdentity] {
        identities.compactMap { identity in
            guard let template = identity.template, !identity.samples.isEmpty else { return nil }
            let centroidSim = FaceEmbedding.cosineSimilarity(embedding, template)
            let maxSim = identity.samples
                .map { FaceEmbedding.cosineSimilarity(embedding, $0.embedding) }
                .max() ?? centroidSim
            return ScoredIdentity(identity: identity, centroidSimilarity: centroidSim, maxSampleSimilarity: maxSim)
        }.sorted { $0.centroidSimilarity > $1.centroidSimilarity }
    }

    /// No runner-up margin check: the same person can be enrolled multiple times under different appearances, so two
    /// of their own profiles legitimately score close together — a margin check can't tell that apart from two
    /// different people colliding.
    static func bestMatch(in scored: [ScoredIdentity], threshold: Float, modelIdentifier: String) -> ScoredIdentity? {
        guard let first = scored.first, !first.identity.isStale(modelIdentifier: modelIdentifier) else { return nil }
        guard first.centroidSimilarity >= threshold, first.maxSampleSimilarity >= threshold else { return nil }
        return first
    }
}

/// Zenith fork: the name rule on its own, so it is testable.
enum FaceEnrollmentNames {
    static func isTaken(_ name: String, among identities: [FaceIdentity], excluding id: UUID? = nil) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return identities.contains {
            $0.id != id
                && $0.name.compare(trimmed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }
}

enum SecureFaceStoreError: LocalizedError {
    case sessionLocked
    case encryptionFailed
    case decryptionFailed

    var errorDescription: String? {
        switch self {
        case .sessionLocked:
            return "Session is locked. Authenticate with Touch ID to access enrolled faces."
        case .encryptionFailed:
            return "Your enrolled faces couldn't be encrypted, so nothing was saved."
        case .decryptionFailed:
            return "Your enrolled faces couldn't be decrypted. The stored data may be corrupted, or it was saved under a different session key."
        }
    }
}

/// AES-GCM under the session key, as Glance's `SecureCredentialManager.encrypt` / `decrypt`. No plaintext fallback.
enum FaceIdentitySealing {
    static func seal(_ identities: [FaceIdentity], key: SymmetricKey) throws -> Data {
        let plaintext = try JSONEncoder().encode(identities)
        guard let combined = try AES.GCM.seal(plaintext, using: key).combined else {
            throw SecureFaceStoreError.encryptionFailed
        }
        return combined
    }

    static func open(_ ciphertext: Data, key: SymmetricKey) throws -> [FaceIdentity] {
        let plaintext: Data
        do {
            plaintext = try AES.GCM.open(AES.GCM.SealedBox(combined: ciphertext), using: key)
        } catch {
            throw SecureFaceStoreError.decryptionFailed
        }
        return try JSONDecoder().decode([FaceIdentity].self, from: plaintext)
    }
}
