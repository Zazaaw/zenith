// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

// Zenith fork: how Zenith's own pages open (General, Appearance, Shortcuts,
// Advanced, About): the page's icon at 50 pt, a bold title and one muted
// line, with an optional control at the trailing edge. Calmer than a
// feature's hero, and what every page without a hero shows.

/// A system page's header.
///
///     ZenithSystemHeader(title: "General", subtitle: "How Zenith starts…")
///     ZenithSystemHeader(title: "Shortcuts", subtitle: "…") { Button("Reset") { … } }
///
/// The icon is the page's own, from Settings; pass `icon:` for another, or
/// `showsIcon: false` for none (a sheet).
struct ZenithSystemHeader<Accessory: View>: View {
    let title: String
    var subtitle: String?
    var icon: SettingsPageIcon?
    var showsIcon = true
    let accessory: Accessory
    @Environment(\.settingsPageIcon) private var pageIcon

    init(title: String, subtitle: String? = nil, icon: SettingsPageIcon? = nil, showsIcon: Bool = true,
         @ViewBuilder accessory: () -> Accessory) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.showsIcon = showsIcon
        self.accessory = accessory()
    }

    static var iconSize: CGFloat { 50 }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            if showsIcon, let shown = icon ?? pageIcon {
                SettingsDestinationIcon(id: shown.id, symbol: shown.symbol, size: Self.iconSize, rich: true)
                    .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-0.6)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            accessory
        }
        .padding(.bottom, 2)
    }
}

extension ZenithSystemHeader where Accessory == EmptyView {
    init(title: String, subtitle: String? = nil, icon: SettingsPageIcon? = nil, showsIcon: Bool = true) {
        self.init(title: title, subtitle: subtitle, icon: icon, showsIcon: showsIcon) { EmptyView() }
    }
}
