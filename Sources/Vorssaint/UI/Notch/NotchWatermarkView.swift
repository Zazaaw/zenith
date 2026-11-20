// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: the Watermark step's controls on the photo actions surface
// (NotchPhotoActionsView). Calm, in the island's bento language: the 3×3
// position as small dots on a soft tile, two thin sliders for scale and
// opacity with their figures in mono, then the preset menu and three soft
// tiles for colour, the tile pattern and the shadow. The picture on the left
// shows the mark as it will be written, redrawn as each option moves.
//
// Motion is SwiftUI's own, transforms and opacity only: the chosen dot glides
// between places on a spring, a slider's knob grows while held, tiles take
// the accent on the toggle curve, and the footer swaps through the island's
// morph when a name is typed. Reduce Motion turns each into a fade.

/// The Watermark step beside Transform's other steps: a soft tile that takes
/// the accent while it is the chosen step.
struct NotchWatermarkStepTile: View {
    let selected: Bool
    let title: String
    let action: () -> Void
    @State private var hovering = false
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: ZenithRadius.large + 1, style: .continuous)
        Button(action: action) {
            Image(systemName: "signature")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(selected ? ZenithIsland.accent : hovering ? ZenithIsland.primary : ZenithIsland.secondary)
                .frame(width: 30, height: 26)
                .background(selected ? ZenithIsland.tileFill(ZenithIsland.accent, contrast: contrast)
                            : Color.white.opacity(hovering ? 0.1 : 0.07), in: shape)
                .overlay {
                    shape.strokeBorder(selected ? ZenithIsland.tileStroke(ZenithIsland.accent, contrast: contrast)
                                       : contrast == .increased ? ZenithIsland.contrastDivider : Color.white.opacity(0.08),
                                       lineWidth: 1)
                        .allowsHitTesting(false)
                }
                .contentShape(shape)
        }
        .buttonStyle(NotchPhotoPressStyle())
        .onHover { hovering = $0 }
        .animation(ZenithMotion.respecting(.easeOut(duration: ZenithMotion.fast)), value: hovering)
        .animation(ZenithMotion.respecting(ZenithMotion.toggle(ZenithMotion.fast)), value: selected)
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// The Watermark step's options: where and how large, then the preset and
/// the look. 40 points of placement over a 24-point footer.
struct NotchWatermarkOptions: View {
    let text: ZenithWatermarkStrings
    @ObservedObject private var photos = NotchPhotoActionsService.shared
    @State private var editing: Editing?
    @State private var draft = ""
    @FocusState private var focused: Bool

    enum Editing: Hashable {
        case presetName, text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .center, spacing: 10) {
                NotchWatermarkPositionPicker(selection: $photos.watermark.position, disabled: photos.watermark.tiled,
                                             names: text.positions, title: text.position)
                VStack(spacing: 4) {
                    NotchWatermarkSlider(symbol: "arrow.up.left.and.arrow.down.right", title: text.scale,
                                         value: $photos.watermark.scale, range: NotchWatermarkStyle.scaleRange,
                                         step: 1) { "\(Int($0.rounded()))%" }
                    NotchWatermarkSlider(symbol: "circle.lefthalf.filled", title: text.opacity,
                                         value: $photos.watermark.opacity, range: NotchWatermarkStyle.opacityRange,
                                         step: 0.05) { "\(Int(($0 * 100).rounded()))%" }
                }
            }
            .frame(height: 40)
            footer
                .frame(height: 24)
                .zenithMorph(on: editing)
        }
    }

    @ViewBuilder private var footer: some View {
        if let editing {
            field(for: editing)
        } else {
            HStack(spacing: 5) {
                NotchWatermarkPresetMenu(text: text) { begin($0) }
                Spacer(minLength: 0)
                NotchWatermarkColorMenu(text: text)
                NotchWatermarkToggleTile(symbol: "square.grid.3x3", title: text.tile, isOn: $photos.watermark.tiled)
                NotchWatermarkToggleTile(symbol: "shadow", title: text.shadow, isOn: $photos.watermark.shadow)
            }
        }
    }

    private func field(for editing: Editing) -> some View {
        HStack(spacing: 2) {
            TextField("", text: $draft,
                      prompt: Text(editing == .presetName ? text.presetName : NotchWatermarkStyle.defaultText)
                        .foregroundStyle(ZenithIsland.meta))
                .textFieldStyle(.plain)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(ZenithIsland.primary)
                .focused($focused)
                .onSubmit(commit)
                .onExitCommand(perform: cancel)
                .onChange(of: draft) { _, value in
                    let line = NotchWatermarkSupport.textInput(value)
                    if line != value { draft = line }
                }
            NotchWatermarkGlyphButton(symbol: "checkmark", title: editing == .presetName ? text.save : text.editText,
                                      action: commit)
            NotchWatermarkGlyphButton(symbol: "xmark", title: ZenithStrings.photoActions(L10n.shared.language).cancel,
                                      action: cancel)
        }
        .padding(.leading, 9)
        .padding(.trailing, 2)
        .modifier(ZenithIslandFieldChrome(focused: focused, cornerRadius: ZenithRadius.large))
    }

    private func begin(_ mode: Editing) {
        draft = mode == .presetName ? (photos.currentWatermarkPreset?.name ?? "") : photos.watermark.text
        editing = mode
        DispatchQueue.main.async { focused = true }
    }

    private func commit() {
        switch editing {
        case .presetName:
            guard photos.saveWatermarkPreset(named: draft) else { return }
        case .text:
            var style = photos.watermark
            style.text = NotchWatermarkSupport.textInput(draft).trimmingCharacters(in: .whitespaces)
            if !style.text.isEmpty, style.content == .logo { style.content = .both }
            photos.watermark = style
        case nil:
            break
        }
        cancel()
    }

    private func cancel() {
        focused = false
        editing = nil
    }
}

// MARK: - Position

/// The 3×3 grid as small dots on a soft tile; the chosen place is a larger
/// accent dot that glides to a new one. Dimmed while the pattern tiles the
/// whole picture, where a place means nothing.
struct NotchWatermarkPositionPicker: View {
    @Binding var selection: NotchWatermarkPosition
    let disabled: Bool
    let names: [String]
    let title: String
    @Namespace private var chosenDot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: ZenithRadius.large + 1, style: .continuous)
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { column in
                        if let position = NotchWatermarkPosition(rawValue: row * 3 + column) { cell(position) }
                    }
                }
            }
        }
        .padding(2)
        .frame(width: 40, height: 40)
        .background(ZenithIsland.cardFill, in: shape)
        .overlay {
            shape.strokeBorder(contrast == .increased ? ZenithIsland.contrastHairline : ZenithIsland.cardStroke,
                               lineWidth: 0.75)
                .allowsHitTesting(false)
        }
        .opacity(disabled ? 0.35 : 1)
        .disabled(disabled)
        .animation(.easeOut(duration: ZenithMotion.fast), value: disabled)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    private func cell(_ position: NotchWatermarkPosition) -> some View {
        let chosen = position == selection
        let name = names.indices.contains(position.rawValue) ? names[position.rawValue] : ""
        return Button {
            guard !chosen else { return }
            withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.32, dampingFraction: 0.8)) {
                selection = position
            }
        } label: {
            NotchWatermarkDot(chosen: chosen, namespace: chosenDot, glides: !reduceMotion)
                .frame(width: 12, height: 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(name)
        .accessibilityLabel(name)
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }
}

private struct NotchWatermarkDot: View {
    let chosen: Bool
    let namespace: Namespace.ID
    let glides: Bool
    @State private var hovering = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(hovering ? 0.65 : 0.3))
                .frame(width: 3.5, height: 3.5)
            if chosen {
                let dot = Circle().fill(ZenithIsland.accent).frame(width: 7.5, height: 7.5)
                if glides {
                    dot.matchedGeometryEffect(id: "dot", in: namespace)
                } else {
                    dot.transition(.opacity)
                }
            }
        }
        .onHover { hovering = $0 }
        .animation(ZenithMotion.respecting(.easeOut(duration: ZenithMotion.fast)), value: hovering)
    }
}

// MARK: - Sliders

/// A thin slider in the island's data-bar style: a 3-point track, a white
/// fill, a knob that grows while held, and its figure in mono at the end.
struct NotchWatermarkSlider: View {
    let symbol: String
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String
    @State private var dragging = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(symbol: String, title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double,
         format: @escaping (Double) -> String) {
        self.symbol = symbol
        self.title = title
        _value = value
        self.range = range
        self.step = step
        self.format = format
    }

    private var fraction: CGFloat {
        let span = range.upperBound - range.lowerBound
        guard span > 0, value.isFinite else { return 0 }
        return CGFloat(min(1, max(0, (value - range.lowerBound) / span)))
    }

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(ZenithIsland.label)
                .frame(width: 12)
            GeometryReader { proxy in
                let width = max(1, proxy.size.width)
                ZStack(alignment: .leading) {
                    Capsule().fill(ZenithIsland.barTrack).frame(height: 3)
                    Capsule().fill(ZenithIsland.barFill).frame(width: max(3, width * fraction), height: 3)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                        .shadow(color: .black.opacity(0.35), radius: 1.5, y: 0.5)
                        .scaleEffect(dragging && !reduceMotion ? 1.3 : 1)
                        .offset(x: width * fraction - 5)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !dragging { withAnimation(knob) { dragging = true } }
                        set(Double(gesture.location.x / width))
                    }
                    .onEnded { _ in withAnimation(knob) { dragging = false } })
            }
            Text(format(value))
                .font(ZenithType.mono(10.5, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(ZenithIsland.secondary)
                .lineLimit(1)
                .frame(width: 32, alignment: .trailing)
        }
        .frame(height: 18)
        .help(title)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(format(value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(range.upperBound, value + step)
            case .decrement: value = max(range.lowerBound, value - step)
            @unknown default: break
            }
        }
    }

    private var knob: Animation {
        reduceMotion ? .easeOut(duration: 0.1) : .spring(response: 0.28, dampingFraction: 0.7)
    }

    /// The point under the pointer, on the slider's steps.
    private func set(_ share: Double) {
        let share = min(1, max(0, share.isFinite ? share : 0))
        let raw = range.lowerBound + share * (range.upperBound - range.lowerBound)
        let stepped = step > 0 ? (raw / step).rounded() * step : raw
        let next = min(range.upperBound, max(range.lowerBound, stepped))
        if next != value { value = next }
    }
}

// MARK: - Footer

/// The presets and the less frequent choices: what the mark shows, its text
/// and weight, the logo, and the margin.
struct NotchWatermarkPresetMenu: View {
    let text: ZenithWatermarkStrings
    let edit: (NotchWatermarkOptions.Editing) -> Void
    @ObservedObject private var photos = NotchPhotoActionsService.shared
    @State private var hovering = false
    @Environment(\.colorSchemeContrast) private var contrast

    private static let margins: [Double] = [0, 1, 2, 3, 5, 8]
    /// Room for "Client proof" beside the three tiles in a compact island.
    static let width: CGFloat = 112

    var body: some View {
        let current = photos.currentWatermarkPreset
        Menu {
            Section(text.presets) {
                ForEach(photos.watermarkPresets) { preset in
                    Button { photos.applyWatermarkPreset(preset.id) } label: {
                        if preset.id == current?.id { Label(preset.name, systemImage: "checkmark") } else { Text(preset.name) }
                    }
                }
            }
            Button(text.savePreset) { edit(.presetName) }
            if let current {
                Button(text.deletePreset, role: .destructive) { photos.deleteWatermarkPreset(current.id) }
            }
            Divider()
            Picker(text.content, selection: $photos.watermark.content) {
                Text(text.logo).tag(NotchWatermarkContent.logo)
                Text(text.text).tag(NotchWatermarkContent.text)
                Text(text.logoAndText).tag(NotchWatermarkContent.both)
            }
            Button(text.editText) { edit(.text) }
            Picker(text.weight, selection: $photos.watermark.weight) {
                Text(text.regular).tag(NotchWatermarkWeight.regular)
                Text(text.medium).tag(NotchWatermarkWeight.medium)
                Text(text.semibold).tag(NotchWatermarkWeight.semibold)
                Text(text.bold).tag(NotchWatermarkWeight.bold)
            }
            Picker(text.margin, selection: $photos.watermark.margin) {
                ForEach(Self.margins, id: \.self) { Text("\(Int($0))%").tag($0) }
            }
            Divider()
            Button(text.chooseLogo) { photos.chooseWatermarkLogo() }
            if photos.watermark.logoFile != nil {
                Button(text.star) { photos.useWatermarkStar() }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.stack")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(ZenithIsland.label)
                Text(current?.name ?? text.unsaved)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(current == nil ? ZenithIsland.secondary : ZenithIsland.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 2)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundStyle(ZenithIsland.label)
            }
            .padding(.horizontal, 9)
            // A set width: a borderless menu that took the row's free width
            // would starve the tiles beside it (issue #569).
            .frame(width: Self.width, height: 24)
            .background(Color.white.opacity(hovering ? 0.1 : 0.07),
                        in: RoundedRectangle(cornerRadius: ZenithRadius.large, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: ZenithRadius.large, style: .continuous)
                    .strokeBorder(contrast == .increased ? ZenithIsland.contrastDivider : Color.white.opacity(0.08),
                                  lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .onHover { hovering = $0 }
        .animation(ZenithMotion.respecting(.easeOut(duration: ZenithMotion.fast)), value: hovering)
        .help(text.presets)
        .accessibilityLabel(text.presets)
        .accessibilityValue(current?.name ?? text.unsaved)
    }
}

/// The mark's colour as a swatch on a soft tile; the choices in a menu.
struct NotchWatermarkColorMenu: View {
    let text: ZenithWatermarkStrings
    @ObservedObject private var photos = NotchPhotoActionsService.shared

    var body: some View {
        let style = photos.watermark
        Menu {
            Picker(text.color, selection: $photos.watermark.color) {
                Text(text.autoColor).tag(NotchWatermarkColor.auto)
                Text(text.white).tag(NotchWatermarkColor.white)
                Text(text.black).tag(NotchWatermarkColor.black)
                Text(text.customColor).tag(NotchWatermarkColor.custom)
                if style.logoFile != nil { Text(text.originalColors).tag(NotchWatermarkColor.original) }
            }
            .pickerStyle(.inline)
        } label: {
            NotchWatermarkTileChrome(active: false) {
                NotchWatermarkSwatch(color: style.color, custom: style.customColor)
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(text.color)
        .accessibilityLabel(text.color)
    }
}

/// A small disc that says which colour the mark wears.
private struct NotchWatermarkSwatch: View {
    let color: NotchWatermarkColor
    let custom: String

    var body: some View {
        switch color {
        case .auto:
            Image(systemName: "circle.lefthalf.filled")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(ZenithIsland.primary)
        case .white:
            disc(.white)
        case .black:
            disc(.black)
        case .custom:
            let rgb = NotchWatermarkSupport.rgb(hex: custom) ?? (1, 1, 1)
            disc(Color(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: 1))
        case .original:
            Image(systemName: "paintpalette")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(ZenithIsland.primary)
        }
    }

    private func disc(_ fill: Color) -> some View {
        Circle().fill(fill)
            .overlay(Circle().strokeBorder(Color.white.opacity(0.45), lineWidth: 0.75))
            .frame(width: 10, height: 10)
    }
}

/// An on or off look of the mark (the tile pattern, the shadow) as a soft
/// tile that takes the accent while on.
struct NotchWatermarkToggleTile: View {
    let symbol: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(ZenithMotion.respecting(ZenithMotion.toggle(ZenithMotion.fast))) { isOn.toggle() }
        } label: {
            NotchWatermarkTileChrome(active: isOn) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isOn ? ZenithIsland.accent : ZenithIsland.secondary)
            }
        }
        .buttonStyle(NotchPhotoPressStyle())
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// A 24-point soft tile: faint white, or the accent's tint when active.
private struct NotchWatermarkTileChrome<Content: View>: View {
    let active: Bool
    @ViewBuilder let content: () -> Content
    @State private var hovering = false
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: ZenithRadius.large, style: .continuous)
        content()
            .frame(width: 24, height: 24)
            .background(active ? ZenithIsland.tileFill(ZenithIsland.accent, contrast: contrast)
                        : Color.white.opacity(hovering ? 0.1 : 0.07), in: shape)
            .overlay {
                shape.strokeBorder(active ? ZenithIsland.tileStroke(ZenithIsland.accent, contrast: contrast)
                                   : contrast == .increased ? ZenithIsland.contrastDivider : Color.white.opacity(0.08),
                                   lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .contentShape(shape)
            .onHover { hovering = $0 }
            .animation(ZenithMotion.respecting(.easeOut(duration: ZenithMotion.fast)), value: hovering)
    }
}

/// A bare glyph in the naming field (save, cancel).
private struct NotchWatermarkGlyphButton: View {
    let symbol: String
    let title: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(hovering ? ZenithIsland.primary : ZenithIsland.secondary)
                .frame(width: 20, height: 20)
                .background(Circle().fill(hovering ? ZenithIsland.hoverFill : .clear))
                .contentShape(Circle())
        }
        .buttonStyle(NotchPhotoPressStyle())
        .onHover { hovering = $0 }
        .animation(ZenithMotion.respecting(.easeOut(duration: ZenithMotion.fast)), value: hovering)
        .help(title)
        .accessibilityLabel(title)
    }
}
