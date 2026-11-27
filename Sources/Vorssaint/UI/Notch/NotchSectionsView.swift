// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// An in-place destination gallery. It only observes navigation, never the
/// contents or services of the sections represented by its buttons.
///
/// Rows step in whole, so the grid always rests on a row boundary; a dot per
/// resting position shows where it is and that more rows follow. Rows that
/// have stepped away keep their place for the motion but take no clicks.
struct NotchSectionsView: View {
    @ObservedObject var service: NotchService
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var text: NotchStrings { FeatureStrings.notch(l10n.language) }
    private var sections: [NotchModule] { service.filteredSections }
    private static let pitch = NotchLayout.sectionTileHeight + NotchLayout.sectionSpacing

    var body: some View {
        // The gallery stays mounted under the empty state. Swapping one for
        // the other rebuilt the island's top row, and the search field in it
        // took focus again with its text selected, so the next key replaced
        // the query.
        gallery
        .accessibilityHidden(sections.isEmpty)
        .overlay {
            if sections.isEmpty {
                NotchEmptyView(symbol: "magnifyingglass", message: FeatureStrings.clipboard(l10n.language).noResults)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: sections) { _, visible in
            if !visible.contains(where: { $0 == service.highlightedSection }) {
                service.highlightedSection = visible.first
            }
        }
    }

    private var gallery: some View {
        let columns = service.geometry.sectionColumns
        let rows = NotchSectionPaging.rows(count: sections.count, columns: columns)
        let visible = service.geometry.sectionRows(count: sections.count)
        let positions = NotchSectionPaging.positions(rows: rows, visible: visible)
        let first = NotchSectionPaging.clamped(service.sectionRow, rows: rows, visible: visible)
        let shown = first..<(first + visible)
        return HStack(spacing: 0) {
            VStack(spacing: NotchLayout.sectionSpacing) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: NotchLayout.sectionColumnSpacing) { // Zenith fork: columns of rows
                        ForEach(0..<columns, id: \.self) { column in
                            let index = row * columns + column
                            if index < sections.count {
                                tile(sections[index], visible: shown.contains(row))
                            } else {
                                Color.clear.frame(maxWidth: .infinity).frame(height: NotchLayout.sectionTileHeight)
                            }
                        }
                    }
                    .allowsHitTesting(shown.contains(row))
                    .accessibilityHidden(!shown.contains(row))
                }
            }
            .offset(y: -CGFloat(first) * Self.pitch)
            .frame(height: NotchLayout.railHeight(rows: visible, rowHeight: NotchLayout.sectionTileHeight,
                                                  spacing: NotchLayout.sectionSpacing), alignment: .top)
            .clipped()
            .animation(reduceMotion ? nil : IslandMotion.spring(duration: 0.3, bounce: 0), value: first)
            .accessibilityScrollAction { edge in
                if edge == .bottom { service.scrollSections(by: 1) }
                else if edge == .top { service.scrollSections(by: -1) }
            }
            indicator(positions: positions, current: first)
                .frame(width: NotchLayout.sectionIndicatorWidth, alignment: .trailing)
        }
        .accessibilityHint(text.sectionKeyboardHint)
    }

    /// One dot per resting position, the current one lit. Clicking a dot
    /// rests the gallery there; the wheel and the arrow keys step rows. The
    /// column keeps its width when everything fits, so tiles never shift.
    @ViewBuilder private func indicator(positions: Int, current: Int) -> some View {
        if positions > 1 {
            VStack(spacing: 5) {
                ForEach(0..<positions, id: \.self) { position in
                    Button { service.showSectionRow(position) } label: {
                        Circle()
                            .fill(.white.opacity(position == current ? 0.9 : contrast == .increased ? 0.5 : 0.28))
                            .frame(width: 6, height: 6)
                            .frame(width: 12, height: 12)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .animation(reduceMotion ? nil : IslandMotion.easeOut(0.15), value: current)
            .accessibilityHidden(true)
        } else {
            Color.clear
        }
    }

    private func tile(_ module: NotchModule, visible: Bool) -> some View {
        let highlighted = service.highlightedSection == module
        let current = service.selected == module
        return Button { service.select(module) } label: {
            // Zenith fork: a command palette row: glyph on its soft tinted tile, name and shortcut.
            ZenithCommandRow(symbol: module.symbol, title: module.title(l10n.language),
                             shortcut: "⌥⌘" + module.shortcutKey.uppercased(),
                             highlighted: highlighted, current: current, height: NotchLayout.sectionTileHeight,
                             tint: module.zenithTint)
        }
        .buttonStyle(NotchButtonStyle(cornerRadius: ZenithRadius.large, lifts: false, highlights: false)) // Zenith fork
        .accessibilityLabel(module.title(l10n.language))
        .accessibilityAddTraits(current ? .isSelected : [])
        .accessibilityIdentifier("notch.module.\(module.rawValue)")
        // A stepped-away row sits under the header, clipped; it keeps no
        // tooltip there.
        .help(visible ? module.title(l10n.language) + "  ⌥⌘" + module.shortcutKey.uppercased() : "")
    }
}

/// The gallery's search lives in the header as a magnifier: the field
/// unfolds under the pointer or as soon as something is typed, since the
/// keyboard already goes to it while the gallery is open.
struct NotchSectionSearch: View {
    @ObservedObject var service: NotchService
    /// Infinite fills the room its parent gives it, up to the camera.
    var maximumFieldWidth: CGFloat = 150
    @ObservedObject private var l10n = L10n.shared
    @FocusState private var searching: Bool
    @State private var hovered = false
    @State private var fieldWidth: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var text: NotchStrings { FeatureStrings.notch(l10n.language) }
    private var expanded: Bool { hovered || !service.sectionQuery.isEmpty }

    /// The whole prompt where it fits, otherwise the plain word, and no
    /// prompt where even that would be cut, so the placeholder never ends
    /// in a letter cut in half. The magnifier and the accessibility label
    /// still say what the field is for.
    private var prompt: String {
        let font = NSFont.systemFont(ofSize: 12)
        // The field's text sits a few points inside its frame.
        func fits(_ prompt: String) -> Bool {
            (prompt as NSString).size(withAttributes: [.font: font]).width + 6 <= fieldWidth
        }
        if fits(text.searchSections) { return text.searchSections }
        return fits(l10n.s.actionSearch) ? l10n.s.actionSearch : ""
    }

    var body: some View {
        HStack(spacing: expanded ? 4 : 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(expanded ? .white : .white.opacity(0.55))
                .frame(width: expanded ? 22 : 28, height: 28)
            // The field keeps its focus at a hair's width, so typing filters
            // the gallery before the field has even shown itself.
            TextField(prompt, text: Binding(get: { service.sectionQuery }, set: service.searchSections))
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($searching)
                .frame(maxWidth: expanded ? maximumFieldWidth : 1)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { fieldWidth = $0 }
                .opacity(expanded ? 1 : 0)
                .accessibilityLabel(text.searchSections)
            if !service.sectionQuery.isEmpty {
                Button { service.searchSections(""); searching = true } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(l10n.s.actionClear)
            }
        }
        .padding(.trailing, expanded ? 8 : 0)
        .frame(height: 28)
        .modifier(ZenithIslandFieldChrome(focused: searching && !service.sectionQuery.isEmpty, visible: expanded,
                                          cornerRadius: 9)) // Zenith fork: a hairline well
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .clipped()
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : IslandMotion.easeOut(0.15)) { hovered = hovering }
        }
        .onTapGesture { searching = true }
        .onAppear { searching = true }
        .help(text.searchSections)
    }
}
