// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: the reply row under a Messages or WhatsApp notification, on
// the held preview and on the island's notifications page. A rounded field
// with the service's placeholder, a send button in its colour and an emoji
// button. Return sends, Esc closes. After a reply, the message line turns
// into "You: …" in the service's colour with a blur crossfade.

extension ZenithReplyApp {
    var color: Color { Color(.sRGB, red: tint.red, green: tint.green, blue: tint.blue, opacity: 1) }
}

/// The motion the row shares: the island's reveal spring, and fades only
/// with Reduce Motion.
enum ZenithReplyMotion {
    static func reveal(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.36, dampingFraction: 0.86)
    }

    static func crossfade(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.2) : .smooth(duration: 0.35)
    }

    /// Each control of the row blurs in 40 ms after the one before it.
    static let stagger: Double = 0.04
}

/// The header's reply glyph, only for a notification that can be answered.
struct ZenithReplyButton: View {
    let item: NotchSystemNotification
    let surface: ZenithReplyComposer.Surface
    @ObservedObject private var composer = ZenithReplyComposer.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if composer.target(for: item) != nil {
            let open = composer.isOpen(item.id, on: surface)
            let text = ZenithStrings.reply(l10n.language)
            NotchIconButton(symbol: open ? "xmark.circle" : "arrowshape.turn.up.left",
                            title: open ? text.closeReply : text.reply, selected: open) {
                withAnimation(ZenithReplyMotion.reveal(reduceMotion)) { composer.toggle(item, on: surface) }
            }
        }
    }
}

/// Where the row goes: shown while it is open for this notification.
struct ZenithReplyRowSlot: View {
    let item: NotchSystemNotification
    let surface: ZenithReplyComposer.Surface
    @ObservedObject private var composer = ZenithReplyComposer.shared

    var body: some View {
        if composer.isOpen(item.id, on: surface), let target = composer.target(for: item) {
            ZenithReplyRow(item: item, target: target, surface: surface)
                .transition(.opacity)
        }
    }
}

/// The message, or what became of the reply: "You: …" in the service's
/// colour once sent, or a note in amber when it went another way.
struct ZenithReplyMessageSlot<Original: View>: View {
    let item: NotchSystemNotification?
    var surface: ZenithReplyComposer.Surface = .page
    var font: Font = .system(size: 12)
    var lineLimit: Int? = nil
    @ViewBuilder let original: () -> Original
    @ObservedObject private var composer = ZenithReplyComposer.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The preview shows a status only while its row is open, since the
    /// island only grows for it then.
    private var status: ZenithReplyComposer.Status? {
        guard let item, surface == .page || composer.isOpen(item.id, on: .preview) else { return nil }
        return composer.statuses[item.id]
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let status, let item, let target = composer.target(for: item) {
                Text(ZenithReplyComposer.message(for: status, language: l10n.language))
                    .font(font)
                    .foregroundStyle(tint(status, target))
                    .lineLimit(lineLimit)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .id(statusKey(status))
                    .transition(reduceMotion ? AnyTransition.opacity : AnyTransition(.blurReplace))
            } else {
                original()
                    .transition(reduceMotion ? AnyTransition.opacity : AnyTransition(.blurReplace))
            }
        }
        .animation(ZenithReplyMotion.crossfade(reduceMotion), value: status.map(statusKey))
    }

    private func tint(_ status: ZenithReplyComposer.Status, _ target: ZenithReplyTarget) -> Color {
        if case .sent = status { return target.app.color }
        return ZenithStatus.warning
    }

    private func statusKey(_ status: ZenithReplyComposer.Status) -> String {
        switch status {
        case .sent(_, let date): return "sent-\(date.timeIntervalSinceReferenceDate)"
        case .opened(_, let prefilled, let copied, _): return "opened-\(prefilled)-\(copied)"
        case .needsPermission(let permission): return "permission-\(permission)"
        case .failed: return "failed"
        }
    }
}

/// The notification's time, or how long ago the reply went: "now", "6s ago".
struct ZenithReplyTime<Original: View>: View {
    let item: NotchSystemNotification
    @ViewBuilder let original: () -> Original
    @ObservedObject private var composer = ZenithReplyComposer.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        if case .sent(_, let date)? = composer.statuses[item.id] {
            TimelineView(.periodic(from: date, by: 1)) { context in
                Text(Self.relative(date, now: context.date, locale: l10n.language.formattingLocale()))
                    .monospacedDigit()
            }
        } else {
            original()
        }
    }

    static func relative(_ date: Date, now: Date, locale: Locale) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.unitsStyle = .abbreviated
        formatter.dateTimeStyle = now.timeIntervalSince(date) < 1 ? .named : .numeric
        return formatter.localizedString(for: min(date, now), relativeTo: now)
    }
}

struct ZenithReplyRow: View {
    let item: NotchSystemNotification
    let target: ZenithReplyTarget
    let surface: ZenithReplyComposer.Surface
    @ObservedObject private var composer = ZenithReplyComposer.shared
    @ObservedObject private var l10n = L10n.shared
    @FocusState private var focused: Bool
    @State private var revealed = false
    /// The reply just sent, drawn over the emptied field as it blurs away.
    @State private var ghost: String?
    @State private var ghostShown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var text: ZenithReplyStrings { ZenithStrings.reply(l10n.language) }
    private var sending: Bool { composer.sendingID == item.id }
    private var canSend: Bool { !sending && ZenithReplyDraft.sendable(composer.draft(for: item.id)) != nil }
    private var permission: ZenithReplyPermission? {
        if case .needsPermission(let permission)? = composer.statuses[item.id] { return permission }
        return nil
    }

    var body: some View {
        HStack(spacing: 8) {
            field.modifier(ZenithReplyReveal(index: 0, revealed: revealed, reduceMotion: reduceMotion))
            if let permission {
                grant(permission).modifier(ZenithReplyReveal(index: 1, revealed: revealed, reduceMotion: reduceMotion))
            } else {
                sendButton.modifier(ZenithReplyReveal(index: 1, revealed: revealed, reduceMotion: reduceMotion))
            }
            emojiButton.modifier(ZenithReplyReveal(index: 2, revealed: revealed, reduceMotion: reduceMotion))
        }
        .frame(height: ZenithReplyHold.rowHeight)
        .onAppear {
            revealed = true
            focusSoon()
        }
        .onDisappear { composer.surfaceDisappeared(item.id, surface) }
        .onChange(of: composer.focusRequest) { _, _ in focusSoon() }
        .onChange(of: composer.statuses[item.id]) { old, new in
            guard case .sent(let reply, _)? = new, new != old else { return }
            fadeOut(reply)
        }
    }

    private var field: some View {
        ZStack(alignment: .leading) {
            TextField("", text: Binding(get: { composer.draft(for: item.id) },
                                        set: { composer.setDraft($0, for: item.id) }),
                      prompt: Text(target.app.placeholder).foregroundStyle(.white.opacity(0.4)))
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(ZenithIsland.primary)
                .focused($focused)
                .onSubmit { composer.send(item) }
                // The open island's own Esc closes the row as a page layer;
                // on the held preview the field's cancel does.
                .onExitCommand { closeRow() }
                .onKeyPress(.escape) {
                    closeRow()
                    return .handled
                }
                .accessibilityLabel(target.app.placeholder)
            if let ghost {
                Text(ghost)
                    .font(.system(size: 13))
                    .foregroundStyle(ZenithIsland.primary)
                    .lineLimit(1)
                    .blur(radius: ghostShown || reduceMotion ? 0 : 8)
                    .opacity(ghostShown ? 1 : 0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Capsule().fill(Color.white.opacity(0.08)))
        .overlay {
            Capsule().strokeBorder(focused ? ZenithIsland.strongHairline : ZenithIsland.hairline, lineWidth: 0.75)
                .allowsHitTesting(false)
        }
        .contentShape(Capsule())
        .onTapGesture { focused = true }
    }

    private var sendButton: some View {
        Button { composer.send(item) } label: {
            ZStack {
                Circle().fill(target.app.color.opacity(canSend || sending ? 1 : 0.35))
                if sending {
                    ProgressView().controlSize(.mini).tint(.white)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(canSend ? 1 : 0.6))
                }
            }
            .frame(width: ZenithReplyHold.rowHeight, height: ZenithReplyHold.rowHeight)
            .contentShape(Circle())
            .animation(.easeOut(duration: 0.15), value: canSend)
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
        .help(text.send)
        .accessibilityLabel(sending ? text.sending : text.send)
    }

    private var emojiButton: some View {
        Button {
            focused = true
            // The palette types into the active app, so Zenith becomes it;
            // the island keeps the keyboard.
            NSApp.activate()
            DispatchQueue.main.async { NSApp.orderFrontCharacterPalette(nil) }
        } label: {
            Image(systemName: "face.smiling")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: ZenithReplyHold.rowHeight, height: ZenithReplyHold.rowHeight)
                .background(Circle().fill(Color.white.opacity(0.1)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(text.emoji)
        .accessibilityLabel(text.emoji)
    }

    private func grant(_ permission: ZenithReplyPermission) -> some View {
        Button(text.grantAccess) { composer.grantAccess(permission, for: item.id) }
            .buttonStyle(ZenithIslandPrimaryButtonStyle())
            .fixedSize()
    }

    private func closeRow() {
        withAnimation(ZenithReplyMotion.reveal(reduceMotion)) { composer.close() }
    }

    private func focusSoon() {
        // The panel takes the keyboard first; the caret follows on the next pass.
        DispatchQueue.main.async { focused = true }
    }

    /// The field is already empty; the reply it held blurs and fades out
    /// over it.
    private func fadeOut(_ reply: String) {
        ghost = reply
        ghostShown = true
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .easeOut(duration: 0.32)) { ghostShown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if !ghostShown { ghost = nil }
        }
    }
}

/// A control of the row coming in: blurred 10 pt to sharp with its opacity,
/// on the reveal spring, each one 40 ms after the last.
private struct ZenithReplyReveal: ViewModifier {
    let index: Int
    let revealed: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .blur(radius: revealed || reduceMotion ? 0 : 10)
            .opacity(revealed ? 1 : 0)
            .scaleEffect(revealed || reduceMotion ? 1 : 0.96)
            .animation(ZenithReplyMotion.reveal(reduceMotion).delay(Double(index) * ZenithReplyMotion.stagger),
                       value: revealed)
    }
}
