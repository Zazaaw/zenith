// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// MARK: Live (REST broadcast)

/// What every live message looks like inside a Realtime broadcast, whichever
/// way it is sent: the event `m` and a payload holding the sealed body. The
/// socket (`PocketRealtime`) and the REST sender below both build it here,
/// so a listener can't tell which way a message came.
public enum PocketBroadcastFrame {
    public static let event = "m"
    public static func payload(_ sealed: String) -> [String: String] { ["s": sealed] }
}

/// Sends live messages with one HTTPS request each, through Supabase
/// Realtime's REST broadcast (`POST /realtime/v1/api/broadcast`), for a side
/// that can't keep a socket open (watchOS limits WebSockets for ordinary
/// apps). It reaches the same public channel the socket joins: the topic is
/// the channel's name (the socket adds `realtime:` in front), and the
/// message arrives there as an ordinary broadcast `m`. It can only speak,
/// never listen.
public struct PocketBroadcastClient: Sendable {
    public let relay: PocketRelayConfig
    public let channel: String
    private let session: URLSession

    public init(relay: PocketRelayConfig, channel: String, session: URLSession = .shared) {
        self.relay = relay
        self.channel = channel
        self.session = session
    }

    public func send(_ sealed: String) async throws {
        let (_, response) = try await session.data(for: try Self.request(relay: relay, channel: channel, sealed: sealed))
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else { throw PocketRelayError.http(code) }
    }

    static func url(_ relay: PocketRelayConfig) -> URL {
        relay.url.appendingPathComponent("realtime/v1/api/broadcast")
    }

    static func request(relay: PocketRelayConfig, channel: String, sealed: String) throws -> URLRequest {
        var r = URLRequest(url: url(relay))
        r.httpMethod = "POST"
        r.timeoutInterval = 15
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.setValue(relay.anonKey, forHTTPHeaderField: "apikey")
        r.setValue("Bearer \(relay.anonKey)", forHTTPHeaderField: "Authorization")
        r.httpBody = try JSONSerialization.data(withJSONObject: body(channel: channel, sealed: sealed), options: [.sortedKeys])
        return r
    }

    /// `{"messages":[{"topic":…,"event":"m","payload":{"s":…},"private":false}]}`
    static func body(channel: String, sealed: String) -> [String: Any] {
        let message: [String: Any] = [
            "topic": channel,
            "event": PocketBroadcastFrame.event,
            "payload": PocketBroadcastFrame.payload(sealed),
            "private": false,
        ]
        return ["messages": [message]]
    }
}

// MARK: Courier

/// One side of a pairing that talks over plain HTTPS only (the Watch and its
/// complications): it seals and sends live messages through REST broadcast
/// and reads boxes, but hears nothing live, so a command's effect is read
/// back from the Mac's next state instead of its reply.
public struct PocketCourier: Sendable {
    public let pairing: PocketPairing
    public let me: PocketSender
    private let sealer: PocketSealer
    private let boxes: PocketBoxClient
    private let broadcast: PocketBroadcastClient

    public init(pairing: PocketPairing, me: PocketSender, session: URLSession = .shared) {
        self.pairing = pairing
        self.me = me
        sealer = PocketSealer(pairing: pairing)
        boxes = PocketBoxClient(relay: pairing.relay, session: session)
        broadcast = PocketBroadcastClient(relay: pairing.relay, channel: pairing.channelName, session: session)
    }

    /// Seals a live message as `PocketLink.send` does; returns its id.
    @discardableResult
    public func send(_ live: PocketLive) async throws -> UUID {
        let envelope = PocketEnvelope(from: me, body: live)
        try await broadcast.send(try seal(envelope))
        return envelope.id
    }

    func seal(_ envelope: PocketEnvelope<PocketLive>) throws -> String {
        try sealer.seal(envelope, purpose: PocketPurpose.live)
    }

    /// The box's body; nil when empty or unreadable (another pairing's key).
    public func getBox<Body: Codable & Sendable>(_ id: String, as type: Body.Type) async throws -> PocketEnvelope<Body>? {
        guard let stored = try await boxes.get(id: id) else { return nil }
        return try? sealer.open(stored.sealed, as: type, purpose: PocketPurpose.box(id))
    }

    /// The Mac's last state, when the Mac wrote it.
    public func macState() async throws -> PocketEnvelope<PocketMacState>? {
        guard let envelope = try await getBox(pairing.macBoxID, as: PocketMacState.self), envelope.from == .mac else { return nil }
        return envelope
    }
}
