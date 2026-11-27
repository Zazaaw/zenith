// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// One rounded group of related controls on a redesigned Settings page, with
/// an optional heading. Zenith fork: drawn as the kit's section (the title
/// outside, a quiet grouped card, compact rows; see `ZenithSection`), so
/// every page that uses it takes the new look.
struct SettingsCard<Content: View>: View {
    let title: String?
    let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title { ZenithSectionTitle(title) }
            VStack(alignment: .leading, spacing: 9) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, ZenithKitSurface.rowInset)
            .padding(.vertical, 11)
            .zenithGroupBackground()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// How every redesigned Settings page opens: a bold title and one muted line
/// on what the page is for, with an optional control at the trailing edge.
/// Zenith fork: drawn as the kit's `ZenithSystemHeader`.
struct SettingsPageHeader<Accessory: View>: View {
    let title: String
    let subtitle: String
    let accessory: Accessory

    init(title: String, subtitle: String, @ViewBuilder accessory: () -> Accessory) {
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory()
    }

    init(title: String, subtitle: String) where Accessory == EmptyView {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }

    var body: some View {
        ZenithSystemHeader(title: title, subtitle: subtitle) { accessory }
            .padding(.bottom, 4)
    }
}

/// Zenith fork: a page's title and its muted line, shared by the redesigned
/// pages and the header Settings puts above the upstream form pages. Drawn
/// as the kit's `ZenithSystemHeader`, with the open page's icon.
struct ZenithPageTitle: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        ZenithSystemHeader(title: title, subtitle: subtitle)
    }
}

/// Where a row's text column starts, so follow-up controls can line up with
/// it. Zenith fork: rows have no icon tile any more, so it is the row's edge.
let settingsRowTextInset: CGFloat = 0

/// A title, its explanation and the control on the right. Zenith fork: drawn
/// as the kit's row: no icon tile (`symbol` is kept for the callers and
/// ignored), and the caption becomes an ⓘ beside the title unless it is
/// `essential` (a permission, a warning), which stays under the title.
struct SettingsRow<Accessory: View>: View {
    let symbol: String?
    let title: String
    let badge: String?
    let caption: String?
    let essential: Bool
    let accessory: Accessory

    init(symbol: String?, title: String, badge: String? = nil, caption: String? = nil, essential: Bool = false,
         @ViewBuilder accessory: () -> Accessory) {
        self.symbol = symbol
        self.title = title
        self.badge = badge
        self.caption = caption
        self.essential = essential
        self.accessory = accessory()
    }

    var body: some View {
        let shown = ZenithCaptionRule.presentation(caption: caption, essential: essential)
        HStack(spacing: 12) {
            ZenithRowLabel(title: title, info: shown.info, essential: shown.inline, badge: badge)
            Spacer(minLength: 12)
            accessory
        }
        .frame(minHeight: 26)
    }
}

/// A switch for an option that needs another feature. While it cannot be
/// used, its feature uninstalled or something else ruling it out, the option
/// reads greyed and off, since a disabled switch looks like one that is just
/// off, and a readable line under it says why.
struct SettingsFeatureSwitchRow: View {
    let symbol: String
    let title: String
    var caption: String? = nil
    @Binding var isOn: Bool
    let feature: AppFeature
    /// False while something else rules the option out, as the caption says.
    var enabled = true
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared

    var body: some View {
        let installed = features.isAvailable(feature)
        let usable = installed && enabled
        VStack(alignment: .leading, spacing: 6) {
            SettingsRow(symbol: symbol, title: title, caption: usable ? caption : nil) {
                Toggle(title, isOn: usable ? $isOn : .constant(false)).labelsHidden().toggleStyle(.switch)
            }
            .disabled(!usable)
            .saturation(usable ? 1 : 0)
            .opacity(usable ? 1 : 0.45)
            if !installed {
                HStack(spacing: 10) {
                    Text(feature.enableReason(l10n))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(FeatureStrings.notchEditor(l10n.language).openFeatures) { feature.showInFeatures() }
                        .controlSize(.small)
                }
                .padding(.leading, settingsRowTextInset)
            } else if !usable, let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, settingsRowTextInset)
            }
        }
    }
}

/// A row that picks one of a few options: segments beside the title while the
/// row fits on one line, under the title otherwise, and a menu there when the
/// segments don't fit either. A row wider than its column would center the page
/// and cut it on both sides.
struct SettingsChoiceRow<Value: Hashable, Options: View>: View {
    let symbol: String?
    let title: String
    @Binding var selection: Value
    let options: Options

    init(symbol: String?, title: String, selection: Binding<Value>, @ViewBuilder options: () -> Options) {
        self.symbol = symbol
        self.title = title
        _selection = selection
        self.options = options()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            SettingsRow(symbol: symbol, title: title) {
                picker.pickerStyle(.segmented).fixedSize()
            }
            VStack(alignment: .leading, spacing: 8) {
                SettingsRow(symbol: symbol, title: title) { EmptyView() }
                ViewThatFits(in: .horizontal) {
                    picker.pickerStyle(.segmented).fixedSize()
                    picker.pickerStyle(.menu).fixedSize()
                }
                .padding(.leading, settingsRowTextInset)
            }
        }
    }

    private var picker: some View {
        Picker(title, selection: $selection) { options }.labelsHidden()
    }
}

/// A row whose choice is a menu: beside the title while the row fits on one
/// line, under the title otherwise, lined up with its text, or with its icon
/// when the menu is wider than the text leaves room for. A menu kept beside a
/// title that has to wrap squeezes the title letter by letter, and a row
/// wider than its column would center the page and cut it on both sides.
struct SettingsMenuRow<Value: Hashable, Options: View>: View {
    let symbol: String?
    let title: String
    @Binding var selection: Value
    let options: Options

    init(symbol: String?, title: String, selection: Binding<Value>, @ViewBuilder options: () -> Options) {
        self.symbol = symbol
        self.title = title
        _selection = selection
        self.options = options()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            SettingsRow(symbol: symbol, title: title) { menu }
            VStack(alignment: .leading, spacing: 8) {
                SettingsRow(symbol: symbol, title: title) { EmptyView() }
                // Only the menu's width decides here: a title too long for one
                // line wraps above it either way.
                ViewThatFits(in: .horizontal) {
                    menu.padding(.leading, settingsRowTextInset)
                    menu
                }
            }
        }
    }

    private var menu: some View {
        Picker(title, selection: $selection) { options }.pickerStyle(.menu).labelsHidden().fixedSize()
    }
}

/// A switch pushed to the trailing edge with its label at the leading one,
/// so a shared control that carries its own label lines up with the rows
/// around it on a redesigned page.
struct TrailingSwitchToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.label
            Spacer(minLength: 12)
            Toggle(isOn: configuration.$isOn) { EmptyView() }
                .labelsHidden()
                .toggleStyle(ZenithSwitchStyle())
        }
    }
}
