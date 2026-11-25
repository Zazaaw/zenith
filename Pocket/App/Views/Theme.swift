// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import PocketKit
import SwiftUI

/// The p441z Style Kit, as Pocket uses it: near-black greyscale surfaces,
/// colour only for status, Plus Jakarta Sans (ExtraBold and Medium), mono
/// for metadata.
enum K {
    static let bg = Color(white: 0.039)
    static let card = Color(white: 0.071)
    static let border = Color(white: 0.15)
    static let fg = Color(white: 0.98)
    static let muted = Color(white: 0.64)
    static let faint = Color(white: 0.45)

    // The status palette (Tailwind 500).
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
}
