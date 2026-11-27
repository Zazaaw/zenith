// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

/// Zenith fork: Settings → Menu Bar, built with the Settings kit. What used
/// to be General's Menu bar tool: the panel behind Zenith's icon (its tabs
/// and their order), the icon itself, and the menu bar hider. The menu bar
/// metrics stay on System Monitor, whose readings they are.
struct MenuBarSettingsPage: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.menuBarIconSymbol) private var symbolName = ""
    @AppStorage(DefaultsKey.menuBarHiderEnabled) private var hiderEnabled = false

    private let page = ZenithStrings.systemApps(.enUS)
    private var text: GeneralSettingsStrings { FeatureStrings.generalSettings(l10n.language) }

    var body: some View {
        ScrollView {
            ZenithPageColumn {
                ZenithHero(title: page.menuBarTitle, subtitle: page.menuBarSubtitle, chips: chips,
                           animation: .menuBar)
                ZenithScreenPreviewCard(group: .menuBar)
                ZenithSection(page.menuBarPanel, anchor: .panelConfiguration) {
                    ZenithRow(l10n.s.menuBarSection, info: text.panelIntro) { EmptyView() }
                    PanelLayoutEditor().padding(.vertical, 12)
                }
                ZenithSection(page.menuBarIcon) {
                    MenuBarIconSymbolRow()
                    ZenithRow(text.iconMissingTitle, info: text.iconMissingCaption, button: l10n.s.showMenuBarIcon) {
                        appDelegate()?.reshowStatusItem()
                    }
                }
                MenuBarHiderSettingsSection()
            }
        }
    }

    private var chips: [ZenithChip] {
        let name = Defaults.sanitizedMenuBarIconSymbol(symbolName)
        var chips = [ZenithChip(name.isEmpty ? page.menuBarZenithIcon : name)]
        if hiderEnabled { chips.append(ZenithChip(page.menuBarHiderOn, dot: ZenithStatus.success)) }
        return chips
    }
}

/// Draws a system symbol in the menu bar in place of the Vorssaint glyph,
/// picked with one click from a gallery. The last cell takes any other symbol
/// by name, and shows that symbol while it is the one in use.
private struct MenuBarIconSymbolRow: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.menuBarIconSymbol) private var savedName = ""
    @State private var typingName = false

    /// Filtered like the radial menu's icons, so a name a future macOS
    /// drops leaves no empty cell.
    private static let symbols = Defaults.menuBarIconGallery.filter {
        NSImage(systemSymbolName: $0, accessibilityDescription: nil) != nil
    }

    private var text: GeneralSettingsStrings { FeatureStrings.generalSettings(l10n.language) }

    var body: some View {
        let name = Defaults.sanitizedMenuBarIconSymbol(savedName)
        let otherName = name.isEmpty || Self.symbols.contains(name) ? "" : name
        VStack(alignment: .leading, spacing: 10) {
            ZenithRow(text.menuBarIconTitle, info: text.menuBarIconCaption) { EmptyView() }
            // Eager, so the cell the name popover hangs from is never
            // released while the page scrolls.
            FlowLayoutLite(spacing: 6) {
                cell(selected: name.isEmpty) {
                    savedName = ""
                } label: {
                    vorssaintMark
                }
                .help(text.menuBarIconReset)
                .accessibilityLabel(text.menuBarIconReset)
                ForEach(Self.symbols, id: \.self) { symbol in
                    cell(selected: name == symbol) {
                        savedName = symbol
                    } label: {
                        Image(systemName: symbol)
                    }
                    .help(symbol)
                }
                cell(selected: !otherName.isEmpty) {
                    typingName = true
                } label: {
                    // A name from a newer macOS has nothing to draw here.
                    let drawable = NSImage(systemSymbolName: otherName, accessibilityDescription: nil) != nil
                    Image(systemName: drawable ? otherName : "ellipsis")
                }
                .help(otherName.isEmpty ? text.menuBarIconOther : otherName)
                .accessibilityLabel(text.menuBarIconOther)
                .popover(isPresented: $typingName, arrowEdge: .bottom) {
                    MenuBarIconNameField()
                }
            }
        }
        .padding(.bottom, 12)
    }

    /// The bundled mark even while a symbol replaces it in the menu bar.
    private var vorssaintMark: some View {
        Group {
            if let mark = BlackHoleGlyph.mark(symbolName: "") {
                Image(nsImage: mark)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "circle.fill")
            }
        }
        .frame(maxWidth: 21, maxHeight: 16)
    }

    private func cell<Label: View>(selected: Bool, action: @escaping () -> Void,
                                   @ViewBuilder label: () -> Label) -> some View {
        Button(action: action) {
            label()
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 34, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(selected ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(selected ? Color.accentColor.opacity(0.75) : Color.secondary.opacity(0.13),
                                      lineWidth: selected ? 1.2 : 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Takes any symbol by name. The icon follows the typing: a name this Mac has
/// a symbol for is kept at once, and any other name brings back the icon the
/// field opened with, so a typo never leaves a valid half of the name behind.
private struct MenuBarIconNameField: View {
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.dismiss) private var dismiss
    @AppStorage(DefaultsKey.menuBarIconSymbol) private var savedName = ""
    @State private var draft = ""
    @State private var openingName = ""
    @FocusState private var focused: Bool

    private var text: GeneralSettingsStrings { FeatureStrings.generalSettings(l10n.language) }

    var body: some View {
        let name = Defaults.sanitizedMenuBarIconSymbol(draft)
        VStack(alignment: .leading, spacing: 8) {
            Text(text.menuBarIconOther)
                .font(.headline)
            HStack(spacing: 6) {
                TextField(text.menuBarIconOther, text: $draft, prompt: Text(verbatim: "bolt.fill"))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .onSubmit { dismiss() }
                // Kept in place while hidden, so the field does not change
                // width as the name is typed or cleared.
                Button {
                    draft = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(text.menuBarIconReset)
                .accessibilityLabel(text.menuBarIconReset)
                .opacity(draft.isEmpty ? 0 : 1)
                .disabled(draft.isEmpty)
                .accessibilityHidden(draft.isEmpty)
            }
            Text(text.menuBarIconOtherCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !name.isEmpty, BlackHoleGlyph.customMark(named: name) == nil {
                Text(text.menuBarIconUnknown)
                    .font(.caption)
                    .foregroundStyle(ZenithStatus.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(width: 280)
        .onAppear {
            openingName = BlackHoleGlyph.chosenSymbolName
            draft = openingName
            // The popover's window is not key yet while it appears.
            DispatchQueue.main.async { focused = true }
        }
        .onChange(of: draft) { _, newValue in
            let kept = Defaults.menuBarIconSymbolToSave(typed: newValue, opening: openingName) {
                BlackHoleGlyph.customMark(named: $0) != nil
            }
            if kept != savedName { savedName = kept }
        }
    }
}
