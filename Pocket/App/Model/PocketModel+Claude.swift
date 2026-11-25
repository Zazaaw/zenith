// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation
import LocalAuthentication
import PocketKit

/// The Claude tab's commands and lookups.
extension PocketModel {
    /// Claude Code in detail, nil from a Zenith that doesn't send it (or with sharing off).
    var claude: PocketClaude? { state?.claude }

    /// Away mode on the Mac; the result comes back as a toast and the next state.
    @discardableResult
    func setAway(_ on: Bool) -> Bool { send(.setAway(on)) }

    /// How long a finished turn waits in Away mode; 0 = until the person is back.
    @discardableResult
    func setAwayWait(_ minutes: Int) -> Bool { send(.setAwayWait(minutes: minutes)) }

    /// Sends a reply to a session waiting in Away mode. Checked here as on
    /// the Mac: something to say, within the limit.
    @discardableResult
    func replyToClaude(_ session: PocketClaude.Session, text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard PocketPresentation.claudeReplyFits(trimmed) else {
            show(trimmed.isEmpty ? "Write something to send." : "That reply is too long. Keep it under 4,000 characters.", ok: false)
            return false
        }
        return send(.claudeReply(sessionID: session.id, text: trimmed))
    }

    /// The permission questions this session asks (the Mac names them `<session>@<time>`).
    func claudeQuestions(_ session: PocketClaude.Session) -> [PocketMacState.AgentQuestion] {
        state?.questions.filter { $0.id.hasPrefix(session.id + "@") } ?? []
    }
}

/// Face ID, Touch ID or the passcode before a reply goes: a reply makes
/// Claude Code act on the Mac.
enum OwnerCheck {
    enum Outcome: Equatable {
        case passed
        case cancelled
        case unavailable(String)
    }

    static func confirm(reason: String) async -> Outcome {
        let context = LAContext()
        var problem: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &problem) else {
            return .unavailable("Set a passcode on this iPhone to send replies to Claude.")
        }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) ? .passed : .cancelled
        } catch {
            return .cancelled
        }
    }
}
