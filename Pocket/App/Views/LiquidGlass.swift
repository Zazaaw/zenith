// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// The splash's liquid metal droplet over the Satu Visual star, drawn by
/// `liquidMetal` in LiquidMetal.metal on every frame of a `TimelineView`.
///
/// All the motion lives in `GlassLook.frame(at:)` (GlassTimeline.swift), ported from
/// zanwei/glass-icon-reveal (MIT, https://github.com/zanwei/glass-icon-reveal)
/// through p441z.my.id's GlassLogoReveal; the shader only sees numbers.
/// The droplet springs in small and round, swells into a rounded tile while
/// the star glides out of its magnification, holds while the light turns
/// round it and a sheen crosses, then lets go: the glass dissolves outward
/// and the bare star is left, at `starSize`, centred on `center`.
struct GlassReveal: View {
    /// Seconds into the glass's own timeline.
    let time: Double
    /// The star's centre in this view's coordinates.
    let center: CGPoint
    /// The star's width when the glass has gone.
    let starSize: CGFloat
    let look: GlassLook

    @Environment(\.displayScale) private var displayScale
    @Environment(\.self) private var environment

    var body: some View {
        let values = uniforms()
        Rectangle()
            .fill(K.bg)
            .colorEffect(ShaderLibrary.liquidMetal(
                .floatArray(values),
                .color(Color((look.dark ? Color(white: 0.02) : Color.white).resolve(in: environment))),
                .color(Color(K.fg.resolve(in: environment)))))
            .accessibilityHidden(true)
    }

    private func uniforms() -> [Float] {
        let f = look.frame(at: time)
        let tile = starSize / look.finalLogoHalf
        var u = [Float](repeating: 0, count: GlassUniform.allCases.count)
        func set(_ key: GlassUniform, _ value: Double) { u[key.rawValue] = Float(value) }
        set(.cx, center.x); set(.cy, center.y); set(.tile, tile); set(.time, time); set(.scale, displayScale)
        for (key, value) in f { set(key, value) }
        return u
    }
}
