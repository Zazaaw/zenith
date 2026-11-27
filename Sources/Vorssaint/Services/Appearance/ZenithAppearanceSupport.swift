// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: the island's look and feel, chosen on Settings → Appearance.
// Pure values and their storage, so the motion system, the glass and the
// battery saver all read one source. The page, the island and the policy that
// decides when to save battery live in their own files.

/// Preference keys for Appearance.
enum ZenithAppearanceDefaults {
    static let motionPreset = "zenithIslandMotionPreset"        // String, IslandMotionPreset raw value
    static let motionBounce = "zenithIslandMotionBounce"        // Double 0…1, custom only
    static let motionBlur = "zenithIslandMotionBlur"            // Double points 0…20, custom only
    static let motionContentPace = "zenithIslandMotionContentPace" // Double 0.5…2, custom only
    static let motionSpeed = "zenithIslandMotionSpeed"          // Double 0.5…2, every preset
    static let glassStyle = "zenithIslandGlassStyle"            // String, IslandGlassStyle raw value
    static let glassGradientHeight = "zenithIslandGlassGradientHeight" // Double 0…1
    static let glassTint = "zenithIslandGlassTint"              // Double 0…1
    static let batterySaver = "zenithIslandBatterySaver"        // String, IslandBatterySaver raw value

    static let all: [String] = [motionPreset, motionBounce, motionBlur, motionContentPace, motionSpeed,
                                glassStyle, glassGradientHeight, glassTint, batterySaver]
}

/// A template for how the island moves. `custom` uses the person's own sliders.
enum IslandMotionPreset: String, CaseIterable, Identifiable {
    case zenith, snappy, calm, playful, custom
    var id: String { rawValue }

    /// The preset's values; `custom` starts from Zenith's.
    var values: IslandMotionValues {
        switch self {
        case .zenith, .custom:
            return IslandMotionValues(bounce: 0.7, blur: 10, contentPace: 1, staged: false)
        case .snappy:
            return IslandMotionValues(bounce: 0, blur: 4, contentPace: 1.6, staged: true)
        case .calm:
            return IslandMotionValues(bounce: 0.2, blur: 14, contentPace: 0.7, staged: false)
        case .playful:
            return IslandMotionValues(bounce: 0.9, blur: 8, contentPace: 1.1, staged: false)
        }
    }
}

/// The knobs behind a preset.
struct IslandMotionValues: Equatable {
    /// 0 lands without overshoot, 1 is a rubbery bounce.
    var bounce: Double
    /// Peak blur of arriving and leaving content, in points.
    var blur: Double
    /// How fast content appears relative to the shape: 0.5 slow, 2 quick.
    var contentPace: Double
    /// Shape first, then content (Snappy), instead of both riding together.
    var staged: Bool

    static let bounceRange: ClosedRange<Double> = 0...1
    static let blurRange: ClosedRange<Double> = 0...20
    static let paceRange: ClosedRange<Double> = 0.5...2

    func clamped() -> IslandMotionValues {
        IslandMotionValues(bounce: min(max(bounce, Self.bounceRange.lowerBound), Self.bounceRange.upperBound),
                           blur: min(max(blur, Self.blurRange.lowerBound), Self.blurRange.upperBound),
                           contentPace: min(max(contentPace, Self.paceRange.lowerBound), Self.paceRange.upperBound),
                           staged: staged)
    }
}

/// Everything the island's motion needs, resolved from the preferences.
struct IslandMotionSettings: Equatable {
    var preset: IslandMotionPreset
    var values: IslandMotionValues
    /// Every island animation's speed: 0.5 slower, 2 faster.
    var speed: Double

    static let speedRange: ClosedRange<Double> = 0.5...2
    static let standard = IslandMotionSettings(preset: .zenith, values: IslandMotionPreset.zenith.values, speed: 1)

    /// The shape's spring: response shortens with speed, damping falls with bounce.
    var springResponse: Double { 0.46 / speed }
    var springDamping: Double { 1 - 0.45 * values.bounce }
    /// Content arrival, scaled by its own pace and the overall speed.
    var contentDelay: Double { (values.staged ? 0.135 : 0.06) / (speed * values.contentPace) }
    var contentDuration: Double { (values.staged ? 0.07 : 0.32) / (speed * values.contentPace) }

    static func load(from defaults: UserDefaults) -> IslandMotionSettings {
        let preset = IslandMotionPreset(rawValue: defaults.string(forKey: ZenithAppearanceDefaults.motionPreset) ?? "") ?? .zenith
        var values = preset.values
        if preset == .custom {
            if let bounce = defaults.object(forKey: ZenithAppearanceDefaults.motionBounce) as? Double { values.bounce = bounce }
            if let blur = defaults.object(forKey: ZenithAppearanceDefaults.motionBlur) as? Double { values.blur = blur }
            if let pace = defaults.object(forKey: ZenithAppearanceDefaults.motionContentPace) as? Double { values.contentPace = pace }
        }
        let rawSpeed = defaults.object(forKey: ZenithAppearanceDefaults.motionSpeed) as? Double ?? 1
        let speed = rawSpeed.isFinite ? min(max(rawSpeed, speedRange.lowerBound), speedRange.upperBound) : 1
        return IslandMotionSettings(preset: preset, values: values.clamped(), speed: speed)
    }
}

/// What the island is made of.
enum IslandGlassStyle: String, CaseIterable, Identifiable {
    case black, gradient, liquid
    var id: String { rawValue }
}

struct IslandGlassSettings: Equatable {
    var style: IslandGlassStyle
    /// How far down the black melts into glass (gradient style), 0…1.
    var gradientHeight: Double
    /// Darkening over the glass for legibility, 0…1.
    var tint: Double

    static let standard = IslandGlassSettings(style: .black, gradientHeight: 0.6, tint: 0.3)

    static func load(from defaults: UserDefaults) -> IslandGlassSettings {
        func unit(_ key: String, _ fallback: Double) -> Double {
            let value = defaults.object(forKey: key) as? Double ?? fallback
            return value.isFinite ? min(max(value, 0), 1) : fallback
        }
        let style = IslandGlassStyle(rawValue: defaults.string(forKey: ZenithAppearanceDefaults.glassStyle) ?? "") ?? standard.style
        return IslandGlassSettings(style: style,
                                   gradientHeight: unit(ZenithAppearanceDefaults.glassGradientHeight, standard.gradientHeight),
                                   tint: unit(ZenithAppearanceDefaults.glassTint, standard.tint))
    }
}

/// When the island trades its effects for battery.
enum IslandBatterySaver: String, CaseIterable, Identifiable {
    case off, on, automatic
    var id: String { rawValue }

    static func load(from defaults: UserDefaults) -> IslandBatterySaver {
        IslandBatterySaver(rawValue: defaults.string(forKey: ZenithAppearanceDefaults.batterySaver) ?? "") ?? .automatic
    }

    /// Whether to save right now. Automatic saves in Low Power Mode, or on
    /// battery at or under `lowBatteryPercent`.
    func isSaving(lowPowerMode: Bool, onBattery: Bool, batteryPercent: Int?,
                  lowBatteryPercent: Int = 20) -> Bool {
        switch self {
        case .off: return false
        case .on: return true
        case .automatic:
            if lowPowerMode { return true }
            guard onBattery, let percent = batteryPercent else { return false }
            return percent <= lowBatteryPercent
        }
    }
}
