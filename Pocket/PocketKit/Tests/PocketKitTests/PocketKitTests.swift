// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import CryptoKit
import Foundation
import Testing
@testable import PocketKit

private let relay = PocketRelayConfig(url: URL(string: "https://example.supabase.co")!,
                                      anonKey: "eyJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoiYW5vbiJ9.c2lnbmF0dXJl")

@Suite struct PairingTests {
    @Test func roundTripsThroughTheQRCode() throws {
        let pairing = PocketPairing.make(relay: relay, macName: "Faiz’s MacBook Pro")
        let read = try #require(PocketPairing(url: pairing.url))
        #expect(read == pairing)
        #expect(pairing.url.absoluteString.count < 600, "fits a QR code a phone reads at a glance")
    }

    @Test func refusesMalformedCodes() {
        let good = PocketPairing.make(relay: relay, macName: "Mac").url.absoluteString
        #expect(PocketPairing(url: URL(string: good.replacingOccurrences(of: "v=1", with: "v=2"))!) == nil)
        #expect(PocketPairing(url: URL(string: good.replacingOccurrences(of: "zenith-pocket", with: "https"))!) == nil)
        #expect(PocketPairing(url: URL(string: "zenith-pocket://pair?v=1&u=https://x.supabase.co&a=a.b.c&p=AAAA&k=AAAA")!) == nil,
                "keys must be 32 bytes")
        #expect(PocketPairing(url: URL(string: good.replacingOccurrences(of: "u=https", with: "u=http"))!) == nil,
                "the relay must be https")
    }

    @Test func derivesDistinctUnguessableNames() {
        let a = PocketPairing.make(relay: relay, macName: "Mac")
        let b = PocketPairing.make(relay: relay, macName: "Mac")
        let ids = [a.macBoxID, a.phoneBoxID, a.wallpaperBoxID]
        #expect(Set(ids).count == 3)
        #expect(ids.allSatisfy { $0.count == 64 && $0.allSatisfy(\.isHexDigit) }, "matches the SQL check")
        #expect(a.macBoxID != b.macBoxID && a.channelName != b.channelName)
        #expect(!a.channelName.contains(a.pairID.base64URL), "the secret never appears in a name")
    }
}

@Suite struct SealTests {
    let pairing = PocketPairing.make(relay: relay, macName: "Mac")

    @Test func sealsAndOpens() throws {
        let sealer = PocketSealer(pairing: pairing)
        let state = PocketMacState(macName: "Mac", battery: .init(percent: 47, charging: true, minutesRemaining: 72))
        let sealed = try sealer.seal(PocketEnvelope(from: .mac, body: PocketLive.macState(state)), purpose: PocketPurpose.live)
        #expect(!sealed.contains("47") || Data(base64Encoded: sealed) != nil)
        let opened = try sealer.open(sealed, as: PocketLive.self, purpose: PocketPurpose.live)
        #expect(opened.body == .macState(state))
        #expect(opened.from == .mac)
    }

    @Test func anotherKeyOrSlotCannotOpen() throws {
        let sealed = try PocketSealer(pairing: pairing).seal(PocketEnvelope(from: .phone, body: PocketLive.command(.lock)), purpose: PocketPurpose.live)
        let stranger = PocketSealer(pairing: PocketPairing.make(relay: relay, macName: "Other"))
        #expect(throws: PocketSealError.cannotOpen) { try stranger.open(sealed, as: PocketLive.self, purpose: PocketPurpose.live) }
        #expect(throws: PocketSealError.cannotOpen) {
            try PocketSealer(pairing: pairing).open(sealed, as: PocketLive.self, purpose: PocketPurpose.box(pairing.macBoxID))
        }
    }

    @Test func tamperingIsCaught() throws {
        let sealer = PocketSealer(pairing: pairing)
        var bytes = try #require(Data(base64Encoded: try sealer.seal(PocketEnvelope(from: .phone, body: PocketLive.command(.lock)), purpose: "live")))
        bytes[bytes.count / 2] ^= 0x01
        #expect(throws: PocketSealError.cannotOpen) { try sealer.open(bytes.base64EncodedString(), as: PocketLive.self, purpose: "live") }
    }

    @Test func replayGuardRefusesOldAndRepeated() {
        var guardian = PocketReplayGuard(window: 120)
        let now = Date()
        let id = UUID()
        let first = guardian.accept(id: id, sentAt: now, now: now)
        let again = guardian.accept(id: id, sentAt: now, now: now.addingTimeInterval(5))
        let old = guardian.accept(id: UUID(), sentAt: now.addingTimeInterval(-300), now: now)
        let future = guardian.accept(id: UUID(), sentAt: now.addingTimeInterval(300), now: now)
        #expect(first)
        #expect(!again, "the same message twice")
        #expect(!old, "recorded and played back later")
        #expect(!future, "from the future")
    }

    @Test func everyMessageRoundTrips() throws {
        let sealer = PocketSealer(pairing: pairing)
        let messages: [PocketLive] = [
            .command(.keepAwake(minutes: 60)), .command(.keepAwake(minutes: nil)), .command(.media(.playPause)),
            .command(.answer(questionID: "q1", allow: false)), .command(.refresh),
            .result(PocketCommandResult(commandID: UUID(), ok: false, message: "Mac is locked")),
            .report(PocketDeviceReport(devices: [.init(kind: .watch, name: "Watch", percent: 89, charging: false, readAt: Date(timeIntervalSince1970: 1_800_000_000))])),
            .wallpaperChanged(hash: "abc"),
        ]
        for m in messages {
            let back = try sealer.open(try sealer.seal(PocketEnvelope(from: .phone, body: m), purpose: "live"), as: PocketLive.self, purpose: "live")
            #expect(back.body == m)
        }
    }
}

@Suite struct RelayFrameTests {
    @Test func buildsTheSocketURL() throws {
        let url = try #require(PocketRealtime.socketURL(relay))
        #expect(url.absoluteString.hasPrefix("wss://example.supabase.co/realtime/v1/websocket?apikey="))
        #expect(url.absoluteString.hasSuffix("&vsn=1.0.0"))
    }

    @Test func readsPhoenixFrames() {
        let topic = "realtime:pocket-abc"
        #expect(PocketRealtime.parse(#"{"topic":"realtime:pocket-abc","event":"phx_reply","ref":"1","payload":{"status":"ok","response":{}}}"#,
                                     topic: topic, joinRef: "1") == .joined)
        #expect(PocketRealtime.parse(#"{"topic":"realtime:pocket-abc","event":"phx_reply","ref":"1","payload":{"status":"error"}}"#,
                                     topic: topic, joinRef: "1") == .closed)
        #expect(PocketRealtime.parse(#"{"topic":"realtime:pocket-abc","event":"phx_reply","ref":"7","payload":{"status":"ok"}}"#,
                                     topic: topic, joinRef: "1") == nil, "a heartbeat's reply is not the join")
        #expect(PocketRealtime.parse(#"{"topic":"realtime:pocket-abc","event":"broadcast","payload":{"type":"broadcast","event":"m","payload":{"s":"SEALED"}}}"#,
                                     topic: topic, joinRef: "1") == .message("SEALED"))
        #expect(PocketRealtime.parse(#"{"topic":"realtime:someone-else","event":"broadcast","payload":{"event":"m","payload":{"s":"X"}}}"#,
                                     topic: topic, joinRef: "1") == nil)
        #expect(PocketRealtime.parse(#"{"topic":"realtime:pocket-abc","event":"phx_error","payload":{}}"#, topic: topic, joinRef: "1") == .closed)
    }

    @Test func readsBoxRows() throws {
        let row = #"[{"box":"QUJD","updated_at":"2026-11-25T09:40:12.123456+00:00"}]"#.data(using: .utf8)!
        let read = try #require(try PocketBoxClient.parseGet(row))
        #expect(read.sealed == "QUJD")
        #expect(abs(read.updatedAt.timeIntervalSince1970 - 1_795_599_612.123) < 1)
        #expect(try PocketBoxClient.parseGet("[]".data(using: .utf8)!) == nil)
    }
}
