// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// The splash glass's spring timeline: every uniform `liquidMetal` reads, as
// a function of time. Ported from zanwei/glass-icon-reveal (MIT,
// https://github.com/zanwei/glass-icon-reveal) through p441z.my.id's
// GlassLogoReveal. Kept free of UI code so it can be rendered offline.

/// The uniforms, in the order the shader's enum lists them.
enum GlassUniform: Int, CaseIterable {
    case cx, cy, tile, time, plateScale, shapeN, cornerN, optics, plateAlpha, logoHalf
    case bold, blur, frost, dome, drop, pinch, tilt, rim, halo, shadow, ghost, ripR, ripA
    case bare, reach, cornerPull, streak, widen, slab, etaSpread, focus, focusK, focusSplit
    case rimLine, cornerOn, dissolve, glow, faceDisp, vivid, disp, double, bevelW, spec
    case iconPlate, lightScene, lightGlass, keep, sheen, sweep, lightAng, metal, scale
}

/// The glass's tuning for a light or a dark screen, as on p441z.my.id:
/// light is clear glass with a contact shadow; dark sits on a near-black
/// plate with a halo.
struct GlassLook {
    var dark: Bool
    var logoScale = 0.6
    var finalScale = 0.8
    var opticalDepth = 1.1, dispersion = 1.7, colorBleed = 1.25, doubleBevel = 1.0, bevelWidth = 0.14
    var corner = 4.8, cornerPull = 2.1, cornerWidth = 2.2, cornerFocus = 0.58, edgeSmear = 2.85
    var stretch = 0.0, tilt = 0.35, bulge = 1.0, specular = 1.0, halo = 0.0, shadow = 1.0, ripple = 1.0
    var bounce = 0.0, response = 0.42, startSize = 0.2, startZoom = 2.6, glide = 2.3, present = 2.4
    var drift = 0.12, swell = 0.5, focus = 1.0, sheen = 1.0, lightTurn = 0.9
    /// How much of the glass is mirror. The original is clear glass (0).
    var metal = 1.0

    /// From the glass letting go to everything at rest.
    static let tail = 1.1
    var end: Double { present + Self.tail }

    init(dark: Bool) {
        self.dark = dark
        guard dark else { return }
        iconPlate = true; halo = 1; shadow = 0; ripple = 0.5; startZoom = 1.6; drift = 0.05
        opticalDepth = 0.75; bevelWidth = 0.22; dispersion = 0.9; colorBleed = 0.45; corner = 5
        cornerPull = 1.4; edgeSmear = 1.2; tilt = 0; cornerWidth = 1.2; cornerFocus = 0.4
    }

    /// The dark look's glass sits on a near-black tile of its own.
    var iconPlate = false

    /// The star's half-size, in tile halves, once everything is at rest:
    /// fixes the tile's size from the star's.
    var finalLogoHalf: Double { frame(at: end)[.logoHalf] ?? (logoScale * finalScale) }

    // MARK: The spring timeline

    static func spring(_ t: Double, _ response: Double, _ damping: Double) -> Double {
        guard t > 0 else { return 0 }
        let w = 2 * Double.pi / response
        if damping >= 1 { return 1 - exp(-w * t) * (1 + w * t) }
        let wd = w * (1 - damping * damping).squareRoot()
        return 1 - exp(-damping * w * t) * (cos(wd * t) + (damping * w) / wd * sin(wd * t))
    }

    /// When a spring first reaches `level`, by bisection.
    static func timeToReach(_ level: Double, _ response: Double, _ damping: Double) -> Double {
        var lo = 0.0, hi = 3.0
        for _ in 0..<40 {
            let mid = (lo + hi) / 2
            if spring(mid, response, damping) < level { lo = mid } else { hi = mid }
        }
        return hi
    }

    static func clamp01(_ x: Double) -> Double { min(1, max(0, x)) }
    static func mix(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
    static func smooth(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let t = clamp01((x - a) / (b - a)); return t * t * (3 - 2 * t)
    }
    static func smoother(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let t = clamp01((x - a) / (b - a)); return t * t * t * (t * (t * 6 - 15) + 10)
    }

    /// Every uniform at `T` seconds into the reveal.
    func frame(at T: Double) -> [GlassUniform: Double] {
        typealias L = GlassLook
        let tx = present
        let damping = 1 - bounce
        let grow = L.spring(T + 0.01, response, damping)
        let tl = L.timeToReach(0.85, response, damping) - 0.01
        let tm = L.timeToReach(0.92, response, damping) - 0.01
        let morph = L.spring(T - tm, 0.4, 1)
        let drop = 1 - L.smooth(0.05, 1, morph)
        let appear = L.smooth(0, 0.08, T)
        let drifted = drift * L.spring(T - 0.3, 2.2, 1)
        let zoomIn = 0.25 * L.spring(T, 0.7, 1) + 0.75 * L.smoother(0, glide, T)
        let settle = L.spring(T - 0.5, 2.4, 1)
        let exit = L.spring(T - tx, 0.95, 1)
        let release = L.spring(T - tx - 0.05, 0.65, 1)
        let dome = 0.15 * bulge * (1 - L.smooth(0.4, 0.95, grow))
        let view = (1 + (startZoom - 1) * (1 - zoomIn)) * (1 - 0.045 * settle) * L.mix(1, finalScale, exit)
        let bandW = L.mix(bevelWidth, max(bevelWidth, 0.4), drop)
        let plateScale = L.mix(startSize, 1, grow) * (1 + drifted) * (1 + 0.14 * release)
        return [
            .plateScale: plateScale,
            .shapeN: L.mix(2, corner, morph),
            .cornerN: corner,
            .optics: 1 - L.smooth(0.55, 1, release),
            .plateAlpha: appear * (1 - L.smooth(0.45, 1, release)),
            .logoHalf: logoScale * view,
            .keep: 0,
            .sheen: sheen,
            .sweep: L.mix(-1.6, 1.6, L.smoother(0.9, tx - 0.1, T)),
            .lightAng: lightTurn * L.smoother(0.4, tx + 0.4, T),
            .bold: swell * 0.03 * (1 - zoomIn),
            .blur: focus * 0.05 * (1 - L.smooth(0.3, 0.95, grow)),
            .frost: focus * (1 - L.smooth(0.5, 0.95, grow)),
            .pinch: 0.38 * stretch * L.smooth(0.1, 0.9, morph) * L.smooth(0.75, 0.97, zoomIn),
            .tilt: tilt,
            .dome: dome,
            .drop: drop,
            .rim: 1 + 0.8 * drop,
            .halo: halo * (0.5 + 0.5 * drop),
            .shadow: shadow * L.smooth(0.45, 0.8, grow) * (1 - L.smooth(0, 0.6, morph)),
            .ghost: L.smooth(0, 0.03, T) * (1 - L.smooth(0.04, 0.08, T)),
            .ripR: 1 + 0.9 * max(0, T - tl),
            .ripA: ripple * L.smooth(tl, tl + 0.06, T) * exp(-max(0, T - tl) / 0.6),
            .bare: L.smooth(tx - 0.25, tx, T),
            .reach: bandW * plateScale,
            .cornerPull: cornerPull,
            .streak: edgeSmear,
            .widen: cornerWidth,
            .slab: 0.3 * opticalDepth,
            .etaSpread: 0.06,
            .focus: cornerFocus,
            .focusK: 1,
            .focusSplit: 0.056 * colorBleed,
            .rimLine: 0.09,
            .cornerOn: L.smooth(0.35, 1, morph),
            .glow: 0.012 * colorBleed,
            .faceDisp: 0.012 * dispersion,
            .vivid: 0.85,
            .dissolve: release,
            .disp: dispersion,
            .double: doubleBevel,
            .bevelW: bandW * (1 - release),
            .spec: specular,
            .iconPlate: iconPlate ? 1 : 0,
            .lightScene: dark ? 0 : 1,
            .lightGlass: dark ? 0 : 1,
            .metal: metal,
        ]
    }
}
