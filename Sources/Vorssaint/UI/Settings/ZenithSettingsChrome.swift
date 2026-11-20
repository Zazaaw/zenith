// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: the Settings chrome after p441z.my.id. A large title above
// the upstream form pages, the dot grid showing through and the brand under
// the sidebar. The About page lives in ZenithAboutPage.swift.

/// One Settings page: an optional large title, then the page itself, with the
/// form backgrounds cleared so the dot grid shows through.
struct ZenithSettingsPage<Content: View>: View {
    let title: String?
    let content: Content

    init(title: String?, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                ZenithPageTitle(title: title)
                    .padding(.horizontal, 24)
                    .padding(.top, 22)
                    .padding(.bottom, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .scrollContentBackground(.hidden)
        .headerProminence(.increased)
    }
}

/// The brand under the sidebar: the Satu Visual mark, the app and its version.
struct ZenithSidebarFooter: View {
    var body: some View {
        HStack(spacing: 9) {
            BrandBadge(size: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(AppInfo.name).font(.system(size: 12, weight: .semibold))
                Text("v\(AppInfo.version) · \(AppInfo.maker)")
                    .font(ZenithType.mono(9.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            Rectangle().fill(ZenithSurface.hairline).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Switch row

/// A label at the leading edge and a switch at the trailing one, for rows that
/// carry their own label. The switch is drawn in SwiftUI: AppKit's NSSwitch,
/// when its value changed from elsewhere (another row, the defaults), redrew
/// and laid out the whole window in the middle of SwiftUI's update, which spun
/// Settings in an AttributeGraph cycle.
struct ZenithSwitchRow<Label: View>: View {
    let title: String
    @Binding var isOn: Bool
    let label: Label

    init(_ title: String, isOn: Binding<Bool>, @ViewBuilder label: () -> Label) {
        self.title = title
        _isOn = isOn
        self.label = label()
    }

    var body: some View {
        HStack(spacing: 12) {
            label
            Spacer(minLength: 12)
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(ZenithSwitchStyle())
        }
    }
}

extension View {
    /// Marks a fork section that Settings search lands on (ZenithSettingsSearch).
    /// The landing outline stands `inset` outside the section, so it frames a
    /// group of rows inside a card without touching their text, and the layout
    /// stays as it was.
    func zenithSectionAnchor(_ anchor: SettingsSectionAnchor, cornerRadius: CGFloat = ZenithRadius.card,
                             inset: CGFloat = 8) -> some View {
        padding(inset)
            .settingsSectionAnchor(anchor, cornerRadius: cornerRadius)
            .padding(-inset)
    }
}
