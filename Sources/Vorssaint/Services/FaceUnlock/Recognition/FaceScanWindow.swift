// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual
// Adapted from Glance by Jonathan Zhou (MIT), https://github.com/jonnyoo/glance (glance/FaceUnlockCoordinator.swift).
//
// The decision half of Glance's `observeScanWindow`, one camera frame at a time.
// Recognition and liveness run concurrently and each latches when it succeeds, so
// unlock fires the moment the second lands; liveness never fails the scan by staying
// undecided, it just keeps scanning until the deadline. Pure, so it is testable.

import Foundation

struct FaceScanWindow {
    enum Outcome: Equatable {
        case matched(name: String, similarity: Float, livenessNote: String)
        case consistentlyWrongFace
        /// A deny cue (glare, device rectangle) fired — actively rejected as a spoof regardless of match.
        case spoofSuspected(reason: String?)
    }

    /// A wake often catches the owner while they are still looking away from
    /// the camera. Require a sustained non-match rather than a few early
    /// frames before giving the failure animation.
    static let wrongFaceGraceDuration: Duration = .seconds(2)

    let livenessEnabled: Bool

    /// Set by the first consecutive non-match. A gap in face detection or
    /// a valid match clears it, so only a sustained wrong face resolves the scan.
    private(set) var wrongFaceStartedAt: ContinuousClock.Instant?
    /// Cleared the moment a detected face fails to match, so a latched match can't be handed to whoever steps in next.
    private(set) var readyMatch: ScoredIdentity?
    /// Turning liveness off in Settings makes this half permanently ready.
    private(set) var livenessConfirmed: Bool

    init(livenessEnabled: Bool) {
        self.livenessEnabled = livenessEnabled
        self.livenessConfirmed = !livenessEnabled
    }

    /// A frame with no usable face.
    mutating func observeNoFace() {
        wrongFaceStartedAt = nil
    }

    /// A frame with a face: `liveness` is that frame's snapshot (ignored with
    /// liveness off), `match` the best identity that cleared the threshold, if any.
    /// Returns the outcome once the scan is decided, nil to keep scanning.
    mutating func observe(
        match: ScoredIdentity?,
        liveness: LivenessDecision?,
        at now: ContinuousClock.Instant = .now
    ) -> Outcome? {
        // Fed regardless of match, so liveness stays a genuinely independent gate rather than one starved by recognition confidence.
        var confirmingCue: LivenessCue?
        if livenessEnabled, let liveness {
            switch liveness {
            case .denied:
                // Overrides everything, including a match and any confirmation that already happened.
                return .spoofSuspected(reason: liveness.denialReason)
            case .confirmed(let cue):
                livenessConfirmed = true
                confirmingCue = cue
            case .pending:
                break
            }
        }

        if let match {
            wrongFaceStartedAt = nil
            readyMatch = match
        } else {
            readyMatch = nil
            let startedAt = wrongFaceStartedAt ?? now
            wrongFaceStartedAt = startedAt
            if now - startedAt >= Self.wrongFaceGraceDuration {
                return .consistentlyWrongFace
            }
        }

        if let readyMatch, livenessConfirmed {
            let livenessNote = livenessEnabled
                ? (confirmingCue.map { "live via \($0.title)" } ?? "liveness clear")
                : "liveness off"
            return .matched(
                name: readyMatch.identity.name,
                similarity: readyMatch.centroidSimilarity,
                livenessNote: livenessNote
            )
        }
        return nil
    }
}

extension FaceScanWindow.Outcome {
    /// What the unlock flow is told.
    var scanOutcome: FaceUnlockScanOutcome {
        switch self {
        case .matched(let name, _, _): return .matched(name: name)
        case .consistentlyWrongFace: return .failed(.wrongFace)
        case .spoofSuspected: return .failed(.spoofSuspected)
        }
    }

    /// Glance's `lastOutcome` line, for Face Lab and diagnostics.
    var summary: String {
        switch self {
        case .matched(let name, let similarity, let note):
            return "Matched \(name) at \(String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), similarity)), \(note)."
        case .consistentlyWrongFace:
            return "Face not recognized."
        case .spoofSuspected(let reason):
            return reason ?? "Couldn't confirm a live face."
        }
    }
}
