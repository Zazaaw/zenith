// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import QuartzCore
import SwiftUI

// Zenith fork: how content changes inside the island. Studied frame by frame
// on a reference island at 60 fps: when a page swaps, the container springs to
// its new size while the old content blurs out and the new one blurs in;
// around 70 to 100 ms in, both are a soft blur, and by about 270 ms the new
// page is sharp. The outgoing layer also dips a few percent in scale.
//
// SwiftUI swaps (a module's own sub-views, the tab pill) use
// `AnyTransition.zenithMorph` with `ZenithMorph.animation`. The island's page
// swaps run in its window host, where the content rides the shape
// (`ZenithContentRide`). Both follow the motion chosen on Settings →
// Appearance (`IslandMotion`): Zenith's container springs with a bounce while
// the new view grows from 90% and comes into focus; Snappy's container lands
// first without a swing and the new view arrives sharp straight after. Reduce
// Motion leaves a plain cross-fade, and the battery saver plain fades.

enum ZenithMorph {
    /// Zenith 1×'s peak blur and the outgoing scale, for look-alike effects
    /// outside the island (the design overlay's HUD).
    static let blur: CGFloat = 10
    static let scale: CGFloat = 0.97

    /// The container's spring in force, for timers that wait it out.
    static var response: Double { IslandMotion.current.morph.duration }
    static var damping: Double {
        if case let .spring(damping) = IslandMotion.current.morph.kind { return damping }
        return 1
    }

    static var animation: Animation { IslandMotion.current.morph.animation }

    /// The swap's animation, or a short cross-fade under Reduce Motion.
    static func animation(reduceMotion: Bool) -> Animation {
        var motion = IslandMotion.current
        if reduceMotion { motion.reduceMotion = true }
        return motion.morph.animation
    }

    /// The leaving view's fade, and the arriving view's delayed ease.
    static var leaving: Animation { IslandMotion.current.leaving.animation }
    static var arriving: Animation { IslandMotion.current.arriving.animation }
}

/// Content `amount` of the way out: 0 in place, 1 gone, blurred `blur` points.
private struct ZenithMorphFade: ViewModifier {
    let amount: CGFloat
    let blur: CGFloat

    func body(content: Content) -> some View {
        content
            .blur(radius: blur * amount)
            .opacity(Double(1 - amount))
    }
}

/// Content `amount` of the way from its size to `scale`, hung from its top.
private struct ZenithMorphGrowth: ViewModifier {
    let amount: CGFloat
    let scale: CGFloat

    func body(content: Content) -> some View {
        content.scaleEffect(1 + (scale - 1) * amount, anchor: .top)
    }
}

extension AnyTransition {
    /// In: from the motion's blur and scale into focus, on its arriving
    /// curve, the growth on the container's own spring. Out: a quick fade
    /// and blur. Read from the motion in force when the swap happens.
    static var zenithMorph: AnyTransition {
        let motion = IslandMotion.current
        let fadeIn = AnyTransition.modifier(active: ZenithMorphFade(amount: 1, blur: motion.morphBlurIn),
                                            identity: ZenithMorphFade(amount: 0, blur: motion.morphBlurIn))
            .animation(motion.arriving.animation)
        let insertion = motion.morphScaleIn == 1 ? fadeIn
            : fadeIn.combined(with: .modifier(active: ZenithMorphGrowth(amount: 1, scale: motion.morphScaleIn),
                                              identity: ZenithMorphGrowth(amount: 0, scale: motion.morphScaleIn))
                .animation(motion.arrivingGrowth.animation))
        let removal = AnyTransition.modifier(active: ZenithMorphFade(amount: 1, blur: motion.morphBlurOut),
                                             identity: ZenithMorphFade(amount: 0, blur: motion.morphBlurOut))
            .animation(motion.leaving.animation)
        return .asymmetric(insertion: insertion, removal: removal)
    }

    /// The morph, or a plain fade under Reduce Motion.
    static func zenithMorph(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .zenithMorph
    }
}

extension View {
    /// Swaps this content through the morph whenever `value` changes: the
    /// old view blurs out as the new one blurs in, on the island's spring.
    func zenithMorph<Value: Hashable>(on value: Value) -> some View {
        modifier(ZenithMorphSwap(value: value))
    }
}

private struct ZenithMorphSwap<Value: Hashable>: ViewModifier {
    let value: Value
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        ZStack {
            content
                .id(value)
                .transition(.zenithMorph(reduceMotion: reduceMotion))
        }
        .animation(ZenithMorph.animation(reduceMotion: reduceMotion), value: value)
    }
}
