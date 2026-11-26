// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Once per launch: a liquid metal droplet springs in over the Satu Visual
/// star, holds while the light turns round it, lets go and leaves the star;
/// "Zenith Pocket" and the link's line rise under it, then the app fades in.
/// A tap skips it; Reduce Motion makes it a plain fade.
struct SplashView: View {
    let onDone: () -> Void

    @Environment(PocketModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    @State private var finished = false
    @State private var stillShown = false

    /// The glass runs half again as fast as its own timeline, as on the web.
    private static let speed = 1.5
    private static let starSize: CGFloat = 92

    var body: some View {
        let look = GlassLook(dark: scheme == .dark)
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = reduceMotion ? 10 : max(0, context.date.timeIntervalSince(start))
            let T = t * Self.speed
            let glassDone = T >= look.end
            // The star has one place for the whole splash, the screen's centre:
            // the glass draws it there and the still star takes over in the
            // same spot, so it never jumps; only the text arrives below it.
            GeometryReader { geo in
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                ZStack {
                    if glassDone {
                        K.bg
                    } else {
                        GlassReveal(time: T, center: center, starSize: Self.starSize, look: look)
                    }
                    layout(t: t, glassDone: glassDone, center: center, height: geo.size.height)
                }
            }
            .ignoresSafeArea()
        }
        .opacity(reduceMotion && !stillShown ? 0 : 1)
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Zenith Pocket, by Satu Visual")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens Pocket")
        .task {
            if reduceMotion {
                withAnimation(.easeOut(duration: 0.3)) { stillShown = true }
                try? await Task.sleep(for: .seconds(1.2))
            } else {
                start = Date()
                try? await Task.sleep(for: .seconds(look.end / Self.speed))
                Haptics.soft()
                try? await Task.sleep(for: .seconds(1.15))
            }
            finish()
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onDone()
    }

    /// The approved layout: the star, the wordmark, the link's line, and the
    /// credit at the bottom. The text rises in as the glass lets go.
    private func layout(t: Double, glassDone: Bool, center: CGPoint, height: CGFloat) -> some View {
        let release = GlassLook(dark: scheme == .dark).present / Self.speed
        let word = reduceMotion ? 1 : Motion.revealCurve((t - release - 0.05) / 0.55)
        let line = reduceMotion ? 1 : Motion.revealCurve((t - release - 0.3) / 0.55)
        return ZStack {
            StarShape()
                .fill(K.fg, style: FillStyle(eoFill: true))
                .frame(width: Self.starSize, height: Self.starSize)
                .position(center)
                .opacity(glassDone ? 1 : 0)
            // The text hangs from the star's bottom edge; the star stays put.
            VStack(spacing: 22) {
                Text("\(Text("Zenith ").font(K.sans(34, bold: true)).foregroundStyle(K.fg))\(Text("Pocket").font(K.sans(34)).foregroundStyle(K.muted))")
                    .tracking(-1)
                    .opacity(word).blur(radius: 8 * (1 - word)).offset(y: 10 * (1 - word))
                status(t: t)
                    .opacity(line).offset(y: 6 * (1 - line))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, center.y + Self.starSize / 2 + 22)
            Text("by Satu Visual").font(K.sans(12, bold: true)).tracking(1).foregroundStyle(K.faint)
                .opacity(line)
                .position(x: center.x, y: height - 58)
        }
    }

    /// "Connecting to <Mac>" with a pulsing dot, "Connected to <Mac>" once
    /// the link is live, or "Pair with your Mac" before there is one.
    private func status(t: Double) -> some View {
        let name = model.state?.macName ?? model.pairing?.macName
        let live = model.link == .live
        let text = name.map { live ? "Connected to \($0)" : "Connecting to \($0)" } ?? "Pair with your Mac"
        let pulse = live || reduceMotion ? 1 : 0.35 + 0.65 * abs(sin(t * 3))
        return HStack(spacing: 8) {
            Circle().fill(name == nil ? K.faint : K.emerald).frame(width: 6, height: 6).opacity(pulse)
            Text(text).font(K.mono(12)).foregroundStyle(K.faint).lineLimit(1)
        }
        .padding(.horizontal, 24)
    }
}
