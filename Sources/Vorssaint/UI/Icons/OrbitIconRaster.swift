// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import SwiftUI

// Zenith fork: the Orbit icons are drawn with gradients, blurs and shadows.
// Drawn live, dozens of them (the sidebar, Orbit's shelves) cost the window
// its frame rate while scrolling. Each one is drawn once into a bitmap for
// its size, scale and appearance, and shown as an image from then on.

@MainActor
enum OrbitIconRaster {
    /// Room around the 100 pt canvas so the base's shadow isn't cut off.
    static let bleed: CGFloat = 0.08

    private static var cache: [String: NSImage] = [:]

    static func image<Content: View>(key: String, size: CGFloat, scale: CGFloat, dark: Bool,
                                     content: () -> Content) -> NSImage? {
        let cacheKey = "\(key)|\(size)|\(scale)|\(dark ? "d" : "l")"
        if let image = cache[cacheKey] { return image }
        let pad = size * bleed
        let view = content()
            .frame(width: 100, height: 100)
            .scaleEffect(size / 100)
            .frame(width: size, height: size)
            .padding(pad)
            .environment(\.colorScheme, dark ? .dark : .light)
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        guard let image = renderer.nsImage else { return nil }
        cache[cacheKey] = image
        return image
    }
}

/// Shows `content` (drawn on the kit's 100 pt canvas) at `size`, from a bitmap
/// made once per size, scale and appearance.
struct OrbitRasterizedIcon<Content: View>: View {
    let key: String
    let size: CGFloat
    @ViewBuilder let content: () -> Content

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let pad = size * OrbitIconRaster.bleed
        if let image = OrbitIconRaster.image(key: key, size: size, scale: displayScale,
                                             dark: colorScheme == .dark, content: content) {
            Image(nsImage: image)
                .resizable()
                .frame(width: size + pad * 2, height: size + pad * 2)
                .padding(-pad)
        } else {
            content()
                .frame(width: 100, height: 100)
                .scaleEffect(size / 100)
                .frame(width: size, height: size)
        }
    }
}
