// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation
import Testing
@testable import PocketKit

private let now = Date(timeIntervalSince1970: 1_800_000_000)
private let utc = TimeZone(identifier: "UTC")!

private func mac(_ battery: PocketMacState.Battery? = .init(percent: 47, charging: true), locked: Bool = false,
                 claude: PocketClaude? = nil) -> PocketMacState {
    var state = PocketMacState(macName: "MacBook Pro", battery: battery, locked: locked)
    state.claude = claude
    return state
}

private func snap(_ state: PocketMacState, heard: TimeInterval = -60, lockedSince: Date? = nil) -> PocketWidgetSnapshot {
    PocketWidgetSnapshot(mac: PocketWatchSnapshot(state: state, sentAt: now.addingTimeInterval(heard),
                                                  heardAt: now.addingTimeInterval(heard)),
                         lockedSince: lockedSince)
}

private func held(left: TimeInterval) -> PocketClaude {
    var session = PocketClaude.Session(id: "s1", project: "zenith", state: .waiting, waitingSince: now.addingTimeInterval(-60),
                                       acceptsReply: true)
    session.replyDeadline = now.addingTimeInterval(left)
    return PocketClaude(sessions: [session], away: true)
}

@Suite struct WidgetSnapshotTests {
    @Test func keepsOnlyANewerStateAndTrimsIt() throws {
        var state = mac(claude: PocketClaude(sessions: [PocketClaude.Session(id: "s", project: "z", state: .waiting,
                                                                              lastMessage: "All done.")]))
        state.health = PocketHealth(cpuPercent: 20)
        state.wallpaperHash = "abc"
        let first = PocketWidgetSnapshot().with(state, sentAt: now, heardAt: now)
        #expect(first.mac?.state.health == nil && first.mac?.state.wallpaperHash == nil)
        #expect(first.mac?.state.claude?.sessions.first?.lastMessage == nil, "widgets never show the message")
        let older = first.with(mac(.init(percent: 10, charging: false)), sentAt: now, heardAt: now.addingTimeInterval(-5))
        #expect(older == first)
        let back = try PocketWidgetSnapshot(data: first.data())
        #expect(back == first)
    }

    @Test func timesTheLockFromTheFirstLockedState() {
        let unlocked = PocketWidgetSnapshot().with(mac(), sentAt: now, heardAt: now)
        #expect(unlocked.lockedSince == nil)
        let lockAt = now.addingTimeInterval(30)
        let locked = unlocked.with(mac(locked: true), sentAt: lockAt, heardAt: lockAt)
        #expect(locked.lockedSince == lockAt)
        let still = locked.with(mac(locked: true), sentAt: lockAt.addingTimeInterval(60), heardAt: lockAt.addingTimeInterval(60))
        #expect(still.lockedSince == lockAt, "kept while it stays locked")
        let open = still.with(mac(), sentAt: lockAt.addingTimeInterval(120), heardAt: lockAt.addingTimeInterval(120))
        #expect(open.lockedSince == nil)
        let firstSeenLocked = PocketWidgetSnapshot().with(mac(locked: true), sentAt: now, heardAt: now)
        #expect(firstSeenLocked.lockedSince == nil, "no unlocked state before it: no time")
    }
}

@Suite struct WidgetWordsTests {
    @Test func saysTheBatteryAsASentence() {
        let charging = PocketWidgetPresentation.battery(snap(mac()), paired: true, now: now)
        #expect(charging.eyebrow == "MacBook Pro")
        #expect(charging.sentence.text == "At 47%, charging.")
        #expect(charging.sentence.tone == .good)
        #expect(charging.meta == "updated 1m ago")
        let plugged = PocketWidgetPresentation.battery(snap(mac(.init(percent: 80, charging: false, pluggedIn: true))),
                                                       paired: true, now: now)
        #expect(plugged.sentence.rest == "plugged in.")
        let draining = PocketWidgetPresentation.battery(snap(mac(.init(percent: 9, charging: false, minutesRemaining: 42))),
                                                        paired: true, now: now)
        #expect(draining.sentence.text == "At 9%, 42m left." && draining.sentence.tone == .alert)
        let full = PocketWidgetPresentation.battery(snap(mac(.init(percent: 100, charging: true))), paired: true, now: now)
        #expect(full.sentence.rest == "full.")
        #expect(PocketWidgetPresentation.batteryShare(snap(mac())) == 0.47)
    }

    @Test func saysAnOldBatteryQuietly() {
        let old = PocketWidgetPresentation.battery(snap(mac(), heard: -2 * 3600), paired: true, now: now)
        #expect(old.sentence.text == "At 47%, asleep or offline.")
        #expect(old.sentence.tone == .quiet)
        #expect(old.meta == "last known 2h ago")
    }

    @Test func saysWhenThereIsNothingYet() {
        #expect(PocketWidgetPresentation.battery(nil, paired: false, now: now).sentence.text == "Not paired, open Pocket.")
        #expect(PocketWidgetPresentation.battery(nil, paired: true, now: now).sentence.text == "Waiting, for your Mac.")
        #expect(PocketWidgetPresentation.battery(snap(mac(nil)), paired: true, now: now).sentence.text == "Online, no battery here.")
        #expect(PocketWidgetPresentation.inline(nil, paired: false, now: now) == "Pocket · not paired")
        #expect(PocketWidgetPresentation.inline(nil, paired: true, now: now) == "Mac · waiting")
    }

    @Test func saysTheLock() {
        let open = PocketWidgetPresentation.lock(snap(mac()), paired: true, now: now)
        #expect(open.sentence.text == "Unlocked, tap to lock.")
        #expect(PocketWidgetPresentation.canLock(snap(mac()), paired: true, now: now))
        let since = Calendar(identifier: .gregorian).date(from: DateComponents(timeZone: utc, year: 2026, month: 11, day: 26,
                                                                               hour: 9, minute: 41))!
        #expect(PocketWidgetPresentation.clock(since, timeZone: utc) == "09.41")
        let locked = PocketWidgetPresentation.lock(snap(mac(locked: true), lockedSince: since), paired: true, now: now)
        #expect(locked.sentence.lead == "Locked," && locked.sentence.rest.hasPrefix("since "))
        let untimed = PocketWidgetPresentation.lock(snap(mac(locked: true)), paired: true, now: now)
        #expect(untimed.sentence.text == "Locked.")
        #expect(!PocketWidgetPresentation.canLock(snap(mac(locked: true)), paired: true, now: now))
        let away = PocketWidgetPresentation.lock(snap(mac(), heard: -3600), paired: true, now: now)
        #expect(away.sentence.text == "Away, asleep or offline." && away.meta == "last known 1h ago")
        #expect(!PocketWidgetPresentation.canLock(snap(mac(), heard: -3600), paired: true, now: now))
    }

    @Test func saysItIsYourTurnWhileClaudeWaits() throws {
        let lines = PocketWidgetPresentation.claude(snap(mac(claude: held(left: 18 * 60))), paired: true, now: now)
        #expect(lines.eyebrow == "Claude · zenith")
        #expect(lines.sentence.text == "Your turn, 18 min left.")
        #expect(lines.meta == "tap to reply" && lines.metaTone == .attention && lines.needsYou)
        let session = try #require(held(left: 30).sessions.first)
        #expect(PocketWidgetPresentation.claudeLeft(session, now: now) == "under a minute left.")
        let long = try #require(held(left: 65 * 60).sessions.first)
        #expect(PocketWidgetPresentation.claudeLeft(long, now: now) == "1h 5m left.")
        let ended = try #require(held(left: -5).sessions.first)
        #expect(PocketWidgetPresentation.claudeLeft(ended, now: now) == nil)

        let asking = PocketWidgetPresentation.claude(
            snap(mac(claude: PocketClaude(sessions: [PocketClaude.Session(id: "s", project: "zenith", state: .asking)]))),
            paired: true, now: now)
        #expect(asking.sentence.text == "Your turn, it needs your OK." && asking.meta == "tap to answer" && asking.needsYou)
        let notHeld = PocketWidgetPresentation.claude(
            snap(mac(claude: PocketClaude(sessions: [PocketClaude.Session(id: "s", project: "zenith", state: .waiting)]))),
            paired: true, now: now)
        #expect(notHeld.sentence.text == "Your turn, on your Mac." && !notHeld.needsYou)
    }

    @Test func saysWhatClaudeDoes() {
        let step = PocketClaude.Step(id: "1", tool: "Edit", target: "Hero.swift", phase: .running, startedAt: now)
        let working = PocketClaude(sessions: [PocketClaude.Session(id: "s", project: "zenith", state: .working, steps: [step])])
        let lines = PocketWidgetPresentation.claude(snap(mac(claude: working)), paired: true, now: now)
        #expect(lines.sentence.text == "Working, editing Hero.swift." && !lines.needsYou)
        #expect(PocketWidgetPresentation.rectangleShowsClaude(snap(mac(claude: working)), now: now))
        let idle = PocketWidgetPresentation.claude(snap(mac()), paired: true, now: now)
        #expect(idle.sentence.text == "Claude is idle." && idle.eyebrow == "Claude" && idle.sentence.tone == .quiet)
        #expect(!PocketWidgetPresentation.rectangleShowsClaude(snap(mac()), now: now))
        let away = PocketWidgetPresentation.claude(snap(mac(claude: working), heard: -3 * 3600), paired: true, now: now)
        #expect(away.sentence.text == "Away, your Mac is asleep.")
    }

    @Test func readsTheControls() {
        var awake = mac()
        awake.awakeUntil = now.addingTimeInterval(600)
        #expect(PocketWidgetPresentation.awakeIsOn(snap(awake), now: now))
        #expect(!PocketWidgetPresentation.awakeIsOn(snap(mac()), now: now))
        #expect(!PocketWidgetPresentation.awakeIsOn(snap(awake, heard: -3600), now: now), "an away Mac reads off")
        var muted = mac()
        muted.sound = PocketSound(volume: 30, muted: false, micMuted: true)
        #expect(!PocketWidgetPresentation.micIsOn(snap(muted)))
        #expect(PocketWidgetPresentation.micIsOn(snap(mac())), "unknown reads on")
    }

    @Test func freshnessLines() {
        #expect(PocketWidgetPresentation.freshnessLine(heardAt: now, now: now) == "updated just now")
        #expect(PocketWidgetPresentation.freshnessLine(heardAt: now.addingTimeInterval(-240), now: now) == "updated 4m ago")
        #expect(PocketWidgetPresentation.freshnessLine(heardAt: now.addingTimeInterval(-7200), now: now) == "last known 2h ago")
        #expect(PocketWidgetPresentation.freshnessLine(heardAt: nil, now: now) == nil)
    }
}

@Suite struct WidgetTimelineTests {
    @Test func movesOnEveryFiveMinutes() {
        let dates = PocketWidgetPresentation.entryDates(snap(mac()), now: now)
        #expect(dates == [0, 300, 600].map { now.addingTimeInterval($0) })
    }

    @Test func countsDownAHeldTurnByTheMinute() {
        let dates = PocketWidgetPresentation.entryDates(snap(mac(claude: held(left: 4 * 60 + 30))), now: now)
        let offsets = dates.map { $0.timeIntervalSince(now) }
        #expect(offsets == [0, 60, 120, 180, 240, 271, 300, 600])
    }

    @Test func turnsAwayOnTime() {
        let dates = PocketWidgetPresentation.entryDates(snap(mac(), heard: -(PocketPresentation.offlineAfter - 120)), now: now)
        #expect(dates.contains(now.addingTimeInterval(121)))
        let away = PocketWidgetPresentation.battery(snap(mac(), heard: -(PocketPresentation.offlineAfter - 120)),
                                                    paired: true, now: now.addingTimeInterval(121))
        #expect(away.sentence.tone == .quiet)
    }

    @Test func reloadsOnlyWhenWhatTheyShowChanges() {
        let a = snap(mac(claude: held(left: 18 * 60)))
        #expect(PocketWidgetPresentation.glance(a, now: now) == PocketWidgetPresentation.glance(a, now: now.addingTimeInterval(60)),
                "a countdown moving on is the timeline's job")
        var b = a
        b.mac?.state.battery?.percent = 48
        #expect(PocketWidgetPresentation.glance(a, now: now) != PocketWidgetPresentation.glance(b, now: now))
        var c = a
        c.phone = PocketDeviceReport.Device(kind: .iphone, name: "paiz", percent: 80, charging: false, readAt: now)
        #expect(PocketWidgetPresentation.glance(a, now: now) != PocketWidgetPresentation.glance(c, now: now))
    }
}
