// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: what every kit component shares: the page's category tint
// from the environment, the grouped surfaces, the motion clock, the ⓘ and
// the chips. See docs/SETTINGS-KIT.md.

// MARK: - The page's category

private struct ZenithCategoryOverrideKey: EnvironmentKey {
    static let defaultValue: SettingsSidebarGroup? = nil
}

extension EnvironmentValues {
    /// A category set with `.zenithCategory(_:)`, ahead of the page's own.
    fileprivate var zenithCategoryOverride: SettingsSidebarGroup? {
        get { self[ZenithCategoryOverrideKey.self] }
        set { self[ZenithCategoryOverrideKey.self] = newValue }
    }

    /// The open page's sidebar group: the one set with `.zenithCategory(_:)`,
    /// else the group of the page Settings shows, else Zenith's own.
    var zenithCategory: SettingsSidebarGroup {
        zenithCategoryOverride ?? settingsPageIcon.map { SettingsSidebarGroup.of($0.id) } ?? .zenith
    }

    /// The open page's tint: hero aura, stage, picker tiles.
    var zenithTint: ZenithCategoryTint { ZenithCategoryTint.of(zenithCategory) }
}

extension View {
    /// Draws the kit components inside in `group`'s tint instead of the page's.
    func zenithCategory(_ group: SettingsSidebarGroup) -> some View {
        environment(\.zenithCategoryOverride, group)
    }
}

// MARK: - Surfaces

/// The grouped look of the redesigned pages: a quiet lifted card with a
/// hairline. Opaque under Reduce Transparency, a firmer line under Increase
/// Contrast.
enum ZenithKitSurface {
    static let groupRadius: CGFloat = 14
    static let stageRadius: CGFloat = 16
    static let heroRadius: CGFloat = 22
    /// A row's height in a grouped card.
    static let rowHeight: CGFloat = 40
    /// A row's text inset from the card's edge.
    static let rowInset: CGFloat = 14

    static func groupFill(dark: Bool, opaque: Bool) -> Color {
        switch (dark, opaque) {
        case (true, false): return Color.white.opacity(0.045)
        case (true, true): return Color(white: 0.17)
        case (false, false): return Color.white.opacity(0.72)
        case (false, true): return Color.white
        }
    }

    static func hairline(highContrast: Bool) -> Color {
        Color.primary.opacity(highContrast ? 0.28 : 0.08)
    }

    static func separator(highContrast: Bool) -> Color {
        Color.primary.opacity(highContrast ? 0.22 : 0.07)
    }
}

private struct ZenithGroupBackground: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            // Over the window's own colour, so the dot grid stays behind the card.
            .background {
                shape.fill(Color(nsColor: .windowBackgroundColor))
                    .overlay(shape.fill(ZenithKitSurface.groupFill(dark: colorScheme == .dark,
                                                                   opaque: reduceTransparency)))
            }
            .overlay(shape.strokeBorder(ZenithKitSurface.hairline(highContrast: contrast == .increased)))
    }
}

extension View {
    /// The grouped card behind a section's rows.
    func zenithGroupBackground(cornerRadius: CGFloat = ZenithKitSurface.groupRadius) -> some View {
        modifier(ZenithGroupBackground(cornerRadius: cornerRadius))
    }
}

/// The hairline between two rows of a grouped card, inset like the rows' text.
struct ZenithRowSeparator: View {
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Rectangle()
            .fill(ZenithKitSurface.separator(highContrast: contrast == .increased))
            .frame(height: 1)
            .padding(.leading, ZenithKitSurface.rowInset)
            .accessibilityHidden(true)
    }
}

/// A section's title, bold, outside its card.
struct ZenithSectionTitle: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .bold))
            .padding(.leading, 4)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Easing helpers for kit art.
enum ZenithKitEase {
    static func smooth(_ x: Double) -> Double { x < 0 ? 0 : (x > 1 ? 1 : x * x * (3 - 2 * x)) }
    /// 0…1…0 over `period` seconds.
    static func pulse(_ t: Double, period: Double) -> Double { (sin(t / period * 2 * .pi) + 1) / 2 }
    /// A landing with a little bounce.
    static func bounceIn(_ x: Double) -> Double {
        guard x > 0 else { return 0 }
        guard x < 1 else { return 1 }
        return 1 - pow(1 - x, 3) * cos(x * .pi * 2.2)
    }
    /// 0…1 repeating every `period` seconds, shifted by `offset` of a period.
    static func phase(_ t: Double, period: Double, offset: Double = 0) -> Double {
        let p = (t / period + offset).truncatingRemainder(dividingBy: 1)
        return p < 0 ? p + 1 : p
    }
}

// MARK: - ⓘ

/// The ⓘ beside a row's title: hovering shows the text as a tooltip,
/// clicking (or Space with keyboard focus) opens it in a popover. VoiceOver
/// reads the text as the row's hint, so the button itself stays quiet.
///
///     HStack { Text("Volume"); ZenithInfoButton(title: "Volume", text: "Mechakey’s own level…") }
struct ZenithInfoButton: View {
    let title: String
    let text: String
    @State private var shown = false

    var body: some View {
        Button { shown.toggle() } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.tertiary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(text)
        .accessibilityLabel(ZenithKitStrings.info(title))
        .accessibilityHint(text)
        .popover(isPresented: $shown, arrowEdge: .bottom) {
            Text(text)
                .font(ZenithType.footnote)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 260, alignment: .leading)
                .padding(12)
        }
    }
}

/// A row's title with its ⓘ and, under it, the essential line when there is one.
struct ZenithRowLabel: View {
    let title: String
    var info: String?
    var essential: String?
    var badge: String?

    var body: some View {
        let shown = ZenithCaptionRule.presentation(info: info, essential: essential)
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(title)
                    .font(ZenithType.body)
                    .accessibilityHint(shown.info ?? "")
                if let badge { ZenithBadge(text: badge) }
                if let info = shown.info { ZenithInfoButton(title: title, text: info) }
            }
            if let inline = shown.inline {
                Text(inline)
                    .font(ZenithType.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// A small mono tag beside a title (NEW, BETA), in the Style Kit's 10/20/100 form.
struct ZenithBadge: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(ZenithType.mono(8.5, weight: .semibold))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(ZenithStatus.fill(Color.accentColor), in: Capsule())
            .overlay(Capsule().strokeBorder(ZenithStatus.stroke(Color.accentColor)))
            .accessibilityHidden(true)
    }
}

// MARK: - Chips

/// A short fact in a capsule, with an optional status dot: the hero's
/// "● On", "Cherry MX Blue", "7 packs".
///
///     ZenithChip("On", dot: ZenithStatus.success)
///     ZenithChip("7 packs")
struct ZenithChip: View, Identifiable {
    let text: String
    var dot: Color?

    init(_ text: String, dot: Color? = nil) {
        self.text = text
        self.dot = dot
    }

    var id: String { text }

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: 5) {
            if let dot {
                Circle().fill(dot).frame(width: 6, height: 6)
                    .shadow(color: dot.opacity(0.8), radius: 3)
            }
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary.opacity(0.85))
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .frame(height: 22)
        .background(Capsule().fill(Color.primary.opacity(0.06)))
        .overlay(Capsule().strokeBorder(Color.primary.opacity(contrast == .increased ? 0.3 : 0.08)))
        .accessibilityElement(children: .combine)
    }
}
