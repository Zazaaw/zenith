// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI

/// The Mac at a glance: its battery as a sentence, its screen, the four
/// things most often done from the phone, today (coding, the next prayer,
/// Claude's question), and the sites and the work it watches.
struct HomeView: View {
    @Environment(PocketModel.self) private var model
    let now: Date
    @State private var showingSites = false
    @State private var showingSafety = false
    @State private var showingSend = false

    var body: some View {
        let state = model.state
        let freshness = model.freshness(now: now)
        VStack(alignment: .leading, spacing: 0) {
            Hero(eyebrow: state?.macName ?? model.pairing?.macName ?? "Mac",
                 badge: PocketPresentation.homeBadge(freshness),
                 sentence: sentence(state, freshness),
                 meter: freshness.isReachable ? state?.battery.map { Double($0.percent) / 100 } : nil,
                 meterNote: freshness.isReachable ? state?.battery.map(PocketPresentation.batteryNote) : nil,
                 footnote: footnote(freshness),
                 onSettings: { model.showingSettings = true })
            // The showcase brings its own entrance (it rises and settles).
            MacShowcase(state: state, wallpaper: model.wallpaper, now: now)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
                .opacity(freshness.isReachable ? 1 : 0.6)
                .animation(Motion.reveal, value: freshness.isReachable)
            if let days = model.expiryDaysLeft(now: now) {
                ExpiryCard(days: days)
                    .padding(.horizontal, 20).padding(.top, 14)
                    .blurFade(index: 5)
            }
            if state == nil && model.loading {
                placeholder
            } else {
                actions(state, freshness: freshness)
                    .padding(.horizontal, 20).padding(.top, 14)
                    .blurFade(index: 6)
                if let state { today(state) }
                summaries(state)
            }
        }
        .sheet(isPresented: $showingSites) {
            SitesSheet(sites: model.state?.sites).environment(model)
        }
        .sheet(isPresented: $showingSafety) {
            SafetySheet(safety: model.state?.safety).environment(model)
        }
        .sheet(isPresented: $showingSend) {
            SendToMacSheet().environment(model)
        }
    }

    private func sentence(_ state: PocketMacState?, _ freshness: PocketFreshness) -> PocketSentence {
        if state == nil && model.loading {
            return PocketSentence(lead: "Reaching ", value: "your Mac", after: "…", rest: "", tone: .quiet)
        }
        return PocketPresentation.homeSentence(state, freshness: freshness)
    }

    private func footnote(_ freshness: PocketFreshness) -> String? {
        if model.state == nil, let problem = model.relayProblem { return problem }
        return PocketPresentation.updatedLine(freshness, now: now)
    }

    /// Grey blocks in the shape of what is coming, while the first state is
    /// on its way.
    private var placeholder: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ForEach(0..<4, id: \.self) { _ in Skeleton(height: 74, radius: 18) }
            }
            Skeleton(width: 80, height: 10, radius: 5).padding(.top, 14)
            Skeleton(height: 110, radius: 20)
        }
        .padding(.horizontal, 20).padding(.top, 14)
        .transition(.opacity)
    }

    // MARK: Quick actions

    private func actions(_ state: PocketMacState?, freshness: PocketFreshness) -> some View {
        let awakeLeft = PocketPresentation.awakeMinutesLeft(state?.awakeUntil, now: now)
        let awake = state?.awakeUntil.map { $0 > now } ?? false
        let micMuted = state?.sound?.micMuted ?? false
        let reachable = freshness.isReachable
        return HStack(spacing: 10) {
            QuickAction(symbol: state?.locked == true ? "lock.fill" : "lock", title: state?.locked == true ? "Locked" : "Lock",
                        tint: nil, dimmed: !reachable) {
                model.lock()
            }
            QuickAction(symbol: awake ? "cup.and.saucer.fill" : "cup.and.saucer",
                        title: awake ? (awakeLeft.map { PocketPresentation.duration(minutes: $0) } ?? "Awake") : "Awake 1h",
                        tint: awake ? K.amber : nil, dimmed: !reachable) {
                model.keepAwake(awake ? nil : 60)
            }
            QuickAction(symbol: micMuted ? "mic.slash.fill" : "mic", title: micMuted ? "Mic off" : "Mute mic",
                        tint: micMuted ? K.red : nil, dimmed: !reachable) {
                model.send(.muteMic(!micMuted))
            }
            QuickAction(symbol: "paperplane", title: "Send", tint: nil, dimmed: false, bouncesOnTap: true) {
                showingSend = true
            }
        }
    }

    // MARK: Today

    @ViewBuilder
    private func today(_ state: PocketMacState) -> some View {
        let question = state.questions.first
        let session = Self.activeSession(state)
        let cells = (state.coding != nil ? 1 : 0) + (state.nextPrayer != nil ? 1 : 0)
        if cells > 0 || question != nil || session != nil {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Today", trailing: now.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                VStack(spacing: 0) {
                    if cells > 0 {
                        HStack(spacing: 0) {
                            if let coding = state.coding {
                                cell("Coding", PocketPresentation.duration(seconds: TimeInterval(coding.seconds)),
                                     PocketPresentation.codingNote(coding), bar: PocketPresentation.codingProgress(coding))
                            }
                            if state.coding != nil && state.nextPrayer != nil {
                                Rectangle().fill(K.border).frame(width: 1, height: 96)
                            }
                            if let prayer = state.nextPrayer {
                                cell(prayer.name, prayer.at.formatted(date: .omitted, time: .shortened),
                                     PocketPresentation.countdown(to: prayer.at, now: now), bar: nil)
                            }
                        }
                    }
                    if let question {
                        if cells > 0 { Rectangle().fill(K.border).frame(height: 1) }
                        ClaudeTodayRow(eyebrow: question.project, title: PocketPresentation.questionTitle(question),
                                       meta: PocketPresentation.questionDetail(question)
                                           ?? "asked " + PocketPresentation.ago(question.askedAt, now: now),
                                       badge: PocketBadge("Your turn", .attention), glyph: "hand.raised.fill",
                                       working: false, step: nil) {
                            model.tab = .claude
                        }
                        .transition(.opacity)
                    }
                    if let session {
                        if cells > 0 || question != nil { Rectangle().fill(K.border).frame(height: 1) }
                        let line = Self.activity(session, now: now)
                        ClaudeTodayRow(eyebrow: session.project, title: line.title, meta: line.meta,
                                       badge: PocketPresentation.claudeBadge(session),
                                       glyph: session.state == .working ? "sparkle" : "text.bubble.fill",
                                       working: session.state == .working,
                                       step: session.state == .working ? session.steps.last(where: { $0.phase == .running }) : nil) {
                            model.tab = .claude
                        }
                        .transition(.opacity)
                    }
                }
                .surface()
                .animation(Motion.spring, value: question?.id)
                .animation(Motion.spring, value: session?.id)
                .animation(Motion.spring, value: session?.state)
            }
            .padding(.horizontal, 20).padding(.top, 22)
            .blurFade(index: 7)
        }
    }

    /// The Claude Code session worth a line on Home: working, or done and
    /// waiting for the next prompt (the Mac sends the one that most needs a
    /// look first). A session asking permission already has its question row.
    static func activeSession(_ state: PocketMacState) -> PocketClaude.Session? {
        let asking = state.questions.first.map { $0.id.split(separator: "@").first.map(String.init) ?? $0.id }
        return state.claude?.sessions.first { session in
            (session.state == .working || session.state == .waiting) && session.id != asking
        }
    }

    /// "Running the tests" over "4m into this turn"; "Finished its turn" over
    /// "waiting for you · 3m ago".
    static func activity(_ session: PocketClaude.Session, now: Date) -> (title: String, meta: String) {
        if session.state == .waiting {
            let since = session.waitingSince.map { " · " + PocketPresentation.ago($0, now: now) } ?? ""
            return ("Finished its turn", "waiting for you" + since)
        }
        let sentence = PocketPresentation.claudeSentence(session, now: now)
        let title = sentence.value.prefix(1).uppercased() + sentence.value.dropFirst()
        let meta = sentence.rest.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return (title, meta)
    }

    private func cell(_ label: String, _ value: String, _ note: String, bar: Double?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).font(K.sans(10, bold: true)).tracking(1).foregroundStyle(K.faint)
            Text(value).font(K.mono(24, .semibold))
                .contentTransition(.numericText())
                .animation(Motion.spring, value: value)
            if let bar { Meter(value: bar, tint: K.blue, height: 3) }
            Text(note).font(K.mono(10)).foregroundStyle(K.faint).lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 96, alignment: .top)
        .accessibilityElement(children: .combine)
    }

    // MARK: Sites and safety

    @ViewBuilder
    private func summaries(_ state: PocketMacState?) -> some View {
        let sites = state?.sites.flatMap { $0.sites.isEmpty ? nil : $0 }
        let safety = state?.safety
        if sites != nil || safety != nil {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Watching")
                HStack(alignment: .top, spacing: 10) {
                    if let sites {
                        SummaryCard(title: "Sites", symbol: "globe", summary: Self.sitesSummary(sites, now: now)) {
                            showingSites = true
                        }
                    }
                    if let safety {
                        SummaryCard(title: "Safety", symbol: "checkmark.shield", summary: Self.safetySummary(safety, now: now)) {
                            showingSafety = true
                        }
                    }
                }
            }
            .padding(.horizontal, 20).padding(.top, 22)
            .blurFade(index: 8)
        }
    }

    struct Summary {
        var value: String
        var badge: PocketBadge
        var meta: String
    }

    static func sitesSummary(_ sites: PocketSites, now: Date) -> Summary {
        let down = sites.sites.filter { $0.status == .down }.count
        let slow = sites.sites.filter { $0.status == .slow }.count
        let up = sites.sites.filter { $0.status == .up }.count
        let checked = sites.sites.compactMap(\.checkedAt).max()
        let meta = "\(sites.sites.count) watched" + (checked.map { " · " + PocketPresentation.ago($0, now: now) } ?? "")
        if down > 0 { return Summary(value: "\(down) down", badge: PocketBadge("Down", .alert), meta: meta) }
        if slow > 0 { return Summary(value: "\(slow) slow", badge: PocketBadge("Slow", .attention), meta: meta) }
        if up == sites.sites.count { return Summary(value: "All up", badge: PocketBadge("Up", .good), meta: meta) }
        return Summary(value: "\(up) of \(sites.sites.count) up", badge: PocketBadge("Paused", .quiet), meta: meta)
    }

    static func safetySummary(_ safety: PocketSafety, now: Date) -> Summary {
        let unsafe = safety.repos.filter { $0.unpushed > 0 || $0.uncommitted > 0 || !$0.hasRemote }.count
        let backupMissing = safety.timeMachineConfigured == false
            || (safety.lastBackup.map { now.timeIntervalSince($0) > 7 * 86_400 } ?? false)
        let todo = unsafe + (backupMissing ? 1 : 0)
        var meta = "\(safety.repos.count) repos"
        if let backup = safety.lastBackup { meta += " · backup " + PocketPresentation.ago(backup, now: now) }
        if todo == 0 { return Summary(value: "All safe", badge: PocketBadge("Safe", .good), meta: meta) }
        return Summary(value: "\(todo) to do", badge: PocketBadge("To do", .attention), meta: meta)
    }
}

/// One of Home's four quick actions: a small tile with a symbol and a word,
/// tinted (with its colour named in the word) while its state is on.
/// The symbol bounces when the Mac confirms the change (the word changes
/// with the state it reports), or on the tap itself for one that opens a sheet.
private struct QuickAction: View {
    let symbol: String
    let title: String
    let tint: Color?
    let dimmed: Bool
    var bouncesOnTap = false
    let action: () -> Void
    @State private var taps = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            if bouncesOnTap { taps += 1 }
            action()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(tint ?? K.fg)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, options: .nonRepeating, value: reduceMotion ? "" : "\(title)\(taps)")
                    .frame(height: 22)
                Text(title).font(K.sans(12, bold: true))
                    .foregroundStyle(tint ?? K.muted)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity).frame(height: 74)
            .surface(radius: 18, tint: tint, fill: tint.map { $0.opacity(0.10) } ?? K.card)
            .opacity(dimmed ? 0.5 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .pressable()
        .animation(Motion.spring, value: title)
        .accessibilityLabel(title)
    }
}

/// A half-width card summing up a part of the Mac Pocket watches, opening
/// its sheet: the value in its status colour, a labelled pill, a mono line.
private struct SummaryCard: View {
    let title: String
    let symbol: String
    let summary: HomeView.Summary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: symbol).font(.system(size: 13, weight: .semibold)).foregroundStyle(K.muted)
                    Text(title.uppercased()).font(K.sans(10, bold: true)).tracking(1).foregroundStyle(K.faint)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(K.faint)
                }
                Text(summary.value).font(K.sans(20, bold: true))
                    .foregroundStyle(K.color(summary.badge.tone))
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .contentTransition(.numericText())
                Status(badge: summary.badge)
                Text(summary.meta).font(K.mono(10)).foregroundStyle(K.faint).lineLimit(1)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .surface()
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .pressable()
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens \(title)")
    }
}

/// A free Personal Team signs Pocket for a week; this says when the week is
/// nearly up, and how to sign it again from the Mac.
private struct ExpiryCard: View {
    let days: Int

    var body: some View {
        let value = days == 0 ? "today" : days == 1 ? "in 1 day" : "in \(days) days"
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "clock.badge.exclamationmark").font(.system(size: 13, weight: .semibold)).foregroundStyle(K.amber)
                Text("Pocket expires \(Text(value).foregroundStyle(K.amber)).").font(K.sans(16, bold: true))
                Spacer(minLength: 0)
                Status(badge: PocketBadge("Expires", .attention))
            }
            Text("Reinstall from your Mac: cd Pocket && ./install.sh").font(K.mono(11)).foregroundStyle(K.muted)
                .textSelection(.enabled)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surface(tint: K.amber)
        .accessibilityElement(children: .combine)
    }
}

/// A Claude Code line in Today, opening the Claude tab: a small glyph tile
/// (breathing while Claude works), the project, what it is doing, and its
/// status; a running step's clock ticks beside it.
private struct ClaudeTodayRow: View {
    let eyebrow: String
    let title: String
    let meta: String
    let badge: PocketBadge
    let glyph: String
    let working: Bool
    let step: PocketClaude.Step?
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let tint = K.color(badge.tone)
        Button(action: action) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 9, style: .continuous).fill(tint.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(tint.opacity(0.22), lineWidth: 1))
                    .overlay(
                        Image(systemName: glyph).font(.system(size: 13, weight: .semibold)).foregroundStyle(tint)
                            .symbolEffect(.breathe, options: .repeating, isActive: working && !reduceMotion)
                            .contentTransition(.symbolEffect(.replace))
                    )
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 3) {
                    Text("CLAUDE · \(eyebrow.uppercased())").font(K.sans(10, bold: true)).tracking(1)
                        .foregroundStyle(K.faint).lineLimit(1)
                    Text(title).font(K.sans(15, bold: true)).lineLimit(1)
                        .contentTransition(.opacity)
                    Text(meta).font(K.mono(11)).foregroundStyle(K.faint).lineLimit(1)
                        .contentTransition(.numericText())
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 5) {
                    Status(badge: badge)
                    if let step {
                        // Only this clock ticks every second.
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(PocketPresentation.claudeStepTime(step, now: context.date))
                                .font(K.mono(11, .semibold)).foregroundStyle(tint)
                                .contentTransition(.numericText(countsDown: false))
                                .animation(Motion.spring, value: context.date)
                        }
                    }
                }
            }
            .padding(14)
            .contentShape(Rectangle())
            .animation(Motion.spring, value: title)
            .animation(Motion.spring, value: meta)
        }
        .pressable()
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens Claude")
    }
}
