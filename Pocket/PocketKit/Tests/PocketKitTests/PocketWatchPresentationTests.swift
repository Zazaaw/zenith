// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation
import Testing
@testable import PocketKit

private let relay = PocketRelayConfig(url: URL(string: "https://example.supabase.co")!,
                                      anonKey: "eyJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoiYW5vbiJ9.c2lnbmF0dXJl")
private let now = Date(timeIntervalSince1970: 1_800_000_000)

private func session(_ state: PocketClaude.Session.State, accepts: Bool = false, message: String? = nil,
                     waitingSince: Date? = nil) -> PocketClaude.Session {
    var s = PocketClaude.Session(id: "s1", project: "zenith", state: state, waitingSince: waitingSince, lastMessage: message,
                                 steps: [], acceptsReply: accepts)
    s.steps = (0..<5).map { PocketClaude.Step(id: "\($0)", tool: "Read", phase: .done, startedAt: now) }
    return s
}

private func mac(percent: Int = 47, charging: Bool = false, claude: PocketClaude? = nil) -> PocketMacState {
    var state = PocketMacState(macName: "Mac", battery: .init(percent: percent, charging: charging))
    state.claude = claude
    return state
}

@Suite struct WatchContextTests {
    @Test func roundTripsThroughAPropertyListDictionary() throws {
        let pairing = PocketPairing.make(relay: relay, macName: "Mac")
        let snapshot = PocketWatchSnapshot(state: mac(), sentAt: now, heardAt: now.addingTimeInterval(1))
        let phone = PocketDeviceReport.Device(kind: .iphone, name: "paiz", percent: 80, charging: false, readAt: now)
        let context = PocketWatchContext(pairing: pairing, snapshot: snapshot, phone: phone)
        let dictionary = try context.dictionary()
        #expect(PropertyListSerialization.propertyList(dictionary, isValidFor: .binary))
        #expect(PocketWatchContext(dictionary: dictionary) == context)
        #expect(PocketWatchContext(dictionary: ["other": 1]) == nil)
        #expect(PocketWatchContext(dictionary: try PocketWatchContext(pairing: nil).dictionary())?.pairing == nil, "unpaired")
    }

    @Test func passesACommandThroughTheIPhone() throws {
        let message = try PocketWatchContext.commandMessage(.claudeReply(sessionID: "s1", text: "Run the tests."))
        #expect(PropertyListSerialization.propertyList(message, isValidFor: .binary))
        #expect(PocketWatchContext.command(from: message) == .claudeReply(sessionID: "s1", text: "Run the tests."))
        #expect(PocketWatchContext.command(from: [PocketWatchContext.helloKey: true]) == nil)
    }

    @Test func keepsTheNewestSnapshot() {
        let old = PocketWatchSnapshot(state: mac(percent: 40), sentAt: now, heardAt: now)
        let new = PocketWatchSnapshot(state: mac(percent: 41), sentAt: now, heardAt: now.addingTimeInterval(30))
        #expect(PocketWatchSnapshot.newest(old, new) == new)
        #expect(PocketWatchSnapshot.newest(new, old) == new)
        #expect(PocketWatchSnapshot.newest(nil, old) == old)
        #expect(PocketWatchSnapshot.newest(old, nil) == old)
    }
}

@Suite struct WatchTrimTests {
    @Test func dropsWhatTheWatchDoesNotShow() throws {
        var state = mac(claude: PocketClaude(sessions: [session(.waiting, message: String(repeating: "word ", count: 2000))]))
        state.health = PocketHealth(cpuPercent: 30)
        state.tools = PocketTools(clips: ["secret"])
        state.wallpaperHash = "abc"
        state.sound = PocketSound(volume: 40, muted: false, micMuted: true, outputs: [
            .init(id: "a", name: "Speakers", kind: "speakers", current: true),
            .init(id: "b", name: "AirPods", kind: "airpods", current: false),
        ])
        let trimmed = PocketWatchPresentation.trimmed(state)
        #expect(trimmed.health == nil && trimmed.tools == nil && trimmed.wallpaperHash == nil)
        #expect(trimmed.battery == state.battery)
        #expect(trimmed.sound?.volume == 40 && trimmed.sound?.micMuted == true && trimmed.sound?.outputs.count == 1)
        let message = try #require(trimmed.claude?.sessions.first?.lastMessage)
        #expect(message.count <= PocketWatchPresentation.messageTail + 1)
        #expect(message.hasPrefix("…word"), "starts on a whole word")
        #expect(trimmed.claude?.sessions.first?.steps.count == 1)
        let size = try PocketWatchContext.encode(trimmed).count
        #expect(size < 8_000, "small enough for the application context")
    }

    @Test func leavesShortMessagesWhole() {
        #expect(PocketWatchPresentation.tail("  All done.  ", limit: 100) == "All done.")
    }
}

@Suite struct WatchWordsTests {
    @Test func saysTheMacAndClaudeInline() {
        let fresh = PocketWatchSnapshot(state: mac(claude: PocketClaude(sessions: [session(.waiting)])), sentAt: now, heardAt: now)
        #expect(PocketWatchPresentation.inline(fresh, now: now) == "Mac 47% · Claude waiting")
        let quiet = PocketWatchSnapshot(state: mac(), sentAt: now, heardAt: now)
        #expect(PocketWatchPresentation.inline(quiet, now: now) == "Mac 47%")
        let old = PocketWatchSnapshot(state: mac(), sentAt: now, heardAt: now.addingTimeInterval(-3600))
        #expect(PocketWatchPresentation.inline(old, now: now) == "MacBook away")
        #expect(PocketWatchPresentation.inline(nil, now: now) == "Pocket · not paired")
    }

    @Test func surfacesClaudeWhenItNeedsYou() {
        func score(_ state: PocketMacState) -> Float {
            PocketWatchPresentation.relevance(PocketWatchSnapshot(state: state, sentAt: now, heardAt: now), now: now)
        }
        let held = score(mac(claude: PocketClaude(sessions: [session(.waiting, accepts: true)], away: true)))
        let asking = score(mac(claude: PocketClaude(sessions: [session(.asking)])))
        let ended = score(mac(claude: PocketClaude(sessions: [session(.waiting, waitingSince: now.addingTimeInterval(-60))])))
        let low = score(mac(percent: 12))
        let calm = score(mac())
        #expect(held == 1 && asking == 1)
        #expect(ended > low && low > calm)
        #expect(PocketWatchPresentation.relevance(nil, now: now) == 0)
    }

    @Test func readsACommandsEffectFromTheNextState() {
        var locked = mac(); locked.locked = true
        #expect(PocketWatchPresentation.confirms(.lock, before: mac(), after: locked) == true)
        #expect(PocketWatchPresentation.confirms(.lock, before: mac(), after: mac()) == false)
        var awake = mac(); awake.awakeUntil = now.addingTimeInterval(3600)
        #expect(PocketWatchPresentation.confirms(.keepAwake(minutes: 60), before: mac(), after: awake) == true)
        #expect(PocketWatchPresentation.confirms(.keepAwake(minutes: nil), before: awake, after: mac()) == true)
        #expect(PocketWatchPresentation.confirms(.muteMic(true), before: nil, after: mac()) == nil, "no sound, can't tell")
        let away = mac(claude: PocketClaude(sessions: [], away: true))
        #expect(PocketWatchPresentation.confirms(.setAway(true), before: nil, after: away) == true)
        let replied = mac(claude: PocketClaude(sessions: [session(.working)]))
        #expect(PocketWatchPresentation.confirms(.claudeReply(sessionID: "s1", text: "Go"), before: nil, after: replied) == true)
        let stillHeld = mac(claude: PocketClaude(sessions: [session(.waiting, accepts: true)]))
        #expect(PocketWatchPresentation.confirms(.claudeReply(sessionID: "s1", text: "Go"), before: nil, after: stillHeld) == false)
        var playing = mac(); playing.nowPlaying = .init(title: "a", artist: "b", playing: true)
        var paused = playing; paused.nowPlaying?.playing = false
        #expect(PocketWatchPresentation.confirms(.media(.playPause), before: playing, after: paused) == true)
        #expect(PocketWatchPresentation.confirms(.refresh, before: nil, after: mac()) == nil)
    }
}

@Suite struct WatchBatteryTests {
    let phone = PocketDeviceReport.Device(kind: .iphone, name: "paiz", percent: 60, charging: false, readAt: now)

    @Test func showsTheWatchBesideTheIPhone() {
        var state = mac()
        state.accessories = [
            .init(id: "w", name: "Apple Watch", kind: "watch", percent: 70, charging: false),
            .init(id: "kb", name: "Maxfit61", kind: "keyboard", percent: 45, charging: false),
        ]
        let watch = PocketDeviceReport.Device(kind: .watch, name: "Apple Watch", percent: 15, charging: false,
                                              readAt: now.addingTimeInterval(-240))
        let items = PocketPresentation.batteryItems(state, phone: phone, watch: watch, now: now)
        #expect(items.map(\.role) == [.mac, .thisPhone, .thisWatch, .accessory], "the Watch's own reading replaces Zenith's")
        let item = items[2]
        #expect(item.kind == "watch" && PocketPresentation.symbolName(item) == "applewatch")
        #expect(PocketPresentation.itemMeta(item, now: now) == "watch · 4m ago")
        #expect(PocketPresentation.lowest(items)?.role == .thisWatch)
        #expect(PocketPresentation.devicesSentence(items).text == "Your Apple Watch is at 15%, charge it soon.")
        #expect(PocketPresentation.attention(state, phone: phone, watch: watch, now: now).devices)
    }

    @Test func marksAnOldWatchReadingAsLastKnown() {
        let watch = PocketDeviceReport.Device(kind: .watch, name: "Apple Watch", percent: 15, charging: true,
                                              readAt: now.addingTimeInterval(-3 * 3600))
        let items = PocketPresentation.batteryItems(nil, phone: nil, watch: watch, now: now)
        let item = items[0]
        #expect(item.seenAt == watch.readAt && !item.charging)
        #expect(PocketPresentation.itemMeta(item, now: now) == "seen 3h ago")
        #expect(PocketPresentation.itemTone(item) == .quiet)
        #expect(PocketPresentation.lowest(items) == nil, "a stale level never reads as low")
    }

    @Test func travelsFromTheWatchToTheIPhone() throws {
        let watch = PocketDeviceReport.Device(kind: .watch, name: "Apple Watch", percent: 64, charging: true, readAt: now)
        let message = try PocketWatchContext.watchBatteryMessage(watch)
        #expect(PropertyListSerialization.propertyList(message, isValidFor: .binary))
        #expect(PocketWatchContext.watchBattery(from: message) == watch)
        #expect(PocketWatchContext.watchBattery(from: try PocketWatchContext.watchBatteryMessage(phone)) == nil, "only a Watch")
    }

    @Test func reportsAFreshWatchToZenith() {
        let fresh = PocketDeviceReport.Device(kind: .watch, name: "Apple Watch", percent: 80, charging: false, readAt: now)
        let old = PocketDeviceReport.Device(kind: .watch, name: "Apple Watch", percent: 80, charging: false,
                                            readAt: now.addingTimeInterval(-3600))
        #expect(PocketPresentation.deviceReport(phone: phone, watch: fresh, now: now)?.devices.map(\.kind) == [.iphone, .watch])
        #expect(PocketPresentation.deviceReport(phone: phone, watch: old, now: now)?.devices.map(\.kind) == [.iphone])
        #expect(PocketPresentation.deviceReport(phone: nil, watch: nil, now: now) == nil)
    }
}
