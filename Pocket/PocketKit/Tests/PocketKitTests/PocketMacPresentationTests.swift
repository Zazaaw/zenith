// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation
import Testing
@testable import PocketKit

private let now = Date(timeIntervalSince1970: 1_800_000_000)
private let relay = PocketRelayConfig(url: URL(string: "https://example.supabase.co")!,
                                      anonKey: "eyJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoiYW5vbiJ9.c2lnbmF0dXJl")

@Suite struct MacHeroTests {
    private func state(cpu: Int?, temperature: Double? = 52) -> PocketMacState {
        var state = PocketMacState(macName: "MacBook Pro")
        state.health = cpu.map { PocketHealth(cpuPercent: $0, temperature: temperature) }
        return state
    }

    @Test func sentence() {
        let calm = PocketMacPresentation.sentence(state(cpu: 38), freshness: .live, now: now)
        #expect(calm.text == "Your Mac runs at 38%, cool and steady.")
        #expect(calm.tone == .good)
        #expect(PocketMacPresentation.sentence(state(cpu: 12), freshness: .live, now: now).text
                == "Your Mac runs at 12%, cool and quiet.")
        let hot = PocketMacPresentation.sentence(state(cpu: 92, temperature: 88), freshness: .live, now: now)
        #expect(hot.text == "Your Mac runs at 92%, hot and busy." && hot.tone == .alert)
        #expect(PocketMacPresentation.sentence(state(cpu: 70, temperature: nil), freshness: .live, now: now).text
                == "Your Mac runs at 70%, running busy.")
        #expect(PocketMacPresentation.sentence(state(cpu: nil), freshness: .live, now: now).text == "Reading your Mac…",
                "health comes a moment after the tab opens")
        #expect(PocketMacPresentation.sentence(state(cpu: 38), freshness: .away(now), now: now).tone == .quiet,
                "an asleep Mac says so instead of an old reading")
    }

    @Test func numbers() {
        #expect(PocketMacPresentation.bytes(230_400_000_000) == "230G")
        #expect(PocketMacPresentation.bytes(1_430_000_000_000) == "1.4T")
        #expect(PocketMacPresentation.bytes(820_000_000) == "820M")
        #expect(PocketMacPresentation.bytes(-1) == "0B")
        #expect(PocketMacPresentation.rate(1_200_000) == "1.2 MB/s")
        #expect(PocketMacPresentation.rate(84_000) == "84 KB/s")
        #expect(PocketMacPresentation.rate(12) == "12 B/s")
        #expect(PocketMacPresentation.share(40.1) == "40%" && PocketMacPresentation.share(4.25) == "4.2%")
        #expect(PocketMacPresentation.diskTone(free: 230, total: 494) == .info)
        #expect(PocketMacPresentation.diskTone(free: 40, total: 494) == .attention)
        #expect(PocketMacPresentation.diskTone(free: 10, total: 494) == .alert)
        #expect(PocketMacPresentation.cpuTone(59) == .good && PocketMacPresentation.cpuTone(60) == .attention)
    }
}

@Suite struct MacToolsTests {
    @Test func timer() {
        #expect(PocketMacPresentation.timerLine(nil, now: now) == "Start")
        let running = PocketTools.Timer(label: "Timer", endsAt: now.addingTimeInterval(1452))
        #expect(PocketMacPresentation.timerLine(running, now: now) == "24:12")
        #expect(PocketMacPresentation.timerLeft(running, now: now) == 1452)
        let paused = PocketTools.Timer(label: "Focus", remaining: 723, paused: true)
        #expect(PocketMacPresentation.timerLine(paused, now: now) == "paused · 12:03")
        #expect(PocketMacPresentation.timerLine(PocketTools.Timer(label: "Focus done", remaining: 0), now: now) == "Focus done")
        #expect(PocketMacPresentation.timerLine(running, now: now.addingTimeInterval(9999)) == "0:00", "never below zero")
    }

    @Test func eventsAndServers() {
        let later = PocketTools.Event(title: "Weekly sync", start: now.addingTimeInterval(18 * 60), end: now.addingTimeInterval(78 * 60))
        #expect(PocketMacPresentation.eventLine(later, now: now) == "in 18m")
        let ongoing = PocketTools.Event(title: "Review", start: now.addingTimeInterval(-60), end: now.addingTimeInterval(600))
        #expect(PocketMacPresentation.eventLine(ongoing, now: now) == "now · ends in 10m")
        #expect(PocketMacPresentation.devServersLine([]) == "none running")
        #expect(PocketMacPresentation.devServersLine([.init(port: 3000, process: "Next.js"), .init(port: 5173, process: "Vite")])
                == ":3000 · :5173")
    }

    @Test func sound() {
        #expect(PocketMacPresentation.volumeSymbol(0, muted: false) == "speaker.slash.fill")
        #expect(PocketMacPresentation.volumeSymbol(80, muted: true) == "speaker.slash.fill")
        #expect(PocketMacPresentation.volumeSymbol(62, muted: false) == "speaker.wave.2.fill")
        let sound = PocketSound(volume: 62, muted: false, outputs: [.init(id: "a", name: "Speakers", kind: "speakers", current: false),
                                                                     .init(id: "b", name: "Liberty 4", kind: "bluetooth", current: true)])
        #expect(PocketMacPresentation.currentOutput(sound) == "Liberty 4")
        #expect(PocketMacPresentation.outputSymbol("airpods") == "airpods")
    }
}

@Suite struct SendToMacTests {
    @Test func slotsGoRoundRobin() {
        #expect(PocketMacPresentation.nextSlot(after: nil) == 0)
        #expect(PocketMacPresentation.nextSlot(after: 0) == 1)
        #expect(PocketMacPresentation.nextSlot(after: 3) == 0)
    }

    /// A drop at the phone's budget seals under the relay's limit; one at the
    /// contract's ceiling would not, which is why the phone aims lower.
    @Test func dropsFitTheRelay() throws {
        let sealer = PocketSealer(pairing: PocketPairing.make(relay: relay, macName: "Mac"))
        var bytes = [UInt8](repeating: 0, count: PocketDrop.fitBytes)
        for index in bytes.indices { bytes[index] = UInt8.random(in: 0...255) }
        let drop = PocketDrop(name: "IMG_5561.jpeg", kind: .photo, data: Data(bytes))
        let sealed = try sealer.seal(PocketEnvelope(from: .phone, body: drop), purpose: PocketPurpose.box("drop"))
        #expect(sealed.count < 350_000)
        let estimate = PocketDrop.sealedLength(dataBytes: PocketDrop.fitBytes, nameLength: drop.name.count)
        #expect(abs(estimate - sealed.count) < 2_000, "the estimate tracks the real thing (\(estimate) vs \(sealed.count))")
        #expect(PocketDrop.sealedLength(dataBytes: PocketDrop.maxBytes) > 350_000)
    }
}
