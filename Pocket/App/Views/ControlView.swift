// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI

/// What the phone may do to the Mac: lock it, keep it awake, and play,
/// pause or skip what it plays. Nothing else exists.
struct ControlView: View {
    @Environment(PocketModel.self) private var model
    let now: Date

    var body: some View {
        let state = model.state
        let freshness = model.freshness(now: now)
        let enabled = model.canControl(now: now)
        VStack(alignment: .leading, spacing: 0) {
            Hero(eyebrow: "Control", badge: PocketPresentation.controlBadge(state, freshness: freshness),
                 sentence: PocketPresentation.controlSentence(state, freshness: freshness, now: now),
                 meter: awakeMeter(state), meterNote: awakeNote(state),
                 footnote: PocketPresentation.updatedLine(freshness, now: now),
                 onSettings: { model.showingSettings = true })
            if let problem = model.controlProblem(now: now) {
                Text(problem).font(K.sans(13)).foregroundStyle(K.muted)
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(K.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(K.border, lineWidth: 1))
                    .padding(.horizontal, 20).padding(.top, 20)
            }
            lockButton.disabled(!enabled)
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Keep awake")
                awakePicker(state).disabled(!enabled)
                if let song = state?.nowPlaying {
                    SectionLabel(text: "Playing on Mac").padding(.top, 10)
                    nowPlaying(song).disabled(!enabled)
                }
            }
            .padding(.horizontal, 20).padding(.top, 24)
        }
    }

    // MARK: Lock

    private var lockButton: some View {
        Button {
            model.lock()
        } label: {
            HStack(spacing: 18) {
                ZStack {
                    Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1).frame(width: 116, height: 116)
                    Circle().fill(Color.white).frame(width: 86, height: 86)
                    Image(systemName: "lock.fill").font(.system(size: 30, weight: .semibold)).foregroundStyle(.black)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Lock Mac").font(K.sans(20, bold: true))
                    Text("Locks at once. Unlocking stays on the Mac.").font(K.sans(13)).foregroundStyle(K.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(DimWhenDisabled())
        .padding(.horizontal, 24).padding(.top, 26)
        .accessibilityLabel("Lock Mac")
    }

    // MARK: Keep awake

    /// What the segments mean: nil off, 0 until turned off.
    private static let segments: [(String, Int?)] = [("Off", nil), ("15m", 15), ("1h", 60), ("4h", 240), ("∞", 0)]

    private func selected(_ state: PocketMacState?) -> Int?? {
        guard let state else { return .none }
        guard let until = state.awakeUntil, until > now else { return .some(nil) }
        if PocketPresentation.isIndefinite(until, now: now) { return .some(0) }
        // The length asked for here, unless the Mac was since set for longer.
        if let choice = model.awakeChoice, PocketModel.awakeChoices.contains(choice),
           let left = PocketPresentation.awakeMinutesLeft(until, now: now), left <= choice { return .some(choice) }
        return .none
    }

    private func awakePicker(_ state: PocketMacState?) -> some View {
        let current = selected(state)
        return HStack(spacing: 4) {
            ForEach(Self.segments, id: \.0) { title, minutes in
                let isOn = current == .some(minutes)
                Button {
                    model.keepAwake(minutes)
                } label: {
                    Text(title).font(K.sans(14, bold: true)).frame(maxWidth: .infinity).padding(.vertical, 10)
                        .foregroundStyle(isOn ? Color.black : K.muted)
                        .background(isOn ? Color.white : .clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(DimWhenDisabled())
                .accessibilityLabel(minutes == nil ? "Keep awake off" : minutes == 0 ? "Keep awake until turned off" : "Keep awake \(title)")
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(4)
        .background(K.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(K.border, lineWidth: 1))
    }

    private func awakeMeter(_ state: PocketMacState?) -> Double? {
        guard let left = PocketPresentation.awakeMinutesLeft(state?.awakeUntil, now: now),
              let total = model.awakeChoice, total > 0 else { return nil }
        return Double(left) / Double(max(total, left))
    }

    private func awakeNote(_ state: PocketMacState?) -> String? {
        guard awakeMeter(state) != nil, let total = model.awakeChoice else { return nil }
        return "keep awake · " + PocketPresentation.duration(minutes: total)
    }

    // MARK: Now playing

    private func nowPlaying(_ song: PocketMacState.NowPlaying) -> some View {
        Rows {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let elapsed = PocketPresentation.elapsed(song, sentAt: model.stateSentAt ?? context.date, now: context.date)
                Row(symbol: "music.note", title: song.title.isEmpty ? "Unknown" : song.title,
                    meta: PocketPresentation.nowPlayingLine(song, elapsed: elapsed), divider: false) {
                    HStack(spacing: 4) {
                        mediaButton("backward.fill", "Previous", size: 13, tint: K.muted) { model.media(.previous) }
                        mediaButton(song.playing ? "pause.fill" : "play.fill", song.playing ? "Pause" : "Play", size: 16, tint: K.fg) {
                            model.media(.playPause)
                        }
                        mediaButton("forward.fill", "Next", size: 13, tint: K.muted) { model.media(.next) }
                    }
                }
            }
        }
    }

    private func mediaButton(_ symbol: String, _ label: String, size: CGFloat, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: size)).foregroundStyle(tint)
                .frame(width: 34, height: 34).contentShape(Rectangle())
        }
        .buttonStyle(DimWhenDisabled())
        .accessibilityLabel(label)
    }
}

/// Plain, half-strength while disabled.
struct DimWhenDisabled: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
