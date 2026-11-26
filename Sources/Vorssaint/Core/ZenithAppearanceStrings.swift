// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: Settings → Appearance, the tile beside General. English in
// every language, like Zenith's other pages. A placeholder until the page's
// motion, glass and battery choices arrive.

struct ZenithAppearanceStrings {
    let title = "Appearance"
    let subtitle = "How the island moves, what it is made of, and how much power it may spend."
    let comingSoon = "Coming soon. Motion, glass and battery choices for the island will live here."
}

extension ZenithStrings {
    /// English in every language (see the file's note).
    static func appearancePage(_ language: AppLanguage) -> ZenithAppearanceStrings {
        ZenithAppearanceStrings()
    }
}
