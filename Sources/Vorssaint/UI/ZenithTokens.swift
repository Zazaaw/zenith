// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith design tokens, after the p441z Style Kit (docs/DESIGN.md in
// Zazaaw/p441z-style-kit): grey surfaces, color only as meaning, personality
// from motion. Text stays SF Pro and controls keep the system accent color.
//
// Upstream views are moved onto these tokens one area at a time (notch, then
// the menu panel, then Settings), so a sync only conflicts where Zenith has
// already redesigned.

// MARK: - Status colors

/// The only hues Zenith uses on its own: status and data that carries meaning.
/// Always pair a status color with a text label.
enum ZenithStatus {
    /// Upcoming, informational.
    static let info = adaptive(light: 0x2563EB, dark: 0x3B82F6)       // blue 600 / 500
    /// In progress.
    static let progress = adaptive(light: 0x9333EA, dark: 0xA855F7)   // purple 600 / 500
    /// Pending, warning.
    static let warning = adaptive(light: 0xD97706, dark: 0xF59E0B)    // amber 600 / 500
    /// Completed, healthy.
    static let success = adaptive(light: 0x059669, dark: 0x10B981)    // emerald 600 / 500
    /// Failed, critical.
    static let error = adaptive(light: 0xDC2626, dark: 0xEF4444)      // red 600 / 500
    /// No particular state.
    static let neutral = Color.secondary

    /// Style Kit's status chip: a 10% fill and a 20% border under full-strength text.
    static func fill(_ color: Color) -> Color { color.opacity(0.10) }
    static func stroke(_ color: Color) -> Color { color.opacity(0.20) }

    /// Light mode uses the 600 step: the kit's 500 step is too faint for small
    /// macOS text on a white surface. Dark mode keeps the kit's 500.
    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return srgb(isDark ? dark : light)
        })
    }

    private static func srgb(_ hex: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1)
    }
}

// MARK: - Motion

/// Style Kit motion: things that appear decelerate hard, things that move into
/// place land on a spring. Nothing UI-facing runs longer than half a second.
enum ZenithMotion {
    /// Color changes and hover fills.
    static let fast: TimeInterval = 0.2
    /// Borders, collapses, pill switches.
    static let standard: TimeInterval = 0.3
    /// Large transforms.
    static let slow: TimeInterval = 0.5
    /// Gap between layers that arrive one after another.
    static let layerStagger: TimeInterval = 0.04

    /// Entrances and reveals: `[0.22, 1, 0.36, 1]`.
    static func reveal(_ duration: TimeInterval = standard) -> Animation {
        .timingCurve(0.22, 1, 0.36, 1, duration: duration)
    }

    /// Collapses and toggles: `[0.4, 0, 0.2, 1]`.
    static func toggle(_ duration: TimeInterval = standard) -> Animation {
        .timingCurve(0.4, 0, 0.2, 1, duration: duration)
    }

    /// Moving into place with a few percent of overshoot: `(.34, 1.36, .5, 1)`.
    /// Overshoot only transforms (scale, offset, rotation), never opacity or color.
    static func spring(_ duration: TimeInterval = standard) -> Animation {
        .timingCurve(0.34, 1.36, 0.5, 1, duration: duration)
    }

    /// Press down fast; release with `spring`.
    static let press = Animation.timingCurve(0.4, 0, 0.2, 1, duration: 0.1)
    /// Scale a pressed element settles to.
    static let pressedScale: CGFloat = 0.94

    /// Delay for the `index`-th layer of a staggered arrival.
    static func layerDelay(_ index: Int) -> TimeInterval { Double(index) * layerStagger }

    /// The animation to use, or nil when the person asked macOS to reduce motion.
    static func respecting(_ animation: Animation) -> Animation? {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? nil : animation
    }
}

// MARK: - Radius

/// One base radius and the steps derived from it, as in the Style Kit.
/// Cards sit above the base and pills are fully round on purpose.
enum ZenithRadius {
    static let base: CGFloat = 8
    static let small: CGFloat = base - 4      // 4
    static let medium: CGFloat = base - 2     // 6
    static let large: CGFloat = base          // 8
    static let card: CGFloat = base + 4       // 12
    static let panel: CGFloat = base + 8      // 16
}

// MARK: - Type

/// SF Pro sizes for Zenith's own views. One high-contrast element per section;
/// everything else steps back to `.secondary`.
enum ZenithType {
    static let caption = Font.system(size: 11)
    static let footnote = Font.system(size: 12)
    static let body = Font.system(size: 13)
    static let emphasis = Font.system(size: 13, weight: .semibold)
    static let title = Font.system(size: 17, weight: .semibold)
    static let display = Font.system(size: 26, weight: .bold)
    /// Figures that change in place (timers, levels, percentages).
    static func figures(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight).monospacedDigit()
    }
}
