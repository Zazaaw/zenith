// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI

/// How things stand, as one word for the glow behind the hero.
enum PocketMood: Hashable {
    /// The Mac answers and nothing needs a look.
    case calm
    /// Claude waits for a reply or asks for permission.
    case waiting
    /// A watched site is down.
    case alert
    /// The Mac can't be reached: nothing to be glad or worried about.
    case quiet
}

extension PocketModel {
    /// What the aura shows. The Mac out of reach outranks everything, since
    /// what the phone knows is then old; a site down outranks Claude.
    func mood(now: Date) -> PocketMood {
        guard let state, freshness(now: now).isReachable else { return .quiet }
        if state.sites?.sites.contains(where: { $0.status == .down }) == true { return .alert }
        let asking = state.claude?.sessions.contains { $0.state == .asking } ?? false
        if !state.questions.isEmpty || asking || waitingSession(now: now) != nil { return .waiting }
        return .calm
    }
}

/// A soft glow at the top of the screen, behind the hero, that breathes
/// slowly and takes the colour of the mood: emerald, amber, red, or a quiet
/// grey. A new mood crossfades in over a second and a half. The glow drifts
/// a few points with the phone's lean (the dot grid drifts the other way).
///
/// Cheap by design: two radial gradients (no blur, no Canvas) that a slow
/// animation only scales and fades, and a mood read once a minute. Still
/// under Reduce Motion.
struct StateAura: View {
    let mood: PocketMood
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ForEach([mood], id: \.self) { mood in
                AuraLayer(mood: mood)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? .easeOut(duration: 0.3) : .easeInOut(duration: 1.6), value: mood)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// One mood's glow: a large wash from the top leading corner and a smaller
/// one lower on the trailing side, breathing out of step.
private struct AuraLayer: View {
    let mood: PocketMood
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let dark = scheme == .dark
        let (main, second) = tints(dark: dark)
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .topLeading) {
                Glow(color: main, diameter: w * 1.7, breath: 5.2, delay: 0, still: reduceMotion)
                    .position(x: w * 0.16, y: 40)
                Glow(color: second, diameter: w * 1.15, breath: 6.8, delay: 1.4, still: reduceMotion)
                    .position(x: w * 0.98, y: 230)
            }
        }
    }

    /// The two glows' colours at full strength; the gradients fade them out.
    private func tints(dark: Bool) -> (Color, Color) {
        switch mood {
        case .calm:
            return (K.emerald.opacity(dark ? 0.30 : 0.20), K.blue.opacity(dark ? 0.16 : 0.10))
        case .waiting:
            return (K.amber.opacity(dark ? 0.30 : 0.24), K.amber.opacity(dark ? 0.16 : 0.12))
        case .alert:
            return (K.red.opacity(dark ? 0.30 : 0.20), K.amber.opacity(dark ? 0.12 : 0.09))
        case .quiet:
            let grey = dark ? Color.white : Color.black
            return (grey.opacity(dark ? 0.08 : 0.05), grey.opacity(dark ? 0.05 : 0.03))
        }
    }
}

/// A round radial wash from `color` to clear (soft without a blur pass); it
/// swells and dims a little over `breath` seconds and back.
private struct Glow: View {
    let color: Color
    let diameter: CGFloat
    let breath: Double
    let delay: Double
    let still: Bool

    var body: some View {
        let wash = Circle()
            .fill(RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: color, location: 0),
                    .init(color: color.opacity(0.55), location: 0.32),
                    .init(color: color.opacity(0.18), location: 0.62),
                    .init(color: color.opacity(0), location: 1),
                ]),
                center: .center, startRadius: 0, endRadius: diameter / 2))
            .frame(width: diameter, height: diameter)
        if still {
            wash
        } else {
            wash.phaseAnimator([false, true]) { content, out in
                content
                    .scaleEffect(out ? 1.08 : 0.94)
                    .opacity(out ? 1 : 0.72)
            } animation: { out in
                .easeInOut(duration: breath / 2).delay(out ? delay : 0)
            }
        }
    }
}
