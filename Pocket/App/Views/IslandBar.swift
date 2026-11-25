// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI

/// The tab bar as Zenith's island, in Liquid Glass: the selected tab is a
/// solid pill with its name (black in light, white in dark) that slides
/// between tabs, with a dot where something needs a look (amber and pulsing
/// on Claude while it waits or asks, red on Devices when a battery is low).
///
/// When Claude asks for permission, or finishes a turn and waits, the same
/// piece of glass morphs into a card that says so; folding it away morphs
/// it back. Both shapes share one `glassEffectID`, so iOS melts one into
/// the other instead of cross-fading two panes.
struct IslandBar: View {
    @Environment(PocketModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var glass
    @Namespace private var pill
    /// Waiting turns folded away here, by session and turn.
    @State private var dismissedWaits: Set<String> = []

    private static let items: [(PocketModel.Tab, String, String)] = [
        (.home, "house.fill", "Home"), (.claude, "sparkles", "Claude"),
        (.mac, "macbook", "Mac"), (.devices, "battery.75percent", "Devices"),
    ]

    /// What the island is open on, if anything. A question outranks a wait.
    private enum Open: Equatable {
        case question(PocketMacState.AgentQuestion)
        case waiting(PocketClaude.Session)

        var id: String {
            switch self {
            case .question(let question): return "q:" + question.id
            case .waiting(let session): return "w:" + IslandBar.waitKey(session)
            }
        }
    }

    private var open: Open? {
        if let question = model.islandQuestion { return .question(question) }
        if model.tab != .claude, let session = model.waitingSession(), !dismissedWaits.contains(Self.waitKey(session)) {
            return .waiting(session)
        }
        return nil
    }

    nonisolated static func waitKey(_ session: PocketClaude.Session) -> String {
        session.id + "@" + String(Int(session.waitingSince?.timeIntervalSince1970 ?? 0))
    }

    var body: some View {
        let open = open
        GlassEffectContainer(spacing: 18) {
            switch open {
            case .question(let question):
                card { questionCard(question) }
            case .waiting(let session):
                card { waitingCard(session) }
            case nil:
                bar
                    .glassEffect(.regular.interactive(), in: Capsule())
                    .glassEffectID("island", in: glass)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)))
            }
        }
        .animation(Motion.respecting(reduceMotion, Motion.island), value: open?.id)
        .onChange(of: open?.id) { old, new in
            if new != nil && old == nil { Haptics.soft() }
        }
    }

    /// The open island: the same glass, grown into a rounded card.
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(18)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
            .glassEffectID("island", in: glass)
            .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .bottom)))
    }

    private var bar: some View {
        let attention = PocketPresentation.attention(model.state, phone: model.phone)
        let asking = model.claude?.sessions.contains { $0.state == .asking } ?? false
        let claudeDot = attention.agents || asking || model.waitingSession() != nil
        return HStack(spacing: 0) {
            ForEach(Self.items, id: \.0) { tab, symbol, title in
                let selected = model.tab == tab
                Button {
                    guard !selected else { return }
                    Haptics.select()
                    model.tab = tab
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: symbol)
                            .font(.system(size: selected ? 16 : 17, weight: selected ? .semibold : .medium))
                        if selected {
                            Text(title).font(K.sans(14, bold: true)).fixedSize()
                                .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .leading)))
                        }
                    }
                    .foregroundStyle(selected ? K.inverse : K.muted)
                    .padding(.horizontal, selected ? 16 : 0)
                    .frame(minWidth: 52, minHeight: 44)
                    .background {
                        if selected {
                            Capsule().fill(K.fg).matchedGeometryEffect(id: "pill", in: pill)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if !selected && tab == .claude && claudeDot { dot(K.amber, pulsing: true) }
                        if !selected && tab == .devices && attention.devices { dot(K.red) }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(PressStyle(haptic: false))
                .accessibilityLabel(title)
                .accessibilityValue(!selected && tab == .claude && claudeDot ? "Claude is waiting for you" : "")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(6)
        .animation(Motion.respecting(reduceMotion, Motion.spring), value: model.tab)
    }

    private func dot(_ color: Color, pulsing: Bool = false) -> some View {
        AttentionDot(color: color, pulsing: pulsing).offset(x: -10, y: 6)
            .transition(.scale.combined(with: .opacity))
    }

    // MARK: Cards

    private func questionCard(_ question: PocketMacState.AgentQuestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                badge
                VStack(alignment: .leading, spacing: 1) {
                    Text("Claude · \(question.project)").font(K.mono(11)).foregroundStyle(K.faint).lineLimit(1)
                    Text(PocketPresentation.questionTitle(question)).font(K.sans(17, bold: true))
                    if let detail = PocketPresentation.questionDetail(question) {
                        Text(detail).font(K.sans(15)).foregroundStyle(K.muted).lineLimit(1)
                    }
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 6) {
                    fold { model.collapseIsland() }
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
    }

    private func waitingCard(_ session: PocketClaude.Session) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                badge
                VStack(alignment: .leading, spacing: 2) {
                    Text("Claude · \(session.project)").font(K.mono(11)).foregroundStyle(K.faint).lineLimit(1)
                    Text("Claude is waiting for you").font(K.sans(17, bold: true))
                    if let message = session.lastMessage?.trimmingCharacters(in: .whitespacesAndNewlines), !message.isEmpty {
                        Text(message).font(K.sans(14)).foregroundStyle(K.muted).lineLimit(2)
                    }
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 6) {
                    fold { dismissedWaits.insert(Self.waitKey(session)) }
                    if let since = session.waitingSince {
                        Text(PocketPresentation.ago(since, now: Date()).replacingOccurrences(of: " ago", with: ""))
                            .font(K.mono(11)).foregroundStyle(K.faint)
                    }
                }
            }
            HStack(spacing: 8) {
                PillButton(title: "Later", compact: true) { dismissedWaits.insert(Self.waitKey(session)) }
                PillButton(title: "Open Claude", primary: true, compact: true) {
                    dismissedWaits.insert(Self.waitKey(session))
                    model.tab = .claude
                }
            }
        }
    }

    private var badge: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous).fill(K.amber.opacity(0.16))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(K.amber.opacity(0.25), lineWidth: 1))
            .overlay(Image(systemName: "sparkle").font(.system(size: 15, weight: .bold)).foregroundStyle(K.amber)
                .symbolEffect(.breathe, options: .repeating))
            .frame(width: 36, height: 36)
    }

    private func fold(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "chevron.down").font(.system(size: 13, weight: .semibold)).foregroundStyle(K.muted)
                .frame(width: 28, height: 28).background(K.track, in: Circle())
        }
        .pressable()
        .accessibilityLabel("Close")
    }
}

/// A tab's "needs a look" dot. Pulsing, a ring swells out of it and fades
/// every couple of seconds, like a heartbeat; still under Reduce Motion.
/// The ring runs in its own keyframe timeline, so the bar's springs and the
/// dot's own entrance don't bend it.
private struct AttentionDot: View {
    let color: Color
    var pulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle().fill(color).frame(width: 7, height: 7)
            .shadow(color: color.opacity(0.8), radius: 4)
            .background {
                if pulsing && !reduceMotion {
                    Circle().strokeBorder(color, lineWidth: 1.5)
                        .frame(width: 7, height: 7)
                        .keyframeAnimator(initialValue: 0.0, repeating: true) { ring, t in
                            ring.scaleEffect(1 + 1.6 * t).opacity(0.9 * (1 - t))
                        } keyframes: { _ in
                            LinearKeyframe(1.0, duration: 1.3, timingCurve: .easeOut)
                            LinearKeyframe(1.0, duration: 0.8)
                        }
                }
            }
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
                .contentTransition(.opacity)
                .animation(Motion.quick, value: model.answers[question.id])
        }
    }
}
