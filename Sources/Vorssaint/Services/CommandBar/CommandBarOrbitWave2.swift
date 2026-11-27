// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: the Command Bar's rows for Orbit wave 2, each only while its
// feature is on: "Remove Background from Clipboard", "Emoji Picker" (when
// it is asked to show here), "Calculator" (when its island page shows) and
// the Calculator's answer for sums the bar's own calculator leaves alone
// (functions such as sin and ln, a factorial). The action rows sit with the
// actions (an `action.` id), so they take aliases, pins and per-row
// shortcuts like any action.

extension CommandBarCatalog {
    static func orbitWave2Entries(_ bar: CommandBarFeatureStrings) -> [CommandBarEntry] {
        var entries: [CommandBarEntry] = []
        if RemoveBackgroundService.isEnabled() {
            let text = ZenithStrings.removeBackground(L10n.shared.language)
            let words = [text.title, text.commandBarRow, "remove background", "cutout", "transparent", "png",
                         "hapus latar", "hapus background", "clipboard"].joined(separator: " ")
            entries.append(CommandBarEntry(id: "action.removeBackground.clipboard", title: text.commandBarRow,
                                           subtitle: text.title, keywords: words,
                                           icon: .symbol("person.and.background.dotted"),
                                           run: { _ in
                                               // A beat, so the bar is gone before the card opens under the pointer.
                                               DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                                   RemoveBackgroundService.shared.runFromClipboard()
                                               }
                                           }))
        }
        if EmojiPickerPreferences().enabled, EmojiPickerPreferences().showInCommandBar {
            let text = ZenithStrings.emojiPicker(L10n.shared.language)
            let words = [text.title, "emoji", "emoticon", "smiley", "pilih emoji"].joined(separator: " ")
            entries.append(CommandBarEntry(id: "action.emojiPicker.open", title: text.title, subtitle: text.searchPlaceholder,
                                           keywords: words, icon: .symbol("face.smiling"),
                                           run: { _ in
                                               DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                                   EmojiPickerService.shared.open()
                                               }
                                           }))
        }
        if CalculatorPreferences.showsInIsland(), NotchSupport.isEnabled() {
            let text = ZenithStrings.calculator(L10n.shared.language)
            let words = [text.title, "calculator", "calc", "kalkulator", "hitung"].joined(separator: " ")
            entries.append(CommandBarEntry(id: "action.calculator.open", title: text.openCalculator,
                                           subtitle: text.openCalculatorSubtitle, keywords: words,
                                           icon: .symbol("plus.forwardslash.minus"),
                                           run: { _ in
                                               DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                                   NotchService.shared.select(.calculator)
                                               }
                                           }))
        }
        return entries
    }

    /// The Calculator's answer, for what the bar's calculator could not
    /// answer. Only for a calculation (an operator, a function), never a lone
    /// number, and never for something that reads as a date or a time.
    static func calculatorAnswerEntry(for query: String, bar: CommandBarFeatureStrings) -> CommandBarEntry? {
        guard CalculatorPreferences.showsInCommandBar() else { return nil }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !CommandBarCalculator.looksLikeDateOrTime(trimmed) else { return nil }
        let service = CalculatorService.shared
        guard case .success(let answer) = service.answer(trimmed), answer.isCalculation else { return nil }
        let display = service.display(answer.value)
        let closed = String(repeating: ")", count: answer.closedBrackets)
        let completed = closed.isEmpty ? "" : trimmed + closed + " · "
        return CommandBarEntry(
            id: "math.zenithCalculator",
            title: display,
            subtitle: completed + bar.copyHint,
            icon: .symbol("plus.forwardslash.minus"),
            isAnswer: true,
            reusableExpression: CalculatorText.copied(answer.value, places: service.preferences.decimalPlaces),
            countsUsage: false,
            run: { _ in
                service.keep(trimmed + closed, value: answer.value)
                service.copy(answer.value) { ok in
                    QuickToolHUD.show(icon: ok ? "doc.on.doc" : "exclamationmark.circle",
                                      message: ok ? display : bar.copyFailed)
                }
            })
    }
}
