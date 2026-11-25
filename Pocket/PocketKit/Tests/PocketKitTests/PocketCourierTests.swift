// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation
import Testing
@testable import PocketKit

private let relay = PocketRelayConfig(url: URL(string: "https://example.supabase.co")!,
                                      anonKey: "eyJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoiYW5vbiJ9.c2lnbmF0dXJl")

@Suite struct BroadcastTests {
    let pairing = PocketPairing.make(relay: relay, macName: "Mac")

    @Test func postsToRealtimeRESTBroadcastWithTheKeys() throws {
        let r = try PocketBroadcastClient.request(relay: relay, channel: pairing.channelName, sealed: "abc")
        #expect(r.url?.absoluteString == "https://example.supabase.co/realtime/v1/api/broadcast")
        #expect(r.httpMethod == "POST")
        #expect(r.value(forHTTPHeaderField: "apikey") == relay.anonKey)
        #expect(r.value(forHTTPHeaderField: "Authorization") == "Bearer \(relay.anonKey)")
        #expect(r.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let data = try #require(r.httpBody)
        let body = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let messages = try #require(body["messages"] as? [[String: Any]])
        #expect(messages.count == 1)
        let message = messages[0]
        #expect(message["topic"] as? String == pairing.channelName, "the channel's name, without the socket's realtime: prefix")
        #expect(message["event"] as? String == "m")
        #expect(message["private"] as? Bool == false, "the public channel the socket joins")
        #expect(message["payload"] as? [String: String] == ["s": "abc"])
    }

    /// What Realtime hands a socket listener for a REST message: the socket's
    /// own topic, a `broadcast` frame, and the message's event and payload.
    @Test func reachesASocketListenerAsAnOrdinaryMessage() throws {
        let courier = PocketCourier(pairing: pairing, me: .watch)
        let envelope = PocketEnvelope(from: .watch, body: PocketLive.command(.lock))
        let sealed = try courier.seal(envelope)
        let body = PocketBroadcastClient.body(channel: pairing.channelName, sealed: sealed)
        let message = try #require((body["messages"] as? [[String: Any]])?.first)
        let delivered: [String: Any] = [
            "topic": "realtime:" + (message["topic"] as? String ?? ""),
            "event": "broadcast",
            "ref": NSNull(),
            "payload": ["type": "broadcast", "event": message["event"] as Any, "payload": message["payload"] as Any],
        ]
        let frame = PocketRealtime.json(delivered)
        let topic = "realtime:" + pairing.channelName
        #expect(PocketRealtime.parse(frame, topic: topic, joinRef: "1") == .message(sealed))
        let opened = try PocketSealer(pairing: pairing).open(sealed, as: PocketLive.self, purpose: PocketPurpose.live)
        #expect(opened.body == .command(.lock))
        #expect(opened.from == .watch)
        #expect(opened.id == envelope.id)
    }

    @Test func throwsOnARefusal() async throws {
        let session = StubProtocol.session()
        StubProtocol.status = 202
        let client = PocketBroadcastClient(relay: relay, channel: pairing.channelName, session: session)
        try await client.send("abc")
        #expect(StubProtocol.lastPath == "/realtime/v1/api/broadcast")
        StubProtocol.status = 401
        await #expect(throws: PocketRelayError.http(401)) { try await client.send("abc") }
    }
}

/// Answers every request with `status` and an empty body.
private final class StubProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var status = 200
    nonisolated(unsafe) static var lastPath: String?

    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastPath = request.url?.path
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
