// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

// Zenith fork: the section gallery as a grid of colourful app icons over
// their names, in pages that slide sideways, with a page control in the
// island's top row. It keeps everything the command palette did: search
// (the field stays in the top row), keyboard navigation (the service's grid
// moves; a highlighted icon brings its page), the current module's mark,
// availability and order (the service's filtered list), and the ⌥⌘ shortcuts,
// shown on a small mono badge under the pointer or the keyboard's cursor.
//
// It fills the room upstream's three rows of 86-point tiles took, so the
// island opens on the gallery at the height it always had
// (`NotchLayout.sectionListHeight`).

struct ZenithWidgetsGallery: View {
    @ObservedObject var service: NotchService
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    /// The icon's side inside an 86-point cell: the icon, 6 points, the name.
    static let iconSize: CGFloat = 60

    var body: some View {
        let sections = service.filteredSections
        let columns = max(1, service.geometry.sectionColumns)
        let rows = NotchSectionPaging.rows(count: sections.count, columns: columns)
        let visible = max(1, service.geometry.sectionRows(count: sections.count))
        let pages = ZenithWidgetsPaging.pages(rows: rows, visible: visible)
        let page = ZenithWidgetsPaging.page(ofRow: ZenithWidgetsPaging.pageStart(service.sectionRow, rows: rows,
                                                                                visible: visible), visible: visible)
        let height = NotchLayout.railHeight(rows: visible, rowHeight: NotchLayout.sectionTileHeight,
                                            spacing: NotchLayout.sectionSpacing)
        GeometryReader { proxy in
            let width = proxy.size.width
            Group {
                if reduceMotion {
                    // A page change cross-fades in place.
                    ZStack(alignment: .topLeading) {
                        grid(sections, page: page, columns: columns, visible: visible)
                            .id(page)
                            .transition(.opacity)
                    }
                    .animation(.easeInOut(duration: ZenithMotion.fast), value: page)
                } else {
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(0..<pages, id: \.self) { index in
                            grid(sections, page: index, columns: columns, visible: visible)
                                .frame(width: width, alignment: .topLeading)
                                .allowsHitTesting(index == page)
                                .accessibilityHidden(index != page)
                        }
                    }
                    .offset(x: -CGFloat(page) * width)
                    .animation(ZenithMorph.animation, value: page)
                }
            }
            .frame(width: width, height: height, alignment: .topLeading)
        }
        .frame(height: height)
        .clipped()
        .accessibilityScrollAction { edge in
            if edge == .trailing || edge == .bottom { service.scrollSections(by: 1) }
            else if edge == .leading || edge == .top { service.scrollSections(by: -1) }
        }
        .notchBand(trailing: { ZenithWidgetsPageControl(service: service, pages: pages, page: page, visible: visible) })
        .onAppear {
            guard !reduceMotion else { appeared = true; return }
            appeared = false
            DispatchQueue.main.async { appeared = true }
        }
    }

    /// One page: `visible` rows of `columns` icons, the last page left open.
    private func grid(_ sections: [NotchModule], page: Int, columns: Int, visible: Int) -> some View {
        VStack(alignment: .leading, spacing: NotchLayout.sectionSpacing) {
            ForEach(0..<visible, id: \.self) { row in
                HStack(spacing: NotchLayout.sectionColumnSpacing) {
                    ForEach(0..<columns, id: \.self) { column in
                        let index = (page * visible + row) * columns + column
                        if index < sections.count {
                            cell(sections[index])
                                // Rows rise in after the island opens, 40 ms apart.
                                .modifier(ZenithGalleryEntrance(shown: appeared))
                                .animation(ZenithMorph.animation.delay(ZenithMotion.layerDelay(row + 1)), value: appeared)
                        } else {
                            Color.clear.frame(maxWidth: .infinity).frame(height: NotchLayout.sectionTileHeight)
                        }
                    }
                }
            }
        }
    }

    private func cell(_ module: NotchModule) -> some View {
        let title = module.title(l10n.language)
        let shortcut = "⌥⌘" + module.shortcutKey.uppercased()
        let current = service.selected == module
        return Button { service.select(module) } label: {
            ZenithWidgetsGalleryCell(module: module, title: title, shortcut: shortcut,
                                     highlighted: service.highlightedSection == module, current: current)
        }
        .buttonStyle(ZenithAppIconButtonStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(current ? .isSelected : [])
        .accessibilityIdentifier("notch.module.\(module.rawValue)")
        .help(title + "  " + shortcut)
    }
}

/// A module's cell: its icon, the current module's check, the shortcut
/// badge under the pointer or the keyboard's cursor, and its name.
private struct ZenithWidgetsGalleryCell: View {
    let module: NotchModule
    let title: String
    let shortcut: String
    let highlighted: Bool
    let current: Bool
    @State private var hovering = false
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: ZenithIsland.nestedRadius(padding: 2), style: .continuous)
        VStack(spacing: 6) {
            ZenithAppIcon(module: module, size: ZenithWidgetsGallery.iconSize)
                .overlay(alignment: .topTrailing) {
                    if current { ZenithAppIconCheck().offset(x: 5, y: -5).transition(.scale.combined(with: .opacity)) }
                }
                .overlay(alignment: .bottom) {
                    if hovering || highlighted {
                        Text(shortcut)
                            .font(ZenithType.mono(9.5, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.92))
                            .padding(.horizontal, 5)
                            .frame(height: 15)
                            .background(Color.black.opacity(0.72), in: Capsule())
                            .overlay { Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5) }
                            .fixedSize()
                            .offset(y: 6)
                            .transition(.opacity.combined(with: .offset(y: 3)))
                    }
                }
            Text(title)
                .font(.system(size: 11, weight: current ? .semibold : .medium))
                .foregroundStyle(current || hovering || highlighted ? ZenithIsland.primary : ZenithIsland.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 2)
        }
        .frame(maxWidth: .infinity)
        .frame(height: NotchLayout.sectionTileHeight)
        // The keyboard's cursor: a brighter fill under a hairline, as the rows had.
        .background(shape.fill(highlighted ? ZenithIsland.cursorFill : .clear))
        .overlay {
            shape.strokeBorder(highlighted ? (contrast == .increased ? Color.white.opacity(0.6) : ZenithIsland.cursorStroke)
                               : .clear, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .contentShape(shape)
        .onHover { hovering = $0 }
        .animation(ZenithMotion.respecting(.easeOut(duration: ZenithMotion.fast)), value: hovering)
        .animation(ZenithMotion.respecting(.easeOut(duration: ZenithMotion.fast)), value: highlighted)
    }
}

/// A row coming in: up 6 points out of a blur.
private struct ZenithGalleryEntrance: ViewModifier {
    let shown: Bool

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .blur(radius: shown ? 0 : 6)
            .offset(y: shown ? 0 : 6)
    }
}

/// The gallery's page control in the island's top row: a dot per page, the
/// current one a short capsule. A dot rests the gallery on its page.
private struct ZenithWidgetsPageControl: View {
    @ObservedObject var service: NotchService
    let pages: Int
    let page: Int
    let visible: Int
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if pages > 1 {
            HStack(spacing: 2) {
                ForEach(0..<pages, id: \.self) { index in
                    Button { service.showSectionRow(index * visible) } label: {
                        Capsule()
                            .fill(Color.white.opacity(index == page ? 0.9 : contrast == .increased ? 0.5 : 0.28))
                            .frame(width: index == page ? 14 : 6, height: 6)
                            .frame(height: 20)
                            .padding(.horizontal, 2)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .animation(reduceMotion ? nil : ZenithMorph.animation, value: page)
            .accessibilityElement(children: .ignore)
            .accessibilityValue("\(page + 1) / \(pages)")
        }
    }
}
