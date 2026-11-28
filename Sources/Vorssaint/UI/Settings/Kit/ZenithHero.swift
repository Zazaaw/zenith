// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: the hero a feature page opens with (the approved left-aligned
// mockup): the page's big icon on a breathing aura in its category's tint,
// a few twinkling stars, the feature's own little animation, then the
// category, title, subtitle and chips, and the master switch as an "On"
// pill in the top right corner.

/// A feature page's hero.
///
///     ZenithHero(title: text.title, subtitle: text.subtitle,
///                chips: [ZenithChip(pack.title), ZenithChip("7 packs")],
///                isOn: enabledBinding, switchLabel: text.enable,
///                animation: .mechakey)
///
/// - `isOn`: the feature's master switch. Shown as the "On" pill, and as a
///   leading "● On" chip. Leave it nil for a page without one.
/// - `animation`: the feature's art around its icon (`ZenithHeroAnimation`);
///   leave it out for the icon alone.
/// - The icon and the tint come from the page Settings shows; pass `icon:`
///   or wrap the hero in `.zenithCategory(_:)` to choose others, and
///   `category:` to word the label differently ("AI").
///
/// The art moves only while the page is shown and the window is on screen,
/// and stands still under Reduce Motion or the battery saver (`ZenithKitClock`).
struct ZenithHero<Animation: ZenithHeroAnimation>: View {
    let title: String
    let subtitle: String
    var chips: [ZenithChip] = []
    var isOn: Binding<Bool>?
    var switchLabel: String?
    var switchHint: String?
    var category: String?
    var icon: SettingsPageIcon?
    let animation: Animation

    init(title: String, subtitle: String, chips: [ZenithChip] = [], isOn: Binding<Bool>? = nil,
         switchLabel: String? = nil, switchHint: String? = nil, category: String? = nil,
         icon: SettingsPageIcon? = nil, animation: Animation) {
        self.title = title
        self.subtitle = subtitle
        self.chips = chips
        self.isOn = isOn
        self.switchLabel = switchLabel
        self.switchHint = switchHint
        self.category = category
        self.icon = icon
        self.animation = animation
    }

    @Environment(\.zenithCategory) private var group
    @Environment(\.zenithTint) private var tint
    @Environment(\.settingsPageIcon) private var pageIcon
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    static var artSize: CGFloat { 190 }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: ZenithKitSurface.heroRadius, style: .continuous)
        let dark = colorScheme == .dark
        ZStack(alignment: .topTrailing) {
            ViewThatFits(in: .horizontal) {
                layout(artScale: 1)
                layout(artScale: 0.74)
            }
            if let isOn {
                ZenithMasterPill(isOn: isOn, label: switchLabel ?? title, hint: switchHint)
                    .padding(16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            shape.fill(ZenithKitSurface.groupFill(dark: dark, opaque: true).opacity(dark ? 0.55 : 0.9))
                .overlay(shape.fill(LinearGradient(colors: [tint.deep.color.opacity(dark ? 0.16 : 0.1), .clear],
                                                   startPoint: .leading, endPoint: .center)))
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(ZenithKitSurface.hairline(highContrast: contrast == .increased)))
    }

    private func layout(artScale: CGFloat) -> some View {
        let size = Self.artSize * artScale
        return HStack(alignment: .center, spacing: 22 * artScale) {
            art.scaleEffect(artScale).frame(width: size, height: size)
            text.frame(minWidth: 250, alignment: .leading)
            Spacer(minLength: 0)
        }
        .padding(.leading, 18 * artScale)
        .padding(.trailing, 20)
        .padding(.vertical, 16)
    }

    private var art: some View {
        let shown = icon ?? pageIcon
        let tint = tint
        let dark = colorScheme == .dark
        return ZenithKitClock { t, moving in
            let context = ZenithHeroArtContext(t: t, moving: moving, tint: tint, dark: dark,
                                               icon: ZenithHeroIcon(page: shown))
            animation.art(context)
                .frame(width: Self.artSize, height: Self.artSize)
                .background {
                    ZenithHeroSky(tint: tint, t: t, dark: dark)
                        .frame(width: 330, height: 330)
                }
        }
        .frame(width: Self.artSize, height: Self.artSize)
        .accessibilityHidden(true)
    }

    private var text: some View {
        let dark = colorScheme == .dark
        let shownChips = (isOn.map { [ZenithHeroStatus.chip(on: $0.wrappedValue)] } ?? []) + chips
        return VStack(alignment: .leading, spacing: 8) {
            Text((category ?? group.categoryLabel).uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(tint.label(dark: dark).color)
            Text(title)
                .font(.system(size: 30, weight: .bold))
                .tracking(-0.6)
                .lineLimit(2)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(maxWidth: 360, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            if !shownChips.isEmpty {
                ViewThatFits(in: .horizontal) {
                    ForEach((1...shownChips.count).reversed(), id: \.self) { count in
                        HStack(spacing: 6) { ForEach(shownChips.prefix(count)) { $0 } }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.trailing, isOn == nil ? 0 : 70)
    }
}

extension ZenithHero where Animation == ZenithHeroIconArt {
    /// A hero with the icon alone, gently floating.
    init(title: String, subtitle: String, chips: [ZenithChip] = [], isOn: Binding<Bool>? = nil,
         switchLabel: String? = nil, switchHint: String? = nil, category: String? = nil,
         icon: SettingsPageIcon? = nil) {
        self.init(title: title, subtitle: subtitle, chips: chips, isOn: isOn, switchLabel: switchLabel,
                  switchHint: switchHint, category: category, icon: icon, animation: ZenithHeroIconArt())
    }
}

/// The hero's status chip.
enum ZenithHeroStatus {
    static func chip(on: Bool) -> ZenithChip {
        on ? ZenithChip(ZenithKitStrings.on, dot: ZenithStatus.success) : ZenithChip(ZenithKitStrings.off)
    }
}

// MARK: - Master pill

/// The feature's master switch as a pill: its state in words and the switch.
/// VoiceOver reads it as one switch named `label`.
struct ZenithMasterPill: View {
    @Binding var isOn: Bool
    let label: String
    var hint: String?
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(spacing: 7) {
            Text(isOn ? ZenithKitStrings.on : ZenithKitStrings.off)
                .font(.system(size: 12, weight: .semibold))
            ZenithSwitch(isOn: $isOn)
        }
        .padding(.leading, 10)
        .padding(.trailing, 4)
        .frame(height: 28)
        .background(Capsule().fill(Color.primary.opacity(0.07)))
        .overlay(Capsule().strokeBorder(Color.primary.opacity(contrast == .increased ? 0.3 : 0.1)))
        .help(hint ?? label)
        .accessibilityElement(children: .ignore)
        .accessibilityRepresentation { Toggle(label, isOn: $isOn) }
    }
}

// MARK: - Icon

/// The page's big icon for the hero, drawn once into the bitmap cache.
struct ZenithHeroIcon: View {
    var page: SettingsPageIcon?
    var size: CGFloat = 88
    /// An Orbit icon by its name (`OrbitIcons`), for art about something that
    /// is not the page itself: a module of the Dynamic Island page.
    var orbitName: String?

    var body: some View {
        Group {
            if let orbitName, let icon = OrbitIcons.named(orbitName) {
                OrbitRasterizedIcon(key: "zenith-hero-orbit|\(orbitName)", size: size) { OrbitIconView(icon: icon) }
                    .accessibilityHidden(true)
            } else if let page {
                SettingsDestinationIcon(id: page.id, symbol: page.symbol, size: size, rich: true)
            } else {
                ZenithHeroIconBase(size: size)
            }
        }
        .shadow(color: .black.opacity(0.4), radius: 14, y: 8)
    }
}

/// The icon's empty squircle, for art that draws its own glyph over it.
struct ZenithHeroIconBase: View {
    var size: CGFloat = 88

    var body: some View {
        OrbitRasterizedIcon(key: "zenith-hero-base", size: size) { OrbitIconBase() }
            .shadow(color: .black.opacity(0.4), radius: 14, y: 8)
            .accessibilityHidden(true)
    }
}

// MARK: - Sky

/// The aura and the stars behind the hero's icon, in one Canvas.
struct ZenithHeroSky: View {
    let tint: ZenithCategoryTint
    let t: Double
    let dark: Bool

    /// x, y (from the centre), twinkle offset, size. The trailing side stays
    /// within the art's square, clear of the title.
    private static let stars: [(CGFloat, CGFloat, Double, CGFloat)] = [
        (-105, -33, 0.0, 9.6), (82, -58, 0.7, 8), (-77, 39, 1.4, 6.4), (88, 30, 2.1, 9.6),
        (-33, -70, 2.8, 6.4), (50, 66, 3.3, 8), (92, -12, 1.0, 6.4), (-132, 6, 1.9, 8),
    ]

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let breath = ZenithKitEase.pulse(t, period: 4)
            let strength = dark ? 1.0 : 0.6
            // The aura breathes, and a second glow drifts around it.
            let radius = 150 * (0.92 + 0.12 * breath)
            context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                                width: radius * 2, height: radius * 2)),
                         with: .radialGradient(Gradient(stops: [
                            .init(color: tint.light.color.opacity(0.5 * strength), location: 0),
                            .init(color: tint.deep.color.opacity(0.2 * strength), location: 0.45),
                            .init(color: tint.deep.color.opacity(0), location: 1),
                         ]), center: center, startRadius: 0, endRadius: radius))
            let angle = t / 4 * 2 * .pi
            let drift = CGPoint(x: center.x + 40 * cos(angle), y: center.y + 18 * sin(angle))
            context.fill(Path(ellipseIn: CGRect(x: drift.x - 95, y: drift.y - 95, width: 190, height: 190)),
                         with: .radialGradient(Gradient(colors: [tint.deep.color.opacity(0.32 * strength),
                                                                 tint.deep.color.opacity(0)]),
                                               center: drift, startRadius: 0, endRadius: 95))
            // Stars.
            let starColor = dark ? Color.white : tint.deep.color
            for star in Self.stars {
                let twinkle = ZenithKitEase.pulse(t + star.2, period: 1.6)
                let side = star.3 * (0.6 + 0.5 * twinkle)
                let point = CGPoint(x: center.x + star.0, y: center.y + star.1)
                context.fill(Self.sparkle(at: point, size: side),
                             with: .color(starColor.opacity(0.15 + 0.6 * twinkle)))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// A four-pointed sparkle `size` across.
    static func sparkle(at center: CGPoint, size: CGFloat) -> Path {
        let r = size / 2
        let waist = r * 0.18
        var path = Path()
        path.move(to: CGPoint(x: center.x, y: center.y - r))
        path.addQuadCurve(to: CGPoint(x: center.x + r, y: center.y), control: CGPoint(x: center.x + waist, y: center.y - waist))
        path.addQuadCurve(to: CGPoint(x: center.x, y: center.y + r), control: CGPoint(x: center.x + waist, y: center.y + waist))
        path.addQuadCurve(to: CGPoint(x: center.x - r, y: center.y), control: CGPoint(x: center.x - waist, y: center.y + waist))
        path.addQuadCurve(to: CGPoint(x: center.x, y: center.y - r), control: CGPoint(x: center.x - waist, y: center.y - waist))
        path.closeSubpath()
        return path
    }
}
