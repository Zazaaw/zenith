// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// One rounded group of related controls on a redesigned Settings page, with
/// an optional heading. The same card the Dynamic Island page draws, so the
/// pages read as one design.
struct SettingsCard<Content: View>: View {
    let title: String?
    let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    // Zenith fork: the heading sits above the card, bold and tightly tracked,
    // and the card is a hairline over the faintest lift (p441z.my.id).
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(ZenithType.sectionTitle)
                    .tracking(ZenithType.sectionTitleTracking)
                    .padding(.leading, 2)
                    .accessibilityAddTraits(.isHeader)
            }
            VStack(alignment: .leading, spacing: 13) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(ZenithSurface.cardFill, in: RoundedRectangle(cornerRadius: ZenithRadius.panel, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: ZenithRadius.panel, style: .continuous)
                .strokeBorder(ZenithSurface.hairline))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// How every redesigned Settings page opens: a bold title and one muted line
/// on what the page is for, with an optional control at the trailing edge.
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

    // Zenith fork: the large, tightly tracked title of p441z.my.id.
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZenithPageTitle(title: title, subtitle: subtitle)
                .frame(maxWidth: .infinity, alignment: .leading)
            accessory
        }
        .padding(.bottom, 6)
    }
}

/// Zenith fork: a page's title and its muted line, shared by the redesigned
/// pages and the header Settings puts above the upstream form pages.
struct ZenithPageTitle: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(ZenithType.pageTitle)
                .tracking(ZenithType.pageTitleTracking)
                .accessibilityAddTraits(.isHeader)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(ZenithType.pageSubtitle)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Where a row's text column starts, so follow-up controls can line up with it.
let settingsRowTextInset: CGFloat = 30 + 12 // Zenith fork: 30 pt tiles

/// Icon, title, one line of explanation and the control on the right. A nil
/// symbol shows the app's own menu bar glyph, for rows about that icon.
struct SettingsRow<Accessory: View>: View {
    let symbol: String?
    let title: String
    let badge: String?
    let caption: String?
    let accessory: Accessory

    init(symbol: String?, title: String, badge: String? = nil, caption: String? = nil,
         @ViewBuilder accessory: () -> Accessory) {
        self.symbol = symbol
        self.title = title
        self.badge = badge
        self.caption = caption
        self.accessory = accessory()
    }

    var body: some View {
        HStack(spacing: 12) {
            iconTile
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title).font(ZenithType.rowTitle) // Zenith fork
                    if let badge {
                        // Zenith fork: a mono tag in the Style Kit's 10% / 20% / 100% form.
                        Text(badge.uppercased())
                            .font(ZenithType.mono(8.5, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(ZenithStatus.fill(Color.accentColor), in: Capsule())
                            .overlay(Capsule().strokeBorder(ZenithStatus.stroke(Color.accentColor)))
                            .accessibilityHidden(true)
                    }
                }
                if let caption {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            accessory
        }
    }

    @ViewBuilder
    private var iconTile: some View {
        // Zenith fork: monochrome glyphs on a grey tile with a hairline, as the
        // logo tiles on p441z.my.id; colour stays for meaning.
        if let symbol {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary.opacity(0.85))
                .frame(width: 30, height: 30)
                .background(ZenithSurface.tileFill,
                            in: RoundedRectangle(cornerRadius: ZenithRadius.large, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: ZenithRadius.large, style: .continuous)
                    .strokeBorder(ZenithSurface.tileStroke))
        } else {
            // The menu bar draws the glyph white on a dark bar; the badge keeps
            // that pairing so it reads as the same icon in both appearances.
            MenuBarGlyph()
                .frame(width: 17, height: 13)
                .frame(width: 30, height: 30)
                .background(Color.black.opacity(0.82),
                            in: RoundedRectangle(cornerRadius: ZenithRadius.large, style: .continuous))
        }
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
