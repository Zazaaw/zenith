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
// (`ZenithContentRide`); SwiftUI swaps follow the same sequence: the old view
// fades and blurs out over 0.12 s, then the new one eases in from a blur, a
// few points up. Reduce Motion leaves a plain cross-fade in either place.

enum ZenithMorph {
    /// Peak blur on the way out and in, in points.
    static let blur: CGFloat = 10
    /// Outgoing content shrinks to this, around the island's top centre.
    static let scale: CGFloat = 0.97
    /// The spring for SwiftUI swaps and for anything that rides along.
    static let response: Double = 0.38
    static let damping: Double = 0.86

    static var animation: Animation { .spring(response: response, dampingFraction: damping) }

    /// The swap's animation, or a short cross-fade under Reduce Motion.
    static func animation(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: ZenithMotion.fast) : animation
    }

    /// The leaving view's fade, and the arriving view's delayed ease.
    static var leaving: Animation { .linear(duration: ZenithContentRide.outgoingFade) }
    static var arriving: Animation {
        .timingCurve(0.42, 0, 0.58, 1, duration: ZenithContentRide.incomingFade).delay(ZenithContentRide.incomingDelay)
    }
}

/// Content `amount` of the way out: 0 in place, 1 gone; `rise` points up at 1.
private struct ZenithMorphEffect: ViewModifier {
    let amount: CGFloat
    let blur: CGFloat
    var rise: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .blur(radius: blur * amount)
            .opacity(Double(1 - amount))
            .offset(y: -rise * amount)
    }
}

extension AnyTransition {
    /// Out: blur 0 → 8 and gone over 0.12 s. In, from 0.05 s over 0.3 s:
    /// blur 12 → 0, 8 points up to its place, opacity 0 → 1.
    static var zenithMorph: AnyTransition {
        .asymmetric(
            insertion: .modifier(active: ZenithMorphEffect(amount: 1, blur: ZenithContentRide.incomingBlur,
                                                           rise: ZenithContentRide.incomingRise),
                                 identity: ZenithMorphEffect(amount: 0, blur: ZenithContentRide.incomingBlur,
                                                             rise: ZenithContentRide.incomingRise))
                .animation(ZenithMorph.arriving),
            removal: .modifier(active: ZenithMorphEffect(amount: 1, blur: ZenithContentRide.outgoingBlur),
                               identity: ZenithMorphEffect(amount: 0, blur: ZenithContentRide.outgoingBlur))
                .animation(ZenithMorph.leaving))
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
