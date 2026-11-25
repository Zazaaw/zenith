// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Zenith fork: the Mac tab's two switches, at the end of the iPhone & Watch
/// page's Sharing card: sharing the clipboard, and letting the phone quit
/// apps. Both off until the person turns them on. Each row brings the
/// hairline above it, so the page adds them with a single line.
struct PocketMacSettingsRows: View {
    @AppStorage(PocketDefaults.shareClipboard) private var shareClipboard = false
    @AppStorage(PocketDefaults.allowQuit) private var allowQuit = false

    private let text = ZenithStrings.pocketMac(.enUS)

    var body: some View {
        Group {
            divider
            row(text.shareClipboard, caption: text.shareClipboardCaption, isOn: $shareClipboard)
            divider
            row(text.allowQuit, caption: text.allowQuitCaption, isOn: $allowQuit)
        }
    }

    private var divider: some View {
        Rectangle().fill(ZenithSurface.hairline).frame(height: 1).padding(.horizontal, 16)
    }

    private func row(_ title: String, caption: String, isOn: Binding<Bool>) -> some View {
        ZenithSwitchRow(title, isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(ZenithType.rowTitle)
                Text(caption)
                    .font(ZenithType.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
