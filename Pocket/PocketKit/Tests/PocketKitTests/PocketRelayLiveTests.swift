// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation
import Testing
@testable import PocketKit

/// Talks to a real relay. Runs only when POCKET_RELAY_URL and POCKET_RELAY_KEY
/// are set, so no key is ever committed and CI stays offline.
private let liveRelay: PocketRelayConfig? = {
    let env = ProcessInfo.processInfo.environment
    guard let url = env["POCKET_RELAY_URL"].flatMap(URL.init(string:)), let key = env["POCKET_RELAY_KEY"] else { return nil }
    return PocketRelayConfig(url: url, anonKey: key)
}()

@Suite(.enabled(if: liveRelay != nil), .serialized) struct PocketRelayLiveTests {
    @Test func boxRoundTripsSealed() async throws {
        let pairing = PocketPairing.make(relay: liveRelay!, macName: "Test Mac")
        let mac = PocketLink(pairing: pairing, me: .mac)
        let phone = PocketLink(pairing: pairing, me: .phone)
        let state = PocketMacState(macName: "Test Mac", battery: .init(percent: 47, charging: true))
        try await mac.putBox(pairing.macBoxID, state)
        let read = try #require(try await phone.getBox(pairing.macBoxID, as: PocketMacState.self))
        #expect(read.body == state)
        #expect(read.from == .mac)
        let stranger = PocketLink(pairing: PocketPairing.make(relay: liveRelay!, macName: "x"), me: .phone)
        #expect(try await stranger.getBox(pairing.macBoxID, as: PocketMacState.self) == nil, "another key reads nothing")
    }

    @Test func liveMessageCrossesTheChannel() async throws {
        let pairing = PocketPairing.make(relay: liveRelay!, macName: "Test Mac")
        let mac = PocketLink(pairing: pairing, me: .mac)
        let phone = PocketLink(pairing: pairing, me: .phone)
        let received = Received()
        await mac.start(onLive: { env in Task { await received.add(env.body) } }, onStatus: { _ in })
        await phone.start(onLive: { _ in }, onStatus: { _ in })
        defer { Task { await mac.stop(); await phone.stop() } }

        // Wait for both joins, then send until the Mac hears it.
        for _ in 0..<40 {
            _ = try? await phone.send(.command(.refresh))
            if await received.items.contains(.command(.refresh)) { break }
            try await Task.sleep(nanoseconds: 250_000_000)
        }
        #expect(await received.items.contains(.command(.refresh)))
    }
}

private actor Received {
    var items: [PocketLive] = []
    func add(_ item: PocketLive) { items.append(item) }
}
