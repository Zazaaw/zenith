// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import Foundation

// Zenith fork: the QR codes in the Command Bar: a code of the clipboard, a
// new one, and scanning one on the screen while the screen text tool is
// installed. The rows sit with the actions (an `action.` id), so they take
// aliases, pins and the bar's own per-row shortcuts like any action.

extension CommandBarCatalog {
    static func qrEntries(_ bar: CommandBarFeatureStrings) -> [CommandBarEntry] {
        let text = ZenithStrings.qr(L10n.shared.language)
        let english = ZenithStrings.qr(.enUS)
        let words = [text.title, english.title, "QR", "qrcode", text.kindWiFi, text.kindWhatsApp, text.kindContact]
            .joined(separator: " ")
        // A beat after Return, so the bar is gone before the page or the
        // capture chooser comes up.
        func later(_ action: @escaping () -> Void) -> (Int?) -> Void {
            { _ in DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: action) }
        }
        var entries = [
            CommandBarEntry(id: "action.qr.clipboard", title: text.fromClipboard, subtitle: text.title,
                            keywords: words + " " + english.fromClipboard, icon: .symbol("qrcode"),
                            shortcut: GlobalShortcutRole.zenithQR.assignedShortcut(),
                            run: later { QRService.shared.showClipboard() }),
            CommandBarEntry(id: "action.qr.new", title: text.newCode, subtitle: text.title,
                            keywords: words + " " + english.newCode, icon: .symbol("qrcode"),
                            run: later { QRService.shared.newCode() }),
        ]
        if QRService.shared.canScan {
            entries.append(CommandBarEntry(id: "action.qr.scan", title: text.scan, subtitle: text.title,
                                           keywords: words + " " + english.scan, icon: .symbol("qrcode.viewfinder"),
                                           shortcut: GlobalShortcutRole.zenithQRScan.assignedShortcut(),
                                           run: later { QRService.shared.scanScreen() }))
        }
        return entries
    }
}
