// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: the lock screen's job rings (ZenithLockScreenJobFeedSupport).
/// Each source's value becomes the right ring, and a finished job keeps its
/// check for a moment and then goes. Plain values only, no services.
enum LockScreenJobFeedTests {
    private typealias Support = ZenithLockScreenJobFeedSupport

    static func run(_ suite: TestSuite) {
        exports(suite)
        copies(suite)
        commands(suite)
        vercel(suite)
        lingering(suite)
        ordering(suite)
        switches(suite)
    }

    private static let start = Date(timeIntervalSince1970: 1_800_000_000)

    private static func export(_ phase: ExportTrackerSupport.Activity.Phase, producer: String?) -> ExportTrackerSupport.Activity {
        ExportTrackerSupport.Activity(id: "/Movies/Wedding.mov", phase: phase, path: "/Movies/Wedding.mov", name: "Wedding.mov",
                                      count: nil,
                                      producer: producer.map { .init(name: $0, kind: .video, tint: 0) },
                                      started: start, bytes: nil, duration: 0, others: 0)
    }

    private static func exports(_ suite: TestSuite) {
        suite.expect(Support.export(nil, fallback: "Export") == nil, "no export, no ring")
        let running = Support.export(export(.running, producer: "DaVinci Resolve"), fallback: "Export")
        suite.expect(running?.label == "DaVinci" && running?.source == .export
                        && running?.phase == .running(fraction: nil),
                     "a DaVinci render runs as \"DaVinci\", its length unknown: \(String(describing: running))")
        suite.expect(Support.export(export(.running, producer: "OBS"), fallback: "Export")?.label == "OBS",
                     "another app keeps the name the tracker gives it")
        suite.expect(Support.export(export(.running, producer: nil), fallback: "Export")?.label == "Export",
                     "an export nobody claims reads as the fallback")
        suite.expect(Support.export(export(.running, producer: "  "), fallback: "Export")?.label == "Export",
                     "a blank app name reads as the fallback")
        let done = Support.export(export(.finished, producer: "DaVinci Resolve"), fallback: "Export")
        suite.expect(done?.phase == .finished && done?.id == running?.id, "the same export finishes under its own id")
    }

    private static func copies(_ suite: TestSuite) {
        var progress = CardImportProgress()
        let preparing = Support.copy(id: "import:A", source: .cardImport, label: "Import", stage: .preparing, progress: progress)
        suite.expect(preparing.phase == .running(fraction: nil), "an import still counting its files is indeterminate")
        let counting = Support.copy(id: "import:A", source: .cardImport, label: "Import", stage: .copying, progress: progress)
        suite.expect(counting.phase == .running(fraction: nil), "a copy with nothing measured yet is indeterminate")
        progress.totalFiles = 4
        progress.totalBytes = 400
        progress.copiedBytes = 100
        let copying = Support.copy(id: "import:A", source: .cardImport, label: "Import", stage: .copying, progress: progress)
        suite.expect(copying.phase == .running(fraction: 0.25), "a copy reports its fraction: \(copying.phase)")
        suite.expect(Support.copy(id: "b", source: .backup, label: "Backup", stage: .finished, progress: progress).phase == .finished,
                     "a finished backup finishes")
        suite.expect(Support.copy(id: "b", source: .backup, label: "Backup", stage: .failed, progress: progress).phase == .failed,
                     "a failed backup fails")
    }

    private static func commands(_ suite: TestSuite) {
        suite.expect(Support.command(nil) == nil, "no command, no ring")
        let running = Support.command(.running(id: "7", program: "npm", folder: "zenith", start: start, others: 1, long: false))
        suite.expect(running == Support.Input(id: "command:7", source: .command, label: "npm", phase: .running(fraction: nil)),
                     "a long command runs under its program's name: \(String(describing: running))")
        let passed = Support.command(.finished(id: "7", program: "npm", folder: nil, duration: 90, succeeded: true))
        suite.expect(passed?.phase == .finished && passed?.id == running?.id, "a command that succeeded finishes")
        let failed = Support.command(.finished(id: "7", program: "npm", folder: nil, duration: 90, succeeded: false))
        suite.expect(failed?.phase == .failed, "a command that failed shows no check")
    }

    private static func deployment(_ uid: String, _ state: VercelSupport.State) -> VercelSupport.Deployment {
        VercelSupport.Deployment(uid: uid, project: "zenith-site", host: nil, state: state, created: start, isProduction: true,
                                 branch: nil, commitMessage: nil, inspectorURL: nil, scope: nil)
    }

    private static func vercel(_ suite: TestSuite) {
        let inputs = Support.vercel([deployment("q", .queued), deployment("i", .initializing), deployment("b", .building),
                                     deployment("r", .ready), deployment("e", .error), deployment("c", .canceled),
                                     deployment("u", .unknown)])
        suite.expect(inputs.map(\.phase) == [.running(fraction: nil), .running(fraction: nil), .running(fraction: nil),
                                             .finished, .failed, .failed],
                     "queued, initializing and building run; ready finishes; error and cancelled fail: \(inputs.map(\.phase))")
        suite.expect(!inputs.contains { $0.id == "vercel:u" }, "a state Vercel did not name is left out")
        suite.expect(inputs.allSatisfy { $0.label == "zenith-site" && $0.source == .vercel },
                     "a deployment is labelled by its project")
    }

    private static func lingering(_ suite: TestSuite) {
        let on: (ZenithLockScreenJobSource) -> Bool = { _ in true }
        let running = Support.Input(id: "j", source: .export, label: "DaVinci", phase: .running(fraction: nil))
        let finished = Support.Input(id: "j", source: .export, label: "DaVinci", phase: .finished)
        var state = Support.State()

        // A result from before the feed looked is not news.
        suite.expect(state.update([finished], now: start, isOn: on).isEmpty, "a job never seen running does not show its check")

        let shown = state.update([running], now: start, isOn: on)
        suite.expect(shown == [ZenithLockScreenJob(id: "j", source: .export, label: "DaVinci", fraction: nil, finished: false)],
                     "a running job shows: \(shown)")
        suite.expect(state.nextExpiry == nil, "nothing to wake for while a job only runs")

        let done = start.addingTimeInterval(10)
        let checked = state.update([finished], now: done, isOn: on)
        suite.expect(checked.first?.finished == true && checked.first?.fraction == 1, "a finished job shows its check, full")
        suite.expect(state.nextExpiry == done.addingTimeInterval(Support.finishedLinger),
                     "it is due to go \(Support.finishedLinger) s after it finished")

        // The source repeating its result does not keep the check longer.
        _ = state.update([finished], now: done.addingTimeInterval(2), isOn: on)
        suite.expect(state.nextExpiry == done.addingTimeInterval(Support.finishedLinger), "repeating the result keeps its moment")

        // The source moving on keeps the check until its moment ends.
        suite.expect(state.update([], now: done.addingTimeInterval(2.5), isOn: on).first?.finished == true,
                     "a finished job stays once its source moved on")
        suite.expect(state.update([finished], now: done.addingTimeInterval(Support.finishedLinger), isOn: on).isEmpty,
                     "and goes once its moment ends")
        suite.expect(state.nextExpiry == nil, "nothing is left to wake for")

        // Gone or failed while running: no check.
        var gone = Support.State()
        _ = gone.update([running], now: start, isOn: on)
        suite.expect(gone.update([], now: start.addingTimeInterval(1), isOn: on).isEmpty, "a job its source stops reporting goes")
        var failed = Support.State()
        _ = failed.update([running], now: start, isOn: on)
        let failure = Support.Input(id: "j", source: .export, label: "DaVinci", phase: .failed)
        suite.expect(failed.update([failure], now: start.addingTimeInterval(1), isOn: on).isEmpty, "a failed job goes at once")

        // Running again after a check starts over.
        var again = Support.State()
        _ = again.update([running], now: start, isOn: on)
        _ = again.update([finished], now: start.addingTimeInterval(1), isOn: on)
        let rerun = again.update([running], now: start.addingTimeInterval(2), isOn: on)
        suite.expect(rerun.first?.finished == false && again.nextExpiry == nil, "a job that runs again loses its check")

        // Fractions stay within the ring.
        var clamped = Support.State()
        let over = clamped.update([Support.Input(id: "x", source: .cardImport, label: "Import", phase: .running(fraction: 1.4))],
                                  now: start, isOn: on)
        suite.expect(over.first?.fraction == 1, "a fraction past the end draws a full ring")
    }

    private static func ordering(_ suite: TestSuite) {
        let on: (ZenithLockScreenJobSource) -> Bool = { _ in true }
        var state = Support.State()
        let first = Support.Input(id: "a", source: .command, label: "npm", phase: .running(fraction: nil))
        let second = Support.Input(id: "b", source: .vercel, label: "site", phase: .running(fraction: nil))
        _ = state.update([first], now: start, isOn: on)
        let both = state.update([first, second], now: start.addingTimeInterval(5), isOn: on)
        suite.expect(both.map(\.id) == ["b", "a"], "the newest job comes first: \(both.map(\.id))")
        let later = state.update([second, first], now: start.addingTimeInterval(6), isOn: on)
        suite.expect(later.map(\.id) == ["b", "a"], "the order follows when each started, not the sources' order")
        let duplicate = state.update([first, Support.Input(id: "a", source: .command, label: "make", phase: .running(fraction: nil))],
                                     now: start.addingTimeInterval(7), isOn: on)
        suite.expect(duplicate.filter { $0.id == "a" }.map(\.label) == ["npm"], "one ring per job, the first report wins")
    }

    private static func switches(_ suite: TestSuite) {
        var state = Support.State()
        let inputs = [Support.Input(id: "a", source: .export, label: "DaVinci", phase: .running(fraction: nil)),
                      Support.Input(id: "b", source: .vercel, label: "site", phase: .running(fraction: nil))]
        let shown = state.update(inputs, now: start, isOn: { $0 != .vercel })
        suite.expect(shown.map(\.id) == ["a"], "a source switched off shows no ring")

        // A lingering check goes with its source's switch.
        _ = state.update([Support.Input(id: "a", source: .export, label: "DaVinci", phase: .finished)],
                         now: start.addingTimeInterval(1), isOn: { _ in true })
        suite.expect(state.update([], now: start.addingTimeInterval(2), isOn: { $0 != .export }).isEmpty,
                     "a finished job of a source switched off goes too")

        // The switches as stored: every source needs the job progress itself.
        let domain = "com.vorssaint.tests.lockscreen-jobs"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.removePersistentDomain(forName: domain)
        suite.expect(ZenithLockScreenJobSource.allCases.allSatisfy { $0.isOn(in: defaults) }, "every source starts on")
        defaults.set(false, forKey: DefaultsKey.zenithLockJobBackup)
        suite.expect(!ZenithLockScreenJobSource.backup.isOn(in: defaults) && ZenithLockScreenJobSource.export.isOn(in: defaults),
                     "each source has its own switch")
        defaults.set(false, forKey: DefaultsKey.zenithLockJobs)
        suite.expect(!ZenithLockScreenJobSource.allCases.contains { $0.isOn(in: defaults) },
                     "job progress off turns every source off")
    }
}
