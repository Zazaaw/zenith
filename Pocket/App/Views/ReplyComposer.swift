// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI

/// Replying to a session that waits in Away mode: quick replies, a field
/// that grows, dictation, and Face ID (or the passcode) before it goes. Off,
/// it says why in plain words. The draft stays until the Mac confirms.
struct ReplyComposer: View {
    @Environment(PocketModel.self) private var model
    let session: PocketClaude.Session
    let away: Bool
    let now: Date

    @State private var draft = ""
    @State private var sending: Date?
    @State private var dictation = Dictation()
    /// The draft as it was when dictation began; what is heard goes after it.
    @State private var spokenAfter = ""
    @FocusState private var focused: Bool

    var body: some View {
        let reachable = model.canControl(now: now)
        let blocker = PocketPresentation.claudeReplyBlocker(session, away: away, reachable: reachable)
        let open = blocker == nil && sending == nil
        let fits = PocketPresentation.claudeReplyFits(draft)
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(PocketPresentation.claudeTemplates, id: \.title) { template in
                        let picked = draft == template.text
                        Button {
                            Haptics.select()
                            withAnimation(Motion.quick) { draft = template.text }
                        } label: {
                            Text(template.title).font(K.sans(13, bold: true)).foregroundStyle(picked ? K.inverse : K.fg)
                                .padding(.horizontal, 14).padding(.vertical, 9)
                                .background(picked ? K.fg : K.card, in: Capsule())
                                .overlay(Capsule().strokeBorder(picked ? .clear : K.border, lineWidth: 1))
                                .animation(Motion.quick, value: picked)
                        }
                        .pressable()
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -20)
            .disabled(!open)
            .opacity(open ? 1 : 0.45)

            HStack(alignment: .bottom, spacing: 8) {
                TextField("Reply to Claude", text: $draft, axis: .vertical)
                    .font(K.sans(15))
                    .lineLimit(1...6)
                    .focused($focused)
                    .submitLabel(.return)
                    .padding(.vertical, 9)
                    .disabled(!open)
                Button {
                    Haptics.tap()
                    if !dictation.listening { spokenAfter = draft }
                    Task { await dictation.toggle() }
                } label: {
                    Circle().fill(dictation.listening ? K.red.opacity(0.16) : K.fg.opacity(0.08))
                        .frame(width: 36, height: 36)
                        .overlay(Image(systemName: dictation.listening ? "stop.fill" : "mic.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(dictation.listening ? K.red : K.muted))
                        .overlay { if dictation.listening { ClaudePulse(tint: K.red).frame(width: 36, height: 36).scaleEffect(36 / 26) } }
                }
                .buttonStyle(.plain)
                .disabled(!open)
                .accessibilityLabel(dictation.listening ? "Stop dictation" : "Dictate")
                Button(action: send) {
                    Circle().fill(K.fg).frame(width: 36, height: 36)
                        .overlay {
                            if sending != nil {
                                ProgressView().tint(K.bg).transition(.scale.combined(with: .opacity))
                            } else {
                                Image(systemName: "arrow.up").font(.system(size: 15, weight: .bold)).foregroundStyle(K.bg)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .opacity(open && fits ? 1 : 0.35)
                        // Ready to go: the button springs up to full size.
                        .scaleEffect(open && fits ? 1 : 0.86)
                        .animation(Motion.spring, value: open && fits)
                        .animation(Motion.spring, value: sending == nil)
                }
                .buttonStyle(PressStyle(haptic: false))
                .disabled(!open || !fits)
                .accessibilityLabel("Send to Claude")
            }
            .padding(.leading, 16).padding(.trailing, 6).padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous).fill(K.card)
                    // Focused, the field lifts a little off the page.
                    .shadow(color: .black.opacity(focused ? 0.10 : 0), radius: 18, y: 8)
            }
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(focused ? K.fg.opacity(0.35) : K.border, lineWidth: focused ? 1.5 : 1))
            .animation(Motion.spring, value: focused)
            .animation(Motion.quick, value: draft.filter { $0 == "\n" }.count)
            .contentShape(Rectangle())
            .onTapGesture { if open { focused = true } }

            HStack(spacing: 6) {
                Image(systemName: blocker == nil ? "faceid" : "info.circle").font(.system(size: 11)).foregroundStyle(K.faint)
                Text(footnote(blocker)).font(K.mono(11)).foregroundStyle(K.faint)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if draft.count > PocketPresentation.claudeReplyLimit - 200 {
                    Text("\(draft.count)/\(PocketPresentation.claudeReplyLimit)").font(K.mono(11))
                        .foregroundStyle(draft.count > PocketPresentation.claudeReplyLimit ? K.red : K.faint)
                }
            }
            .padding(.horizontal, 6)
            if let problem = dictation.problem {
                Text(problem).font(K.mono(11)).foregroundStyle(K.amber).padding(.horizontal, 6)
            }
        }
        .onChange(of: dictation.transcript) { _, heard in
            guard dictation.listening || !heard.isEmpty else { return }
            draft = spokenAfter.isEmpty ? heard : spokenAfter + " " + heard
        }
        .onChange(of: model.toast) { _, toast in
            // The Mac's answer to the reply arrives as the toast.
            guard sending != nil, let toast else { return }
            sending = nil
            if toast.ok {
                draft = ""
                Haptics.success()
            } else {
                Haptics.failure()
            }
        }
        .onChange(of: blocker) { _, next in
            if next != nil { dictation.stop() }
        }
        .onDisappear { dictation.stop() }
    }

    private func footnote(_ blocker: String?) -> String {
        if let blocker { return blocker }
        if sending != nil { return "Sending to your Mac…" }
        let wait = PocketPresentation.claudeWaitLeft(session, now: now)
        return ["Sends with Face ID", wait].compactMap { $0 }.joined(separator: " · ")
    }

    private func send() {
        guard sending == nil, PocketPresentation.claudeReplyFits(draft) else { return }
        dictation.stop()
        focused = false
        Haptics.press()
        let text = draft
        let session = session
        Task {
            switch await OwnerCheck.confirm(reason: "Send your reply to Claude Code on your Mac.") {
            case .passed:
                guard model.replyToClaude(session, text: text) else { return Haptics.failure() }
                let started = Date()
                sending = started
                // No answer in time: the model says so; the draft stays.
                try? await Task.sleep(for: .seconds(PocketModel.resultTimeout + 2))
                if sending == started { sending = nil }
            case .cancelled:
                break
            case .unavailable(let reason):
                model.show(reason, ok: false)
            }
        }
    }
}
