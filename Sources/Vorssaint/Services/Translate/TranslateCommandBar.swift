// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: "Translate Clipboard" in the Command Bar, while Translate is
// on. The row sits with the actions (an `action.` id), so it takes aliases,
// pins and the bar's own per-row shortcuts like any action.

extension CommandBarCatalog {
    static func translateEntries(_ bar: CommandBarFeatureStrings) -> [CommandBarEntry] {
        guard TranslateService.isEnabled() else { return [] }
        let text = ZenithStrings.translate(L10n.shared.language)
        let words = [text.title, text.translateClipboard, "translate", "terjemah", "terjemahkan", "terjemahan",
                     "clipboard", "papan klip"].joined(separator: " ")
        return [
            CommandBarEntry(id: "action.translate.clipboard", title: text.translateClipboard, subtitle: text.title,
                            keywords: words, icon: .symbol("translate"),
                            run: { _ in
                                // A beat, so the bar is gone before the card opens under the pointer.
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    TranslateService.shared.translateClipboard()
                                }
                            }),
        ]
    }
}
