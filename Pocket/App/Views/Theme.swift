// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI
import UIKit

/// The p441z Style Kit, as Pocket uses it: greyscale surfaces, colour only
/// for status, Plus Jakarta Sans (ExtraBold and Medium), mono for metadata.
///
/// Every surface token is a dynamic colour, so a view written once reads
/// right in light and dark; `ThemeChoice` decides which one the app shows.
enum K {
    static let bg = dynamic(light: Color(white: 0.965), dark: Color(white: 0.039))
    static let card = dynamic(light: .white, dark: Color(white: 0.071))
    static let border = dynamic(light: Color(white: 0.89), dark: Color(white: 0.15))
    static let fg = dynamic(light: Color(white: 0.07), dark: Color(white: 0.98))
    static let muted = dynamic(light: Color(white: 0.42), dark: Color(white: 0.64))
    static let faint = dynamic(light: Color(white: 0.56), dark: Color(white: 0.45))
    /// The ink on an `fg` fill: the selected tab, a primary button.
    static let inverse = dynamic(light: .white, dark: .black)
    /// Empty meters and secondary buttons.
    static let track = dynamic(light: Color.black.opacity(0.07), dark: Color.white.opacity(0.10))
    /// The faintest fill: icon tiles, pressed rows.
    static let wash = dynamic(light: Color.black.opacity(0.035), dark: Color.white.opacity(0.04))
    /// The ambient dot grid and line grid.
    static let dot = dynamic(light: Color.black.opacity(0.10), dark: Color.white.opacity(0.22))
    static let gridLine = dynamic(light: Color.black.opacity(0.045), dark: Color.white.opacity(0.07))
    /// The shimmer's travelling highlight.
    static let shine = dynamic(light: Color.white.opacity(0.75), dark: Color.white.opacity(0.10))

    // The status palette (Tailwind 500), the same in both themes.
    static let blue = Color(red: 0.231, green: 0.510, blue: 0.965)
    static let purple = Color(red: 0.659, green: 0.333, blue: 0.969)
    static let amber = Color(red: 0.961, green: 0.620, blue: 0.043)
    static let emerald = Color(red: 0.063, green: 0.725, blue: 0.506)
    static let red = Color(red: 0.937, green: 0.267, blue: 0.267)

    static func sans(_ size: CGFloat, bold: Bool = false) -> Font {
        .custom(bold ? "PlusJakartaSans-ExtraBold" : "PlusJakartaSans-Medium", size: size)
    }

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// A tone's colour where it marks a value (the hero, a percentage).
    static func color(_ tone: PocketTone) -> Color {
        switch tone {
        case .plain: return fg
        case .quiet: return muted
        case .good: return emerald
        case .info: return blue
        case .attention: return amber
        case .alert: return red
        case .progress: return purple
        }
    }

    /// One colour per appearance, resolved by UIKit wherever it is drawn.
    static func dynamic(light: Color, dark: Color) -> Color {
        let light = UIColor(light), dark = UIColor(dark)
        return Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

/// The appearance picked in Settings. System follows the iPhone.
enum ThemeChoice: String, CaseIterable, Identifiable {
    case system, light, dark

    /// Where the choice is kept (`@AppStorage`).
    static let key = "pocket.theme"

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var scheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// A card: in light, a white surface lifted by two soft shadows (a wide
/// ambient one and a close contact one) with a near-invisible edge; in dark,
/// the hairline does the lifting, since shadows vanish on near-black.
struct Surface: ViewModifier {
    var radius: CGFloat = 20
    var tint: Color?
    var fill: Color = K.card
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let dark = scheme == .dark
        content
            .background {
                shape.fill(fill)
                    .shadow(color: .black.opacity(dark ? 0 : 0.05), radius: 22, y: 12)
                    .shadow(color: .black.opacity(dark ? 0 : 0.035), radius: 2, y: 1)
            }
            .overlay(shape.strokeBorder(tint.map { $0.opacity(0.30) } ?? (dark ? K.border : Color.black.opacity(0.04)), lineWidth: 1))
    }
}

extension View {
    /// See `Surface`.
    func surface(radius: CGFloat = 20, tint: Color? = nil, fill: Color = K.card) -> some View {
        modifier(Surface(radius: radius, tint: tint, fill: fill))
    }
}
