// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import SwiftUI
import UIKit

// The small pieces that make Home's Mac feel like an object on a table:
// light across its glass, its shadow on the floor, its screen glowing with
// the wallpaper, and power flowing into it while it charges.

/// A band of light across glass or metal, toward the upper left.
struct Specular: View {
    var strength: Double

    var body: some View {
        let along: CGFloat = -0.18
        let down: CGFloat = -0.1
        let band = Gradient(colors: [.white.opacity(0), .white.opacity(strength), .white.opacity(0)])
        GeometryReader { geometry in
            let size = geometry.size
            let shift = CGSize(width: size.width * along, height: size.height * down)
            LinearGradient(gradient: band, startPoint: .leading, endPoint: .trailing)
                .frame(width: size.width * 0.5, height: size.height * 2.2)
                .rotationEffect(.degrees(22))
                .position(x: size.width / 2, y: size.height / 2)
                .offset(shift)
        }
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The soft shadow the Mac casts on the floor.
struct FloorShadow: View {
    var width: CGFloat
    var dark: Bool

    var body: some View {
        let shade: Double = dark ? 0.62 : 0.2
        Ellipse()
            .fill(Color.black.opacity(shade))
            .frame(width: width, height: 20)
            .blur(radius: 12)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// A light running along an edge from left to right, again and again: power
/// flowing in while the Mac charges.
struct ChargeFlow: View {
    var tint: Color
    @State private var running = false

    var body: some View {
        GeometryReader { geometry in
            let band = geometry.size.width * 0.32
            Capsule()
                .fill(LinearGradient(colors: [tint.opacity(0), tint, tint.opacity(0)], startPoint: .leading, endPoint: .trailing))
                .frame(width: band, height: geometry.size.height)
                .shadow(color: tint.opacity(0.8), radius: 3)
                .offset(x: running ? geometry.size.width : -band)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: false)) { running = true }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A light that swells and fades, slowly: the MagSafe LED while charging.
struct Breathing: ViewModifier {
    var active: Bool
    @State private var lit = false

    func body(content: Content) -> some View {
        content
            .opacity(active && !lit ? 0.45 : 1)
            .onAppear { start() }
            .onChange(of: active) { _, _ in start() }
    }

    private func start() {
        guard active else { lit = false; return }
        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { lit = true }
    }
}

/// The wallpaper's colour, for the screen's glow: its average, a little
/// more saturated and never too dark to glow. Kept for the last image, so
/// Home reopening doesn't measure it again.
@MainActor
enum WallpaperGlow {
    private static var last: (image: ObjectIdentifier, color: Color)?

    static func color(of image: UIImage?) -> Color? {
        guard let image else { return nil }
        let key = ObjectIdentifier(image)
        if let last, last.image == key { return last.color }
        guard let color = average(image) else { return nil }
        last = (key, color)
        return color
    }

    /// Draws the image into 8×8 pixels and averages them.
    private static func average(_ image: UIImage) -> Color? {
        guard let cgImage = image.cgImage else { return nil }
        let side = 8
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                          bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.interpolationQuality = .medium
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return nil }
        var r = 0.0, g = 0.0, b = 0.0
        for i in stride(from: 0, to: pixels.count, by: 4) {
            r += Double(pixels[i]); g += Double(pixels[i + 1]); b += Double(pixels[i + 2])
        }
        let count = Double(side * side) * 255
        let mean = UIColor(red: r / count, green: g / count, blue: b / count, alpha: 1)
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        mean.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return Color(hue: Double(hue), saturation: Double(min(1, saturation * 1.35)), brightness: Double(max(0.6, brightness)))
    }
}
