// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI

/// The tab bar as Zenith's island: a black pill whose selected tab is a
/// white pill with its name, with a dot where something needs a look (amber
/// on Agents when Claude asks, red on Devices when a battery is low). When
/// Claude asks, it opens into a card with the question.
struct IslandBar: View {
    @Environment(PocketModel.self) private var model

    private static let items: [(PocketModel.Tab, String, String)] = [
        (.home, "house.fill", "Home"), (.claude, "sparkles", "Claude"),
        (.mac, "macbook", "Mac"), (.devices, "battery.75percent", "Devices"),
    ]

    var body: some View {
        Group {
            if let question = model.islandQuestion {
                card(question)
                    .transition(.scale(scale: 0.6, anchor: .bottom).combined(with: .opacity))
            } else {
                bar.transition(.scale(scale: 0.9, anchor: .bottom).combined(with: .opacity))
            }
        }
        .shadow(color: .black.opacity(0.7), radius: 24, y: 10)
        .animation(.spring(duration: 0.45, bounce: 0.25), value: model.islandQuestion?.id)
        .animation(.spring(duration: 0.35), value: model.tab)
    }

    private var bar: some View {
        let attention = PocketPresentation.attention(model.state, phone: model.phone)
        return HStack(spacing: 0) {
            ForEach(Self.items, id: \.0) { tab, symbol, title in
                let selected = model.tab == tab
                Button {
                    model.tab = tab
                } label: {
                    if selected {
                        HStack(spacing: 7) {
                            Image(systemName: symbol).font(.system(size: 16, weight: .semibold))
                            Text(title).font(K.sans(14, bold: true))
                        }
                        .foregroundStyle(.black).padding(.horizontal, 16).frame(height: 44)
                        .background(Color.white, in: Capsule())
                    } else {
                        Image(systemName: symbol).font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.55))
                            .frame(width: 52, height: 44)
                            .overlay(alignment: .topTrailing) {
                                if tab == .claude && attention.agents { dot(K.amber) }
                                if tab == .devices && attention.devices { dot(K.red) }
                            }
                            .contentShape(Rectangle())
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(title)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(6)
        .background(Color.black, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
    }

    private func dot(_ color: Color) -> some View {
        Circle().fill(color).frame(width: 7, height: 7).shadow(color: color, radius: 4).offset(x: -10, y: 6)
    }

    private func card(_ question: PocketMacState.AgentQuestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(K.amber.opacity(0.18))
                    .overlay(Image(systemName: "sparkle").font(.system(size: 15, weight: .bold)).foregroundStyle(K.amber))
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Claude · \(question.project)").font(K.mono(11)).foregroundStyle(K.faint).lineLimit(1)
                    Text(PocketPresentation.questionTitle(question)).font(K.sans(17, bold: true))
                    if let detail = PocketPresentation.questionDetail(question) {
                        Text(detail).font(K.sans(15)).foregroundStyle(K.muted).lineLimit(1)
                    }
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 6) {
                    Button {
                        model.collapseIsland()
                    } label: {
                        Image(systemName: "chevron.down").font(.system(size: 13, weight: .semibold)).foregroundStyle(K.muted)
                            .frame(width: 28, height: 28).background(Color.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                    Text(PocketPresentation.ago(question.askedAt, now: Date()).replacingOccurrences(of: " ago", with: ""))
                        .font(K.mono(11)).foregroundStyle(K.faint)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                model.tab = .claude
                model.collapseIsland()
            }
            AnswerButtons(question: question, compact: true)
        }
        .padding(18)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
    }
}

/// Deny and Allow, and what the Mac said back. Zenith can't answer Claude
/// Code from the phone yet; the buttons ask anyway, so the reply (and a
/// future Zenith that can) is the one to say so.
struct AnswerButtons: View {
    @Environment(PocketModel.self) private var model
    let question: PocketMacState.AgentQuestion
    var compact = false

    var body: some View {
        let busy = model.answering.contains(question.id)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                PillButton(title: "Deny", compact: compact) { model.answer(question, allow: false) }
                PillButton(title: "Allow", primary: true, compact: compact) { model.answer(question, allow: true) }
            }
            .disabled(busy || !model.canControl())
            Text(model.answers[question.id] ?? (busy ? "Asking your Mac…" : "Answering from Pocket isn't ready in Zenith yet."))
                .font(K.mono(11)).foregroundStyle(K.faint).fixedSize(horizontal: false, vertical: true)
        }
    }
}
