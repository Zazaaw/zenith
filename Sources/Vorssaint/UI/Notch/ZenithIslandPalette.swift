// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

// Zenith fork: the island is colourful now. Each module wears an identity
// colour on its glyph, over a soft tile of the same hue (`ZenithIslandGlyphTile`).
// The rule that colour only carries meaning still holds for data and status
// (`ZenithStatus`); a module's colour is identity, so it never stands for a
// state, and it is always shown with the module's glyph and name.
//
// The hues are the 400 steps of a common open palette, chosen to read on the
// island's black and on the translucent grey of a glass island, spread around
// the wheel so neighbours in the gallery tell apart. Timer keeps the purple
// it has worn since the status palette; Vercel and GitHub keep their brands'
// greys.
//
// The test executable compiles this file (build.sh, TEST_SOURCES): keep it
// free of anything outside SwiftUI and `NotchModule`.

enum ZenithIslandPalette {
    /// sRGB 0xRRGGBB for each module.
    static func hex(_ module: NotchModule) -> UInt32 {
        switch module {
        case .controls: return 0x60A5FA      // blue
        case .mixer: return 0x818CF8         // indigo
        case .music: return 0xFB7185         // rose
        case .clipboard: return 0xA78BFA     // violet
        case .captures: return 0x22D3EE      // cyan
        case .files: return 0x2DD4BF         // teal
        case .system: return 0x4ADE80        // green
        case .tools: return 0xE879F9         // fuchsia
        case .calendar: return 0xF87171      // red
        case .notifications: return 0xFBBF24 // amber
        case .timer: return 0xC084FC         // purple
        case .camera: return 0x34D399        // emerald
        case .downloads: return 0x38BDF8     // sky
        case .scratchpad: return 0xFACC15    // yellow
        case .agents: return 0xFB923C        // orange
        case .watch: return 0xA3E635         // lime
        case .wakatime: return 0xF472B6      // pink
        case .vercel: return 0xE5E7EB        // neutral
        case .github: return 0xCBD5E1        // slate
        case .cardImport: return 0xFDBA74    // peach, the warm 300 step: the wheel's 400s are all taken
        }
    }

    static func color(_ module: NotchModule) -> Color {
        let value = hex(module)
        return Color(.sRGB, red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255,
                     blue: Double(value & 0xFF) / 255, opacity: 1)
    }
}

extension NotchModule {
    /// The module's identity colour in the island.
    var zenithTint: Color { ZenithIslandPalette.color(self) }
}
