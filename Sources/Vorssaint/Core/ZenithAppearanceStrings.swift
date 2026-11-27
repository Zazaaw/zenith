// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: Settings → Appearance, the tile beside General. English in
// every language, like Zenith's other pages; the Theme section keeps the
// localized words it had on General (AppearanceStrings, GeneralSettingsStrings).

struct ZenithAppearanceStrings {
    let title = "Appearance"
    let subtitle = "How the island moves, what it is made of, and how much power it may spend."

    // Theme
    let theme = "Theme"

    // Motion
    let motion = "Motion"
    let bounce = "Bounce"
    let bounceCaption = "How far the island overshoots before it settles."
    let blur = "Blur"
    let blurCaption = "How soft content looks while it arrives and leaves."
    let contentPace = "Content pace"
    let contentPaceCaption = "How soon content appears as the shape opens."
    let speed = "Speed"
    let speedCaption = "Every island animation, from opening to page changes."
    let customNote = "Moving Bounce, Blur or Content pace switches to Custom. Speed applies to every style."
    let reduceMotionNote = "Reduce Motion is respected: when it is on in System Settings, the island fades instead of morphing and these previews stand still."
    let reduceMotionOn = "Reduce Motion is on, so the island fades instead of morphing."

    func preset(_ preset: IslandMotionPreset) -> String {
        switch preset {
        case .zenith: return "Zenith"
        case .snappy: return "Snappy"
        case .calm: return "Calm"
        case .playful: return "Playful"
        case .custom: return "Custom"
        }
    }

    func presetCaption(_ preset: IslandMotionPreset) -> String {
        switch preset {
        case .zenith: return "A springy morph that lands with a little bounce."
        case .snappy: return "The shape grows first, then the content fades in sharp."
        case .calm: return "Slow and soft, with a long blur and barely a bounce."
        case .playful: return "A rubbery bounce, with content that pops in quickly."
        case .custom: return "Your own bounce, blur and content pace."
        }
    }

    // Glass
    let glass = "Glass"
    let glassCaption = "What the open island is made of. Text keeps a dark backing in every style."
    let gradientHeight = "Gradient height"
    let gradientHeightCaption = "How far down the black melts into glass."
    let tint = "Tint"
    let tintCaption = "Darkens the glass so text stays readable on bright wallpapers."
    let liquidNeedsMacOS26 = "Liquid Glass needs macOS 26. Until then the island uses Gradient."
    let reduceTransparencyOn = "Reduce Transparency is on, so the island stays black."

    func glassStyle(_ style: IslandGlassStyle) -> String {
        switch style {
        case .black: return "Black"
        case .gradient: return "Gradient"
        case .liquid: return "Liquid Glass"
        }
    }

    // Battery
    let battery = "Battery"
    let saveBattery = "Save battery with lighter visuals"
    let saveBatteryCaption = "Plain fades, no live visualizer, island timers sleep. Automatic saves in Low Power Mode, or on battery at 20% or less."
    let savingNow = "Saving now"

    func batterySaver(_ saver: IslandBatterySaver) -> String {
        switch saver {
        case .off: return "Off"
        case .on: return "On"
        case .automatic: return "Automatic"
        }
    }

    // Values beside the sliders.
    func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }
    func points(_ value: Double) -> String { value.rounded() == value ? "\(Int(value)) pt" : String(format: "%.1f pt", value) }
    /// 1.0×, 1.2×, 1.25×: at least one decimal, at most two.
    func times(_ value: Double) -> String {
        var digits = String(format: "%.2f", value)
        if digits.hasSuffix("0") { digits.removeLast() }
        return digits + "×"
    }
}

extension ZenithStrings {
    /// English in every language (see the file's note).
    static func appearancePage(_ language: AppLanguage) -> ZenithAppearanceStrings {
        ZenithAppearanceStrings()
    }
}

/// Settings search words for Appearance that its labels do not use: English
/// synonyms and the Indonesian words its owner types.
enum AppearanceSearch {
    static let aliases = ["appearance", "look", "style", "tampilan", "gaya", "penampilan"]
    static let theme = ["theme", "dark mode", "light mode", "night mode", "tema", "mode gelap", "mode terang",
                        "tema gelap", "tema terang", "gelap", "terang"]
    static let motion = ["animation", "animations", "spring", "transition", "animasi", "gerak", "gerakan",
                         "kecepatan", "mantul", "pegas", "transisi", "Reduce Motion", "kurangi gerakan"]
    static let glass = ["Liquid Glass", "glass", "translucent", "transparent", "blur", "kaca", "kaca cair",
                        "transparan", "tembus pandang", "gradasi", "hitam", "warna island"]
    static let battery = ["battery saver", "low power", "Low Power Mode", "power saving", "hemat baterai",
                          "hemat daya", "mode hemat daya", "irit baterai"]
}
