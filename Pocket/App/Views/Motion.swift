// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI
import UIKit

/// Pocket's motion, from the p441z Style Kit: colour stays quiet, movement
/// carries the personality. Every screen uses these, so the app moves as one.
enum Motion {
    /// Reveals and entrances: decelerates hard at the end, [0.22, 1, 0.36, 1].
    static let reveal = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.6)
    /// Collapses and toggles, [0.4, 0, 0.2, 1].
    static let toggle = Animation.timingCurve(0.4, 0, 0.2, 1, duration: 0.3)
    /// Things that move into place: overshoots a little and settles.
    static let spring = Animation.spring(response: 0.42, dampingFraction: 0.72)
    /// The island bar's morph: a stronger, rubbery spring, like the Dynamic Island.
    static let island = Animation.spring(response: 0.5, dampingFraction: 0.68)
    /// Toasts and banners sliding in: quick, with a small bounce.
    static let toast = Animation.spring(response: 0.38, dampingFraction: 0.78)
    /// Meters filling: the reveal curve, a little longer, so the fill reads.
    static let fill = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.9)
    /// Colour and hover changes.
    static let quick = Animation.easeOut(duration: 0.2)
    /// Stagger between siblings appearing in turn.
    static let stagger: Double = 0.05

    /// Reduce Motion turns movement into plain fades.
    static func respecting(_ reduceMotion: Bool, _ animation: Animation) -> Animation {
        reduceMotion ? .easeOut(duration: 0.2) : animation
    }

    /// The Style Kit's reveal curve as a function, for timelines drawn by
    /// hand (the splash): close enough to [0.22, 1, 0.36, 1] as easeOutQuint.
    static func revealCurve(_ x: Double) -> Double { 1 - pow(1 - min(1, max(0, x)), 5) }
}

/// Fades content in while un-blurring it and drifting it up a few points:
/// the Style Kit's signature entrance. `delay` staggers siblings.
struct BlurFade: ViewModifier {
    var delay: Double = 0
    var distance: CGFloat = 10
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .blur(radius: shown || reduceMotion ? 0 : 8)
            .offset(y: shown || reduceMotion ? 0 : distance)
            .onAppear {
                withAnimation(Motion.respecting(reduceMotion, Motion.reveal).delay(delay)) { shown = true }
            }
    }
}

extension View {
    func blurFade(delay: Double = 0, distance: CGFloat = 10) -> some View {
        modifier(BlurFade(delay: delay, distance: distance))
    }

    /// The `index`-th sibling of a list appearing in turn.
    func blurFade(index: Int, base: Double = 0) -> some View {
        modifier(BlurFade(delay: base + Double(index) * Motion.stagger))
    }

    /// A press that dips to 94% and springs back, with a light tap felt as
    /// the finger lands (the moment the press registers, not on release).
    func pressable(haptic: Bool = true) -> some View { buttonStyle(PressStyle(haptic: haptic)) }
}

struct PressStyle: ButtonStyle {
    var haptic = true
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(configuration.isPressed ? .easeOut(duration: 0.1) : Motion.spring, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed && haptic && isEnabled { Haptics.tap() }
            }
    }
}

extension View {
    /// A number that rolls to its new value (battery, CPU, timers) instead of
    /// jumping: SwiftUI's numeric text transition on Pocket's spring.
    func countingNumber(_ value: Double) -> some View {
        contentTransition(.numericText(value: value)).animation(Motion.spring, value: value)
    }
}

/// A whole number that counts up from zero when it first appears, then rolls
/// digit by digit whenever it changes. `format` wraps it ("47%", "3 repos").
struct RollingNumber: View {
    let value: Int
    var format: (Int) -> String = { "\($0)" }
    @State private var shown = 0
    @State private var started = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(format(shown))
            .contentTransition(.numericText(value: Double(shown)))
            .onAppear {
                guard !started else { return }
                started = true
                if reduceMotion { shown = value; return }
                withAnimation(Motion.reveal.speed(0.6)) { shown = value }
            }
            .onChange(of: value) { _, next in
                withAnimation(Motion.spring) { shown = next }
            }
            .accessibilityLabel(format(value))
    }
}

/// Tabs slide sideways with a blur, toward the side the new tab sits on in
/// the island bar, so the content seems to move with the pill.
struct TabSlide: Transition {
    /// +1 when the new tab is to the right of the old one.
    var direction: CGFloat

    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .opacity(phase.isIdentity ? 1 : 0)
            .blur(radius: phase.isIdentity ? 0 : 6)
            .offset(x: -phase.value * 28 * direction)
    }
}

/// Haptics, one word per meaning.
@MainActor
enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func press() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    /// A soft landing: a sheet, the splash letting go, a card opening.
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.7) }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func failure() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func select() { UISelectionFeedbackGenerator().selectionChanged() }
}

/// A placeholder that shimmers while data loads: a soft band of light
/// crossing it, in either theme.
struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { g in
                    LinearGradient(colors: [.clear, K.shine, .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: g.size.width * 0.6)
                        .offset(x: phase * g.size.width)
                }
                .clipped()
                .allowsHitTesting(false)
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) { phase = 1.4 }
            }
    }
}

extension View {
    func shimmering() -> some View { modifier(Shimmer()) }
}

/// A grey block standing in for text or a card until the first state lands.
struct Skeleton: View {
    var width: CGFloat?
    var height: CGFloat = 14
    var radius: CGFloat = 7

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(K.track)
            .frame(width: width, height: height)
            .shimmering()
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
            .accessibilityHidden(true)
    }
}
