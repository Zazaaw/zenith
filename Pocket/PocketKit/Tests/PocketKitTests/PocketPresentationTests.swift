// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation
import Testing
@testable import PocketKit

private let now = Date(timeIntervalSince1970: 1_800_000_000)

@Suite struct PresentationTimeTests {
    @Test func durations() {
        #expect(PocketPresentation.duration(minutes: 42) == "42m")
        #expect(PocketPresentation.duration(minutes: 60) == "1h")
        #expect(PocketPresentation.duration(minutes: 190) == "3h 10m")
        #expect(PocketPresentation.duration(minutes: -5) == "0m")
        #expect(PocketPresentation.duration(seconds: 11_059) == "3h 4m", "rounded down")
    }

    @Test func agoAndCountdown() {
        #expect(PocketPresentation.ago(now.addingTimeInterval(-20), now: now) == "just now")
        #expect(PocketPresentation.ago(now.addingTimeInterval(30), now: now) == "just now", "a clock running ahead")
        #expect(PocketPresentation.ago(now.addingTimeInterval(-4 * 60), now: now) == "4m ago")
        #expect(PocketPresentation.ago(now.addingTimeInterval(-3 * 3600), now: now) == "3h ago")
        #expect(PocketPresentation.ago(now.addingTimeInterval(-50 * 3600), now: now) == "2d ago")
        #expect(PocketPresentation.countdown(to: now.addingTimeInterval(341 * 60), now: now) == "in 5h 41m")
        #expect(PocketPresentation.countdown(to: now.addingTimeInterval(10), now: now) == "now")
        #expect(PocketPresentation.clock(102) == "1:42")
        #expect(PocketPresentation.clock(3723) == "1:02:03")
    }

    @Test func freshness() {
        #expect(PocketPresentation.freshness(heardAt: nil, live: false, now: now) == .never)
        #expect(PocketPresentation.freshness(heardAt: now, live: true, now: now) == .live)
        let box = now.addingTimeInterval(-5 * 60)
        #expect(PocketPresentation.freshness(heardAt: box, live: false, now: now) == .recent(box))
        #expect(PocketPresentation.updatedLine(.recent(box), now: now) == "updated 5m ago")
        let old = now.addingTimeInterval(-21 * 60)
        #expect(PocketPresentation.freshness(heardAt: old, live: true, now: now) == .away(old),
                "a live state goes stale too: the Mac stopped talking")
        #expect(PocketPresentation.freshness(heardAt: now.addingTimeInterval(600), live: false, now: now) == .recent(now))
        #expect(!PocketFreshness.away(old).isReachable && PocketFreshness.recent(box).isReachable)
    }
}

@Suite struct PresentationSentenceTests {
    func mac(_ battery: PocketMacState.Battery?) -> PocketMacState { PocketMacState(macName: "Faiz’s MacBook Pro", battery: battery) }

    @Test func homeSaysWhatTheBatteryDoes() {
        let charging = PocketPresentation.homeSentence(mac(.init(percent: 47, charging: true, minutesRemaining: 72)), freshness: .live)
        #expect(charging.text == "Your MacBook is at 47%, and charging.")
        #expect(charging.value == "47%" && charging.tone == .good)
        let held = PocketPresentation.homeSentence(mac(.init(percent: 80, charging: false, pluggedIn: true)), freshness: .live)
        #expect(held.rest == "and plugged in.")
        let draining = PocketPresentation.homeSentence(mac(.init(percent: 60, charging: false, minutesRemaining: 190)), freshness: .live)
        #expect(draining.rest == "and has 3h 10m left.")
        let low = PocketPresentation.homeSentence(mac(.init(percent: 8, charging: false)), freshness: .live)
        #expect(low.rest == "and on battery." && low.tone == .alert)
        let desktop = PocketPresentation.homeSentence(PocketMacState(macName: "Studio", locked: true), freshness: .live)
        #expect(desktop.text == "Your Mac is online, and locked.")
        let away = PocketPresentation.homeSentence(mac(.init(percent: 47, charging: true)), freshness: .away(now))
        #expect(away.text == "Your MacBook is away, asleep, off or offline.")
        #expect(PocketPresentation.homeSentence(nil, freshness: .never).value == "your Mac")
        #expect(PocketPresentation.batteryNote(.init(percent: 47, charging: true, minutesRemaining: 72)) == "full in 1h 12m")
    }

    @Test func controlSaysHowLongItStaysAwake() {
        var state = PocketMacState(macName: "Mac")
        #expect(PocketPresentation.controlSentence(state, freshness: .live, now: now).text == "Your Mac sleeps as usual.")
        state.awakeUntil = now.addingTimeInterval(42 * 60)
        #expect(PocketPresentation.controlSentence(state, freshness: .live, now: now).text == "Your Mac stays awake 42m then sleeps.")
        state.awakeUntil = .distantFuture
        #expect(PocketPresentation.controlSentence(state, freshness: .live, now: now).text == "Your Mac stays awake, until you turn it off.")
        state.awakeUntil = now.addingTimeInterval(-60)
        #expect(PocketPresentation.controlSentence(state, freshness: .live, now: now).value == "sleeps", "an end that passed")
        #expect(PocketPresentation.controlSentence(state, freshness: .away(now), now: now).value == "out of reach")
        #expect(PocketPresentation.controlBadge(state, freshness: .live) == PocketBadge("Unlocked", .info))
    }

    @Test func agentsCountTheQuestions() {
        var state = PocketMacState(macName: "Mac")
        #expect(PocketPresentation.agentsSentence(state).text == "Claude is all quiet. Nothing is waiting on you.")
        state.sessions = [.init(id: "a", project: "portfolio", status: .running, since: now)]
        #expect(PocketPresentation.agentsSentence(state).text == "Claude is working on portfolio.")
        let question = PocketMacState.AgentQuestion(id: "q", project: "zenith", tool: "Bash", detail: "./build.sh", askedAt: now)
        state.questions = [question]
        #expect(PocketPresentation.agentsSentence(state).text == "Claude has 1 question waiting on you.")
        state.questions.append(question)
        #expect(PocketPresentation.agentsSentence(state).value == "2 questions")
        #expect(PocketPresentation.questionTitle(question) == "Run a command?")
        #expect(PocketPresentation.questionDetail(question) == "$ ./build.sh")
        #expect(PocketPresentation.sessionLine(.init(id: "b", project: "x", status: .done, since: now.addingTimeInterval(-18 * 60)), now: now) == "18m ago")
        #expect(PocketPresentation.sessionLine(.init(id: "c", project: "x", status: .running, since: now.addingTimeInterval(-4 * 60)), now: now) == "running · 4m")
    }

    @Test func devicesNameTheLowestBattery() {
        var state = mac(.init(percent: 5, charging: false))
        state.accessories = [
            .init(id: "buds", name: "AirPods Pro", kind: "headphones", percent: 18, charging: false),
            .init(id: "kb", name: "Maxfit61", kind: "keyboard", percent: 9, charging: false, seenAt: now.addingTimeInterval(-7200)),
            .init(id: "mouse", name: "MX", kind: "mouse", percent: 3, charging: true),
        ]
        let phone = PocketDeviceReport.Device(kind: .iphone, name: "iPhone 13 Pro", percent: 43, charging: false, readAt: now)
        let items = PocketPresentation.batteryItems(state, phone: phone)
        #expect(items.map(\.role) == [.mac, .thisPhone, .accessory, .accessory, .accessory])
        #expect(PocketPresentation.lowest(items)?.name == "AirPods Pro", "not the Mac, a stale reading, or one charging")
        #expect(PocketPresentation.devicesSentence(items).text == "Your earbuds are at 18%, charge them soon.")
        #expect(PocketPresentation.devicesBadge(items) == PocketBadge("Low", .alert))
        #expect(PocketPresentation.attention(state, phone: phone).devices)
        #expect(PocketPresentation.itemMeta(items[3], now: now) == "seen 2h ago")

        state.accessories = [.init(id: "kb", name: "Maxfit61", kind: "keyboard", percent: 45, charging: false)]
        let fine = PocketPresentation.batteryItems(state, phone: phone)
        #expect(PocketPresentation.devicesSentence(fine).text == "Every battery is fine. This iPhone is lowest, at 43%.")
        state.accessories = [.init(id: "kb", name: "Maxfit61", kind: "keyboard", percent: 12, charging: false)]
        #expect(PocketPresentation.devicesSentence(PocketPresentation.batteryItems(state, phone: phone)).text
                == "Your keyboard is at 12%, charge it soon.")
        #expect(!PocketPresentation.attention(PocketMacState(macName: "Mac"), phone: phone).devices)
    }

    @Test func playbackCountsOn() {
        let song = PocketMacState.NowPlaying(title: "Feast", artist: "nina", playing: true, elapsed: 100, duration: 238)
        #expect(PocketPresentation.elapsed(song, sentAt: now, now: now.addingTimeInterval(2)) == 102)
        #expect(PocketPresentation.elapsed(song, sentAt: now, now: now.addingTimeInterval(1000)) == 238)
        #expect(PocketPresentation.nowPlayingLine(song, elapsed: 102) == "nina · 1:42 / 3:58")
    }

    @Test func resultsReadAsSentences() {
        let id = UUID()
        #expect(PocketPresentation.resultLine(.init(commandID: id, ok: false, message: "Mac is locked"), for: .lock) == "Mac is locked")
        #expect(PocketPresentation.resultLine(.init(commandID: id, ok: true), for: .keepAwake(minutes: 60)) == "Your Mac stays awake for 1h.")
        #expect(PocketPresentation.resultLine(.init(commandID: id, ok: true), for: .keepAwake(minutes: nil)) == "Your Mac sleeps as usual.")
        #expect(PocketPresentation.resultLine(.init(commandID: id, ok: false), for: nil) == "Your Mac couldn't do that.")
    }
}
