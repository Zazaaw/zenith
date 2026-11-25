// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI

/// Claude Code on the Mac: the questions waiting, the sessions, and today's
/// coding time.
struct AgentsView: View {
    @Environment(PocketModel.self) private var model
    let now: Date

    var body: some View {
        let state = model.state
        let freshness = model.freshness(now: now)
        VStack(alignment: .leading, spacing: 0) {
            Hero(eyebrow: "Claude Code", badge: PocketPresentation.agentsBadge(state),
                 sentence: PocketPresentation.agentsSentence(state),
                 footnote: PocketPresentation.updatedLine(freshness, now: now),
                 onSettings: { model.showingSettings = true })
            if let state {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(state.questions) { question($0) }
                }
                .padding(.horizontal, 20).padding(.top, 22)
                VStack(alignment: .leading, spacing: 10) {
                    if !state.sessions.isEmpty {
                        SectionLabel(text: "Sessions")
                        Rows {
                            ForEach(Array(state.sessions.enumerated()), id: \.element.id) { index, session in
                                Row(symbol: symbol(session.status), title: session.project,
                                    meta: PocketPresentation.sessionLine(session, now: now),
                                    divider: index < state.sessions.count - 1) {
                                    Status(badge: PocketPresentation.sessionBadge(session))
                                }
                            }
                        }
                    }
                    if let coding = state.coding { codingToday(coding).padding(.top, state.sessions.isEmpty ? 0 : 8) }
                }
                .padding(.horizontal, 20).padding(.top, state.questions.isEmpty ? 26 : 20)
            }
        }
    }

    private func question(_ question: PocketMacState.AgentQuestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(question.project).font(K.mono(11)).foregroundStyle(K.faint).lineLimit(1)
                Spacer()
                Text(PocketPresentation.ago(question.askedAt, now: now)).font(K.mono(11)).foregroundStyle(K.faint)
            }
            Text(PocketPresentation.questionTitle(question)).font(K.sans(19, bold: true)).tracking(-0.3)
            if let detail = PocketPresentation.questionDetail(question) {
                Text(detail).font(K.mono(12.5)).foregroundStyle(K.muted).lineLimit(3)
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            AnswerButtons(question: question)
        }
        .padding(16)
        .background(K.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(K.amber.opacity(0.28), lineWidth: 1))
    }

    private func symbol(_ status: PocketMacState.AgentSession.Status) -> String {
        switch status {
        case .running: return "circle.dotted"
        case .waiting: return "hand.raised"
        case .done: return "checkmark"
        }
    }

    /// No week of history comes from the Mac, so today stands alone.
    private func codingToday(_ coding: PocketMacState.Coding) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Coding today", trailing: coding.goalSeconds.map { "goal " + PocketPresentation.duration(seconds: TimeInterval($0)) })
            VStack(alignment: .leading, spacing: 8) {
                Text(PocketPresentation.duration(seconds: TimeInterval(coding.seconds))).font(K.mono(28, .semibold))
                if let progress = PocketPresentation.codingProgress(coding) { Meter(value: progress, tint: K.blue, height: 4) }
                if let language = coding.topLanguage, !language.isEmpty {
                    Text(language.lowercased() + (coding.topLanguagePercent.map { " \($0)%" } ?? ""))
                        .font(K.mono(11)).foregroundStyle(K.faint)
                }
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(K.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(K.border, lineWidth: 1))
            .accessibilityElement(children: .combine)
        }
    }
}
