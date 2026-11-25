// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI

/// The Mac at a glance: its battery as a sentence, its screen, and today
/// (coding, the next prayer, Claude's question).
struct HomeView: View {
    @Environment(PocketModel.self) private var model
    let now: Date

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
            MacShowcase(state: state, wallpaper: model.wallpaper, now: now)
                .scaleEffect(0.9)
                .frame(height: 214)
                .frame(maxWidth: .infinity)
                .padding(.top, 18)
                .opacity(freshness.isReachable ? 1 : 0.6)
            if let state { today(state) }
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

    @ViewBuilder
    private func today(_ state: PocketMacState) -> some View {
        let question = state.questions.first
        let cells = (state.coding != nil ? 1 : 0) + (state.nextPrayer != nil ? 1 : 0)
        if cells > 0 || question != nil {
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
                        Button {
                            model.tab = .claude
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("CLAUDE · \(question.project.uppercased())").font(K.sans(10, bold: true)).tracking(1)
                                        .foregroundStyle(K.faint).lineLimit(1)
                                    Text(PocketPresentation.questionTitle(question)).font(K.sans(15, bold: true))
                                }
                                Spacer()
                                Status(badge: PocketBadge("Pending", .attention))
                            }
                            .padding(14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(K.card.opacity(0.75), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(K.border, lineWidth: 1))
            }
            .padding(.horizontal, 20).padding(.top, 14)
        }
    }

    private func cell(_ label: String, _ value: String, _ note: String, bar: Double?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).font(K.sans(10, bold: true)).tracking(1).foregroundStyle(K.faint)
            Text(value).font(K.mono(24, .semibold))
            if let bar { Meter(value: bar, tint: K.blue, height: 3) }
            Text(note).font(K.mono(10)).foregroundStyle(K.faint).lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 96, alignment: .top)
        .accessibilityElement(children: .combine)
    }
}
