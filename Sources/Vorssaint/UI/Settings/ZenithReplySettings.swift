// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Zenith fork: the switch for typing WhatsApp replies into WhatsApp, under
/// the island's Notifications settings. It drives WhatsApp's own window, so
/// its caption says it can break with a WhatsApp update.
struct ZenithReplySettings: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchWhatsAppAutoReply) private var automatic = true

    var body: some View {
        let text = ZenithStrings.reply(l10n.language)
        ZenithSwitchRow(text.autoWhatsApp, isOn: $automatic) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "arrowshape.turn.up.left")
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(text.autoWhatsApp)
                    Text(text.autoWhatsAppCaption).font(ZenithType.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
