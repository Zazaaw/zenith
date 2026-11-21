// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: what ZenithLockScreenJobFeed decides, apart from the services
/// it reads, so the tests can drive it with plain values.
///
/// Each source becomes zero or more inputs: a job running (with its fraction
/// when known), one that finished, or one that failed. The state turns them
/// into the lock screen's jobs: a running job shows; a finished one that was
/// seen running stays with its check for `finishedLinger`, then goes; a failed
/// one goes at once, and so does one whose source stops reporting it.
enum ZenithLockScreenJobFeedSupport {
    /// How long a finished job keeps its check before it is dropped.
    static let finishedLinger: TimeInterval = 3

    enum Phase: Equatable {
        /// `fraction` 0...1 when known, nil for an indeterminate ring.
        case running(fraction: Double?)
        case finished
        case failed
    }

    struct Input: Equatable {
        let id: String
        let source: ZenithLockScreenJobSource
        let label: String
        let phase: Phase
    }

    /// A copy's stage, as the card import and the backup both report it.
    enum Stage: Equatable {
        /// Counting files: nothing to measure yet.
        case preparing
        case copying
        case finished
        case failed
    }

    // MARK: Mapping

    /// The export the closed island shows, labelled by the app writing it.
    static func export(_ activity: ExportTrackerSupport.Activity?, fallback: String) -> Input? {
        guard let activity else { return nil }
        let name = activity.producer?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return Input(id: "export:" + activity.id, source: .export,
                     label: name.isEmpty ? fallback : shortName(name),
                     phase: activity.phase == .running ? .running(fraction: nil) : .finished)
    }

    /// A card import or a backup: the copy's fraction once there are files to count.
    static func copy(id: String, source: ZenithLockScreenJobSource, label: String, stage: Stage,
                     progress: CardImportProgress) -> Input {
        let phase: Phase
        switch stage {
        case .preparing: phase = .running(fraction: nil)
        case .copying:
            let measured = progress.totalBytes > 0 || progress.totalFiles > 0
            phase = .running(fraction: measured ? progress.fraction : nil)
        case .finished: phase = .finished
        case .failed: phase = .failed
        }
        return Input(id: id, source: source, label: label, phase: phase)
    }

    /// The long command the closed island shows, by its program's name.
    static func command(_ activity: CommandActivitySupport.Activity?) -> Input? {
        guard let activity else { return nil }
        let phase: Phase
        switch activity {
        case .running: phase = .running(fraction: nil)
        case .finished(_, _, _, _, let succeeded): phase = succeeded ? .finished : .failed
        }
        return Input(id: "command:" + activity.id, source: .command, label: activity.program, phase: phase)
    }

    /// Every deployment Vercel listed: building ones run, a ready one
    /// finished, an errored or cancelled one failed.
    static func vercel(_ deployments: [VercelSupport.Deployment]) -> [Input] {
        deployments.compactMap { deployment in
            let phase: Phase
            switch deployment.state {
            case .queued, .initializing, .building: phase = .running(fraction: nil)
            case .ready: phase = .finished
            case .error, .canceled: phase = .failed
            case .unknown: return nil
            }
            return Input(id: "vercel:" + deployment.uid, source: .vercel, label: deployment.project, phase: phase)
        }
    }

    /// Names that fit a ring's label: "DaVinci" rather than "DaVinci Resolve".
    static func shortName(_ name: String) -> String {
        let short = ["DaVinci Resolve": "DaVinci", "Final Cut Pro": "Final Cut", "Lightroom Classic": "Lightroom",
                     "Premiere Pro": "Premiere"]
        return short[name] ?? name
    }

    // MARK: Lingering

    struct State: Equatable {
        private struct Entry: Equatable {
            var job: ZenithLockScreenJob
            let firstSeen: Date
            /// Set once the job finished.
            var expires: Date?
        }

        private var entries: [String: Entry] = [:]

        init() {}

        /// Applies the sources' inputs now; returns the jobs to show, newest first.
        mutating func update(_ inputs: [Input], now: Date,
                             isOn: (ZenithLockScreenJobSource) -> Bool) -> [ZenithLockScreenJob] {
            var next: [String: Entry] = [:]
            for input in inputs where isOn(input.source) && next[input.id] == nil {
                let old = entries[input.id]
                switch input.phase {
                case .running(let fraction):
                    let job = ZenithLockScreenJob(id: input.id, source: input.source, label: input.label,
                                                  fraction: fraction.map { min(1, max(0, $0)) }, finished: false)
                    next[input.id] = Entry(job: job, firstSeen: old?.firstSeen ?? now, expires: nil)
                case .finished:
                    // Only a job seen running is news; a result reported
                    // from before (a last import, an old deployment) is not.
                    guard let old else { continue }
                    let expires = old.expires ?? now.addingTimeInterval(finishedLinger)
                    guard expires > now else { continue }
                    let job = ZenithLockScreenJob(id: input.id, source: input.source, label: input.label,
                                                  fraction: 1, finished: true)
                    next[input.id] = Entry(job: job, firstSeen: old.firstSeen, expires: expires)
                case .failed:
                    continue
                }
            }
            // A finished job keeps its moment even once its source moved on.
            for (id, entry) in entries where next[id] == nil && isOn(entry.job.source) {
                if let expires = entry.expires, expires > now { next[id] = entry }
            }
            entries = next
            return jobs
        }

        /// What shows, newest first.
        var jobs: [ZenithLockScreenJob] {
            entries.values.sorted {
                $0.firstSeen != $1.firstSeen ? $0.firstSeen > $1.firstSeen : $0.job.id < $1.job.id
            }.map(\.job)
        }

        /// When a finished job is due to go, nil while none lingers.
        var nextExpiry: Date? { entries.values.compactMap(\.expires).min() }
    }
}
