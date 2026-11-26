// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI
import WatchKit

/// What plays on the Mac: the track, previous / play-pause / next, and the
/// Mac's volume on the Digital Crown, with a firmer tick at every tenth.
struct MediaPage: View {
    @Environment(WatchModel.self) private var model
    @State private var crown = 0.0
    /// The crown moved here and its value hasn't been sent and seen yet.
    @State private var turning = false
    @State private var sendWork: Task<Void, Never>?
    @State private var lastTenth = 0

    var body: some View {
        let playing = model.state?.nowPlaying
        let sound = model.state?.sound
        let reachable = model.freshness().isReachable
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: playing?.app ?? "Now playing")
            if let playing {
                Text(playing.title).font(.system(size: 17, weight: .bold)).foregroundStyle(K.fg).lineLimit(2)
                    .contentTransition(.opacity)
                Text(playing.artist).font(.system(size: 14)).foregroundStyle(K.muted).lineLimit(1)
            } else {
                Text("Nothing is playing on your Mac.").font(.system(size: 15, weight: .semibold)).foregroundStyle(K.muted)
            }
            Spacer(minLength: 2)
            HStack(spacing: 4) {
                transport("backward.fill", "Previous", .previous)
                transport(playing?.playing == true ? "pause.fill" : "play.fill", playing?.playing == true ? "Pause" : "Play", .playPause,
                          big: true)
                transport("forward.fill", "Next", .next)
            }
            .disabled(!reachable || playing == nil)
            .opacity(reachable && playing != nil ? 1 : 0.45)
            volume(sound)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .focusable(sound != nil && reachable)
        .digitalCrownRotation($crown, from: 0, through: 100, by: 1, sensitivity: .medium,
                              isContinuous: false, isHapticFeedbackEnabled: true)
        .onChange(of: crown) { _, value in crowned(value) }
        .onAppear { if let sound { crown = Double(sound.volume); lastTenth = sound.volume / 10 } }
        .onChange(of: sound?.volume) { _, next in
            guard let next, !turning else { return }
            crown = Double(next)
            lastTenth = next / 10
        }
        .animation(Motion.spring, value: playing)
        .containerBackground(K.blue.opacity(0.18).gradient, for: .tabView)
    }

    private func transport(_ symbol: String, _ label: String, _ action: PocketCommand.MediaAction, big: Bool = false) -> some View {
        Button {
            model.media(action)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: big ? 22 : 16, weight: .bold))
                .contentTransition(.symbolEffect(.replace))
                .frame(maxWidth: .infinity, minHeight: big ? 46 : 40)
        }
        .buttonStyle(.glass)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private func volume(_ sound: PocketSound?) -> some View {
        if sound != nil {
            let shown = Int(crown.rounded())
            HStack(spacing: 6) {
                Image(systemName: PocketMacPresentation.volumeSymbol(shown, muted: sound?.muted ?? false))
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(K.muted)
                    .frame(width: 18)
                Gauge(value: crown, in: 0...100) { EmptyView() }
                    .gaugeStyle(.accessoryLinearCapacity)
                    .tint(K.fg)
                Text("\(shown)").font(.system(size: 12, weight: .bold).monospacedDigit()).foregroundStyle(K.fg)
                    .contentTransition(.numericText(value: crown))
                    .frame(width: 26, alignment: .trailing)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Mac volume")
            .accessibilityValue("\(shown) percent")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: crown = min(100, crown + 10)
                case .decrement: crown = max(0, crown - 10)
                @unknown default: break
                }
            }
        } else {
            Text("Turn the crown for volume once your Mac shares its sound.")
                .font(.system(size: 11)).foregroundStyle(K.faint)
        }
    }

    /// Sends the volume once the crown rests, so the Mac's limit of ten
    /// commands a minute is never spent on one turn.
    private func crowned(_ value: Double) {
        guard let sound = model.state?.sound else { return }
        let percent = Int(value.rounded())
        if percent / 10 != lastTenth {
            lastTenth = percent / 10
            WKInterfaceDevice.current().play(.directionUp)
        }
        guard percent != sound.volume else { return }
        turning = true
        sendWork?.cancel()
        sendWork = Task {
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            model.setVolume(percent)
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            turning = false
        }
    }
}
