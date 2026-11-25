// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CryptoKit
import Foundation

/// Who sent an envelope.
public enum PocketSender: String, Codable, Sendable {
    case mac, phone, watch
}

/// What every sealed message carries besides its body: who sent it, when,
/// and a unique id, so a replayed or stale message can be refused.
public struct PocketEnvelope<Body: Codable & Sendable>: Codable, Sendable {
    public var id: UUID
    public var sentAt: Date
    public var from: PocketSender
    public var body: Body

    public init(id: UUID = UUID(), sentAt: Date = Date(), from: PocketSender, body: Body) {
        self.id = id
        self.sentAt = sentAt
        self.from = from
        self.body = body
    }
}

public enum PocketSealError: Error, Equatable {
    case cannotOpen
    case badPayload
}

/// Seals and opens envelopes with ChaCha20-Poly1305. The purpose (a box id
/// or "live") is bound in as associated data, so a sealed box cannot be
/// moved to another slot, and a live message cannot be replayed as a box.
public struct PocketSealer: Sendable {
    private let key: SymmetricKey

    public init(pairing: PocketPairing) { key = pairing.symmetricKey }
    public init(key: SymmetricKey) { self.key = key }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .millisecondsSince1970
        return e
    }()
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .millisecondsSince1970
        return d
    }()

    private func aad(_ purpose: String) -> Data { Data("zenith-pocket/v1/aad/\(purpose)".utf8) }

    /// Base64 of nonce ‖ ciphertext ‖ tag.
    public func seal<Body>(_ envelope: PocketEnvelope<Body>, purpose: String) throws -> String {
        let plain = try Self.encoder.encode(envelope)
        let box = try ChaChaPoly.seal(plain, using: key, authenticating: aad(purpose))
        return box.combined.base64EncodedString()
    }

    public func open<Body>(_ sealed: String, as: Body.Type, purpose: String) throws -> PocketEnvelope<Body> {
        guard let data = Data(base64Encoded: sealed),
              let box = try? ChaChaPoly.SealedBox(combined: data),
              let plain = try? ChaChaPoly.open(box, using: key, authenticating: aad(purpose)) else {
            throw PocketSealError.cannotOpen
        }
        do { return try Self.decoder.decode(PocketEnvelope<Body>.self, from: plain) }
        catch { throw PocketSealError.badPayload }
    }
}

/// Refuses a live message that is too old, from the future, or already seen.
/// Commands go through this so a recorded "lock" cannot be played back.
public struct PocketReplayGuard: Sendable {
    public var window: TimeInterval
    private var seen: [UUID: Date] = [:]

    public init(window: TimeInterval = 120) { self.window = window }

    public mutating func accept(id: UUID, sentAt: Date, now: Date = Date()) -> Bool {
        seen = seen.filter { now.timeIntervalSince($0.value) < window * 2 }
        guard abs(now.timeIntervalSince(sentAt)) <= window, seen[id] == nil else { return false }
        seen[id] = now
        return true
    }
}
