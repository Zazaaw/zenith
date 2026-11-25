// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI
import UIKit

/// The Claude tab: what Claude Code is doing right now as a sentence, the
/// session switcher, this turn's live timeline, what Claude said and the
/// reply composer when a turn waits in Away mode, the turn's files and the
/// 5-hour allowance, and the Away switch.
struct ClaudeView: View {
    @Environment(PocketModel.self) private var model
    let now: Date

    @State private var chosen: String?

    var body: some View {
        let state = model.state
        let claude = model.claude
        let session = PocketPresentation.claudeFocus(claude, chosen: chosen)
        let freshness = model.freshness(now: now)
        VStack(alignment: .leading, spacing: 0) {
            Hero(eyebrow: session.map { "Claude · " + $0.project } ?? "Claude Code",
                 badge: claude == nil ? PocketPresentation.agentsBadge(state) : PocketPresentation.claudeBadge(session),
                 sentence: claude == nil ? PocketPresentation.agentsSentence(state)
                                         : PocketPresentation.claudeSentence(session, now: now),
                 footnote: PocketPresentation.updatedLine(freshness, now: now),
                 onSettings: { model.showingSettings = true })
                .animation(Motion.reveal, value: session?.state)
            if let claude {
                content(claude, session)
            } else if state != nil {
                notShared.padding(.horizontal, 20).padding(.top, 22)
            }
        }
    }

    @ViewBuilder
    private func content(_ claude: PocketClaude, _ session: PocketClaude.Session?) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if claude.sessions.count > 1 {
                ClaudeSessionChips(sessions: claude.sessions, selected: session?.id) { id in
                    withAnimation(Motion.spring) { chosen = id }
                }
            }
            if let session {
                switch session.state {
                case .working:
                    if !session.steps.isEmpty { ClaudeTimeline(steps: session.steps, now: now) }
                case .asking:
                    ForEach(model.claudeQuestions(session)) { ClaudeQuestionCard(question: $0, now: now) }
                    if !session.steps.isEmpty { ClaudeTimeline(steps: session.steps, now: now) }
                case .waiting, .done:
                    if let said = session.lastMessage { ClaudeSaidCard(session: session, text: said, now: now).blurFade() }
                    ReplyComposer(session: session, away: claude.away, now: now).id(session.id)
                }
                ClaudeAwayRow(away: claude.away, minutes: claude.awayMinutes, now: now)
                if session.state == .waiting || session.state == .done, !session.steps.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "This turn", trailing: PocketPresentation.claudeFiles(session))
                        ClaudeTimeline(steps: session.steps, now: now)
                    }
                }
            } else {
                ClaudeAwayRow(away: claude.away, minutes: claude.awayMinutes, now: now)
            }
            cards(session, claude.usage)
        }
        .padding(.horizontal, 20).padding(.top, 20)
        .animation(Motion.spring, value: session?.id)
    }

    /// The turn's files beside the 5-hour allowance.
    @ViewBuilder
    private func cards(_ session: PocketClaude.Session?, _ usage: PocketClaude.Usage?) -> some View {
        let turn = session.flatMap { $0.state == .working && ($0.filesChanged > 0 || !$0.steps.isEmpty) ? $0 : nil }
        if turn != nil || usage != nil {
            HStack(alignment: .top, spacing: 10) {
                if let turn { ClaudeTurnCard(session: turn) }
                if let usage { ClaudeUsageCard(usage: usage, now: now) }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var notShared: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Claude Code isn't shared in detail").font(K.sans(15, bold: true))
            Text("Update Zenith on your Mac and keep Claude Code on in Settings, iPhone & Watch. Claude Code's hooks connect in Settings, Dynamic Island, AI agents.")
                .font(K.sans(13)).foregroundStyle(K.muted).fixedSize(horizontal: false, vertical: true)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(K.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(K.border, lineWidth: 1))
    }
}

/// One chip per session, its state as a dot; the chosen one filled.
struct ClaudeSessionChips: View {
    let sessions: [PocketClaude.Session]
    let selected: String?
    let choose: (String) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                    let on = session.id == selected
                    Button {
                        Haptics.select()
                        choose(session.id)
                    } label: {
                        HStack(spacing: 7) {
                            Circle().fill(K.color(PocketPresentation.claudeTone(session.state))).frame(width: 7, height: 7)
                            Text(session.project).font(K.sans(13, bold: true)).lineLimit(1)
                        }
                        .foregroundStyle(on ? K.bg : K.fg)
                        .padding(.horizontal, 13).padding(.vertical, 8)
                        .background(on ? K.fg : K.card, in: Capsule())
                        .overlay(Capsule().strokeBorder(on ? Color.clear : K.border, lineWidth: 1))
                    }
                    .pressable()
                    .blurFade(index: index)
                    .accessibilityLabel("\(session.project), \(PocketPresentation.claudeBadge(session).text)")
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -20)
    }
}

/// "Claude said": the end of Claude's last reply, with the turn's files.
struct ClaudeSaidCard: View {
    let session: PocketClaude.Session
    let text: String
    let now: Date
    @State private var reading = false

    /// A reply longer than this shows as a preview with "Read all".
    private var isLong: Bool { text.count > 420 || text.filter { $0 == "\n" }.count > 7 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("CLAUDE SAID").font(K.sans(10, bold: true)).tracking(1).foregroundStyle(K.faint)
                Spacer()
                if let since = session.waitingSince {
                    Text(PocketPresentation.ago(since, now: now)).font(K.mono(10.5)).foregroundStyle(K.faint)
                }
            }
            Text(Self.markdown(text)).font(K.sans(15)).foregroundStyle(K.fg).lineSpacing(3)
                .lineLimit(isLong ? 8 : nil)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                // The preview fades out at its last lines instead of stopping hard.
                .mask {
                    if isLong {
                        LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.7),
                                               .init(color: .black.opacity(0), location: 1)], startPoint: .top, endPoint: .bottom)
                    } else {
                        Rectangle()
                    }
                }
            if isLong {
                Button {
                    Haptics.tap()
                    reading = true
                } label: {
                    HStack(spacing: 6) {
                        Text("Read all").font(K.sans(13, bold: true))
                        Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(K.fg)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(K.track, in: Capsule())
                }
                .pressable()
            }
            if session.filesChanged > 0 {
                HStack(spacing: 8) {
                    Status(badge: PocketBadge(PocketPresentation.claudeFiles(session), .info))
                    Text("+\(session.added)").font(K.mono(11, .semibold)).foregroundStyle(K.emerald)
                    Text("−\(session.removed)").font(K.mono(11, .semibold)).foregroundStyle(K.red)
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(K.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(K.border, lineWidth: 1))
        .sheet(isPresented: $reading) {
            ClaudeMessageSheet(session: session, text: text, now: now)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    /// Claude writes Markdown: bold, code and links read as such, the rest as written.
    static func markdown(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }
}

/// Claude's whole reply, to read at leisure: paragraphs and lists as Claude
/// wrote them, selectable, with a copy button.
struct ClaudeMessageSheet: View {
    let session: PocketClaude.Session
    let text: String
    let now: Date
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(session.project.uppercased()).font(K.sans(11, bold: true)).tracking(1.1).foregroundStyle(K.faint)
                        Spacer()
                        if let since = session.waitingSince {
                            Text(PocketPresentation.ago(since, now: now)).font(K.mono(11)).foregroundStyle(K.faint)
                        }
                    }
                    ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                        Text(ClaudeSaidCard.markdown(paragraph))
                            .font(paragraph.hasPrefix("```") ? K.mono(13) : K.sans(16))
                            .foregroundStyle(K.fg).lineSpacing(4)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .blurFade(index: min(index, 12))
                    }
                }
                .padding(20)
            }
            .background(K.bg)
            .navigationTitle("Claude said")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(copied ? "Copied" : "Copy") {
                        UIPasteboard.general.string = text
                        Haptics.success()
                        withAnimation(Motion.quick) { copied = true }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }

    /// Blank lines split paragraphs; a fenced code block stays one piece.
    private var paragraphs: [String] {
        var result: [String] = []
        var current: [String] = []
        var inCode = false
        for line in text.components(separatedBy: "\n") {
            if line.hasPrefix("```") { inCode.toggle() }
            if line.trimmingCharacters(in: .whitespaces).isEmpty && !inCode {
                if !current.isEmpty { result.append(current.joined(separator: "\n")); current = [] }
            } else {
                current.append(line)
            }
        }
        if !current.isEmpty { result.append(current.joined(separator: "\n")) }
        return result
    }
}

/// "This turn": how many files Claude wrote and their lines.
struct ClaudeTurnCard: View {
    let session: PocketClaude.Session

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("THIS TURN").font(K.sans(10, bold: true)).tracking(1).foregroundStyle(K.faint)
            Text(PocketPresentation.claudeFiles(session)).font(K.mono(18, .semibold))
            HStack(spacing: 6) {
                Text("+\(session.added)").foregroundStyle(K.emerald).countingNumber(Double(session.added))
                Text("−\(session.removed)").foregroundStyle(K.red).countingNumber(Double(session.removed))
            }
            .font(K.mono(11, .semibold))
        }
        .padding(14).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(K.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(K.border, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

/// The 5-hour allowance and the spend, as the island's agents page reads them.
struct ClaudeUsageCard: View {
    let usage: PocketClaude.Usage
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let percent = usage.windowPercent {
                let tint = K.color(PocketPresentation.claudeUsageTone(percent: percent))
                Text("5-HOUR LIMIT").font(K.sans(10, bold: true)).tracking(1).foregroundStyle(K.faint)
                Text("\(percent)%").font(K.mono(18, .semibold)).countingNumber(Double(percent))
                Meter(value: Double(percent) / 100, tint: tint, height: 4).padding(.vertical, 2)
            } else {
                Text("TODAY").font(K.sans(10, bold: true)).tracking(1).foregroundStyle(K.faint)
                Text(PocketPresentation.claudeCost(usage.costToday ?? 0)).font(K.mono(18, .semibold))
            }
            ForEach(lines, id: \.self) { line in
                Text(line).font(K.mono(10)).foregroundStyle(K.faint).lineLimit(1)
            }
        }
        .padding(14).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(K.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(K.border, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private var lines: [String] {
        var lines: [String] = []
        if let resets = PocketPresentation.claudeResets(usage, now: now) { lines.append(resets) }
        if usage.windowPercent != nil, let today = usage.costToday { lines.append(PocketPresentation.claudeCost(today) + " today") }
        if let week = usage.costWeek { lines.append(PocketPresentation.claudeCost(week) + " this week") }
        if let percent = usage.weekPercent { lines.append("week \(percent)%") }
        return lines
    }
}

/// Away mode: while on, a turn that ends waits on the Mac for a reply from here.
struct ClaudeAwayRow: View {
    @Environment(PocketModel.self) private var model
    let away: Bool
    /// The chosen wait; nil from a Zenith that can't choose one.
    let minutes: Int?
    let now: Date
    /// What was asked, until the Mac's state or answer says otherwise.
    @State private var asked: Bool?
    @State private var askedMinutes: Int?

    var body: some View {
        let on = asked ?? away
        let wait = askedMinutes ?? minutes
        VStack(alignment: .leading, spacing: 12) {
            row(on: on, wait: wait)
            if on, let wait {
                choices(wait).transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(K.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(K.border, lineWidth: 1))
        .animation(Motion.toggle, value: on)
        .onChange(of: away) { _, _ in asked = nil }
        .onChange(of: minutes) { _, _ in askedMinutes = nil }
        .onChange(of: model.toast) { _, toast in
            if toast?.ok == false { asked = nil; askedMinutes = nil }
        }
    }

    private func row(on: Bool, wait: Int?) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(K.border, lineWidth: 1)
                .overlay(Image(systemName: on ? "figure.walk.departure" : "desktopcomputer")
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(on ? K.emerald : K.muted)
                    .contentTransition(.symbolEffect(.replace)))
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text("Away mode").font(K.sans(15, bold: true))
                Text(PocketPresentation.awayCaption(on: on, minutes: wait))
                    .font(K.mono(11)).foregroundStyle(K.faint).fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
            }
            Spacer(minLength: 8)
            Toggle("Away mode", isOn: Binding(get: { on }, set: set))
                .labelsHidden()
                .tint(K.emerald)
                .disabled(!model.canControl(now: now))
        }
    }

    /// How long a finished turn waits: 10m · 30m · 1h · 2h · Until I'm back.
    private func choices(_ wait: Int) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(PocketPresentation.awayChoices, id: \.self) { choice in
                    let chosen = choice == wait
                    Button { pick(choice) } label: {
                        Text(PocketPresentation.awayChoiceLabel(choice))
                            .font(K.sans(13, bold: chosen))
                            .foregroundStyle(chosen ? K.emerald : K.muted)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(chosen ? K.emerald.opacity(0.14) : K.bg, in: Capsule())
                            .overlay(Capsule().strokeBorder(chosen ? K.emerald.opacity(0.4) : K.border, lineWidth: 1))
                    }
                    .pressable(haptic: false)
                    .disabled(!model.canControl(now: now))
                    .accessibilityAddTraits(chosen ? .isSelected : [])
                }
            }
            .padding(.leading, 44)
        }
        .scrollClipDisabled()
    }

    private func pick(_ choice: Int) {
        guard choice != (askedMinutes ?? minutes), model.setAwayWait(choice) else { return }
        Haptics.tap()
        withAnimation(Motion.toggle) { askedMinutes = choice }
        Task {
            try? await Task.sleep(for: .seconds(PocketModel.resultTimeout + 2))
            if askedMinutes == choice { askedMinutes = nil }
        }
    }

    private func set(_ next: Bool) {
        guard model.setAway(next) else { return }
        Haptics.tap()
        withAnimation(Motion.toggle) { asked = next }
        Task {
            try? await Task.sleep(for: .seconds(PocketModel.resultTimeout + 2))
            if asked == next { asked = nil }
        }
    }
}

/// A permission question this session asks, as the island bar shows it.
struct ClaudeQuestionCard: View {
    let question: PocketMacState.AgentQuestion
    let now: Date

    var body: some View {
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
                    .background(K.bg, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            AnswerButtons(question: question)
        }
        .padding(16)
        .background(K.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(K.amber.opacity(0.28), lineWidth: 1))
    }
}
