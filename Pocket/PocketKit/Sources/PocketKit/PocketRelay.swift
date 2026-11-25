// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

public enum PocketRelayError: Error, Equatable {
    case http(Int)
    case badResponse
    case notJoined
}

// MARK: Boxes (REST)

/// The last state of each side, through the two relay functions
/// (`pocket_put`, `pocket_get`). Bodies are already sealed.
public struct PocketBoxClient: Sendable {
    public let relay: PocketRelayConfig
    private let session: URLSession

    public init(relay: PocketRelayConfig, session: URLSession = .shared) {
        self.relay = relay
        self.session = session
    }

    private func request(_ function: String, _ body: [String: String]) throws -> URLRequest {
        var r = URLRequest(url: relay.url.appendingPathComponent("rest/v1/rpc/\(function)"))
        r.httpMethod = "POST"
        r.timeoutInterval = 15
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.setValue(relay.anonKey, forHTTPHeaderField: "apikey")
        r.setValue("Bearer \(relay.anonKey)", forHTTPHeaderField: "Authorization")
        r.httpBody = try JSONSerialization.data(withJSONObject: body)
        return r
    }

    public func put(id: String, sealed: String) async throws {
        let (_, response) = try await session.data(for: try request("pocket_put", ["p_id": id, "p_box": sealed]))
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else { throw PocketRelayError.http(code) }
    }

    /// nil when the box was never written (or swept after 30 days).
    public func get(id: String) async throws -> (sealed: String, updatedAt: Date)? {
        let (data, response) = try await session.data(for: try request("pocket_get", ["p_id": id]))
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else { throw PocketRelayError.http(code) }
        return try Self.parseGet(data)
    }

    static func parseGet(_ data: Data) throws -> (sealed: String, updatedAt: Date)? {
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { throw PocketRelayError.badResponse }
        guard let row = rows.first else { return nil }
        guard let box = row["box"] as? String, let stamp = row["updated_at"] as? String,
              let date = parseTimestamp(stamp) else { throw PocketRelayError.badResponse }
        return (box, date)
    }

    /// Postgres timestamptz as PostgREST prints it ("2026-11-25T09:40:12.123456+00:00").
    static func parseTimestamp(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }
}

// MARK: Live (Realtime Broadcast)

/// A Supabase Realtime Broadcast channel, spoken directly over a WebSocket
/// (Phoenix protocol), so neither app needs the Supabase SDK. It rejoins on
/// its own with a growing delay, and heartbeats every 25 seconds.
public actor PocketRealtime {
    public enum Event: Sendable, Equatable {
        case joined
        case message(String)
        case disconnected
    }

    private let relay: PocketRelayConfig
    private let topic: String
    private let session: URLSession
    private var onEvent: (@Sendable (Event) -> Void)?
    private var task: URLSessionWebSocketTask?
    private var heartbeat: Task<Void, Never>?
    private var reconnect: Task<Void, Never>?
    private var ref = 0
    private var joinRef = ""
    private var joined = false
    private var running = false
    private var attempt = 0

    public init(relay: PocketRelayConfig, channel: String, session: URLSession = .shared) {
        self.relay = relay
        self.topic = "realtime:" + channel
        self.session = session
    }

    public var isJoined: Bool { joined }

    public func start(onEvent: @escaping @Sendable (Event) -> Void) {
        self.onEvent = onEvent
        running = true
        connect()
    }

    public func stop() {
        running = false
        reconnect?.cancel(); reconnect = nil
        heartbeat?.cancel(); heartbeat = nil
        task?.cancel(with: .goingAway, reason: nil); task = nil
        if joined { joined = false; onEvent?(.disconnected) }
    }

    /// Sends a sealed body to whoever else is on the channel.
    public func send(_ sealed: String) async throws {
        guard joined, let task else { throw PocketRelayError.notJoined }
        let frame: [String: Any] = [
            "topic": topic, "event": "broadcast", "ref": nextRef(), "join_ref": joinRef,
            "payload": ["type": "broadcast", "event": "m", "payload": ["s": sealed]],
        ]
        try await task.send(.string(Self.json(frame)))
    }

    // MARK: Connection

    static func socketURL(_ relay: PocketRelayConfig) -> URL? {
        guard var c = URLComponents(url: relay.url.appendingPathComponent("realtime/v1/websocket"), resolvingAgainstBaseURL: false) else { return nil }
        c.scheme = "wss"
        c.queryItems = [URLQueryItem(name: "apikey", value: relay.anonKey), URLQueryItem(name: "vsn", value: "1.0.0")]
        return c.url
    }

    private func connect() {
        guard running, let url = Self.socketURL(relay) else { return }
        let task = session.webSocketTask(with: url)
        self.task = task
        task.resume()
        joinRef = nextRef()
        let join: [String: Any] = [
            "topic": topic, "event": "phx_join", "ref": joinRef, "join_ref": joinRef,
            "payload": [
                "config": ["broadcast": ["self": false, "ack": false], "presence": ["key": ""], "private": false],
                "access_token": relay.anonKey,
            ],
        ]
        let text = Self.json(join)
        Task { [weak self] in
            do { try await task.send(.string(text)) } catch { await self?.lost(task) }
        }
        receive(on: task)
        heartbeat?.cancel()
        heartbeat = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 25_000_000_000)
                guard !Task.isCancelled else { return }
                await self?.beat(task)
            }
        }
    }

    private func beat(_ task: URLSessionWebSocketTask) async {
        guard task === self.task else { return }
        let frame: [String: Any] = ["topic": "phoenix", "event": "heartbeat", "payload": [String: Any](), "ref": nextRef()]
        do { try await task.send(.string(Self.json(frame))) } catch { lost(task) }
    }

    private func receive(on task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            Task { [weak self] in
                guard let self else { return }
                switch result {
                case .success(let message):
                    if case .string(let text) = message { await self.handle(text) }
                    await self.receiveIfCurrent(task)
                case .failure:
                    await self.lost(task)
                }
            }
        }
    }

    private func receiveIfCurrent(_ task: URLSessionWebSocketTask) {
        guard task === self.task else { return }
        receive(on: task)
    }

    private func handle(_ text: String) {
        switch Self.parse(text, topic: topic, joinRef: joinRef) {
        case .joined?:
            joined = true
            attempt = 0
            onEvent?(.joined)
        case .message(let sealed)?:
            onEvent?(.message(sealed))
        case .closed?:
            if let task { lost(task) }
        case nil:
            break
        }
    }

    private func lost(_ task: URLSessionWebSocketTask) {
        guard task === self.task else { return }
        self.task = nil
        task.cancel(with: .abnormalClosure, reason: nil)
        heartbeat?.cancel(); heartbeat = nil
        if joined { joined = false; onEvent?(.disconnected) }
        guard running else { return }
        let delays: [UInt64] = [1, 2, 5, 10, 30]
        let delay = delays[min(attempt, delays.count - 1)]
        attempt += 1
        reconnect = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay * 1_000_000_000)
            guard !Task.isCancelled else { return }
            await self?.connect()
        }
    }

    private func nextRef() -> String {
        ref += 1
        return String(ref)
    }

    // MARK: Frames

    enum Incoming: Equatable {
        case joined
        case message(String)
        case closed
    }

    /// Reads one Phoenix frame for this topic.
    static func parse(_ text: String, topic: String, joinRef: String) -> Incoming? {
        guard let data = text.data(using: .utf8),
              let frame = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              frame["topic"] as? String == topic,
              let event = frame["event"] as? String else { return nil }
        let payload = frame["payload"] as? [String: Any]
        switch event {
        case "phx_reply":
            guard frame["ref"] as? String == joinRef else { return nil }
            return payload?["status"] as? String == "ok" ? .joined : .closed
        case "broadcast":
            guard payload?["event"] as? String == "m",
                  let inner = payload?["payload"] as? [String: Any],
                  let sealed = inner["s"] as? String else { return nil }
            return .message(sealed)
        case "phx_close", "phx_error":
            return .closed
        default:
            return nil
        }
    }

    static func json(_ object: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }
}
