// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation
import Testing
@testable import PocketKit

private let now = Date(timeIntervalSince1970: 1_800_000_000)

private func step(_ tool: String, _ target: String?, _ phase: PocketClaude.Step.Phase, ago seconds: TimeInterval) -> PocketClaude.Step {
    PocketClaude.Step(id: UUID().uuidString, tool: tool, target: target, phase: phase, startedAt: now.addingTimeInterval(-seconds))
}

private func session(_ state: PocketClaude.Session.State, steps: [PocketClaude.Step] = [], accepts: Bool = false,
                     waitingFor seconds: TimeInterval? = nil) -> PocketClaude.Session {
    PocketClaude.Session(id: "s", project: "zenith", state: state, turnStartedAt: now.addingTimeInterval(-245),
                         waitingSince: seconds.map { now.addingTimeInterval(-$0) }, steps: steps, filesChanged: 3,
                         added: 36, removed: 6, acceptsReply: accepts)
}

@Suite struct ClaudePresentationTests {
    @Test func sentences() {
        let working = session(.working, steps: [step("Read", "a.swift", .done, ago: 200), step("Bash", "pytest", .running, ago: 84)])
        #expect(PocketPresentation.claudeSentence(working, now: now).text == "Claude is running the tests, 4m into this turn.")
        #expect(PocketPresentation.claudeSentence(working, now: now).tone == .progress)
        #expect(PocketPresentation.claudeSentence(session(.waiting), now: now).text == "Claude is done, and waiting for you.")
        #expect(PocketPresentation.claudeSentence(session(.asking), now: now).tone == .attention)
        #expect(PocketPresentation.claudeSentence(session(.done, waitingFor: 7200), now: now).text
                == "Claude is idle, last turn ended 2h ago.")
        #expect(PocketPresentation.claudeSentence(nil, now: now).text == "Claude is all quiet. No session is running.")
        #expect(PocketPresentation.claudeBadge(working) == PocketBadge("Working", .progress))
        #expect(PocketPresentation.claudeBadge(session(.waiting)) == PocketBadge("Your turn", .attention))
    }

    @Test func activities() {
        #expect(PocketPresentation.claudeActivity(nil) == "thinking")
        #expect(PocketPresentation.claudeActivity(step("Bash", "npm", .running, ago: 1)) == "running npm")
        #expect(PocketPresentation.claudeActivity(step("Bash", nil, .running, ago: 1)) == "running a command")
        #expect(PocketPresentation.claudeActivity(step("Edit", "Hero.swift", .running, ago: 1)) == "editing Hero.swift")
        #expect(PocketPresentation.claudeActivity(step("Grep", nil, .running, ago: 1)) == "searching the code")
        #expect(PocketPresentation.claudeActivity(step("create_issue", nil, .running, ago: 1)) == "using create_issue")
    }

    @Test func stepTimes() {
        #expect(PocketPresentation.claudeStepTime(step("Bash", nil, .running, ago: 84), now: now) == "1:24")
        #expect(PocketPresentation.claudeStepTime(step("Read", nil, .done, ago: 240), now: now) == "4m")
        #expect(PocketPresentation.claudeStepTime(step("Read", nil, .done, ago: 20), now: now) == "now")
        #expect(PocketPresentation.claudeStepTime(step("Read", nil, .failed, ago: 7300), now: now) == "2h")
    }

    @Test func turnAndUsage() {
        #expect(PocketPresentation.claudeFiles(session(.working)) == "3 files")
        #expect(PocketPresentation.claudeUsageTone(percent: 30) == .good)
        #expect(PocketPresentation.claudeUsageTone(percent: 62) == .attention)
        #expect(PocketPresentation.claudeUsageTone(percent: 91) == .alert)
        let usage = PocketClaude.Usage(windowPercent: 62, windowResetsAt: now.addingTimeInterval(72 * 60))
        #expect(PocketPresentation.claudeResets(usage, now: now) == "resets in 1h 12m")
        #expect(PocketPresentation.claudeResets(PocketClaude.Usage(), now: now) == nil)
        #expect(PocketPresentation.claudeCost(4.254) == "$4.25")
        #expect(PocketPresentation.claudeCost(1204.4) == "$1,204")
        #expect(PocketPresentation.claudeCost(-.infinity) == "$0.00")
    }

    @Test func replies() {
        let open = session(.waiting, accepts: true, waitingFor: 180)
        #expect(PocketPresentation.claudeReplyBlocker(open, away: true, reachable: true) == nil)
        #expect(PocketPresentation.claudeReplyBlocker(open, away: true, reachable: false) != nil)
        #expect(PocketPresentation.claudeReplyBlocker(session(.waiting), away: false, reachable: true)?.contains("Away mode") == true)
        #expect(PocketPresentation.claudeReplyBlocker(session(.waiting), away: true, reachable: true) != nil, "not held")
        #expect(PocketPresentation.claudeReplyBlocker(session(.working, accepts: true), away: true, reachable: true) != nil)
        #expect(PocketPresentation.claudeReplyBlocker(session(.asking), away: true, reachable: true) != nil)
        #expect(PocketPresentation.claudeWaitLeft(open, now: now) == "Claude waits 7m more")
        #expect(PocketPresentation.claudeWaitLeft(session(.waiting, accepts: true, waitingFor: 700), now: now) == nil)
        #expect(PocketPresentation.claudeReplyFits("Commit it"))
        #expect(!PocketPresentation.claudeReplyFits("  \n "))
        #expect(!PocketPresentation.claudeReplyFits(String(repeating: "a", count: 4001)))
        #expect(PocketPresentation.claudeTemplates.map(\.title) == ["Continue", "Commit it", "Run the tests", "Explain the diff"])
    }

    @Test func focus() {
        let first = PocketClaude.Session(id: "a", project: "a", state: .waiting)
        let second = PocketClaude.Session(id: "b", project: "b", state: .working)
        let claude = PocketClaude(sessions: [first, second])
        #expect(PocketPresentation.claudeFocus(claude, chosen: "b")?.id == "b")
        #expect(PocketPresentation.claudeFocus(claude, chosen: "gone")?.id == "a")
        #expect(PocketPresentation.claudeFocus(nil, chosen: nil) == nil)
    }

    @Test func waitRing() {
        // No deadline from the Mac: the default ten minutes, three gone.
        let open = session(.waiting, accepts: true, waitingFor: 180)
        #expect(abs((PocketPresentation.claudeWaitShare(open, now: now) ?? 0) - 0.7) < 0.0001)
        #expect(PocketPresentation.claudeWaitClock(open, now: now) == "7:00")
        // The Mac's deadline: a 30-minute wait with 90.5 s left.
        var held = session(.waiting, accepts: true, waitingFor: 1709.5)
        held.replyDeadline = now.addingTimeInterval(90.5)
        #expect(abs((PocketPresentation.claudeWaitShare(held, now: now) ?? 0) - 90.5 / 1800) < 0.0001)
        #expect(PocketPresentation.claudeWaitClock(held, now: now) == "1:31", "rounds up, never 0:00 while it waits")
        // Until I'm back: hours on the clock.
        held.replyDeadline = now.addingTimeInterval(3723)
        #expect(PocketPresentation.claudeWaitClock(held, now: now) == "1:02:03")
        // Past the deadline, or not held: nothing to count.
        held.replyDeadline = now.addingTimeInterval(-1)
        #expect(PocketPresentation.claudeWaitShare(held, now: now) == nil)
        #expect(PocketPresentation.claudeWaitClock(held, now: now) == nil)
        #expect(PocketPresentation.claudeWaitShare(session(.waiting, waitingFor: 10), now: now) == nil)
        // A deadline without a start counts against the default window, capped at full.
        var late = session(.waiting, accepts: true)
        late.replyDeadline = now.addingTimeInterval(1200)
        #expect(PocketPresentation.claudeWaitShare(late, now: now) == 1)
    }
}
