// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Zenith fork: a kit row recording a feature's own global shortcut, stored
/// as `GlobalShortcut.storageValue` under `storageKey` ("" for none, absent
/// for `fallback`), as Translate's and Mechakey's are. `sync` registers the
/// new combination; `conflict` names who already answers to one.
struct ZenithShortcutSettingRow: View {
    let title: String
    let info: String?
    let storageKey: String
    let fallback: GlobalShortcut
    let refused: Bool
    let conflict: (GlobalShortcut) -> String?
    let sync: () -> Void

    @AppStorage private var stored: String
    @ObservedObject private var l10n = L10n.shared
    @State private var message: String?

    init(_ title: String, info: String? = nil, storageKey: String, fallback: GlobalShortcut, refused: Bool,
         conflict: @escaping (GlobalShortcut) -> String?, sync: @escaping () -> Void) {
        self.title = title
        self.info = info
        self.storageKey = storageKey
        self.fallback = fallback
        self.refused = refused
        self.conflict = conflict
        self.sync = sync
        _stored = AppStorage(wrappedValue: fallback.storageValue, storageKey)
    }

    var body: some View {
        let s = l10n.s
        let warning = message ?? (refused ? s.shortcutNotCaptured : nil)
        return ZenithRow(title, info: info, warning: warning, shortcut: {
            ShortcutRecorderButton(
                shortcut: GlobalShortcut(storageValue: stored) ?? fallback,
                isEnabled: true,
                waitingTitle: s.shortcutPressKeys,
                emptyTitle: stored.isEmpty ? s.shortcutNone : nil,
                clearAction: {
                    message = nil
                    stored = ""
                    sync()
                },
                notCapturedAction: { message = s.shortcutNotCaptured },
                recordingChanged: { recording in if recording { message = nil } },
                invalidAction: { message = s.shortcutInvalid },
                captureAction: { captured in
                    if let owner = conflict(captured) {
                        message = s.shortcutConflictFormat.replacingOccurrences(of: "%@", with: owner)
                        return
                    }
                    message = nil
                    stored = captured.storageValue
                    sync()
                }
            )
        })
    }
}
