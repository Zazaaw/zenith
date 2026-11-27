// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Zenith fork: the Mac tab's two switches, under More options in the iPhone &
/// Watch page's Sharing section: sharing the clipboard, and letting the phone
/// quit apps. Both off until the person turns them on. Two kit rows with the
/// hairline between them, so the page adds them with a single line.
struct PocketMacSettingsRows: View {
    @AppStorage(PocketDefaults.shareClipboard) private var shareClipboard = false
    @AppStorage(PocketDefaults.allowQuit) private var allowQuit = false

    private let text = ZenithStrings.pocketMac(.enUS)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            row(text.shareClipboard, caption: text.shareClipboardCaption, isOn: $shareClipboard)
            ZenithRowSeparator()
            row(text.allowQuit, caption: text.allowQuitCaption, isOn: $allowQuit)
        }
        .zenithFullBleed()
    }

    private func row(_ title: String, caption: String, isOn: Binding<Bool>) -> some View {
        ZenithRow(title, isOn: isOn, info: caption)
            .padding(.horizontal, ZenithKitSurface.rowInset)
            .frame(maxWidth: .infinity, minHeight: ZenithKitSurface.rowHeight, alignment: .leading)
    }
}
