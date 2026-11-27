// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: the little island on each motion tile in Settings → Appearance,
/// opening, holding, closing and resting in a loop, in the timing of one
/// `IslandMotionSettings`. Pure numbers, so the tile only draws them.
struct IslandMotionPreview: Equatable {
    /// One moment of the loop.
    struct Frame: Equatable {
        /// 0 closed, 1 open; a bouncy spring passes 1 before it settles.
        var shape: Double
        /// How far the content has arrived, 0…1.
        var content: Double
        /// The content's blur, in the island's points.
        var blur: Double

        static let open = Frame(shape: 1, content: 1, blur: 0)
        static let closed = Frame(shape: 0, content: 0, blur: 0)
    }

    let settings: IslandMotionSettings

    /// How long the island stays open, and closed, between openings. Held
    /// steady at every speed so a slow preset still has a moment to read.
    static let hold: Double = 0.9
    static let rest: Double = 0.6

    /// Long enough for the spring to settle and the content to land.
    var opening: Double {
        max(settings.springResponse * 1.6, settings.contentDelay + settings.contentDuration + 0.1)
    }

    /// Closing has no bounce: a quick ease back into the notch.
    var closing: Double { 0.32 / settings.speed }

    var cycle: Double { opening + Self.hold + closing + Self.rest }

    func frame(at time: Double) -> Frame {
        guard time.isFinite else { return .open }
        var t = time.truncatingRemainder(dividingBy: cycle)
        if t < 0 { t += cycle }
        if t < opening { return arriving(at: t) }
        t -= opening
        if t < Self.hold { return .open }
        t -= Self.hold
        if t < closing {
            let progress = t / closing
            let eased = progress * progress * (3 - 2 * progress)
            // The content leaves in the first part of the close.
            let content = max(0, 1 - progress / 0.45)
            return Frame(shape: 1 - eased, content: content, blur: settings.values.blur * (1 - content) * 0.5)
        }
        return .closed
    }

    private func arriving(at t: Double) -> Frame {
        let shape = Self.spring(at: t, response: settings.springResponse, damping: settings.springDamping)
        let raw = settings.contentDuration > 0 ? (t - settings.contentDelay) / settings.contentDuration : 1
        let linear = min(max(raw, 0), 1)
        let content = 1 - pow(1 - linear, 3)
        return Frame(shape: shape, content: content, blur: settings.values.blur * (1 - content))
    }

    /// A spring from 0 to 1 with SwiftUI's response and damping fraction.
    static func spring(at t: Double, response: Double, damping: Double) -> Double {
        guard t > 0 else { return 0 }
        let omega = 2 * Double.pi / max(response, 0.01)
        let zeta = min(max(damping, 0), 1)
        if zeta >= 0.999 {
            return 1 - exp(-omega * t) * (1 + omega * t)
        }
        let damped = omega * (1 - zeta * zeta).squareRoot()
        return 1 - exp(-zeta * omega * t) * (cos(damped * t) + zeta * omega / damped * sin(damped * t))
    }
}
