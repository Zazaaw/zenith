// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: the menu bar panel's chrome in the Settings language of
// p441z.my.id, scaled down for a 332 pt panel. Grey hairline surfaces, mono
// uppercase labels, the accent only on what is selected, and status colour
// only where a state is meant. Upstream's panel views reach these through the
// few shared building blocks they already use (`PanelSection`, `panelCard`,
// the tab strip, the chip style, the footer), so a sync only meets one-line
// hooks marked `// Zenith fork`.
//
// The island hosts the same sections with `notchPresentation` set; its own
// surfaces (NotchControlSurface, black tabs and footer) are left as they are.

/// The panel's outlines. Increase Contrast asks for an outline that can be
/// seen, so the hairlines answer it the way upstream's panel border did.
enum ZenithPanelSurface {
    static var hairline: Color {
        raisedContrast ? Color.primary.opacity(0.26) : ZenithSurface.hairline
    }

    static var controlStroke: Color {
        raisedContrast ? Color.primary.opacity(0.32) : ZenithSurface.tileStroke
    }

    /// A pressed control, one step above the hover fill.
    static let pressedFill = Color.primary.opacity(0.09)

    private static var raisedContrast: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
    }
}

// MARK: - Section label

/// A section's heading: small mono capitals with light tracking, as the
/// Settings sidebar labels its groups.
struct ZenithPanelSectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(ZenithType.mono(10, weight: .medium))
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Cards and tiles

extension View {
    /// A card in the panel: the faintest lift under a hairline.
    func zenithPanelCardSurface() -> some View {
        background(ZenithSurface.cardFill,
                   in: RoundedRectangle(cornerRadius: ZenithRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: ZenithRadius.card, style: .continuous)
                .strokeBorder(ZenithPanelSurface.hairline))
    }

    /// A block inside a card, such as a temperature reading: an outline only,
    /// so it never reads as a grey slab on the card.
    func zenithPanelTile(cornerRadius: CGFloat = ZenithRadius.large) -> some View {
        overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(ZenithPanelSurface.hairline))
    }

    /// The Style Kit's selected state: the accent at 10% fill and 20%
    /// outline under full-strength content.
    func zenithPanelSelection<S: InsettableShape>(_ isSelected: Bool, in shape: S,
                                                 tint: Color = .accentColor) -> some View {
        background(shape.fill(isSelected ? ZenithStatus.fill(tint) : Color.clear))
            .overlay(shape.strokeBorder(isSelected ? ZenithStatus.stroke(tint) : Color.clear))
    }
}

// MARK: - Tab strip

extension View {
    /// The section tab strip around the icon tabs.
    func zenithPanelTabStrip(notch: Bool) -> some View {
        modifier(ZenithPanelTabStrip(notch: notch))
    }

    /// One icon tab: a grey glyph, and the accent only on the selected tab.
    func zenithPanelTab(isActive: Bool, notch: Bool) -> some View {
        modifier(ZenithPanelTab(isActive: isActive, notch: notch))
    }
}

private struct ZenithPanelTabStrip: ViewModifier {
    let notch: Bool
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if notch {
            content
                .background(RoundedRectangle(cornerRadius: ZenithRadius.card, style: .continuous).fill(.black))
                .overlay(RoundedRectangle(cornerRadius: ZenithRadius.card, style: .continuous)
                    .strokeBorder(PanelSurface.border(for: colorScheme), lineWidth: 0.7))
        } else {
            content.zenithPanelCardSurface()
        }
    }
}

private struct ZenithPanelTab: ViewModifier {
    let isActive: Bool
    let notch: Bool
    @State private var hovering = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: ZenithRadius.large, style: .continuous)
        if notch {
            content
                .foregroundStyle(isActive ? Color.white : Color.secondary.opacity(0.86))
                .background(shape.fill(isActive ? Color.black : Color.clear))
        } else {
            content
                .foregroundStyle(isActive ? Color.accentColor : (hovering ? Color.primary : Color.secondary))
                .background(shape.fill(!isActive && hovering ? ZenithSurface.tileFill : Color.clear))
                .zenithPanelSelection(isActive, in: shape)
                .onHover { hovering = $0 }
                .animation(ZenithMotion.respecting(.easeOut(duration: ZenithMotion.fast)), value: hovering)
        }
    }
}

// MARK: - Chips and segmented choices

/// An outlined pill. The selected one takes the accent in the Style Kit's
/// 10% / 20% / 100% form instead of a filled capsule.
struct ZenithPanelChipStyle: ButtonStyle {
    var isSelected = false

    func makeBody(configuration: Configuration) -> some View {
        ZenithPanelChip(label: configuration.label, isSelected: isSelected,
                        isPressed: configuration.isPressed)
    }
}

private struct ZenithPanelChip<Label: View>: View {
    let label: Label
    let isSelected: Bool
    let isPressed: Bool
    @State private var hovering = false

    var body: some View {
        label
            .font(.system(size: 11, weight: .medium))
            .monospacedDigit()
            .lineLimit(1)
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            .padding(.horizontal, 8)
            .frame(minHeight: 22)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(fill))
            .overlay(Capsule().strokeBorder(stroke))
            .contentShape(Capsule())
            .onHover { hovering = $0 }
            .animation(ZenithMotion.respecting(.easeOut(duration: ZenithMotion.fast)), value: hovering)
    }

    private var fill: Color {
        if isSelected { return Color.accentColor.opacity(isPressed ? 0.18 : 0.10) }
        if isPressed { return ZenithPanelSurface.pressedFill }
        return hovering ? ZenithSurface.tileFill : Color.clear
    }

    private var stroke: Color {
        isSelected ? ZenithStatus.stroke(.accentColor) : ZenithPanelSurface.controlStroke
    }
}

/// A row of chips standing in for a segmented control, one per choice.
struct ZenithPanelSegmented<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(value: Value, title: String)]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let selected = option.value == selection
                Button(option.title) { selection = option.value }
                    .buttonStyle(ZenithPanelChipStyle(isSelected: selected))
                    .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}

// MARK: - Buttons

/// An outlined button, as the footer's Settings and Quit: grey text under a
/// hairline that lifts on hover. The label brings its own font and size.
struct ZenithPanelOutlineButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = ZenithRadius.large
    /// The island draws its controls on black.
    var notch = false

    func makeBody(configuration: Configuration) -> some View {
        ZenithPanelOutlineButton(label: configuration.label, isPressed: configuration.isPressed,
                                 cornerRadius: cornerRadius, notch: notch)
    }
}

private struct ZenithPanelOutlineButton<Label: View>: View {
    let label: Label
    let isPressed: Bool
    let cornerRadius: CGFloat
    let notch: Bool
    @State private var hovering = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        label
            .foregroundStyle(hovering ? Color.primary : Color.secondary)
            .background(shape.fill(fill))
            .overlay(shape.strokeBorder(notch ? PanelSurface.border(for: colorScheme) : ZenithPanelSurface.controlStroke))
            .contentShape(shape)
            .onHover { hovering = $0 }
            .animation(ZenithMotion.respecting(.easeOut(duration: ZenithMotion.fast)), value: hovering)
    }

    private var fill: Color {
        if isPressed { return ZenithPanelSurface.pressedFill }
        if hovering { return ZenithSurface.tileFill }
        return notch ? .black : .clear
    }
}

// MARK: - Badges

/// A small mono tag, such as "Beta" or a shortcut, in a status colour's
/// 10% / 20% / 100% form, or grey under a hairline when no state is meant.
struct ZenithPanelTag: View {
    let text: String
    var tint: Color? = nil
    var uppercase = true

    var body: some View {
        Text(uppercase ? text.uppercased() : text)
            .font(ZenithType.mono(8.5, weight: .semibold))
            .foregroundStyle(tint.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.secondary))
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(Capsule().fill(tint.map(ZenithStatus.fill) ?? Color.clear))
            .overlay(Capsule().strokeBorder(tint.map(ZenithStatus.stroke) ?? ZenithPanelSurface.controlStroke))
    }
}

// MARK: - Switches

/// How large a panel switch draws, after the AppKit control sizes it replaces.
enum ZenithPanelSwitchSize {
    case regular, small, mini

    fileprivate var scale: CGFloat {
        switch self {
        case .regular: return 1
        case .small: return 0.88
        case .mini: return 0.76
        }
    }
}

extension View {
    /// A label-hidden switch in the panel, drawn by `ZenithSwitchStyle`.
    /// AppKit's NSSwitch, when its value changes from elsewhere while it is
    /// on screen, lays the window out in the middle of SwiftUI's update, the
    /// cycle that spun Settings. The style draws at 34 by 20 pt; the panel
    /// scales it to the AppKit size the row used, frame included.
    func zenithPanelSwitch(_ size: ZenithPanelSwitchSize = .small) -> some View {
        toggleStyle(ZenithSwitchStyle())
            .scaleEffect(size.scale)
            .frame(width: 34 * size.scale, height: 20 * size.scale)
    }
}

/// A switch that shows its own label before it, for the panel's few switches
/// that are not given a separate title.
struct ZenithPanelLabeledSwitchStyle: ToggleStyle {
    var size: ZenithPanelSwitchSize = .mini

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.label
                .accessibilityHidden(true)
            Toggle(isOn: configuration.$isOn) { configuration.label }
                .labelsHidden()
                .zenithPanelSwitch(size)
        }
    }
}
