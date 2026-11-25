// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// One side of a pairing, ready to talk: it seals what it sends, opens and
/// checks what it receives, and keeps the boxes. Zenith runs one as `.mac`,
/// the iPhone app as `.phone`.
public actor PocketLink {
    public enum Status: Sendable, Equatable {
        case connecting
        case live
        case offline
    }

    public nonisolated let pairing: PocketPairing
    public nonisolated let me: PocketSender
    private let sealer: PocketSealer
    private let boxes: PocketBoxClient
    private let realtime: PocketRealtime
    private var guardian = PocketReplayGuard()
    private var onLive: (@Sendable (PocketEnvelope<PocketLive>) -> Void)?
    private var onStatus: (@Sendable (Status) -> Void)?

    public init(pairing: PocketPairing, me: PocketSender, session: URLSession = .shared) {
        self.pairing = pairing
        self.me = me
        sealer = PocketSealer(pairing: pairing)
        boxes = PocketBoxClient(relay: pairing.relay, session: session)
        realtime = PocketRealtime(relay: pairing.relay, channel: pairing.channelName, session: session)
    }

    public func start(onLive: @escaping @Sendable (PocketEnvelope<PocketLive>) -> Void,
                      onStatus: @escaping @Sendable (Status) -> Void) async {
        self.onLive = onLive
        self.onStatus = onStatus
        onStatus(.connecting)
        await realtime.start { [weak self] event in
            Task { await self?.handle(event) }
        }
    }

    public func stop() async {
        await realtime.stop()
        onStatus?(.offline)
    }

    /// Sends a live message; returns its id (a command's result names it).
    @discardableResult
    public func send(_ live: PocketLive) async throws -> UUID {
        let envelope = PocketEnvelope(from: me, body: live)
        try await realtime.send(try sealer.seal(envelope, purpose: PocketPurpose.live))
        return envelope.id
    }

    public func putBox<Body: Codable & Sendable>(_ id: String, _ body: Body) async throws {
        let sealed = try sealer.seal(PocketEnvelope(from: me, body: body), purpose: PocketPurpose.box(id))
        try await boxes.put(id: id, sealed: sealed)
    }

    /// The box's body and when it was written; nil when empty, unreadable
    /// (another pairing's key), or written by this same side.
    public func getBox<Body: Codable & Sendable>(_ id: String, as type: Body.Type) async throws -> PocketEnvelope<Body>? {
        guard let stored = try await boxes.get(id: id) else { return nil }
        guard let envelope = try? sealer.open(stored.sealed, as: type, purpose: PocketPurpose.box(id)) else { return nil }
        return envelope
    }

    private func handle(_ event: PocketRealtime.Event) {
        switch event {
        case .joined:
            onStatus?(.live)
        case .disconnected:
            onStatus?(.connecting)
        case .message(let sealed):
            guard let envelope = try? sealer.open(sealed, as: PocketLive.self, purpose: PocketPurpose.live),
                  envelope.from != me else { return }
            // Commands and answers must be fresh and unseen; state may be late.
            if case .command = envelope.body {
                guard guardian.accept(id: envelope.id, sentAt: envelope.sentAt) else { return }
            }
            onLive?(envelope)
        }
    }
}
