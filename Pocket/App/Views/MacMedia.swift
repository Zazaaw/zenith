// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI

// MARK: - Now playing

/// The song on the Mac: its cover (crossfading when it changes), the
/// position you can drag to seek, and play, pause and skip.
struct MacNowPlaying: View {
    @Environment(PocketModel.self) private var model
    let song: PocketMacState.NowPlaying

    /// Where the thumb is while dragging, and a seek just sent (until the
    /// Mac's next state shows it).
    @State private var scrub: Double?
    @State private var sought: (seconds: Double, at: Date)?

    var body: some View {
        let store = model.mac
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = position(at: context.date)
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    cover(store)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(song.title.isEmpty ? "Unknown" : song.title).font(K.sans(16, bold: true)).lineLimit(1)
                        Text(subtitle).font(K.mono(11)).foregroundStyle(K.faint).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                if let duration = song.duration, duration > 0 {
                    seekBar(elapsed: elapsed ?? 0, duration: duration)
                }
                HStack(spacing: 28) {
                    Spacer()
                    mediaButton("backward.fill", "Previous", size: 17) { model.media(.previous) }
                    mediaButton(song.playing ? "pause.fill" : "play.fill", song.playing ? "Pause" : "Play", size: 24) {
                        model.media(.playPause)
                    }
                    .contentTransition(.symbolEffect(.replace))
                    mediaButton("forward.fill", "Next", size: 17) { model.media(.next) }
                    Spacer()
                }
            }
            .macCard()
        }
        .onAppear { store.showArtwork(song.artworkHash, model: model) }
        .onChange(of: song.artworkHash) { _, hash in store.showArtwork(hash, model: model) }
        .onChange(of: song.elapsed) { _, _ in sought = nil }
    }

    private var subtitle: String {
        [song.artist, song.album ?? "", song.app.map { "on " + $0 } ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func position(at date: Date) -> Double? {
        if let scrub { return scrub }
        if let sought, date.timeIntervalSince(sought.at) < 4 {
            return sought.seconds + (song.playing ? date.timeIntervalSince(sought.at) : 0)
        }
        return PocketPresentation.elapsed(song, sentAt: model.stateSentAt ?? date, now: date)
    }

    private func cover(_ store: MacStore) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(K.fg.opacity(0.06))
            Image(systemName: "music.note").font(.system(size: 20, weight: .semibold)).foregroundStyle(K.faint)
            if let image = store.artwork, song.artworkHash != nil {
                Image(uiImage: image).resizable().scaledToFill()
                    .id(store.artworkHash)
                    .transition(.opacity.combined(with: .scale(scale: 1.04)))
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(K.border, lineWidth: 1))
        .animation(.easeInOut(duration: 0.5), value: store.artworkHash)
        .accessibilityHidden(true)
    }

    private func seekBar(elapsed: Double, duration: Double) -> some View {
        let fraction = min(1, max(0, elapsed / duration))
        return VStack(spacing: 6) {
            GeometryReader { geometry in
                Capsule().fill(K.fg.opacity(0.1))
                    .overlay(alignment: .leading) {
                        Capsule().fill(K.fg).frame(width: geometry.size.width * fraction)
                    }
                    .frame(height: scrub == nil ? 4 : 8)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if scrub == nil { Haptics.tap() }
                            scrub = min(1, max(0, value.location.x / max(1, geometry.size.width))) * duration
                        }
                        .onEnded { _ in
                            if let scrub {
                                model.seek(to: scrub)
                                sought = (scrub, Date())
                                Haptics.select()
                            }
                            scrub = nil
                        })
                    .animation(Motion.spring, value: scrub == nil)
            }
            .frame(height: 18)
            HStack {
                Text(PocketPresentation.clock(elapsed)).monospacedDigit()
                Spacer()
                Text("-" + PocketPresentation.clock(max(0, duration - elapsed))).monospacedDigit()
            }
            .font(K.mono(10)).foregroundStyle(K.faint)
        }
        .accessibilityElement()
        .accessibilityLabel("Position")
        .accessibilityValue(PocketPresentation.clock(elapsed) + " of " + PocketPresentation.clock(duration))
        .accessibilityAdjustableAction { direction in
            let step: Double = direction == .increment ? 15 : -15
            model.seek(to: min(duration, max(0, elapsed + step)))
        }
    }

    private func mediaButton(_ symbol: String, _ label: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: symbol).font(.system(size: size, weight: .semibold)).foregroundStyle(K.fg)
                .frame(width: 44, height: 44).contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(label)
    }
}

// MARK: - Sound

/// The Mac's volume (a slider that sends as you drag, at most four times a
/// second), its microphone and the outputs it can switch to.
struct MacSound: View {
    @Environment(PocketModel.self) private var model
    let sound: PocketSound

    @State private var draft: Double?
    @State private var dragging = false
    @State private var lastSent = Date.distantPast
    @State private var trailing: Task<Void, Never>?
    @State private var settle: Task<Void, Never>?

    private static let sendEvery: TimeInterval = 0.25

    var body: some View {
        let shown = draft ?? Double(sound.muted ? 0 : sound.volume)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: PocketMacPresentation.volumeSymbol(Int(shown.rounded()), muted: draft == nil && sound.muted))
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(K.muted)
                    .frame(width: 22)
                    .contentTransition(.symbolEffect(.replace))
                slider(shown)
                Text("\(Int(shown.rounded()))").font(K.mono(13, .semibold)).monospacedDigit()
                    .frame(width: 30, alignment: .trailing)
                    .countingNumber(shown.rounded())
            }
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    if let micMuted = sound.micMuted {
                        chip(micMuted ? "mic.slash.fill" : "mic.fill", micMuted ? "Mic muted" : "Mute mic",
                             on: micMuted, tint: K.red) {
                            model.muteMic(!micMuted)
                        }
                    }
                    ForEach(sound.outputs) { output in
                        chip(PocketMacPresentation.outputSymbol(output.kind), output.name, on: output.current, tint: nil) {
                            guard !output.current else { return }
                            model.setOutput(output.id)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .macCard()
        .onChange(of: sound.volume) { _, _ in
            // The Mac caught up: its reading is the truth again.
            if !dragging { draft = nil }
        }
    }

    private func slider(_ value: Double) -> some View {
        GeometryReader { geometry in
            let fraction = value / 100
            Capsule().fill(K.fg.opacity(0.1))
                .overlay(alignment: .leading) {
                    Capsule().fill(K.fg).frame(width: max(dragging ? 10 : 6, geometry.size.width * fraction))
                }
                .frame(height: dragging ? 10 : 6)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let next = (min(1, max(0, drag.location.x / max(1, geometry.size.width))) * 100).rounded()
                        if !dragging { dragging = true; Haptics.tap() }
                        if let draft, Int(draft) / 10 != Int(next) / 10 { Haptics.select() }
                        draft = next
                        send(next, final: false)
                    }
                    .onEnded { _ in
                        dragging = false
                        if let draft { send(draft, final: true) }
                    })
                .animation(Motion.spring, value: dragging)
                .animation(dragging ? nil : Motion.spring, value: fraction)
        }
        .frame(height: 24)
        .accessibilityElement()
        .accessibilityLabel("Volume")
        .accessibilityValue("\(Int(value.rounded()))%")
        .accessibilityAdjustableAction { direction in
            let next = min(100, max(0, value + (direction == .increment ? 10 : -10)))
            draft = next
            send(next, final: true)
        }
    }

    /// At once when the last send was a while ago, else once the drag rests.
    private func send(_ value: Double, final: Bool) {
        trailing?.cancel()
        let now = Date()
        if final || now.timeIntervalSince(lastSent) >= Self.sendEvery {
            lastSent = now
            model.setVolume(Int(value))
        } else {
            trailing = Task { @MainActor in
                try? await Task.sleep(for: .seconds(Self.sendEvery))
                guard !Task.isCancelled else { return }
                lastSent = Date()
                model.setVolume(Int(value))
            }
        }
        if final {
            // A Mac that never answers (asleep) lets the slider fall back.
            settle?.cancel()
            settle = Task { @MainActor in
                try? await Task.sleep(for: .seconds(6))
                guard !Task.isCancelled, !dragging else { return }
                withAnimation(Motion.spring) { draft = nil }
            }
        }
    }

    private func chip(_ symbol: String, _ title: String, on: Bool, tint: Color?, action: @escaping () -> Void) -> some View {
        let color = on ? (tint ?? K.bg) : K.muted
        return Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 12, weight: .semibold))
                Text(title).font(K.sans(12, bold: true)).lineLimit(1)
            }
            .foregroundStyle(color)
            .padding(.horizontal, 12).frame(height: 34)
            .background(on ? (tint.map { $0.opacity(0.12) } ?? K.fg) : K.fg.opacity(0.07), in: Capsule())
            .overlay(Capsule().strokeBorder(on ? (tint ?? .clear).opacity(0.25) : .clear, lineWidth: 1))
            .animation(Motion.quick, value: on)
        }
        .buttonStyle(PressStyle())
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
