// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI

/// Claude Code on the wrist: the star companion and what the session does,
/// the end of Claude's last message, a reply (quick ones, or said or
/// written with the system's input), and Away mode with its wait.
struct ClaudePage: View {
    @Environment(WatchModel.self) private var model
    @State private var choosingWait = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date
            let claude = model.state?.claude
            let session = PocketPresentation.claudeFocus(claude, chosen: nil)
            let reachable = model.freshness(now: now).isReachable
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 0) {
                        Eyebrow(text: session?.project ?? "Claude")
                        Spacer(minLength: 4)
                        ClaudeMascot(mood: ClaudeMascot.Mood(session?.state), size: 34)
                            .frame(width: 64, height: 50)
                    }
                    SentenceText(sentence: PocketPresentation.claudeSentence(session, now: now))
                    if let session, session.acceptsReply { held(session, now: now) }
                    if let message = session?.lastMessage, !message.isEmpty {
                        Text(message)
                            .font(.system(size: 14))
                            .foregroundStyle(K.muted)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(K.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .accessibilityLabel("Claude said: \(message)")
                    }
                    if let session { replies(session, away: claude?.away ?? false, reachable: reachable) }
                    if let claude { awayRow(claude) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: session?.state)
        }
        .containerBackground(K.purple.opacity(0.2).gradient, for: .tabView)
        .sheet(isPresented: $choosingWait) {
            WaitChoices(current: model.state?.claude?.awayMinutes) { minutes in
                choosingWait = false
                model.setAwayWait(minutes)
            }
        }
    }

    /// A held turn's countdown: a ring that empties and the time left.
    private func held(_ session: PocketClaude.Session, now: Date) -> some View {
        let share = PocketPresentation.claudeWaitShare(session, now: now) ?? 0
        return HStack(spacing: 8) {
            ZStack {
                Circle().stroke(K.track, lineWidth: 3)
                Circle().trim(from: 0, to: share)
                    .stroke(K.amber, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: share)
            }
            .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(PocketPresentation.claudeWaitClock(session, now: now) ?? "0:00")
                    .font(.system(size: 15, weight: .bold).monospacedDigit())
                    .foregroundStyle(K.amber)
                    .contentTransition(.numericText(countsDown: true))
                Text(PocketPresentation.claudeWaitLeft(session, now: now) ?? "Claude stopped waiting")
                    .font(.system(size: 11)).foregroundStyle(K.faint).lineLimit(2)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func replies(_ session: PocketClaude.Session, away: Bool, reachable: Bool) -> some View {
        if let blocker = PocketPresentation.claudeReplyBlocker(session, away: away, reachable: reachable) {
            Text(blocker).font(.system(size: 12)).foregroundStyle(K.faint)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            let sending = model.isBusy(.claudeReply(sessionID: session.id, text: ""))
            VStack(spacing: 6) {
                ForEach(PocketPresentation.claudeTemplates, id: \.title) { template in
                    Button {
                        model.reply(to: session, text: template.text)
                    } label: {
                        Text(template.title).font(.system(size: 14, weight: .semibold)).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                }
                TextFieldLink(prompt: Text("Reply to Claude")) {
                    Label("Reply…", systemImage: "mic.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                } onSubmit: { text in
                    model.reply(to: session, text: text)
                }
                .buttonStyle(.glassProminent)
                .tint(K.amber)
            }
            .disabled(sending)
            .opacity(sending ? 0.5 : 1)
            .animation(Motion.quick, value: sending)
        }
    }

    private func awayRow(_ claude: PocketClaude) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: Binding(get: { claude.away }, set: { model.setAway($0) })) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Away").font(.system(size: 15, weight: .bold))
                    Text(claude.away ? "Turns wait for you" : "Claude stops as usual")
                        .font(.system(size: 11)).foregroundStyle(K.faint)
                }
            }
            .tint(K.amber)
            .disabled(model.isBusy(.setAway(true)))
            if claude.away, let minutes = claude.awayMinutes {
                Button { choosingWait = true } label: {
                    HStack {
                        Text("Wait").font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Text(PocketPresentation.awayChoiceLabel(minutes)).font(.system(size: 14)).foregroundStyle(K.muted)
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).foregroundStyle(K.faint)
                    }
                }
                .buttonStyle(.glass)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.top, 4)
        .animation(Motion.spring, value: claude.away)
    }
}

/// How long a finished turn waits in Away mode.
private struct WaitChoices: View {
    let current: Int?
    let choose: (Int) -> Void

    var body: some View {
        List(PocketPresentation.awayChoices, id: \.self) { minutes in
            Button { choose(minutes) } label: {
                HStack {
                    Text(PocketPresentation.awayChoiceLabel(minutes)).font(.system(size: 16, weight: .semibold))
                    Spacer()
                    if minutes == current { Image(systemName: "checkmark").foregroundStyle(K.amber) }
                }
            }
        }
        .navigationTitle("Wait")
    }
}
