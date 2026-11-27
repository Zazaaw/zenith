// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: the open island's chrome in the language Settings and the
// menu bar panel already speak (p441z.my.id), translated onto the island's
// black: white hairlines and the faintest white lift instead of grey blocks,
// white text at three steps, mono for labels and figures, monochrome glyphs,
// and the system accent only on what is selected, in the Style Kit's
// 10% fill / 20% outline / 100% content form. Status colours keep their
// meaning (`ZenithStatus`); data colours (charts, covers, the companion,
// agent and deployment marks) stay as they are.
//
// Upstream's island views reach this file through one-line hooks marked
// `// Zenith fork`, mostly in their shared building blocks (NotchIconButton,
// NotchPillButton, NotchEmptyView, NotchControlSurface, the section gallery),
// so a sync meets few lines. The test executable compiles this file too,
// since several island declarations are copied into it: keep it free of
// anything outside SwiftUI, AppKit and `ZenithTokens`/`ZenithSwitch`.
//
// The second redesign (bento cells, mono figures, 3-point bars, the
// segmented well, status dots, the command palette) lives beside this file
// in `ZenithIslandKit.swift`; the values here were raised to read on the
// translucent grey of a glass island as well as on black.

/// The island's values on black.
enum ZenithIsland {
    /// Text and glyphs, in three steps.
    static let primary = Color.white.opacity(0.95)
    static let secondary = Color.white.opacity(0.55)
    static let tertiary = Color.white.opacity(0.35)

    /// A card's or a control's outline, and the one a hovered, highlighted
    /// or emphasised one takes.
    /// Strong enough to survive the translucent grey of a glass island.
    static let hairline = Color.white.opacity(0.12)
    static let strongHairline = Color.white.opacity(0.28)
    /// Increase Contrast asks for an outline that can be seen.
    static let contrastHairline = Color.white.opacity(0.4)

    /// A card's lift (none: the second redesign draws no lifted cards), the
    /// wash under the pointer and a press.
    static let lift = Color.clear
    static let hoverFill = Color.white.opacity(0.06)
    static let pressedFill = Color.white.opacity(0.10)

    /// The system accent, read from AppKit: the island tints its controls
    /// white, and the selection must still wear the accent.
    static let accent = Color(nsColor: .controlAccentColor)

    /// Upstream's island radii, moved onto the `ZenithRadius` steps: large
    /// cards, which sit on the page, run concentric with the island's corner
    /// (`cardRadius`, ZenithIslandKit), smaller ones take `card`, controls `large`.
    static func radius(_ upstream: CGFloat) -> CGFloat {
        if upstream >= 16 { return cardRadius }
        if upstream >= 11 { return ZenithRadius.card }
        if upstream >= 8 { return ZenithRadius.large }
        if upstream >= 6 { return ZenithRadius.medium }
        return ZenithRadius.small
    }

    static func outline(_ contrast: ColorSchemeContrast, emphasised: Bool = false) -> Color {
        if contrast == .increased { return contrastHairline }
        return emphasised ? strongHairline : hairline
    }
}

// MARK: - Section label

/// A heading inside a page: small mono capitals with light tracking, as the
/// panel and Settings label their groups.
struct ZenithIslandSectionLabel: View {
    let text: String
    var color: Color = ZenithIsland.secondary

    var body: some View {
        Text(text)
            .modifier(ZenithIslandLabelStyle(color: color))
    }
}

/// The section label's look, for a label that is not a plain string.
struct ZenithIslandLabelStyle: ViewModifier {
    var color: Color = ZenithIsland.secondary

    func body(content: Content) -> some View {
        content
            .font(ZenithType.mono(10, weight: .medium))
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(color)
    }
}

// MARK: - Cards and tiles

extension View {
    /// A card in the island: the faintest lift under a hairline. A `selected`
    /// card, such as a pinned clipboard entry, takes the stronger hairline;
    /// it is a state, not a selection, so it stays grey.
    func zenithIslandCard(cornerRadius: CGFloat = ZenithRadius.panel, selected: Bool = false) -> some View {
        modifier(ZenithIslandCard(cornerRadius: cornerRadius, selected: selected))
    }

    /// An outline only, for a block inside a card or an icon's well.
    func zenithIslandOutline<S: InsettableShape>(_ shape: S, emphasised: Bool = false, visible: Bool = true) -> some View {
        modifier(ZenithIslandOutline(shape: shape, emphasised: emphasised, visible: visible))
    }

    /// The Style Kit's selected state on black: the accent, or a status colour
    /// that means something, at 10% fill and 20% outline.
    func zenithIslandSelection<S: InsettableShape>(_ isSelected: Bool, in shape: S,
                                                  tint: Color = ZenithIsland.accent) -> some View {
        background(shape.fill(isSelected ? ZenithStatus.fill(tint) : Color.clear))
            .overlay(shape.strokeBorder(isSelected ? ZenithStatus.stroke(tint) : Color.clear).allowsHitTesting(false))
    }
}

extension View {
    /// One of a few choices drawn as outlined shapes: a hairline when not
    /// chosen, the accent's 10/20 when chosen. The content sets its own colour.
    func zenithIslandChoice<S: InsettableShape>(_ isSelected: Bool, in shape: S,
                                               tint: Color = ZenithIsland.accent) -> some View {
        modifier(ZenithIslandChoice(isSelected: isSelected, shape: shape, tint: tint))
    }
}

private struct ZenithIslandChoice<S: InsettableShape>: ViewModifier {
    let isSelected: Bool
    let shape: S
    let tint: Color
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .background(shape.fill(isSelected ? ZenithStatus.fill(tint) : Color.clear))
            .overlay {
                shape.strokeBorder(isSelected ? ZenithStatus.stroke(tint) : ZenithIsland.outline(contrast),
                                   lineWidth: 0.75)
                    .allowsHitTesting(false)
            }
    }
}

private struct ZenithIslandCard: ViewModifier {
    let cornerRadius: CGFloat
    let selected: Bool
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(selected ? ZenithIsland.hoverFill : ZenithIsland.lift, in: shape)
            .overlay {
                shape.strokeBorder(ZenithIsland.outline(contrast, emphasised: selected), lineWidth: 0.75)
                    .allowsHitTesting(false)
            }
    }
}

private struct ZenithIslandOutline<S: InsettableShape>: ViewModifier {
    let shape: S
    let emphasised: Bool
    let visible: Bool
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content.overlay {
            shape.strokeBorder(visible ? ZenithIsland.outline(contrast, emphasised: emphasised) : .clear, lineWidth: 0.75)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Glyphs

private struct ZenithIslandHoverKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Whether the pointer is over the control a glyph belongs to.
    var zenithIslandHovered: Bool {
        get { self[ZenithIslandHoverKey.self] }
        set { self[ZenithIslandHoverKey.self] = newValue }
    }
}

extension View {
    /// A chrome glyph: grey at rest, nearly white under the pointer, the
    /// accent when its control is the selected one.
    func zenithIslandGlyph(selected: Bool = false) -> some View {
        modifier(ZenithIslandGlyph(selected: selected))
    }
}

private struct ZenithIslandGlyph: ViewModifier {
    let selected: Bool
    @Environment(\.zenithIslandHovered) private var hovered

    func body(content: Content) -> some View {
        content.foregroundStyle(selected ? ZenithIsland.accent : hovered ? ZenithIsland.primary : ZenithIsland.secondary)
    }
}

/// Tracks the pointer over a control and hands it to the glyphs inside.
private struct ZenithIslandHoverTracking: ViewModifier {
    @Binding var hovering: Bool

    func body(content: Content) -> some View {
        content
            .environment(\.zenithIslandHovered, hovering)
            .onHover { hovering = $0 }
            .animation(ZenithMotion.respecting(IslandMotion.easeOut(ZenithMotion.fast)), value: hovering)
    }
}

extension View {
    /// Tracks the pointer over this view and tells the glyphs inside, for a
    /// control that draws no wash of its own.
    func zenithIslandHoverTracked() -> some View {
        modifier(ZenithIslandHoverState())
    }
}

private struct ZenithIslandHoverState: ViewModifier {
    @State private var hovering = false
    @Environment(\.isEnabled) private var enabled

    func body(content: Content) -> some View {
        content.modifier(ZenithIslandHoverTracking(hovering: Binding(get: { hovering && enabled },
                                                                    set: { hovering = $0 })))
    }
}

// MARK: - Header bar

/// The way back in the island's top row: a plain chevron and the page's
/// name, both brightening under the pointer. Nothing is drawn around them.
struct ZenithBandBackLabel: View {
    let title: String
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "chevron.left")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(hovering ? ZenithIsland.primary : ZenithIsland.secondary)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .tracking(-0.2)
                .foregroundStyle(ZenithIsland.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .frame(height: 28)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(ZenithMotion.respecting(IslandMotion.easeOut(ZenithMotion.fast)), value: hovering)
    }
}

/// What a menu in the island's top row reads: its current choice in mono 12
/// with a chevron, grey at rest and bright under the pointer, no chrome.
struct ZenithBandMenuTitle: View {
    let title: String
    var symbol: String? = nil
    var truncation: Text.TruncationMode = .tail
    @Environment(\.zenithIslandHovered) private var hovered

    var body: some View {
        HStack(spacing: 5) {
            if let symbol {
                Image(systemName: symbol).font(.system(size: 11, weight: .medium))
            }
            Text(title).font(ZenithType.mono(12, weight: .medium)).lineLimit(1).truncationMode(truncation)
            Image(systemName: "chevron.down").font(.system(size: 8.5, weight: .semibold)).opacity(0.8)
        }
        .foregroundStyle(hovered ? ZenithIsland.primary : Color.white.opacity(0.7))
        .padding(.horizontal, 6)
        .frame(height: 28)
        .contentShape(Rectangle())
    }
}

// MARK: - Icon buttons

/// The island's icon button: a plain glyph at 55% that brightens to 95%
/// under the pointer, with no box around it. The button that stands for the
/// current choice (the pin, the player's lyrics or queue) wears the accent
/// and a small accent mark under the glyph, so it never rests on colour alone.
struct ZenithIslandIconChrome: ViewModifier {
    let selected: Bool
    var cornerRadius: CGFloat = 9
    @State private var hovering = false
    @Environment(\.isEnabled) private var enabled

    func body(content: Content) -> some View {
        content
            .zenithIslandGlyph(selected: selected)
            .overlay(alignment: .bottom) {
                if selected {
                    Capsule().fill(ZenithIsland.accent).frame(width: 8, height: 2).padding(.bottom, 2)
                        .allowsHitTesting(false)
                }
            }
            .modifier(ZenithIslandHoverTracking(hovering: Binding(get: { hovering && enabled },
                                                                 set: { hovering = $0 })))
    }
}

// MARK: - Section gallery

extension View {
    /// A tile of the section gallery. The current section wears the accent;
    /// the keyboard's highlight is a brighter outline, accented on the
    /// current tile, so the cursor still shows where Return lands.
    func zenithIslandSectionTile(highlighted: Bool, selected: Bool,
                                 cornerRadius: CGFloat = ZenithRadius.panel) -> some View {
        modifier(ZenithIslandSectionTile(highlighted: highlighted, selected: selected, cornerRadius: cornerRadius))
    }
}

private struct ZenithIslandSectionTile: ViewModifier {
    let highlighted: Bool
    let selected: Bool
    let cornerRadius: CGFloat
    @State private var hovering = false
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(shape.fill(fill))
            .overlay { shape.strokeBorder(stroke, lineWidth: highlighted ? 1 : 0.75).allowsHitTesting(false) }
            .environment(\.zenithIslandHovered, hovering || highlighted)
            .onHover { hovering = $0 }
            .animation(ZenithMotion.respecting(IslandMotion.easeOut(ZenithMotion.fast)), value: hovering)
    }

    private var fill: Color {
        if selected { return ZenithStatus.fill(ZenithIsland.accent) }
        return highlighted || hovering ? ZenithIsland.hoverFill : ZenithIsland.lift
    }

    private var stroke: Color {
        if selected { return ZenithIsland.accent.opacity(highlighted ? 0.5 : 0.2) }
        if highlighted { return Color.white.opacity(0.4) }
        return ZenithIsland.outline(contrast)
    }
}

// MARK: - Action tiles

extension View {
    /// The glyph well of a shortcut tile: a hairline circle that lifts under
    /// the pointer. An active tile takes its colour in the 10/20/100 form:
    /// the accent for a choice, a status colour for a state to notice.
    func zenithIslandActionWell(active: Bool, tint: Color) -> some View {
        modifier(ZenithIslandActionWell(active: active, tint: tint))
    }
}

private struct ZenithIslandActionWell: ViewModifier {
    let active: Bool
    let tint: Color
    @State private var hovering = false
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .foregroundStyle(active ? tint : ZenithIsland.primary)
            .background(Circle().fill(active ? ZenithStatus.fill(tint) : hovering ? ZenithIsland.hoverFill : ZenithIsland.lift))
            .overlay {
                Circle().strokeBorder(active ? ZenithStatus.stroke(tint) : ZenithIsland.outline(contrast, emphasised: hovering),
                                      lineWidth: 0.75)
                    .allowsHitTesting(false)
            }
            .onHover { hovering = $0 }
            .animation(ZenithMotion.respecting(IslandMotion.easeOut(ZenithMotion.fast)), value: hovering)
    }
}

// MARK: - Pills, chips and buttons

/// An empty page's next step, or any word on a pill. The step the page
/// leads to is the island's one solid action (`ZenithIslandPrimaryAction`);
/// any other is grey under a hairline.
struct ZenithIslandPill: ViewModifier {
    var prominent = false
    @Environment(\.colorSchemeContrast) private var contrast

    @ViewBuilder func body(content: Content) -> some View {
        if prominent {
            content.modifier(ZenithIslandPrimaryAction())
        } else {
            content
                .foregroundStyle(ZenithIsland.secondary)
                .overlay {
                    Capsule().strokeBorder(ZenithIsland.outline(contrast), lineWidth: 1)
                        .allowsHitTesting(false)
                }
        }
    }
}

/// An outlined pill that can be chosen. The selected one takes the accent in
/// the 10/20/100 form; the others stay grey under a hairline.
struct ZenithIslandChipStyle: ButtonStyle {
    var isSelected = false
    var tint: Color = ZenithIsland.accent
    var height: CGFloat = 22

    func makeBody(configuration: Configuration) -> some View {
        ZenithIslandChip(label: configuration.label, isSelected: isSelected, isPressed: configuration.isPressed,
                         tint: tint, height: height)
    }
}

private struct ZenithIslandChip<Label: View>: View {
    let label: Label
    let isSelected: Bool
    let isPressed: Bool
    let tint: Color
    let height: CGFloat
    @State private var hovering = false
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        label
            .font(.system(size: 11, weight: .medium))
            .monospacedDigit()
            .lineLimit(1)
            .foregroundStyle(isSelected ? tint : hovering ? ZenithIsland.primary : ZenithIsland.secondary)
            .padding(.horizontal, 9)
            .frame(height: height)
            .background(Capsule().fill(fill))
            .overlay(Capsule().strokeBorder(isSelected ? ZenithStatus.stroke(tint) : ZenithIsland.outline(contrast),
                                            lineWidth: 0.75))
            .contentShape(Capsule())
            .opacity(enabled ? 1 : 0.4)
            .onHover { hovering = $0 }
            .animation(ZenithMotion.respecting(IslandMotion.easeOut(ZenithMotion.fast)), value: hovering)
    }

    private var fill: Color {
        if isSelected { return tint.opacity(isPressed ? 0.18 : 0.10) }
        if isPressed { return ZenithIsland.pressedFill }
        return hovering ? ZenithIsland.hoverFill : Color.clear
    }
}

/// A row of chips standing in for a segmented control, one per choice.
struct ZenithIslandSegmented<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(value: Value, title: String)]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let selected = option.value == selection
                Button { selection = option.value } label: {
                    Text(option.title).frame(maxWidth: .infinity)
                }
                .buttonStyle(ZenithIslandChipStyle(isSelected: selected))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}

/// A plain button on black, where upstream used the system's bordered look:
/// grey words under a hairline that lift under the pointer. A `prominent`
/// one, the page's main step, reads brighter under a stronger outline.
struct ZenithIslandOutlineButtonStyle: ButtonStyle {
    var prominent = false
    var height: CGFloat = 24

    func makeBody(configuration: Configuration) -> some View {
        ZenithIslandOutlineButton(label: configuration.label, prominent: prominent,
                                  isPressed: configuration.isPressed, height: height)
    }
}

private struct ZenithIslandOutlineButton<Label: View>: View {
    let label: Label
    let prominent: Bool
    let isPressed: Bool
    let height: CGFloat
    @State private var hovering = false
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        label
            .font(.system(size: 11.5, weight: prominent ? .semibold : .medium))
            .lineLimit(1)
            .foregroundStyle(prominent || hovering ? ZenithIsland.primary : ZenithIsland.secondary)
            .padding(.horizontal, 11)
            .frame(height: height)
            .background(Capsule().fill(isPressed ? ZenithIsland.pressedFill : hovering ? ZenithIsland.hoverFill : .clear))
            .overlay(Capsule().strokeBorder(ZenithIsland.outline(contrast, emphasised: prominent || hovering),
                                            lineWidth: 0.75))
            .contentShape(Capsule())
            .opacity(enabled ? 1 : 0.4)
            .onHover { hovering = $0 }
            .animation(ZenithMotion.respecting(IslandMotion.easeOut(ZenithMotion.fast)), value: hovering)
    }
}

/// A text field's well: a hairline that brightens while it has the keys.
struct ZenithIslandFieldChrome: ViewModifier {
    var focused = false
    var visible = true
    var cornerRadius: CGFloat = ZenithRadius.large
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(shape.fill(visible ? ZenithIsland.lift : .clear))
            .overlay {
                shape.strokeBorder(visible ? ZenithIsland.outline(contrast, emphasised: focused) : .clear, lineWidth: 0.75)
                    .allowsHitTesting(false)
            }
    }
}

// MARK: - Tags

/// A small mono tag, such as an agent's plan, a multiple or a deployment's
/// target: an outlined capsule with grey words. A colour that means
/// something (a provider, a status) shows only as a 5-point dot inside it;
/// an `emphasised` tag (production) reads a step brighter.
struct ZenithIslandTag: View {
    let text: String
    /// The dot's colour, when the tag carries one.
    var tint: Color? = nil
    var uppercase = true
    var emphasised = false
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: 4) {
            if let tint {
                Circle().fill(tint).frame(width: 5, height: 5).accessibilityHidden(true)
            }
            Text(uppercase ? text.uppercased() : text)
                .font(ZenithType.mono(10, weight: .medium))
                .foregroundStyle(Color.white.opacity(emphasised ? 0.85 : 0.5))
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 1.5)
        .overlay {
            Capsule().strokeBorder(contrast == .increased ? ZenithIsland.contrastHairline
                                   : Color.white.opacity(emphasised ? 0.3 : 0.15), lineWidth: 1)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Figures

extension View {
    /// Metadata in the island, such as a time, a size, a count or a key:
    /// mono, so it reads as data beside the words.
    func zenithIslandMeta(_ size: CGFloat = 9.5, weight: Font.Weight = .regular) -> some View {
        font(ZenithType.mono(size, weight: weight))
    }
}

// MARK: - Switches

/// Zenith's switch (`ZenithSwitch`, as `ZenithSwitchStyle` draws it) at the
/// island's control sizes, after its label. Drawn in SwiftUI: AppKit's
/// NSSwitch, changed from elsewhere while it is on screen, can lay a window
/// out in the middle of SwiftUI's update and spin it.
struct ZenithIslandSwitchStyle: ToggleStyle {
    /// 1 is AppKit's regular switch, 0.88 its small one.
    var scale: CGFloat = 1

    // A custom style is handed the label even under `labelsHidden()`, so it
    // reads the visibility itself (macOS 15+), as ZenithSwitchStyle does.
    @ViewBuilder func makeBody(configuration: Configuration) -> some View {
        if #available(macOS 15.0, *) {
            ZenithIslandSwitchBody(configuration: configuration, scale: scale)
        } else {
            zenithIslandSwitchBody(configuration, scale: scale, showsLabel: true)
        }
    }
}

@available(macOS 15.0, *)
private struct ZenithIslandSwitchBody: View {
    let configuration: ToggleStyleConfiguration
    let scale: CGFloat
    @Environment(\.labelsVisibility) private var labelsVisibility

    var body: some View {
        zenithIslandSwitchBody(configuration, scale: scale, showsLabel: labelsVisibility != .hidden)
    }
}

@MainActor @ViewBuilder
private func zenithIslandSwitchBody(_ configuration: ToggleStyleConfiguration, scale: CGFloat, showsLabel: Bool) -> some View {
    HStack(spacing: 8) {
        if showsLabel { configuration.label }
        ZenithSwitch(isOn: configuration.$isOn)
            // The island tints its controls white; the switch keeps the accent.
            .tint(ZenithIsland.accent)
            .scaleEffect(scale)
            .frame(width: 34 * scale, height: 20 * scale)
    }
    .accessibilityRepresentation {
        Toggle(isOn: configuration.$isOn) { configuration.label }
    }
}

extension View {
    /// Zenith's switch where a view shared with another host is in the
    /// island, the system switch elsewhere.
    @ViewBuilder func zenithIslandSwitches(_ inIsland: Bool, scale: CGFloat = 0.88) -> some View {
        if inIsland {
            toggleStyle(ZenithIslandSwitchStyle(scale: scale))
        } else {
            toggleStyle(.switch)
        }
    }
}

// MARK: - Calendar days

/// A day in the island's month grid and week strip. Today keeps the
/// calendar's own red disc; a chosen day takes the accent's 10/20/100 ring
/// instead of a white disc.
struct ZenithIslandDayMark: ViewModifier {
    let today: Bool
    let selected: Bool
    let todayTint: Color

    func body(content: Content) -> some View {
        content
            .background(Circle().fill(today ? todayTint : selected ? ZenithStatus.fill(ZenithIsland.accent) : .clear))
            .overlay {
                Circle().strokeBorder(selected && !today ? ZenithStatus.stroke(ZenithIsland.accent) : .clear, lineWidth: 0.75)
                    .allowsHitTesting(false)
            }
    }
}
