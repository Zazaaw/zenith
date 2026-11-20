// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: a QR code on screen. The bitmap is drawn at exactly the
// pixels a module takes on this display (so nothing is resampled), shown
// with nearest-neighbour sampling, dark modules on white with the quiet zone
// as the tile's own margin. Light modules on a dark island read poorly on
// many phone cameras, so a code is never drawn inverted.

struct QRCodeView: View {
    let matrix: QRMatrix
    let logo: Bool
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { proxy in
            let total = matrix.size + QRRender.quietZone * 2
            let side = min(proxy.size.width, proxy.size.height)
            let scale = max(1, displayScale)
            // Whole pixels a module, so every module is the same size.
            let pixels = max(1, Int((side * scale / CGFloat(total)).rounded(.down)))
            let drawn = CGFloat(pixels * total) / scale
            Group {
                if let image = QRImageCache.image(matrix, moduleSize: pixels, logo: logo) {
                    Image(decorative: image, scale: scale)
                        .resizable()
                        .interpolation(.none)
                        .antialiased(false)
                } else {
                    Color.white
                }
            }
            .frame(width: drawn, height: drawn)
            .clipShape(RoundedRectangle(cornerRadius: drawn * 0.06, style: .continuous))
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .accessibilityElement()
        .accessibilityLabel(ZenithStrings.qr(L10n.shared.language).title)
    }
}

/// The bitmaps the views draw, by matrix, pixels a module and star, so a
/// redraw does not render the same code again.
enum QRImageCache {
    private static let cache = NSCache<NSString, CGImageBox>()

    static func image(_ matrix: QRMatrix, moduleSize: Int, logo: Bool) -> CGImage? {
        let key = "\(matrix.hashValue)-\(matrix.size)-\(moduleSize)-\(logo)" as NSString
        if let box = cache.object(forKey: key), box.matrix == matrix { return box.image }
        guard let image = QRRender.image(matrix, moduleSize: moduleSize, logo: logo) else { return nil }
        cache.setObject(CGImageBox(image: image, matrix: matrix), forKey: key)
        return image
    }

    private final class CGImageBox {
        let image: CGImage
        let matrix: QRMatrix
        init(image: CGImage, matrix: QRMatrix) {
            self.image = image
            self.matrix = matrix
        }
    }
}

/// The QR surfaces' card: the island's near black with a hairline, its
/// controls in the dark appearance whatever the system's.
struct QRCardChrome: ViewModifier {
    var cornerRadius: CGFloat = 24
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(Color(white: 0.055).opacity(0.97), in: shape)
            .overlay {
                shape.strokeBorder(contrast == .increased ? ZenithIsland.contrastHairline : Color.white.opacity(0.1),
                                   lineWidth: 0.75)
                    .allowsHitTesting(false)
            }
            .environment(\.colorScheme, .dark)
            .tint(ZenithIsland.accent)
    }
}

/// How a code arrives: out of a blur, up from slightly small, on the
/// island's spring. Reduce Motion leaves a fade.
struct QRArrival: ViewModifier {
    let shown: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .blur(radius: shown || reduceMotion ? 0 : 12)
            .scaleEffect(shown || reduceMotion ? 1 : 0.92)
    }
}

/// A QR surface's small action: a glyph over a short word, on a soft tile.
struct QRActionButton: View {
    let symbol: String
    let title: String
    var done = false
    let action: () -> Void
    @State private var hovering = false
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: done ? "checkmark" : symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(height: 16)
                Text(title)
                    .font(.system(size: 9.5, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(hovering ? ZenithIsland.primary : ZenithIsland.secondary)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, 2)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(hovering ? Color.white.opacity(0.09) : ZenithIsland.cardFill))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(enabled ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(ZenithMotion.respecting(.easeOut(duration: ZenithMotion.fast)), value: hovering)
        .help(title)
        .accessibilityLabel(title)
    }
}
