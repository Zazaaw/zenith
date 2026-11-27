// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

/// Zenith fork: how Settings → Appearance writes its choices, and the one-time
/// move from the island's old glass switches. Every write goes through here so
/// clamping, the switch to Custom and the old glass key stay in one place.
/// `ZenithAppearance` reads the result back from the same defaults.
enum ZenithAppearanceStore {
    // MARK: Motion

    /// Picks a template. Custom keeps the sliders it last had.
    static func selectPreset(_ preset: IslandMotionPreset, in defaults: UserDefaults = .standard) {
        defaults.set(preset.rawValue, forKey: ZenithAppearanceDefaults.motionPreset)
    }

    /// Moving Bounce, Blur or Content pace turns the motion into Custom,
    /// starting from what the island showed, so only the moved slider changes.
    static func editCustom(from current: IslandMotionSettings, in defaults: UserDefaults = .standard,
                           _ change: (inout IslandMotionValues) -> Void) {
        var values = current.values
        change(&values)
        values = values.clamped()
        defaults.set(values.bounce, forKey: ZenithAppearanceDefaults.motionBounce)
        defaults.set(values.blur, forKey: ZenithAppearanceDefaults.motionBlur)
        defaults.set(values.contentPace, forKey: ZenithAppearanceDefaults.motionContentPace)
        if current.preset != .custom { selectPreset(.custom, in: defaults) }
    }

    /// Custom's sliders as Custom would load them (Zenith's values for any
    /// never moved), whichever template is chosen now.
    static func customValues(in defaults: UserDefaults = .standard) -> IslandMotionValues {
        var values = IslandMotionPreset.custom.values
        if let bounce = defaults.object(forKey: ZenithAppearanceDefaults.motionBounce) as? Double { values.bounce = bounce }
        if let blur = defaults.object(forKey: ZenithAppearanceDefaults.motionBlur) as? Double { values.blur = blur }
        if let pace = defaults.object(forKey: ZenithAppearanceDefaults.motionContentPace) as? Double { values.contentPace = pace }
        return values.clamped()
    }

    /// The overall speed, for every template.
    static func setSpeed(_ speed: Double, in defaults: UserDefaults = .standard) {
        defaults.set(clamp(speed, IslandMotionSettings.speedRange, fallback: 1), forKey: ZenithAppearanceDefaults.motionSpeed)
    }

    // MARK: Glass

    /// The island's glass. The old Liquid Glass switch follows, because the
    /// island's controls and the panel still read it to match their surface.
    static func setGlassStyle(_ style: IslandGlassStyle, in defaults: UserDefaults = .standard) {
        defaults.set(style.rawValue, forKey: ZenithAppearanceDefaults.glassStyle)
        mirrorLegacyGlass(style, in: defaults)
    }

    static func setGradientHeight(_ height: Double, in defaults: UserDefaults = .standard) {
        defaults.set(clamp(height, 0...1, fallback: IslandGlassSettings.standard.gradientHeight),
                     forKey: ZenithAppearanceDefaults.glassGradientHeight)
    }

    static func setTint(_ tint: Double, in defaults: UserDefaults = .standard) {
        defaults.set(clamp(tint, 0...1, fallback: IslandGlassSettings.standard.tint), forKey: ZenithAppearanceDefaults.glassTint)
    }

    // MARK: Battery

    static func setBatterySaver(_ saver: IslandBatterySaver, in defaults: UserDefaults = .standard) {
        defaults.set(saver.rawValue, forKey: ZenithAppearanceDefaults.batterySaver)
    }

    // MARK: The old glass switches

    /// Before Appearance the island had two switches: Liquid Glass (Settings →
    /// General) and a translucent background (Dynamic Island → Layout). With no
    /// glass style saved yet (an upgrade, or a backup from before), the old
    /// choice becomes the style once: Liquid Glass, else the translucent
    /// background as Gradient, else Black. After that the style leads and the
    /// Liquid Glass key only mirrors it.
    static func migrateLegacyGlass(in defaults: UserDefaults = .standard) {
        let saved = defaults.string(forKey: ZenithAppearanceDefaults.glassStyle).flatMap(IslandGlassStyle.init(rawValue:))
        guard let style = saved else {
            let migrated: IslandGlassStyle = defaults.bool(forKey: DefaultsKey.notchLiquidGlassEnabled) ? .liquid
                : defaults.bool(forKey: DefaultsKey.notchTranslucentBackground) ? .gradient : .black
            setGlassStyle(migrated, in: defaults)
            return
        }
        mirrorLegacyGlass(style, in: defaults)
    }

    private static func mirrorLegacyGlass(_ style: IslandGlassStyle, in defaults: UserDefaults) {
        // Written only when it differs, so a reload that calls this never
        // posts another change.
        let liquid = style == .liquid
        if defaults.bool(forKey: DefaultsKey.notchLiquidGlassEnabled) != liquid {
            defaults.set(liquid, forKey: DefaultsKey.notchLiquidGlassEnabled)
        }
    }

    // MARK: Helpers

    static func clamp(_ value: Double, _ range: ClosedRange<Double>, fallback: Double) -> Double {
        value.isFinite ? min(max(value, range.lowerBound), range.upperBound) : fallback
    }
}
