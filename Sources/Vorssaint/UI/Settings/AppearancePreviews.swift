// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI

// Zenith fork: the pictures on Settings → Appearance. The theme's little
// desktops (moved from General), the island opening in each motion style,
// and the island in each glass. They draw over a fixed sample wallpaper: the
// colours are the subject, so they stay the same in Light and Dark Mode.

// MARK: - Choice tile

/// A picture over a name, outlined in the accent colour when chosen.
struct AppearanceChoiceTile<Picture: View>: View {
    let title: String
    var symbol: String? = nil
    let selected: Bool
    var enabled = true
    var pictureHeight: CGFloat = 66
    let action: () -> Void
    @ViewBuilder let picture: () -> Picture

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                picture()
                    .frame(height: pictureHeight)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(selected ? Color.accentColor : Color.primary.opacity(0.12),
                                          lineWidth: selected ? 2 : 1)
                    }
                HStack(spacing: 4) {
                    if let symbol {
                        Image(systemName: symbol).font(.system(size: 10, weight: .semibold))
                    }
                    Text(title)
                        .font(.system(size: 11, weight: selected ? .semibold : .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .foregroundStyle(selected ? Color.accentColor : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(selected ? Color.accentColor.opacity(0.08) : Color.clear,
                        in: RoundedRectangle(cornerRadius: ZenithRadius.card, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: ZenithRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Theme

/// Three little desktops with a window on each: the same picture System
/// Settings uses, so the choice needs no reading.
struct AppearanceThemePicture: View {
    let option: AppAppearance

    var body: some View {
        switch option {
        case .light:
            DesktopThumbnail(dark: false)
        case .dark:
            DesktopThumbnail(dark: true)
        case .system:
            ZStack {
                DesktopThumbnail(dark: false)
                DesktopThumbnail(dark: true)
                    .mask(DiagonalHalf())
            }
        }
    }
}

/// A desktop gradient with a sidebar window on it, painted in the
/// appearance it stands for; the colors are the subject, so they stay fixed.
private struct DesktopThumbnail: View {
    let dark: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: dark
                               ? [Color(red: 0.20, green: 0.22, blue: 0.34), Color(red: 0.07, green: 0.07, blue: 0.13)]
                               : [Color(red: 0.80, green: 0.88, blue: 1.00), Color(red: 0.58, green: 0.72, blue: 0.95)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 0) {
                HStack(spacing: 3) {
                    Circle().fill(Color(red: 1.00, green: 0.37, blue: 0.34))
                    Circle().fill(Color(red: 1.00, green: 0.74, blue: 0.18))
                    Circle().fill(Color(red: 0.16, green: 0.78, blue: 0.25))
                    Spacer(minLength: 0)
                }
                .frame(height: 5)
                .padding(.horizontal, 6)
                .frame(height: 12)
                .background(Color(white: dark ? 0.22 : 0.93))
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        bar(width: 18)
                        bar(width: 22)
                        bar(width: 14)
                    }
                    .padding(6)
                    .frame(width: 34, alignment: .topLeading)
                    .background(Color(white: dark ? 0.16 : 0.90))
                    VStack(alignment: .leading, spacing: 5) {
                        bar(width: 46)
                        bar(width: 34)
                        bar(width: 40)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .background(Color(white: dark ? 0.19 : 0.99))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .padding(.top, 12)
            .padding(.leading, 14)
        }
    }

    private func bar(width: CGFloat) -> some View {
        Capsule()
            .fill(Color(white: dark ? 0.40 : 0.76))
            .frame(width: width, height: 3)
    }
}

/// The lower-right half of a rectangle, cut corner to corner.
private struct DiagonalHalf: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - The island over a wallpaper

/// The sample wallpaper behind the island pictures.
struct AppearanceSampleWallpaper: View {
    var body: some View {
        LinearGradient(colors: [Color(red: 0.24, green: 0.25, blue: 0.48), Color(red: 0.47, green: 0.31, blue: 0.55),
                                Color(red: 0.85, green: 0.51, blue: 0.43)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// The island's outline in a picture: flush with the top edge, its lower
/// corners rounded.
private func islandShape(radius: CGFloat) -> UnevenRoundedRectangle {
    UnevenRoundedRectangle(cornerRadii: .init(topLeading: 0, bottomLeading: radius, bottomTrailing: radius, topTrailing: 0),
                           style: .continuous)
}

/// One frame of the island opening, for a motion tile: the resting notch
/// growing into the open island, its three cards arriving with the blur and
/// pace of the style.
struct AppearanceMotionPicture: View {
    let frame: IslandMotionPreview.Frame

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let shape = max(0, frame.shape)
            let width = lerp(size.width * 0.30, size.width * 0.80, shape)
            let height = lerp(8, size.height * 0.62, shape)
            let radius = lerp(4, 11, min(shape, 1))
            ZStack(alignment: .top) {
                AppearanceSampleWallpaper()
                islandShape(radius: radius)
                    .fill(Color.black)
                    .frame(width: width, height: height)
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color.white.opacity(index == 2 ? 0.30 : 0.20))
                            .frame(width: size.width * 0.17, height: max(4, size.height * 0.16))
                    }
                }
                .scaleEffect(0.9 + 0.1 * frame.content)
                .blur(radius: frame.blur * 0.3)
                .opacity(frame.content)
                .padding(.top, max(0, height - size.height * 0.16 - 7))
            }
            .frame(width: size.width, height: size.height, alignment: .top)
        }
        .accessibilityHidden(true)
    }

    private func lerp(_ from: CGFloat, _ to: CGFloat, _ t: Double) -> CGFloat { from + (to - from) * CGFloat(t) }
}

/// The open island in one glass over the wallpaper: black, black melting
/// into a frosted wallpaper over the gradient's height, or a clear glass
/// lens, each darkened by the tint.
struct AppearanceGlassPicture: View {
    let style: IslandGlassStyle
    let gradientHeight: Double
    let tint: Double

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let island = CGSize(width: size.width * 0.66, height: size.height * 0.80)
            let shape = islandShape(radius: 12)
            ZStack(alignment: .top) {
                AppearanceSampleWallpaper()
                Group {
                    switch style {
                    case .black:
                        shape.fill(Color.black)
                    case .gradient:
                        gradient(in: shape, height: island.height)
                    case .liquid:
                        liquid(in: shape, height: island.height)
                    }
                }
                .frame(width: island.width, height: island.height)
                // Two lines of text low in the island, where the glass is
                // clearest, to show they stay readable.
                VStack(alignment: .leading, spacing: 3) {
                    Capsule().fill(Color.white.opacity(0.9)).frame(width: island.width * 0.42, height: 3.5)
                    Capsule().fill(Color.white.opacity(0.55)).frame(width: island.width * 0.28, height: 3)
                }
                .frame(width: island.width * 0.72, alignment: .leading)
                .padding(.top, island.height * 0.62)
            }
            .frame(width: size.width, height: size.height, alignment: .top)
        }
        .accessibilityHidden(true)
    }

    /// What the island blurs, for the two see-through glasses.
    private var frosted: some View {
        AppearanceSampleWallpaper().blur(radius: 6).saturation(1.2)
    }

    private func gradient(in shape: UnevenRoundedRectangle, height: CGFloat) -> some View {
        let strip = 0.16
        let melt = NotchTranslucentTint.gradient(height: height, stripHeight: height * strip,
                                                 gradientHeight: gradientHeight, tint: tint)
        let stops = NotchTranslucentTint.stops(height: height, stripHeight: height * strip, openness: 1,
                                               increasedContrast: false, rampLength: melt.rampLength,
                                               clearance: melt.clearance)
            .map { Gradient.Stop(color: .black.opacity($0.opacity), location: $0.location) }
        return ZStack {
            frosted
            Color.black.opacity(0.18)
            LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
        }
        .clipShape(shape)
    }

    /// A clear lens rather than a melt: the whole island lets the wallpaper
    /// through, darker toward the camera and by the tint, with a bright rim.
    private func liquid(in shape: UnevenRoundedRectangle, height: CGFloat) -> some View {
        let unit = min(max(tint, 0), 1)
        return ZStack {
            frosted
            LinearGradient(colors: [Color.black.opacity(0.45 + 0.45 * unit), Color.black.opacity(0.12 + 0.5 * unit)],
                           startPoint: .top, endPoint: .bottom)
            LinearGradient(colors: [Color.white.opacity(0), Color.white.opacity(0.14)], startPoint: .top, endPoint: .bottom)
        }
        .clipShape(shape)
        .overlay { shape.strokeBorder(Color.white.opacity(0.45), lineWidth: 0.75) }
    }
}
