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
// swaps run in its window host, where Core Animation crossfades the hosting
// layer while the silhouette springs; the host draws the same blur and dip
// there with the `layer…` values, so both read as one motion. Reduce Motion
// leaves a plain cross-fade in either place.

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

    /// The window host's page swap: the blur and dip run over
    /// `layerDuration`, peaking `layerPeak` of the way through, while the
    /// hosting layer crossfades over `layerCrossfade`.
    static let layerDuration: CFTimeInterval = 0.34
    static let layerPeak: Double = 0.3
    static let layerCrossfade: CFTimeInterval = 0.22
    /// Into the peak fast, out of it on the Style Kit's reveal curve.
    static var layerTimings: [CAMediaTimingFunction] {
        [CAMediaTimingFunction(name: .easeOut), CAMediaTimingFunction(controlPoints: 0.22, 1, 0.36, 1)]
    }

    /// Whether a swap at a surface of `height` is an open page changing,
    /// which morphs, rather than a closed strip's reading, which only fades.
    static func morphs(height: CGFloat) -> Bool {
        ZenithIslandSilhouette.openness(height: height) >= 0.5
    }
}

/// Content `amount` of the way out: 0 in place, 1 gone.
private struct ZenithMorphEffect: ViewModifier {
    let amount: CGFloat

    func body(content: Content) -> some View {
        content
            .blur(radius: ZenithMorph.blur * amount)
            .opacity(Double(1 - amount))
            .scaleEffect(1 - (1 - ZenithMorph.scale) * amount)
    }
}

extension AnyTransition {
    /// Out: blur 0 → 10, opacity 1 → 0, scale 1 → 0.97. In: the reverse.
    static var zenithMorph: AnyTransition {
        .modifier(active: ZenithMorphEffect(amount: 1), identity: ZenithMorphEffect(amount: 0))
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
