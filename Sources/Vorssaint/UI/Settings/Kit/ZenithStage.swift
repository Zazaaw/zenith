// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: the stage previews sit on (the approved mockups): a gradient
// panel in the page's category tint holding the thing itself, and under it
// the states to look at as pills and a line on what it shows. Every
// `ZenithSettingsPreviewCard` draws on it.

/// A preview on the tinted stage.
///
///     ZenithStage(caption: "Press a key on the stage to hear the pack",
///                 states: ["Typing", "Space", "Enter"], selection: $state) {
///         MechakeyKeys(state: state)
///     }
///
/// - `height`: the stage's height; nil lets the art decide (a preview
///   picture sized by its aspect ratio).
/// - `states` / `selection`: the pills; leave empty for none. More than
///   fit become a menu.
/// - `hint`: a second, accent line (which part is outlined, click to jump).
/// - `footer`: controls under the pills that belong to the preview.
struct ZenithStage<Art: View, Footer: View>: View {
    var caption: String?
    var hint: String?
    var hintHelp: String?
    var states: [String]
    var selection: Binding<Int>?
    var height: CGFloat?
    let art: Art
    let footer: Footer

    init(caption: String? = nil, hint: String? = nil, hintHelp: String? = nil, states: [String] = [],
         selection: Binding<Int>? = nil, height: CGFloat? = 210,
         @ViewBuilder art: () -> Art, @ViewBuilder footer: () -> Footer) {
        self.caption = caption
        self.hint = hint
        self.hintHelp = hintHelp
        self.states = states
        self.selection = selection
        self.height = height
        self.art = art()
        self.footer = footer()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZenithStageSurface(height: height) { art }
            if hasPills || caption != nil || hint != nil {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        pills
                        Spacer(minLength: 12)
                        captions(alignment: .trailing).fixedSize()
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        pills
                        captions(alignment: .leading)
                    }
                }
            }
            footer
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var hasPills: Bool { selection != nil && states.count > 1 }

    @ViewBuilder private var pills: some View {
        if let selection, hasPills {
            ZenithStatePills(states: states, selection: selection)
        }
    }

    private func captions(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            if let caption {
                Text(caption)
                    .font(ZenithType.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(alignment == .trailing ? .trailing : .leading)
            }
            if let hint {
                Label(hint, systemImage: "hand.point.up.left")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .help(hintHelp ?? hint)
            }
        }
    }
}

extension ZenithStage where Footer == EmptyView {
    init(caption: String? = nil, hint: String? = nil, hintHelp: String? = nil, states: [String] = [],
         selection: Binding<Int>? = nil, height: CGFloat? = 210, @ViewBuilder art: () -> Art) {
        self.init(caption: caption, hint: hint, hintHelp: hintHelp, states: states, selection: selection,
                  height: height, art: art, footer: { EmptyView() })
    }
}

/// The stage's tinted panel alone, for art that needs no pills (a picker tile
/// uses the same gradient through `ZenithStageGradient`).
struct ZenithStageSurface<Art: View>: View {
    var height: CGFloat?
    let art: Art
    @Environment(\.zenithTint) private var tint
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    init(height: CGFloat? = 210, @ViewBuilder art: () -> Art) {
        self.height = height
        self.art = art()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: ZenithKitSurface.stageRadius, style: .continuous)
        let dark = colorScheme == .dark
        art
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background {
                ZStack {
                    ZenithStageGradient(tint: tint, dark: dark)
                    GeometryReader { geo in
                        // Two soft discs, as in the mockup: light falling across the stage.
                        Circle().fill(Color.white.opacity(dark ? 0.07 : 0.22))
                            .frame(width: geo.size.width * 0.5)
                            .position(x: geo.size.width * 0.82, y: geo.size.height * 0.05)
                        Circle().fill(Color.white.opacity(dark ? 0.05 : 0.18))
                            .frame(width: geo.size.width * 0.34)
                            .position(x: geo.size.width * 0.18, y: geo.size.height * 1.05)
                    }
                    .accessibilityHidden(true)
                }
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(ZenithKitSurface.hairline(highContrast: contrast == .increased)))
    }
}

/// The stage's gradient in a category's tint.
struct ZenithStageGradient: View {
    let tint: ZenithCategoryTint
    let dark: Bool

    var body: some View {
        LinearGradient(colors: tint.stageColors(dark: dark), startPoint: .topLeading, endPoint: .bottomTrailing)
            .accessibilityHidden(true)
    }
}

/// The stage's state pills: a capsule of choices, a menu when they don't fit.
struct ZenithStatePills: View {
    let states: [String]
    @Binding var selection: Int
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 2) {
                ForEach(states.indices, id: \.self) { index in
                    pill(index)
                }
            }
            .padding(2)
            .background(Capsule().fill(Color.primary.opacity(0.05)))
            .overlay(Capsule().strokeBorder(Color.primary.opacity(contrast == .increased ? 0.25 : 0)))
            .fixedSize()
            Picker("", selection: $selection) {
                ForEach(states.indices, id: \.self) { Text(states[$0]).tag($0) }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()
        }
    }

    private func pill(_ index: Int) -> some View {
        let selected = index == selection
        return Button { selection = index } label: {
            Text(states[index])
                .font(.system(size: 11.5, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? .primary : .secondary)
                .padding(.horizontal, 10)
                .frame(height: 22)
                .background(Capsule().fill(selected ? Color.primary.opacity(0.12) : .clear))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
