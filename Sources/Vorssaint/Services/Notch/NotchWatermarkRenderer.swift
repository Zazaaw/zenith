// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Satu Visual

import AppKit
import CoreGraphics
import CoreText
import Foundation
import ImageIO

// Zenith fork: drawing the photo actions' watermark (NotchWatermarkSupport)
// with Core Graphics and Core Text, at the picture's full resolution and in
// its own colour space, so a Display P3 photo stays P3 and the mark's white
// is the picture's white. The bundled star is a vector path, a chosen PDF or
// SVG is drawn as vectors at the size it lands at, and a bitmap logo is read
// at that size from its source. Everything here runs off the main thread: the
// photo queue for the outputs, a preview queue for the island's live preview,
// which draws the same mark over a small copy of the first picture.
//
// The test executable compiles this file.

/// A logo ready to draw. Immutable once made; each queue loads its own.
final class NotchWatermarkLogo: @unchecked Sendable {
    private enum Art {
        case star(CGPath)
        case bitmap(CGImageSource)
        case pdf(CGPDFPage, CGRect)
        case vector(NSImage)
    }

    private let art: Art
    /// Width over height.
    let aspect: CGFloat
    /// The file it was read from; nil for the star.
    let file: String?

    var isStar: Bool { if case .star = art { return true } else { return false } }

    private init(art: Art, aspect: CGFloat, file: String?) {
        self.art = art
        self.aspect = aspect
        self.file = file
    }

    /// The Satu Visual star, the mascot's own path brought into a unit square.
    static let star: NotchWatermarkLogo = {
        let box = NotchMascotGeometry.starBox
        var transform = CGAffineTransform(scaleX: 1 / box.width, y: 1 / box.height)
            .translatedBy(x: -box.minX, y: -box.minY)
        let path = NotchMascotGeometry.star(size: 1).copy(using: &transform) ?? NotchMascotGeometry.star(size: 1)
        return NotchWatermarkLogo(art: .star(path), aspect: 1, file: nil)
    }()

    /// The logo a style names, or the star when it names none or the file
    /// is missing or unreadable.
    static func load(_ file: String?, container: URL? = PrivateFileStore.containerURL) -> NotchWatermarkLogo {
        guard let file, let url = NotchWatermarkLogoStore.url(for: file, container: container),
              let logo = load(url: url, name: file) else { return star }
        return logo
    }

    static func load(url: URL, name: String? = nil) -> NotchWatermarkLogo? {
        let name = name ?? url.lastPathComponent
        switch url.pathExtension.lowercased() {
        case "pdf":
            guard let document = CGPDFDocument(url as CFURL), let page = document.page(at: 1) else { return nil }
            let box = page.getBoxRect(.cropBox)
            guard box.width > 0, box.height > 0 else { return nil }
            return NotchWatermarkLogo(art: .pdf(page, box), aspect: box.width / box.height, file: name)
        case "svg":
            guard let image = NSImage(contentsOf: url), image.isValid, image.size.width > 0, image.size.height > 0
            else { return nil }
            return NotchWatermarkLogo(art: .vector(image), aspect: image.size.width / image.size.height, file: name)
        default:
            guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
                  CGImageSourceGetCount(source) > 0,
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let size = MediaSupport.imageDisplaySize(properties: properties), size.width > 0, size.height > 0
            else { return nil }
            return NotchWatermarkLogo(art: .bitmap(source), aspect: size.width / size.height, file: name)
        }
    }

    /// Draws the logo filling `rect` (Core Graphics coordinates, y up). The
    /// star is filled with the current fill colour; the others in their own
    /// colours, which `NotchWatermarkRenderer` tints when it must.
    func draw(in context: CGContext, rect: CGRect) {
        guard rect.width > 0, rect.height > 0 else { return }
        switch art {
        case let .star(path):
            // The path runs y down in a unit square.
            var transform = CGAffineTransform(translationX: rect.minX, y: rect.maxY)
                .scaledBy(x: rect.width, y: -rect.height)
            guard let placed = path.copy(using: &transform) else { return }
            context.addPath(placed)
            context.fillPath(using: .evenOdd)
        case let .bitmap(source):
            let pixels = Int(max(rect.width, rect.height).rounded(.up))
            let options = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: max(1, pixels),
                kCGImageSourceShouldCacheImmediately: true,
            ] as CFDictionary
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return }
            context.saveGState()
            context.interpolationQuality = .high
            context.draw(image, in: rect)
            context.restoreGState()
        case let .pdf(page, box):
            context.saveGState()
            context.translateBy(x: rect.minX, y: rect.minY)
            context.scaleBy(x: rect.width / box.width, y: rect.height / box.height)
            context.translateBy(x: -box.minX, y: -box.minY)
            context.clip(to: box)
            context.drawPDFPage(page)
            context.restoreGState()
        case let .vector(image):
            context.saveGState()
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            NSGraphicsContext.restoreGraphicsState()
            context.restoreGState()
        }
    }
}

enum NotchWatermarkRenderer {
    /// `image` with the watermark drawn in, same size, colour space and
    /// alpha. Nil when it cannot be drawn: the caller must not write the
    /// picture unmarked.
    static func watermarked(_ image: CGImage, style: NotchWatermarkStyle, logo: NotchWatermarkLogo) -> CGImage? {
        let style = style.sanitized()
        guard let context = canvas(like: image) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.draw(image, in: rect)
        draw(style, logo: logo, canvas: rect.size, backdrop: image, in: context)
        return context.makeImage()
    }

    /// The watermark alone over transparency at `backdrop`'s size, for the
    /// island's preview to lay over the picture.
    static func overlay(for backdrop: CGImage, style: NotchWatermarkStyle, logo: NotchWatermarkLogo) -> CGImage? {
        let space = backdrop.colorSpace.flatMap { $0.model == .rgb ? $0 : nil } ?? CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(data: nil, width: backdrop.width, height: backdrop.height, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let size = CGSize(width: backdrop.width, height: backdrop.height)
        context.clear(CGRect(origin: .zero, size: size))
        draw(style.sanitized(), logo: logo, canvas: size, backdrop: backdrop, in: context)
        return context.makeImage()
    }

    /// A bitmap like `image`'s: its colour space, its depth (8 or 16 bits),
    /// alpha only where it has alpha.
    private static func canvas(like image: CGImage) -> CGContext? {
        let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
        let space = image.colorSpace.flatMap { $0.model == .rgb || $0.model == .monochrome ? $0 : nil } ?? srgb
        let alpha: CGImageAlphaInfo
        if space.model == .monochrome {
            alpha = .none
        } else {
            alpha = NotchPhotoEncoder.hasAlpha(image) ? .premultipliedLast : .noneSkipLast
        }
        let depth = image.bitsPerComponent == 16 ? 16 : 8
        if let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: depth,
                                   bytesPerRow: 0, space: space, bitmapInfo: alpha.rawValue) {
            return context
        }
        return CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                         space: space, bitmapInfo: alpha.rawValue)
    }

    // MARK: Drawing

    /// One line of text, measured.
    private struct TextLine {
        let line: CTLine
        let width: CGFloat
        let ascent: CGFloat
        let descent: CGFloat
        var size: CGSize { CGSize(width: width, height: ascent + descent) }
    }

    private static func textLine(_ text: String, size: CGFloat, weight: NotchWatermarkWeight) -> TextLine? {
        guard !text.isEmpty, size > 0 else { return nil }
        let font = NSFont.systemFont(ofSize: size, weight: NSFont.Weight(rawValue: weight.fontWeight)) as CTFont
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String): true,
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
        var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
        let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
        guard width > 0 else { return nil }
        return TextLine(line: line, width: width, ascent: ascent, descent: descent)
    }

    /// Draws the watermark on a canvas of `canvas` pixels whose backdrop is
    /// `backdrop` (the same picture, any size, for Auto's luminance).
    static func draw(_ style: NotchWatermarkStyle, logo: NotchWatermarkLogo, canvas: CGSize, backdrop: CGImage?,
                     in context: CGContext) {
        guard style.drawsSomething, canvas.width >= 1, canvas.height >= 1 else { return }
        let unit = NotchWatermarkSupport.unit(canvas: canvas, scale: style.scale)
        let text = style.content.showsText
            ? textLine(style.text, size: NotchWatermarkSupport.fontSize(unit: unit, content: style.content), weight: style.weight)
            : nil
        let block = NotchWatermarkSupport.block(unit: unit, content: style.content,
                                                logoAspect: style.content.showsLogo ? logo.aspect : nil,
                                                textSize: text?.size)
        guard block.size.width > 0, block.size.height > 0 else { return }

        // Where the mark lands, in the picture's top-left coordinates, and the
        // region Auto reads under it.
        let centres: [CGPoint]
        let region: CGRect
        if style.tiled {
            centres = NotchWatermarkSupport.tileCenters(canvas: canvas, block: block.size, unit: unit)
            region = CGRect(origin: .zero, size: canvas)
        } else {
            let margin = NotchWatermarkSupport.margin(canvas: canvas, margin: style.margin)
            let origin = NotchWatermarkSupport.origin(canvas: canvas, block: block.size, position: style.position,
                                                      margin: margin)
            centres = [CGPoint(x: origin.x + block.size.width / 2, y: origin.y + block.size.height / 2)]
            region = CGRect(origin: origin, size: block.size)
        }
        guard !centres.isEmpty else { return }

        let autoTone = backdrop.flatMap { image -> NotchWatermarkTone? in
            let scaleX = CGFloat(image.width) / canvas.width, scaleY = CGFloat(image.height) / canvas.height
            let scaled = CGRect(x: region.minX * scaleX, y: region.minY * scaleY,
                                width: region.width * scaleX, height: region.height * scaleY)
            return luminance(of: image, in: scaled).map(NotchWatermarkSupport.tone(luminance:))
        } ?? .light
        let fill = color(for: style, autoTone: autoTone)
        let tintsLogo = logo.isStar || style.color != .original

        context.saveGState()
        context.setAlpha(CGFloat(style.opacity))
        if style.shadow {
            // Dark under a light mark, a faint light glow under a dark one.
            let lightMark = luminance(of: fill) > NotchWatermarkSupport.toneThreshold
            context.setShadow(offset: CGSize(width: 0, height: -unit * 0.035), blur: unit * 0.18,
                              color: lightMark ? CGColor(gray: 0, alpha: 0.5) : CGColor(gray: 1, alpha: 0.3))
        }
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        context.setFillColor(fill)
        for centre in centres {
            context.saveGState()
            // Into Core Graphics' y-up space, centred on the mark.
            context.translateBy(x: centre.x, y: canvas.height - centre.y)
            if style.tiled { context.rotate(by: NotchWatermarkSupport.tileAngle * .pi / 180) }
            let frame = CGRect(x: -block.size.width / 2, y: -block.size.height / 2,
                               width: block.size.width, height: block.size.height)
            func place(_ rect: CGRect) -> CGRect {
                CGRect(x: frame.minX + rect.minX, y: frame.maxY - rect.maxY, width: rect.width, height: rect.height)
            }
            if let logoRect = block.logo.map(place) {
                drawLogo(logo, in: logoRect, tinted: tintsLogo, color: fill, context: context)
            }
            if let text, let textRect = block.text.map(place) {
                context.textMatrix = .identity
                context.textPosition = CGPoint(x: textRect.minX, y: textRect.minY + text.descent)
                CTLineDraw(text.line, context)
            }
            context.restoreGState()
        }
        context.endTransparencyLayer()
        context.restoreGState()
    }

    private static func drawLogo(_ logo: NotchWatermarkLogo, in rect: CGRect, tinted: Bool, color: CGColor,
                                 context: CGContext) {
        if logo.isStar {
            logo.draw(in: context, rect: rect)
            return
        }
        guard tinted else {
            logo.draw(in: context, rect: rect)
            return
        }
        // Keep the logo's shape, wear the mark's colour.
        context.saveGState()
        context.beginTransparencyLayer(in: rect, auxiliaryInfo: nil)
        logo.draw(in: context, rect: rect)
        context.setBlendMode(.sourceIn)
        context.setFillColor(color)
        context.fill(rect)
        context.endTransparencyLayer()
        context.restoreGState()
    }

    // MARK: Colour

    /// The fill for a style: Auto's white or black, the fixed white or
    /// black, or the custom colour, in sRGB (the context converts it into
    /// the picture's space).
    static func color(for style: NotchWatermarkStyle, autoTone: NotchWatermarkTone) -> CGColor {
        let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
        func make(_ red: Double, _ green: Double, _ blue: Double) -> CGColor {
            CGColor(colorSpace: srgb, components: [CGFloat(red), CGFloat(green), CGFloat(blue), 1])
                ?? CGColor(gray: CGFloat(green), alpha: 1)
        }
        switch style.color {
        case .white: return make(1, 1, 1)
        case .black: return make(0, 0, 0)
        case .custom:
            if let rgb = NotchWatermarkSupport.rgb(hex: style.customColor) { return make(rgb.red, rgb.green, rgb.blue) }
            return make(1, 1, 1)
        case .auto, .original:
            return autoTone == .dark ? make(0, 0, 0) : make(1, 1, 1)
        }
    }

    /// The relative luminance of a colour, read through sRGB.
    static func luminance(of color: CGColor) -> Double {
        let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let converted = color.converted(to: srgb, intent: .defaultIntent, options: nil),
              let components = converted.components, components.count >= 3 else {
            return Double(color.components?.first ?? 1)
        }
        return NotchWatermarkSupport.relativeLuminance(red: Double(components[0]), green: Double(components[1]),
                                                       blue: Double(components[2]))
    }

    /// The average relative luminance of `rect` (pixels, origin top left)
    /// in `image`, read from a small sRGB copy; transparent pixels count for
    /// nothing. Nil when the region misses the picture.
    static func luminance(of image: CGImage, in rect: CGRect) -> Double? {
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let region = rect.integral.intersection(bounds)
        guard !region.isNull, region.width >= 1, region.height >= 1, let crop = image.cropping(to: region) else {
            return nil
        }
        let side = 8
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                          bytesPerRow: side * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.interpolationQuality = .medium
            context.draw(crop, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return nil }
        var total = 0.0, weight = 0.0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Double(pixels[index + 3]) / 255
            guard alpha > 0 else { continue }
            let value = NotchWatermarkSupport.relativeLuminance(red: Double(pixels[index]) / 255 / alpha,
                                                                green: Double(pixels[index + 1]) / 255 / alpha,
                                                                blue: Double(pixels[index + 2]) / 255 / alpha)
            total += value * alpha
            weight += alpha
        }
        return weight > 0 ? total / weight : nil
    }
}
