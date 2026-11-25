// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI

/// The Mac tab: how the Mac runs ("Your Mac runs at 38%, cool and quiet."),
/// lock and keep awake, what plays and how loud, Zenith's quick tools, the
/// next event, Send to Mac, and the busiest apps.
///
/// While it shows, the phone tells the Mac it watches (every minute, as the
/// Mac expects), so the Mac reads its health and sound only then.
struct MacView: View {
    @Environment(PocketModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    let now: Date
    @State private var sheet: MacSheet?

    /// The Mac forgets an open phone after 150 s without a word.

    var body: some View {
        let state = model.state
        let freshness = model.freshness(now: now)
        let reachable = freshness.isReachable
        let tools = state?.tools
        VStack(alignment: .leading, spacing: 0) {
            Hero(eyebrow: state?.macName ?? model.pairing?.macName ?? "Mac",
                 badge: PocketPresentation.controlBadge(state, freshness: freshness),
                 sentence: PocketMacPresentation.sentence(state, freshness: freshness, now: now),
                 footnote: PocketPresentation.updatedLine(freshness, now: now),
                 onSettings: { model.showingSettings = true })
                .animation(Motion.spring, value: state?.health?.cpuPercent)
                .blurFade()
            if let problem = model.controlProblem(now: now) {
                Text(problem).font(K.sans(13)).foregroundStyle(K.muted)
                    .macCard()
                    .padding(.horizontal, 20).padding(.top, 18)
                    .transition(.opacity)
            }
            VStack(alignment: .leading, spacing: 22) {
                MacHealthTiles(health: reachable ? state?.health : nil, reachable: reachable, history: model.mac.history)
                    .blurFade(index: 1)
                MacControls(now: now)
                    .blurFade(index: 2)
                if let song = state?.nowPlaying {
                    section("Playing on Mac", trailing: song.app) { MacNowPlaying(song: song) }
                        .disabled(!model.canControl(now: now))
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }
                if let sound = state?.sound, reachable {
                    section("Sound", trailing: PocketMacPresentation.currentOutput(sound)) { MacSound(sound: sound) }
                        .disabled(!model.canControl(now: now))
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }
                MacQuickTiles(tools: tools) { sheet = $0 }
                    .blurFade(index: 3)
                if let event = tools?.nextEvent {
                    MacNextUp(event: event, now: now).transition(.opacity)
                }
                SendToMacCard { sheet = .send }
                    .blurFade(index: 4)
                if let top = state?.health?.top, !top.isEmpty, reachable {
                    MacBusiest(top: top).transition(.opacity)
                }
                if let downloads = tools?.downloads, !downloads.isEmpty {
                    MacDownloads(downloads: downloads).transition(.opacity)
                }
                if let clips = tools?.clips, !clips.isEmpty {
                    MacClips(clips: clips).transition(.opacity)
                }
            }
            .padding(.horizontal, 20).padding(.top, 20)
            .animation(Motion.spring, value: state?.nowPlaying?.title)
            .animation(Motion.spring, value: state?.sound == nil)
            .animation(Motion.spring, value: state?.health?.top.isEmpty)
        }
        // Presence is the app's (PocketModel): an open Pocket keeps the Mac
        // sampling health and sound, so switching tabs doesn't flap it.
        .sheet(item: $sheet) { sheet in
            Group {
                switch sheet {
                case .workspaces: WorkspacesSheet()
                case .timer: TimerSheet()
                case .devServers: DevServersSheet()
                case .send: SendToMacSheet()
                }
            }
            .environment(model)
        }
    }

    private func section<Content: View>(_ title: String, trailing: String?,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: title, trailing: trailing)
            content()
        }
    }
}
