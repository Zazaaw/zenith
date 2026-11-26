// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI
import WatchKit

/// The p441z Style Kit on the Watch: SF Pro (the Watch's own face, bold and
/// regular for contrast, never italic or serif), black surfaces, colour only
/// for status. The names match the iPhone's `K`, so the companion star
/// (`ClaudeMascot.swift`, shared with the iPhone app) draws the same here.
enum K {
    static let bg = Color.black
    static let card = Color(white: 0.11)
    static let fg = Color(white: 0.98)
    static let muted = Color(white: 0.66)
    static let faint = Color(white: 0.47)
    static let track = Color.white.opacity(0.14)

    static let blue = Color(red: 0.231, green: 0.510, blue: 0.965)
    static let purple = Color(red: 0.659, green: 0.333, blue: 0.969)
    static let amber = Color(red: 0.961, green: 0.620, blue: 0.043)
    static let emerald = Color(red: 0.063, green: 0.725, blue: 0.506)
    static let red = Color(red: 0.937, green: 0.267, blue: 0.267)

    static func color(_ tone: PocketTone) -> Color {
        switch tone {
        case .plain: return fg
        case .quiet: return muted
        case .good: return emerald
        case .info: return blue
        case .attention: return amber
        case .alert: return red
        case .progress: return purple
        }
    }
}

/// Pocket's motion curves, the iPhone's (`Motion.swift`), for the Watch.
enum Motion {
    static let reveal = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.6)
    static let toggle = Animation.timingCurve(0.4, 0, 0.2, 1, duration: 0.3)
    static let spring = Animation.spring(response: 0.42, dampingFraction: 0.72)
    static let fill = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.9)
    static let quick = Animation.easeOut(duration: 0.2)

    /// Reduce Motion turns movement into plain fades.
    static func respecting(_ reduceMotion: Bool, _ animation: Animation) -> Animation {
        reduceMotion ? .easeOut(duration: 0.2) : animation
    }
}

/// Haptics, one word per meaning, as on the iPhone.
@MainActor
enum Haptics {
    static func tap() { WKInterfaceDevice.current().play(.click) }
    static func soft() { WKInterfaceDevice.current().play(.click) }
    static func success() { WKInterfaceDevice.current().play(.success) }
    static func failure() { WKInterfaceDevice.current().play(.failure) }
    static func notify() { WKInterfaceDevice.current().play(.notification) }
}

/// The hero sentence: a bold lead with the value in its tone, then the rest
/// in regular weight. "**Your MacBook is at 47%,** and charging."
struct SentenceText: View {
    let sentence: PocketSentence
    var size: CGFloat = 17

    var body: some View {
        let lead = Text(sentence.lead).fontWeight(.bold).foregroundStyle(K.fg)
        let value = Text(sentence.value).fontWeight(.bold).foregroundStyle(K.color(sentence.tone))
        let after = Text(sentence.after).fontWeight(.bold).foregroundStyle(K.fg)
        let rest = Text(sentence.rest.isEmpty ? "" : " " + sentence.rest).fontWeight(.regular).foregroundStyle(K.muted)
        Text("\(lead)\(value)\(after)\(rest)")
            .font(.system(size: size))
            .fixedSize(horizontal: false, vertical: true)
            .contentTransition(.interpolate)
            .animation(Motion.spring, value: sentence)
            .accessibilityLabel(sentence.text)
    }
}

/// How fresh the state is, small and quiet: "2m ago", "Checking…".
struct FreshnessLine: View {
    let heardAt: Date?
    let checking: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            HStack(spacing: 5) {
                Circle().fill(dot(context.date)).frame(width: 5, height: 5)
                Text(text(context.date)).font(.system(size: 12)).foregroundStyle(K.faint).lineLimit(1)
            }
        }
        .animation(Motion.quick, value: checking)
    }

    private func text(_ now: Date) -> String {
        if checking { return "Checking…" }
        guard let heardAt else { return "Waiting for your Mac" }
        return PocketPresentation.ago(heardAt, now: now)
    }

    private func dot(_ now: Date) -> Color {
        let freshness = PocketPresentation.freshness(heardAt: heardAt, live: false, now: now)
        return freshness.isReachable ? K.emerald : K.faint
    }
}

/// A round action under the hero: a symbol on glass, its word under it.
struct ActionButton: View {
    let symbol: String
    let title: String
    var tint: Color = K.fg
    var on = false
    var busy = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    if busy {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: symbol)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(on ? Color.black : tint)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .frame(width: 44, height: 44)
                .background(on ? AnyShapeStyle(tint) : AnyShapeStyle(Color.clear), in: Circle())
                .glassEffect(.regular.interactive(), in: Circle())
                Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(K.muted).lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .animation(Motion.spring, value: on)
        .animation(Motion.quick, value: busy)
        .accessibilityLabel(title)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// A small ring: a battery's level round its device's symbol.
struct LevelRing: View {
    let value: Double
    let tint: Color
    let symbol: String
    var charging = false
    var size: CGFloat = 34
    @State private var shown = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().stroke(K.track, lineWidth: 3.5)
            Circle().trim(from: 0, to: shown)
                .stroke(tint, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: symbol).font(.system(size: size * 0.36, weight: .medium)).foregroundStyle(K.fg)
            if charging {
                Image(systemName: "bolt.fill").font(.system(size: 8, weight: .bold)).foregroundStyle(K.emerald)
                    .padding(2).background(Color.black, in: Circle())
                    .offset(y: -size / 2)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: size, height: size)
        .onAppear { withAnimation(Motion.respecting(reduceMotion, Motion.fill)) { shown = value } }
        .onChange(of: value) { _, next in withAnimation(Motion.respecting(reduceMotion, Motion.fill)) { shown = next } }
        .animation(Motion.spring, value: charging)
    }
}

/// A short note that slides in over the bottom of a page and goes.
struct NoteBanner: View {
    let note: WatchModel.Note

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: note.symbol).font(.system(size: 12, weight: .bold)).foregroundStyle(K.color(note.tone))
            Text(note.text).font(.system(size: 13, weight: .semibold)).foregroundStyle(K.fg)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .glassEffect(.regular, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}
