// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

// Zenith fork: a choice shown as pictures (the approved Mechakey mockup):
// tiles with a little scene on the stage gradient, the label under each,
// an accent ring around the chosen one.

/// One choice of a `ZenithVisualPicker`.
struct ZenithPickerOption<Value: Hashable>: Identifiable {
    let value: Value
    let label: String
    /// A longer word on the choice, shown on hover and read by VoiceOver.
    var detail: String?
    var id: Value { value }

    init(_ value: Value, _ label: String, detail: String? = nil) {
        self.value = value
        self.label = label
        self.detail = detail
    }
}

/// Picks one of a few choices shown as pictures.
///
///     ZenithVisualPicker("Sound pack", selection: $packID,
///                        options: packs.map { ZenithPickerOption($0.id, $0.shortTitle) }) { id, selected in
///         KeycapArt(color: color(for: id))
///     }
///
/// Tiles fill the width from `minimumTileWidth`; `tileHeight` is the art's.
/// Each tile is a button VoiceOver reads by its label, marked selected.
struct ZenithVisualPicker<Value: Hashable, Art: View>: View {
    let title: String
    @Binding var selection: Value
    let options: [ZenithPickerOption<Value>]
    var minimumTileWidth: CGFloat = 84
    var tileHeight: CGFloat = 64
    @ViewBuilder let art: (Value, Bool) -> Art

    init(_ title: String, selection: Binding<Value>, options: [ZenithPickerOption<Value>],
         minimumTileWidth: CGFloat = 84, tileHeight: CGFloat = 64,
         @ViewBuilder art: @escaping (Value, Bool) -> Art) {
        self.title = title
        _selection = selection
        self.options = options
        self.minimumTileWidth = minimumTileWidth
        self.tileHeight = tileHeight
        self.art = art
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minimumTileWidth), spacing: 10)], spacing: 12) {
            ForEach(options) { option in
                ZenithPickerTile(label: option.label, detail: option.detail, selected: option.value == selection,
                                 height: tileHeight) {
                    selection = option.value
                } art: {
                    art(option.value, option.value == selection)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}

private struct ZenithPickerTile<Art: View>: View {
    let label: String
    let detail: String?
    let selected: Bool
    let height: CGFloat
    let action: () -> Void
    @ViewBuilder let art: () -> Art
    @Environment(\.zenithTint) private var tint
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        Button(action: action) {
            VStack(spacing: 7) {
                ZStack {
                    ZenithStageGradient(tint: tint, dark: colorScheme == .dark)
                    art()
                }
                .frame(height: height)
                .frame(maxWidth: .infinity)
                .clipShape(shape)
                .overlay(shape.strokeBorder(selected ? Color.accentColor
                                                : Color.primary.opacity(contrast == .increased ? 0.3 : (hovering ? 0.2 : 0.08)),
                                            lineWidth: selected ? 2.5 : 1))
                Text(label)
                    .font(.system(size: 11.5, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Color.accentColor : .secondary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(detail ?? label)
        .accessibilityLabel(label)
        .accessibilityHint(detail ?? "")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
