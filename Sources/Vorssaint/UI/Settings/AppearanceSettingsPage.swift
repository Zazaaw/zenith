// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

/// Zenith fork: Settings → Appearance, the tile beside General. A placeholder
/// for now: how the island moves, what it is made of and how much power it
/// may spend arrive in a later step.
struct AppearanceSettingsPage: View {
    private let text = ZenithStrings.appearancePage(.enUS)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsPageHeader(title: text.title, subtitle: text.subtitle)
                SettingsCard {
                    Text(text.comingSoon)
                        .font(ZenithType.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
    }
}
