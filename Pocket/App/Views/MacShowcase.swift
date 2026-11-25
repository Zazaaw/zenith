// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI

/// The Mac as a small MacBook: its real wallpaper, a menu bar, Zenith's
/// island saying what the Mac is up to, a dock, and a dimmed lock screen
/// when it is locked.
struct MacShowcase: View {
    let state: PocketMacState?
    let wallpaper: UIImage?
    let now: Date

    private let width: CGFloat = 330
    private let height: CGFloat = 212

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                background
                menuBar
                island
                if let session = runningProject { window(session) }
                dock
                if state?.locked == true { lockScreen }
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(7)
            .background(RoundedRectangle(cornerRadius: 17, style: .continuous).fill(Color(white: 0.09)))
            .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
            UnevenRoundedRectangle(bottomLeadingRadius: 10, bottomTrailingRadius: 10, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.30), Color(white: 0.16)], startPoint: .top, endPoint: .bottom))
                .frame(width: 380, height: 12)
                .overlay(alignment: .top) { Capsule().fill(Color(white: 0.12)).frame(width: 56, height: 3.5) }
        }
        .accessibilityElement()
        .accessibilityLabel(state?.locked == true ? "Your Mac, locked" : "Your Mac's screen")
    }

    private var background: some View {
        Group {
            if let wallpaper {
                Image(uiImage: wallpaper).resizable().aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(colors: [Color(white: 0.22), Color(white: 0.08)], startPoint: .top, endPoint: .bottom)
            }
        }
        .frame(width: width, height: height).clipped()
    }

    private var menuBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "apple.logo").font(.system(size: 8))
            Text("Finder").font(.system(size: 7.5, weight: .bold))
            Text("File  Edit  View").font(.system(size: 7.5))
            Spacer()
            Text(now, format: .dateTime.weekday(.abbreviated).hour().minute()).font(.system(size: 7.5, weight: .medium))
        }
        .foregroundStyle(.white).padding(.horizontal, 10).frame(height: 14)
        .background(Color.black.opacity(0.2))
    }

    /// What Zenith's island would show: a question first, then a song, then
    /// Keep Awake, otherwise just the island.
    private var island: some View {
        HStack(spacing: 7) {
            if let state, !state.questions.isEmpty {
                Image(systemName: "sparkle").font(.system(size: 8, weight: .bold)).foregroundStyle(K.amber)
                Text("Claude asks").font(.system(size: 8, weight: .bold)).foregroundStyle(.white)
                Spacer(minLength: 0)
                bars
            } else if let song = state?.nowPlaying, song.playing {
                Image(systemName: "music.note").font(.system(size: 8, weight: .bold)).foregroundStyle(.white.opacity(0.8))
                Text(song.title).font(.system(size: 8, weight: .bold)).foregroundStyle(.white).lineLimit(1)
                Spacer(minLength: 0)
                bars
            } else if let until = state?.awakeUntil, until > now {
                Image(systemName: "cup.and.saucer.fill").font(.system(size: 8, weight: .bold)).foregroundStyle(K.amber)
                Spacer(minLength: 0)
                Text(PocketPresentation.awakeMinutesLeft(until, now: now).map { PocketPresentation.duration(minutes: $0) } ?? "∞")
                    .font(.system(size: 8, weight: .bold)).foregroundStyle(.white)
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 10).frame(width: 140, height: 22)
        .background(UnevenRoundedRectangle(bottomLeadingRadius: 11, bottomTrailingRadius: 11, style: .continuous).fill(.black))
    }

    private var bars: some View {
        HStack(spacing: 1.5) {
            ForEach(Array([4.0, 7, 5, 8, 4].enumerated()), id: \.offset) { _, h in
                Capsule().fill(Color.white.opacity(0.8)).frame(width: 1.6, height: h)
            }
        }
    }

    private var runningProject: String? {
        guard let state else { return nil }
        if let question = state.questions.first { return PocketPresentation.questionDetail(question) ?? question.project }
        return state.sessions.first { $0.status == .running }?.project
    }

    private func window(_ line: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 3) {
                ForEach(Array([K.red, K.amber, K.emerald].enumerated()), id: \.offset) { _, color in
                    Circle().fill(color).frame(width: 5, height: 5)
                }
            }
            Text(line).font(K.mono(7)).foregroundStyle(.white.opacity(0.8)).lineLimit(1)
            ForEach(Array([70.0, 90, 50].enumerated()), id: \.offset) { _, w in
                Capsule().fill(Color.white.opacity(0.25)).frame(width: w, height: 2.5)
            }
        }
        .padding(8).frame(width: 118, alignment: .leading)
        .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 6))
        .padding(.leading, 12).padding(.top, 40).frame(width: width, alignment: .leading)
    }

    private var dock: some View {
        VStack {
            Spacer()
            HStack(spacing: 4) {
                ForEach(Array([Color.blue, .green, .pink, .orange, .white, .purple].enumerated()), id: \.offset) { _, color in
                    RoundedRectangle(cornerRadius: 3.5).fill(color.opacity(0.9)).frame(width: 15, height: 15)
                }
            }
            .padding(4).background(Color.white.opacity(0.25), in: RoundedRectangle(cornerRadius: 6)).padding(.bottom, 5)
        }
    }

    private var lockScreen: some View {
        ZStack {
            Color.black.opacity(0.55)
            VStack(spacing: 4) {
                Image(systemName: "lock.fill").font(.system(size: 14, weight: .semibold))
                Text(now, format: .dateTime.hour().minute()).font(.system(size: 22, weight: .bold))
            }
            .foregroundStyle(.white)
        }
        .frame(width: width, height: height)
    }
}
