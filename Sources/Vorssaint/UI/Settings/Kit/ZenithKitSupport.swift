// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: the Settings kit's decisions, kept out of its views so the
// `settings-kit` test suite can pin them: the category tints, which caption
// shows inline and which becomes an ⓘ, when "More options" is open, and when
// the hero may move. See docs/SETTINGS-KIT.md.

// MARK: - Category tints

/// An sRGB colour as numbers, so tints can be mixed and tested.
struct ZenithRGB: Equatable {
    let red: Double
    let green: Double
    let blue: Double

    init(_ red: Double, _ green: Double, _ blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    var color: Color { Color(.sRGB, red: red, green: green, blue: blue) }

    /// `self` moved `amount` (0…1) of the way to `other`.
    func mixed(with other: ZenithRGB, _ amount: Double) -> ZenithRGB {
        let t = min(max(amount, 0), 1)
        return ZenithRGB(red + (other.red - red) * t, green + (other.green - green) * t, blue + (other.blue - blue) * t)
    }

    /// Relative luminance (WCAG), for the contrast checks in the tests.
    var luminance: Double {
        func channel(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    static let white = ZenithRGB(1, 1, 1)
    static let night = ZenithRGB(0.09, 0.09, 0.17)
}

/// A sidebar group's colours, used by the hero's aura and label, the stage
/// behind previews, the visual picker's tiles and the sidebar's fallback icons.
/// One table: `ZenithCategoryTint.of(_:)`.
struct ZenithCategoryTint: Equatable {
    /// The light end of the pair: the aura's core and the label in Dark Mode.
    let light: ZenithRGB
    /// The deep end: the aura's rim, the hero's wash and the label in Light Mode.
    let deep: ZenithRGB
    /// The stage gradient in Dark Mode, top leading to bottom trailing.
    let stage: [ZenithRGB]

    /// The pair as colours, light first.
    var colors: [Color] { [light.color, deep.color] }

    /// The stage in Light Mode: pastels of the pair, so it reads as a soft
    /// tint behind dark content.
    let lightStage: [ZenithRGB]

    func stageStops(dark: Bool) -> [ZenithRGB] { dark ? stage : lightStage }

    func stageColors(dark: Bool) -> [Color] { stageStops(dark: dark).map(\.color) }

    /// The category label's colour: the light end on dark, the deep end
    /// pulled towards black on light, so small caps stay readable.
    func label(dark: Bool) -> ZenithRGB {
        dark ? light : deep.mixed(with: ZenithRGB(0, 0, 0), 0.25)
    }

    /// A stage built from a pair: night into the deep tint, then a little
    /// towards the light one. Kept soft: the stage frames what it holds.
    private static func pair(_ light: ZenithRGB, _ deep: ZenithRGB) -> ZenithCategoryTint {
        ZenithCategoryTint(light: light, deep: deep,
                           stage: [ZenithRGB.night.mixed(with: deep, 0.3),
                                   ZenithRGB.night.mixed(with: deep, 0.48),
                                   deep.mixed(with: light, 0.35).mixed(with: .night, 0.4)],
                           lightStage: [deep.mixed(with: .white, 0.8),
                                        deep.mixed(with: .white, 0.72),
                                        light.mixed(with: .white, 0.6)])
    }

    /// Zenith's own pages (the tiles and the app's pages): indigo into coral,
    /// the stage of the approved General mockup.
    static let zenith: ZenithCategoryTint = {
        let stage = [ZenithRGB(0.20, 0.22, 0.52), ZenithRGB(0.42, 0.27, 0.62), ZenithRGB(0.86, 0.50, 0.48)]
        return ZenithCategoryTint(light: ZenithRGB(0.62, 0.62, 1), deep: ZenithRGB(0.42, 0.27, 0.62),
                                  stage: stage, lightStage: stage.map { $0.mixed(with: .white, 0.7) })
    }()

    static func of(_ group: SettingsSidebarGroup) -> ZenithCategoryTint {
        switch group {
        case .tiles, .zenith: return zenith
        case .island: return pair(ZenithRGB(0.62, 0.6, 1), ZenithRGB(0.38, 0.3, 0.95))
        case .everyday: return pair(ZenithRGB(0.4, 0.7, 1), ZenithRGB(0.12, 0.38, 0.92))
        case .capture: return pair(ZenithRGB(0.4, 0.88, 1), ZenithRGB(0.08, 0.55, 0.85))
        case .windows: return pair(ZenithRGB(0.72, 0.55, 1), ZenithRGB(0.42, 0.3, 0.95))
        case .input: return pair(ZenithRGB(1, 0.85, 0.35), ZenithRGB(1, 0.58, 0.1))
        case .sound: return pair(ZenithRGB(1, 0.5, 0.7), ZenithRGB(0.92, 0.2, 0.45))
        case .system: return pair(ZenithRGB(0.45, 0.95, 0.6), ZenithRGB(0.1, 0.65, 0.4))
        case .apps: return pair(ZenithRGB(1, 0.7, 0.4), ZenithRGB(0.95, 0.42, 0.15))
        case .devices: return pair(ZenithRGB(0.3, 0.92, 0.8), ZenithRGB(0.1, 0.5, 0.75))
        // Zenith fork: Privacy, a calm steel blue.
        case .privacy: return pair(ZenithRGB(0.62, 0.74, 1), ZenithRGB(0.32, 0.36, 0.78))
        // The hero mockup's amber for the features that came from Orbit.
        case .fromOrbit: return pair(ZenithRGB(1, 0.72, 0.25), ZenithRGB(0.95, 0.45, 0.2))
        }
    }

    /// The tint of the page a sidebar destination opens.
    static func of(_ id: SettingsSidebarItem.ID) -> ZenithCategoryTint { of(SettingsSidebarGroup.of(id)) }
}

extension SettingsSidebarGroup {
    /// The category label a hero shows above its title.
    var categoryLabel: String {
        switch self {
        case .tiles, .zenith: return "Zenith"
        default: return title
        }
    }
}

// MARK: - Captions

/// Where a row's explanation goes. Explanations become an ⓘ beside the title
/// (hover or click shows them); only an essential line, one the person must
/// read before using the row (a permission, a warning, why it is off), stays
/// under the title.
enum ZenithCaptionRule {
    struct Presentation: Equatable {
        /// Shown under the title.
        var inline: String?
        /// Behind the ⓘ.
        var info: String?
    }

    /// For a row with an `info` text and an `essential` line.
    static func presentation(info: String?, essential: String?) -> Presentation {
        Presentation(inline: cleaned(essential), info: cleaned(info))
    }

    /// For an old-style row with one caption, marked essential or not.
    static func presentation(caption: String?, essential: Bool) -> Presentation {
        essential ? presentation(info: nil, essential: caption) : presentation(info: caption, essential: nil)
    }

    private static func cleaned(_ text: String?) -> String? {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return text
    }
}

// MARK: - More options

/// "More options" folds a page's advanced rows away. It starts folded, each
/// page remembers whether it was opened, and it opens itself when Settings
/// search lands on a section inside it.
enum ZenithMoreOptionsRule {
    static func key(_ id: String) -> String { "zenithMoreOptions.\(id)" }

    /// Whether a search landing on `target` opens the fold holding `inside`.
    static func opensForSearch(target: SettingsSectionAnchor?, inside: Set<SettingsSectionAnchor>) -> Bool {
        guard let target else { return false }
        return inside.contains(target)
    }

    /// Whether the fold is open: remembered open, or opened for a landing.
    static func isOpen(remembered: Bool, openedForSearch: Bool) -> Bool { remembered || openedForSearch }
}

// MARK: - Hero motion

/// When the hero and other kit art move. Only while the page is shown and
/// the window is on screen and not covered, and never under Reduce Motion
/// or while Appearance's battery saver is saving; otherwise a still frame.
enum ZenithKitMotionRule {
    static func animates(pageShown: Bool, windowVisible: Bool, reduceMotion: Bool, savingBattery: Bool) -> Bool {
        pageShown && windowVisible && !reduceMotion && !savingBattery
    }

    /// The moment the still frame shows: past every animation's entrance,
    /// with stars and rings partly lit (the approved still mockup).
    static let stillTime: Double = 1.1
}

// MARK: - Text

/// The kit's own words. English in every language, like the rest of Zenith's pages.
enum ZenithKitStrings {
    static let moreOptions = "More options"
    static let on = "On"
    static let off = "Off"
    static func info(_ title: String) -> String { "About \(title)" }
}
