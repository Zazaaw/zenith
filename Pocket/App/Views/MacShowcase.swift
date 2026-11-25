// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI

/// The Mac as a small MacBook: its real wallpaper, a menu bar, Zenith's
/// island saying what the Mac is up to, a dock, and a blurred lock screen
/// when it is locked. It leans with the phone, light slides across it, its
/// screen glows with the wallpaper's colour, and power runs into it through
/// MagSafe while it charges. On first showing it rises and settles in.
struct MacShowcase: View {
    let state: PocketMacState?
    let wallpaper: UIImage?
    let now: Date
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var settled = false
    /// On screen (not scrolled away): the tilt and the charging light run only then.
    @State private var visible = true

    /// The screen, in points: sized for a 390-point-wide iPhone with room to lean.
    static let screen = CGSize(width: 300, height: 192)
    private static let bezel: CGFloat = 6
    private static let baseWidth: CGFloat = 344
    /// The whole object's height, base and shadow included.
    static let height: CGFloat = 236

    private var width: CGFloat { Self.screen.width }
    private var height: CGFloat { Self.screen.height }
    private var dark: Bool { scheme == .dark }
    private var locked: Bool { state?.locked == true }
    private var charging: Bool { state?.battery?.charging == true }
    private var onPower: Bool { charging || state?.battery?.pluggedIn == true }
    /// Whether anything should move right now.
    private var animating: Bool { visible && !reduceMotion && scenePhase == .active }

    var body: some View {
        ZStack(alignment: .bottom) {
            FloorShadow(width: Self.baseWidth * 0.86, dark: dark)
                .offset(y: 4)
            VStack(spacing: 0) {
                lid
                base
            }
            .padding(.bottom, 12)
        }
        .frame(height: Self.height)
        .onScrollVisibilityChange(threshold: 0.05) { visible = $0 }
        // The entrance: up from below, the lid tipping forward into place.
        .opacity(settled ? 1 : 0)
        .blur(radius: settled || reduceMotion ? 0 : 6)
        .rotation3DEffect(.degrees(settled || reduceMotion ? 0 : 16), axis: (x: 1, y: 0, z: 0),
                          anchor: .bottom, perspective: 0.6)
        .scaleEffect(settled || reduceMotion ? 1 : 0.94, anchor: .bottom)
        .offset(y: settled || reduceMotion ? 0 : 34)
        .onAppear {
            guard !settled else { return }
            withAnimation(reduceMotion ? .easeOut(duration: 0.3)
                          : .spring(response: 0.8, dampingFraction: 0.7).delay(0.15)) { settled = true }
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var text = locked ? "Your Mac, locked" : "Your Mac's screen"
        if charging { text += ", charging" }
        return text
    }

    // MARK: Lid

    private var lid: some View {
        let glow = WallpaperGlow.color(of: wallpaper)
        return ZStack(alignment: .top) {
            background
            menuBar
            island
            if let session = runningProject { window(session) }
            dock
            if locked { lockScreen.transition(.opacity.combined(with: .blurReplace)) }
        }
        .animation(Motion.reveal, value: locked)
        .animation(Motion.island, value: islandKey)
        .frame(width: width, height: height)
        .overlay {
            // The glass: a fixed gloss from the top, and the light that moves.
            ZStack {
                LinearGradient(colors: [.white.opacity(0.10), .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.35))
                Specular(strength: dark ? 0.16 : 0.22)
            }
            .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .padding(Self.bezel)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(white: 0.09)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        .background {
            // The screen's light on whatever is behind it.
            if let glow {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(glow)
                    .padding(-6)
                    .blur(radius: 30)
                    .opacity((dark ? 0.42 : 0.3) * (locked ? 0.4 : 1))
                    .animation(Motion.reveal, value: locked)
                    .accessibilityHidden(true)
            }
        }
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
        HStack(spacing: 7) {
            Image(systemName: "apple.logo").font(.system(size: 8))
            Text("Finder").font(.system(size: 7.5, weight: .bold))
            Text("File  Edit  View").font(.system(size: 7.5))
            Spacer()
            if let battery = state?.battery {
                Image(systemName: Self.batterySymbol(battery))
                    .font(.system(size: 8.5))
                    .symbolRenderingMode(.hierarchical)
                    .contentTransition(.symbolEffect(.replace))
            }
            Text(now, format: .dateTime.weekday(.abbreviated).hour().minute()).font(.system(size: 7.5, weight: .medium))
        }
        .foregroundStyle(.white).padding(.horizontal, 9).frame(height: 14)
        .background(Color.black.opacity(0.2))
    }

    static func batterySymbol(_ battery: PocketMacState.Battery) -> String {
        if battery.charging { return "battery.100percent.bolt" }
        switch battery.percent {
        case ..<13: return "battery.0percent"
        case ..<38: return "battery.25percent"
        case ..<63: return "battery.50percent"
        case ..<88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }

    /// What changes the island's shape, so it springs between them.
    private var islandKey: String {
        if let question = state?.questions.first { return "q" + question.id }
        if let song = state?.nowPlaying, song.playing { return "s" + song.title }
        if let until = state?.awakeUntil, until > now { return "a" }
        return charging ? "c" : ""
    }

    /// What Zenith's island would show: a question first, then a song, then
    /// Keep Awake, then charging, otherwise just the island.
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
            } else if charging, let battery = state?.battery {
                Image(systemName: "bolt.fill").font(.system(size: 8, weight: .bold)).foregroundStyle(K.emerald)
                    .symbolEffect(.pulse, options: .repeating, isActive: animating)
                Text("Charging").font(.system(size: 8, weight: .bold)).foregroundStyle(.white)
                Spacer(minLength: 0)
                Text("\(battery.percent)%").font(.system(size: 8, weight: .bold)).foregroundStyle(K.emerald)
                    .contentTransition(.numericText(value: Double(battery.percent)))
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 10).frame(width: 132, height: 21)
        .background(UnevenRoundedRectangle(bottomLeadingRadius: 10.5, bottomTrailingRadius: 10.5, style: .continuous).fill(.black))
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
            ForEach(Array([64.0, 82, 46].enumerated()), id: \.offset) { _, w in
                Capsule().fill(Color.white.opacity(0.25)).frame(width: w, height: 2.5)
            }
        }
        .padding(8).frame(width: 110, alignment: .leading)
        .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 6))
        .padding(.leading, 11).padding(.top, 36).frame(width: width, alignment: .leading)
    }

    private var dock: some View {
        VStack {
            Spacer()
            HStack(spacing: 4) {
                ForEach(Array([Color.blue, .green, .pink, .orange, .white, .purple].enumerated()), id: \.offset) { _, color in
                    RoundedRectangle(cornerRadius: 3.5).fill(color.opacity(0.9)).frame(width: 14, height: 14)
                }
            }
            .padding(4).background(Color.white.opacity(0.25), in: RoundedRectangle(cornerRadius: 6)).padding(.bottom, 5)
        }
    }

    /// The Mac's own lock screen: the wallpaper frosted, the date and a large
    /// time at the top, the account and its lock at the bottom.
    private var lockScreen: some View {
        ZStack {
            background
                .blur(radius: 9, opaque: true)
                .overlay(Color.black.opacity(0.32))
            VStack(spacing: 1) {
                Text(now, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text(now, format: .dateTime.hour().minute())
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .tracking(-0.5)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 24)
            VStack(spacing: 5) {
                Circle().fill(.white.opacity(0.22))
                    .overlay(Image(systemName: "person.fill").font(.system(size: 10)).foregroundStyle(.white.opacity(0.9)))
                    .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 0.5))
                    .frame(width: 22, height: 22)
                HStack(spacing: 3) {
                    Image(systemName: "lock.fill").font(.system(size: 6.5, weight: .bold))
                    Text("Locked").font(.system(size: 7, weight: .semibold))
                }
                .foregroundStyle(.white.opacity(0.75))
                .padding(.horizontal, 7).padding(.vertical, 2.5)
                .background(.white.opacity(0.14), in: Capsule())
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 14)
        }
        .frame(width: width, height: height)
    }

    // MARK: Base

    /// The base: dark aluminium in dark, silver in light, with the thumb
    /// notch; a MagSafe plug at its left end when on power, and light running
    /// along its edge while it charges.
    private var base: some View {
        let shape = UnevenRoundedRectangle(bottomLeadingRadius: 10, bottomTrailingRadius: 10, style: .continuous)
        return shape
            .fill(LinearGradient(colors: dark ? [Color(white: 0.30), Color(white: 0.15)] : [Color(white: 0.9), Color(white: 0.7)],
                                 startPoint: .top, endPoint: .bottom))
            .overlay { Specular(strength: dark ? 0.22 : 0.5).clipShape(shape) }
            .overlay(alignment: .top) {
                Capsule().fill(Color(white: dark ? 0.12 : 0.6)).frame(width: 54, height: 3.5)
            }
            .overlay(alignment: .top) {
                if charging && animating {
                    ChargeFlow(tint: K.emerald)
                        .frame(height: 1.5)
                        .clipShape(shape)
                        .transition(.opacity)
                }
            }
            .frame(width: Self.baseWidth, height: 11)
            .overlay(alignment: .leading) {
                if onPower {
                    magSafe
                        .offset(x: -15)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            .animation(Motion.spring, value: onPower)
            .animation(Motion.quick, value: charging && animating)
    }

    /// The plug and its light: green and breathing while it charges, steady
    /// while held at a limit.
    private var magSafe: some View {
        HStack(spacing: 0) {
            Capsule().fill(Color(white: dark ? 0.35 : 0.62)).frame(width: 10, height: 2.5)
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(Color(white: dark ? 0.42 : 0.78))
                .frame(width: 7, height: 5)
                .overlay(alignment: .trailing) {
                    Circle().fill(K.emerald).frame(width: 2.2, height: 2.2)
                        .shadow(color: K.emerald, radius: 2)
                        .modifier(Breathing(active: charging && animating))
                        .padding(.trailing, 1)
                }
        }
        .accessibilityHidden(true)
    }
}
